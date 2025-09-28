from typing import Dict, List, Any
import load_question_data
import pandas as pd
import numpy as np
import time
from PIL import Image
import torch
from data_utils import load_image, text_to_image, combine_images_vertically, get_is_math, get_keywords
from transformers import BlipProcessor, BlipForConditionalGeneration, AutoTokenizer, AutoModel
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

processor = BlipProcessor.from_pretrained("Salesforce/blip-image-captioning-base")
model = BlipForConditionalGeneration.from_pretrained("Salesforce/blip-image-captioning-base")
scibert_tokenizer = AutoTokenizer.from_pretrained("allenai/scibert_scivocab_uncased")
scibert_model = AutoModel.from_pretrained("allenai/scibert_scivocab_uncased")

def vectorize_records() -> None:
    """
    Vectorizes question records from database using image-to-text pipeline with SciBERT.
    
    Pipeline:
    1. Extract text from images using OCR (if applicable)
    2. Generate image captions using BLIP
    3. Combine question text + OCR text + image captions
    4. Vectorize combined text using SciBERT for scientific/academic domain knowledge
    
    This approach maintains SciBERT's academic vocabulary while handling multimodal content
    by converting all visual information into textual descriptions.
    
    Fetches records from DB, processes them, and saves back to DB until complete.
    """
    db = initialize_and_fetch_db()
    processed_count = 0
    
    print("Starting vectorization process with SciBERT pipeline...")
    
    while True:
        # Get next record that needs vectorization
        record = get_empty_vector_record(db)
        
        # Break if no more records need processing
        if record is None:
            print(f"Vectorization complete! Processed {processed_count} records.")
            break
        
        try:
            # Simplify the record format
            record = simplify_question_record(record)
            
            question_id = record.get('question_id', '')
            question_text = record.get('question_text', '')
            answer_text = record.get('answer_text', '')
            question_media = record.get('question_media', [])
            answer_media = record.get('answer_media', [])
            combined_text = f"{question_text} {answer_text}".strip()
            keywords = get_keywords(combined_text)
            is_math = get_is_math(combined_text)
            
            # Helper function to safely convert tensor to PIL
            def safe_tensor_to_pil(img_tensor):
                if img_tensor is None:
                    return None
                
                # If it's already a PIL Image, return as-is
                if isinstance(img_tensor, Image.Image):
                    return img_tensor
                
                # Convert tensor to PIL safely
                if torch.is_tensor(img_tensor):
                    # Normalize tensor to [0,1] range
                    img_tensor = img_tensor.float()
                    img_tensor = (img_tensor - img_tensor.min()) / (img_tensor.max() - img_tensor.min())
                    
                    # Remove batch dimension if present
                    if img_tensor.dim() == 4:
                        img_tensor = img_tensor.squeeze(0)
                    
                    # Ensure correct channel order (C, H, W) -> (H, W, C)
                    if img_tensor.dim() == 3 and img_tensor.shape[0] in [1, 3]:
                        img_tensor = img_tensor.permute(1, 2, 0)
                    
                    # Convert to uint8 and PIL
                    img_array = (img_tensor * 255).clamp(0, 255).byte().numpy()
                    
                    # Handle grayscale
                    if img_array.shape[-1] == 1:
                        img_array = img_array.squeeze(-1)
                        return Image.fromarray(img_array, mode='L')
                    else:
                        return Image.fromarray(img_array, mode='RGB')
                
                return None
            
            # Process images to text descriptions
            image_descriptions = []
            ocr_texts = []
            
            # Process question media images
            if question_media:
                for img_name in question_media:
                    if img_name:
                        try:
                            img_tensor = load_image(img_name)
                            img_pil = safe_tensor_to_pil(img_tensor)
                            if img_pil is not None:
                                # Generate image caption using BLIP
                                inputs = processor(img_pil, return_tensors="pt")
                                with torch.no_grad():
                                    out = model.generate(**inputs, max_length=50, num_beams=5)
                                    caption = processor.decode(out[0], skip_special_tokens=True)
                                    image_descriptions.append(f"Question image: {caption}")
                                
                                # Extract text using OCR if image contains text
                                try:
                                    ocr_text = pytesseract.image_to_string(img_pil, config='--psm 6').strip()
                                    if ocr_text and len(ocr_text) > 3:  # Filter out noise
                                        ocr_texts.append(f"Text from question image: {ocr_text}")
                                except:
                                    pass  # OCR failed, continue without it
                        except Exception as e:
                            print(f"Error processing question image {img_name}: {e}")
            
            # Process answer media images
            if answer_media:
                for img_name in answer_media:
                    if img_name:
                        try:
                            img_tensor = load_image(img_name)
                            img_pil = safe_tensor_to_pil(img_tensor)
                            if img_pil is not None:
                                # Generate image caption using BLIP
                                inputs = processor(img_pil, return_tensors="pt")
                                with torch.no_grad():
                                    out = model.generate(**inputs, max_length=50, num_beams=5)
                                    caption = processor.decode(out[0], skip_special_tokens=True)
                                    image_descriptions.append(f"Answer image: {caption}")
                                
                                # Extract text using OCR if image contains text
                                try:
                                    ocr_text = pytesseract.image_to_string(img_pil, config='--psm 6').strip()
                                    if ocr_text and len(ocr_text) > 3:  # Filter out noise
                                        ocr_texts.append(f"Text from answer image: {ocr_text}")
                                except:
                                    pass  # OCR failed, continue without it
                        except Exception as e:
                            print(f"Error processing answer image {img_name}: {e}")
            
            # Combine all textual information
            all_text_components = []
            
            # Add original question and answer text
            if question_text:
                all_text_components.append(f"Question: {question_text}")
            if answer_text:
                all_text_components.append(f"Answer: {answer_text}")
            
            # Add OCR extracted text
            if ocr_texts:
                all_text_components.extend(ocr_texts)
            
            # Add image descriptions
            if image_descriptions:
                all_text_components.extend(image_descriptions)
            
            # Create final text for SciBERT processing
            final_text = " ".join(all_text_components)
            
            # Ensure we have some text to process
            if not final_text.strip():
                final_text = "Empty educational content"
            
            # Tokenize and encode with SciBERT
            inputs = scibert_tokenizer(
                final_text,
                max_length=512,
                truncation=True,
                padding=True,
                return_tensors="pt"
            )
            
            with torch.no_grad():
                outputs = scibert_model(**inputs)
                # Use [CLS] token embedding as the document representation
                embedding = outputs.last_hidden_state[:, 0, :].squeeze()  # [CLS] token
                embedding = embedding.cpu().numpy()
            
            # Update the original record with computed values
            record['question_vector'] = embedding
            record['is_math'] = is_math
            record['keywords'] = keywords
            
            # Save back to database
            success = upsert_question_record(db, record)
            
            if success:
                processed_count += 1
                print(f"Processed record {processed_count}: {question_id}")
                print(f"  - Is math: {is_math}")
                print(f"  - Keywords: {len(keywords) if keywords else 0}")
                print(f"  - Image descriptions: {len(image_descriptions)}")
                print(f"  - OCR extractions: {len(ocr_texts)}")
                print(f"  - Final text length: {len(final_text)} chars")
                print(f"  - SciBERT embedding shape: {embedding.shape}")
            else:
                print(f"Failed to save record: {question_id}")
            
        except Exception as e:
            print(f"Error processing record {record.get('question_id', 'unknown')}: {e}")
            
            # Still try to save a fallback record to avoid infinite loop
            try:
                record['question_vector'] = np.zeros(768, dtype=np.float32)  # SciBERT embedding size
                record['is_math'] = False
                record['keywords'] = []
                upsert_question_record(db, record)
                processed_count += 1
                print(f"Saved fallback for record: {record.get('question_id', 'unknown')}")
            except Exception as save_error:
                print(f"Failed to save fallback record: {save_error}")
                break  # Prevent infinite loop if DB is broken
    
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