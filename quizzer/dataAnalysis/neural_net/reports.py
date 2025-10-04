import pandas as pd
from typing import List, Dict, Any
from sklearn.ensemble import RandomForestClassifier
from sklearn.feature_selection import mutual_info_classif
from sklearn.metrics import (classification_report, confusion_matrix, f1_score, roc_auc_score, 
                           roc_curve, precision_recall_curve, brier_score_loss)
from sklearn.metrics import f1_score, accuracy_score, precision_score, recall_score
from sklearn.metrics import ConfusionMatrixDisplay
import datetime
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

def question_type_distribution_bar_chart(df: pd.DataFrame, save_prefix: str = 'question_type_dist'):
    """Bar chart of count by question_type from one-hot encoded columns."""
    import matplotlib.pyplot as plt
    
    qt_cols = [col for col in df.columns if col.startswith('question_type_')]
    
    if not qt_cols:
        print("No question_type columns found")
        return
    
    counts = {col.replace('question_type_', ''): df[col].sum() for col in qt_cols}
    
    plt.figure(figsize=(10, 6))
    plt.bar(counts.keys(), counts.values(), color='steelblue', alpha=0.7)
    plt.xlabel('Question Type')
    plt.ylabel('Count')
    plt.title('Question Distribution by Type')
    plt.xticks(rotation=45, ha='right')
    plt.tight_layout()
    plt.savefig(f'{save_prefix}.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    print(f"Question type distribution saved to {save_prefix}.png")

def create_comprehensive_visualizations(metrics, save_prefix=None):
    """
    Creates comprehensive visualizations from model analytics metrics.
    
    Args:
        metrics: Dictionary from model_analytics_report function
        save_prefix: Prefix for saved files (default: auto-generated timestamp)
    """
    
    # Generate save prefix if not provided
    if save_prefix is None:
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        save_prefix = f"model_analysis_{timestamp}"
    
    # Set style
    plt.style.use('default')
    sns.set_palette("husl")
    
    # 1. ROC Curve
    plt.figure(figsize=(8, 6))
    plt.plot(metrics['roc_fpr'], metrics['roc_tpr'], linewidth=2, 
             label=f'ROC Curve (AUC = {metrics["auc_roc"]:.3f})')
    plt.plot([0, 1], [0, 1], 'k--', linewidth=1, label='Random Classifier')
    plt.xlabel('False Positive Rate')
    plt.ylabel('True Positive Rate')
    plt.title('ROC Curve')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.savefig(f'{save_prefix}_roc_curve.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # 2. Precision-Recall Curve
    plt.figure(figsize=(8, 6))
    plt.plot(metrics['recall_curve'], metrics['precision_curve'], linewidth=2,
             label=f'PR Curve')
    plt.xlabel('Recall')
    plt.ylabel('Precision')
    plt.title('Precision-Recall Curve')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.savefig(f'{save_prefix}_precision_recall_curve.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # 3. Confusion Matrix
    plt.figure(figsize=(6, 5))
    disp = ConfusionMatrixDisplay(confusion_matrix=metrics['confusion_matrix'], 
                                  display_labels=['Incorrect', 'Correct'])
    disp.plot(cmap='Blues')
    plt.title('Confusion Matrix')
    plt.savefig(f'{save_prefix}_confusion_matrix.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # 4. Probability Distribution by Class (KEY CHART YOU REQUESTED)
    plt.figure(figsize=(12, 6))
    
    # Subplot 1: Histograms
    plt.subplot(1, 2, 1)
    if len(metrics['class_0_probabilities']) > 0:
        plt.hist(metrics['class_0_probabilities'], bins=20, alpha=0.7, 
                label=f'Incorrect (Class 0) - {len(metrics["class_0_probabilities"])} samples', 
                color='red', density=True)
    if len(metrics['class_1_probabilities']) > 0:
        plt.hist(metrics['class_1_probabilities'], bins=20, alpha=0.7,
                label=f'Correct (Class 1) - {len(metrics["class_1_probabilities"])} samples', 
                color='blue', density=True)
    plt.xlabel('Predicted Probability')
    plt.ylabel('Density')
    plt.title('Probability Distribution by Class')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    # Subplot 2: Box plots
    plt.subplot(1, 2, 2)
    box_data = []
    labels = []
    if len(metrics['class_0_probabilities']) > 0:
        box_data.append(metrics['class_0_probabilities'])
        labels.append('Incorrect\n(Class 0)')
    if len(metrics['class_1_probabilities']) > 0:
        box_data.append(metrics['class_1_probabilities'])
        labels.append('Correct\n(Class 1)')
    
    if box_data:
        plt.boxplot(box_data, labels=labels)
        plt.ylabel('Predicted Probability')
        plt.title('Probability Range by Class')
        plt.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(f'{save_prefix}_probability_distributions.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # 5. Probability Range Visualization
    plt.figure(figsize=(10, 6))
    ranges = ['0.0-0.2', '0.2-0.4', '0.4-0.6', '0.6-0.8', '0.8-1.0']
    
    # Calculate range distributions
    range_counts = []
    for low, high in [(0.0, 0.2), (0.2, 0.4), (0.4, 0.6), (0.6, 0.8), (0.8, 1.0)]:
        count = ((metrics['y_pred_prob'] >= low) & (metrics['y_pred_prob'] < high)).sum()
        range_counts.append(count)
    
    bars = plt.bar(ranges, range_counts, color='steelblue', alpha=0.7)
    plt.xlabel('Probability Range')
    plt.ylabel('Number of Predictions')
    plt.title('Distribution of Predictions Across Probability Ranges')
    plt.grid(True, alpha=0.3, axis='y')
    
    # Add value labels on bars
    for bar, count in zip(bars, range_counts):
        plt.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5, 
                str(count), ha='center', va='bottom')
    
    plt.savefig(f'{save_prefix}_probability_ranges.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # 6. Class-specific Percentile Analysis
    plt.figure(figsize=(10, 6))
    percentile_labels = ['10th', '25th', '50th', '75th', '90th']
    
    x = np.arange(len(percentile_labels))
    width = 0.35
    
    if len(metrics['class_0_probabilities']) > 0 and len(metrics['class_1_probabilities']) > 0:
        bars1 = plt.bar(x - width/2, metrics['class_0_percentiles'], width, 
                       label='Incorrect (Class 0)', color='red', alpha=0.7)
        bars2 = plt.bar(x + width/2, metrics['class_1_percentiles'], width,
                       label='Correct (Class 1)', color='blue', alpha=0.7)
        
        plt.xlabel('Percentiles')
        plt.ylabel('Probability')
        plt.title('Percentile Analysis by Class')
        plt.xticks(x, percentile_labels)
        plt.legend()
        plt.grid(True, alpha=0.3, axis='y')
    
    plt.savefig(f'{save_prefix}_percentile_analysis.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # 7. Performance Metrics Summary
    plt.figure(figsize=(12, 8))
    
    # Create metrics summary
    metric_names = ['Accuracy', 'Precision', 'Recall', 'F1-Score', 'AUC-ROC']
    metric_values = [metrics['test_accuracy'], metrics['test_precision'], 
                    metrics['test_recall'], metrics['f1_score'], metrics['auc_roc']]
    
    plt.subplot(2, 2, 1)
    bars = plt.bar(metric_names, metric_values, color='lightcoral', alpha=0.8)
    plt.ylim(0, 1)
    plt.ylabel('Score')
    plt.title('Performance Metrics')
    plt.xticks(rotation=45)
    for bar, value in zip(bars, metric_values):
        plt.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.01, 
                f'{value:.3f}', ha='center', va='bottom')
    
    # Probability statistics
    plt.subplot(2, 2, 2)
    prob_stats = [metrics['prob_min'], metrics['prob_mean'], metrics['prob_max']]
    stat_names = ['Min', 'Mean', 'Max']
    plt.bar(stat_names, prob_stats, color='lightblue', alpha=0.8)
    plt.ylabel('Probability')
    plt.title('Probability Statistics')
    for i, (name, value) in enumerate(zip(stat_names, prob_stats)):
        plt.text(i, value + 0.01, f'{value:.3f}', ha='center', va='bottom')
    
    # Class distribution
    plt.subplot(2, 2, 3)
    class_counts = [metrics['class_0_count'], metrics['class_1_count']]
    class_labels = ['Incorrect\n(Class 0)', 'Correct\n(Class 1)']
    colors = ['red', 'blue']
    plt.bar(class_labels, class_counts, color=colors, alpha=0.7)
    plt.ylabel('Sample Count')
    plt.title('Class Distribution')
    for i, count in enumerate(class_counts):
        plt.text(i, count + 0.5, str(count), ha='center', va='bottom')
    
    # Discrimination metrics
    plt.subplot(2, 2, 4)
    if not np.isnan(metrics['mean_discrimination']):
        disc_metrics = [metrics['mean_discrimination'], metrics['overlap_percentage']/100]
        disc_labels = ['Mean\nDiscrimination', 'Overlap\nPercentage']
        colors = ['green' if metrics['mean_discrimination'] > 0 else 'red', 
                 'red' if metrics['overlap_percentage'] > 50 else 'green']
        bars = plt.bar(disc_labels, disc_metrics, color=colors, alpha=0.7)
        plt.ylabel('Value')
        plt.title('Discrimination Analysis')
        for bar, value in zip(bars, disc_metrics):
            plt.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.005, 
                    f'{value:.3f}', ha='center', va='bottom')
    
    plt.tight_layout()
    plt.savefig(f'{save_prefix}_performance_summary.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # 8. Threshold Analysis
    plt.figure(figsize=(12, 6))
    
    # Calculate metrics at different thresholds
    thresholds = np.linspace(0, 1, 101)
    accuracies = []
    precisions = []
    recalls = []
    f1_scores = []
    
    for threshold in thresholds:
        y_pred_thresh = (metrics['y_pred_prob'] >= threshold).astype(int)
        
        # Calculate confusion matrix elements
        tp = ((metrics['y_true'] == 1) & (y_pred_thresh == 1)).sum()
        tn = ((metrics['y_true'] == 0) & (y_pred_thresh == 0)).sum()
        fp = ((metrics['y_true'] == 0) & (y_pred_thresh == 1)).sum()
        fn = ((metrics['y_true'] == 1) & (y_pred_thresh == 0)).sum()
        
        # Calculate metrics
        acc = (tp + tn) / (tp + tn + fp + fn) if (tp + tn + fp + fn) > 0 else 0
        prec = tp / (tp + fp) if (tp + fp) > 0 else 0
        rec = tp / (tp + fn) if (tp + fn) > 0 else 0
        f1 = 2 * prec * rec / (prec + rec) if (prec + rec) > 0 else 0
        
        accuracies.append(acc)
        precisions.append(prec)
        recalls.append(rec)
        f1_scores.append(f1)
    
    plt.plot(thresholds, accuracies, label='Accuracy', linewidth=2)
    plt.plot(thresholds, precisions, label='Precision', linewidth=2)
    plt.plot(thresholds, recalls, label='Recall', linewidth=2)
    plt.plot(thresholds, f1_scores, label='F1-Score', linewidth=2)
    plt.axvline(x=0.5, color='red', linestyle='--', alpha=0.7, label='Default Threshold (0.5)')
    
    plt.xlabel('Threshold')
    plt.ylabel('Metric Value')
    plt.title('Performance Metrics vs. Threshold')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.savefig(f'{save_prefix}_threshold_analysis.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # 9. Prediction Scatter Plot
    plt.figure(figsize=(10, 6))
    
    # Create scatter plot of predictions
    y_true = metrics['y_true']
    y_pred_prob = metrics['y_pred_prob']
    
    # Add jitter to y-axis for better visualization
    y_jitter = y_true + np.random.normal(0, 0.05, len(y_true))
    
    scatter = plt.scatter(y_pred_prob, y_jitter, c=y_true, cmap='RdYlBu', 
                         alpha=0.6, s=20)
    plt.xlabel('Predicted Probability')
    plt.ylabel('Actual Class (with jitter)')
    plt.title('Predicted Probability vs Actual Class')
    plt.colorbar(scatter, label='Actual Class')
    plt.axvline(x=0.5, color='red', linestyle='--', alpha=0.7, label='Decision Threshold')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.savefig(f'{save_prefix}_prediction_scatter.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # 10. Calibration Plot
    plt.figure(figsize=(8, 8))
    
    # Create calibration plot
    n_bins = 10
    bin_boundaries = np.linspace(0, 1, n_bins + 1)
    bin_lowers = bin_boundaries[:-1]
    bin_uppers = bin_boundaries[1:]
    
    ece = 0  # Expected Calibration Error
    bin_accuracies = []
    bin_confidences = []
    bin_counts = []
    
    for bin_lower, bin_upper in zip(bin_lowers, bin_uppers):
        in_bin = (metrics['y_pred_prob'] > bin_lower) & (metrics['y_pred_prob'] <= bin_upper)
        prop_in_bin = in_bin.mean()
        
        if prop_in_bin > 0:
            accuracy_in_bin = metrics['y_true'][in_bin].mean()
            avg_confidence_in_bin = metrics['y_pred_prob'][in_bin].mean()
            ece += np.abs(avg_confidence_in_bin - accuracy_in_bin) * prop_in_bin
            
            bin_accuracies.append(accuracy_in_bin)
            bin_confidences.append(avg_confidence_in_bin)
            bin_counts.append(in_bin.sum())
        else:
            bin_accuracies.append(0)
            bin_confidences.append(0)
            bin_counts.append(0)
    
    # Plot calibration
    plt.plot([0, 1], [0, 1], 'k--', label='Perfect Calibration')
    plt.bar(bin_confidences, bin_accuracies, width=0.1, alpha=0.7, 
           label=f'Model (ECE = {ece:.3f})', edgecolor='black')
    
    plt.xlabel('Mean Predicted Probability')
    plt.ylabel('Fraction of Positives')
    plt.title('Calibration Plot')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.savefig(f'{save_prefix}_calibration_plot.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # 11. ROC Thresholds Analysis
    plt.figure(figsize=(12, 8))
    
    # Ensure arrays match by taking minimum length
    min_len = min(len(metrics['roc_thresholds']), len(metrics['roc_fpr']), len(metrics['roc_tpr']))
    thresholds_plot = metrics['roc_thresholds'][:min_len]
    fpr_plot = metrics['roc_fpr'][:min_len]
    tpr_plot = metrics['roc_tpr'][:min_len]
    
    plt.subplot(2, 2, 1)
    plt.plot(thresholds_plot, fpr_plot, label='False Positive Rate')
    plt.xlabel('Threshold')
    plt.ylabel('False Positive Rate')
    plt.title('FPR vs Threshold')
    plt.grid(True, alpha=0.3)
    
    plt.subplot(2, 2, 2)
    plt.plot(thresholds_plot, tpr_plot, label='True Positive Rate')
    plt.xlabel('Threshold')
    plt.ylabel('True Positive Rate')
    plt.title('TPR vs Threshold')
    plt.grid(True, alpha=0.3)
    
    plt.subplot(2, 2, 3)
    youden_j = tpr_plot - fpr_plot
    optimal_idx = np.argmax(youden_j)
    optimal_threshold = thresholds_plot[optimal_idx]
    plt.plot(thresholds_plot, youden_j, label='Youden J Statistic')
    plt.axvline(optimal_threshold, color='red', linestyle='--', label=f'Optimal: {optimal_threshold:.3f}')
    plt.xlabel('Threshold')
    plt.ylabel('Youden J (TPR - FPR)')
    plt.title('Optimal Threshold Selection')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    plt.subplot(2, 2, 4)
    distance_to_perfect = np.sqrt((1 - tpr_plot)**2 + fpr_plot**2)
    closest_idx = np.argmin(distance_to_perfect)
    closest_threshold = thresholds_plot[closest_idx]
    plt.plot(thresholds_plot, distance_to_perfect, label='Distance to Perfect')
    plt.axvline(closest_threshold, color='red', linestyle='--', label=f'Closest: {closest_threshold:.3f}')
    plt.xlabel('Threshold')
    plt.ylabel('Distance to Perfect Classifier')
    plt.title('Distance to Perfect Classifier')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(f'{save_prefix}_roc_threshold_analysis.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # 12. Precision-Recall Thresholds Analysis
    plt.figure(figsize=(12, 6))
    
    plt.subplot(1, 3, 1)
    plt.plot(metrics['pr_thresholds'], metrics['precision_curve'][:-1], label='Precision')
    plt.xlabel('Threshold')
    plt.ylabel('Precision')
    plt.title('Precision vs Threshold')
    plt.grid(True, alpha=0.3)
    
    plt.subplot(1, 3, 2)
    plt.plot(metrics['pr_thresholds'], metrics['recall_curve'][:-1], label='Recall')
    plt.xlabel('Threshold')
    plt.ylabel('Recall')
    plt.title('Recall vs Threshold')
    plt.grid(True, alpha=0.3)
    
    plt.subplot(1, 3, 3)
    f1_curve = 2 * (metrics['precision_curve'][:-1] * metrics['recall_curve'][:-1]) / (metrics['precision_curve'][:-1] + metrics['recall_curve'][:-1])
    f1_curve = np.nan_to_num(f1_curve)
    max_f1_idx = np.argmax(f1_curve)
    max_f1_threshold = metrics['pr_thresholds'][max_f1_idx]
    plt.plot(metrics['pr_thresholds'], f1_curve, label='F1-Score')
    plt.axvline(max_f1_threshold, color='red', linestyle='--', label=f'Max F1: {max_f1_threshold:.3f}')
    plt.xlabel('Threshold')
    plt.ylabel('F1-Score')
    plt.title('F1-Score vs Threshold')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(f'{save_prefix}_pr_threshold_analysis.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # 13. Overlap Analysis Visualization
    plt.figure(figsize=(12, 8))
    
    plt.subplot(2, 2, 1)
    # Overlap percentage pie chart
    if not np.isnan(metrics['overlap_percentage']):
        overlap_pct = metrics['overlap_percentage']
        perfect_pct = 100 - overlap_pct
        plt.pie([perfect_pct, overlap_pct], labels=[f'Perfect Separation\n({perfect_pct:.1f}%)', 
                                                   f'Overlap\n({overlap_pct:.1f}%)'], 
                colors=['green', 'red'], autopct='%1.1f%%')
        plt.title('Class Separation Analysis')
    
    plt.subplot(2, 2, 2)
    # Perfect separation indicator
    separation_status = ['Perfect Separation'] if metrics['perfect_separation'] else ['Has Overlap']
    separation_colors = ['green'] if metrics['perfect_separation'] else ['red']
    plt.bar(separation_status, [1], color=separation_colors, alpha=0.7)
    plt.ylabel('Status')
    plt.title('Perfect Separation Status')
    plt.ylim(0, 1.2)
    
    plt.subplot(2, 2, 3)
    # Separation boundaries
    if not np.isnan(metrics['max_class_0_prob']) and not np.isnan(metrics['min_class_1_prob']):
        boundaries = [metrics['max_class_0_prob'], metrics['min_class_1_prob']]
        labels = ['Max Class 0\nProbability', 'Min Class 1\nProbability']
        colors = ['red', 'blue']
        bars = plt.bar(labels, boundaries, color=colors, alpha=0.7)
        plt.ylabel('Probability')
        plt.title('Class Boundary Analysis')
        for bar, val in zip(bars, boundaries):
            plt.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.01, 
                    f'{val:.3f}', ha='center', va='bottom')
        
        # Add gap visualization
        if metrics['perfect_separation']:
            gap = metrics['min_class_1_prob'] - metrics['max_class_0_prob']
            plt.text(0.5, max(boundaries) + 0.05, f'Separation Gap: {gap:.3f}', 
                    ha='center', va='bottom', fontweight='bold', color='green')
    
    plt.subplot(2, 2, 4)
    # Overlap count visualization
    if not np.isnan(metrics['overlap_count']):
        total_comparisons = len(metrics['class_0_probabilities']) * len(metrics['class_1_probabilities'])
        perfect_comparisons = total_comparisons - metrics['overlap_count']
        plt.bar(['Perfect\nComparisons', 'Overlap\nComparisons'], 
               [perfect_comparisons, metrics['overlap_count']], 
               color=['green', 'red'], alpha=0.7)
        plt.ylabel('Number of Comparisons')
        plt.title(f'Overlap Count Analysis\n(Total: {total_comparisons})')
    
    plt.tight_layout()
    plt.savefig(f'{save_prefix}_overlap_analysis.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # 14. Brier Score and Calibration Metrics
    plt.figure(figsize=(10, 6))
    
    plt.subplot(1, 2, 1)
    # Brier score components
    reliability = 0  # Simplified - would need bin analysis for true reliability
    resolution = np.var(metrics['y_true'])
    uncertainty = np.mean(metrics['y_true']) * (1 - np.mean(metrics['y_true']))
    
    components = [metrics['brier_score'], uncertainty]
    labels = ['Brier Score\n(Lower is Better)', 'Base Rate\nUncertainty']
    colors = ['red' if metrics['brier_score'] > uncertainty else 'green', 'blue']
    
    bars = plt.bar(labels, components, color=colors, alpha=0.7)
    plt.ylabel('Score')
    plt.title('Brier Score Analysis')
    for bar, val in zip(bars, components):
        plt.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.005, 
                f'{val:.3f}', ha='center', va='bottom')
    
    plt.subplot(1, 2, 2)
    # Calibration quality indicator
    ece_threshold = 0.1  # Common threshold for good calibration
    calib_quality = ['Well Calibrated'] if metrics['brier_score'] < ece_threshold else ['Poorly Calibrated']
    calib_colors = ['green'] if metrics['brier_score'] < ece_threshold else ['red']
    plt.bar(calib_quality, [metrics['brier_score']], color=calib_colors, alpha=0.7)
    plt.axhline(y=ece_threshold, color='orange', linestyle='--', label=f'Good Calibration Threshold ({ece_threshold})')
    plt.ylabel('Brier Score')
    plt.title('Calibration Quality Assessment')
    plt.legend()
    
    plt.tight_layout()
    plt.savefig(f'{save_prefix}_calibration_metrics.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # 15. Class Imbalance Analysis
    plt.figure(figsize=(12, 6))
    
    plt.subplot(1, 3, 1)
    # Class distribution pie chart
    class_counts = [metrics['class_0_count'], metrics['class_1_count']]
    class_labels = [f'Incorrect\n({metrics["class_0_count"]} samples)', 
                   f'Correct\n({metrics["class_1_count"]} samples)']
    plt.pie(class_counts, labels=class_labels, colors=['red', 'blue'], autopct='%1.1f%%')
    plt.title('Class Distribution')
    
    plt.subplot(1, 3, 2)
    # Imbalance ratio
    imbalance_ratio = max(class_counts) / min(class_counts) if min(class_counts) > 0 else float('inf')
    plt.bar(['Imbalance Ratio'], [imbalance_ratio], color='orange', alpha=0.7)
    plt.ylabel('Ratio')
    plt.title(f'Class Imbalance Ratio\n({imbalance_ratio:.1f}:1)')
    plt.text(0, imbalance_ratio + 0.1, f'{imbalance_ratio:.1f}:1', ha='center', va='bottom')
    
    plt.subplot(1, 3, 3)
    # Sample efficiency
    samples_per_feature = metrics['total_samples'] / 1231  # Using your mentioned feature count
    efficiency_threshold = 1.0  # 1 sample per feature threshold
    efficiency_color = 'green' if samples_per_feature >= efficiency_threshold else 'red'
    plt.bar(['Samples per\nFeature'], [samples_per_feature], color=efficiency_color, alpha=0.7)
    plt.axhline(y=efficiency_threshold, color='orange', linestyle='--', label=f'Ideal Threshold ({efficiency_threshold})')
    plt.ylabel('Ratio')
    plt.title(f'Data Efficiency\n({samples_per_feature:.2f} samples/feature)')
    plt.legend()
    
    plt.tight_layout()
    plt.savefig(f'{save_prefix}_class_imbalance_analysis.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    print(f"All visualizations saved with prefix: {save_prefix}")
    print("Generated files:")
    print(f"  - {save_prefix}_roc_curve.png")
    print(f"  - {save_prefix}_precision_recall_curve.png")
    print(f"  - {save_prefix}_confusion_matrix.png")
    print(f"  - {save_prefix}_probability_distributions.png")
    print(f"  - {save_prefix}_probability_ranges.png")
    print(f"  - {save_prefix}_percentile_analysis.png")
    print(f"  - {save_prefix}_performance_summary.png")
    print(f"  - {save_prefix}_threshold_analysis.png")
    print(f"  - {save_prefix}_prediction_scatter.png")
    print(f"  - {save_prefix}_calibration_plot.png")
    print(f"  - {save_prefix}_roc_threshold_analysis.png")
    print(f"  - {save_prefix}_pr_threshold_analysis.png")
    print(f"  - {save_prefix}_overlap_analysis.png")
    print(f"  - {save_prefix}_calibration_metrics.png")
    print(f"  - {save_prefix}_class_imbalance_analysis.png")
    
    return save_prefix

def analyze_feature_imbalance(df: pd.DataFrame) -> None:
    """Comprehensive feature imbalance analysis for response_result prediction."""
    target = 'response_result'
    X = df.drop(columns=[target])
    y = df[target]
    
    # Class distribution
    class_counts = y.value_counts()
    class_ratios = y.value_counts(normalize=True)
    
    # Feature variance by class
    variance_by_class = {}
    for class_val in y.unique():
        class_mask = y == class_val
        variance_by_class[class_val] = X[class_mask].var()
    
    # Features with high class-conditional variance differences
    variance_diff = abs(variance_by_class[0] - variance_by_class[1]).sort_values(ascending=False)
    
    # Missing value patterns by class
    missing_by_class = {}
    for class_val in y.unique():
        class_mask = y == class_val
        missing_by_class[class_val] = X[class_mask].isnull().sum()
    
    # Zero-value patterns by class
    zero_patterns = {}
    for class_val in y.unique():
        class_mask = y == class_val
        zero_patterns[class_val] = (X[class_mask] == 0).sum()
    
    # Feature means by class
    means_by_class = {}
    for class_val in y.unique():
        class_mask = y == class_val
        means_by_class[class_val] = X[class_mask].mean()
    
    # Feature distributions by class for visualization
    feature_stats = {}
    for feature in X.columns:
        stats = {}
        for class_val in y.unique():
            class_mask = y == class_val
            feature_data = X[class_mask][feature]
            stats[f'class_{class_val}_mean'] = feature_data.mean()
            stats[f'class_{class_val}_std'] = feature_data.std()
            stats[f'class_{class_val}_zero_pct'] = (feature_data == 0).mean()
        feature_stats[feature] = stats
    
    # Output comprehensive report
    with open("feature_imbalance_report.txt", 'w') as f:
        f.write("=" * 80 + "\n")
        f.write("COMPREHENSIVE FEATURE IMBALANCE ANALYSIS\n")
        f.write("=" * 80 + "\n")
        f.write(f"Dataset: {len(df)} samples, {len(X.columns)} features\n")
        f.write(f"Target: {target}\n\n")
        
        f.write("CLASS DISTRIBUTION:\n")
        for class_val, count in class_counts.items():
            ratio = class_ratios[class_val]
            f.write(f"  Class {class_val}: {count:,} samples ({ratio:.1%})\n")
        f.write(f"  Imbalance ratio: {class_counts.max()/class_counts.min():.1f}:1\n\n")
        
        f.write("TOP 30 FEATURES WITH HIGHEST CLASS VARIANCE DIFFERENCES:\n")
        for i, (feature, diff) in enumerate(variance_diff.head(30).items(), 1):
            f.write(f"{i:2d}. {feature:<50} | {diff:.6f}\n")
        
        f.write("\nFEATURE MEANS BY CLASS (Top 20 differences):\n")
        mean_diffs = abs(means_by_class[0] - means_by_class[1]).sort_values(ascending=False)
        for i, (feature, diff) in enumerate(mean_diffs.head(20).items(), 1):
            mean_0 = means_by_class[0][feature]
            mean_1 = means_by_class[1][feature]
            f.write(f"{i:2d}. {feature:<40} | Class 0: {mean_0:.4f} | Class 1: {mean_1:.4f} | Diff: {diff:.4f}\n")
        
        f.write("\nMISSING VALUE PATTERNS BY CLASS:\n")
        missing_diffs = abs(missing_by_class[0] - missing_by_class[1]).sort_values(ascending=False)
        for feature in missing_diffs[missing_diffs > 0].head(10).index:
            miss_0 = missing_by_class[0][feature]
            miss_1 = missing_by_class[1][feature]
            f.write(f"{feature:<40} | Class 0: {miss_0:4d} | Class 1: {miss_1:4d}\n")
        
        f.write("\nZERO VALUE PATTERNS BY CLASS (Top 20):\n")
        zero_diffs = abs(zero_patterns[0] - zero_patterns[1]).sort_values(ascending=False)
        for i, (feature, diff) in enumerate(zero_diffs.head(20).items(), 1):
            zero_0 = zero_patterns[0][feature]
            zero_1 = zero_patterns[1][feature]
            f.write(f"{i:2d}. {feature:<40} | Class 0: {zero_0:4d} | Class 1: {zero_1:4d}\n")
        
        # Feature prefix analysis
        f.write("\nFEATURE IMBALANCE BY PREFIX:\n")
        prefix_imbalance = {}
        for feature in X.columns:
            if '_' in feature:
                prefix = feature.split('_')[0]
                if prefix not in prefix_imbalance:
                    prefix_imbalance[prefix] = []
                mean_diff = abs(means_by_class[0][feature] - means_by_class[1][feature])
                prefix_imbalance[prefix].append(mean_diff)
        
        prefix_avg_imbalance = {prefix: np.mean(diffs) for prefix, diffs in prefix_imbalance.items()}
        prefix_sorted = sorted(prefix_avg_imbalance.items(), key=lambda x: x[1], reverse=True)
        
        for i, (prefix, avg_imbalance) in enumerate(prefix_sorted, 1):
            count = len(prefix_imbalance[prefix])
            f.write(f"{i:2d}. {prefix:<20} | Avg Mean Diff: {avg_imbalance:.4f} ({count:4d} features)\n")
    
    # Create visualizations
    fig, ((ax1, ax2), (ax3, ax4), (ax5, ax6)) = plt.subplots(3, 2, figsize=(16, 18))
    
    # 1. Class distribution
    class_counts.plot(kind='bar', ax=ax1, color=['skyblue', 'lightcoral'])
    ax1.set_title('Class Distribution')
    ax1.set_ylabel('Count')
    ax1.set_xlabel('Response Result')
    
    # 2. Top variance differences
    variance_diff.head(15).plot(kind='barh', ax=ax2)
    ax2.set_title('Top 15 Features - Variance Differences Between Classes')
    ax2.set_xlabel('Variance Difference')
    
    # 3. Mean differences heatmap (top features)
    top_features = mean_diffs.head(20).index
    heatmap_data = []
    for feature in top_features:
        heatmap_data.append([means_by_class[0][feature], means_by_class[1][feature]])
    
    sns.heatmap(np.array(heatmap_data), 
                xticklabels=['Class 0', 'Class 1'],
                yticklabels=[f.split('_')[0] + '_...' if len(f) > 15 else f for f in top_features],
                annot=True, fmt='.3f', ax=ax3, cmap='RdBu_r')
    ax3.set_title('Feature Means by Class (Top 20)')
    
    # 4. Zero value patterns
    zero_diff_top = zero_diffs.head(15)
    zero_diff_top.plot(kind='barh', ax=ax4, color='orange')
    ax4.set_title('Top 15 Features - Zero Value Count Differences')
    ax4.set_xlabel('Zero Count Difference')
    
    # 5. Prefix imbalance
    prefix_df = pd.DataFrame(prefix_sorted[:15], columns=['Prefix', 'Avg_Imbalance'])
    sns.barplot(data=prefix_df, x='Avg_Imbalance', y='Prefix', ax=ax5, palette='viridis')
    ax5.set_title('Feature Imbalance by Prefix (Top 15)')
    ax5.set_xlabel('Average Mean Difference')
    
    # 6. Imbalance distribution
    all_mean_diffs = abs(means_by_class[0] - means_by_class[1])
    ax6.hist(all_mean_diffs.values, bins=50, alpha=0.7, color='purple')
    ax6.set_title('Distribution of Mean Differences Across All Features')
    ax6.set_xlabel('Mean Difference')
    ax6.set_ylabel('Feature Count')
    
    plt.tight_layout()
    plt.savefig('feature_imbalance_analysis.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    print("Feature imbalance analysis saved to feature_imbalance_report.txt")
    print("Visualizations saved to feature_imbalance_analysis.png")
    print(f"Most imbalanced prefix: {prefix_sorted[0][0]} (avg diff: {prefix_sorted[0][1]:.4f})")
    print(f"Class imbalance ratio: {class_counts.max()/class_counts.min():.1f}:1")

def feature_importance_analysis(df: pd.DataFrame, target_col: str, filename: str = "feature_importance_analysis.txt") -> None:
    """
    Analyzes feature characteristics using correlation and mutual information before model training.
    
    Args:
        df: DataFrame with features and target
        target_col: Name of target column (e.g., 'response_result')
        filename: Output filename
    """
    X = df.drop(columns=[target_col])
    y = df[target_col]
    
    print(f"Running feature analysis on {X.shape[1]} features...")
    
    # Correlation with target
    correlations = X.corrwith(y).abs().sort_values(ascending=False)
    
    # Mutual Information
    mi_scores = mutual_info_classif(X, y, random_state=42)
    mi_importance = pd.Series(mi_scores, index=X.columns).sort_values(ascending=False)
    
    # Feature variance
    variances = X.var().sort_values(ascending=False)
    
    # Identify noise features (low correlation AND low MI)
    corr_threshold = correlations.quantile(0.25)
    mi_threshold = mi_importance.quantile(0.25)
    noise_features = X.columns[(correlations < corr_threshold) & (mi_importance < mi_threshold)]
    
    # Feature prefix analysis
    prefix_importance = {}
    for feature in X.columns:
        if '_' in feature:
            prefix = feature.split('_')[0]
            if prefix not in prefix_importance:
                prefix_importance[prefix] = []
            prefix_importance[prefix].append(mi_importance[feature])
    
    prefix_means = {prefix: np.mean(scores) for prefix, scores in prefix_importance.items()}
    prefix_means_sorted = sorted(prefix_means.items(), key=lambda x: x[1], reverse=True)
    
    with open(filename, 'w') as f:
        f.write("=" * 80 + "\n")
        f.write("FEATURE ANALYSIS (PRE-TRAINING)\n")
        f.write("=" * 80 + "\n")
        f.write(f"Dataset: {X.shape[0]} samples x {X.shape[1]} features\n")
        f.write(f"Target: {target_col}\n")
        f.write(f"Target distribution: {y.value_counts().to_dict()}\n")
        f.write("=" * 80 + "\n\n")
        
        f.write("TOP 50 FEATURES - CORRELATION WITH TARGET\n")
        f.write("-" * 60 + "\n")
        for i, (feature, corr) in enumerate(correlations.head(50).items(), 1):
            f.write(f"{i:2d}. {feature:<45} | {corr:.6f}\n")
        
        f.write("\n" + "=" * 80 + "\n")
        
        f.write("TOP 50 FEATURES - MUTUAL INFORMATION\n")
        f.write("-" * 60 + "\n")
        for i, (feature, mi_score) in enumerate(mi_importance.head(50).items(), 1):
            f.write(f"{i:2d}. {feature:<45} | {mi_score:.6f}\n")
        
        f.write("\n" + "=" * 80 + "\n")
        
        f.write("FEATURE IMPORTANCE BY PREFIX (Mean MI)\n")
        f.write("-" * 60 + "\n")
        for i, (prefix, mean_importance) in enumerate(prefix_means_sorted, 1):
            count = len(prefix_importance[prefix])
            f.write(f"{i:2d}. {prefix:<20} | {mean_importance:.6f} ({count:4d} features)\n")
        
        f.write("\n" + "=" * 80 + "\n")
        
        module_features = [f for f in X.columns if f.startswith('mvec_')]
        if module_features:
            f.write("TOP MODULE PERFORMANCE FEATURES\n")
            f.write("-" * 60 + "\n")
            module_importance = mi_importance[module_features].head(20)
            for i, (feature, importance) in enumerate(module_importance.items(), 1):
                f.write(f"{i:2d}. {feature:<45} | {importance:.6f}\n")
            f.write("\n" + "=" * 80 + "\n")
        
        f.write("POTENTIAL NOISE FEATURES (Low Correlation & Low MI)\n")
        f.write(f"Threshold: Corr < {corr_threshold:.6f}, MI < {mi_threshold:.6f}\n")
        f.write(f"Total: {len(noise_features)} features\n")
        f.write("-" * 60 + "\n")
        for i, feature in enumerate(sorted(noise_features), 1):
            corr_val = correlations[feature]
            mi_val = mi_importance[feature]
            f.write(f"{i:2d}. {feature:<45} | Corr: {corr_val:.6f} | MI: {mi_val:.6f}\n")
    
    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(16, 12))
    
    correlations.head(20).plot(kind='barh', ax=ax1)
    ax1.set_title('Top 20 Features - Correlation with Target')
    ax1.set_xlabel('Correlation')
    
    mi_importance.head(20).plot(kind='barh', ax=ax2)
    ax2.set_title('Top 20 Features - Mutual Information')
    ax2.set_xlabel('MI Score')
    
    prefix_df = pd.DataFrame(prefix_means_sorted[:15], columns=['Prefix', 'Mean_Importance'])
    sns.barplot(data=prefix_df, x='Mean_Importance', y='Prefix', ax=ax3)
    ax3.set_title('Feature Importance by Prefix')
    
    ax4.hist(mi_importance.values, bins=50, alpha=0.7)
    ax4.set_title('Distribution of MI Scores')
    ax4.set_xlabel('MI Score')
    ax4.set_ylabel('Frequency')
    
    plt.tight_layout()
    chart_filename = filename.replace('.txt', '_charts.png')
    plt.savefig(chart_filename, dpi=300, bbox_inches='tight')
    plt.close()
    
    print(f"Feature analysis saved to {filename}")
    print(f"Visualization saved to {chart_filename}")
    print(f"Top 3 feature prefixes: {[p[0] for p in prefix_means_sorted[:3]]}")
    print(f"Most important single feature: {mi_importance.index[0]} ({mi_importance.iloc[0]:.6f})")
    print(f"Potential noise features identified: {len(noise_features)}")

def save_feature_analysis(df: pd.DataFrame, filename: str = "feature_analysis.txt") -> None:
    """
    Saves a feature analysis table to a text file showing feature name, sample value, and data type.
    Sorted by type: non-numeric first, then int, then float.
    
    Args:
        df: DataFrame to analyze
        filename: Output filename (default: "feature_analysis.txt")
    """
    feature_data = []
    
    for col in df.columns:
        # Get first non-null value as sample
        sample_val = df[col].dropna().iloc[0] if not df[col].dropna().empty else "NULL"
        data_type = str(df[col].dtype)
        
        # Truncate long values
        if isinstance(sample_val, str) and len(sample_val) > 25:
            sample_val = sample_val[:25] + "..."
        
        # Categorize types for sorting
        if 'int' in data_type.lower():
            sort_order = 2
        elif 'float' in data_type.lower():
            sort_order = 3
        else:
            sort_order = 1  # Non-numeric types first
        
        feature_data.append((sort_order, col, str(sample_val), data_type))
    
    # Sort by type category, then alphabetically within each type
    feature_data.sort(key=lambda x: (x[0], x[1]))
    
    # Count features by type
    non_numeric_count = sum(1 for x in feature_data if x[0] == 1)
    int_count = sum(1 for x in feature_data if x[0] == 2)
    float_count = sum(1 for x in feature_data if x[0] == 3)
    
    # Calculate memory usage
    memory_usage_mb = df.memory_usage(deep=True).sum() / (1024 * 1024)
    
    with open(filename, 'w') as f:
        # Write header with metadata
        f.write("=" * 80 + "\n")
        f.write("FEATURE ANALYSIS REPORT\n")
        f.write("=" * 80 + "\n")
        f.write(f"Dataset Shape: {df.shape[0]:,} rows x {df.shape[1]:,} columns\n")
        f.write(f"Total Features: {len(df.columns):,}\n")
        f.write(f"Memory Usage: {memory_usage_mb:.2f} MB\n")
        f.write(f"\nFeature Type Breakdown:\n")
        f.write(f"  Non-numeric: {non_numeric_count:,}\n")
        f.write(f"  Integer:     {int_count:,}\n")
        f.write(f"  Float:       {float_count:,}\n")
        f.write(f"\nNull Value Summary:\n")
        f.write(f"  Total null values: {df.isnull().sum().sum():,}\n")
        f.write(f"  Columns with nulls: {(df.isnull().sum() > 0).sum():,}\n")
        f.write("=" * 80 + "\n\n")
        
        # Write feature table
        f.write("| feature_name | value | type |\n")
        f.write("|" + "-" * 50 + "|" + "-" * 30 + "|" + "-" * 15 + "|\n")
        
        for _, col, sample_val, data_type in feature_data:
            f.write(f"| {col:<48} | {sample_val:<28} | {data_type:<13} |\n")
    
    print(f"Feature analysis saved to {filename}")
    print(f"Report summary: {df.shape[0]:,} rows, {df.shape[1]:,} features, {memory_usage_mb:.1f}MB")


def model_analytics_report(interpreter, X_test, y_test, save_to_file=True, filename=None):
    """
    Comprehensive evaluation and analysis of TFLite model performance on test set.
    
    Args:
        interpreter: TFLite interpreter
        X_test: Test features
        y_test: Test targets
        save_to_file: Whether to save output to file
        filename: Custom filename (default: auto-generated with timestamp)
        
    Returns:
        Dictionary with ALL metrics for comprehensive analysis
    """
    
    # Generate filename if not provided
    if save_to_file and filename is None:
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"model_analytics_report_{timestamp}.txt"
    
    def print_and_write(text, file_handle=None):
        """Print to console and optionally write to file."""
        print(text)
        if file_handle:
            file_handle.write(text + "\n")
    
    # Get input/output details
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    # Get predictions using TFLite interpreter
    y_pred_prob = []
    for i in range(len(X_test)):
        input_data = X_test.iloc[i:i+1].values.astype(np.float32)
        interpreter.set_tensor(input_details[0]['index'], input_data)
        interpreter.invoke()
        output_data = interpreter.get_tensor(output_details[0]['index'])
        y_pred_prob.append(output_data[0])
    
    y_pred_prob = np.array(y_pred_prob)
    y_pred_prob_flat = y_pred_prob.flatten()
    y_pred = (y_pred_prob_flat > 0.5).astype(int)
    
    # Open file if saving
    file_handle = open(filename, 'w', encoding='utf-8') if save_to_file else None
    
    try:
        # Test set evaluation
        header = "\n" + "="*60 + "\nFINAL TEST SET EVALUATION\n" + "="*60
        print_and_write(header, file_handle)
        
        # Calculate comprehensive metrics
        test_accuracy = accuracy_score(y_test, y_pred)
        test_precision = precision_score(y_test, y_pred)
        test_recall = recall_score(y_test, y_pred)
        f1 = f1_score(y_test, y_pred)
        auc = roc_auc_score(y_test, y_pred_prob_flat)
        conf_matrix = confusion_matrix(y_test, y_pred)
        class_report = classification_report(y_test, y_pred)
        
        # ROC curve data
        fpr, tpr, roc_thresholds = roc_curve(y_test, y_pred_prob_flat)
        
        # Precision-Recall curve data
        precision_curve, recall_curve, pr_thresholds = precision_recall_curve(y_test, y_pred_prob_flat)
        
        # Calibration metrics
        brier_score = brier_score_loss(y_test, y_pred_prob_flat)
        
        # Class distributions
        class_0_count = (y_test == 0).sum()
        class_1_count = (y_test == 1).sum()
        
        # Analyze predictions by actual class
        incorrect_mask = (y_test == 0)
        correct_mask = (y_test == 1)
        
        incorrect_probs = y_pred_prob_flat[incorrect_mask.values]
        correct_probs = y_pred_prob_flat[correct_mask.values]
        
        # Overlap analysis - key metric for discrimination
        if len(incorrect_probs) > 0 and len(correct_probs) > 0:
            overlap_count = 0
            for inc_prob in incorrect_probs:
                overlap_count += (correct_probs < inc_prob).sum()
            
            total_comparisons = len(incorrect_probs) * len(correct_probs)
            overlap_percentage = (overlap_count / total_comparisons) * 100 if total_comparisons > 0 else 0
            
            max_class_0 = incorrect_probs.max() if len(incorrect_probs) > 0 else 0
            min_class_1 = correct_probs.min() if len(correct_probs) > 0 else 1
            perfect_separation = max_class_0 < min_class_1
        else:
            overlap_count = 0
            overlap_percentage = 0
            max_class_0 = 0
            min_class_1 = 1
            perfect_separation = True
        
        # Percentile analysis
        if len(incorrect_probs) > 0:
            class_0_percentiles = np.percentile(incorrect_probs, [10, 25, 50, 75, 90])
        else:
            class_0_percentiles = np.array([0, 0, 0, 0, 0])
            
        if len(correct_probs) > 0:
            class_1_percentiles = np.percentile(correct_probs, [10, 25, 50, 75, 90])
        else:
            class_1_percentiles = np.array([0, 0, 0, 0, 0])
        
        # Print results
        results_text = f"""Test Accuracy: {test_accuracy:.4f}
Test Precision: {test_precision:.4f}
Test Recall: {test_recall:.4f}
Test F1-Score: {f1:.4f}
Test AUC-ROC: {auc:.4f}
Brier Score: {brier_score:.4f}

Confusion Matrix:
{conf_matrix}

Classification Report:
{class_report}"""
        
        print_and_write(results_text, file_handle)
        
        # Detailed prediction analysis
        analysis_header = "\nPREDICTION ANALYSIS:\n" + "-" * 40
        print_and_write(analysis_header, file_handle)
        
        # Overall probability distribution
        prob_dist = f"""Overall Probability Distribution:
  Min: {y_pred_prob_flat.min():.4f}
  Max: {y_pred_prob_flat.max():.4f}
  Mean: {y_pred_prob_flat.mean():.4f}
  Std: {y_pred_prob_flat.std():.4f}"""
        
        print_and_write(prob_dist, file_handle)
        
        # Class-specific analysis
        class_header = "\nCLASS-SPECIFIC PREDICTION ANALYSIS:\n" + "-" * 40
        print_and_write(class_header, file_handle)
        
        if len(incorrect_probs) > 0:
            incorrect_text = f"""INCORRECT ANSWERS (Class 0) - {len(incorrect_probs)} samples:
  Min: {incorrect_probs.min():.4f}
  Max: {incorrect_probs.max():.4f}
  Mean: {incorrect_probs.mean():.4f}
  Std: {incorrect_probs.std():.4f}
  Percentiles [10,25,50,75,90]: {class_0_percentiles}"""
        else:
            incorrect_text = "INCORRECT ANSWERS (Class 0): No samples in test set"
        
        print_and_write(incorrect_text, file_handle)
        
        if len(correct_probs) > 0:
            correct_text = f"""
CORRECT ANSWERS (Class 1) - {len(correct_probs)} samples:
  Min: {correct_probs.min():.4f}
  Max: {correct_probs.max():.4f}
  Mean: {correct_probs.mean():.4f}
  Std: {correct_probs.std():.4f}
  Percentiles [10,25,50,75,90]: {class_1_percentiles}"""
        else:
            correct_text = "CORRECT ANSWERS (Class 1): No samples in test set"
        
        print_and_write(correct_text, file_handle)
        
        # Discrimination analysis
        if len(incorrect_probs) > 0 and len(correct_probs) > 0:
            mean_diff = correct_probs.mean() - incorrect_probs.mean()
            discrimination_text = f"""
DISCRIMINATION ANALYSIS:
  Mean probability difference (Correct - Incorrect): {mean_diff:.4f}
  Overlap analysis: {overlap_count}/{total_comparisons} comparisons ({overlap_percentage:.2f}%)
  Perfect separation: {perfect_separation}
  Max Class 0 probability: {max_class_0:.4f}
  Min Class 1 probability: {min_class_1:.4f}"""
            if mean_diff > 0:
                discrimination_text += "\n  ✓ Model assigns higher probabilities to correct answers"
            else:
                discrimination_text += "\n  ✗ Model assigns higher probabilities to incorrect answers"
            
            print_and_write(discrimination_text, file_handle)
        
        # Show probability ranges
        ranges = [(0.0, 0.2), (0.2, 0.4), (0.4, 0.6), (0.6, 0.8), (0.8, 1.0)]
        range_header = "\nProbability Range Distribution:"
        print_and_write(range_header, file_handle)
        
        for low, high in ranges:
            count = ((y_pred_prob_flat >= low) & (y_pred_prob_flat < high)).sum()
            pct = count / len(y_pred_prob_flat) * 100
            range_text = f"  {low:.1f}-{high:.1f}: {count:3d} samples ({pct:5.1f}%)"
            print_and_write(range_text, file_handle)
        
        # Sample predictions table
        sample_header = "\nSample Predictions (first 20):\nProbability | Actual | Predicted\n" + "-" * 35
        print_and_write(sample_header, file_handle)
        
        for i in range(min(20, len(y_test))):
            prob = y_pred_prob_flat[i]
            actual = y_test.iloc[i]
            pred = "Correct" if prob > 0.5 else "Incorrect"
            sample_text = f"    {prob:.4f}  |   {actual}    |  {pred}"
            print_and_write(sample_text, file_handle)
        
        if save_to_file:
            print(f"\nReport saved to: {filename}")
        
    finally:
        if file_handle:
            file_handle.close()
    
    # Return ALL metrics for comprehensive analysis
    return {
        'test_accuracy': test_accuracy,
        'test_precision': test_precision,
        'test_recall': test_recall,
        'f1_score': f1,
        'auc_roc': auc,
        'brier_score': brier_score,
        'confusion_matrix': conf_matrix,
        'y_pred_prob': y_pred_prob_flat,
        'y_pred': y_pred,
        'y_true': y_test.values,
        'class_0_probabilities': incorrect_probs,
        'class_1_probabilities': correct_probs,
        'prob_min': y_pred_prob_flat.min(),
        'prob_max': y_pred_prob_flat.max(),
        'prob_mean': y_pred_prob_flat.mean(),
        'prob_std': y_pred_prob_flat.std(),
        'prob_range': y_pred_prob_flat.max() - y_pred_prob_flat.min(),
        'class_0_mean': incorrect_probs.mean() if len(incorrect_probs) > 0 else np.nan,
        'class_0_std': incorrect_probs.std() if len(incorrect_probs) > 0 else np.nan,
        'class_1_mean': correct_probs.mean() if len(correct_probs) > 0 else np.nan,
        'class_1_std': correct_probs.std() if len(correct_probs) > 0 else np.nan,
        'mean_discrimination': correct_probs.mean() - incorrect_probs.mean() if len(incorrect_probs) > 0 and len(correct_probs) > 0 else np.nan,
        'class_0_count': class_0_count,
        'class_1_count': class_1_count,
        'total_samples': len(y_test),
        'class_0_percentiles': class_0_percentiles,
        'class_1_percentiles': class_1_percentiles,
        'overlap_count': overlap_count,
        'overlap_percentage': overlap_percentage,
        'perfect_separation': perfect_separation,
        'max_class_0_prob': max_class_0,
        'min_class_1_prob': min_class_1,
        'roc_fpr': fpr,
        'roc_tpr': tpr,
        'roc_thresholds': roc_thresholds,
        'precision_curve': precision_curve,
        'recall_curve': recall_curve,
        'pr_thresholds': pr_thresholds
    }