from neural_net.accuracy_net import pre_process_training_data
from neural_net.prediction_net.handle_datasets import train_test_split, collect_feature_list, select_random_feature_subsets, get_candidate_subset_records
from neural_net.prediction_net.model_train import train_sub_model, select_best_subset_model, build_concat_model
from neural_net.prediction_net.model_eval import run_full_model_evaluation
from neural_net.prediction_net.model_charting import update_performance_chart
from neural_net.prediction_net.model_sub import report_sub_model_results
import random
import uuid
import timeit
import gc
from pathlib import Path

#FIXME
#Plans will be to separate the paths in this model training process
# Path 1, explores best sub-model configuration, in sets of 10, storing the hyperparameters so these can be rebuilt later
# Path 2, Loop over the best 100-200 configs and continue the gride search on these configurations to hopefully find more optimal solutions
# Path 3, Use our knowledge of the best sub-model configurations, and construct our large model on these sub-models
#   - Will start with rank 1 sub-model, and concat with rank 2
#   - Keep either rank 1 or the new concat model
#   - Repeat with model 3 through n, if concat model does not show improvement maintain old model.
#   - Track progression as it updates

# This way each path is designed in a way where they can be run in parallel in a form of a continuous training process.


def train_question_accuracy_model():
    df = pre_process_training_data()
    X_train, X_test, y_train, y_test = train_test_split(df)
    # get a list of all the feature names
    all_features = collect_feature_list(df)
    # Shuffle the features based on seed:
    random.shuffle(all_features)
    n = 5 # the number of random feature subsets to select from
    subset_size = 10 # the number of features that each sub-model will be trained on.
    completeness_threshold = 0.9

    max_iterations = 100
    current_iteration = 1
    iteration_timings = []
    sub_model_train_times = []

    # working model and sub model is the current architecture, defining the entire neural net, with all saved weights, neurons, and configs
    working_model = None
    evaluation_list = []
    all_sub_models = []
    rolling_results = []

    # Track comp-scores for sub-models for reporting
    sub_model_results = [] # list of maps {"composite_score": val, "feature_list": s}

    # When new models are trained, we generate a new unique id, this id will go into our model directory in a unique directory to house all the model files and results
    model_id = uuid.uuid4()
    model_dir = Path(f"neural_net/prediction_net/trained_models/{model_id}")

    for i in all_features:
        start = timeit.default_timer()
        if current_iteration >= max_iterations:
            break # prevent combinatorial explosion by limiting the number of features we end up selecting

        # Select n number of candidate additions to the working model
        # FIXME We should consider making a switch option that utilizes the best feature subsets selected as our list of sub-models instead
        # FIXME This would be much easier if we were to say store the model. However as new data comes in the sub-models will also change in performance.
        subsets = select_random_feature_subsets(
            current_feature         = i, 
            n                       = n, 
            all_features            = all_features, 
            X_train                 = X_train, 
            completeness_threshold  = completeness_threshold, 
            subset_size             = subset_size)

        # Train each candidate subset on available data, and save the weights for each one
        for s in subsets:
            s_start = timeit.default_timer()
            df = get_candidate_subset_records(
                subset_features = s,
                X_train         = X_train,
                y_train         = y_train
            )

            # Train our sub-models
            sub_model = train_sub_model(
                df              = df,
                feature_subset  = s,
                X_test          = X_test,
                y_test          = y_test
            )

            all_sub_models.append(sub_model)
            s_end = timeit.default_timer()
            s_train_time = s_end - s_start
            print(f"Sub-Model took {s_train_time} seconds to train")
            print(f"Sub-Model had a composite score: {sub_model['best_score']}")
            sub_model_results.append({"composite_score": sub_model['best_score'], "feature_list": s, "hyperparams": sub_model['best_params']})
            sub_model_train_times.append((s_end - s_start))

            # For this we push the results to the local db in a new table
            # This table houses all historical results
            # It then examines the local database table, and outputs visualizations for these models
            # This will help identify which subsets of features are truly the best, and perhaps we can cut training times down by always selecting the best subsets first, before trying new subsets
            report_sub_model_results(sub_model_results)
#################################################
# This part is not actually written, but would scan over the saved configurations and do more extensive grid search on the top sub-models to fine tune them as best as we can

# In theory the more accurate the sub-models the more accurate our final model will be

# Add new columns to sub_model table
#| AUC_ROC | num_grid_searches_performed | model_config | model_weights |

# currently the score recorded is a composite score, we will add in the AUC_ROC score and other metrics using the run_full_model_eval function
# num_grid_searches_performed, we will use this instead of a boolean to keep track of how much time has been invested into finding the best hyperparameters for the sub-model
#   heuristic would be to ensure the top 100 have 50 or so grid searches performed each on them,
#   Alternatively I could do a tiered heuristic, ensuring that the most promising results get more time invested.
#   Tiered would be intervals of 10, the top ten would be tier 1, 11 - 20 would be tier 2 and so on.
#   Based on rank, ranks 1 - 10 would get more grid searches as 11-21, in increments of 50 or some other heuristic.
#   if rank 11-21 had 100 searches performed each, then 1 - 10 should each get up to 150, then ranks 11-20 would get up to 100, and ranks 21-30 would get 50.
#   At this point all are even, the next grid search goes to ranks 1-10, bumping them to 200 each, once 1-10 are at 200, then 11-20 would get pushed to 150, and 21-30 to 100

#   The potential grid search space will be in the billiions so we should be too concerned with configurations getting randomly picked twice, and even if it does it will likely just be updated.
#################################################
# This part will be a specific sub-model that chops up all records with knn_## prefixes, for each of our records we've recorded some 25 adjacent questions
# This gives us 25 records per record, feature set would be the set of features recorded for the adjacent questions
# Since we have 6000 records, this gives us 25 * 6000 records to train a sub-model to learn how an adjacent question effects nearby accuracy,
# Unfortunately since we changed the distance metric to Manhattan, we will need to purge all records that used our cosine distnace (some value less than 1 for each)
# I could purge manually or not, but we lose a lot of data.

# Based on the current grid search the knn features rank at the top for most predictive, along with individual performance metrics to the specific question, while stat metrics are less important
# qv vector also ranks high in the list.
# So to predict accuracy we need the vectorized form of the question, how the user performed with it in the past (if at all) and how the user performed with similar questions
#   This aligns with what Dr. Manning found in his paper

#################################################
# This part separates out to the concat model train process
        if working_model == None:
            working_model = select_best_subset_model(all_sub_models)
        else:
            
            top_sub_models = get_sub_model_data() # Get only the record id's to preserve memory

            for sm in top_sub_models:
                sm = retrain_submodel_based_on_hyperparameters()
                cm = build_concat_model(
                    working_model_info  = working_model, 
                    sub_model_info      = sm, 
                    X_train             = X_train, 
                    y_train             = y_train, 
                    X_test              = X_test, 
                    y_test              = y_test)
                evaluation_list.append(cm)
                evaluation_list.append(working_model) # Add the working model to the evaluation_list
                working_model = select_best_subset_model(evaluation_list) # if the additional models showed no improvement over the working model, the original working model would get chosen.
                # if working model does not get better with the sub-model added do nothing, else run full evaluation and post new results

        #####################################
        # Iteration is now complete
        #####################################
        # Run full evaluation on updated model (could be the same model, but we will run regardless)
        # For this we will get all metrics, so that we can have a historical training chart
        # Keeps historical record of metrics, and maintains most current copy of the model plots for specific evaluation
        rolling_results.append(run_full_model_evaluation(
            working_model=working_model,
            X_test=X_test,
            y_test=y_test,
            model_dir=model_dir
        ))
        
        update_performance_chart(
            rolling_results = rolling_results,
            model_id        = model_id,
            model_dir       = model_dir
            ) # Rebuild the charts based on the current map

        # At this phase the working model has been updated and we iterate to the next feature in the dataset
        evaluation_list = [] # reset the evaluation list for next round
        all_sub_models  = []
        current_iteration += 1

        # run the garbage collector since models take up a good amount of memory space
        gc.collect() 

        end = timeit.default_timer()
        total_iteration_time = end - start
        print(f"Cycle Complete: {current_iteration/max_iterations} iterations")
        print(f"Cycle took {total_iteration_time} seconds")
        
        iteration_timings.append(total_iteration_time)

# Considerations
# 1. Not all features would be chosen all the time, condition lies that some features may not get chosen at all especially if they don't show improvement
# 2. Some features might get chosen twice, due to the bootstrap nature of the sub-models, some sub-models will use the same feature.