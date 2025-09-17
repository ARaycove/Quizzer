import pandas as pd
import typing
import numpy as np
import matplotlib.pyplot as plt
from sklearn.cluster import KMeans
from sklearn.decomposition import PCA
from scipy.spatial.distance import cdist
import seaborn as sns
import json
import sqlite3
from sqlite3 import Connection
from load_question_data import initialize_and_fetch_db
from sklearn.preprocessing import MultiLabelBinarizer

def split_dataframe_by_cluster(df):
    """
    Split dataframe into separate dataframes based on cluster_label.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        DataFrame with 'cluster_label' column
        
    Returns:
    --------
    list : Array of dataframes indexed by cluster_label
    """
    unique_clusters = sorted(df['cluster_label'].unique())
    cluster_dfs = []
    
    for cluster_id in unique_clusters:
        cluster_df = df[df['cluster_label'] == cluster_id].copy()
        cluster_dfs.append(cluster_df)
    
    return cluster_dfs

def create_onehot_features(df: pd.DataFrame, encode_keywords: bool = True, pca_components: int = None) -> pd.DataFrame:
    """
    Creates one-hot encoded features from keywords and converts is_math to binary.
    Args:
        df: DataFrame with 'keywords' (list) and 'is_math' (bool) columns
        encode_keywords: Whether to one-hot encode keywords column. Defaults to True.
        pca_components: Number of PCA components to reduce keyword features to. If None, no PCA is performed.
    Returns:
        New DataFrame with original columns except keywords/is_math, plus one-hot encoded features
    """
    result_df = df.copy()
    
    result_df['is_math'] = result_df['is_math'].astype(int)
    
    if encode_keywords:
        mlb = MultiLabelBinarizer()
        keywords_onehot = mlb.fit_transform(result_df['keywords'])
        
        num_unique_keywords = len(mlb.classes_)
        num_rows = len(result_df)
        print(f"One-hot encoding results:")
        print(f"  - Total unique keywords found: {num_unique_keywords}")
        print(f"  - Number of records processed: {num_rows}")
        print(f"  - Created {num_unique_keywords} keyword feature columns")
        print(f"  - Converted is_math to binary (0/1)")
        
        keywords_df = pd.DataFrame(
            keywords_onehot, 
            columns=[f'keyword_{keyword}' for keyword in mlb.classes_],
            index=result_df.index
        )
        
        if pca_components is not None:
            pca = PCA(n_components=pca_components)
            keywords_pca = pca.fit_transform(keywords_df)
            
            print(f"  - Applied PCA to reduce from {keywords_df.shape[1]} to {pca_components} components")
            print(f"  - Explained variance ratio: {pca.explained_variance_ratio_.sum():.3f}")
            
            keywords_df = pd.DataFrame(
                keywords_pca,
                columns=[f'keyword_pca_{i}' for i in range(pca_components)],
                index=result_df.index
            )
        
        result_df = result_df.drop('keywords', axis=1)
        result_df = pd.concat([result_df, keywords_df], axis=1)
        
        print(f"  - Final dataframe shape: {result_df.shape}")
        print("One-hot encoding completed successfully.")
    else:
        result_df = result_df.drop('keywords', axis=1)
        print(f"Keywords encoding skipped.")
        print(f"  - Converted is_math to binary (0/1)")
        print(f"  - Removed keywords column")
        print(f"  - Final dataframe shape: {result_df.shape}")
    
    return result_df, result_df.shape

def load_vectorized_dataframe() -> typing.Union[pd.DataFrame, None]:
    """
    Loads a Pandas DataFrame from a Parquet file named 'vectorized_data.parquet'.

    This function is designed to retrieve the previously saved vectorized
    question records from disk. It handles cases where the file does not exist,
    returning None in that scenario.

    Returns:
        A pandas.DataFrame containing the vectorized data if the file exists,
        otherwise None.
    """
    file_path = "vectorized_data.parquet"
    
    try:
        # Load the DataFrame from the Parquet file
        df = pd.read_parquet(file_path)
        print(f"Successfully loaded DataFrame from '{file_path}'.")
        return df
    except FileNotFoundError:
        print(f"Error: The file '{file_path}' was not found.")
        return None
    except Exception as e:
        print(f"An unexpected error occurred while loading the file: {e}")
        return None

def plot_elbow_method(df: pd.DataFrame, file_name: str = 'question_data_elbow_graph.png', 
                     k_start: int = 1, k_end: int = 11) -> None:
    """
    Performs the elbow method on any DataFrame with numeric features.
    Automatically excludes non-numeric identifier columns and uses all numeric columns for clustering.
    
    Args:
        df: A pandas DataFrame containing numeric features for clustering.
        file_name: Name of the file to save the plot to. Defaults to 'question_data_elbow_graph.png'.
        k_start: Starting value for k range (inclusive). Defaults to 1.
        k_end: Ending value for k range (exclusive). Defaults to 11 (so range is 1-10).
    """
    # Extract only numeric columns for clustering
    numeric_cols = df.select_dtypes(include=[np.number]).columns
    numeric_data = df[numeric_cols].values
    
    print(f"Using {len(numeric_cols)} numeric features for elbow method")
    
    inertia = []
    k_range = range(k_start, k_end)
    
    for k in k_range:
        print(f"Calculating inertia for k = {k}...")
        kmeans = KMeans(n_clusters=k, random_state=42, n_init='auto')
        kmeans.fit(numeric_data)
        inertia.append(kmeans.inertia_)
    
    plt.figure(figsize=(10, 6))
    plt.plot(k_range, inertia, 'bx-')
    plt.xlabel('Number of Clusters (k)')
    plt.ylabel('Inertia')
    plt.title(f'Elbow Method for Optimal k (k = {k_start} to {k_end-1})')
    plt.grid(True)
    
    plt.savefig(file_name)
    print(f"\nElbow method graph saved as '{file_name}'")
    plt.close()

def cluster_data_with_kmeans(df: pd.DataFrame, num_clusters: int, prefix: str = None) -> typing.Tuple[pd.DataFrame, KMeans]:
    """
    Performs K-Means clustering using all numeric features except identifiers.
    This function automatically uses all numeric columns for clustering,
    excluding non-numeric identifier columns like question_id.
    
    Args:
        df: A pandas DataFrame containing features for clustering.
        num_clusters: The number of clusters (k) to create.
        prefix: Optional prefix to add to cluster labels.
        
    Returns:
        A tuple containing:
        - The input DataFrame with an additional 'cluster_label' column.
        - The fitted KMeans model object.
    """
    if df.empty:
        print("Error: The DataFrame is empty. Cannot perform clustering.")
        return df, None
    
    # Get all numeric columns for clustering (excludes question_id and other identifiers)
    numeric_cols = df.select_dtypes(include=[np.number]).columns
    feature_data = df[numeric_cols].values
    
    print(f"Using {len(numeric_cols)} numeric features for clustering")
    print(f"Feature matrix shape: {feature_data.shape}")
    
    # Initialize the KMeans model with the specified number of clusters
    print(f"Starting K-Means clustering with {num_clusters} clusters...")
    kmeans_model = KMeans(n_clusters=num_clusters, random_state=42, n_init='auto')
    
    # Fit the model to the data and predict cluster labels
    cluster_labels = kmeans_model.fit_predict(feature_data)
    
    if prefix is not None:
        cluster_labels = [f"{prefix}_{label}" for label in cluster_labels]
    
    # Add the cluster labels back to the DataFrame
    df_result = df.copy()
    df_result['cluster_label'] = cluster_labels
    
    print("K-Means clustering complete.")
    
    return df_result, kmeans_model

def plot_clusters_pca(df: pd.DataFrame, num_clusters: int, filename: str) -> None:
    """
    Performs PCA to reduce dimensionality and plots the clustered data in both 2D and 3D side by side.
    This function takes a DataFrame with a 'cluster_label' column, reduces
    its dimensions using PCA on all numeric features, and then plots the data points, 
    colored by their cluster labels. Creates both 2D and 3D visualizations in one image.
    
    Args:
        df: A pandas DataFrame with a 'cluster_label' column and numeric features.
        num_clusters: The number of clusters used in the K-Means model.
        filename: The name of the file to save the plot to (e.g., 'clusters.png').
    """
    if 'cluster_label' not in df.columns:
        print("Error: DataFrame does not have a 'cluster_label' column. Cannot plot clusters.")
        return
    
    # Get all numeric columns except cluster_label for PCA
    numeric_cols = df.select_dtypes(include=[np.number]).columns
    feature_data = df[numeric_cols].values
    
    print(f"Plotting {len(feature_data)} data points across {num_clusters} clusters.")
    print(f"Using {len(numeric_cols)} numeric features for PCA visualization")
    print("Performing PCA for both 2D and 3D plotting...")
    
    # Apply PCA for both 2D and 3D
    pca_2d = PCA(n_components=2)
    pca_3d = PCA(n_components=3)
    
    components_2d = pca_2d.fit_transform(feature_data)
    components_3d = pca_3d.fit_transform(feature_data)
    
    print(f"2D PCA explained variance ratio: {pca_2d.explained_variance_ratio_.sum():.3f}")
    print(f"3D PCA explained variance ratio: {pca_3d.explained_variance_ratio_.sum():.3f}")
    
    # Create plotting DataFrames
    plot_df_2d = pd.DataFrame(data=components_2d, columns=['PC1', 'PC2'])
    plot_df_3d = pd.DataFrame(data=components_3d, columns=['PC1', 'PC2', 'PC3'])
    
    plot_df_2d['cluster_label'] = df['cluster_label'].values
    plot_df_3d['cluster_label'] = df['cluster_label'].values
    
    # Create figure with side-by-side subplots
    fig = plt.figure(figsize=(20, 8))
    
    # 2D plot
    ax1 = fig.add_subplot(1, 2, 1)
    # 3D plot
    ax2 = fig.add_subplot(1, 2, 2, projection='3d')
    
    unique_clusters = df['cluster_label'].unique()
    
    # Plot 2D
    for cluster_id in unique_clusters:
        cluster_data_2d = plot_df_2d[plot_df_2d['cluster_label'] == cluster_id]
        ax1.scatter(
            cluster_data_2d['PC1'],
            cluster_data_2d['PC2'],
            label=f'Cluster {cluster_id}',
            alpha=0.7
        )
    
    ax1.set_title('K-Means Clustering Visualization (2D PCA)')
    ax1.set_xlabel('Principal Component 1')
    ax1.set_ylabel('Principal Component 2')
    ax1.legend()
    ax1.grid(True)
    
    # Plot 3D
    for cluster_id in unique_clusters:
        cluster_data_3d = plot_df_3d[plot_df_3d['cluster_label'] == cluster_id]
        ax2.scatter(
            cluster_data_3d['PC1'],
            cluster_data_3d['PC2'],
            cluster_data_3d['PC3'],
            label=f'Cluster {cluster_id}',
            alpha=0.7
        )
    
    ax2.set_title('K-Means Clustering Visualization (3D PCA)')
    ax2.set_xlabel('Principal Component 1')
    ax2.set_ylabel('Principal Component 2')
    ax2.set_zlabel('Principal Component 3')
    ax2.legend()
    ax2.grid(True)
    
    plt.tight_layout()
    plt.savefig(filename)
    print(f"\nCluster plot saved as '{filename}'")
    plt.close()

def calculate_cluster_relations(kmeans_model: KMeans, output_file: str = 'cluster_relations.json') -> pd.DataFrame:
    """
    Calculates the relational strength between clusters based on the distance
    between their centroids and saves the data to a JSON file.

    The relational strength is a normalized value from 0 to 1, where 1 means
    the clusters are most similar (closest) and 0 means they are least similar.

    Args:
        kmeans_model: The fitted KMeans model object.
        output_file: The name of the JSON file to save the data to.

    Returns:
        A pandas DataFrame with 'primary_cluster', 'other_cluster', and
        'relational_strength' columns.
    """
    print("\n--- Calculating cluster relations ---")
    centroids = kmeans_model.cluster_centers_
    num_clusters = centroids.shape[0]

    # Calculate the Euclidean distance matrix between all centroids
    distance_matrix = cdist(centroids, centroids, metric='euclidean')
    
    # Normalize the distances to be between 0 and 1
    # Max distance will be the largest value in the matrix
    max_distance = np.max(distance_matrix)
    normalized_distances = distance_matrix / max_distance

    # Convert distances to relational strength (0-1, where 1 is most related)
    relational_strength_matrix = 1 - normalized_distances

    relations = []
    for i in range(num_clusters):
        for j in range(num_clusters):
            relations.append({
                'primary_cluster': i,
                'other_cluster': j,
                'relational_strength': relational_strength_matrix[i, j]
            })
    
    relations_df = pd.DataFrame(relations)

    # Save the data to a JSON file
    try:
        with open(output_file, 'w') as f:
            # Convert DataFrame to a list of dictionaries for JSON serialization
            json.dump(relations_df.to_dict('records'), f, indent=4)
        print(f"Cluster relations saved to '{output_file}'.")
    except Exception as e:
        print(f"Error saving data to JSON file: {e}")
    
    print("Cluster relation calculation complete.")
    return relations_df

def plot_cluster_relations_heatmap(relations_df: pd.DataFrame, filename: str) -> None:
    """
    Generates a heatmap to visualize the relational strength between clusters.

    Args:
        relations_df: The DataFrame containing cluster relations.
        filename: The name of the file to save the heatmap to.
    """
    print("\n--- Plotting cluster relations heatmap ---")
    # Pivot the DataFrame to create a matrix for the heatmap
    heatmap_data = relations_df.pivot(index='primary_cluster', columns='other_cluster', values='relational_strength')

    plt.figure(figsize=(10, 8))
    sns.heatmap(heatmap_data, annot=True, cmap='viridis', fmt=".2f", linewidths=.5, cbar_kws={'label': 'Relational Strength'})
    plt.title('Cluster Relational Strength Heatmap')
    plt.xlabel('Other Cluster')
    plt.ylabel('Primary Cluster')
    plt.tight_layout()
    
    plt.savefig(filename)
    print(f"\nCluster relation heatmap saved as '{filename}'")
    plt.close()

def update_db_with_cluster_ids(df: pd.DataFrame, db: Connection) -> None:
    """
    Updates the 'cluster_id' column in the SQLite database for each record
    based on the provided DataFrame.

    This function performs the following steps:
    1.  Checks if the 'cluster_id' column exists in the 'question_answer_pairs' table.
    2.  If the column does not exist, it adds it to the table.
    3.  Iterates through the DataFrame and updates the 'cluster_id' for each
        record in the database using the 'question_id' as the primary key.

    Args:
        df: A pandas DataFrame that must include 'question_id' and 'cluster_label' columns.
        db: The SQLite database connection object.
    """
    if 'question_id' not in df.columns or 'cluster_label' not in df.columns:
        print("Error: DataFrame must contain 'question_id' and 'cluster_label' columns.")
        return

    cursor = db.cursor()

    # Step 1: Check if the 'cluster_id' column exists
    try:
        cursor.execute("PRAGMA table_info(question_answer_pairs)")
        columns = [info[1] for info in cursor.fetchall()]
        if 'cluster_id' not in columns:
            # Step 2: Add the column if it doesn't exist
            print("The 'cluster_id' column does not exist. Adding column to the database...")
            cursor.execute("ALTER TABLE question_answer_pairs ADD COLUMN cluster_id TEXT")
            db.commit()
            print("Column 'cluster_id' added successfully.")
        else:
            print("The 'cluster_id' column already exists.")

    except sqlite3.Error as e:
        print(f"Database error during column check: {e}")
        return

    # Prepare data for batch update
    # The format is a list of tuples: [(cluster_id, question_id), ...]
    updates = [(int(row['cluster_label']), str(row['question_id'])) for index, row in df.iterrows()]

    print(f"Preparing to update {len(updates)} records.")

    # Step 3: Update the cluster_id for each record
    update_sql = "UPDATE question_answer_pairs SET cluster_id = ? WHERE question_id = ?"
    
    try:
        cursor.executemany(update_sql, updates)
        db.commit()
        print("Database updated successfully.")
    except sqlite3.Error as e:
        print(f"Database error during update: {e}")
        db.rollback()
    finally:
        cursor.close()

def main():
    df = load_vectorized_dataframe()
    k = 4

    df = create_onehot_features(df)
    # elbow method when new data, uncomment and rerun
    # plot_elbow_method(df)


    cluster_data = cluster_data_with_kmeans(df, k, use_embeddings=True)
    cluster_relations = calculate_cluster_relations(cluster_data[1])
    plot_cluster_relations_heatmap(cluster_relations, "cluster_relational_strength")
    plot_clusters_pca(cluster_data[0], k, "question_data_kmeans_cluster", 3)

    # For hierarchical clustering, we will repeat the same cluster_data_with_kmeans k times,

    # print(cluster_data[0].columns)

    # sub_clusters = split_dataframe_by_cluster(cluster_data[0])
    # sub_k = [4, 3, 2, 4] # k values for each sub-cluster
    # cluster_data_array = [None, None, None, None]
    
    # for pos, cluster in enumerate(sub_clusters):
    #     plot_elbow_method(cluster, f"cluster_{pos}") # run elbow plots so we can see how to set sub_k
    #     cluster_data_array[pos] = cluster_data_with_kmeans(cluster, sub_k[pos], prefix=str(pos))


    # # Combine our sub_clustering back together
    # combined_df = pd.concat([cluster_data_array[i][0] for i in range(len(cluster_data_array))], ignore_index=True)
    # print(combined_df['cluster_label'].unique())

    # plot_clusters_pca(combined_df, sum(sub_k), "question_data_sub_clusters", 3) #replot with subclusters

    update_db_with_cluster_ids(cluster_data[0], initialize_and_fetch_db())
    

if __name__ == "__main__":
    main()