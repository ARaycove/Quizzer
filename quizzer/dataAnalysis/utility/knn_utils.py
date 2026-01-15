# knn_utils.py
import numpy as np
import json
import matplotlib.pyplot as plt
from sklearn.neighbors import NearestNeighbors
from pathlib import Path
import pandas as pd

def compute_complete_pairwise_distances(embeddings, metric='manhattan'):
    """
    Computes all pairwise distances between embeddings (full distance matrix).
    
    Args:
        embeddings: numpy array of shape (n_samples, n_features)
        metric: distance metric ('manhattan', 'euclidean', 'cosine', etc.)
    
    Returns:
        distance_matrix: complete n x n distance matrix
        question_ids: list of corresponding question IDs (for reference)
    """
    n_samples = embeddings.shape[0]
    
    # Initialize distance matrix
    distance_matrix = np.zeros((n_samples, n_samples))
    
    # Use NearestNeighbors to compute all distances efficiently
    knn = NearestNeighbors(n_neighbors=n_samples, metric=metric)
    knn.fit(embeddings)
    
    # Get distances to all points (including self)
    distances, _ = knn.kneighbors(embeddings, n_neighbors=n_samples)
    
    # Fill the distance matrix
    for i in range(n_samples):
        distance_matrix[i] = distances[i]
    
    # Make sure diagonal is 0 (distance to self)
    np.fill_diagonal(distance_matrix, 0)
    
    return distance_matrix

def plot_distance_distribution(distance_matrix, output_dir="distance_plots", prefix="raw"):
    """
    Plots the distribution of distances from the complete distance matrix.
    
    Args:
        distance_matrix: n x n numpy array of distances
        output_dir: directory to save plots
        prefix: prefix for filenames (e.g., "raw", "normalized")
    """
    # Create output directory if it doesn't exist
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)
    
    # Flatten the upper triangle (excluding diagonal) to avoid double counting
    n = distance_matrix.shape[0]
    triu_indices = np.triu_indices(n, k=1)
    distances_flat = distance_matrix[triu_indices]
    
    # Create figure
    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    
    # 1. Histogram of all distances
    axes[0, 0].hist(distances_flat, bins=100, alpha=0.7, edgecolor='black')
    axes[0, 0].set_xlabel('Distance')
    axes[0, 0].set_ylabel('Frequency')
    axes[0, 0].set_title(f'Distribution of All Pairwise Distances ({prefix})')
    axes[0, 0].grid(True, alpha=0.3)
    
    # 2. Box plot
    axes[0, 1].boxplot(distances_flat, vert=True, patch_artist=True)
    axes[0, 1].set_ylabel('Distance')
    axes[0, 1].set_title(f'Box Plot of Distances ({prefix})')
    axes[0, 1].grid(True, alpha=0.3)
    
    # 3. Cumulative distribution
    sorted_dists = np.sort(distances_flat)
    cdf = np.arange(1, len(sorted_dists) + 1) / len(sorted_dists)
    axes[1, 0].plot(sorted_dists, cdf, linewidth=2)
    axes[1, 0].set_xlabel('Distance')
    axes[1, 0].set_ylabel('Cumulative Probability')
    axes[1, 0].set_title(f'Cumulative Distribution Function ({prefix})')
    axes[1, 0].grid(True, alpha=0.3)
    
    # 4. Log-scale histogram for tail behavior
    axes[1, 1].hist(distances_flat, bins=100, alpha=0.7, edgecolor='black', log=True)
    axes[1, 1].set_xlabel('Distance')
    axes[1, 1].set_ylabel('Frequency (log scale)')
    axes[1, 1].set_title(f'Log-Scale Distribution ({prefix})')
    axes[1, 1].grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(output_path / f"{prefix}_distance_distribution.png", dpi=150, bbox_inches='tight')
    plt.close()
    
    # Also save statistics to a CSV file
    stats = {
        'mean': np.mean(distances_flat),
        'median': np.median(distances_flat),
        'std': np.std(distances_flat),
        'min': np.min(distances_flat),
        'max': np.max(distances_flat),
        'q25': np.percentile(distances_flat, 25),
        'q75': np.percentile(distances_flat, 75),
        'total_pairs': len(distances_flat)
    }
    
    stats_df = pd.DataFrame([stats])
    stats_df.to_csv(output_path / f"{prefix}_distance_stats.csv", index=False)
    
    return stats

def compute_knn_model(embeddings, k=25, metric='manhattan'):
    """
    Computes and returns a fitted K-nearest neighbors model.
    
    Args:
        embeddings: numpy array of shape (n_samples, n_features)
        k: number of nearest neighbors to compute
        metric: distance metric ('manhattan', 'euclidean', 'cosine')
    
    Returns:
        knn_model: fitted NearestNeighbors model
    """
    knn_model = NearestNeighbors(n_neighbors=k, metric=metric)
    knn_model.fit(embeddings)
    return knn_model

def update_knn_vectors_locally(db, question_ids, knn_model, embeddings):
    """
    Updates KNN vectors in database only for records that have actually changed.
    
    Args:
        db: SQLite database connection
        question_ids: list of question_ids corresponding to the embeddings
        knn_model: fitted NearestNeighbors model
        embeddings: numpy array of embeddings used to fit the model
    
    Returns:
        tuple: (changed_records, total_records)
        - changed_records: list of question_ids that were updated
        - total_records: total number of records processed
    """
    # Compute distances and indices for all embeddings
    distances, indices = knn_model.kneighbors(embeddings)
    
    cursor = db.cursor()
    
    # Ensure column exists
    cursor.execute("PRAGMA table_info(question_answer_pairs)")
    columns = [col[1] for col in cursor.fetchall()]
    
    if 'k_nearest_neighbors' not in columns:
        cursor.execute("ALTER TABLE question_answer_pairs ADD COLUMN k_nearest_neighbors TEXT")
    
    db.commit()
    
    changed_records = []
    total_records = len(question_ids)
    
    for i, question_id in enumerate(question_ids):
        # Create new neighbors map with distances
        new_neighbors_map = {
            question_ids[idx]: float(dist) 
            for idx, dist in zip(indices[i], distances[i])
        }
        new_neighbors_json = json.dumps(new_neighbors_map, sort_keys=True)
        
        # Get current KNN from database
        cursor.execute("""
            SELECT k_nearest_neighbors FROM question_answer_pairs 
            WHERE question_id = ?
        """, (question_id,))
        result = cursor.fetchone()
        
        if result and result[0]:
            # Parse existing map
            existing_neighbors_map = json.loads(result[0])
            
            # Compare the two maps directly
            if existing_neighbors_map == new_neighbors_map:
                # No change, skip update
                continue
        
        # Update database with new KNN vector
        cursor.execute("""
            UPDATE question_answer_pairs 
            SET k_nearest_neighbors = ?
            WHERE question_id = ?
        """, (new_neighbors_json, question_id))
        
        changed_records.append(question_id)
    
    db.commit()
    
    if changed_records:
        print(f"Updated {len(changed_records)}/{total_records} records with new KNN vectors")
        print(f"Records needing server reset: {len(changed_records)}")
    else:
        print(f"No KNN vectors changed. All {total_records} records unchanged.")
    
    return changed_records, total_records