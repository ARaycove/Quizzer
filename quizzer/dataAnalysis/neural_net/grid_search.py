import tensorflow as tf
import numpy as np
from neural_net_model import create_quizzer_neural_network, kfold_cross_validation
from attempt_pre_process import apply_smote_balancing
from sklearn.metrics import f1_score, roc_auc_score, balanced_accuracy_score
import itertools
import pandas as pd
import random
import os

def _train_and_evaluate_config(params, X_train, y_train, X_test, y_test, input_features):
    random.seed(params['random_state'])
    np.random.seed(params['random_state'])
    tf.random.set_seed(params['random_state'])
    
    X_train_smote, y_train_smote = apply_smote_balancing(
        X_train=X_train.copy(), 
        y_train=y_train.copy(),
        sampling_strategy=params['sampling_strategy'],
        random_state=params['random_state'],
        k_neighbors=params['k_neighbors']
    )
    
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
    
    model = kfold_cross_validation(
        model, 
        X_train_smote, 
        y_train_smote, 
        k_folds=params['k_folds'], 
        epochs=params['epochs'], 
        batch_size=params['batch_size'],
        random_state=params['random_state']
    )
    
    test_loss, test_accuracy, test_precision, test_recall = model.evaluate(X_test, y_test, verbose=0)
    
    y_pred_prob = model.predict(X_test, verbose=0)
    y_pred = (y_pred_prob > 0.5).astype(int).flatten()
    y_pred_prob_flat = y_pred_prob.flatten()
    
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
    
    prob_std = np.std(y_pred_prob_flat)
    prob_range = np.max(y_pred_prob_flat) - np.min(y_pred_prob_flat)
    
    roc_auc = roc_auc_score(y_test, y_pred_prob_flat)
    f1 = f1_score(y_test, y_pred)
    bacc = balanced_accuracy_score(y_test, y_pred)
    
    f1_mean_discrimination_auc = (f1 * mean_discrimination * roc_auc)
    
    result = {
        'layer_width': params['layer_width'],
        'reduction_percent': params['reduction_percent'],
        'stop_condition': params['stop_condition'],
        'dropout_rate': params['dropout_rate'],
        'focal_gamma': params['focal_gamma'],
        'focal_alpha': params['focal_alpha'],
        'sampling_strategy': params['sampling_strategy'],
        'k_neighbors': params['k_neighbors'],
        'k_folds': params['k_folds'],
        'epochs': params['epochs'],
        'batch_size': params['batch_size'],
        'random_state': params['random_state'],
        'prob_range': prob_range,
        'mean_discrimination': mean_discrimination,
        'roc_auc': roc_auc,
        'f1_mean_discrimination_auc': f1_mean_discrimination_auc,
        'class_0_mean': class_0_mean,
        'class_1_mean': class_1_mean,
        'prob_std': prob_std,
        'test_loss': test_loss,
        'test_accuracy': test_accuracy,
        'test_precision': test_precision,
        'test_recall': test_recall,
        'balanced_accuracy': bacc,
        'f1_score': f1
    }
    
    return result, model

def _update_top_results(result, model=None):
    if os.path.exists('grid_search_top_results.csv'):
        top_results = pd.read_csv('grid_search_top_results.csv')
    else:
        top_results = pd.DataFrame()
    
    current_result_df = pd.DataFrame([result])
    top_results = pd.concat([top_results, current_result_df], ignore_index=True)
    top_results = top_results.sort_values('f1_mean_discrimination_auc', ascending=False).head(25)
    top_results.to_csv('grid_search_top_results.csv', index=False)
    
    f1_mean_discrimination_auc = result['f1_mean_discrimination_auc']
    if f1_mean_discrimination_auc >= top_results['f1_mean_discrimination_auc'].min():
        rank = (top_results['f1_mean_discrimination_auc'] >= f1_mean_discrimination_auc).sum()
        print(f"  *** NEW TOP RESULT - RANK #{rank} ***")
    
    # Check all-time best
    if os.path.exists('global_best_model.csv'):
        best_ever = pd.read_csv('global_best_model.csv')
        best_ever_score = best_ever['f1_mean_discrimination_auc'].values[0]
    else:
        best_ever_score = -1
    
    if f1_mean_discrimination_auc > best_ever_score:
        pd.DataFrame([result]).to_csv('global_best_model.csv', index=False)
        if model:
            model.save('global_best_model.keras')
        print(f"  *** NEW GLOBAL BEST: {f1_mean_discrimination_auc:.6f} (previous: {best_ever_score:.6f}) ***")
        print(f"  *** MODEL SAVED TO global_best_model.keras ***")

def _run_config_iteration(params, X_train, y_train, X_test, y_test, input_features, label):
    print(f"{label}:")
    print(f"  NN: layer_width={params['layer_width']}, reduction={params['reduction_percent']}, dropout={params['dropout_rate']}")
    print(f"  SMOTE: strategy={params['sampling_strategy']}, k_neighbors={params['k_neighbors']}")
    print(f"  K-fold: folds={params['k_folds']}, epochs={params['epochs']}, batch_size={params['batch_size']}")
    
    try:
        result, model = _train_and_evaluate_config(params, X_train, y_train, X_test, y_test, input_features)
        
        print(f"  DISCRIMINATION: {result['mean_discrimination']:.4f}, ROC_AUC: {result['roc_auc']:.3f}, F1: {result['f1_score']:.4f}")
        print(f"  Class means: 0={result['class_0_mean']:.3f}, 1={result['class_1_mean']:.3f}")
        
        try:
            _update_top_results(result, model)
        except Exception as e:
            print(f"  Error updating top results: {e}")
        
        return result
        
    except Exception as e:
        print(f"  ERROR: {str(e)}")
        return None
    finally:
        print("-" * 80)

def _load_previous_configs():
    previous_configs = []
    if os.path.exists('grid_search_top_results.csv'):
        print("Found previous top results - testing these configurations first...")
        previous_df = pd.read_csv('grid_search_top_results.csv')
        
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
        
        # Deduplicate configs
        seen = set()
        deduplicated = []
        for config in previous_configs:
            config_tuple = tuple(sorted(config.items()))
            if config_tuple not in seen:
                seen.add(config_tuple)
                deduplicated.append(config)
        previous_configs = deduplicated
        
        print(f"Will test {len(previous_configs)} previous top configurations first")
        
        if os.path.exists('grid_search_top_results.csv'):
            os.remove('grid_search_top_results.csv')
            print("Cleared previous top results CSV for fresh results")
    
    return previous_configs

def _test_previous_configs(previous_configs, X_train, y_train, X_test, y_test, input_features):
    results = []
    
    if not previous_configs:
        return results
    
    print(f"\nTESTING {len(previous_configs)} PREVIOUS TOP CONFIGURATIONS")
    print("=" * 80)
    
    for i, params in enumerate(previous_configs, 1):
        label = f"Previous Config {i}/{len(previous_configs)}"
        result = _run_config_iteration(params, X_train, y_train, X_test, y_test, input_features, label)
        if result:
            results.append(result)
    
    return results

def _test_random_samples(param_grid, X_train, y_train, X_test, y_test, input_features):
    results = []
    
    param_names = list(param_grid.keys())
    param_values = list(param_grid.values())
    
    total_combinations = 1
    for values in param_values:
        total_combinations *= len(values)
    
    print(f"\nTESTING RANDOM SAMPLES")
    print("=" * 80)
    
    if total_combinations > 50000:
        print(f"Sampling 50,000 random combinations from {total_combinations:,} total")
        for i in range(50000):
            random_combo = tuple(random.choice(values) for values in param_values)
            params = dict(zip(param_names, random_combo))
            
            label = f"Random Sample {i+1}/50000"
            result = _run_config_iteration(params, X_train, y_train, X_test, y_test, input_features, label)
            if result:
                results.append(result)
    else:
        all_combinations = list(itertools.product(*param_values))
        random.shuffle(all_combinations)
        
        for i, combo in enumerate(all_combinations, 1):
            params = dict(zip(param_names, combo))
            
            label = f"Combination {i}/{len(all_combinations)}"
            result = _run_config_iteration(params, X_train, y_train, X_test, y_test, input_features, label)
            if result:
                results.append(result)
    
    return results

def _print_final_results():
    print("\n" + "=" * 80)
    print("FINAL TOP 10 RESULTS")
    print("=" * 80)
    
    if os.path.exists('grid_search_top_results.csv'):
        final_top_results = pd.read_csv('grid_search_top_results.csv')
        for idx, row in final_top_results.iterrows():
            print(f"Rank {idx + 1}:")
            print(f"  F1(Discrim,AUC): {row['f1_mean_discrimination_auc']:.4f} (Discrim: {row['mean_discrimination']:.4f}, AUC: {row['roc_auc']:.3f})")
            print(f"  NN: layer_width={row['layer_width']}, reduction={row['reduction_percent']:.3f}, dropout={row['dropout_rate']:.2f}")
            print(f"  SMOTE: strategy={row['sampling_strategy']}, k_neighbors={row['k_neighbors']}")
            print(f"  K-fold: folds={row['k_folds']}, epochs={row['epochs']}, batch_size={row['batch_size']}")
            print(f"  Class means: 0={row['class_0_mean']:.3f}, 1={row['class_1_mean']:.3f}")
            print()
    
    print("Top results maintained in 'grid_search_top_results.csv'")
    print("Full results saved to 'comprehensive_grid_search_results.csv'")

def grid_search_quizzer_model(X_train, y_train, X_test, y_test):
    previous_configs = _load_previous_configs()
    
    reduction_percent = []
    i = 0.90
    while True:
        reduction_percent.append(i)
        i += 0.001
        if i >= 1:
            break
    
    param_grid = {
        # Neural network parameters
        'layer_width': [5], # increases depth of network range  # 1, 2, 3, 4, 
        'reduction_percent': reduction_percent,
        'stop_condition': [5, 10, 15, 20, 25],
        'dropout_rate': [0.05], # , 0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5, 0.55, 0.6, 0.65, 0.7, 0.75, 0.8, 0.85, 0.9, 0.95
        'focal_gamma': [0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5],
        'focal_alpha': [0.05, 0.1, 0.15, 0.20, 0.25, 0.30, 0.35, 0.4, 0.45, 0.5],
        
        # SMOTE parameters
        'sampling_strategy': ['minority', 0.7, 0.75, 0.8, 0.85, 0.9, 0.95], # 0.35, 0.4, 0.45, 0.5, 0.55, 0.6, 0.65, 
        'k_neighbors': [2, 3, 4, 5], # k >= 6 did not make it into top results
        
        # K-fold validation parameters
        'k_folds': [2, 3, 4, 5], # all k-folds made it into top 5
        'epochs': [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100],
        'batch_size': [32, 48, 64, 80, 96, 112, 128], # 8, 16, 
        
        # Random seed parameter
        'random_state': [42]
    }
    
    input_features = X_train.shape[1]
    
    results = []
    results.extend(_test_previous_configs(previous_configs, X_train, y_train, X_test, y_test, input_features))
    results.extend(_test_random_samples(param_grid, X_train, y_train, X_test, y_test, input_features))
    
    results_df = pd.DataFrame(results)
    
    if len(results_df) == 0:
        print("No successful combinations found!")
        return None
    
    results_df = results_df.sort_values('f1_mean_discrimination_auc', ascending=False)
    results_df.to_csv('comprehensive_grid_search_results.csv', index=False)
    
    _print_final_results()
    
    return results_df