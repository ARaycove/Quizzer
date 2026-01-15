import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import json
from pathlib import Path
from typing import List, Dict, Any
import pickle
import base64
# Import the existing database function from sync_fetch_data
from utility.sync_fetch_data import initialize_and_fetch_db


# For use in Phase 2 of the pipeline
def _serialize_weights(weights_list):
    """Serialize list of numpy arrays to base64 string for database storage."""
    if weights_list is None:
        return None
    # Pickle the list of numpy arrays, then base64 encode
    weights_bytes = pickle.dumps(weights_list, protocol=pickle.HIGHEST_PROTOCOL)
    return base64.b64encode(weights_bytes).decode('utf-8')

def _deserialize_weights(weights_str):
    """Deserialize base64 string back to list of numpy arrays."""
    if not weights_str:
        return None
    weights_bytes = base64.b64decode(weights_str.encode('utf-8'))
    return pickle.loads(weights_bytes)

def update_submodel_record(new_sub_model: dict, existing_record: dict) -> None:
    """
    Update the database with the better of two sub-models (new vs existing).
    
    Args:
        new_sub_model: Dictionary containing newly trained sub-model results
        existing_record: Dictionary containing existing sub-model record from database
    """
    db_conn = initialize_and_fetch_db()
    cursor = db_conn.cursor()
    
    # Extract feature set identifier
    feature_set = existing_record['feature_set']
    new_score = new_sub_model['best_score']
    new_params = new_sub_model['best_params']
    
    # Serialize new model weights if they exist (they're list of numpy arrays)
    new_weights_raw = new_sub_model.get('model_weights')
    if new_weights_raw and isinstance(new_weights_raw, list):
        new_weights_serialized = _serialize_weights(new_weights_raw)
    else:
        new_weights_serialized = new_weights_raw
    
    # Check if existing record has saved model weights/config
    existing_weights = existing_record.get('model_weights')
    existing_config = existing_record.get('model_config')
    
    existing_has_model = (existing_weights is not None and 
                         existing_config is not None and
                         existing_weights != '' and
                         existing_config != '')
    
    if not existing_has_model:
        # No existing model, use the new one
        better_score = new_score
        better_params = json.dumps(new_params)
        better_config = json.dumps(new_sub_model.get('model_config', {}))
        better_weights = new_weights_serialized
        print(f"New model selected (no existing model): {new_score:.4f}")
    else:
        # Compare scores - higher composite score is better
        existing_score = existing_record.get('composite_score', -float('inf'))
        
        if new_score > existing_score:
            # New model is better
            better_score = new_score
            better_params = json.dumps(new_params)
            better_config = json.dumps(new_sub_model.get('model_config', {}))
            better_weights = new_weights_serialized
            print(f"New model selected (score: {new_score:.4f} vs existing: {existing_score:.4f})")
        else:
            # Existing model is better
            better_score = existing_score
            better_params = existing_record.get('hyperparams', '{}')
            better_config = existing_record.get('model_config', '{}')
            better_weights = existing_record.get('model_weights', '')
            print(f"Existing model remains (score: {existing_score:.4f} vs new: {new_score:.4f})")
    
    # Always increment grid search counter
    new_search_count = existing_record.get('num_grid_searches_performed', 0) + 1
    
    # Ensure all values are strings/ints/floats for SQLite
    better_params_str = str(better_params) if better_params is not None else '{}'
    better_config_str = str(better_config) if better_config is not None else '{}'
    better_weights_str = str(better_weights) if better_weights is not None else ''
    
    # Update the database record
    cursor.execute('''
    UPDATE sub_model_results 
    SET composite_score = ?,
        hyperparams = ?,
        model_config = ?,
        model_weights = ?,
        num_grid_searches_performed = ?,
        timestamp = CURRENT_TIMESTAMP
    WHERE feature_set = ?
    ''', (float(better_score), better_params_str, better_config_str, better_weights_str, 
          int(new_search_count), str(feature_set)))
    
    db_conn.commit()
    db_conn.close()
    
    print(f"Updated {feature_set}")
    print(f"Total grid searches: {new_search_count}")


def _create_submodel_results_table(db_conn) -> None:
    """
    Create the submodel results table if it doesn't exist in the main database.
    If table exists but missing columns, add the missing columns.
    
    Args:
        db_conn: SQLite database connection from initialize_and_fetch_db
    """
    cursor = db_conn.cursor()
    
    # First, create table if it doesn't exist
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS sub_model_results (
        feature_set TEXT PRIMARY KEY,           -- Sorted, comma-separated feature list (e.g., "feature1,feature2,feature3")
        composite_score REAL,                   -- Phase 1 composite score (harmonic mean of ROC AUC and 1-ECE)
        auc_roc REAL,                          -- Phase 2 AUC-ROC score (when available)
        num_grid_searches_performed INTEGER DEFAULT 0,  -- Counter of grid search iterations performed
        model_config TEXT,                      -- JSON-serialized TensorFlow model configuration
        model_weights TEXT,                     -- JSON-serialized model weights (base64 or pickled)
        hyperparams TEXT,                       -- JSON-serialized hyperparameters from grid search
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        tier INTEGER DEFAULT 0                  -- Priority tier (0-2)
    )    
    ''')
    
    # Check if table exists (it should now, either created above or already existed)
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='sub_model_results'")
    if cursor.fetchone():
        # Check for missing columns and add them if they don't exist
        cursor.execute("PRAGMA table_info(sub_model_results)")
        existing_columns = [column[1] for column in cursor.fetchall()]
        
        # Define all required columns for Phase 1 and Phase 2
        required_columns = {
            'feature_set': 'TEXT PRIMARY KEY',
            'composite_score': 'REAL',
            'auc_roc': 'REAL',
            'num_grid_searches_performed': 'INTEGER DEFAULT 0',
            'model_config': 'TEXT',
            'model_weights': 'TEXT',
            'hyperparams': 'TEXT',
            'timestamp': 'DATETIME DEFAULT CURRENT_TIMESTAMP',
            'tier': 'INTEGER DEFAULT 0'
        }
        
        # Add missing columns - ALTER TABLE ADD COLUMN works for all except PRIMARY KEY
        for column_name, column_def in required_columns.items():
            if column_name not in existing_columns:
                print(f"Adding missing column '{column_name}' to sub_model_results table")
                
                # Remove PRIMARY KEY from column definition for ALTER TABLE
                if 'PRIMARY KEY' in column_def:
                    # For the feature_set column, we need to ensure it exists as TEXT
                    cursor.execute(f"ALTER TABLE sub_model_results ADD COLUMN {column_name} TEXT")
                    # Note: PRIMARY KEY constraint would need table recreation to add
                    # For now, we'll rely on application logic for uniqueness
                else:
                    cursor.execute(f"ALTER TABLE sub_model_results ADD COLUMN {column_name} {column_def}")
    
    db_conn.commit()

def _insert_submodel_results(db_conn, sub_model_results: List[Dict[str, Any]]) -> None:
    """
    Insert or update sub-model results into the database.
    Updates existing records with new values, preserving existing data in other columns.
    
    Args:
        db_conn: SQLite database connection
        sub_model_results: List of dictionaries with 'composite_score', 'feature_list', and 'hyperparams'
    """
    if not sub_model_results:
        return
    if sub_model_results == []:
        return
    cursor = db_conn.cursor()
    
    for result in sub_model_results:
        composite_score = result['composite_score']
        feature_list = result['feature_list']
        hyperparams = result.get('hyperparams', {})
        
        # Create sorted string representation of feature set
        feature_set_str = ','.join(sorted(feature_list))
        
        # Convert hyperparams to JSON string
        hyperparams_json = json.dumps(hyperparams)
        
        # Check if record already exists
        cursor.execute('''
        SELECT COUNT(*) FROM sub_model_results WHERE feature_set = ?
        ''', (feature_set_str,))
        
        exists = cursor.fetchone()[0] > 0
        
        if exists:
            # UPDATE existing record - only update provided fields
            cursor.execute('''
            UPDATE sub_model_results 
            SET composite_score = ?, 
                hyperparams = ?,
                timestamp = CURRENT_TIMESTAMP
            WHERE feature_set = ?
            ''', (composite_score, hyperparams_json, feature_set_str))
        else:
            # INSERT new record
            cursor.execute('''
            INSERT INTO sub_model_results 
            (feature_set, composite_score, hyperparams)
            VALUES (?, ?, ?)
            ''', (feature_set_str, composite_score, hyperparams_json))
    
    db_conn.commit()

def _analyze_submodel_scores(db_conn) -> Dict[str, Any]:
    """
    Analyze all sub-model scores in the database.
    
    Args:
        db_conn: SQLite database connection
        
    Returns:
        Dictionary containing analysis results
    """
    cursor = db_conn.cursor()
    cursor.execute('''
    SELECT composite_score, feature_set, hyperparams 
    FROM sub_model_results 
    ORDER BY composite_score DESC
    ''')
    
    all_results = cursor.fetchall()
    
    if not all_results:
        return {}
    
    # Extract scores
    scores = [row[0] for row in all_results]
    
    # Calculate statistics
    analysis = {
        'n_models': len(scores),
        'mean_score': np.mean(scores),
        'median_score': np.median(scores),
        'std_score': np.std(scores),
        'max_score': np.max(scores),
        'min_score': np.min(scores),
        'top_results': all_results[:min(10, len(all_results))],
        'all_results': all_results
    }
    
    return analysis

def _generate_submodel_histogram(analysis: Dict[str, Any], output_dir: Path) -> Path:
    """
    Generate histogram of sub-model scores.
    
    Args:
        analysis: Dictionary containing analysis results
        output_dir: Path to output directory
        
    Returns:
        Path to saved histogram
    """
    if not analysis:
        return None
    
    scores = [row[0] for row in analysis['all_results']]
    
    # Generate histogram
    plt.figure(figsize=(12, 8))
    bins = np.arange(0, 1.01, 0.01)
    n, bins, patches = plt.hist(scores, bins=bins, edgecolor='black', alpha=0.7, color='steelblue')
    
    # Add vertical lines for statistics
    plt.axvline(analysis['mean_score'], color='red', linestyle='--', 
                linewidth=2, label=f'Mean: {analysis["mean_score"]:.3f}')
    plt.axvline(analysis['median_score'], color='green', linestyle='--', 
                linewidth=2, label=f'Median: {analysis["median_score"]:.3f}')
    plt.axvline(analysis['max_score'], color='gold', linestyle='--', 
                linewidth=2, label=f'Max: {analysis["max_score"]:.3f}')
    
    # Customize plot
    plt.xlabel('Composite Score', fontsize=12)
    plt.ylabel('Number of Feature Sets', fontsize=12)
    plt.title(f'Distribution of Sub-Model Composite Scores\nTotal Feature Sets: {analysis["n_models"]}', 
              fontsize=14, pad=20)
    plt.grid(True, alpha=0.3)
    plt.legend(fontsize=10)
    
    # Add text box with statistics
    stats_text = f"""
    Statistics:
    Mean: {analysis['mean_score']:.4f}
    Median: {analysis['median_score']:.4f}
    Std Dev: {analysis['std_score']:.4f}
    Min: {analysis['min_score']:.4f}
    Max: {analysis['max_score']:.4f}
    """
    plt.text(0.02, 0.98, stats_text, transform=plt.gca().transAxes,
             fontsize=10, verticalalignment='top',
             bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.8))
    
    # Add count labels to top of bars
    max_bin_height = max(n)
    for i, count in enumerate(n):
        if count > 0 and count > max_bin_height * 0.1:
            plt.text(bins[i] + 0.005, count + 0.5, str(int(count)),
                     ha='center', va='bottom', fontsize=8, rotation=45)
    
    plt.tight_layout()
    
    # Save histogram
    histogram_path = output_dir / "sub_model_score_distribution.png"
    plt.savefig(histogram_path, dpi=150, bbox_inches='tight')
    plt.close()
    
    return histogram_path

def _save_top_feature_sets(analysis: Dict[str, Any], output_dir: Path) -> Path:
    """
    Save top feature sets to CSV.
    
    Args:
        analysis: Dictionary containing analysis results
        output_dir: Path to output directory
        
    Returns:
        Path to saved CSV
    """
    if not analysis or 'all_results' not in analysis:
        return None
    
    num_top_results = 250

    top_data = []
    for i, (score, feature_set, hyperparams_json) in enumerate(analysis['all_results'][:num_top_results], 1):
        features = feature_set.split(',')
        
        # Parse hyperparams from JSON
        try:
            hyperparams = json.loads(hyperparams_json) if hyperparams_json else {}
        except:
            hyperparams = {}
        
        top_data.append({
            'rank': i,
            'composite_score': score,
            'feature_count': len(features),
            'features': ', '.join(features),
            'hyperparams': hyperparams_json
        })
    
    csv_path = output_dir / "top_feature_sets.csv"
    pd.DataFrame(top_data).to_csv(csv_path, index=False)
    
    return csv_path

def _print_submodel_analysis(analysis: Dict[str, Any]) -> None:
    """
    Print sub-model analysis to console.
    
    Args:
        analysis: Dictionary containing analysis results
    """
    if not analysis:
        print("No sub-model results to report")
        return
    
    print(f"\n{'='*60}")
    print(f"SUB-MODEL RESULTS ANALYSIS")
    print(f"{'='*60}")
    print(f"Total unique feature sets tested: {analysis['n_models']}")
    print(f"\nScore Statistics:")
    print(f"  Mean: {analysis['mean_score']:.4f}")
    print(f"  Median: {analysis['median_score']:.4f}")
    print(f"  Std Dev: {analysis['std_score']:.4f}")
    print(f"  Min: {analysis['min_score']:.4f}")
    print(f"  Max: {analysis['max_score']:.4f}")
    
    print(f"\nTop {len(analysis['top_results'])} Feature Sets:")
    for i, (score, feature_set, hyperparams_json) in enumerate(analysis['top_results'], 1):
        features = feature_set.split(',')
        
        # Parse hyperparams for display
        try:
            hyperparams = json.loads(hyperparams_json) if hyperparams_json else {}
            hyperparams_str = json.dumps(hyperparams, indent=2)
        except:
            hyperparams_str = "No hyperparams available"
        
        print(f"  {i}. Score: {score:.4f}")
        print(f"     Features: {', '.join(features[:5])}" + 
              (f" ... +{len(features)-5} more" if len(features) > 5 else ""))
        print(f"     Hyperparams: {hyperparams_str}")
    
    print(f"{'='*60}")

def report_sub_model_results(sub_model_results: List[Dict[str, Any]] = []):
    """
    Record sub-model composite scores in the main SQLite database and generate analysis.
    
    Args:
        sub_model_results: List of dictionaries with 'composite_score', 'feature_list', and 'hyperparams'
    """
    # Connect to main database using existing function
    db_conn = initialize_and_fetch_db()
    
    try:
        # Create table if it doesn't exist
        _create_submodel_results_table(db_conn)
        
        # Insert results
        _insert_submodel_results(db_conn, sub_model_results)
        
        # Analyze all results in database
        analysis = _analyze_submodel_scores(db_conn)
        
        if not analysis:
            print("No sub-model results to report")
            return
        
        # Print analysis
        # _print_submodel_analysis(analysis)
        
        # Create output directory for plots/CSVs in trained_models root
        output_dir = Path("neural_net/prediction_net/trained_models/submodel_analysis")
        output_dir.mkdir(parents=True, exist_ok=True)
        
        # Generate histogram
        histogram_path = _generate_submodel_histogram(analysis, output_dir)
        
        # Save top feature sets to CSV
        csv_path = _save_top_feature_sets(analysis, output_dir)
        
    finally:
        db_conn.close()