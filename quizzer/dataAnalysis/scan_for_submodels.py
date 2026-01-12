from neural_net.accuracy_net import pre_process_training_data
from neural_net.prediction_net.handle_datasets import train_test_split, collect_feature_list, select_random_feature_subsets, get_candidate_subset_records
from neural_net.prediction_net.model_train import train_sub_model
from neural_net.prediction_net.model_sub import report_sub_model_results
import random
import uuid
import timeit
import gc
from pathlib import Path

def scan_for_submodels():
    df = pre_process_training_data()
    X_train, X_test, y_train, y_test = train_test_split(df)
    # get a list of all the feature names
    all_features = collect_feature_list(df)
    # Shuffle the features based on seed:
    random.shuffle(all_features)
    n = 100 # the number of random feature subsets to select from
    subset_size = 10 # the number of features that each sub-model will be trained on.
    completeness_threshold = 0.85

    sub_model_train_times = []
    all_sub_models = []

    # Track comp-scores for sub-models for reporting
    sub_model_results = [] # list of maps {"composite_score": val, "feature_list": s}

    # When new models are trained, we generate a new unique id, this id will go into our model directory in a unique directory to house all the model files and results
    ###########################
    # PRE-DEFINED HAND-PICKED FEATURE SUBSETS
    ###########################
    # Define hand-picked feature subsets (2D array)
    # These are feature sets chosen based on domain knowledge or previous experiments
    # Note: Subsets can be of any size, not limited to subset_size
    hand_picked_subsets = [
        ['avg_react_time', 'was_first_attempt', 'total_correct_attempts', 'total_incorrect_attempts', 'total_attempts', 'accuracy_rate', 'revision_streak', 'days_since_last_revision', 'days_since_first_introduced', 'attempt_day_ratio'],
        # Example format - replace with actual feature names
        # ["feature1", "feature2", "feature3"],
        # ["feature4", "feature5", "feature6", "feature7"],
        # Each inner list represents a feature subset to train on
    ]
    
    # Train models on hand-picked subsets first
    print("=" * 80)
    print("TRAINING HAND-PICKED FEATURE SUBSETS")
    print("=" * 80)
    
    for subset_idx, hand_picked_subset in enumerate(hand_picked_subsets, 1):
        # Validate that all features in the subset exist in the dataset
        missing_features = [f for f in hand_picked_subset if f not in all_features]
        if missing_features:
            print(f"WARNING: Hand-picked subset {subset_idx} contains features not in dataset: {missing_features}")
            print(f"Skipping subset {subset_idx}")
            continue
        
        print(f"\nTraining on hand-picked subset {subset_idx}/{len(hand_picked_subsets)}")
        print(f"Subset size: {len(hand_picked_subset)} features")
        print(f"Features: {hand_picked_subset}")
        
        start = timeit.default_timer()
        
        # Get data for this subset
        subset_df = get_candidate_subset_records(
            subset_features=hand_picked_subset,
            X_train=X_train,
            y_train=y_train
        )
        
        if subset_df.empty:
            print(f"WARNING: No complete records for hand-picked subset {subset_idx}. Skipping.")
            continue
        
        # Train sub-model on hand-picked subset
        sub_model = train_sub_model(
            df=subset_df,
            feature_subset=hand_picked_subset,
            X_test=X_test,
            y_test=y_test,
            n_num_grid_search=1  # Same as random subsets for consistency
        )
        
        all_sub_models.append(sub_model)
        end = timeit.default_timer()
        train_time = end - start
        
        print(f"Hand-picked subset {subset_idx} took {train_time:.2f} seconds to train")
        print(f"Hand-picked subset {subset_idx} composite score: {sub_model['best_score']:.4f}")
        
        # Record results
        sub_model_results.append({
            "composite_score": sub_model['best_score'],
            "feature_list": hand_picked_subset,
            "hyperparams": sub_model['best_params']
        })
        
        sub_model_train_times.append(train_time)
        
        # Report results
        report_sub_model_results(sub_model_results)
        gc.collect()
    
    print(f"\nFinished training {len(hand_picked_subsets)} hand-picked subsets")
    print("=" * 80)
    print("STARTING RANDOM FEATURE SUBSET EXPLORATION")
    print("=" * 80)

    ###########################
    # Continue with existing random subset exploration
    ###########################
    for i in all_features:
        start = timeit.default_timer()

        # Select n number of candidate additions to the working model
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
                df                  = df,
                feature_subset      = s,
                X_test              = X_test,
                y_test              = y_test,
                n_num_grid_search   = 1 # Since sub-models in phase 1 are purely exploratory configuration we are not going to concern ourselves with optimal grid search, phase 2 of the pipeline will had more in depth grid search on only the most promising results
                # Use default param grid which has one configuration
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
            gc.collect()

if __name__ == "__main__":
    scan_for_submodels()