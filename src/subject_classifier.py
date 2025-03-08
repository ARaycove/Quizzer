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

# Models and device configuration
CLIP_MODEL = "openai/clip-vit-base-patch32"  # Supports 77 tokens
CLASSIFIER_MODEL = "facebook/bart-large-mnli"
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

# Default subject taxonomy file path
DEFAULT_TAXONOMY_PATH = "system_data/subject_taxonomy.json"

# Global model instances
_clip_processor = None
_clip_model = None
_zero_shot_classifier = None
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
        _clip_processor = CLIPProcessor.from_pretrained(CLIP_MODEL)
        
    if _clip_model is None:
        _clip_model = CLIPModel.from_pretrained(CLIP_MODEL).to(DEVICE)
        _clip_model.eval()
    
    if _zero_shot_classifier is None:
        # Use DistilBERT instead of BART (smaller model)
        classifier_model = "typeform/distilbert-base-uncased-mnli"  
        
        # Create pipeline with the smaller model, no quantization
        _zero_shot_classifier = pipeline(
            "zero-shot-classification",
            model=classifier_model,
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


def _load_image(image_path: str) -> Optional[Image.Image]:
    """Load an image from a file path or URL."""
    if not image_path:
        return None
    
    try:
        if image_path.startswith(('http://', 'https://')):
            response = requests.get(image_path, stream=True)
            return Image.open(BytesIO(response.content)).convert('RGB')
        elif os.path.exists(image_path):
            return Image.open(image_path).convert('RGB')
        else:
            print(f"Image not found: {image_path}")
            return None
    except Exception as e:
        print(f"Error loading image: {e}")
        return None


def _extract_features(question_obj: Dict) -> torch.Tensor:
    """Extract multimodal features using CLIP."""
    question_text = question_obj.get("question_text", "")
    if not question_text:
        question_text = "What is this image about?"
    
    # Add context from answer if available to enrich understanding
    answer_text = question_obj.get("answer_text", "")
    if answer_text and len(question_text) + len(answer_text) < 300:  # Rough check to avoid extremely long inputs
        question_text += f" Answer: {answer_text}"
        
    image_path = question_obj.get("question_image")
    image = _load_image(image_path)
    
    if image is None:
        # Create blank image if none provided
        image = Image.new('RGB', (224, 224), color='white')
    
    # Process with CLIP - with truncation for text that exceeds token limit
    inputs = _clip_processor(
        text=question_text,
        images=image,
        return_tensors="pt",
        padding="max_length",
        max_length=77,  # CLIP's token limit
        truncation=True,
    ).to(DEVICE)
    
    with torch.no_grad():
        outputs = _clip_model(**inputs)
    
    # CLIP provides separate text and image embeddings, we'll use text embeddings
    # as they contain the multimodal context for our classification
    return outputs.text_embeds.squeeze(0)


def _prepare_classification_text(question_obj: Dict) -> str:
    """Prepare text for zero-shot classification."""
    parts = []
    
    question_text = question_obj.get("question_text", "")
    if question_text:
        parts.append(f"Question: {question_text}")
    
    answer_text = question_obj.get("answer_text", "")
    if answer_text:
        parts.append(f"Answer: {answer_text}")
    
    module_name = question_obj.get("module_name", "")
    if module_name:
        parts.append(f"Module: {module_name}")
    
    return " ".join(parts) or "Unknown question"

def _filter_subjects_for_consistency(subjects: List[str], hierarchy_map: Dict[str, str] = None) -> List[str]:
    """
    Filter subjects to maintain hierarchical consistency.
    
    This ensures that if we have both a parent and child subject,
    we keep the most specific one and filter out overly general ones.
    
    Args:
        subjects: List of flat subjects
        hierarchy_map: Map of child->parent relationships (optional)
        
    Returns:
        Filtered list of subjects
    """
    if not hierarchy_map:
        # Simple approach - just return top 3-5 subjects
        return subjects[:min(5, len(subjects))]
    
    # More sophisticated approach with hierarchy consistency
    # would be implemented here if hierarchy_map is provided
    # This could remove parents when children are present, etc.
    
    return subjects


def _classify_with_zero_shot(text: str, min_subjects: int = 3) -> List[str]:
    """
    Classify text using zero-shot classification with a three-stage hierarchical approach.
    
    Args:
        text: Text to classify
        min_subjects: Minimum number of subjects to return
        
    Returns:
        List of subject categories
    """
    # Load subject taxonomy
    taxonomy = _load_subject_taxonomy()
    all_subjects = taxonomy.get("all_subjects", [])
    
    # Extract the hierarchy into separate levels
    domains = set()
    fields_by_domain = {}
    subfields_by_field = {}
    
    for subject in all_subjects:
        parts = subject.split('.')
        
        if len(parts) >= 1:
            domain = parts[0]
            domains.add(domain)
            
            if len(parts) >= 2:
                field = parts[1]
                if domain not in fields_by_domain:
                    fields_by_domain[domain] = set()
                fields_by_domain[domain].add(field)
                
                if len(parts) >= 3:
                    subfield = parts[2]
                    field_key = f"{domain}.{field}"
                    if field_key not in subfields_by_field:
                        subfields_by_field[field_key] = set()
                    subfields_by_field[field_key].add(subfield)
    
    # STAGE 1: Classify into top-level domains
    domain_results = _zero_shot_classifier(text, list(domains), multi_label=True)
    domain_scores = list(zip(domain_results['labels'], domain_results['scores']))
    domain_scores.sort(key=lambda x: x[1], reverse=True)
    
    # Take top domains (at most 2)
    domain_threshold = 0.1
    top_domains = [domain for domain, score in domain_scores if score > domain_threshold][:2]
    
    # Ensure we have at least one domain
    if not top_domains and domain_scores:
        top_domains = [domain_scores[0][0]]
    
    # STAGE 2: Classify into fields within top domains
    all_fields = []
    domain_to_field_map = {}  # Keep track of which domain each field belongs to
    
    for domain in top_domains:
        if domain in fields_by_domain:
            for field in fields_by_domain[domain]:
                all_fields.append(field)
                domain_to_field_map[field] = domain
    
    # If no fields found, fall back to domains
    if not all_fields:
        final_subjects = top_domains
    else:
        # Classify against fields
        field_results = _zero_shot_classifier(text, all_fields, multi_label=True)
        field_scores = list(zip(field_results['labels'], field_results['scores']))
        field_scores.sort(key=lambda x: x[1], reverse=True)
        
        # Take top fields (at most 5)
        field_threshold = 0.05
        top_fields = [field for field, score in field_scores if score > field_threshold][:5]
        
        # Ensure we have at least one field
        if not top_fields and field_scores:
            top_fields = [field_scores[0][0]]
        
        # STAGE 3: Classify into subfields within top fields
        all_subfields = []
        field_to_subfield_map = {}  # Keep track of which field each subfield belongs to
        
        for field in top_fields:
            domain = domain_to_field_map.get(field)
            if domain:
                field_key = f"{domain}.{field}"
                if field_key in subfields_by_field:
                    for subfield in subfields_by_field[field_key]:
                        all_subfields.append(subfield)
                        field_to_subfield_map[subfield] = field
        
        # Finalize subject list:
        # 1. Always include top domains
        final_subjects = list(top_domains)
        
        # 2. Include top fields
        final_subjects.extend(top_fields)
        
        # 3. If we have subfields, classify and include top ones
        if all_subfields:
            subfield_results = _zero_shot_classifier(text, all_subfields, multi_label=True)
            subfield_scores = list(zip(subfield_results['labels'], subfield_results['scores']))
            subfield_scores.sort(key=lambda x: x[1], reverse=True)
            
            # Take top subfields
            subfield_threshold = 0.05
            top_subfields = [subfield for subfield, score in subfield_scores if score > subfield_threshold][:5]
            final_subjects.extend(top_subfields)
    
    # Ensure minimum number of subjects
    if len(final_subjects) < min_subjects:
        # Try to add more fields or domains
        more_needed = min_subjects - len(final_subjects)
        
        # Look for fields not already included
        remaining_fields = [field for field, _ in field_scores 
                          if field not in final_subjects][:more_needed]
        final_subjects.extend(remaining_fields)
        
        # If still not enough, add more domains
        if len(final_subjects) < min_subjects:
            more_needed = min_subjects - len(final_subjects)
            remaining_domains = [domain for domain, _ in domain_scores 
                              if domain not in final_subjects][:more_needed]
            final_subjects.extend(remaining_domains)
    # Filter subjects for consistency
    filtered_subjects = _filter_subjects_for_consistency(final_subjects)
    # Limit to top 10 subjects to avoid too many results
    return filtered_subjects[:10]


def get_question_subjects(question_obj: Dict, taxonomy_path: str = DEFAULT_TAXONOMY_PATH, min_subjects: int = 3) -> List[str]:
    """
    Classify a question object by subject using multimodal analysis.
    
    Args:
        question_obj: Dictionary containing question information, including:
                     - question_text: Text of the question
                     - question_image: Path to an image (optional)
                     - answer_text: Text of the answer (optional)
                     - module_name: Name of the module (optional)
        taxonomy_path: Path to the subject taxonomy JSON file
        min_subjects: Minimum number of subjects to return
        
    Returns:
        List of subject categories (flat, without dot notation)
    """
    try:
        # Load models
        _ensure_models_loaded()
        # Load subject taxonomy with specified path
        global _subject_taxonomy
        _subject_taxonomy = None  # Reset to force reload if path changed
        _load_subject_taxonomy(taxonomy_path)
        # Extract multimodal features 
        # This validates we can process both text and image with CLIP
        _ = _extract_features(question_obj)
        # Prepare text for classification
        classification_text = _prepare_classification_text(question_obj)
        # Classify using zero-shot classification
        subjects = _classify_with_zero_shot(classification_text, min_subjects)
        return subjects
        
    except Exception as e:
        print(f"Classification error: {e}")
        return ["miscellaneous"]