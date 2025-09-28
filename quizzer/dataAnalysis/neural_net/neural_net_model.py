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
import itertools
import pandas as pd
import random
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
    
    # Comprehensive parameter grid
    param_grid = {
        # Neural network parameters
        'layer_width': [1, 2, 3],
        'reduction_percent': [0.70, 0.80, 0.90],
        'stop_condition': [5, 10, 25],
        'dropout_rate': [0.1, 0.3, 0.5],
        'focal_gamma': [0.5, 2.0, 5.0],
        'focal_alpha': [0.1, 0.25, 0.5],
        
        # SMOTE parameters
        'sampling_strategy': ['auto', 'minority', 0.25, 0.5, 0.75],
        'k_neighbors': [3, 5, 7],
        
        # K-fold validation parameters
        'k_folds': [2, 3, 5],
        'epochs': [5, 10, 15],
        'batch_size': [8, 16, 32]
    }
    
    # Generate all combinations
    param_combinations = list(ParameterGrid(param_grid))
    
    print(f"Testing {len(param_combinations)} parameter combinations...")
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
            # Apply SMOTE with current parameters
            X_train_smote, y_train_smote = apply_smote_balancing(
                X_train=X_train.copy(), 
                y_train=y_train.copy(),
                sampling_strategy=params['sampling_strategy'],
                random_state=42,
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
                batch_size=params['batch_size']
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
            from sklearn.metrics import balanced_accuracy_score, f1_score, roc_auc_score
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
            
            # Write result to file immediately
            current_df = pd.DataFrame([result])
            if i == 1:
                # First iteration - create new file with header
                current_df.to_csv('grid_search_progress.csv', index=False, mode='w')
            else:
                # Append to existing file without header
                current_df.to_csv('grid_search_progress.csv', index=False, mode='a', header=False)
            
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
    print("COMPREHENSIVE GRID SEARCH RESULTS (Top 10)")
    print("=" * 80)
    
    top_10 = results_df.head(10)
    for idx, row in top_10.iterrows():
        print(f"Rank {row.name + 1}:")
        print(f"  DISCRIMINATION: {row['mean_discrimination']:.4f}, ROC_AUC: {row['roc_auc']:.3f}, Range: {row['prob_range']:.3f}")
        print(f"  NN: layer_width={row['layer_width']}, reduction={row['reduction_percent']:.2f}, dropout={row['dropout_rate']:.2f}")
        print(f"  SMOTE: strategy={row['sampling_strategy']}, k_neighbors={row['k_neighbors']}")
        print(f"  K-fold: folds={row['k_folds']}, epochs={row['epochs']}, batch_size={row['batch_size']}")
        print(f"  Class means: 0={row['class_0_mean']:.3f}, 1={row['class_1_mean']:.3f}")
        print()
    
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

def kfold_cross_validation(model, X_train, y_train, k_folds=5, epochs=100, batch_size=32, verbose=1):
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
        
    Returns:
        Trained model (fitted on full training data after cross validation)
    """
    
    print(f"Starting {k_folds}-Fold Cross Validation")
    print("=" * 50)
    
    # Initialize K-Fold
    kfold = KFold(n_splits=k_folds, shuffle=True, random_state=42)
    
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
        model.set_weights([np.random.normal(size=w.shape) for w in model.get_weights()])
        
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
    
    # Reset model weights
    model.set_weights([np.random.normal(size=w.shape) for w in model.get_weights()])
    
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