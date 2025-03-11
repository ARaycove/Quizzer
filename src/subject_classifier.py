"""
Question Classifier Module

This module provides a function to classify questions by subject using CLIP
(Contrastive Language-Image Pre-training) for multimodal processing of both text 
and image inputs with support for longer text sequences and comprehensive subject taxonomy.
"""

import os
import json
import torch
from typing import Dict, List, Optional, Any
from PIL import Image
import requests
from io import BytesIO
from transformers import CLIPProcessor, CLIPModel, pipeline

possible_classifiers = [
    "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
    "facebook/bart-large-mnli",
    "cross-encoder/nli-roberta-base",
    "joeddav/xlm-roberta-large-xnli"
]

# Models and device configuration
PRE_PROCESSING_MODEL = "openai/clip-vit-base-patch32"  # Supports 77 tokens
CLASSIFIER_MODEL = possible_classifiers[0]
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
DEFAULT_TAXONOMY_PATH = "system_data/subject_taxonomy.json"

# Global model instances
_clip_processor = None
_clip_model = None
_zero_shot_classifier = CLASSIFIER_MODEL
_subject_taxonomy = None


def _ensure_models_loaded():
    """Ensure all required models are loaded, using CPU-optimized versions."""
    global _clip_processor, _clip_model, _zero_shot_classifier
    
    # Set optimal CPU threading parameters
    import os
    os.environ["OMP_NUM_THREADS"] = "4"  # Optimize OpenMP threads
    os.environ["MKL_NUM_THREADS"] = "4"  # Optimize MKL threads
    # Set torch threads for CPU efficiency
    import torch
    torch.set_num_threads(4)
    if _clip_processor is None:
        _clip_processor = CLIPProcessor.from_pretrained(PRE_PROCESSING_MODEL)
    if _clip_model is None:
        _clip_model = CLIPModel.from_pretrained(PRE_PROCESSING_MODEL).to(DEVICE)
        _clip_model.eval()
    # Create pipeline with the smaller model
    _zero_shot_classifier = pipeline(
        "zero-shot-classification",
        model=CLASSIFIER_MODEL,
        device=-1  # Force CPU
    )


def _load_subject_taxonomy(taxonomy_path: str = DEFAULT_TAXONOMY_PATH) -> Dict[str, Any]:
    """
    Load the subject taxonomy from a JSON file.
    Args:
        taxonomy_path: Path to the taxonomy JSON file
    Returns:
        Dict containing the subject taxonomy
    """
    global _subject_taxonomy
    if _subject_taxonomy is None:
        with open(taxonomy_path, 'r', encoding='utf-8') as f:
            _subject_taxonomy = json.load(f)
        print(f"Loaded subject taxonomy from {taxonomy_path}")
        
        # Ensure we have the flattened subject list
        if "all_subjects" not in _subject_taxonomy:
            print("Warning: Taxonomy file doesn't contain a flattened subject list")
            # This would be handled by the generator script normally
    return _subject_taxonomy

def _extract_content(question_obj: Dict) -> torch.Tensor:
    """Extract multimodal features using CLIP from both question and answer images if available."""
    def load_image(image_path: str) -> Optional[Image.Image]:
        """Load an image from a file path or URL."""
        if not image_path:
            return Image.new('RGB', (224, 224), color="white")
        
        try:
            if image_path.startswith(('http://', 'https://')):
                response = requests.get(image_path, stream=True)
                return Image.open(BytesIO(response.content)).convert('RGB')
            elif os.path.exists(image_path):
                return Image.open(image_path).convert('RGB')
            else:
                print(f"Image not found: {image_path}")
                return Image.new('RGB', (224, 224), color="white")
        except Exception as e:
            print(f"Error loading image: {e}")
            return Image.new('RGB', (224, 224), color="white")
    def process_image_with_text(image, text):
        """Helper function to process an image with text through CLIP."""
        inputs = _clip_processor(
            text=text,
            images=image,
            return_tensors="pt",
            padding="max_length",
            max_length=77,
            truncation=True,
        ).to(DEVICE)
        with torch.no_grad():
            outputs = _clip_model(**inputs)
        return outputs.text_embeds.squeeze(0)
    # Load in appropriate elements of Question Object
    question_text = question_obj["question_text"]
    answer_text = question_obj["answer_text"]
    question_image = load_image(question_obj.get("question_image"))
    answer_image = load_image(question_obj.get("answer_image"))
    # Initialize text embeddings list
    text_embeddings = []
    
    if question_image is not None:
        text_embeddings.append(process_image_with_text(question_image, question_text))
    if answer_image is not None:
        text_embeddings.append(process_image_with_text(answer_image, answer_text))
    combined_content = torch.stack(text_embeddings).mean(dim=0)

    print(type(combined_content))
    return combined_content



def _classify_all_subjects(question_content: torch.Tensor, min_subjects: int = 3) -> List[str]:
    """
    Simplified classification function that only classifies against top-level domains.
    
    Args:
        text: Text to classify
        min_subjects: Minimum number of subjects to return
        
    Returns:
        List of subject categories
    """
    # Load subject taxonomy
    all_subjects = _subject_taxonomy.get("all_subjects", [])
    print(_subject_taxonomy["hierarchy"].keys())
    top_nesting = _subject_taxonomy["hierarchy"].keys()
    second_nesting = []
    for domain in top_nesting:
        second_nesting.extend(list((_subject_taxonomy["hierarchy"][domain].keys())))
    return _zero_shot_classifier(question_content)
    # We're going to create a multi-call system, which will integrate into a menu option inside of quizzer

    # The broader subject_taxonomy is a nested hierarchy, about 5 layers deep:
    # So we can refer to this all as layers 1 - 5
    # Step 1: Call the model to classify the question_object on layer 1 (5 options)
    #   - User will provide feedback
    # Step 2: Call the model for every "correct" option, in this case calling the model for each option that is correct (as labeled by the user) model is now going to classify the object against subjects in layer 2
    #   - User will provide feedback again
    # Step 3: Call the model again for "correct" options as labeled by the user, now we are classifying against subjects in layer 3
    #   - User will provide feedback again
    # Step 4 & 5: repeat the previous steps, this continues until we reach the end of the hierarchy, if the list of options is empty, the loop terminates

    # On every step the model is immediately trained (online learning)
    # Once we complete training on that object wwe will move to the next object

    # This function will the complete 5 steps, to be called for every object

def get_question_subjects(question_obj: Dict, 
                          taxonomy_path: str = DEFAULT_TAXONOMY_PATH, 
                          min_subjects: int = 3) -> List[str]:
    """
    Classify a question object by subject using multimodal analysis.
    Args:
        question_obj: Dictionary containing question information, including:
                     - question_text: Text of the question
                     - question_image: Path to an image
                     - answer_text: Text of the answer
                     - answer_image: Path to an image
        taxonomy_path: Path to the subject taxonomy JSON file
        min_subjects: Minimum number of subjects to return
        
    Returns:
        List of classified subjects
    """
    try:
        # Load models
        _ensure_models_loaded()
        _load_subject_taxonomy(taxonomy_path)
        question_content = _extract_content(question_obj)
        # Classify using zero-shot classification
        subjects = _classify_all_subjects(question_content, min_subjects)
        return subjects
        
    except Exception as e:
        print(f"Classification error: {e}")
        return ["miscellaneous"]
    

if __name__ == "__main__":
    print("Unit Test for Subject Classifier")
    test_object =  {
        "id": "2024-12-10 17:01:57.486159_47d39d7b-37ff-461b-aeec-ca52e36c101d",
        "primary_subject": "miscellaneous",
        "subject": [],
        "related": [
            "NoSQL"
        ],
        "question_text": "How does a NoSQL database store information?",
        "question_audio": None,
        "question_image": None,
        "question_video": None,
        "answer_text": "In an unstructured, flexible manner. Data is not related to other pieces of data.\n\n(This makes scaling easy by facilitating a change to the database structure itself without the need for complex data models)",
        "answer_audio": None,
        "answer_image": None,
        "answer_video": None,
        "module_name": "introduction to databases for back-end development",
        "author": "47d39d7b-37ff-461b-aeec-ca52e36c101d",
        "index_id": "question_index_1",
        "updateTime": "2024-12-10T17:01:58.521310Z"
    }

    print(get_question_subjects(test_object))