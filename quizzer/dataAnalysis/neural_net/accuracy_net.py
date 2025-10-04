import neural_net.attempt_pre_process as ap
from neural_net.grid_search import grid_search_quizzer_model
import os
import neural_net.reports as rp
import numpy as np
import tensorflow as tf
import random



def pre_process_training_data():
    # Get our unprocessed table and load into a dataframe
    df = ap.get_attempt_dataframe()

    # Unpack embedded features
    df = ap.flatten_attempts_dataframe(df)

    # Impute and handle missing values (nulls)
    df = ap.handle_nulls(df)

    # One Hot Encode now
    df = ap.oneHotEncodeDataframe(df)

    # Cap reaction times (these have been shown as extreme)
    df = ap.cap_reaction_times(df)

    # Drop all 0 columns:
    df = ap.drop_zero_columns(df)

    # Save the feature names we kept, for use in ml_models_table.dart

    # Run initial reporting and analysis on processed frame
    rp.question_type_distribution_bar_chart(df)
    rp.save_feature_analysis(df)
    rp.feature_importance_analysis(df, "response_result")
    rp.analyze_feature_imbalance(df)
    # data should be ready for plotting and analysis
    return df




if __name__ == "__main__":
    seed = 42
    random.seed(seed)
    np.random.seed(seed)
    tf.random.set_seed(seed)
    
    # Clean data preprocessing - no SMOTE here, done in grid search
    X_train, X_test, y_train, y_test = ap.train_test_split_extraction(pre_process_training_data(), 0.2, random_state=seed)
    
    print(f"Starting comprehensive grid search with {X_train.shape[1]} input features")
    print(f"Training set: {len(X_train)} samples, Test set: {len(X_test)} samples")
    
    # Run comprehensive grid search
    results_df = grid_search_quizzer_model(X_train, y_train, X_test, y_test)
    
    if os.path.exists('global_best_model.keras'):
        print(f"\nLoading global best model from disk...")
        final_model = tf.keras.models.load_model('global_best_model.keras')
        
        print(f"Model loaded with {X_train.shape[1]} input features")
        
        metrics = rp.model_analytics_report(final_model, X_test, y_test, filename="NN_Text_Report.txt")
        rp.create_comprehensive_visualizations(metrics, "Quizzer_NN")
        
    else:
        print("Grid search failed - no model saved")

    

