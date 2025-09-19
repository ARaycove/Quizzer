import supabase
import sqlite3
from sync_fetch_data import initialize_supabase_session
from sync_fetch_data import initialize_and_fetch_db, get_last_sync_date, fetch_new_records_from_supabase, update_last_sync_date,find_newest_timestamp,upsert_records_to_db
import datetime
from transform_question_to_vector import vectorize_records
import numpy as np
import torch
import time
from load_question_data import load_question_data
from k_means_cluster_question_data import (
    create_onehot_features, cluster_data_with_kmeans, calculate_cluster_relations, 
    plot_cluster_relations_heatmap, plot_clusters_pca, plot_elbow_method,
    update_db_with_cluster_ids)
from data_utils import filter_df_for_k_means, calculate_optimal_pca_components, run_pca
from plotting_functions import umap_plot



# First we need initialize our supabase client and the local db file:
print("Now Initializing Supabase Client")
supabase_client: supabase = initialize_supabase_session()
print("Now Initializing database object")
db: sqlite3 = initialize_and_fetch_db()

# Get the last sync date
last_sync_date: datetime = get_last_sync_date()
print(f"Got last sync time of: {last_sync_date}")
# Pass that into and then fetch the new question records to be analyzed
new_records: list = fetch_new_records_from_supabase(
    supabase_client     =supabase_client,
    last_sync_date      =last_sync_date
)
print(f"Got {len(new_records)} total records from supabase")
# Assuming we got anything back, update the last sync date for future runs
update_last_sync_date(find_newest_timestamp(records=new_records))

# Now we need to save the new records to our local db file:
upsert_records_to_db(
    records=new_records, 
    db = db)

# We should now be up to date with the server:

# Now we need to ensure all data has a question_vector and keywords list field
np.random.seed(42)
torch.manual_seed(42)
start_time = time.time()
vectorize_records()

end_time = time.time()
total_time = end_time - start_time
print(f"Question vectorization took: {total_time} seconds")

# Now we will fetch the dataframe so we can run it through our models
# From the database we need:


df = load_question_data() # This should already be converted into types

# Determine Cluster Groups for questions and assign the cluster_id's based on the models
# clean up the dataframe so we keep only the following:
# {question_id: ..., question_vector: ..., is_math: ..., keywords: ...}
k = 4 #Set by the elbow method
print(df.head(5))


encoded_df = filter_df_for_k_means(df)
encoded_df, shape = create_onehot_features(df = encoded_df) # Use one principle component per subject field identified in the taxonomy

# We'll reduce this using PCA
# let's say we want 100 samples per core component 
samples = shape[0]
print(f"Samples: {samples}")
d = shape[1] + 1408 # 1408 is the size of our transformer vector (subtract one add one is_math - the single feature in here that represents the vector)
print(f"Dimensionality: {d}")

cluster_data = umap_plot(df = encoded_df, min_k=65, max_k = 65, filename="cluster_plots/umap_plot")
update_db_with_cluster_ids(cluster_data, initialize_and_fetch_db())


# OLD CODE, not using this right now:
# # Since we are working in extremely high dimensional space, with a relatively limited sample size, we will run a calculation on the spot to determine the optimal reduction
# p = calculate_optimal_pca_components(num_samples=samples, num_features=d)
# print(f"Ideal p value is: {p}")

# k_means_df = run_pca(k_means_df, p)

# # elbow method when new data, uncomment and rerun
# skip_initial_elbow_plot = False
# if not skip_initial_elbow_plot:
#     plot_elbow_method(df=k_means_df, file_name="elbow_plots/question_data_elbow_plot.png", k_end = 10)
#     # Subject (2nd layer) taxonomy is around 30 subject matters of distinction. Given we had data for all 30, we should expect around 30 clusters, with subclusters within.

# # Elbow method does nothing on this set now, there is no elbow
# k = 5 # 5 reflects UNESCO academic classification 5 broad domains
# cluster_data = cluster_data_with_kmeans(k_means_df, k)
# cluster_relations = calculate_cluster_relations(cluster_data[1])
# plot_cluster_relations_heatmap(cluster_relations, "cluster_plots/cluster_relational_strength")
# plot_clusters_pca(cluster_data[0], k, "cluster_plots/question_data_kmeans_cluster")

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

