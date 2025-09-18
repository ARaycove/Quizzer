import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from umap import UMAP
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score

def umap_plot(df, max_k, filename, min_k=2, k_clusters=None):
    """
    Conducts UMAP plotting with varying n_neighbors parameter from min_k to max_k.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        Input dataframe containing numerical and non-numerical columns
    max_k : int
        Maximum n_neighbors value to test (plots from min_k to max_k)
    filename : str
        Base filename for saving plots (without extension)
    min_k : int, optional
        Minimum n_neighbors value to test (default: 2)
    k_clusters : int, optional
        If provided, bypasses optimal cluster heuristic and uses this number directly
    
    Returns:
    --------
    pandas.DataFrame
        Original dataframe with added cluster_id column
    """
    
    # Identify numerical columns dynamically
    numerical_cols = df.select_dtypes(include=[np.number]).columns.tolist()
    
    if len(numerical_cols) == 0:
        raise ValueError("No numerical columns found in the dataframe")
    
    # Extract and scale numerical data
    X = df[numerical_cols].copy()
    X = X.fillna(X.mean())
    
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    # Copy dataframe for modification
    df_result = df.copy()
    
    # Calculate grid dimensions
    k_values = list(range(min_k, max_k + 1))
    n_plots = len(k_values)
    plots_per_image = 5
    
    print(f"Starting UMAP analysis for k values from {min_k} to {max_k}")
    if k_clusters:
        print(f"Using fixed cluster count: {k_clusters}")
    else:
        print("Using optimal cluster heuristic")
    print(f"Total plots to generate: {n_plots}")
    
    current_batch = []
    batch_num = 1
    
    for i, k in enumerate(k_values):
        print(f"Processing UMAP with n_neighbors={k} ({i+1}/{n_plots})")
        
        # Perform UMAP with current n_neighbors value
        umap_reducer = UMAP(
            n_components=3,  # 3D projection instead of 2D
            n_neighbors=min(k, len(X_scaled) - 1),
            min_dist=0.1,
            init='random',
            n_jobs=1
        )
        
        X_umap = umap_reducer.fit_transform(X_scaled)
        
        # Determine number of clusters
        if k_clusters:
            # Use provided k_clusters directly
            best_k = k_clusters
            kmeans = KMeans(n_clusters=best_k, random_state=42, n_init=10)
            cluster_labels = kmeans.fit_predict(X_umap)
            
            # Calculate silhouette score for reporting
            if len(set(cluster_labels)) > 1:
                best_score = silhouette_score(X_umap, cluster_labels)
            else:
                best_score = 0.0
            
        else:
            # Use optimal cluster heuristic
            # Run a quick elbow analysis to find where improvement drops off
            inertias = []
            test_range = range(2, min(21, len(X_umap) // 2))  # Quick test up to 20 clusters
            
            for test_k in test_range:
                kmeans_test = KMeans(n_clusters=test_k, random_state=42, n_init=3)
                kmeans_test.fit(X_umap)
                inertias.append(kmeans_test.inertia_)
            
            # Find elbow point - where rate of improvement drops significantly
            if len(inertias) >= 3:
                improvements = [inertias[i] - inertias[i+1] for i in range(len(inertias)-1)]
                improvement_ratios = [improvements[i] / improvements[i+1] if improvements[i+1] > 0 else 1 
                                    for i in range(len(improvements)-1)]
                # Find where improvement drops by more than 50%
                elbow_idx = next((i for i, ratio in enumerate(improvement_ratios) if ratio > 1.5), len(improvement_ratios))
                max_clusters = min(test_range[elbow_idx + 2], len(X_umap) // 2)  # Add buffer beyond elbow
            else:
                max_clusters = min(10, len(X_umap) // 2)
            
            # Now run silhouette analysis only up to the heuristic limit
            best_k = 2
            best_score = -1
            
            for test_k in range(2, max_clusters + 1):
                kmeans_test = KMeans(n_clusters=test_k, random_state=42, n_init=10)
                test_labels = kmeans_test.fit_predict(X_umap)
                if len(set(test_labels)) > 1:
                    score = silhouette_score(X_umap, test_labels)
                    if score > best_score:
                        best_score = score
                        best_k = test_k
            
            # Apply best clustering
            kmeans = KMeans(n_clusters=best_k, random_state=42, n_init=10)
            cluster_labels = kmeans.fit_predict(X_umap)
        
        unique_clusters = len(np.unique(cluster_labels))
        print(f"  → 3D UMAP embedding created, K-means found {unique_clusters} clusters (silhouette score: {best_score:.3f})")
        
        # Store plot data
        current_batch.append({
            'k': k,
            'X_umap': X_umap,
            'cluster_labels': cluster_labels
        })
        
        # Save batch every 5 plots or at the end
        if len(current_batch) == plots_per_image or i == len(k_values) - 1:
            n_plots_batch = len(current_batch)
            fig = plt.figure(figsize=(4 * n_plots_batch, 4))
            
            for j, plot_data in enumerate(current_batch):
                ax = fig.add_subplot(1, n_plots_batch, j+1, projection='3d')
                
                # Create actual 3D scatter plot
                scatter = ax.scatter(plot_data['X_umap'][:, 0], 
                                   plot_data['X_umap'][:, 1], 
                                   plot_data['X_umap'][:, 2],
                                   c=plot_data['cluster_labels'], 
                                   cmap='viridis', 
                                   alpha=0.7, s=30)
                ax.set_title(f'UMAP 3D (n_neighbors={plot_data["k"]})')
                ax.set_xlabel('UMAP 1')
                ax.set_ylabel('UMAP 2')
                ax.set_zlabel('UMAP 3')
                plt.colorbar(scatter, ax=ax, label='Cluster', shrink=0.8)
            
            plt.tight_layout()
            batch_filename = f"{filename}_batch{batch_num}.png"
            plt.savefig(batch_filename, dpi=300, bbox_inches='tight')
            plt.close()
            
            print(f"Saved batch {batch_num}: {batch_filename}")
            
            current_batch = []
            batch_num += 1
        
        # Assign final cluster_id to dataframe using the last k value
        if i == len(k_values) - 1:
            final_kmeans = KMeans(n_clusters=unique_clusters, random_state=42, n_init=10)
            final_cluster_ids = final_kmeans.fit_predict(X_umap)
            df_result['cluster_id'] = final_cluster_ids
    
    print(f"UMAP analysis complete! Generated {batch_num-1} batch images.")
    
    return df_result