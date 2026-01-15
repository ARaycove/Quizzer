import os
os.environ["TOKENIZERS_PARALLELISM"] = "false"
import umap
import timeit
import hdbscan
import supabase
import datetime
import pandas as pd
from pathlib import Path
from bertopic import BERTopic
from sklearn.cluster import KMeans
from neural_net import reports as rp
from neural_net import attempt_pre_process as ap
from sentence_transformers import SentenceTransformer
from bertopic.vectorizers import ClassTfidfTransformer
from utility.transform_question_to_vector import vectorize_records
from sklearn.feature_extraction.text import CountVectorizer
from neural_net.grid_search import grid_search_quizzer_model
from neural_net.accuracy_net import pre_process_training_data
from neural_net.grid_search import train_and_save_batch_configs
from utility.bertopic_helpers import create_docs, export_outlier_topics_to_docx, set_process_limits
from bertopic.representation import KeyBERTInspired, MaximalMarginalRelevance
from utility.sync_fetch_data import (initialize_and_fetch_db, get_last_sync_date, fetch_new_records_from_supabase, 
                             update_last_sync_date,find_newest_timestamp,upsert_records_to_db, 
                             fetch_data_for_bertopic, initialize_supabase_session, sync_vectors_to_supabase,
                             sync_knn_results_to_supabase, clean_deleted_records_locally,
                             save_changed_records, load_changed_records)
from neural_net.prediction_net.model_def import train_question_accuracy_model

from utility.knn_utils import (compute_complete_pairwise_distances, plot_distance_distribution, compute_knn_model, update_knn_vectors_locally)
from sklearn.mixture import GaussianMixture
# Define Globals
bypass_model_train      = False  # topic model
reset_question_vector   = False
reset_doc               = False

# Timing Globals

def run_data_sync_process(supabase_client, db):
    '''
    Fetches Fresh Data, Syncs new data from models
    '''
    last_sync_date: datetime = get_last_sync_date()
    print(f"Got last sync time of: {last_sync_date}")
    new_records = fetch_new_records_from_supabase(
        supabase_client     =supabase_client,
        last_sync_date      =last_sync_date
    )
    # Now we need to save the new records to our local db file:
    upsert_records_to_db(
        records=new_records,
        db = db,
        supabase_client=supabase_client)
    
    # Assuming we got anything back, update the last sync date for future runs (do this after we have recorded our return values)
    update_last_sync_date(find_newest_timestamp(records=new_records))
    clean_deleted_records_locally(db=db, supabase_client=supabase_client)

    # Ensure all question records have their doc created and placed back into the database
    create_docs() # {question_id: "", ..., doc: ""}

    # Pre-Compute vectors (so we don't have to recalculate 10,000's of records every run)
    vectorize_records()
    sync_vectors_to_supabase(reset_attempts_vector=reset_question_vector, reset_question_vector=reset_question_vector)

    changed_records = load_changed_records()
    sync_knn_results_to_supabase(db, supabase_client, changed_records, get_last_sync_date())
    # Once results are synced, clear the local changed_records cache (preventing repeats)
    save_changed_records([])

def main():
    set_process_limits()
    # HyperParameters
    global bypass_model_train



    bypass_prediction_model = False
    n_clusters              = 31
    random_state            = 69

    overall_start = timeit.default_timer()
    # First we need initialize our supabase client and the local db file:
    supabase_client: supabase   = initialize_supabase_session()
    db                          = initialize_and_fetch_db(
        # Easy way to clear existing docs and vectors for recalculation
        reset_question_vector=reset_question_vector,
        reset_doc=reset_doc
        )
    
    run_data_sync_process(supabase_client = supabase_client,
                          db = db)

    start = timeit.default_timer()
    end = timeit.default_timer()
    topic_model_train_time = end - start # Set to now in case model doesn't run
    if not bypass_model_train:
        docs, embeddings, question_ids = fetch_data_for_bertopic(db)
        embedding_model = SentenceTransformer('sentence-transformers/allenai-specter')
        # Define Dimensionality Reduction model for bertopic 
        umap_model              = umap.UMAP(
                n_neighbors     = 25,
                n_components    = 25,
                min_dist        = 0.01,
                spread          = 0.5,
                random_state    = 0,
                metric          = 'manhattan'
            )
        ######################################
        # Define What clustering model to use:
        ######################################
        cluster_models = [
            hdbscan.HDBSCAN(
                min_cluster_size    = 25,
                min_samples         = 10,
                metric              = 'manhattan', #FIXME Evaluate better distance metric
                cluster_selection_method = 'eom',
                prediction_data     = True
            ),
            # These models require us to know what the number of clusters is before hand, since we don't know this information it presents an issue
            KMeans(
                n_clusters=n_clusters,
                random_state=random_state
            ),
            GaussianMixture(n_components=3, random_state=42)
        ]
        # Select from list:
        clustering_model        = cluster_models[0]

        # Define which count vectorizer we will use for bertopic
        vectorizer              = CountVectorizer(
            lowercase   = True,
            max_df      = 0.80,
            stop_words  = 'english', # keep stopwords, but remove common words
            ngram_range = (1,4)
        )

        # Define c_tf_idf model for bertopic
        c_tf_idf                = ClassTfidfTransformer(
            reduce_frequent_words   = True,
            bm25_weighting          = True,
            )

        # Define the representation model for bertopic
        representation_model    = MaximalMarginalRelevance(diversity=0.3)
        
        # Define the bertopic initialization using the models we've defined
        start = timeit.default_timer()

        topic_model = BERTopic(
            verbose                 = True,
            calculate_probabilities = True,
            top_n_words             = 10,
            embedding_model         = embedding_model,
            umap_model              = umap_model,
            hdbscan_model           = clustering_model,
            vectorizer_model        = vectorizer,
            ctfidf_model            = c_tf_idf,
            representation_model    = representation_model,
            # seed_topic_list     = seed_topics,
        )

        # Create visualizations directory if it doesn't exist
        vis_dir = Path("bertopic_visualizations")
        vis_dir.mkdir(exist_ok=True)

        # Fit the model
        topics, probabilities = topic_model.fit_transform(docs, embeddings)

        # Get topic info
        topic_info = topic_model.get_topic_info()
        topic_info.to_csv(vis_dir / "topic_info.csv", index=False)

        # Generate and save all BERTopic visualizations
        topic_model.visualize_topics().write_html(str(vis_dir / "topics.html"))
        
        topic_model.visualize_documents(docs, embeddings=embeddings, hide_annotations=True).write_html(str(vis_dir / "documents.html"))
        topic_model.visualize_hierarchy().write_html(str(vis_dir / "hierarchy.html"))
        topic_model.visualize_barchart(top_n_topics=50).write_html(str(vis_dir / "barchart.html"))
        topic_model.visualize_heatmap().write_html(str(vis_dir / "heatmap.html"))
        # topic_model.visualize_term_rank().write_html(str(vis_dir / "term_rank.html"))

        hierarchical_topics = topic_model.hierarchical_topics(docs)
        topic_model.visualize_hierarchical_documents(docs, hierarchical_topics=hierarchical_topics, embeddings=embeddings).write_html(str(vis_dir / "hierarchical_documents.html"))

        print(f"Visualizations saved to {vis_dir}")
        end = timeit.default_timer()
        topic_model_train_time = end - start

        # Save data locally
        reduced_embeddings = topic_model.umap_model.embedding_

        # Visualize distance distribution of points (Are all points equally distant?)
        distance_matrix = compute_complete_pairwise_distances(reduced_embeddings)
        plot_distance_distribution(distance_matrix)
        
        # save only the updated values, if the knn vector has changed from last time then wipe it and it's neighbors (resetting dynamically)
        knn_model = compute_knn_model(embeddings=reduced_embeddings, k=25)
        changed_records, total_records = update_knn_vectors_locally(db=db, question_ids=question_ids, knn_model=knn_model, embeddings=reduced_embeddings)
        print(f"KNN vectors changed for {len(changed_records)}/{total_records} records")

        save_changed_records(changed_records)

        # FIXME Collect topic probabilities for each question, {topic_01: p_1, topic_02: p_2, topic_n: p_n}
        # This will show us how any given question relates to the larger knowledge map, not just it's immediate surroundings

        # FIXME Push topic_proba to Supabase
        
        # # Export to file for sharing
        # export_outlier_topics_to_docx(topic_model=topic_model)

        # Run the data sync again, so we immediately push new data.
        run_data_sync_process(supabase_client = supabase_client,
                            db = db)
    # ================================================================================
    # # Begin neural net pipeline
    # if not bypass_prediction_model:
    #     # Clear old global best and prior model before retraining. . .
    #     if os.path.exists('global_best_model.csv'):
    #         os.remove('global_best_model.csv')
    #     if os.path.exists('global_best_model.tflite'):
    #         os.remove('global_best_model.tflite')
    #     print(f"Now starting pre-processing of attempt data for neural net training")
    #     seed = 42

    #     # Pre-process, and train test split
    #     start = timeit.default_timer()
    #     X_train, X_test, y_train, y_test = ap.train_test_split_extraction(pre_process_training_data(), 0.2, random_state=seed)
    #     end = timeit.default_timer()
    #     pre_process_time = end - start

    #     print(f"Starting comprehensive grid search with {X_train.shape[1]} input features")
    #     print(f"Training set: {len(X_train)} samples, Test set: {len(X_test)} samples")
    #     # # Run comprehensive grid search
        
    #     start   = timeit.default_timer()
    #     n_search = 50
    #     grid_search_quizzer_model(X_train, y_train, X_test, y_test, n_search=n_search, batch_size=25)
    #     end     = timeit.default_timer()
    #     grid_search_time = end - start

    #     if not os.path.exists('global_best_model.tflite'):
    #         if not os.path.exists('grid_search_top_results.csv'):
    #             raise FileNotFoundError("No model or top results found")
    #         top_results = pd.read_csv('grid_search_top_results.csv')
    #         if top_results.empty:
    #             raise ValueError("Top results CSV is empty")
    #         best_params = [top_results.iloc[0].to_dict()]
    #         train_and_save_batch_configs(
    #             config_batch=best_params,
    #             X_train=X_train,
    #             y_train=y_train,
    #             X_test=X_test,
    #             y_test=y_test,
    #             input_features=X_train.shape[1]
    #         )

    #     if os.path.exists('global_best_model.tflite'):
    #         print(f"\nLoading global best model from disk...")
    #         start = timeit.default_timer()
    #         interpreter, X_test_transformed = ap.load_model_and_transform_test_data(
    #             model_path='global_best_model.tflite',
    #             feature_map_path='input_feature_map.json',
    #             X_train=X_train,
    #             X_test=X_test,
    #             y_train=y_train,
    #             y_test=y_test
    #         )
    #         metrics = rp.model_analytics_report(interpreter, X_test_transformed, y_test, filename="NN_Text_Report.txt")
    #         rp.create_comprehensive_visualizations(metrics, "Quizzer_NN")
    #         end = timeit.default_timer()
    #         final_report_time = end - start
    #         ap.push_model_to_supabase(
    #             model_name="accuracy_net", 
    #             metrics=metrics, 
    #             model_path="global_best_model.tflite", 
    #             feature_map_path="input_feature_map.json"
    #         )
            
    #     else:
    #         print("Grid search failed - no model saved")



    overall_end = timeit.default_timer()
    overall_time = overall_end - overall_start
    print("Final Report")
    # print(f"Got {len(new_records['question_answer_pairs'])} total qa records from supabase")
    # print(f"Got {len(new_records['question_answer_attempts'])} total attempt records from supabase")
    print(f"Bertopic Training took: {topic_model_train_time:.5f} seconds")
    print(f"Pipeline took:          {overall_time:.5f} seconds from start to finish")

if __name__ == "__main__":
    main()

    