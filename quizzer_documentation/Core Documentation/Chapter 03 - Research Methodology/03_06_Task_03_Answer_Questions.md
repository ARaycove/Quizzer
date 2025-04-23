## Task_03: Answer Question-Answer pairs Task

At this phase, we have collected academic citations, individual passages, probable question outputs, probable answer outputs for questions, subject classification data, and concept/key-term classification data. The primary behavioral task for users of the Quizzer platform will be to answer these questions through direct match validation.

### Design Rationale

The Quizzer platform intentionally avoids self-reported correctness through confidence buttons or similar mechanisms. This design decision is based on several key observations:

1. **Unreliable Self-Assessment**: Users often struggle to accurately assess their own knowledge and confidence levels. Studies show that self-reported confidence frequently misaligns with actual performance.

2. **Cognitive Load**: Asking users to make multiple decisions (correctness + confidence) increases cognitive load and may interfere with the learning process.

3. **Response Time as a Proxy**: Instead of explicit confidence reporting, we use response time as an implicit measure of confidence, as it naturally correlates with the user's certainty.

4. **Objective Validation**: Each question type is designed to provide immediate, objective validation of correctness through direct matching or specific interaction patterns.

5. **Streamlined Experience**: By focusing on quick, direct responses, we maintain user engagement while still gathering valuable data about knowledge retention.

### Question Type Categories

Questions are categorized into three core formats, each with specific validation methods:

#### 1. Selection-Based Questions
All questions where users choose from provided options:

- **Multiple Choice**: Selecting one or more correct answers from a set
- **True/False**: The simplest form of multiple choice with only two options (will be a multiple_choice format)
- **Matching**: Pairing items from two lists (fundamentally selection-based)
- **Sorting/Ordering**: Arranging items in correct sequence (selection through ordering)

#### 2. Input-Based Questions
All questions requiring user-generated text or values:

- **Fill-in-the-Blank**: Any question requiring a specific word, phrase, or value
  - Includes equation completion, terminology recall, unit conversion, etc.
- **Short Answer**: Slightly longer response with some flexibility in wording
  - Generally limited to 1-3 words or a simple phrase

#### 3. Interactive Questions
Questions using spatial interaction beyond simple selection or text entry:

- **Hot Spot**: Clicking/tapping the correct location on an image
- **Diagram Labeling**: Placing labels in correct positions (drag-and-drop variation)

### Data Collection and Analysis

For each question attempt, we record:

- **qst_ans_reference**: Reference to the question-answer pair being attempted
- **response_time**: Time taken from question presentation to answer submission
- **response_result**: Whether the answer was correct or incorrect
- **user_uuid**: Unique identifier for the platform user
- **attempt_number**: The nth attempt by the user for this specific question
- **knowledge_base**: Current state of the user's knowledge (derived from subject and concept mentions)

### Knowledge Retention Modeling

Using the collected response data, along with the question context and the user's current knowledge state, among other possible data the user shares, we feed this information into a model that calculates:

1. The probability of correct response given the present context
2. The optimal timing for question review based on retention patterns

The model aims to determine: "At what time (t) will the user's probability of being correct (p) reach n%?" 

For maximizing retention while avoiding late reviews, we set n at 99% probability, meaning approximately 1 in 100 questions will be answered incorrectly. Machine learning techniques process the complete dataset to train and refine this mathematical model.

### Implementation Notes

- All interactions are timestamped to enable historical analysis
- Response times are recorded as they correlate with confidence levels
- The system maintains a question bank with:
  - Active pool: Questions currently in circulation
  - Reserve bank: Questions temporarily locked from circulation
  - Retired pool: Questions marked as no longer relevant

### Data Structure Reference
[[08_01_03_Question_Answer_Attempts_Table]]
