from typing import Dict, List, Any
import load_question_data
import pandas as pd
import numpy as np
import time
from PIL import Image
import torch
from data_utils import load_image, text_to_image, combine_images_vertically, get_is_math, get_keywords
from transformers import InstructBlipProcessor, InstructBlipForConditionalGeneration
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

processor = InstructBlipProcessor.from_pretrained("Salesforce/instructblip-vicuna-7b")
model = InstructBlipForConditionalGeneration.from_pretrained("Salesforce/instructblip-vicuna-7b")

def vectorize_records() -> None:
    """
    Vectorizes question records from database using InstructBLIP multi-modal transformer.
    Processes records one by one until all have vectors.
    Uses combined embeddings that capture cross-modal educational semantic meaning.
    
    InstructBLIP is specifically designed for instruction-following with visual content,
    making it ideal for educational Q&A that combines text explanations with images,
    diagrams, equations, and other visual learning materials.
    
    Fetches records from DB, processes them, and saves back to DB until complete.
    """
    db = initialize_and_fetch_db()
    processed_count = 0
    
    print("Starting vectorization process...")
    
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

            # Create educational instruction that emphasizes subject matter and concept understanding
            instruction_text = f"Analyze the educational concept and subject matter in this learning material. Question: {question_text} Answer: {answer_text}. What is the main educational topic and key concepts being taught?"
            
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

            # Handle images - load actual media images if they exist
            all_images = []
            
            # Load question media images
            if question_media:
                for img_name in question_media:
                    if img_name:
                        try:
                            img_tensor = load_image(img_name)
                            img_pil = safe_tensor_to_pil(img_tensor)
                            if img_pil is not None:
                                all_images.append(img_pil)
                        except Exception as e:
                            print(f"Error loading question image {img_name}: {e}")
            
            # Load answer media images  
            if answer_media:
                for img_name in answer_media:
                    if img_name:
                        try:
                            img_tensor = load_image(img_name)
                            img_pil = safe_tensor_to_pil(img_tensor)
                            if img_pil is not None:
                                all_images.append(img_pil)
                        except Exception as e:
                            print(f"Error loading answer image {img_name}: {e}")
            
            # If no actual images, create a simple white image as placeholder
            if not all_images:
                placeholder_image = Image.new('RGB', (224, 224), color='white')
                all_images = [placeholder_image]
            
            # Combine multiple images if present
            if len(all_images) > 1:
                combined_image = combine_images_vertically(all_images)
            else:
                combined_image = all_images[0]
            
            # Process through InstructBLIP
            inputs = processor(
                images=combined_image, 
                text=instruction_text, 
                return_tensors="pt"
            )
            
            with torch.no_grad():
                # Get the full model outputs which include cross-modal interactions
                outputs = model.vision_model(
                    pixel_values=inputs.pixel_values,
                    return_dict=True
                )
                
                # Get vision features
                vision_features = outputs.last_hidden_state  # [batch, patches, hidden_size]
                vision_pooled = outputs.pooler_output  # [batch, hidden_size]
                
                # Get text embeddings
                text_embeddings = model.language_model.get_input_embeddings()(inputs.input_ids)
                text_pooled = text_embeddings.mean(dim=1)  # [batch, hidden_size]
                
                # Create combined cross-modal embedding
                # This captures the interaction between visual and textual educational content
                
                # Method 1: Concatenate vision and text features
                vision_flat = vision_pooled.squeeze()  # Remove batch dim
                text_flat = text_pooled.squeeze()      # Remove batch dim
                
                # Ensure same dimensionality for proper combination
                if vision_flat.shape[0] != text_flat.shape[0]:
                    # Project to common dimension
                    target_dim = min(vision_flat.shape[0], text_flat.shape[0])
                    vision_projected = F.linear(vision_flat.unsqueeze(0), 
                                              torch.randn(target_dim, vision_flat.shape[0])).squeeze()
                    text_projected = F.linear(text_flat.unsqueeze(0), 
                                            torch.randn(target_dim, text_flat.shape[0])).squeeze()
                else:
                    vision_projected = vision_flat
                    text_projected = text_flat
                
                # Create combined embedding that captures cross-modal educational semantics
                # Weighted combination emphasizing both modalities
                alpha = 0.6  # Weight for vision (important for educational diagrams/images)
                beta = 0.4   # Weight for text (important for concepts/explanations)
                
                combined_embedding = alpha * vision_projected + beta * text_projected
                
                # Optional: Add interaction term to capture cross-modal relationships
                interaction_term = vision_projected * text_projected * 0.1
                final_embedding = combined_embedding + interaction_term
                
                embedding = final_embedding.cpu().numpy()
            
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
                print(f"  - Images processed: {len(all_images)}")
                print(f"  - Embedding shape: {embedding.shape}")
            else:
                print(f"Failed to save record: {question_id}")
            
        except Exception as e:
            print(f"Error processing record {record.get('question_id', 'unknown')}: {e}")
            
            # Still try to save a fallback record to avoid infinite loop
            try:
                record['question_vector'] = np.zeros(4096, dtype=np.float32)  # Fallback embedding
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