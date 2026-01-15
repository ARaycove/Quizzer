from neural_net.accuracy_net import pre_process_training_data
from neural_net.prediction_net.handle_datasets import train_test_split, collect_feature_list, select_random_feature_subsets, get_candidate_subset_records
from neural_net.prediction_net.model_train import train_sub_model
from neural_net.prediction_net.model_sub import report_sub_model_results
from utility.sync_fetch_data import initialize_and_fetch_db, initialize_supabase_session
from run_experimental_pipeline import reset_question_vector, reset_doc, run_data_sync_process
import random
import supabase
import timeit
import gc

def scan_for_submodels():
    supabase_client: supabase   = initialize_supabase_session()
    db                          = initialize_and_fetch_db(
        # Easy way to clear existing docs and vectors for recalculation
        reset_question_vector=reset_question_vector,
        reset_doc=reset_doc
        )
    
    run_data_sync_process(supabase_client = supabase_client,
                          db = db)

    df = pre_process_training_data()
    print("Data has been pre-processed")
    X_train, X_test, y_train, y_test = train_test_split(df)
    print("Train Test Split has been completed")
    # get a list of all the feature names
    all_features = collect_feature_list(df)
    # Shuffle the features based on seed:
    random.shuffle(all_features)
    completeness_threshold = 0.85

    sub_model_train_times = []
    all_sub_models = []

    # Track comp-scores for sub-models for reporting
    sub_model_results = []  # list of maps {"composite_score": val, "feature_list": s}

    # When new models are trained, we generate a new unique id, this id will go into our model directory in a unique directory to house all the model files and results
    ###########################
    # PRE-DEFINED HAND-PICKED FEATURE SUBSETS
    ###########################
    # Define hand-picked feature subsets (2D array)
    # These are feature sets chosen based on domain knowledge or previous experiments
    # Note: Subsets can be of any size, not limited to subset_size
    hand_picked_subsets = [
        # The question performance metrics
        ['avg_react_time', 'was_first_attempt', 'total_correct_attempts', 'total_incorrect_attempts', 'total_attempts', 'accuracy_rate', 'revision_streak', 'days_since_last_revision', 'days_since_first_introduced', 'attempt_day_ratio'],
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
        sub_model_results = []
        gc.collect()
    
    print(f"\nFinished training {len(hand_picked_subsets)} hand-picked subsets")
    print("=" * 80)
    print("STARTING INFINITE LOOP FOR RANDOM FEATURE SUBSET EXPLORATION")
    print("=" * 80)
    print("Press Ctrl+C to stop the infinite loop")
    print("=" * 80)

    # Define the fixed subset sizes to choose from
    subset_sizes = [10, 15, 20, 25, 30]
    
    # Counter for iterations
    iteration = 0
    
    # INFINITE LOOP - runs until manually terminated
    while True:
        iteration += 1

        current_feature = random.choice(all_features)
        subset_size = random.choice(subset_sizes)
        
        print(f"\n{'='*60}")
        print(f"Iteration {iteration}")
        print(f"Current feature: {current_feature}")
        print(f"Subset size: {subset_size}")
        print(f"{'='*60}")
        
        start = timeit.default_timer()
        
        # Select n=1 random feature subset that includes current_feature
        subsets = select_random_feature_subsets(
            current_feature         = current_feature, 
            n                       = 1,  # Only 1 subset per iteration
            all_features            = all_features, 
            X_train                 = X_train, 
            completeness_threshold  = completeness_threshold, 
            subset_size             = subset_size
        )
        
        if not subsets:
            print(f"WARNING: No valid subsets found for feature {current_feature} with size {subset_size}")
            continue
        
        # We get exactly 1 subset (since n=1)
        s = subsets[0]
        
        print(f"Selected subset of {len(s)} features (includes {current_feature})")
        print(f"Features: {s}")
        
        # Get data for this subset
        df = get_candidate_subset_records(
            subset_features = s,
            X_train         = X_train,
            y_train         = y_train
        )
        
        if df.empty:
            print(f"WARNING: No complete records for subset. Skipping iteration.")
            continue
        
        # Train our sub-model
        sub_model = train_sub_model(
            df                  = df,
            feature_subset      = s,
            X_test              = X_test,
            y_test              = y_test,
            n_num_grid_search   = 1
        )
        
        all_sub_models.append(sub_model)
        end = timeit.default_timer()
        train_time = end - start
        
        print(f"Sub-Model took {train_time:.2f} seconds to train")
        print(f"Sub-Model composite score: {sub_model['best_score']:.4f}")
        
        # Record results
        sub_model_results.append({
            "composite_score": sub_model['best_score'], 
            "feature_list": s, 
            "hyperparams": sub_model['best_params'],
            "subset_size": subset_size,
            "anchor_feature": current_feature
        })
        
        sub_model_train_times.append(train_time)
        
        # Report results
        report_sub_model_results(sub_model_results)
        
        # Perform garbage collection and reset lists
        gc.collect()
        sub_model_results = []

if __name__ == "__main__":
    scan_for_submodels()