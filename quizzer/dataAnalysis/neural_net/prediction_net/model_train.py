import multiprocessing
import tensorflow as tf
import numpy as np
import random
from neural_net.neural_net_model import create_quizzer_neural_network
from sklearn.metrics import roc_auc_score
from netcal.metrics import ECE

def _train_concat_model_process(queue, working_model_info, sub_model_info, X_train_union, 
                               y_train_union, X_test_union, y_test_union, union_features, 
                               param_grid, n_random_search, seed=42):
    """
    Helper function to train concatenation model with comprehensive grid search in a separate process.
    
    Args:
        queue: multiprocessing.Queue for returning results
        working_model_info: Dictionary with working model config and weights
        sub_model_info: Dictionary with sub-model config and weights
        X_train_union, y_train_union: Training data for union features
        X_test_union, y_test_union: Test data for union features
        union_features: List of union feature names
        param_grid: Dictionary of hyperparameter grids for grid search
        n_random_search: Number of random hyperparameter combinations to try
        seed: Random seed for reproducibility
    """
    # Set random seeds
    random.seed(seed)
    np.random.seed(seed)
    tf.random.set_seed(seed)
    
    # Reconstruct working model with unique name
    working_model_config = working_model_info['model_config']
    working_model_config['name'] = 'working_model'
    working_model = tf.keras.Model.from_config(working_model_config)
    working_model.set_weights(working_model_info['model_weights'])
    working_model.trainable = False
    
    # Reconstruct sub-model with unique name
    sub_model_config = sub_model_info['model_config']
    sub_model_config['name'] = 'sub_model'
    sub_model = tf.keras.Model.from_config(sub_model_config)
    sub_model.set_weights(sub_model_info['model_weights'])
    sub_model.trainable = False
    
    # Instead of using Lambda layers, we'll pre-select features and create separate inputs
    # This avoids serialization issues with Lambda layers
    
    # Create indices for each model's features
    working_model_indices = [union_features.index(f) for f in working_model_info['feature_subset']]
    sub_model_indices = [union_features.index(f) for f in sub_model_info['feature_subset']]
    
    best_score = -1
    best_model_config = None
    best_model_weights = None
    best_params = None
    
    # Generate random hyperparameter combinations
    param_names = list(param_grid.keys())
    param_values = list(param_grid.values())
    
    # Track unique combinations to avoid duplicates
    seen_combinations = set()
    
    for search_idx in range(n_random_search):
        # Generate random combination
        while True:
            combo = tuple(random.choice(values) for values in param_values)
            if combo not in seen_combinations:
                seen_combinations.add(combo)
                break
        
        params = dict(zip(param_names, combo))
        
        # Create a new model that directly processes the union features
        # Instead of using Lambda layers, we'll use indexing in a custom way
        input_layer = tf.keras.Input(shape=(len(union_features),))
        
        # Extract features for each model using slicing
        # We'll use tf.gather but in a way that's embeddable
        # Create separate inputs by gathering indices
        working_model_features = tf.gather(input_layer, indices=working_model_indices, axis=1)
        sub_model_features = tf.gather(input_layer, indices=sub_model_indices, axis=1)
        
        # Get outputs from both models
        working_model_output = working_model(working_model_features)
        sub_model_output = sub_model(sub_model_features)
        
        # Concatenate outputs
        concatenated = tf.keras.layers.Concatenate()([working_model_output, sub_model_output])
        x = concatenated
        
        # Number of concat layers (1-3)
        for layer_idx in range(params['num_concat_layers']):
            # All layers use same size in this simple architecture
            x = tf.keras.layers.Dense(
                params['concat_layer_size'], 
                activation=params['activation'],
                name=f'concat_layer_{layer_idx+1}'
            )(x)
            
            if params['batch_norm']:
                x = tf.keras.layers.BatchNormalization()(x)
            
            x = tf.keras.layers.Dropout(params['dropout_rate'])(x)
        
        # Output layer
        output = tf.keras.layers.Dense(1, activation='sigmoid')(x)
        
        # Create model - use a functional model without Lambda layers
        model = tf.keras.Model(inputs=input_layer, outputs=output)
        
        # Only train the concatenation layers
        for layer in model.layers:
            if 'concat_layer' in layer.name or 'batch_normalization' in layer.name or 'dropout' in layer.name or 'dense_1' in layer.name:
                layer.trainable = True
            else:
                layer.trainable = False
        
        # Compile model with specified optimizer and learning rate
        if params['optimizer'] == 'adam':
            optimizer = tf.keras.optimizers.Adam(learning_rate=params['learning_rate'])
        elif params['optimizer'] == 'rmsprop':
            optimizer = tf.keras.optimizers.RMSprop(learning_rate=params['learning_rate'])
        else:  # nadam
            optimizer = tf.keras.optimizers.Nadam(learning_rate=params['learning_rate'])
        
        model.compile(
            optimizer=optimizer,
            loss=tf.keras.losses.BinaryFocalCrossentropy(gamma=2.0, alpha=0.25),
            metrics=['accuracy']
        )
        
        # Train only the concatenation layer
        model.fit(
            X_train_union, y_train_union,
            validation_split=0.2,
            epochs=params['epochs'],
            batch_size=params['batch_size'],
            verbose=0
        )
        
        # Evaluate on test set
        score = evaluate_model(model, X_test_union, y_test_union)
        
        if score > best_score:
            best_score = score
            best_model_config = model.get_config()
            best_model_weights = model.get_weights()
    
    # Put results in queue
    queue.put({
        'best_score': best_score,
        'model_config': best_model_config,
        'model_weights': best_model_weights,
        'feature_subset': union_features,
        'input_dim': len(union_features),
    })

def build_concat_model(working_model_info, sub_model_info, X_train, y_train, X_test, y_test):
    """
    Build and train concatenation model with comprehensive grid search.
    Runs training in a separate process to avoid memory leaks.
    
    Args:
        working_model_info: Dictionary containing working model configuration and weights
        sub_model_info: Dictionary containing sub-model configuration and weights
        X_train: Training features DataFrame
        y_train: Training target Series
        X_test: Test features DataFrame
        y_test: Test target Series
        
    Returns:
        Dictionary containing best concatenation model configuration, weights, and metadata
    """
    # Get union of features
    union_features = list(set(working_model_info['feature_subset'] + sub_model_info['feature_subset']))
    
    # Prepare data with union features (drop rows with missing values)
    X_train_union = X_train[union_features].copy()
    X_test_union = X_test[union_features].copy()
    
    # Drop rows with missing values
    train_mask = X_train_union.notnull().all(axis=1)
    X_train_union = X_train_union[train_mask]
    y_train_union = y_train[train_mask]
    
    test_mask = X_test_union.notnull().all(axis=1)
    X_test_union = X_test_union[test_mask]
    y_test_union = y_test[test_mask]
    
    print(f"Building concat model with union of {len(union_features)} features")
    print(f"Training samples: {len(X_train_union)}")
    print(f"Test samples: {len(X_test_union)}")
    
    # Comprehensive hyperparameter grid for concat model
    param_grid = {
        'concat_layer_size': list(range(1, 11)),
        'num_concat_layers': [1],
        'dropout_rate': [0.0, 0.1, 0.2, 0.3, 0.4, 0.5],
        'batch_norm': [True, False],
        'activation': ['sigmoid'],
        'learning_rate': [0.1, 0.01, 0.001],
        'optimizer': ['adam', 'rmsprop', 'nadam'],
        'epochs': [20, 30, 40, 50],
        'batch_size': [32, 64, 128]
    }
    
    # Number of random combinations to try
    n_random_search = 10
    
    # Create queue for inter-process communication
    ctx = multiprocessing.get_context('spawn')
    queue = ctx.Queue()
    
    # Create and start the training process
    p = ctx.Process(
        target=_train_concat_model_process,
        args=(queue, working_model_info, sub_model_info, X_train_union, y_train_union,
              X_test_union, y_test_union, union_features, param_grid, n_random_search)
    )
    
    p.start()
    result = queue.get()
    p.join()
    
    print(f"Best concat model score: {result['best_score']:.4f}")
    return result

def select_best_subset_model(all_sub_models):
    """
    Select the best sub-model from a list of trained sub-models based on the composite score.
    
    Args:
        all_sub_models: List of dictionaries, each containing a trained sub-model's
                       configuration, weights, and metadata
    
    Returns:
        The dictionary of the best sub-model (with highest 'best_score')
    """
    if not all_sub_models:
        raise ValueError("No sub-models provided")
    
    # Find the sub-model with the highest best_score
    best_model = max(all_sub_models, key=lambda x: x['best_score'])
    
    print(f"Selected best sub-model with score: {best_model['best_score']:.4f}")
    print(f"Features in best model: {len(best_model['feature_subset'])}")
    
    return best_model

def evaluate_model(model, X_test_subset, y_test):
    """
    Evaluate a model's performance on test data and return a composite score.
    
    Args:
        model: Trained TensorFlow model
        X_test_subset: Test feature DataFrame (only the subset features)
        y_test: Test target Series
        
    Returns:
        Composite score (harmonic mean of ROC AUC and 1-ECE)
    """
    # Get predictions
    y_pred_prob = model.predict(X_test_subset, verbose=0).flatten()
    
    # Calculate ROC AUC
    roc_auc = roc_auc_score(y_test, y_pred_prob)
    
    # Calculate Expected Calibration Error (ECE)
    ece_metric = ECE(bins=10)
    ece = ece_metric.measure(y_pred_prob, np.array(y_test))
    
    # Calculate composite score (harmonic mean of ROC AUC and 1-ECE)
    ece_score = 1 - ece  # Convert ECE to a score where higher is better
    
    # Use harmonic mean to balance both metrics
    if roc_auc > 0 and ece_score > 0:
        composite_score = 2 * (roc_auc * ece_score) / (roc_auc + ece_score)
    else:
        composite_score = 0
    
    return composite_score

def _train_sub_model_process(queue, X_train_subset, y_train_subset, X_test_subset, y_test, 
                           feature_subset, param_grid, n_random_search, seed):
    """
    Helper function to run in separate process for training a sub-model.
    
    Args:
        queue: multiprocessing.Queue to return results
        X_train_subset: Training features (subset)
        y_train_subset: Training targets
        X_test_subset: Test features (subset)
        y_test: Test targets
        feature_subset: List of feature names
        param_grid: Hyperparameter grid
        n_random_search: Number of random configurations to try
        seed: Random seed
    """
    # Set random seeds inside the process
    random.seed(seed)
    np.random.seed(seed)
    tf.random.set_seed(seed)
    
    best_score = -1
    best_model_config = None
    best_model_weights = None
    best_params = None
    
    # Track unique combinations to avoid duplicates
    seen_combinations = set()
    
    for search_idx in range(n_random_search):
        # Generate random hyperparameters - ensure uniqueness
        while True:
            params = {key: random.choice(values) for key, values in param_grid.items()}
            # Create a hashable representation of the parameters
            param_tuple = tuple(sorted(params.items()))
            if param_tuple not in seen_combinations:
                seen_combinations.add(param_tuple)
                break
        
        # Create and train model with all parameters
        model = create_quizzer_neural_network(
            input_dim=len(feature_subset),
            train_samples=len(X_train_subset),
            epochs=params['epochs'],
            batch_size=params['batch_size'],
            layer_width=params['layer_width'],
            reduction_percent=params['reduction_percent'],
            stop_condition=params['stop_condition'],
            activation=params['activation'],
            learning_rate=params['learning_rate'],
            dropout_rate=params['dropout_rate'],
            batch_norm=params['batch_norm'],
            focal_gamma=params['focal_gamma'],
            focal_alpha=params['focal_alpha'],
            optimizer=params['optimizer'],
            l2_regularization=params['l2_regularization']
        )
        
        # Train the model
        model.fit(
            X_train_subset, y_train_subset,
            validation_split=0.2,
            epochs=params['epochs'],
            batch_size=params['batch_size'],
            verbose=0
        )
        
        # Evaluate on the global test set using the evaluate_model helper
        score = evaluate_model(model, X_test_subset, y_test)
        
        if score > best_score:
            best_score = score
            best_model_config = model.get_config()
            best_model_weights = model.get_weights()
            best_params = params
    
    # Put results in queue
    queue.put({
        'best_score': best_score,
        'best_params': best_params,
        'model_config': best_model_config,
        'model_weights': best_model_weights,
        'feature_subset': feature_subset,
        'input_dim': len(feature_subset)
    })

def train_sub_model(df, feature_subset, X_test, y_test, 
        n_num_grid_search=10, 
        param_grid = {
        # Default parameter grid matching create_quizzer_neural_network defaults
        'layer_width': [1], 
        'reduction_percent': [0.99],
        'stop_condition': [5],
        'dropout_rate': [0.3],
        'focal_gamma': [1.0],
        'focal_alpha': [0.25],
        'epochs': [50],
        'batch_size': [256],
        'learning_rate': [0.1],
        'optimizer': ['nadam'],
        'activation': ['relu'],
        'batch_norm': [False],
        'l2_regularization': [0.0]
    }):
    """
    Train a neural network model on a subset of features using grid search in a separate process.
    
    Args:
        df: DataFrame containing subset features and 'response_result' target (no missing values)
        feature_subset: List of feature names in the subset
        X_test: Test feature DataFrame (complete, no missing values)
        y_test: Test target Series
        
    Returns:
        Dictionary containing trained model architecture config and weights
    """
    # Split features and target from df
    X_subset = df[feature_subset]
    y_subset = df['response_result']
    
    # Prepare test subset (only features that exist in X_test)
    X_test_subset = X_test[feature_subset]
    
    print(f"Training sub-model on {len(feature_subset)} features")
    print(f"Training samples: {len(X_subset)}")
    
    # Number of random combinations to try
    n_random_search = n_num_grid_search
    seed = 42
    
    # Create queue for inter-process communication
    ctx = multiprocessing.get_context('spawn')
    queue = ctx.Queue()
    
    # Create and start the training process
    p = ctx.Process(
        target=_train_sub_model_process,
        args=(queue, X_subset, y_subset, X_test_subset, y_test, 
              feature_subset, param_grid, n_random_search, seed)
    )
    
    p.start()
    result = queue.get()
    p.join()
    
    print(f"Best sub-model score: {result['best_score']:.4f}")
    
    return result