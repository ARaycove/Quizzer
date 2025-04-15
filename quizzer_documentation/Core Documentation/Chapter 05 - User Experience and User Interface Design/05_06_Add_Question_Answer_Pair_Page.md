# Add Question-Answer Pair Page

## Purpose
This page provides a streamlined interface for quickly submitting complete question-answer pairs. It's designed for efficient content creation, with classification and verification handled through separate processes.

## Interface Elements

### Question Type Selection
- **Dropdown**: Basic selection of question types:
  - Multiple choice (Currently Implemented)
  - True/False
  - Matching
  - Sorting
  - Fill-in-blank
  - Short answer
  - Hot spot
  - Diagram labeling

### Question Entry
- **Drag-and-Drop Interface**: For building question elements
  - Each element stored as a map: `{'type': String, 'content': String}`
  - Supported types: text, image, audio, video
  - Elements can be reordered via drag-and-drop
  - Stored in `question_elements` as JSON array

### Multiple Choice Options (Shown only for Multiple Choice type)
- **Options Dialog**: Appears below question field
  - Add Option Button: Creates new option entry field
  - Option Entry Fields: Text input for each possible answer
  - Correct Answer Toggle: Radio button next to each option
    - Only one option can be selected as correct
    - Visual indicator for selected correct answer
  - Remove Option Button: Allows deletion of unwanted options
  - Minimum of 2 options required
  - Maximum of 6 options allowed
  - Options stored in `answer_options` as JSON array
  - Correct answer stored in `correct_option_index` as integer

### Answer Entry
- **Drag-and-Drop Interface**: Matching question capabilities
  - Same element structure as question field
  - Stored in `answer_elements` as JSON array
  - Appears for multiple choice, but serves as the explanation for the correct option

## Buttons
- **Upload Media Button**
  - Opens system file browser
  - Allows selection of any supported media file (image, audio, video)
  - Validates file type and adds to current element list
  - Calls [[07_15_uploadMedia()|uploadMedia()]] function
  - Shows error message for unsupported file types

- **Submit Button**
  - Calls [[07_14_addQuestionAnswerPair()|addQuestionAnswerPair()]] function
  - Validates required fields before submission
  - For Multiple Choice:
    - Validates at least 2 options exist
    - Validates exactly one correct answer is selected
  - Stores pair in database for later classification

## User Experience Notes
- Maintain dark theme (Color(0xFF0A1929)) with light green accents
- Keep interface simple and focused
- Provide basic validation for required fields
- Show clear error messages for invalid entries
- Implement intuitive drag-and-drop functionality
- Provide visual feedback during element manipulation
- For Multiple Choice:
  - Clear visual distinction between correct and incorrect options
  - Smooth animation when adding/removing options
  - Immediate feedback when selecting correct answer

## Implementation Notes
- Follow the application's dark theme with light green accents
- Maintain consistent button styling
- Support responsive design
- Include basic error handling
- Implement logging for submissions
- Use Flutter's drag-and-drop widgets for element manipulation
- Ensure proper JSON serialization of element maps
- For Multiple Choice:
  - Use RadioListTile for option selection
  - Implement smooth animations for option management
  - Store options and correct answer in separate fields
  - Validate option count and correct answer selection
