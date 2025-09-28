import attempt_pre_process as ap
from neural_net_model import create_quizzer_neural_network, kfold_cross_validation, grid_search_quizzer_model

import reports as rp
import pandas as pd
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
    # rp.save_feature_analysis(df)
    # rp.feature_importance_analysis(df, "response_result")
    # rp.analyze_feature_imbalance(df)
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
    
    if results_df is not None:
        best_row = results_df.iloc[0]
        print(f"\nBEST CONFIGURATION:")
        print(f"Mean Discrimination: {best_row['mean_discrimination']:.4f}")
        print(f"ROC AUC: {best_row['roc_auc']:.3f}")
        print(f"Probability Range: {best_row['prob_range']:.3f}")
        
        # Extract best parameters and rebuild model for full report
        print("\nBuilding final model with best parameters...")
        
        # Apply SMOTE with best parameters
        X_train_final, y_train_final = ap.apply_smote_balancing(
            X_train=X_train.copy(), 
            y_train=y_train.copy(),
            sampling_strategy=best_row['sampling_strategy'],
            random_state=seed,
            k_neighbors=int(best_row['k_neighbors'])
        )
        
        # Create final model with best neural network parameters
        input_features = X_train.shape[1]
        final_model = create_quizzer_neural_network(
            input_dim=input_features,
            layer_width=int(best_row['layer_width']),
            reduction_percent=best_row['reduction_percent'],
            stop_condition=int(best_row['stop_condition']),
            activation='relu',
            dropout_rate=best_row['dropout_rate'],
            batch_norm=True,
            focal_gamma=best_row['focal_gamma'],
            focal_alpha=best_row['focal_alpha']
        )
        
        # Train final model with best k-fold parameters
        final_model = kfold_cross_validation(
            final_model, 
            X_train_final, 
            y_train_final, 
            k_folds=int(best_row['k_folds']), 
            epochs=int(best_row['epochs']), 
            batch_size=int(best_row['batch_size'])
        )
        
        print(f"Final model created with {input_features} input features")
        
        # Generate comprehensive analytics report
        metrics = rp.model_analytics_report(final_model, X_test, y_test, filename="NN_Text_Report.txt")
        rp.create_comprehensive_visualizations(metrics, "Quizzer_NN")
        
    else:
        print("Grid search failed - no successful combinations found")

    

