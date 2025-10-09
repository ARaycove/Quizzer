from typing import Dict, List, Any
import load_question_data
import pandas as pd
import numpy as np
import time
from PIL import Image
import torch
from data_utils import load_image, text_to_image, combine_images_vertically, get_is_math, get_keywords
from transformers import AutoTokenizer, AutoModel
import pytesseract
import torch.nn.functional as F
from sync_fetch_data import get_empty_vector_record, upsert_question_record, initialize_and_fetch_db
from load_question_data import pre_process_record



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
    # Assuming the record came directly from the database it must be processed into types before we can extract it's contents
    record = pre_process_record(record)
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


def vectorize_records() -> None:
    """
    Vectorizes question records from database using SciBERT.
    
    Retrieves pre-computed 'doc' field from database and generates embeddings.
    The 'doc' field should already contain question text + answer text + OCR text + image captions.
    
    Fetches records from DB, processes them, and saves back to DB until complete.
    """
    scibert_tokenizer = AutoTokenizer.from_pretrained("allenai/scibert_scivocab_uncased")
    scibert_model = AutoModel.from_pretrained("allenai/scibert_scivocab_uncased")
    db = initialize_and_fetch_db()
    processed_count = 0
    
    print("Starting vectorization process with SciBERT...")
    
    while True:
        # Get next record that needs vectorization
        record = get_empty_vector_record(db)
        
        # Break if no more records need processing
        if record is None:
            print(f"Vectorization complete! Processed {processed_count} records.")
            break
        
        question_id = record.get('question_id', '')
        doc = record.get('doc', '')
        
        # If doc doesn't exist, skip this record
        if not doc or doc == '':
            print(f"Skipping record {question_id}: no doc field found")
            record['question_vector'] = np.zeros(768, dtype=np.float32)
            upsert_question_record(db, record)
            processed_count += 1
            continue
        
        # Tokenize and encode with SciBERT
        inputs = scibert_tokenizer(
            doc,
            max_length=512,
            truncation=True,
            padding=True,
            return_tensors="pt"
        )
        
        with torch.no_grad():
            outputs = scibert_model(**inputs)
            # Use [CLS] token embedding as the document representation
            embedding = outputs.last_hidden_state[:, 0, :].squeeze()
            embedding = embedding.cpu().numpy()
        
        # Update the record with computed values
        record['question_vector'] = embedding
        
        # Save back to database
        success = upsert_question_record(db, record)
        
        if success:
            processed_count += 1
            print(f"Processed record {processed_count}: {question_id}")
            print(f"  - Doc length: {len(doc)} chars")
            print(f"  - SciBERT embedding shape: {embedding.shape}")
        else:
            print(f"Failed to save record: {question_id}")
    
    db.close()
    print("Database connection closed.")

def main():
    """
    Main execution function for the data processing pipeline.
    """
    np.random.seed(42)
    torch.manual_seed(42)
    start_time = time.time()
    vectorize_records()
    
    end_time = time.time()
    total_time = end_time - start_time



    print(f"\nVectorization complete.")
    print(f"Total time taken: {total_time:.2f} seconds")

if __name__ == '__main__':
    main()