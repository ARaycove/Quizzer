import supabase
import sqlite3
from sync_fetch_data import initialize_supabase_session, sync_vectors_to_supabase
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

# Set to True to clear the question_vector fields, for use when testing on new transformer models.
reset_vectors = False

# First we need initialize our supabase client and the local db file:
print("Now Initializing Supabase Client")
supabase_client: supabase = initialize_supabase_session()
print("Now Initializing database object")
db: sqlite3 = initialize_and_fetch_db(reset_question_vector=reset_vectors)

# Get the last sync date
last_sync_date: datetime = get_last_sync_date()
print(f"Got last sync time of: {last_sync_date}")
# Pass that into and then fetch the new question records to be analyzed
new_records = fetch_new_records_from_supabase(
    supabase_client     =supabase_client,
    last_sync_date      =last_sync_date
)
print(f"Got {len(new_records['question_answer_pairs'])} total qa records from supabase")
print(f"Got {len(new_records['question_answer_attempts'])} total attempt records from supabase")
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


# df = load_question_data() # This should already be converted into types

# # Determine Cluster Groups for questions and assign the cluster_id's based on the models
# # clean up the dataframe so we keep only the following:
# # {question_id: ..., question_vector: ..., is_math: ..., keywords: ...}
# k = 4 #Set by the elbow method
# print(df.head(5))


# encoded_df = filter_df_for_k_means(df)
# encoded_df, shape = create_onehot_features(df = encoded_df, encode_keywords=False) # Use one principle component per subject field identified in the taxonomy

# # We'll reduce this using PCA
# # let's say we want 100 samples per core component 
# samples = shape[0]
# print(f"Samples: {samples}")
# d = shape[1] + 768 # 768 is the size of our transformer vector (subtract one add one is_math - the single feature in here that represents the vector)
# print(f"Dimensionality: {d}")

# cluster_data = umap_plot(df = encoded_df, min_k=5, max_k = 5, k_clusters=10, filename="cluster_plots/umap_plot")
# update_db_with_cluster_ids(cluster_data, initialize_and_fetch_db())
sync_vectors_to_supabase(reset_question_vector=reset_vectors, reset_attempts_vector=False)

