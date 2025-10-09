from bertopic_helpers import create_docs
from sync_fetch_data import initialize_and_fetch_db, get_last_sync_date, fetch_new_records_from_supabase, update_last_sync_date,find_newest_timestamp,upsert_records_to_db, fetch_data_for_bertopic, initialize_supabase_session
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.cluster import KMeans
from bertopic.vectorizers import ClassTfidfTransformer
from bertopic.representation import KeyBERTInspired, MaximalMarginalRelevance
from transform_question_to_vector import vectorize_records
from sentence_transformers import SentenceTransformer


import umap
import supabase
import hdbscan
import datetime
from bertopic import BERTopic
from pathlib import Path




if __name__ == "__main__":
    # First we need initialize our supabase client and the local db file:
    supabase_client: supabase   = initialize_supabase_session()
    db                          = initialize_and_fetch_db(
        # Easy way to clear existing docs and vectors for recalculation
        reset_question_vector=False,
        reset_doc=False
        )
    
    # Fetch new data from server
    last_sync_date: datetime = get_last_sync_date()
    print(f"Got last sync time of: {last_sync_date}")
    # Pass that into and then fetch the new question records to be analyzed
    new_records = fetch_new_records_from_supabase(
        supabase_client     =supabase_client,
        last_sync_date      =last_sync_date
    )
    print(f"Got {len(new_records['question_answer_pairs'])} total qa records from supabase")
    print(f"Got {len(new_records['question_answer_attempts'])} total attempt records from supabase")
    # Assuming we got anything back, update the last sync date for future runs
    update_last_sync_date(find_newest_timestamp(records=new_records))

    # Now we need to save the new records to our local db file:
    upsert_records_to_db(
        records=new_records, 
        db = db)

    # Ensure all question records have their doc created and placed back into the database
    create_docs()
        # {question_id: "", ..., doc: ""}


    # Pre-Compute vectors (so we don't have to recalculate 10,000's of records every run)
    vectorize_records()
    

    docs, embeddings, question_ids = fetch_data_for_bertopic(db)
    embedding_model = SentenceTransformer('sentence-transformers/allenai-specter')
    # Define Dimensionality Reduction model for bertopic 
    umap_model              = umap.UMAP(
            n_neighbors     = 5,
            min_dist        = 0.1,
            random_state    = 0
        )

    # Define hdbscan model
    hdbscan_model           = hdbscan.HDBSCAN(
        min_cluster_size    = 25,
        # min_samples         = 1,
        metric              = 'euclidean',
        cluster_selection_method = 'eom',
        prediction_data     = True
    )

    clustering_model        = KMeans(
        n_clusters=80,
        random_state=0
    )

    # Define which count vectorizer we will use for bertopic
    vectorizer              = CountVectorizer(
        lowercase   = True,
        max_df      = 0.80,
        stop_words  = 'english',
        ngram_range = (1,3)
    )

    # Define c_tf_idf model for bertopic
    c_tf_idf                = ClassTfidfTransformer(
        reduce_frequent_words   = True,
        bm25_weighting          = True,
        seed_words=[
            'RSS', 'residual sum of squares', 'linear regression', 'logistic regression',
            'latent dirichlet allocation', 'endoplasmic reticulum', 'electron', 'proton', 'model', 
        ],
        seed_multiplier=2
        )

    # Define the representation model for bertopic
    representation_model    = MaximalMarginalRelevance(diversity=0.3)
    
    # Define the bertopic initialization using the models we've defined
    topic_model = BERTopic(
        embedding_model     = embedding_model,
        umap_model          = umap_model,
        hdbscan_model       = hdbscan_model,
        vectorizer_model    = vectorizer,
        ctfidf_model        = c_tf_idf,
        representation_model= representation_model,
    )
    # Create visualizations directory if it doesn't exist
    vis_dir = Path("bertopic_visualizations")
    vis_dir.mkdir(exist_ok=True)

    # Fit the model
    topics, probabilities = topic_model.fit_transform(docs, embeddings)

    # Get topic info
    topic_info = topic_model.get_topic_info()
    topic_info.to_csv(vis_dir / "topic_info.csv", index=False)

    # Generate and save visualizations
    topic_model.visualize_topics().write_html(str(vis_dir / "topics.html"))
    topic_model.visualize_documents(docs, embeddings=embeddings, hide_annotations=True).write_html(str(vis_dir / "documents.html"))
    topic_model.visualize_hierarchy().write_html(str(vis_dir / "hierarchy.html"))
    topic_model.visualize_barchart().write_html(str(vis_dir / "barchart.html"))
    topic_model.visualize_heatmap().write_html(str(vis_dir / "heatmap.html"))


    print(f"Visualizations saved to {vis_dir}")