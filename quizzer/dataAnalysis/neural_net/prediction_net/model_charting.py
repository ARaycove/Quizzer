import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


def update_performance_chart(rolling_results, model_id, model_dir):
    """
    Create dynamic performance charts showing historical progression of model metrics.
    
    Args:
        rolling_results: List of dictionaries, each containing evaluation metrics for one iteration
        model_id: UUID string for model directory
        
    Returns:
        Path to saved chart file
    """
    if not rolling_results:
        print("No results to plot")
        return None
    
    # Create model directory
    model_dir.mkdir(parents=True, exist_ok=True)
    
    # Extract scalar numeric metrics (excluding nested dicts, lists, and non-numeric values)
    scalar_metrics = {}
    
    # Get all possible metric keys from the first result
    first_result = rolling_results[0]
    
    for key, value in first_result.items():
        # Check if value is scalar numeric (int, float, bool) and not a collection
        if isinstance(value, (int, float, bool, np.number)):
            # Ensure it's not a path or ID
            if not any(excluded in key.lower() for excluded in ['id', 'timestamp', 'path', 'file']):
                scalar_metrics[key] = []
    
    # Collect metric values across all iterations
    for result in rolling_results:
        for metric in list(scalar_metrics.keys()):
            if metric in result:
                value = result[metric]
                # Convert bool to 0/1 for plotting
                if isinstance(value, bool):
                    scalar_metrics[metric].append(1 if value else 0)
                else:
                    scalar_metrics[metric].append(float(value))
            else:
                scalar_metrics[metric].append(np.nan)
    
    # Filter out metrics with no valid data
    valid_metrics = {}
    for metric, values in scalar_metrics.items():
        # Remove NaN values and check if we have valid data
        clean_values = [v for v in values if not np.isnan(v)]
        if clean_values and len(set(clean_values)) > 1:  # More than one unique value
            valid_metrics[metric] = values
    
    if not valid_metrics:
        print("No valid numeric metrics to plot")
        return None
    
    # Calculate grid dimensions for subplots
    n_metrics = len(valid_metrics)
    n_cols = min(4, int(np.ceil(np.sqrt(n_metrics))))
    n_rows = int(np.ceil(n_metrics / n_cols))
    
    # Create figure with subplots
    fig, axes = plt.subplots(n_rows, n_cols, figsize=(6 * n_cols, 4 * n_rows))
    fig.suptitle(f'Model Performance Progression\nModel ID: {model_id}', fontsize=16, y=1.02)
    
    # Flatten axes array for easy iteration
    if n_rows == 1 and n_cols == 1:
        axes = np.array([axes])
    axes_flat = axes.flatten()
    
    # Plot each metric
    for idx, (metric, values) in enumerate(sorted(valid_metrics.items())):
        ax = axes_flat[idx]
        
        # Prepare data
        iterations = list(range(1, len(values) + 1))
        clean_values = []
        clean_iterations = []
        
        # Remove NaN values for plotting
        for i, val in enumerate(values):
            if not np.isnan(val):
                clean_iterations.append(i + 1)
                clean_values.append(val)
        
        # Plot line
        ax.plot(clean_iterations, clean_values, marker='o', linewidth=2, markersize=6)
        
        # Formatting
        ax.set_title(metric.replace('_', ' ').title(), fontsize=12)
        ax.set_xlabel('Iteration', fontsize=10)
        ax.set_ylabel('Value', fontsize=10)
        ax.grid(True, alpha=0.3)
        
        # Add value labels for last point
        if clean_values:
            last_val = clean_values[-1]
            last_iter = clean_iterations[-1]
            ax.annotate(f'{last_val:.4f}', 
                       xy=(last_iter, last_val),
                       xytext=(5, 5),
                       textcoords='offset points',
                       fontsize=9,
                       bbox=dict(boxstyle='round,pad=0.3', fc='yellow', alpha=0.7))
        
        # Adjust y-axis limits with padding
        if clean_values:
            y_min, y_max = min(clean_values), max(clean_values)
            y_range = y_max - y_min
            padding = y_range * 0.1 if y_range > 0 else 0.1
            ax.set_ylim(y_min - padding, y_max + padding)
    
    # Hide unused subplots
    for idx in range(len(valid_metrics), len(axes_flat)):
        axes_flat[idx].set_visible(False)
    
    # Adjust layout
    plt.tight_layout()
    
    # Save plot
    chart_path = model_dir / 'performance_progression.png'
    plt.savefig(chart_path, dpi=150, bbox_inches='tight')
    plt.close(fig)
    
    print(f"Performance chart saved to: {chart_path}")
    
    # Also save CSV data for reference
    csv_path = model_dir / 'performance_data.csv'
    data_for_csv = {'iteration': list(range(1, len(rolling_results) + 1))}
    data_for_csv.update(valid_metrics)
    pd.DataFrame(data_for_csv).to_csv(csv_path, index=False)
    
    return chart_path