import pandas as pd
from transform_question_to_vector import print_first_n_records
import typing
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.cluster import KMeans
from sklearn.decomposition import PCA
from mpl_toolkits.mplot3d import Axes3D
from scipy.spatial.distance import cdist
import seaborn as sns
import json
import sqlite3
from sqlite3 import Connection
from load_question_data import initialize_and_fetch_db


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

def plot_elbow_method(df: pd.DataFrame) -> None:
    """
    Performs the elbow method on a vectorized DataFrame and plots the results.

    This function combines all vector columns into a single feature matrix,
    then calculates the inertia (sum of squared distances) for a range of
    cluster numbers (k). The resulting plot is saved to a file, which can be
    used to visually determine the optimal number of clusters.

    Args:
        df: A pandas DataFrame containing vectorized data. It must have columns
            named 'question_text', 'answer_text', 'question_media',
            and 'answer_media', where each cell contains a NumPy array.
    """
    # Verify that the required columns exist in the DataFrame
    required_cols = ['question_text', 'answer_text', 'question_media', 'answer_media']
    if not all(col in df.columns for col in required_cols):
        print(f"Error: The DataFrame is missing one or more required columns: {required_cols}")
        return

    # Check if the DataFrame is empty
    if df.empty:
        print("Error: The DataFrame is empty. Cannot perform elbow method.")
        return

    # Combine all vectors into a single feature matrix
    # The vectors are assumed to be NumPy arrays in the DataFrame cells.
    # We use np.vstack to stack them vertically into a single 2D array.
    try:
        combined_vectors = np.hstack([
            np.vstack(df['question_text'].values),
            np.vstack(df['answer_text'].values),
            np.vstack(df['question_media'].values),
            np.vstack(df['answer_media'].values)
        ])
    except ValueError as e:
        print(f"Error combining vectors. Please ensure all vector arrays have consistent shapes. Details: {e}")
        return

    # Create a list to store the inertia values for each k
    inertia = []
    
    # Define a range for k (number of clusters) to test.
    # We will test k from 1 to 10.
    k_range = range(1, 50)

    # Loop through the range of k values
    for k in k_range:
        print(f"Calculating inertia for k = {k}...")
        # Initialize the KMeans model with the current k
        # We set `n_init='auto'` to use the default intelligent initialization.
        kmeans = KMeans(n_clusters=k, random_state=42, n_init='auto')
        
        # Fit the model to the combined data
        kmeans.fit(combined_vectors)
        
        # Append the inertia (sum of squared distances) to our list
        inertia.append(kmeans.inertia_)
    
    # Plot the results
    plt.figure(figsize=(10, 6))
    plt.plot(k_range, inertia, 'bx-')
    plt.xlabel('Number of Clusters (k)')
    plt.ylabel('Inertia')
    plt.title('Elbow Method for Optimal k')
    plt.grid(True)
    
    # Save the plot to a file
    filename = 'question_data_elbow_graph.png'
    plt.savefig(filename)
    print(f"\nElbow method graph saved as '{filename}'")
    plt.close() # Close the plot to prevent it from displaying in a window

def cluster_data_with_kmeans(df: pd.DataFrame, num_clusters: int) -> typing.Tuple[pd.DataFrame, KMeans]:
    """
    Performs K-Means clustering on the vectorized data within a DataFrame.

    This function combines the vectorized columns into a single feature matrix
    and then applies the K-Means algorithm to partition the data into a
    specified number of clusters. The cluster labels are then added to the
    original DataFrame for further analysis.

    Args:
        df: A pandas DataFrame containing vectorized data. It must have columns
            named 'question_text', 'answer_text', 'question_media',
            and 'answer_media', where each cell contains a NumPy array.
        num_clusters: The number of clusters (k) to create.

    Returns:
        A tuple containing:
        - The input DataFrame with an additional 'cluster_label' column.
        - The fitted KMeans model object.
    """
    # Verify that the required columns exist in the DataFrame
    required_cols = ['question_text', 'answer_text', 'question_media', 'answer_media']
    if not all(col in df.columns for col in required_cols):
        print(f"Error: The DataFrame is missing one or more required columns: {required_cols}")
        return df, None

    # Check if the DataFrame is empty
    if df.empty:
        print("Error: The DataFrame is empty. Cannot perform clustering.")
        return df, None

    # Combine all vectors into a single feature matrix
    try:
        combined_vectors = np.hstack([
            np.vstack(df['question_text'].values),
            np.vstack(df['answer_text'].values),
            np.vstack(df['question_media'].values),
            np.vstack(df['answer_media'].values)
        ])
    except ValueError as e:
        print(f"Error combining vectors. Please ensure all vector arrays have consistent shapes. Details: {e}")
        return df, None

    # Initialize the KMeans model with the specified number of clusters
    print(f"Starting K-Means clustering with {num_clusters} clusters...")
    kmeans_model = KMeans(n_clusters=num_clusters, random_state=42, n_init='auto')
    
    # Fit the model to the combined data and predict cluster labels
    cluster_labels = kmeans_model.fit_predict(combined_vectors)
    
    # Add the cluster labels back to the DataFrame
    df['cluster_label'] = cluster_labels
    
    print("K-Means clustering complete.")
    
    return df, kmeans_model

def plot_clusters_pca(df: pd.DataFrame, num_clusters: int, filename: str, dimensions: int = 2) -> None:
    """
    Performs PCA to reduce dimensionality and plots the clustered data in 2D or 3D.

    This function takes a DataFrame with a 'cluster_label' column, reduces
    its dimensions using PCA, and then plots the data points, colored by
    their cluster labels. The resulting plot is saved to a file.

    Args:
        df: A pandas DataFrame with a 'cluster_label' column and vectorized data.
        num_clusters: The number of clusters used in the K-Means model.
        filename: The name of the file to save the plot to (e.g., 'clusters.png').
        dimensions: The number of dimensions to plot (2 or 3).
    """
    if dimensions not in [2, 3]:
        print("Error: 'dimensions' must be 2 or 3.")
        return

    # Ensure the 'cluster_label' column exists
    if 'cluster_label' not in df.columns:
        print("Error: DataFrame does not have a 'cluster_label' column. Cannot plot clusters.")
        return

    # Extract the combined vectors
    try:
        combined_vectors = np.hstack([
            np.vstack(df['question_text'].values),
            np.vstack(df['answer_text'].values),
            np.vstack(df['question_media'].values),
            np.vstack(df['answer_media'].values)
        ])
    except ValueError as e:
        print(f"Error combining vectors for plotting. Details: {e}")
        return

    # Print the total number of data points
    total_data_points = len(combined_vectors)
    print(f"Plotting {total_data_points} data points across {num_clusters} clusters.")

    print(f"Performing PCA to reduce dimensionality for {dimensions}D plotting...")
    # Apply PCA to reduce the vectors to 2 or 3 dimensions for plotting
    pca = PCA(n_components=dimensions)
    principal_components = pca.fit_transform(combined_vectors)
    
    # Create a new DataFrame for plotting
    if dimensions == 2:
        plot_df = pd.DataFrame(data=principal_components, columns=['PC1', 'PC2'])
        plot_df['cluster_label'] = df['cluster_label']
        fig = plt.figure(figsize=(10, 8))
        ax = fig.add_subplot(1, 1, 1)
    else:  # dimensions == 3
        plot_df = pd.DataFrame(data=principal_components, columns=['PC1', 'PC2', 'PC3'])
        plot_df['cluster_label'] = df['cluster_label']
        fig = plt.figure(figsize=(10, 8))
        ax = fig.add_subplot(111, projection='3d')
        
    # Plot each cluster
    for cluster_id in range(num_clusters):
        cluster_data = plot_df[plot_df['cluster_label'] == cluster_id]
        if dimensions == 2:
            ax.scatter(
                cluster_data['PC1'],
                cluster_data['PC2'],
                label=f'Cluster {cluster_id}',
                alpha=0.7
            )
        else: # dimensions == 3
            ax.scatter(
                cluster_data['PC1'],
                cluster_data['PC2'],
                cluster_data['PC3'],
                label=f'Cluster {cluster_id}',
                alpha=0.7
            )
    
    plt.title(f'K-Means Clustering Visualization ({dimensions}D PCA)')
    ax.set_xlabel('Principal Component 1')
    ax.set_ylabel('Principal Component 2')
    if dimensions == 3:
        ax.set_zlabel('Principal Component 3')

    ax.legend()
    ax.grid(True)
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
            cursor.execute("ALTER TABLE question_answer_pairs ADD COLUMN cluster_id INTEGER")
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
    k = 25
    print_first_n_records(df, 10, 5)

    # elbow method when new data, uncomment and rerun
    # plot_elbow_method(df)

    cluster_data = cluster_data_with_kmeans(df, k)
    cluster_relations = calculate_cluster_relations(cluster_data[1])
    plot_cluster_relations_heatmap(cluster_relations, "cluster_relational_strength")
    plot_clusters_pca(cluster_data[0], k, "question_data_kmeans_cluster", 3)


    update_db_with_cluster_ids(cluster_data[0], initialize_and_fetch_db())
    


    

if __name__ == "__main__":
    main()
    