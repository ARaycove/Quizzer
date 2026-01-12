from sklearn.model_selection import train_test_split as sk_train_test_split
from neural_net.attempt_pre_process import apply_smote_balancing
from sync_fetch_data import initialize_and_fetch_db
import pandas as pd
import numpy as np
#######################################
# Helper functions for Phase 2:
def find_best_subset_to_train(top_n: int = 100, top_k: int = 1000, top_n_perc: float = 0.5) -> dict:
    """
    Find the best sub-model feature set to train next based on balancing
    grid search effort between top-ranked combinations.
    
    Args:
        top_n: Top N combinations that get priority (default: 100)
        top_k: Total records to consider from the top (default: 1000)
        top_n_perc: Percentage of grid searches for top_n group (default: 0.5 = 50%)
    
    Returns:
        Dictionary containing the sub-model record to train next
    """
    db_conn = initialize_and_fetch_db()
    cursor = db_conn.cursor()
    
    # Get only necessary columns for ranking
    cursor.execute('''
    SELECT 
        feature_set,
        composite_score,
        num_grid_searches_performed
    FROM sub_model_results 
    ORDER BY composite_score DESC
    LIMIT ?
    ''', (top_k,))
    
    all_records = cursor.fetchall()
    
    if not all_records:
        db_conn.close()
        return None
    
    # Track group statistics
    group_top_n = []
    group_rest = []
    total_grid_searches = 0
    
    # Process records and group them
    for rank, (feature_set, composite_score, num_searches) in enumerate(all_records, 1):
        record = {
            'rank': rank,
            'feature_set': feature_set,
            'composite_score': composite_score,
            'num_grid_searches_performed': num_searches
        }
        
        total_grid_searches += num_searches
        
        if rank <= top_n:
            group_top_n.append(record)
        else:
            group_rest.append(record)
    
    # Determine target group based on current distribution
    if total_grid_searches == 0:
        # First run - pick highest rank
        target_record = group_top_n[0] if group_top_n else group_rest[0]
    else:
        top_n_searches = sum(r['num_grid_searches_performed'] for r in group_top_n)
        top_n_current_perc = top_n_searches / total_grid_searches
        
        if top_n_current_perc < top_n_perc:
            # Top N needs more searches - pick from top N with fewest searches
            target_record = min(group_top_n, key=lambda x: x['num_grid_searches_performed'])
        else:
            # Rest needs more searches - pick from rest with fewest searches
            target_record = min(group_rest, key=lambda x: x['num_grid_searches_performed'])
    
    # Now get full record for selected feature_set
    cursor.execute('''
    SELECT *
    FROM sub_model_results 
    WHERE feature_set = ?
    ''', (target_record['feature_set'],))
    
    row = cursor.fetchone()
    column_names = [description[0] for description in cursor.description]
    
    db_conn.close()
    
    # Convert to dictionary
    full_record = dict(zip(column_names, row))
    
    print(f"Selected rank {target_record['rank']} for training")
    print(f"Grid searches so far: {target_record['num_grid_searches_performed']}")
    print(f"Group: {'top_n' if target_record['rank'] <= top_n else 'rest'}")
    
    return full_record
#######################################
def get_candidate_subset_records(subset_features, X_train, y_train):
    """
    Extract records from X_train and y_train that have complete data for the specified subset of features.
    Applies SMOTE balancing to the complete records.
    
    Args:
        subset_features: List of feature names to include in the subset
        X_train: Training feature DataFrame
        y_train: Training target Series
        
    Returns:
        DataFrame containing the specified features and target column, with only rows that have no missing values
        and balanced via SMOTE
    """
    # Check that all subset features exist in X_train
    missing_features = [f for f in subset_features if f not in X_train.columns]
    if missing_features:
        raise ValueError(f"Features not found in X_train: {missing_features}")
    
    # Select only the subset features from X_train
    subset_data = X_train[subset_features].copy()
    
    # Add target column
    subset_data = pd.concat([subset_data, y_train], axis=1)
    
    # Drop rows with any missing values in these features (including target)
    complete_data = subset_data.dropna()
    
    # Report statistics
    total_rows = len(subset_data)
    complete_rows = len(complete_data)
    completeness_ratio = complete_rows / total_rows if total_rows > 0 else 0
    
    print(f"Subset: {len(subset_features)} features, {complete_rows}/{total_rows} complete rows ({completeness_ratio:.1%})")
    
    if complete_rows == 0:
        print(f"Warning: No complete records for subset: {subset_features}")
        return pd.DataFrame()
    
    # Apply SMOTE balancing to complete records
    print("Applying SMOTE balancing to complete records...")
    X_complete = complete_data.drop(columns=['response_result'])
    y_complete = complete_data['response_result']
    
    # Apply SMOTE
    X_balanced, y_balanced = apply_smote_balancing(
        X_complete, y_complete,
        sampling_strategy='auto',
        random_state=42,
        k_neighbors=5
    )
    
    # Combine back into DataFrame
    balanced_data = pd.concat([X_balanced, y_balanced], axis=1)
    
    # Report SMOTE results
    print(f"SMOTE: {complete_rows} → {len(balanced_data)} samples (added {len(balanced_data) - complete_rows} synthetic samples)")
    
    # Show class distribution
    class_counts = y_balanced.value_counts()
    for class_val, count in class_counts.items():
        print(f"  Class {class_val}: {count} samples ({count/len(y_balanced)*100:.1f}%)")
    
    return balanced_data

def select_random_feature_subsets(current_feature, n, all_features, X_train, completeness_threshold=0.9, subset_size=15):
    """
    Returns EXACTLY N subsets of EXACTLY size subset_size.
    Builds subsets incrementally by adding one feature at a time.
    If a feature results in insufficient data, skip that feature and try another.
    
    Args:
        current_feature: Starting feature that must be in all subsets
        n: Number of subsets to return (N)
        all_features: List of all available features
        X_train: Training data DataFrame
        completeness_threshold: Minimum data completeness required (default 0.9)
        subset_size: Exact size of each subset (default 15)
    
    Returns:
        List of N feature subsets, each of exactly subset_size
    """
    subsets = []
    
    for i in range(n):
        print(f"\nBuilding subset {i+1}/{n}")
        selected_features = [current_feature]
        remaining_features = [f for f in all_features if f != current_feature]
        
        while len(selected_features) < subset_size and remaining_features:
            # Try features one by one
            found_valid_feature = False
            
            # Randomize order to get different subsets
            np.random.shuffle(remaining_features)
            
            for feature in list(remaining_features):
                # Check if adding this feature maintains data completeness
                test_features = selected_features + [feature]
                
                # Calculate completeness for these features
                complete_rows = X_train[test_features].dropna()
                completeness = len(complete_rows) / len(X_train)
                
                print(f"  Trying feature '{feature}': completeness = {completeness:.4f} (threshold: {completeness_threshold})")
                
                if completeness >= completeness_threshold:
                    # Feature is valid - add it
                    selected_features.append(feature)
                    remaining_features.remove(feature)
                    found_valid_feature = True
                    print(f"  ✓ Added feature '{feature}' to subset {i+1}")
                    print(f"  Current subset size: {len(selected_features)}/{subset_size}")
                    break
                else:
                    print(f"  ✗ Skipping feature '{feature}' (insufficient data)")
            
            if not found_valid_feature:
                # No remaining feature can maintain completeness
                print(f"  WARNING: No valid feature found to maintain completeness threshold. Stopping subset construction.")
                print(f"  WARNING: Subset {i+1} will have only {len(selected_features)} features instead of {subset_size}")
                break
        
        # Print final subset composition
        print(f"Subset {i+1} complete: {len(selected_features)} features")
        print(f"Features in subset {i+1}: {selected_features}")
        
        subsets.append(selected_features)
    
    return subsets

def collect_feature_list(df):
    """
    Collects a list of all feature names from the dataframe, excluding the target column.
    
    Args:
        df: DataFrame containing features and target column 'response_result'
        
    Returns:
        List of feature names (all columns except 'response_result')
    """
    # Ensure the target column exists
    if 'response_result' not in df.columns:
        raise ValueError("DataFrame must contain 'response_result' column")
    
    # Get all column names except the target
    features = [col for col in df.columns if col != 'response_result']
    
    print(f"Collected {len(features)} features from dataset")
    print(f"Target column excluded: 'response_result'")
    
    return features

def train_test_split(df, test_size=0.2, random_state=42):
    """
    Splits data into train and test sets, ensuring the test set has no missing values.
    
    Args:
        df: DataFrame containing features and 'response_result' target column
        test_size: Proportion of complete cases to use for test set (default 0.2)
        random_state: Random seed for reproducibility (default 42)
        
    Returns:
        X_train, X_test, y_train, y_test DataFrames/Series
    """
    
    # Separate features and target
    X = df.drop(columns=['response_result'])
    y = df['response_result']
    
    # Find complete cases (no missing values in any feature)
    complete_mask = X.notnull().all(axis=1)
    complete_cases = X[complete_mask]
    complete_targets = y[complete_mask]
    
    if len(complete_cases) == 0:
        raise ValueError("No complete cases found in dataset for test set")
    
    total_samples = len(df)
    complete_samples = len(complete_cases)
    incomplete_samples = total_samples - complete_samples
    
    print(f"Total samples: {total_samples}")
    print(f"Complete cases (no missing values): {complete_samples} ({complete_samples/total_samples*100:.1f}%)")
    print(f"Incomplete cases: {incomplete_samples}")
    
    # Split complete cases into test and train-complete
    X_train_complete, X_test, y_train_complete, y_test = sk_train_test_split(
        complete_cases, 
        complete_targets,
        test_size=test_size,
        random_state=random_state,
        stratify=complete_targets
    )
    
    # Get incomplete cases for training
    incomplete_mask = ~complete_mask
    X_train_incomplete = X[incomplete_mask]
    y_train_incomplete = y[incomplete_mask]
    
    # Combine complete training cases with incomplete cases
    X_train = pd.concat([X_train_complete, X_train_incomplete], axis=0)
    y_train = pd.concat([y_train_complete, y_train_incomplete], axis=0)
    
    # Shuffle the combined training set
    train_indices = np.random.permutation(X_train.index)
    X_train = X_train.loc[train_indices]
    y_train = y_train.loc[train_indices]
    
    print(f"\nSplit Summary:")
    print(f"  - Test set (complete cases only): {len(X_test)} samples ({len(X_test)/total_samples*100:.1f}%)")
    print(f"  - Train set: {len(X_train)} samples ({len(X_train)/total_samples*100:.1f}%)")
    print(f"    • Complete cases in train: {len(X_train_complete)} ({len(X_train_complete)/len(X_train)*100:.1f}% of train)")
    print(f"    • Incomplete cases in train: {len(X_train_incomplete)} ({len(X_train_incomplete)/len(X_train)*100:.1f}% of train)")
    
    # Verify test set has no missing values
    if X_test.isnull().any().any():
        print("WARNING: Test set contains missing values!")
    else:
        print("✓ Test set has no missing values")
    
    return X_train, X_test, y_train, y_test