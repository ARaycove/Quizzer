import typing
from typing import Dict, List, Any
import load_question_data
import pandas as pd
import numpy as np
import typing
import time
from typing import Dict, List, Any
from PIL import Image
import io
import torch
from sentence_transformers import SentenceTransformer
from torchvision import models, transforms
import os
from sync_fetch_data import initialize_supabase_session
from supabase import Client
import multiprocessing as mp
import concurrent.futures


import typing
from typing import Dict, List, Any

def simplify_question_record(record: Dict[str, Any]) -> Dict[str, Any]:
    """
    Simplifies a single question record into a format suitable for K-means clustering.

    This function extracts and concatenates textual and media content from a raw
    question record. It focuses on the core content fields: question_elements,
    answer_elements, options, and answers_to_blanks, while omitting other data
    that could introduce noise.

    Args:
        record: A dictionary representing a single question record. It is expected
                to have the following keys:
                - 'question_id' (str): The unique identifier for the question.
                - 'question_elements' (List[Dict]): A list of dictionaries, each with
                  'type' and 'content' keys.
                - 'answer_elements' (List[Dict]): A list of dictionaries, same structure
                  as 'question_elements'.
                - 'options' (List[Dict]): A list of dictionaries, same structure.
                - 'answers_to_blanks' (Dict[str, List[str]]): A dictionary mapping
                  primary answers to a list of synonyms.

    Returns:
        A simplified dictionary with the following keys, all in snake case:
        - 'question_id': The unique identifier of the question.
        - 'question_text': A single string containing all text from question, answer, and options.
        - 'answer_text': A single string containing all text from answer and options.
        - 'question_media': A list of image file names from the question.
        - 'answer_media': A list of image file names from the answer and options.
    """
    # Get the question_id and handle cases where it might not exist
    question_id = record.get('question_id')

    # Handle the case where the record is nested under a single integer key.
    if len(record) == 1 and isinstance(list(record.keys())[0], int):
        record = record[list(record.keys())[0]]

    # Initialize lists to build the simplified record
    question_text_list: List[str] = []
    answer_text_list: List[str] = []
    question_media: List[str] = []
    answer_media: List[str] = []

    # Process question elements
    for element in record.get('question_elements', []):
        if element.get('type') == 'text' and isinstance(element.get('content'), str):
            question_text_list.append(element['content'])
        elif element.get('type') == 'image' and isinstance(element.get('content'), str):
            question_media.append(element['content'])

    # Process answer elements
    for element in record.get('answer_elements', []):
        if element.get('type') == 'text' and isinstance(element.get('content'), str):
            answer_text_list.append(element['content'])
        elif element.get('type') == 'image' and isinstance(element.get('content'), str):
            answer_media.append(element['content'])

    # Process options
    options_list = record.get('options')
    if options_list is not None:
        for element in options_list:
            if element.get('type') == 'text' and isinstance(element.get('content'), str):
                answer_text_list.append(element['content'])
            elif element.get('type') == 'image' and isinstance(element.get('content'), str):
                answer_media.append(element['content'])

    # Process answers to blanks
    answers_to_blanks = record.get('answers_to_blanks')
    if isinstance(answers_to_blanks, dict):
        for primary_answer, synonyms in answers_to_blanks.items():
            if isinstance(primary_answer, str):
                answer_text_list.append(primary_answer)
            if isinstance(synonyms, list):
                for synonym in synonyms:
                    if isinstance(synonym, str):
                        answer_text_list.append(synonym)

    # Convert the lists of strings to single strings
    question_text = " ".join(question_text_list)
    answer_text = " ".join(answer_text_list)

    # Return the final simplified record with snake case field names
    data_map = {
        "question_id": question_id,
        "question_text": question_text,
        "answer_text": answer_text,
        "question_media": question_media,
        "answer_media": answer_media
    }
    print(data_map)
    return data_map


def pre_process_question_dataframe(df: pd.DataFrame) -> List:
    """
    Processes a DataFrame of question records by applying a simplification
    function to each record.

    This function iterates through the DataFrame, processes each record, and
    constructs a new DataFrame from the simplified results.

    Args:
        df: A pandas.DataFrame containing question records.

    Returns:
        A new pandas.DataFrame with the simplified records.
    """
    # Ensure the input is a DataFrame, even if a Series is passed.
    if isinstance(df, pd.Series):
        df = pd.DataFrame(df)

    processed_records: List[Dict[str, Any]] = []

    # Iterate over the records in the DataFrame, converting each row to a dictionary
    # for processing by the `simplify_question_record` function.
    for record in df.to_dict('records'):
        # NOTE: This function assumes that `simplify_question_record` is defined
        # in the same scope.
        processed_record = simplify_question_record(record[0])
        processed_records.append(processed_record)
    
    # Construct a new DataFrame using the list of processed records
    return processed_records

def vectorize_records(records: List[Dict[str, Any]]) -> List[Dict[str, np.ndarray]]:
    """
    Vectorizes a list of question records in batches for improved performance.

    This function processes all text and media from a list of records at once
    to leverage the parallel processing capabilities of the models. It now also
    preserves the question_id for tracking.

    Args:
        records: A list of simplified dictionaries, each with the following keys:
                 - 'question_id' (str)
                 - 'question_text' (str)
                 - 'answer_text' (str)
                 - 'question_media' (List[str])
                 - 'answer_media' (List[str])

    Returns:
        A list of new dictionaries, with each value replaced by its
        corresponding vector (NumPy array) and the original question_id.
    """
    # Initialize text and vision models outside the main loop to avoid re-loading.
    text_model = SentenceTransformer('all-MiniLM-L6-v2')
    vision_model = models.resnet50(weights=models.ResNet50_Weights.IMAGENET1K_V2)
    vision_model = torch.nn.Sequential(*list(vision_model.children())[:-1])
    vision_model.eval()
    preprocess = transforms.Compose([
        transforms.Resize(256),
        transforms.CenterCrop(224),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ])

    def load_and_preprocess_image(image_name: str, preprocess: transforms.Compose) -> typing.Union[torch.Tensor, None]:
        """
        Loads an image from a local directory or downloads it from Supabase,
        then preprocesses it for the vision model.

        Args:
            image_name (str): The name of the image file (e.g., 'image.png').
            preprocess (transforms.Compose): The torchvision preprocessing pipeline.

        Returns:
            A preprocessed image tensor if successful, otherwise None.
        """
        if not image_name:
            print("Warning: Received an empty image name. Skipping processing.")
            return None

        local_path = os.path.join("data_images", image_name)
        
        # Check if the image exists locally
        if os.path.exists(local_path):
            print(f"Loading image from local cache: {local_path}")
            try:
                img = Image.open(local_path)
                # Convert palette images to RGBA to handle transparency
                if img.mode != 'RGB':
                    img = img.convert('RGB')
                return preprocess(img)
            except Exception as e:
                print(f"Error opening image from local path {local_path}: {e}")
                return None
        else:
            print(f"Image not found locally. Downloading from Supabase: {image_name}")
            try:
                supabase_client: Client = initialize_supabase_session()
                bucket_name = 'question-answer-pair-assets'
                
                # Download the image bytes from Supabase
                res = supabase_client.storage.from_(bucket_name).download(image_name)
                
                # Create the local directory if it doesn't exist
                os.makedirs(os.path.dirname(local_path), exist_ok=True)
                
                # Save the image locally
                with open(local_path, "wb") as f:
                    f.write(res)
                
                # Open the image from the saved bytes
                img = Image.open(io.BytesIO(res))
                # Convert palette images to RGBA to handle transparency
                if img.mode != 'RGB':
                    img = img.convert('RGB')
                
                print(f"Downloaded and saved image to {local_path}")
                return preprocess(img)

            except Exception as e:
                print(f"Error processing image {image_name}: {e}")
                return None

    # Extract all text and media into separate lists for batch processing.
    all_question_ids = [record.get('question_id', '') for record in records]
    all_question_texts = [record.get('question_text', '') for record in records]
    all_answer_texts = [record.get('answer_text', '') for record in records]
    
    all_question_media_lists = [record.get('question_media', []) for record in records]
    all_answer_media_lists = [record.get('answer_media', []) for record in records]

    # Vectorize all text fields in a single batch.
    question_text_vectors = text_model.encode(all_question_texts)
    print("Vectorized question text")
    print(question_text_vectors)
    answer_text_vectors = text_model.encode(all_answer_texts)
    print("Vectorized answer text")
    print(answer_text_vectors)

    # Vectorize all media fields in a single batch.
    all_media_names = []
    for media_list in all_question_media_lists + all_answer_media_lists:
        all_media_names.extend(media_list)

    # Process all images and keep track of successful ones.
    processed_images_info = []
    for name in all_media_names:
        tensor = load_and_preprocess_image(image_name=name, preprocess=preprocess)
        if tensor is not None:
            processed_images_info.append((name, tensor))

    image_tensors = [info[1] for info in processed_images_info]
    successful_image_names = [info[0] for info in processed_images_info]

    media_vectors = {}
    if image_tensors:
        image_batch = torch.stack(image_tensors)
        with torch.no_grad():
            vectors_tensor = vision_model(image_batch).squeeze()
        
        # If there's only one image, squeeze() can remove the batch dimension.
        # We need to reshape it to be a 2D array.
        if vectors_tensor.dim() == 1:
            vectors_tensor = vectors_tensor.unsqueeze(0)
        
        vectorized_images = vectors_tensor.numpy()
        
        # Correctly map vectorized images back to their original names.
        for i, name in enumerate(successful_image_names):
            media_vectors[name] = vectorized_images[i]

    print(media_vectors)
    # Reconstruct the records with the new vectorized data.
    vectorized_records = []
    for i in range(len(records)):
        record = records[i]
        
        q_media_vectors = []
        for media_name in all_question_media_lists[i]:
            if media_name in media_vectors:
                q_media_vectors.append(media_vectors[media_name])
        
        a_media_vectors = []
        for media_name in all_answer_media_lists[i]:
            if media_name in media_vectors:
                a_media_vectors.append(media_vectors[media_name])
                
        vectorized_record = {
            "question_id": all_question_ids[i],
            "question_text": question_text_vectors[i],
            "answer_text": answer_text_vectors[i],
            "question_media": np.mean(q_media_vectors, axis=0) if q_media_vectors else np.zeros(2048),
            "answer_media": np.mean(a_media_vectors, axis=0) if a_media_vectors else np.zeros(2048),
        }
        vectorized_records.append(vectorized_record)

    return vectorized_records


def process_and_vectorize_dataframe() -> pd.DataFrame:
    """
    Processes and vectorizes a Pandas DataFrame of question records using multiprocessing.

    This function acts as a pipeline:
    1. It simplifies each record into a standardized dictionary format.
    2. It splits the records into chunks and processes each chunk on a separate
       process to leverage all available CPU cores.
    3. The vectorized data is returned as a single Pandas DataFrame.

    Returns:
        A pandas.DataFrame containing the vector representations of the question's
        text and media.
    """

    # simplified_records = pre_process_question_dataframe(load_question_data.load_question_data())

    # if not simplified_records:
    #     return pd.DataFrame()

    # # Determine the number of workers to use (number of CPU cores).
    # num_workers = os.cpu_count() or 1
    
    # # Divide the records into chunks for each worker.
    # # The `+ 1` ensures that even a small remainder gets its own chunk.
    # chunk_size = len(simplified_records) // num_workers + 1

    # chunks = [
    #     simplified_records[i:i + chunk_size]
    #     for i in range(0, len(simplified_records), chunk_size)
    # ]

    # all_vectorized_data = []
    # with concurrent.futures.ProcessPoolExecutor(max_workers=num_workers) as executor:
    #     # Submit each chunk to the executor for vectorization.
    #     future_to_chunk = {executor.submit(vectorize_records, chunk): chunk for chunk in chunks}
        
    #     for future in concurrent.futures.as_completed(future_to_chunk):
    #         try:
    #             # Retrieve the vectorized data from the completed future.
    #             result = future.result()
    #             all_vectorized_data.extend(result)
    #         except Exception as e:
    #             # Catch and print any errors that occur during a chunk's processing.
    #             print(f"Error vectorizing a chunk: {e}")
                
    # # Convert the combined vectorized data back into a DataFrame.
    # vectorized_df = pd.DataFrame(all_vectorized_data)

    # Step 1: Simplify each record in the DataFrame.
    # We convert each row to a dictionary and simplify it.
    simplified_records = pre_process_question_dataframe(load_question_data.load_question_data())

    # Step 2: Vectorize all simplified records in a single batch.
    vectorized_data = vectorize_records(simplified_records)
    # Step 3: Convert the vectorized data into a Pandas DataFrame.
    vectorized_df = pd.DataFrame(vectorized_data)

    # Step 4: Save the vectorized data to a local file for caching.
    # The Parquet format is used for efficient storage of DataFrames.
    print("\n--- Saving vectorized data to vectorized_data.parquet ---")
    try:
        # Before saving, ensure the dtypes are uniform to avoid errors.
        # This is a common issue with mixed-type NumPy arrays.
        for col in ['question_media', 'answer_media']:
            if col in vectorized_df.columns:
                vectorized_df[col] = vectorized_df[col].apply(
                    lambda x: x.astype(np.float64) if isinstance(x, np.ndarray) else x
                )
        
        vectorized_df.to_parquet('vectorized_data.parquet')
        print("--- Save successful ---")
    except Exception as e:
        print(f"Error saving vectorized data: {e}")

    return vectorized_df


def print_first_n_records(df: pd.DataFrame, n_head: int, n_media: int) -> None:
    """
    Provides a summary of a Pandas DataFrame by printing its first `n_head` records
    and the first `n_media` records that contain non-zero media vectors.

    This function combines two separate printing functionalities into a single call.

    Args:
        df (pd.DataFrame): The DataFrame to summarize.
        n_head (int): The number of records to print from the beginning of the DataFrame.
        n_media (int): The number of records to print that have non-zero media vectors.
    """
    if df.empty:
        print("DataFrame is empty. No records to display.")
        return

    # Print the head of the DataFrame
    print(f"\n--- Printing the first {n_head} records from the DataFrame ---")
    if n_head > 0:
        print(df.head(n_head))
    else:
        print("Invalid number of records to print from the head. Please provide a positive integer.")
    print("--- End of DataFrame preview ---")

    # Print the records with non-zero media vectors
    print(f"\n--- Printing the first {n_media} records with non-zero media vectors ---")
    
    # We first need to check if the columns exist to avoid an error.
    if 'question_media' in df.columns and 'answer_media' in df.columns:
        # Create boolean masks for non-zero media vectors
        # We apply a lambda function to each row to check for non-zero values in the media columns
        has_question_media = df['question_media'].apply(lambda x: np.any(np.array(x) != 0) if isinstance(x, (list, np.ndarray)) else False)
        has_answer_media = df['answer_media'].apply(lambda x: np.any(np.array(x) != 0) if isinstance(x, (list, np.ndarray)) else False)
        
        # Combine the masks to find records with either non-zero question or answer media
        non_zero_media_df = df[has_question_media | has_answer_media]

        if not non_zero_media_df.empty:
            print(non_zero_media_df.head(n_media))
        else:
            print("No records with non-zero media vectors found.")
    else:
        print("DataFrame does not contain 'question_media' or 'answer_media' columns.")
    
    print("--- End of media records preview ---")

def main():
    """
    Main execution function for the data processing pipeline.
    """
    start_time = time.time()
    
    # Placeholder for the function call to process and vectorize data
    vectorized_df = process_and_vectorize_dataframe()
    
    end_time = time.time()
    total_time = end_time - start_time
    
    if not vectorized_df.empty:
        df_length = len(vectorized_df)
        avg_time_per_record = total_time / df_length
    else:
        df_length = 0
        avg_time_per_record = 0.0

    # Placeholder for printing the first n records of the DataFrame
    print_first_n_records(vectorized_df, 10, 5)

    print(f"\nVectorization complete.")
    print(f"Total time taken: {total_time:.2f} seconds")
    print(f"Number of records vectorized: {df_length}")
    print(f"Average time per record: {avg_time_per_record:.4f} seconds")

if __name__ == '__main__':
    main()