from PIL import Image, ImageDraw, ImageFont
from typing import List, Union
from PIL import Image
import io
from torchvision import transforms
import os
from utility.sync_fetch_data import initialize_supabase_session
from supabase import Client
import torchvision.transforms as transforms
import yake
from latex2sympy2 import latex2sympy
import re
import pandas as pd
import numpy as np
from sklearn.decomposition import PCA


# Define the transform pipeline
transform = transforms.Compose([
    transforms.Resize((224, 224)),  # Resize to standard size
    transforms.ToTensor(),          # Convert PIL to tensor [0,1]
    transforms.Normalize(           # Normalize for pretrained models
        mean=[0.485, 0.456, 0.406], # ImageNet means
        std=[0.229, 0.224, 0.225]   # ImageNet stds
    )
])

def load_image(image_name: str):
    """
    Load an image from local path or Supabase storage.
    Returns a PIL Image (not tensor) if found, None if not.
    """
    # Handle empty or None image_name
    if not image_name:
        return Image.new('RGB', (224, 224), color='white')
    
    local_path = os.path.join("data_images", image_name)
    
    # Try to load from local path first
    if os.path.exists(local_path):
        try:
            img = Image.open(local_path).convert('RGB')
            return img  # Return PIL Image, not tensor
        except Exception as e:
            print(f"Error loading local image {image_name}: {e}")
            return Image.new('RGB', (224, 224), color='white')
    
    # Try to download from Supabase if not found locally
    try:
        supabase_client: Client = initialize_supabase_session()
        res = supabase_client.storage.from_('question-answer-pair-assets').download(image_name)
        
        # Create directory if it doesn't exist
        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        
        # Save the downloaded file locally
        with open(local_path, "wb") as f:
            f.write(res)
        
        # Load and return PIL image (not tensor)
        img = Image.open(io.BytesIO(res)).convert('RGB')
        return img
        
    except Exception as e:
        print(f"Error downloading/processing image {image_name}: {e}")
        return Image.new('RGB', (224, 224), color='white')
    

def text_to_image(text: str, width: int = 800, font_size: int = 16) -> Image.Image:
    """Convert text to image with proper wrapping."""
    if not text:
        return Image.new('RGB', (width, 50), color='white')
    
    try:
        font = ImageFont.truetype("arial.ttf", font_size)
    except:
        font = ImageFont.load_default()
    
    # Calculate text dimensions with wrapping
    words = text.split()
    lines = []
    current_line = []
    
    temp_img = Image.new('RGB', (1, 1), color='white')
    temp_draw = ImageDraw.Draw(temp_img)
    
    for word in words:
        test_line = ' '.join(current_line + [word])
        text_width = temp_draw.textbbox((0, 0), test_line, font=font)[2]
        
        if text_width <= width - 20:  # 10px margin on each side
            current_line.append(word)
        else:
            if current_line:
                lines.append(' '.join(current_line))
                current_line = [word]
            else:
                lines.append(word)  # Single word longer than width
    
    if current_line:
        lines.append(' '.join(current_line))
    
    # Calculate image height
    line_height = temp_draw.textbbox((0, 0), "Ay", font=font)[3] + 5
    height = max(50, len(lines) * line_height + 20)
    
    # Create final image
    img = Image.new('RGB', (width, height), color='white')
    draw = ImageDraw.Draw(img)
    
    y_offset = 10
    for line in lines:
        draw.text((10, y_offset), line, fill='black', font=font)
        y_offset += line_height
    
    return img

def combine_images_vertically(images: List[Image.Image], target_width: int = 800) -> Image.Image:
    """Combine multiple images vertically into one image."""
    if not images:
        return Image.new('RGB', (target_width, 50), color='white')
    
    # Resize all images to same width
    resized_images = []
    for img in images:
        if img.width != target_width:
            aspect_ratio = img.height / img.width
            new_height = int(target_width * aspect_ratio)
            img = img.resize((target_width, new_height), Image.Resampling.LANCZOS)
        resized_images.append(img)
    
    # Calculate total height
    total_height = sum(img.height for img in resized_images)
    
    # Create combined image
    combined = Image.new('RGB', (target_width, total_height), color='white')
    
    y_offset = 0
    for img in resized_images:
        combined.paste(img, (0, y_offset))
        y_offset += img.height
    
    return combined

def get_keywords(sentence):
    """
    Extract keywords using YAKE library
    """
    if not sentence or not isinstance(sentence, str):
        return []
    
    # manually exclude keywords that are not related to subject matter or concept matter
    excluded = ["lowest to highest", "highest to lowest", "correct order", "identify terms", "describes the solution", 
                "find the missing", "directly", "Find", "find", "select", "Select",]

    language = "en"
    max_ngram_size = 3  # Extract up to 3-word phrases
    deduplication_threshold = 0.9
    num_keywords = 10
    
    custom_kw_extractor = yake.KeywordExtractor(
        lan=language,
        n=max_ngram_size,
        dedupLim=deduplication_threshold,
        top=num_keywords
    )
    
    keywords = custom_kw_extractor.extract_keywords(sentence)
    
    # Return just the keyword strings (YAKE returns tuples with scores)
    return [keyword for keyword, score in keywords if keyword not in excluded]

def get_is_math(sentence):
    if not sentence or not isinstance(sentence, str):
        return False
    
    latex_matches = re.findall(r'\$(.+?)\$', sentence)
    
    if not latex_matches:
        return False
    
    for latex_expr in latex_matches:
        try:
            latex2sympy(latex_expr.strip())
            return True
        except:
            continue
    
    return False

def filter_df_for_k_means(df):
    """
    Filter DataFrame to keep only columns needed for K-means clustering.
    
    Parameters:
    df (pandas.DataFrame): Original DataFrame with all metadata
    
    Returns:
    pandas.DataFrame: Filtered DataFrame with only the required columns:
        - question_id: Identifier for each question
        - question_vector: Vector representation for clustering
        - is_math: Boolean/binary indicator for math questions
        - keywords: Keywords associated with each question
    """
    # Define the columns we want to keep
    required_columns = ['question_id', 'question_vector', 'is_math', "keywords"]
    
    # Filter the DataFrame to keep only the required columns
    filtered_df = df[required_columns].copy()
    
    return filtered_df

def calculate_optimal_pca_components(num_samples: int, num_features: int) -> int:
    """
    Calculate optimal number of PCA components using established statistical guidelines.
    
    Args:
        num_samples: Number of data samples
        num_features: Number of original features
    
    Returns:
        Recommended number of PCA components
    """
    print(f"Calculating optimal PCA components:")
    print(f"  - Dataset: {num_samples} samples, {num_features} features")
    
    # Rule 1: Bartlett's criterion - minimum 5-10 observations per variable
    # For PCA specifically, 5 samples per component is the statistical minimum
    min_samples_per_component = 5
    components_bartlett = num_samples // min_samples_per_component
    
    # Rule 2: Kaiser-Meyer-Olkin sampling adequacy - never exceed n/2
    components_kmo = num_samples // 2
    
    # Rule 3: Cumulative variance rule - typically 80-90% of variance
    # For high-dimensional sparse data, this translates to roughly n/10 to n/5
    components_variance = num_samples // 8
    
    # Rule 4: Absolute ceiling - cannot exceed min(samples-1, features)
    absolute_max = min(num_samples - 1, num_features)
    
    print(f"  - Bartlett criterion (5 samples/component): {components_bartlett}")
    print(f"  - KMO sampling adequacy (n/2 max): {components_kmo}")
    print(f"  - Variance preservation rule (n/8): {components_variance}")
    print(f"  - Absolute maximum possible: {absolute_max}")
    
    # Take the most restrictive (conservative) estimate
    recommended = min(components_bartlett, components_kmo, components_variance, absolute_max)
    recommended = max(recommended, 2)
    
    print(f"  - Recommended components: {recommended}")
    print(f"  - Final ratio: {num_samples/recommended:.1f} samples per component")
    
    return recommended

def run_pca(df: pd.DataFrame, p: int) -> pd.DataFrame:
    """
    Apply PCA to reduce dimensionality of a DataFrame, dynamically unpacking array columns.
    Preserves non-numeric identifier columns.
    
    Args:
        df: Input DataFrame with potential array columns
        p: Number of PCA components to reduce to
    
    Returns:
        DataFrame with PCA-reduced features and preserved identifiers
    """
    print(f"Starting PCA reduction to {p} components...")
    print(f"  - Input shape: {df.shape}")
    
    df_expanded = df.copy()
    unpacked_columns = []
    identifier_columns = []
    
    for col in df.columns:
        first_value = df[col].iloc[0]
        
        # Check if column contains arrays (numpy arrays or lists)
        if isinstance(first_value, (np.ndarray, list)) and len(first_value) > 1:
            print(f"  - Unpacking column '{col}' with {len(first_value)} dimensions")
            
            # Convert to DataFrame with individual columns
            col_df = pd.DataFrame(
                df[col].tolist(),
                columns=[f'{col}_{i}' for i in range(len(first_value))],
                index=df.index
            )
            
            # Remove original column and add unpacked columns
            df_expanded = df_expanded.drop(col, axis=1)
            df_expanded = pd.concat([df_expanded, col_df], axis=1)
            unpacked_columns.append(col)
        
        # Check if column is non-numeric identifier (strings, objects)
        elif df[col].dtype == 'object' or df[col].dtype.name.startswith('string'):
            print(f"  - Preserving identifier column '{col}'")
            identifier_columns.append(col)
    
    # Separate identifiers from numeric data
    identifier_data = df_expanded[identifier_columns] if identifier_columns else pd.DataFrame(index=df.index)
    numeric_data = df_expanded.drop(columns=identifier_columns)
    
    print(f"  - After unpacking: {df_expanded.shape}")
    print(f"  - Unpacked columns: {unpacked_columns}")
    print(f"  - Preserved identifiers: {identifier_columns}")
    print(f"  - Numeric data shape: {numeric_data.shape}")
    
    # Apply PCA only to numeric data
    pca = PCA(n_components=p)
    pca_result = pca.fit_transform(numeric_data)
    
    print(f"  - PCA explained variance ratio: {pca.explained_variance_ratio_.sum():.3f}")
    
    # Create new DataFrame with PCA components
    pca_df = pd.DataFrame(
        pca_result,
        columns=[f'pca_{i}' for i in range(p)],
        index=df.index
    )
    
    # Combine identifiers with PCA results
    final_df = pd.concat([identifier_data, pca_df], axis=1)
    
    print(f"  - Final shape: {final_df.shape}")
    print("PCA reduction completed.")
    
    return final_df

if __name__ == "__main__":
    # Download required NLTK data (run once)
    # nltk.download('punkt')
    # nltk.download('stopwords') 
    # nltk.download('averaged_perceptron_tagger')
    # nltk.download('punkt_tab')
    # nltk.download('averaged_perceptron_tagger_eng')
    print(get_is_math("something is here $1 + 2$ yes!"))
    print(get_is_math("not_math"))