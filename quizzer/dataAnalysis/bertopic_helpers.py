from sync_fetch_data import initialize_and_fetch_db, get_empty_doc_record, upsert_question_record
from transform_question_to_vector import simplify_question_record
from data_utils import load_image
from transformers import BlipProcessor, BlipForConditionalGeneration
from PIL import Image
import torch
import pytesseract


def create_docs() -> None:
    """
    Creates document strings for question records to use with BERTopic.
    
    Pipeline:
    1. Extract text from images using OCR (if applicable)
    2. Generate image captions using BLIP
    3. Combine question text + OCR text + image captions into a single document string
    
    This creates rich textual representations of multimodal content that BERTopic
    can use for topic modeling while preserving academic vocabulary.
    
    Fetches records from DB, processes them, and saves back to DB until complete.
    """
    processor = BlipProcessor.from_pretrained("Salesforce/blip-image-captioning-base")
    model = BlipForConditionalGeneration.from_pretrained("Salesforce/blip-image-captioning-base")

    db = initialize_and_fetch_db()
    processed_count = 0
    
    print("Starting doc creation process for BERTopic...")
    
    while True:
        # Get next record that needs doc creation
        record = get_empty_doc_record(db)
        
        # Break if no more records need processing
        if record is None:
            print(f"Doc creation complete! Processed {processed_count} records.")
            break
        
        try:
            # Simplify the record format
            record = simplify_question_record(record)
            
            question_id = record.get('question_id', '')
            question_text = record.get('question_text', '')
            answer_text = record.get('answer_text', '')
            question_media = record.get('question_media', [])
            answer_media = record.get('answer_media', [])
            
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
            
            # Combine all textual information into a single document
            all_text_components = []
            
            # Add original question and answer text
            if question_text:
                all_text_components.append(question_text)
            if answer_text:
                all_text_components.append(answer_text)
            
            # Add OCR extracted text
            if ocr_texts:
                all_text_components.extend(ocr_texts)
            
            # Add image descriptions
            if image_descriptions:
                all_text_components.extend(image_descriptions)
            
            # Create final doc string for BERTopic
            doc = " ".join(all_text_components)
            
            # Ensure we have some text
            if not doc.strip():
                doc = "Empty educational content"
            
            # Update the record with the doc
            record['doc'] = doc
            
            # Save back to database
            success = upsert_question_record(db, record)
            
            if success:
                processed_count += 1
                print(f"Processed record {processed_count}: {question_id}")
                print(f"  - Image descriptions: {len(image_descriptions)}")
                print(f"  - OCR extractions: {len(ocr_texts)}")
                print(f"  - Doc length: {len(doc)} chars")
            else:
                print(f"Failed to save record: {question_id}")
            
        except Exception as e:
            print(f"Error processing record {record.get('question_id', 'unknown')}: {e}")
            
            # Still try to save a fallback record to avoid infinite loop
            try:
                record['doc'] = "Empty educational content"
                upsert_question_record(db, record)
                processed_count += 1
                print(f"Saved fallback for record: {record.get('question_id', 'unknown')}")
            except Exception as save_error:
                print(f"Failed to save fallback record: {save_error}")
                break  # Prevent infinite loop if DB is broken
    
    db.close()
    print("Database connection closed.")