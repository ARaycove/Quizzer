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