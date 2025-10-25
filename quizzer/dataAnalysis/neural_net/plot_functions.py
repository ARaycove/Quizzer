from sklearn.metrics import ConfusionMatrixDisplay
from sklearn.calibration import calibration_curve
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np

def question_type_distribution_bar_chart(df: pd.DataFrame, save_prefix: str = 'question_type_dist'):
    """Bar chart of count by question_type from one-hot encoded columns."""
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

def plot_roc_curve(metrics, save_prefix):
    """Plot ROC curve with threshold analysis."""
    plt.figure(figsize=(20, 5))
    
    # Subplot 1: ROC Curve
    plt.subplot(1, 5, 1)
    plt.plot(metrics['roc_fpr'], metrics['roc_tpr'], linewidth=2, 
             label=f'ROC Curve (AUC = {metrics["auc_roc"]:.3f})')
    plt.plot([0, 1], [0, 1], 'k--', linewidth=1, label='Random Classifier')
    plt.xlabel('False Positive Rate')
    plt.ylabel('True Positive Rate')
    plt.title('ROC Curve')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    # Subplot 2: FPR vs Threshold
    plt.subplot(1, 5, 2)
    plt.plot(metrics['roc_thresholds'], metrics['roc_fpr'], label='FPR')
    plt.xlabel('Threshold')
    plt.ylabel('False Positive Rate')
    plt.title('FPR vs Threshold')
    plt.grid(True, alpha=0.3)
    
    # Subplot 3: TPR vs Threshold
    plt.subplot(1, 5, 3)
    plt.plot(metrics['roc_thresholds'], metrics['roc_tpr'], label='TPR')
    plt.xlabel('Threshold')
    plt.ylabel('True Positive Rate')
    plt.title('TPR vs Threshold')
    plt.grid(True, alpha=0.3)
    
    # Subplot 4: Youden's J
    plt.subplot(1, 5, 4)
    youden_j = metrics['roc_tpr'] - metrics['roc_fpr']
    max_youden_idx = np.argmax(youden_j)
    max_youden_threshold = metrics['roc_thresholds'][max_youden_idx]
    plt.plot(metrics['roc_thresholds'], youden_j, label="Youden J Statistic")
    plt.axvline(max_youden_threshold, color='red', linestyle='--', 
               label=f'Optimal: {max_youden_threshold:.3f}')
    plt.xlabel('Threshold')
    plt.ylabel("Youden J (TPR - FPR)")
    plt.title('Optimal Threshold Selection')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    # Subplot 5: Distance to Perfect Classifier
    plt.subplot(1, 5, 5)
    distance = np.sqrt((1 - metrics['roc_tpr'])**2 + metrics['roc_fpr']**2)
    min_distance_idx = np.argmin(distance)
    min_distance_threshold = metrics['roc_thresholds'][min_distance_idx]
    plt.plot(metrics['roc_thresholds'], distance, label='Distance to Perfect')
    plt.axvline(min_distance_threshold, color='red', linestyle='--',
               label=f'Closest: {min_distance_threshold:.3f}')
    plt.xlabel('Threshold')
    plt.ylabel('Distance to Perfect Classifier')
    plt.title('Distance to Perfect Classifier')
    plt.ylim(0, 1)
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(f'{save_prefix}_roc_analysis.png', dpi=300, bbox_inches='tight')
    plt.close()

def plot_precision_recall_curve(metrics, save_prefix):
    """Plot Precision-Recall curve."""
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

def plot_confusion_matrix(metrics, save_prefix):
    """Plot confusion matrix."""
    plt.figure(figsize=(6, 5))
    disp = ConfusionMatrixDisplay(confusion_matrix=metrics['confusion_matrix'], 
                                  display_labels=['Incorrect', 'Correct'])
    disp.plot(cmap='Blues')
    plt.title('Confusion Matrix')
    plt.savefig(f'{save_prefix}_confusion_matrix.png', dpi=300, bbox_inches='tight')
    plt.close()

def plot_probability_distributions(metrics, save_prefix):
    """Plot probability distributions by class with histogram, boxplot, and scatter."""
    plt.figure(figsize=(18, 6))
    
    # Subplot 1: Histograms
    plt.subplot(1, 3, 1)
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
    plt.subplot(1, 3, 2)
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
    
    # Subplot 3: Scatter plot
    plt.subplot(1, 3, 3)
    
    y_true = metrics['y_true']
    y_pred_prob = metrics['y_pred_prob']
    
    # Add jitter to y-axis for better visualization
    y_jitter = y_true + np.random.normal(0, 0.20, len(y_true))
    
    scatter = plt.scatter(y_pred_prob, y_jitter, c=y_true, cmap='RdYlBu', 
                         alpha=0.6, s=20)
    
    plt.xlabel('Predicted Probability')
    plt.ylabel('Actual Class (with jitter)')
    plt.title('Predicted Probability vs Actual Class')
    plt.colorbar(scatter, label='Actual Class')
    plt.axvline(x=0.5, color='red', linestyle='--', alpha=0.7, label='Decision Threshold')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(f'{save_prefix}_probability_distributions.png', dpi=300, bbox_inches='tight')
    plt.close()

def plot_model_performance_overview(metrics, save_prefix):
    """Plot comprehensive model performance overview."""
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
        plt.title('Discrimination Metrics')
        for bar, val in zip(bars, disc_metrics):
            plt.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.01, 
                    f'{val:.3f}', ha='center', va='bottom')
    
    plt.tight_layout()
    plt.savefig(f'{save_prefix}_model_performance_overview.png', dpi=300, bbox_inches='tight')
    plt.close()

def plot_calibration_analysis(metrics, save_prefix):
    """Plot combined calibration analysis with calibration curve, Brier score, and quality assessment."""
    plt.figure(figsize=(18, 6))
    
    # Subplot 1: Calibration curve
    plt.subplot(1, 3, 1)
    n_bins = 10
    prob_true, prob_pred = calibration_curve(metrics['y_true'], metrics['y_pred_prob'], 
                                             n_bins=n_bins, strategy='uniform')
    plt.plot(prob_pred, prob_true, marker='o', linewidth=2, label='Model Calibration')
    plt.plot([0, 1], [0, 1], linestyle='--', color='gray', label='Perfect Calibration')
    plt.xlabel('Mean Predicted Probability')
    plt.ylabel('Fraction of Positives')
    plt.title(f'Calibration Curve (Brier Score: {metrics["brier_score"]:.3f})')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    # Subplot 2: Brier score components
    plt.subplot(1, 3, 2)
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
    
    # Subplot 3: Calibration quality assessment
    plt.subplot(1, 3, 3)
    ece_threshold = 0.1
    calib_quality = ['Well Calibrated'] if metrics['brier_score'] < ece_threshold else ['Poorly Calibrated']
    calib_colors = ['green'] if metrics['brier_score'] < ece_threshold else ['red']
    plt.bar(calib_quality, [metrics['brier_score']], color=calib_colors, alpha=0.7)
    plt.axhline(y=ece_threshold, color='orange', linestyle='--', label=f'Good Calibration Threshold ({ece_threshold})')
    plt.ylabel('Brier Score')
    plt.title('Calibration Quality Assessment')
    plt.legend()
    
    plt.tight_layout()
    plt.savefig(f'{save_prefix}_calibration_analysis.png', dpi=300, bbox_inches='tight')
    plt.close()


def plot_class_imbalance_analysis(metrics, save_prefix, samples_per_feature_threshold=100):
    """Plot class imbalance analysis."""
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
    samples_per_feature = metrics['total_samples'] / metrics['num_features']
    efficiency_color = 'green' if samples_per_feature >= samples_per_feature_threshold else 'red'
    plt.bar(['Samples per\nFeature'], [samples_per_feature], color=efficiency_color, alpha=0.7)
    plt.axhline(y=samples_per_feature_threshold, color='orange', linestyle='--', 
               label=f'Ideal Threshold ({samples_per_feature_threshold})')
    plt.ylabel('Ratio')
    plt.title(f'Data Efficiency\n({samples_per_feature:.2f} samples/feature)')
    plt.legend()
    
    plt.tight_layout()
    plt.savefig(f'{save_prefix}_class_imbalance_analysis.png', dpi=300, bbox_inches='tight')
    plt.close()