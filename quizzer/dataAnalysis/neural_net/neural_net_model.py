'''
Activation functions:
RELU
Softplus
Sigmoid
'''

import tensorflow as tf
from tensorflow import keras
from keras import layers, Model
from keras.optimizers import Adam
from sklearn.model_selection import KFold
import numpy as np
from sklearn.model_selection import ParameterGrid
from attempt_pre_process import apply_smote_balancing
from sklearn.metrics import f1_score, roc_auc_score, balanced_accuracy_score
import itertools
import pandas as pd
import random
import itertools
import os

def grid_search_quizzer_model(X_train, y_train, X_test, y_test):
    """
    Comprehensive grid search for Quizzer neural network with SMOTE and k-fold parameters.
    
    Args:
        X_train, y_train: Training data
        X_test, y_test: Test data for evaluation
        
    Returns:
        DataFrame with results sorted by mean discrimination
    """
    
    # First, try previous top n configurations if they exist
    previous_configs = []
    if os.path.exists('grid_search_top_results.csv'):
        print("Found previous top results - testing these configurations first...")
        previous_df = pd.read_csv('grid_search_top_results.csv')
        
        # Convert DataFrame rows to parameter dictionaries
        for _, row in previous_df.iterrows():
            config = {
                'layer_width': int(row['layer_width']),
                'reduction_percent': float(row['reduction_percent']),
                'stop_condition': int(row['stop_condition']),
                'dropout_rate': float(row['dropout_rate']),
                'focal_gamma': float(row['focal_gamma']),
                'focal_alpha': float(row['focal_alpha']),
                'sampling_strategy': row['sampling_strategy'],
                'k_neighbors': int(row['k_neighbors']),
                'k_folds': int(row['k_folds']),
                'epochs': int(row['epochs']),
                'batch_size': int(row['batch_size']),
                'random_state': int(row['random_state'])
            }
            previous_configs.append(config)
        
        print(f"Will test {len(previous_configs)} previous top configurations first")
        
        # Clear the existing CSV to start fresh
        if os.path.exists('grid_search_top_results.csv'):
            os.remove('grid_search_top_results.csv')
            print("Cleared previous top results CSV for fresh results")
    
    # Comprehensive parameter grid
    param_grid = {
        # Neural network parameters
        'layer_width': [1, 2],
        'reduction_percent': [0.90, 0.91, 0.92, 0.93, 0.94, 0.945, 0.95, 0.955, 0.96, 0.97, 0.98, 0.99],
        'stop_condition': [3, 5, 10, 15, 20, 25],
        'dropout_rate': [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9],
        'focal_gamma': [0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5],
        'focal_alpha': [0.05, 0.1, 0.15, 0.20, 0.25, 0.30, 0.35, 0.4, 0.45, 0.5],
        
        # SMOTE parameters
        'sampling_strategy': ['minority', 0.20, 0.25, 0.30, 0.35, 0.4, 0.45, 0.5, 0.55, 0.6, 0.65, 0.7, 0.75, 0.8, 0.85, 0.9, 0.95],
        'k_neighbors': [2, 3, 4, 5, 6, 7, 8, 9, 10],
        
        # K-fold validation parameters
        'k_folds': [2, 3, 4, 5],
        'epochs': [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100],
        'batch_size': [2, 4, 8, 16, 32, 64],
        
        # Random seed parameter
        'random_state': [42]
    }
    
    # Generate all combinations using itertools to avoid memory explosion
    param_names = list(param_grid.keys())
    param_values = list(param_grid.values())
    
    # Calculate total combinations
    total_combinations = 1
    for values in param_values:
        total_combinations *= len(values)
    
    print(f"Total possible combinations: {total_combinations:,}")
    
    # Combine previous configs with new random sampling
    if previous_configs:
        # Test previous top 25 first, then add random sampling
        all_combinations = previous_configs.copy()
        
        # Always add random sampling after testing previous configs
        remaining_samples = 50000 - len(previous_configs)
        if total_combinations > remaining_samples:
            print(f"Adding {remaining_samples} random combinations from {total_combinations:,} total")
            for _ in range(remaining_samples):
                random_combo = tuple(random.choice(values) for values in param_values)
                # Convert to dict format
                random_config = dict(zip(param_names, random_combo))
                all_combinations.append(random_config)
        else:
            # Add all possible combinations
            all_remaining = list(itertools.product(*param_values))
            random.shuffle(all_remaining)
            for combo in all_remaining:
                random_config = dict(zip(param_names, combo))
                all_combinations.append(random_config)
        
        param_combinations = all_combinations
    else:
        # No previous configs - do normal random sampling
        if total_combinations > 50000:
            print(f"Sampling 50,000 random combinations from {total_combinations:,} total")
            param_combinations = []
            for _ in range(50000):
                random_combo = tuple(random.choice(values) for values in param_values)
                random_config = dict(zip(param_names, random_combo))
                param_combinations.append(random_config)
        else:
            all_combinations = list(itertools.product(*param_values))
            random.shuffle(all_combinations)
            param_combinations = [dict(zip(param_names, combo)) for combo in all_combinations]
    
    print(f"Testing {len(param_combinations):,} parameter combinations (shuffled order)...")
    print("Optimizing for: MEAN DISCRIMINATION")
    print("=" * 80)
    
    results = []
    input_features = X_train.shape[1]
    
    for i, params in enumerate(param_combinations, 1):
        print(f"Combination {i}/{len(param_combinations)}:")
        print(f"  NN: layer_width={params['layer_width']}, reduction={params['reduction_percent']}, dropout={params['dropout_rate']}")
        print(f"  SMOTE: strategy={params['sampling_strategy']}, k_neighbors={params['k_neighbors']}")
        print(f"  K-fold: folds={params['k_folds']}, epochs={params['epochs']}, batch_size={params['batch_size']}")
        
        try:
            # Set seeds for this iteration
            random.seed(params['random_state'])
            np.random.seed(params['random_state'])
            tf.random.set_seed(params['random_state'])
            
            # Apply SMOTE with current parameters
            X_train_smote, y_train_smote = apply_smote_balancing(
                X_train=X_train.copy(), 
                y_train=y_train.copy(),
                sampling_strategy=params['sampling_strategy'],
                random_state=params['random_state'],
                k_neighbors=params['k_neighbors']
            )
            
            # Create model with current neural network parameters
            model = create_quizzer_neural_network(
                input_dim=input_features,
                layer_width=params['layer_width'],
                reduction_percent=params['reduction_percent'],
                stop_condition=params['stop_condition'],
                activation='relu',
                dropout_rate=params['dropout_rate'],
                batch_norm=True,
                focal_gamma=params['focal_gamma'],
                focal_alpha=params['focal_alpha']
            )
            
            # Train with k-fold validation using current parameters
            model = kfold_cross_validation(
                model, 
                X_train_smote, 
                y_train_smote, 
                k_folds=params['k_folds'], 
                epochs=params['epochs'], 
                batch_size=params['batch_size'],
                random_state=params['random_state']
            )
            
            # Evaluate on test set
            test_loss, test_accuracy, test_precision, test_recall = model.evaluate(
                X_test, y_test, verbose=0
            )
            
            # Get predictions for discrimination analysis
            y_pred_prob = model.predict(X_test, verbose=0)
            y_pred = (y_pred_prob > 0.5).astype(int).flatten()
            y_pred_prob_flat = y_pred_prob.flatten()
            
            # Calculate discrimination metrics
            class_0_probs = y_pred_prob_flat[y_test == 0]
            class_1_probs = y_pred_prob_flat[y_test == 1]
            
            if len(class_0_probs) > 0 and len(class_1_probs) > 0:
                mean_discrimination = np.mean(class_1_probs) - np.mean(class_0_probs)
                class_0_mean = np.mean(class_0_probs)
                class_1_mean = np.mean(class_1_probs)
            else:
                mean_discrimination = 0
                class_0_mean = 0
                class_1_mean = 0
            
            # Additional metrics
            balanced_acc = balanced_accuracy_score(y_test, y_pred)
            f1 = f1_score(y_test, y_pred)
            roc_auc = roc_auc_score(y_test, y_pred_prob_flat)
            prob_std = np.std(y_pred_prob_flat)
            prob_range = np.max(y_pred_prob_flat) - np.min(y_pred_prob_flat)
            
            # Store comprehensive results
            result = {
                'combination': i,
                # Neural network params
                'layer_width': params['layer_width'],
                'reduction_percent': params['reduction_percent'],
                'stop_condition': params['stop_condition'],
                'dropout_rate': params['dropout_rate'],
                'focal_gamma': params['focal_gamma'],
                'focal_alpha': params['focal_alpha'],
                # SMOTE params
                'sampling_strategy': params['sampling_strategy'],
                'k_neighbors': params['k_neighbors'],
                # K-fold params
                'k_folds': params['k_folds'],
                'epochs': params['epochs'],
                'batch_size': params['batch_size'],
                'random_state': params['random_state'],
                # Primary metrics
                'mean_discrimination': mean_discrimination,
                'roc_auc': roc_auc,
                'prob_range': prob_range,
                # Secondary metrics
                'test_loss': test_loss,
                'test_accuracy': test_accuracy,
                'test_precision': test_precision,
                'test_recall': test_recall,
                'balanced_accuracy': balanced_acc,
                'f1_score': f1,
                'class_0_mean': class_0_mean,
                'class_1_mean': class_1_mean,
                'prob_std': prob_std
            }
            
            results.append(result)
            
            print(f"  DISCRIMINATION: {mean_discrimination:.4f}, ROC_AUC: {roc_auc:.3f}, Range: {prob_range:.3f}")
            print(f"  Class means: 0={class_0_mean:.3f}, 1={class_1_mean:.3f}")
            
            # Update top 25 results in CSV
            try:
                # Try to read existing top results
                if os.path.exists('grid_search_top_results.csv'):
                    top_results = pd.read_csv('grid_search_top_results.csv')
                else:
                    top_results = pd.DataFrame()
                
                # Add current result
                current_result_df = pd.DataFrame([result])
                top_results = pd.concat([top_results, current_result_df], ignore_index=True)
                
                # Sort by mean_discrimination (descending) and keep top 25
                top_results = top_results.sort_values('mean_discrimination', ascending=False).head(25)
                
                # Save updated top results
                top_results.to_csv('grid_search_top_results.csv', index=False)
                
                # Print current ranking if this result made it to top results
                if mean_discrimination >= top_results['mean_discrimination'].min():
                    rank = (top_results['mean_discrimination'] >= mean_discrimination).sum()
                    print(f"  *** NEW TOP RESULT - RANK #{rank} ***")
                    
            except Exception as e:
                print(f"  Error updating top results: {e}")
            
        except Exception as e:
            print(f"  ERROR: {str(e)}")
            continue
        
        print("-" * 80)
    
    # Convert to DataFrame
    results_df = pd.DataFrame(results)
    
    if len(results_df) == 0:
        print("No successful combinations found!")
        return None
    
    # Sort by mean discrimination (primary metric)
    results_df = results_df.sort_values('mean_discrimination', ascending=False)
    
    # Save comprehensive results
    results_df.to_csv('comprehensive_grid_search_results.csv', index=False)
    
    print("\n" + "=" * 80)
    print("FINAL TOP 10 RESULTS")
    print("=" * 80)
    
    # Load and display final top results
    if os.path.exists('grid_search_top_results.csv'):
        final_top_results = pd.read_csv('grid_search_top_results.csv')
        for idx, row in final_top_results.iterrows():
            print(f"Rank {idx + 1}:")
            print(f"  DISCRIMINATION: {row['mean_discrimination']:.4f}, ROC_AUC: {row['roc_auc']:.3f}, Range: {row['prob_range']:.3f}")
            print(f"  NN: layer_width={row['layer_width']}, reduction={row['reduction_percent']:.3f}, dropout={row['dropout_rate']:.2f}")
            print(f"  SMOTE: strategy={row['sampling_strategy']}, k_neighbors={row['k_neighbors']}")
            print(f"  K-fold: folds={row['k_folds']}, epochs={row['epochs']}, batch_size={row['batch_size']}")
            print(f"  Class means: 0={row['class_0_mean']:.3f}, 1={row['class_1_mean']:.3f}")
            print()
    
    print("Top results maintained in 'grid_search_top_results.csv'")
    print("Full results saved to 'comprehensive_grid_search_results.csv'")
    return results_df

def create_quizzer_neural_network(input_dim, 
                                 layer_width=5, 
                                 reduction_percent=0.50, 
                                 stop_condition=20,
                                 activation='relu',
                                 loss='binary_crossentropy',
                                 optimizer='adam',
                                 learning_rate=0.001,
                                 dropout_rate=0.0,
                                 batch_norm=False,
                                 focal_gamma=3.0,
                                 focal_alpha=0.25):
    """
    Creates neural network for Quizzer response prediction.
    
    Args:
        input_dim: Number of input features
        layer_width: Number of equal-sized layers at input_dim size
        reduction_percent: Percentage to reduce layer size each step
        stop_condition: Minimum neurons before output layer
        activation: Activation function for hidden layers
        loss: Loss function
        optimizer: Optimizer type
        learning_rate: Learning rate
        dropout_rate: Dropout rate
        batch_norm: Whether to use batch normalization
        focal_gamma: Gamma parameter for focal loss (higher = focus on hard examples)
        focal_alpha: Alpha parameter for focal loss (lower = penalize false positives more)
        
    Returns:
        Compiled TensorFlow model
    """
    
    inputs = tf.keras.Input(shape=(input_dim,))
    x = inputs
    
    # print(f"Creating neural network with input_dim={input_dim}, layer_width={layer_width}")
    # print(f"Reduction: {reduction_percent*100}% per step, stopping at {stop_condition} neurons")
    # print(f"Focal loss: gamma={focal_gamma}, alpha={focal_alpha}")
    # print("-" * 60)
    
    # Create layer_width number of layers, each with input_dim neurons
    # print(f"Creating {layer_width} initial layers with {input_dim} neurons each:")
    for i in range(layer_width):
        x = layers.Dense(input_dim)(x)
        # print(f"  Layer {i+1}: {input_dim} neurons")
        
        if batch_norm:
            x = layers.BatchNormalization()(x)
            
        if activation == 'leaky_relu':
            x = layers.LeakyReLU(alpha=0.1)(x)
        else:
            x = layers.Activation(activation)(x)
            
        if dropout_rate > 0:
            x = layers.Dropout(dropout_rate)(x)
    
    # print(f"Initial layers complete: {layer_width} layers created")
    # print("-" * 60)
    
    # Create reducing layers - layer_width layers at each reduction step
    current_size = input_dim
    reduction_step = 1
    
    # print("Starting reduction phase:")
    while True:
        next_size = int(current_size * (1 - reduction_percent))
        
        if next_size <= stop_condition:
            next_size = stop_condition
            
        # print(f"Reduction step {reduction_step}: Creating {layer_width} layers with {next_size} neurons each:")
        
        # Create layer_width layers at this size
        for i in range(layer_width):
            x = layers.Dense(next_size)(x)
            # print(f"  Layer {i+1}: {next_size} neurons")
            
            if batch_norm:
                x = layers.BatchNormalization()(x)
                
            if activation == 'leaky_relu':
                x = layers.LeakyReLU(alpha=0.1)(x)
            else:
                x = layers.Activation(activation)(x)
                
            if dropout_rate > 0:
                x = layers.Dropout(dropout_rate)(x)
        
        current_size = next_size
        reduction_step += 1
        
        if current_size <= stop_condition:
            # print(f"Reached stop condition ({stop_condition} neurons), ending reduction")
            break
    
    # print("-" * 60)
    
    # Output layer - always sigmoid for probability
    outputs = layers.Dense(1, activation='sigmoid')(x)
    # print("Creating output layer: 1 neuron with sigmoid activation")
    
    model = Model(inputs=inputs, outputs=outputs)
    
    total_layers = len(model.layers)
    # print(f"Model created successfully with {total_layers} total layers")
    # print("=" * 60)
    
    # Configure optimizer
    if optimizer == 'adam':
        opt = Adam(learning_rate=learning_rate)
    elif optimizer == 'sgd':
        opt = tf.keras.optimizers.SGD(learning_rate=learning_rate)
    elif optimizer == 'rmsprop':
        opt = tf.keras.optimizers.RMSprop(learning_rate=learning_rate)
    
    model.compile(
        optimizer=opt,
        loss=tf.keras.losses.BinaryFocalCrossentropy(
            gamma=focal_gamma,     # Use parameter
            alpha=focal_alpha      # Use parameter
        ),
        metrics=['accuracy', 'precision', 'recall']
    )
    
    return model

def kfold_cross_validation(model, X_train, y_train, k_folds=5, epochs=100, batch_size=32, verbose=1, random_state=42):
    """
    Performs K-Fold cross validation on the model and returns the trained model.
    
    Args:
        model: Compiled TensorFlow model
        X_train: Training features
        y_train: Training targets
        k_folds: Number of folds for cross validation
        epochs: Number of epochs per fold
        batch_size: Batch size for training
        verbose: Verbosity level
        random_state: Random seed for KFold splits
        
    Returns:
        Trained model (fitted on full training data after cross validation)
    """
    
    print(f"Starting {k_folds}-Fold Cross Validation")
    print("=" * 50)
    
    # Initialize K-Fold with passed random state
    kfold = KFold(n_splits=k_folds, shuffle=True, random_state=random_state)
    
    # Store results
    fold_scores = []
    fold_accuracies = []
    
    # Perform K-Fold cross validation
    for fold, (train_idx, val_idx) in enumerate(kfold.split(X_train), 1):
        print(f"Fold {fold}/{k_folds}")
        print("-" * 30)
        
        # Split data for this fold
        X_fold_train = X_train.iloc[train_idx]
        X_fold_val = X_train.iloc[val_idx]
        y_fold_train = y_train.iloc[train_idx]
        y_fold_val = y_train.iloc[val_idx]
        
        print(f"Train samples: {len(X_fold_train)}, Validation samples: {len(X_fold_val)}")
        
        # Reset model weights for each fold
        initial_weights = []
        for w in model.get_weights():
            initial_weights.append(np.random.normal(0, 0.1, size=w.shape))
        model.set_weights(initial_weights)
        
        # Train on this fold
        history = model.fit(
            X_fold_train, y_fold_train,
            validation_data=(X_fold_val, y_fold_val),
            epochs=epochs,
            batch_size=batch_size,
            verbose=0 if verbose == 0 else 1
        )
        
        # Evaluate this fold
        fold_loss, fold_accuracy, fold_precision, fold_recall = model.evaluate(
            X_fold_val, y_fold_val, verbose=0
        )
        
        fold_scores.append(fold_loss)
        fold_accuracies.append(fold_accuracy)
        
        print(f"Fold {fold} Results:")
        print(f"  Loss: {fold_loss:.4f}")
        print(f"  Accuracy: {fold_accuracy:.4f}")
        print(f"  Precision: {fold_precision:.4f}")
        print(f"  Recall: {fold_recall:.4f}")
        print()
    
    # Calculate cross validation statistics
    mean_score = np.mean(fold_scores)
    std_score = np.std(fold_scores)
    mean_accuracy = np.mean(fold_accuracies)
    std_accuracy = np.std(fold_accuracies)
    
    print("=" * 50)
    print("CROSS VALIDATION RESULTS")
    print("=" * 50)
    print(f"Mean Loss: {mean_score:.4f} (+/- {std_score:.4f})")
    print(f"Mean Accuracy: {mean_accuracy:.4f} (+/- {std_accuracy:.4f})")
    print()
    
    # Final training on full dataset
    print("Training final model on full training dataset...")
    print("-" * 50)
    
    # Reset model weights for final training
    final_weights = []
    for w in model.get_weights():
        final_weights.append(np.random.normal(0, 0.1, size=w.shape))
    model.set_weights(final_weights)
    
    # Train on full training data
    final_history = model.fit(
        X_train, y_train,
        validation_split=0.2,
        epochs=epochs,
        batch_size=batch_size,
        verbose=verbose
    )
    
    print("Cross validation and final training complete!")
    print("=" * 50)
    
    return model