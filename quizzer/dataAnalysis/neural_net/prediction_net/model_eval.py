import os
import json
import numpy as np
import pandas as pd
import tensorflow as tf
from pathlib import Path
from sklearn.metrics import (
    roc_curve, confusion_matrix, roc_auc_score,
    precision_recall_curve, brier_score_loss,
    accuracy_score, precision_score, recall_score,
    f1_score
)
from netcal.metrics import ECE
import sqlite3
import matplotlib.pyplot as plt
from typing import List, Dict, Any

# Import plotting functions
from neural_net.plot_functions import (
    plot_roc_curve,
    plot_precision_recall_curve,
    plot_confusion_matrix,
    plot_probability_distributions,
    plot_model_performance_overview,
    plot_calibration_analysis,
    plot_class_imbalance_analysis
)

def _save_tflite_model_and_input_mapping(working_model, model_dir):
    """
    Save the current working model as a .tflite file and its input feature mapping as JSON.
    Overwrites previous files so only the latest model is kept.
    
    Args:
        working_model: Dictionary containing model configuration, weights, and metadata
        model_dir: Directory path where model files should be saved (e.g., "trained_models/{model_id}")
        
    Returns:
        Dictionary with paths to saved files
    """
    # Create model directory if it doesn't exist
    model_path = Path(model_dir)
    model_path.mkdir(parents=True, exist_ok=True)
    
    # Extract model info
    feature_subset = working_model['feature_subset']
    model_config = working_model['model_config']
    model_weights = working_model['model_weights']
    
    # Reconstruct the model
    model = tf.keras.Model.from_config(model_config)
    model.set_weights(model_weights)
    
    # Convert to TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()
    
    # Save TFLite model
    tflite_path = model_path / "model.tflite"
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)
    
    # Create input feature mapping
    input_mapping = {}
    for idx, feature_name in enumerate(feature_subset):
        input_mapping[feature_name] = {
            "index": idx,
            "default_value": 0.0  # Default for missing features during inference
        }
    
    # Save input mapping as JSON
    mapping_path = model_path / "input_mapping.json"
    with open(mapping_path, 'w') as f:
        json.dump(input_mapping, f, indent=2)
    
    # Verify TFLite model can be loaded
    interpreter = tf.lite.Interpreter(model_content=tflite_model)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    input_shape = input_details[0]['shape']
    
    print(f"✓ TFLite model saved: {tflite_path}")
    print(f"  Input shape: {input_shape}")
    print(f"✓ Input mapping saved: {mapping_path}")
    print(f"  Features: {len(feature_subset)}")
    
    return {
        'tflite_path': str(tflite_path),
        'mapping_path': str(mapping_path),
        'input_dim': len(feature_subset),
        'feature_count': len(feature_subset)
    }


def _reconstruct_and_predict(working_model, X_test_subset):
    """
    Reconstruct model from config and weights and make predictions.
    
    Args:
        working_model: Dictionary containing model configuration and weights
        X_test_subset: Test feature DataFrame (only model's feature subset)
        
    Returns:
        Reconstructed model and predictions
    """
    # Reconstruct the model
    model = tf.keras.Model.from_config(working_model['model_config'])
    model.set_weights(working_model['model_weights'])
    
    # Get predictions
    y_pred_prob = model.predict(X_test_subset, verbose=0).flatten()
    
    return model, y_pred_prob

def _compute_comprehensive_metrics(y_test_subset, y_pred_prob, feature_subset):
    """
    Compute all comprehensive evaluation metrics using established packages.
    
    Args:
        y_test_subset: Test target values
        y_pred_prob: Predicted probabilities
        feature_subset: List of features used in the model
        
    Returns:
        Dictionary of comprehensive metrics
    """
    # Calculate optimal threshold using Youden's J statistic
    fpr, tpr, thresholds = roc_curve(y_test_subset, y_pred_prob)
    j_scores = tpr - fpr
    optimal_idx = np.argmax(j_scores)
    optimal_threshold = thresholds[optimal_idx]
    
    # Apply optimal threshold for binary predictions
    y_pred = (y_pred_prob > optimal_threshold).astype(int)
    
    # Get confusion matrix using sklearn
    tn, fp, fn, tp = confusion_matrix(y_test_subset, y_pred).ravel()
    
    # Calculate metrics using sklearn functions
    accuracy = accuracy_score(y_test_subset, y_pred)
    precision = precision_score(y_test_subset, y_pred, zero_division=0)
    recall = recall_score(y_test_subset, y_pred, zero_division=0)
    f1 = f1_score(y_test_subset, y_pred, zero_division=0)
    
    # Calculate specificity using confusion matrix values
    specificity = tn / (tn + fp) if (tn + fp) > 0 else 0
    
    # Probability distribution metrics
    class_0_probs = y_pred_prob[y_test_subset == 0]
    class_1_probs = y_pred_prob[y_test_subset == 1]
    
    mean_discrimination = np.mean(class_1_probs) - np.mean(class_0_probs) if len(class_0_probs) > 0 and len(class_1_probs) > 0 else 0
    class_0_mean = np.mean(class_0_probs) if len(class_0_probs) > 0 else 0
    class_1_mean = np.mean(class_1_probs) if len(class_1_probs) > 0 else 0
    
    # Advanced metrics using sklearn
    roc_auc = roc_auc_score(y_test_subset, y_pred_prob)
    
    # Precision-recall curve
    precision_curve, recall_curve, pr_thresholds = precision_recall_curve(y_test_subset, y_pred_prob)
    
    # Calibration metrics
    ece_metric = ECE(bins=10)
    ece = ece_metric.measure(y_pred_prob, np.array(y_test_subset))
    
    # Brier score using sklearn
    brier_score = brier_score_loss(y_test_subset, y_pred_prob)
    
    # Composite score
    ece_score = 1 - ece
    if roc_auc > 0 and ece_score > 0:
        composite_score = 2 * (roc_auc * ece_score) / (roc_auc + ece_score)
    else:
        composite_score = 0
    
    # Class distribution
    n_samples = len(y_test_subset)
    class_0_count = np.sum(y_test_subset == 0)
    class_1_count = np.sum(y_test_subset == 1)
    
    # Create comprehensive metrics dictionary
    metrics = {
        # Basic metrics
        'y_true': y_test_subset,
        'y_pred_prob': y_pred_prob,
        'optimal_threshold': optimal_threshold,
        'youden_j_statistic': j_scores[optimal_idx],
        
        # Confusion matrix
        'confusion_matrix': [[tn, fp], [fn, tp]],
        'true_negatives': int(tn),
        'false_positives': int(fp),
        'false_negatives': int(fn),
        'true_positives': int(tp),
        
        # Performance metrics (using sklearn)
        'test_accuracy': float(accuracy),
        'test_precision': float(precision),
        'test_recall': float(recall),
        'specificity': float(specificity),
        'f1_score': float(f1),
        
        # Probability metrics
        'class_0_probabilities': class_0_probs,
        'class_1_probabilities': class_1_probs,
        'mean_discrimination': float(mean_discrimination),
        'class_0_mean_prob': float(class_0_mean),
        'class_1_mean_prob': float(class_1_mean),
        'prob_std': float(np.std(y_pred_prob)),
        'prob_range': float(np.max(y_pred_prob) - np.min(y_pred_prob)),
        'prob_min': float(np.min(y_pred_prob)),
        'prob_mean': float(np.mean(y_pred_prob)),
        'prob_max': float(np.max(y_pred_prob)),
        
        # Advanced metrics (using sklearn and netcal)
        'roc_fpr': fpr,
        'roc_tpr': tpr,
        'roc_thresholds': thresholds,
        'auc_roc': float(roc_auc),
        'expected_calibration_error': float(ece),
        'brier_score': float(brier_score),
        'composite_score': float(composite_score),
        
        # Precision-recall curve (using sklearn)
        'precision_curve': precision_curve,
        'recall_curve': recall_curve,
        'pr_thresholds': pr_thresholds,
        
        # Class distribution
        'class_0_count': int(class_0_count),
        'class_1_count': int(class_1_count),
        'total_samples': int(n_samples),
        'num_features': len(feature_subset),
        
        # Overlap percentage (simplified)
        'overlap_percentage': 0.0  # Placeholder
    }
    
    return metrics

def _generate_plots(metrics, model_dir):
    """
    Generate all evaluation plots and save to model directory.
    
    Args:
        metrics: Dictionary containing evaluation metrics
        model_dir: Path to model directory for saving plots
    """
    # Create plots directory and parent directories if needed
    plots_dir = Path(model_dir) / "evaluation_plots"
    
    # Use parents=True to create parent directories if they don't exist
    plots_dir.mkdir(parents=True, exist_ok=True)
    
    save_prefix = str(plots_dir / "model_evaluation")

    # Generate each plot
    plot_roc_curve(metrics, save_prefix)
    plot_precision_recall_curve(metrics, save_prefix)
    plot_confusion_matrix(metrics, save_prefix)
    plot_probability_distributions(metrics, save_prefix)
    plot_model_performance_overview(metrics, save_prefix)
    plot_calibration_analysis(metrics, save_prefix)
    plot_class_imbalance_analysis(metrics, save_prefix)
    
    print(f"All evaluation plots saved to: {plots_dir}")

def run_full_model_evaluation(working_model, X_test, y_test, model_dir):
    """
    Run comprehensive evaluation on a model, optionally generate plots and save TFLite model.
    
    Args:
        working_model: Dictionary containing model configuration, weights, and metadata
        X_test: Test feature DataFrame (complete, no missing values)
        y_test: Test target Series
        model_dir: Optional directory for saving plots and TFLite model
        
    Returns:
        Dictionary containing comprehensive evaluation metrics and saved file info
    """
    # Extract feature subset from working model
    feature_subset = working_model['feature_subset']
    
    # Prepare test data with only the model's feature subset
    X_test_subset = X_test[feature_subset].copy()
    
    # Ensure no missing values in test subset
    if X_test_subset.isnull().any().any():
        print(f"Warning: Test subset contains missing values for features: {feature_subset}")
        X_test_subset = X_test_subset.dropna()
        y_test_subset = y_test[X_test_subset.index]
    else:
        y_test_subset = y_test
    
    # Reconstruct model and get predictions
    _, y_pred_prob = _reconstruct_and_predict(working_model, X_test_subset)
    
    # Compute comprehensive metrics
    metrics = _compute_comprehensive_metrics(y_test_subset, y_pred_prob, feature_subset)
    print(f"Got Metrics from Model: {metrics}")

    # Initialize saved_files dict
    saved_files = {}
    
    # If model_dir provided, generate plots and save TFLite model
    if model_dir:
        _generate_plots(metrics, model_dir)
        saved_files = _save_tflite_model_and_input_mapping(working_model, model_dir)
    
    # Create comprehensive results dictionary for tracking
    results = {
        # Model info
        'input_dim': working_model['input_dim'],
        'feature_count': len(feature_subset),
        
        # Test set info
        'n_samples': len(y_test_subset),
        'class_distribution': {
            0: int(np.sum(y_test_subset == 0)),
            1: int(np.sum(y_test_subset == 1))
        },
        
        # Threshold info
        'optimal_threshold': float(metrics['optimal_threshold']),
        'youden_j_statistic': float(metrics['youden_j_statistic']),
        
        # Performance metrics
        'accuracy': float(metrics['test_accuracy']),
        'precision': float(metrics['test_precision']),
        'recall': float(metrics['test_recall']),
        'specificity': float(metrics['specificity']),
        'f1_score': float(metrics['f1_score']),
        
        # Probability metrics
        'mean_discrimination': float(metrics['mean_discrimination']),
        'class_0_mean_prob': float(metrics['class_0_mean_prob']),
        'class_1_mean_prob': float(metrics['class_1_mean_prob']),
        'probability_std': float(metrics['prob_std']),
        'probability_range': float(metrics['prob_range']),
        
        # Advanced metrics
        'roc_auc': float(metrics['auc_roc']),
        'expected_calibration_error': float(metrics['expected_calibration_error']),
        'composite_score': float(metrics['composite_score']),
        
        # Feature info
        'feature_subset': feature_subset,
        
        # Saved files info (if saved)
        'saved_files': saved_files,
        
        # Timestamp
        'timestamp': pd.Timestamp.now().isoformat()
    }
    
    # Print summary
    print(f"\n{'='*60}")
    print(f"FULL MODEL EVALUATION")
    print(f"{'='*60}")
    print(f"Features: {len(feature_subset)}")
    print(f"Samples: {results['n_samples']}")
    print(f"Class distribution: 0={results['class_distribution'][0]}, 1={results['class_distribution'][1]}")
    print(f"Optimal threshold: {results['optimal_threshold']:.4f}")
    print(f"\nPerformance Metrics:")
    print(f"  Accuracy: {results['accuracy']:.4f}")
    print(f"  Precision: {results['precision']:.4f}")
    print(f"  Recall: {results['recall']:.4f}")
    print(f"  F1 Score: {results['f1_score']:.4f}")
    print(f"  ROC AUC: {results['roc_auc']:.4f}")
    print(f"  ECE: {results['expected_calibration_error']:.4f}")
    print(f"  Composite Score: {results['composite_score']:.4f}")
    print(f"\nProbability Distribution:")
    print(f"  Class 0 mean prob: {results['class_0_mean_prob']:.4f}")
    print(f"  Class 1 mean prob: {results['class_1_mean_prob']:.4f}")
    print(f"  Mean discrimination: {results['mean_discrimination']:.4f}")
    
    # Print saved file info if model was saved
    if saved_files:
        print(f"\nSaved Files:")
        print(f"  TFLite Model: {saved_files['tflite_path']}")
        print(f"  Input Mapping: {saved_files['mapping_path']}")
    
    print(f"{'='*60}")
    
    return results