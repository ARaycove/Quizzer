import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from utility.sync_fetch_data import initialize_and_fetch_db
from sklearn.preprocessing import OneHotEncoder
import pandas as pd
import json
from typing import List, Dict, Any
from imblearn.over_sampling import SMOTE
import numpy as np
import tensorflow as tf
from datetime import datetime, timezone
from utility.sync_fetch_data import initialize_supabase_session
from sklearn.model_selection import train_test_split

def get_attempt_dataframe() -> pd.DataFrame:
    """
    Reads all records from the question_answer_attempts table and returns as a pandas DataFrame.
    Before querying, updates question_vectors in attempts table to match current vectors 
    from question_answer_pairs table to ensure consistency.
    
    Returns:
        A pandas DataFrame containing all records from the question_answer_attempts table.
    """
    db = initialize_and_fetch_db()
    
    print("Database connection info:", db)
    
    # Try to get the database file path if it's sqlite3
    try:
        cursor = db.cursor()
        cursor.execute("PRAGMA database_list")
        db_info = cursor.fetchall()
        print("Database file paths:", db_info)
    except:
        pass
    
    # Update question_vectors in attempts table from pairs table
    print("Updating question_vectors in attempts table...")
    cursor = db.cursor()
    
    # Get count of records that need updating
    cursor.execute("""
        SELECT COUNT(*) 
        FROM question_answer_attempts qa
        INNER JOIN question_answer_pairs qp ON qa.question_id = qp.question_id
        WHERE qa.question_vector != qp.question_vector OR qa.question_vector IS NULL
    """)
    update_count = cursor.fetchone()[0]
    print(f"Found {update_count} records with outdated question_vectors")
    
    if update_count > 0:
        # Update the question_vectors
        cursor.execute("""
            UPDATE question_answer_attempts 
            SET question_vector = (
                SELECT question_vector 
                FROM question_answer_pairs 
                WHERE question_answer_pairs.question_id = question_answer_attempts.question_id
            )
            WHERE question_id IN (
                SELECT question_id FROM question_answer_pairs 
                WHERE question_answer_pairs.question_vector IS NOT NULL
            )
        """)
        
        db.commit()
        print(f"Updated {cursor.rowcount} question_vectors in attempts table")
    else:
        print("All question_vectors are already up to date")
    
    # Now query the updated table
    query = "SELECT * FROM question_answer_attempts"
    df = pd.read_sql_query(query, db)
    
    print("Raw dataframe shape:", df.shape)
    
    # Verify question_vector consistency
    if 'question_vector' in df.columns:
        vector_lengths = df['question_vector'].apply(
            lambda x: len(json.loads(x)) if isinstance(x, str) and x.strip() else 0
        )
        unique_lengths = vector_lengths.unique()
        print(f"Question vector lengths found: {sorted(unique_lengths)}")
        
        if len(unique_lengths) > 1:
            print("WARNING: Multiple question vector lengths detected!")
            for length in sorted(unique_lengths):
                count = (vector_lengths == length).sum()
                print(f"  Length {length}: {count} records")
    
    db.close()
    return df

def flatten_attempts_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """
    Unpacks and cleans the question_answer_attempts DataFrame.
    Handles JSON string fields properly using pandas json_normalize.
    
    Args:
        df: Raw DataFrame from question_answer_attempts table
        
    Returns:
        Flattened DataFrame with unpacked features and bad columns removed
    """
    processed_df = df.copy()
    
    # Drop unwanted columns first
    columns_to_drop = [
        "time_stamp", "question_id", "participant_id", 
        "last_revised_date", "time_of_presentation"
    ]
    
    processed_df = processed_df.drop(columns=[col for col in columns_to_drop if col in processed_df.columns])
    
    if 'module_performance_vector' in processed_df.columns:
        processed_df = processed_df.drop(columns=['module_performance_vector'])
        print("Dropped 'module_performance_vector' column")

    # unpack user_stats_vector
    processed_df = flatten_user_stats_vector(processed_df, "user_stats")

    # unpack user_stats_revision_streak_sum
    processed_df = flatten_revision_streak_sum(processed_df, "rs")

    # unpack module_performance_vector -> moving to topic model, omitted for now #FIXME
    # processed_df = flatten_module_performance_vector(processed_df, "mvec")

    # unpack user_profile_record
    processed_df = flatten_user_profile_record(processed_df, "up")

    # unpack question_vector
    processed_df = flatten_question_vector(processed_df, "qv")

    # unpack knn_performance_vector
    processed_df = flatten_knn_performance_vector(processed_df, "knn")

    # Drop additional unwanted columns after unpacking
    additional_drops = [
        "user_stats_user_id", "user_stats_record_date", 
        "user_stats_last_modified_timestamp", "up_birth_date",
        "user_stats_has_been_synced", "user_stats_edits_are_synced",

        # Noisy Stats, not really related to accuracy
        "user_stats_total_non_circ_questions", "user_stats_total_in_circ_questions", "user_stats_total_eligible_questions",
    ]
    processed_df = processed_df.drop(columns=[col for col in additional_drops if col in processed_df.columns])
    
    return processed_df

def flatten_user_stats_vector(df: pd.DataFrame, prefix: str) -> pd.DataFrame:
    if 'user_stats_vector' not in df.columns:
        return df
    
    # Parse JSON strings and normalize in one step
    parsed_series = df['user_stats_vector'].apply(lambda x: json.loads(x) if isinstance(x, str) else x)
    flattened_df = pd.json_normalize(parsed_series).add_prefix(f"{prefix}_")
    
    return pd.concat([
        df.drop(columns=['user_stats_vector']).reset_index(drop=True), 
        flattened_df.reset_index(drop=True)
    ], axis=1)

def flatten_revision_streak_sum(df: pd.DataFrame, prefix: str) -> pd.DataFrame:
    if 'user_stats_revision_streak_sum' not in df.columns:
        return df
    
    # Parse JSON array and create columns for each revision_streak value
    parsed_series = df['user_stats_revision_streak_sum'].apply(lambda x: json.loads(x) if isinstance(x, str) else x)
    
    # Get all unique revision_streak values across all rows
    all_streaks = set()
    for streak_list in parsed_series:
        if isinstance(streak_list, list):
            for item in streak_list:
                if isinstance(item, dict) and 'revision_streak' in item:
                    all_streaks.add(item['revision_streak'])
    
    # Create columns for each streak value
    streak_data = []
    for streak_list in parsed_series:
        row_data = {}
        if isinstance(streak_list, list):
            for item in streak_list:
                if isinstance(item, dict) and 'revision_streak' in item and 'count' in item:
                    streak_key = f"{prefix}_{item['revision_streak']}"
                    row_data[streak_key] = item['count']
        
        # Fill missing streaks with 0
        for streak in all_streaks:
            streak_key = f"{prefix}_{streak}"
            if streak_key not in row_data:
                row_data[streak_key] = 0
        
        streak_data.append(row_data)
    
    flattened_df = pd.DataFrame(streak_data)
    
    return pd.concat([
        df.drop(columns=['user_stats_revision_streak_sum']).reset_index(drop=True), 
        flattened_df.reset_index(drop=True)
    ], axis=1)


def flatten_module_performance_vector(df: pd.DataFrame, prefix: str) -> pd.DataFrame:
    if 'module_performance_vector' not in df.columns:
        return df
    
    # Modules to exclude from unpacking
    excluded_modules = [
        "dummy module","multi field test","new module name", "test module",
        "test module 1", "test module 10", "test module 2", "test module 3",
        "test module 4", "test module 5", "test module 6", "test module 7",
        "test module 8", "test module 9", "test module with underscores",
        "testmodule", "testmodule0", "testmodule1", "testmodule2", "testmodule3",
        "testmodule4", "algebra 1-3", "algebra & trigonometry", "testmodule0 edited"
    ]
    
    # Parse JSON array and create columns for each module
    parsed_series = df['module_performance_vector'].apply(lambda x: json.loads(x) if isinstance(x, str) else x)
    
    # Get all unique module names and their fields, excluding specified modules
    all_modules = set()
    all_fields = set()
    for module_list in parsed_series:
        if isinstance(module_list, list):
            for module in module_list:
                if isinstance(module, dict) and 'module_name' in module:
                    module_name = module['module_name']
                    if module_name not in excluded_modules:
                        all_modules.add(module_name)
                        for field in module.keys():
                            if field != 'module_name':
                                all_fields.add(field)
    
    # Create columns for each module-field combination
    module_data = []
    for module_list in parsed_series:
        row_data = {}
        if isinstance(module_list, list):
            for module in module_list:
                if isinstance(module, dict) and 'module_name' in module:
                    module_name = module['module_name']
                    if module_name not in excluded_modules:
                        for field in all_fields:
                            col_name = f"{prefix}_{module_name}_{field}"
                            row_data[col_name] = module.get(field, 0)
        
        # Fill missing module-field combinations with 0
        for module_name in all_modules:
            for field in all_fields:
                col_name = f"{prefix}_{module_name}_{field}"
                if col_name not in row_data:
                    row_data[col_name] = 0
        
        module_data.append(row_data)
    
    flattened_df = pd.DataFrame(module_data)
    
    return pd.concat([
        df.drop(columns=['module_performance_vector']).reset_index(drop=True), 
        flattened_df.reset_index(drop=True)
    ], axis=1)

def flatten_user_profile_record(df: pd.DataFrame, prefix: str) -> pd.DataFrame:
    if 'user_profile_record' not in df.columns:
        return df
    
    # Parse JSON strings and normalize in one step
    parsed_series = df['user_profile_record'].apply(lambda x: json.loads(x) if isinstance(x, str) else x)
    flattened_df = pd.json_normalize(parsed_series).add_prefix(f"{prefix}_")
    
    return pd.concat([
        df.drop(columns=['user_profile_record']).reset_index(drop=True), 
        flattened_df.reset_index(drop=True)
    ], axis=1)

def flatten_question_vector(df: pd.DataFrame, prefix: str) -> pd.DataFrame:
    if 'question_vector' not in df.columns:
        return df
    
    # Parse JSON arrays and create columns for each index
    parsed_series = df['question_vector'].apply(lambda x: json.loads(x) if isinstance(x, str) else x)
    
    # Get the maximum vector length across all rows
    max_length = 0
    for vector in parsed_series:
        if isinstance(vector, list):
            max_length = max(max_length, len(vector))
    
    # Create columns for each vector index
    vector_data = []
    for vector in parsed_series:
        row_data = {}
        if isinstance(vector, list):
            for i in range(max_length):
                col_name = f"{prefix}_{i}"
                row_data[col_name] = vector[i] if i < len(vector) else 0
        else:
            # Fill with zeros if not a list
            for i in range(max_length):
                col_name = f"{prefix}_{i}"
                row_data[col_name] = 0
        
        vector_data.append(row_data)
    
    flattened_df = pd.DataFrame(vector_data)
    
    return pd.concat([
        df.drop(columns=['question_vector']).reset_index(drop=True), 
        flattened_df.reset_index(drop=True)
    ], axis=1)

def handle_nulls(df: pd.DataFrame) -> pd.DataFrame:
    """
    Handles null values by filling with specified defaults per field pattern.
    
    Args:
        df: DataFrame with flattened features
        
    Returns:
        DataFrame with all nulls filled according to default rules
    """
    df = df.copy()
    
    # Define default values for specific field patterns
    field_defaults = {
        '_was_first_attempt': 1,
    }
    
    # Apply pattern-based defaults
    for col in df.columns:
        default_value = 0  # Global default
        
        # Check if column matches any pattern
        for pattern, value in field_defaults.items():
            if pattern in col:
                default_value = value
                break
        
        # Fill nulls with determined default
        if df[col].isnull().any():
            df[col] = df[col].fillna(default_value)
    
    print(f"Filled NaN values with pattern-based defaults")
    print(f"  - Global default: 0")
    for pattern, value in field_defaults.items():
        affected_cols = [col for col in df.columns if pattern in col]
        if affected_cols:
            print(f"  - '{pattern}' fields: {value} ({len(affected_cols)} columns)")
    
    return df

def oneHotEncodeDataframe(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    
    # Find categorical columns
    categorical_cols = [col for col in df.columns if df[col].dtype == 'object']
    
    print(f"Found {len(categorical_cols)} categorical columns to encode: {categorical_cols}")
    
    if not categorical_cols:
        return df
    
    # Replace numeric values in categorical columns with NaN, then fill all NaN with 'missing'
    for col in categorical_cols:
        df[col] = df[col].apply(lambda x: np.nan if isinstance(x, (int, float)) else x)
        df[col] = df[col].fillna('missing')
    
    # One-hot encode
    encoder = OneHotEncoder(sparse_output=False, handle_unknown='ignore')
    encoded_array = encoder.fit_transform(df[categorical_cols])
    encoded_feature_names = encoder.get_feature_names_out(categorical_cols)
    
    # Replace categorical columns with encoded ones
    encoded_df = pd.DataFrame(encoded_array, columns=encoded_feature_names, index=df.index)
    result_df = pd.concat([df.drop(columns=categorical_cols), encoded_df], axis=1)
    
    print(f"One-hot encoding complete. Added {len(encoded_feature_names)} new columns")
    return result_df

def drop_zero_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Remove columns with zero variance (all values identical)."""
    zero_var_cols = df.columns[df.nunique() <= 1].tolist()
    if zero_var_cols:
        print(f"Dropped {len(zero_var_cols)} zero-variance columns")
    return df.drop(columns=zero_var_cols)

def cap_reaction_times(df: pd.DataFrame, method: str = 'iqr', factor: float = 1.5) -> pd.DataFrame:
    """
    Intelligently cap reaction times using statistical outlier detection.
    
    Args:
        df: DataFrame with reaction time features
        method: 'iqr', 'zscore', or 'percentile'
        factor: Multiplier for IQR method or threshold for z-score
    """
    df = df.copy()
    reaction_cols = [col for col in df.columns if 'reaction_time' in col or 'react_time' in col]
    
    print(f"Processing {len(reaction_cols)} reaction time columns...")
    
    for col in reaction_cols:
        if col not in df.columns:
            continue
            
        values = df[col].dropna()
        if len(values) == 0:
            continue
            
        original_max = values.max()
        original_mean = values.mean()
        original_std = values.std()
        
        if method == 'iqr':
            Q1 = values.quantile(0.25)
            Q3 = values.quantile(0.75)
            IQR = Q3 - Q1
            lower_bound = Q1 - factor * IQR
            upper_bound = Q3 + factor * IQR
            cap_value = upper_bound
            
        elif method == 'zscore':
            mean = values.mean()
            std = values.std()
            cap_value = mean + factor * std
            
        elif method == 'percentile':
            cap_value = values.quantile(0.95 + (factor - 1) * 0.04)  # 95th to 99th percentile
            
        # Ensure minimum cap of 60 seconds (reasonable upper bound)
        cap_value = max(cap_value, 60.0)
        
        # Apply cap
        outliers_count = (df[col] > cap_value).sum()
        df[col] = df[col].clip(upper=cap_value)
        
        new_max = df[col].max()
        print(f"{col}: {original_max:.1f}s → {new_max:.1f}s (capped {outliers_count} outliers)")
        
    return df

def train_test_split_extraction(df: pd.DataFrame, test_size: float = 0.2, random_state = 42) -> tuple:
    """
    Split DataFrame into train/test sets with feature/target separation.
    
    Args:
        df: DataFrame with features and response_result target
        test_size: Proportion of data for test set (default 0.2)
        
    Returns:
        Tuple of (X_train, X_test, y_train, y_test) DataFrames
    """
    # Separate features and target
    X = df.drop(columns=['response_result'])
    y = df['response_result']
    
    # Split the data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, 
        test_size=test_size, 
        random_state=random_state, 
        stratify=y  # Maintain class distribution in splits
    )
    
    print(f"Train set: {len(X_train)} samples")
    print(f"Test set: {len(X_test)} samples")
    print(f"Features: {len(X.columns)}")
    
    return X_train, X_test, y_train, y_test

def apply_smote_balancing(X_train: pd.DataFrame, y_train: pd.Series, 
                         sampling_strategy='auto', random_state=42, k_neighbors=5) -> tuple:
    """
    Apply SMOTE to balance class distribution in training data.
    
    Args:
        X_train: Training features DataFrame
        y_train: Training target Series
        sampling_strategy: Strategy for resampling ('auto', 'minority', dict, etc.)
        random_state: Random seed for reproducibility
        k_neighbors: Number of nearest neighbors for SMOTE
        
    Returns:
        Tuple of (X_train_balanced, y_train_balanced) with balanced classes
    """
    from imblearn.over_sampling import SMOTE
    import numpy as np
    
    # Check original class distribution
    original_counts = y_train.value_counts().sort_index()
    # print("Original class distribution:")
    # for class_val, count in original_counts.items():
    #     print(f"  Class {class_val}: {count} samples ({count/len(y_train)*100:.1f}%)")
    
    # Apply SMOTE with configurable parameters
    smote = SMOTE(
        sampling_strategy=sampling_strategy,
        random_state=random_state,
        k_neighbors=k_neighbors,
    )
    X_balanced, y_balanced = smote.fit_resample(X_train, y_train)
    
    # Convert back to pandas with original column names
    X_train_balanced = pd.DataFrame(X_balanced, columns=X_train.columns)
    y_train_balanced = pd.Series(y_balanced, name=y_train.name)
    
    # Check new class distribution
    balanced_counts = y_train_balanced.value_counts().sort_index()
    # print("\nBalanced class distribution:")
    # for class_val, count in balanced_counts.items():
    #     print(f"  Class {class_val}: {count} samples ({count/len(y_train_balanced)*100:.1f}%)")
    
    print(f"\nSMOTE complete: {len(X_train)} → {len(X_train_balanced)} samples")
    
    return X_train_balanced, y_train_balanced

def load_model_and_transform_test_data(X_train=None, X_test=None, y_train=None, y_test=None, model_path='global_best_model.tflite', feature_map_path='input_feature_map.json'):
    """
    Load saved .tflite model and transform X_test into proper vector format.
    If model doesn't exist, retrain from best params in top results.
    """
    
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    
    with open(feature_map_path, 'r') as f:
        feature_map = json.load(f)
    
    expected_features = sorted(feature_map.items(), key=lambda x: x[1]['pos'])
    feature_order = [feat[0] for feat in expected_features]
    n_features = len(feature_order)
    
    X_test_transformed = np.zeros((len(X_test), n_features))
    for feature_name, feature_info in feature_map.items():
        pos = feature_info['pos']
        default_value = feature_info['default_value']
        if feature_name in X_test.columns:
            X_test_transformed[:, pos] = X_test[feature_name].fillna(default_value).values
        else:
            X_test_transformed[:, pos] = default_value
    
    X_test_transformed = pd.DataFrame(X_test_transformed, columns=feature_order, index=X_test.index)
    return interpreter, X_test_transformed

def push_model_to_supabase(model_name, metrics, model_path='global_best_model.tflite', 
                          feature_map_path='input_feature_map.json'):
    """
    Upload TFLite model to Supabase storage and update ml_models table.
    VALIDATES that model input shape matches feature map count.
    """
    # Load and validate model input shape
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    model_input_shape = input_details[0]['shape'][1]  # [batch, features] -> get features
    
    # Load feature map
    with open(feature_map_path, 'r') as f:
        feature_map = json.load(f)
    
    feature_map_count = len(feature_map)
    
    # VALIDATION
    if model_input_shape != feature_map_count:
        raise ValueError(
            f"MODEL MISMATCH: Model expects {model_input_shape} features "
            f"but feature_map has {feature_map_count} features. "
        )
    
    print(f"✓ Validation passed: Model and feature map both have {model_input_shape} features")
    
    # Calculate optimal threshold
    fpr = metrics['roc_fpr']
    tpr = metrics['roc_tpr']
    thresholds = metrics['roc_thresholds']
    j_scores = tpr - fpr
    optimal_idx = np.argmax(j_scores)
    optimal_threshold = float(thresholds[optimal_idx])
    
    print(f"Calculated optimal threshold: {optimal_threshold:.4f}")
    
    supabase_client = initialize_supabase_session()
    
    if not supabase_client:
        print("Error: Could not initialize Supabase session")
        return None
    
    # Authenticate
    try:
        auth_response = supabase_client.auth.sign_in_with_password({
            "email": "aacra0820@gmail.com",
            "password": "Starting11Over!"
        })
        print("Successfully authenticated with Supabase")
    except Exception as e:
        print(f"Error authenticating with Supabase: {e}")
        return None
    
    # Upload to storage bucket
    filename = f"{model_name}.tflite"
    try:
        with open(model_path, 'rb') as f:
            supabase_client.storage.from_('ml_models').upload(filename, f, {'content-type': 'application/octet-stream', 'upsert': 'true'})
        print(f"Model uploaded to storage: ml_models/{filename}")
    except Exception as e:
        print(f"Error uploading model to storage: {e}")
        return None
    
    # Prepare data for table
    timestamp = datetime.now(timezone.utc).isoformat()
    
    data = {
        'model_name': model_name,
        'input_features': json.dumps(feature_map),
        'model_json': filename,
        'last_modified_timestamp': timestamp,
        'optimal_threshold': optimal_threshold
    }
    
    # Upsert to table
    try:
        response = supabase_client.table('ml_models').upsert(data).execute()
        print(f"Database record updated: {model_name}")
        print(f"Timestamp: {timestamp}")
        return response
    except Exception as e:
        print(f"Error updating database: {e}")
        return None
    
def flatten_knn_performance_vector(df: pd.DataFrame, prefix: str) -> pd.DataFrame:
    if 'knn_performance_vector' not in df.columns:
        return df
    
    # Fields to exclude from unpacking
    excluded_fields = {'time_of_presentation', 'last_revised_date'}
    
    parsed_series = df['knn_performance_vector'].apply(lambda x: json.loads(x) if isinstance(x, str) else x)
    
    max_neighbors = 0
    all_fields = set()
    for knn_list in parsed_series:
        if isinstance(knn_list, list):
            max_neighbors = max(max_neighbors, len(knn_list))
            for neighbor in knn_list:
                if isinstance(neighbor, dict):
                    all_fields.update(neighbor.keys())
    
    # Remove excluded fields
    all_fields = all_fields - excluded_fields
    
    knn_data = []
    for knn_list in parsed_series:
        row_data = {}
        
        # Add is_missing flag for entire vector
        if knn_list is None or not isinstance(knn_list, list) or len(knn_list) == 0:
            row_data[f"{prefix}_vector_is_missing"] = 1
        else:
            row_data[f"{prefix}_vector_is_missing"] = 0
        
        if isinstance(knn_list, list):
            for i, neighbor in enumerate(knn_list):
                neighbor_num = str(i + 1).zfill(2)
                if isinstance(neighbor, dict):
                    for field in all_fields:
                        value = neighbor.get(field, 0)
                        # Convert booleans to integers
                        if isinstance(value, bool):
                            value = 1 if value else 0
                        row_data[f"{prefix}_{neighbor_num}_{field}"] = value
        
        for i in range(max_neighbors):
            neighbor_num = str(i + 1).zfill(2)
            for field in all_fields:
                col_name = f"{prefix}_{neighbor_num}_{field}"
                if col_name not in row_data:
                    row_data[col_name] = 0
        
        knn_data.append(row_data)
    
    flattened_df = pd.DataFrame(knn_data)
    
    return pd.concat([
        df.drop(columns=['knn_performance_vector']).reset_index(drop=True), 
        flattened_df.reset_index(drop=True)
    ], axis=1)

def drop_features(df, features_to_drop=None, prefixes_to_drop=None):
    """
    Drop specified features from dataframe.
    
    Args:
        df: pandas DataFrame
        features_to_drop: list of column names to drop (default: empty list)
        prefixes_to_drop: list of prefixes - drops all columns starting with these (default: empty list)
    
    Returns:
        DataFrame with specified features removed
    """
    if features_to_drop is None:
        features_to_drop = []
    if prefixes_to_drop is None:
        prefixes_to_drop = []
    
    # Drop exact column names
    df = df.drop(columns=features_to_drop, errors='ignore')
    
    # Drop columns with specified prefixes
    for prefix in prefixes_to_drop:
        cols_to_drop = [col for col in df.columns if col.startswith(prefix)]
        df = df.drop(columns=cols_to_drop, errors='ignore')
    
    return df