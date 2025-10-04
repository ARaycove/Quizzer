import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from sync_fetch_data import initialize_and_fetch_db
from sklearn.preprocessing import OneHotEncoder
import pandas as pd
import json
from typing import List, Dict, Any
from imblearn.over_sampling import SMOTE
import numpy as np
import tensorflow as tf
from datetime import datetime, timezone
from sync_fetch_data import initialize_supabase_session

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
    
    # unpack user_stats_vector
    processed_df = flatten_user_stats_vector(processed_df, "user_stats")

    # unpack user_stats_revision_streak_sum
    processed_df = flatten_revision_streak_sum(processed_df, "rs")

    # unpack module_performance_vector
    processed_df = flatten_module_performance_vector(processed_df, "mvec")

    # unpack user_profile_record
    processed_df = flatten_user_profile_record(processed_df, "up")

    # unpack question_vector
    processed_df = flatten_question_vector(processed_df, "qv")
    
    # Drop additional unwanted columns after unpacking
    additional_drops = [
        "user_stats_user_id", "user_stats_record_date", 
        "user_stats_last_modified_timestamp", "up_birth_date",
        "user_stats_has_been_synced", "user_stats_edits_are_synced",
        "module_name_bio 160", # bio 160, was misnamed, a course title, not even a subject category, this vector get's stripped
        "mvec_bio 160_num_fitb", "mvec_bio 160_num_total",  "mvec_bio 160_overall_accuracy",
        "mvec_bio 160_num_mcq", "mvec_bio 160_num_mcq", "mvec_bio 160_num_tf", "mvec_bio 160_days_since_last_seen",
        "mvec_bio 160_total_attempts", "mvec_bio 160_total_correct_attempts", "mvec_bio 160_total_incorrect_attempts",
        "mvec_bio 160_total_seen","mvec_bio 160_avg_attempts_per_question", "mvec_bio 160_avg_reaction_time",
        "mvec_bio 160_percentage_seen",
        
        "module_name_chemistry and strcutural biology", # Typo module name get's stripped (just noise)
        "mvec_chemistry and strcutural biology_days_since_last_seen",
         
         
        "module_name_math", # Generic math module, noisy, serves as a catch all for unclassified math shit
        "mvec_math_num_fitb", "mvec_math_num_mcq", "mvec_math_num_total", "mvec_math_total_attempts",
        "mvec_math_total_correct_attempts", "mvec_math_total_incorrect_attempts", "mvec_math_total_seen",
        "mvec_math_avg_attempts_per_question", "mvec_math_avg_reaction_time", "mvec_math_days_since_last_seen",
        "mvec_math_overall_accuracy", "mvec_math_percentage_seen"

        

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
    Handles null values by filling all NaN values with 0.
    
    Args:
        df: DataFrame with flattened features
        
    Returns:
        DataFrame with all nulls filled with 0
    """
    df = df.copy()
    df = df.fillna(0)
    print("Filled all NaN values with 0")
    return df

def oneHotEncodeDataframe(df: pd.DataFrame) -> pd.DataFrame:
    """
    One-hot encodes categorical columns, handling nulls as separate categories.
    For user profile fields, fills nulls with 'unknown' before encoding to 
    create clean category names instead of 'nan'.
    
    Args:
        df: DataFrame with categorical features to encode
        
    Returns:
        DataFrame with categorical features one-hot encoded
    """
    df = df.copy()
    
    # Find categorical columns
    categorical_cols = [col for col in df.columns if df[col].dtype == 'object']
    
    print(f"Found {len(categorical_cols)} categorical columns to encode: {categorical_cols}")
    
    if not categorical_cols:
        return df
    
    # Fill nulls in user profile columns with 'unknown' for cleaner encoding
    for col in categorical_cols:
        if col.startswith('up_'):
            df[col] = df[col].fillna('unknown')
    
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
    from sklearn.model_selection import train_test_split
    
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
    print("Original class distribution:")
    for class_val, count in original_counts.items():
        print(f"  Class {class_val}: {count} samples ({count/len(y_train)*100:.1f}%)")
    
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
    print("\nBalanced class distribution:")
    for class_val, count in balanced_counts.items():
        print(f"  Class {class_val}: {count} samples ({count/len(y_train_balanced)*100:.1f}%)")
    
    print(f"\nSMOTE complete: {len(X_train)} → {len(X_train_balanced)} samples")
    
    return X_train_balanced, y_train_balanced

def load_model_and_transform_test_data(model_path='global_best_model.tflite', 
                                       feature_map_path='input_feature_map.json',
                                       X_test=None):
    """
    Load saved .tflite model and transform X_test into proper vector format.
    
    Args:
        model_path: Path to saved .tflite model file
        feature_map_path: Path to saved feature map JSON
        X_test: Test data DataFrame to transform
        
    Returns:
        Tuple of (interpreter, X_test_transformed)
    """
    # Load the TFLite model
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    
    # Load feature map
    with open(feature_map_path, 'r') as f:
        feature_map = json.load(f)
    
    # Get expected feature order from feature map
    expected_features = sorted(feature_map.items(), key=lambda x: x[1]['pos'])
    feature_order = [feat[0] for feat in expected_features]
    n_features = len(feature_order)
    
    # Transform X_test to match expected feature order and fill missing features
    X_test_transformed = np.zeros((len(X_test), n_features))
    
    for feature_name, feature_info in feature_map.items():
        pos = feature_info['pos']
        default_value = feature_info['default_value']
        
        if feature_name in X_test.columns:
            X_test_transformed[:, pos] = X_test[feature_name].fillna(default_value).values
        else:
            X_test_transformed[:, pos] = default_value
    
    # Convert back to DataFrame with proper column names and preserve original index
    X_test_transformed = pd.DataFrame(X_test_transformed, columns=feature_order, index=X_test.index)
    
    print(f"Model loaded from: {model_path}")
    print(f"Feature map loaded from: {feature_map_path}")
    print(f"Transformed test data shape: {X_test_transformed.shape}")
    print(f"Expected features: {n_features}")
    
    return interpreter, X_test_transformed


def push_model_to_supabase(model_name, metrics, model_path='global_best_model.tflite', 
                          feature_map_path='input_feature_map.json'):
    """
    Upload TFLite model to Supabase storage and update ml_models table.
    
    Args:
        model_name: Name for the model (used as primary key)
        metrics: Metrics dictionary from model_analytics_report()
        model_path: Path to .tflite model file
        feature_map_path: Path to feature map JSON
        
    Returns:
        Response from database insert/update
    """
    # Calculate optimal threshold from ROC curve (maximize Youden's J statistic)
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
    
    # Read feature map
    with open(feature_map_path, 'r') as f:
        feature_map = json.load(f)
    
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