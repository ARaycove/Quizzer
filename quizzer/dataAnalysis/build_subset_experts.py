from neural_net.accuracy_net import pre_process_training_data
from neural_net.prediction_net.handle_datasets import train_test_split, collect_feature_list, find_best_subset_to_train, get_candidate_subset_records
from neural_net.prediction_net.model_train import train_sub_model
from neural_net.prediction_net.model_sub   import update_submodel_record

# Data setup
df = pre_process_training_data()
X_train, X_test, y_train, y_test = train_test_split(df)
all_features = collect_feature_list(df)

while True:
    # building subsets is a continuous process
    # Out of the 
    subset_to_try = find_best_subset_to_train(
        top_n       = 100,
        top_k       = 1000,
        top_n_perc  = 0.5 # top_n get's 50% of the compute time
    )

    # Extract feature list from the record
    s = subset_to_try['feature_set'].split(',')

    df_subset = get_candidate_subset_records(
        subset_features = s,
        X_train         = X_train,
        y_train         = y_train
    )

    # Train with comprehensive parameter grid
    trained_sub_model = train_sub_model(
        df                  = df_subset,
        feature_subset      = s,
        X_test              = X_test,
        y_test              = y_test,
        n_num_grid_search   = 1,
        param_grid          = {
            'layer_width': [1, 2, 3, 4, 5],
            'reduction_percent': [0.5, 0.6, 0.7, 0.8, 0.9, 0.91, 0.92, 0.93, 0.94, 0.95, 0.96, 0.97, 0.98, 0.99],
            'stop_condition': [2, 3, 4, 5, 6, 7, 8, 9, 10],
            'dropout_rate': [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9],
            'focal_gamma': [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0],
            'focal_alpha': [0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.5, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95, 1.00],
            'epochs': [10, 20, 30, 40, 50, 60, 70, 80, 90, 100],
            'batch_size': [32, 64, 128, 256],  # Different batch sizes
            'learning_rate': [0.1, 0.01, 0.001, 0.0005, 0.0001],  # Different learning rates
            'optimizer': ['nadam', 'adam', 'rmsprop', 'sgd'],  # Different optimizers
            'activation': ['relu', 'leaky_relu', 'elu'],  # Different activation functions
            'batch_norm': [True, False],  # With and without batch normalization
            'l2_regularization': [0.0, 0.00001, 0.0001, 0.001, 0.01, 0.1],  # Different L2 regularization strengths
        }
    )

    # Compares the two model scores, places the best model config and weights into the database, increment the total grid searches performed counter everytime
    # total grid searches will be used 
    update_submodel_record(trained_sub_model, subset_to_try)