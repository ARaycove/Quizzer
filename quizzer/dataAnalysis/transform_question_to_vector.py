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
    record = pre_process_record(record)
    question_id = record.get('question_id')
    
    if len(record) == 1 and isinstance(list(record.keys())[0], int):
        record = record[list(record.keys())[0]]
    
    question_text_list: List[str] = []
    answer_text_list: List[str] = []
    question_media: List[str] = []
    answer_media: List[str] = []
    
    # Get answers for blanks
    blank_answers = []
    answers_to_blanks = record.get('answers_to_blanks')
    if isinstance(answers_to_blanks, list):
        for answer_group in answers_to_blanks:
            if isinstance(answer_group, dict):
                for primary_answer, synonyms in answer_group.items():
                    blank_answers.append(primary_answer)
                    if isinstance(synonyms, list):
                        for synonym in synonyms:
                            if isinstance(synonym, str):
                                answer_text_list.append(synonym)
    
    # Process question elements with blank replacement
    blank_index = 0
    for element in record.get('question_elements', []):
        if element.get('type') == 'text' and isinstance(element.get('content'), str):
            question_text_list.append(element['content'])
        elif element.get('type') == 'image' and isinstance(element.get('content'), str):
            question_media.append(element['content'])
        elif element.get('type') == 'blank':
            if blank_index < len(blank_answers):
                question_text_list.append(blank_answers[blank_index])
                blank_index += 1
    
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
    
    question_text = " ".join(question_text_list)
    answer_text = " ".join(answer_text_list)
    
    return {
        "question_id": question_id,
        "question_text": question_text,
        "answer_text": answer_text,
        "question_media": question_media,
        "answer_media": answer_media
    }


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
            # print(f"  - Doc length: {len(doc)} chars")
            # print(f"  - SciBERT embedding shape: {embedding.shape}")
        else:
            print(f"Failed to save record: {question_id}")
    
    db.close()

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