# Adding New Question Types to Quizzer Framework

## Overview

This guide outlines the step-by-step framework requirements for adding new question types with validation to the Quizzer system.

## Step-by-Step Implementation Process

### Step 1: Database Schema Design & Implementation

#### 1.1 Design Validation Data Structure
- **Define what constitutes a "correct" answer** for your question type
- **Design the validation data structure** that will be stored in the database
- **Determine validation approach**: Decide how to compare user answers against the correct answer(s). This involves understanding:
  - What format the user answer will be in
  - What format the correct answer is stored in
  - How to determine if they match (exact match, partial match, tolerance for errors, etc.)
  - Whether order matters, case sensitivity, etc.
  
  Examples from existing types:
  - **Exact match**: User answer must exactly match stored answer (example: multiple choice, true/false)
  - **Set comparison**: User must select exactly the correct options, order doesn't matter (example: select-all-that-apply)
  - **Sequence comparison**: User must arrange items in exact correct order (example: sort-order)
  - **Text similarity**: User answer is compared against primary answer and synonyms with tolerance for typos (example: fill-in-the-blank)
  - **Custom approach**: Design your own validation logic based on your question type requirements

#### 1.2 Database Schema Updates
**File**: `lib/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart`

- Add new columns if needed for type-specific data
  - **Examples**: 
    - `answers_to_blanks` (fill-in-the-blank): Stores `List<Map<String, List<String>>>` where each map contains primary answer as key and synonyms as values
    - `correct_order` (sort-order): Stores `List<Map<String, dynamic>>` representing the correct sequence of items
    - `index_options_that_apply` (select-all-that-apply): Stores `List<int>` of correct option indices
  - **Purpose**: Store question type-specific validation data that doesn't fit in standard question/answer elements
  - **Usage**: These fields are used by validation functions to check user answers against correct answers
- Update `verifyQuestionAnswerPairTable()` function with column checks
- Add migration logic for existing databases

#### 1.3 Add Question Function
Create `add[TypeName]Question()` function:
```dart
Future<String> add[TypeName]Question({
  required String moduleName,
  required List<Map<String, dynamic>> questionElements,
  required List<Map<String, dynamic>> answerElements,
  // Type-specific parameters
  required String qstContrib,
  String? citation,
  String? concepts,
  String? subjects,
}) async {
  // Implementation following existing patterns
}
```

#### 1.4 Edit Question Function
Update `editQuestionAnswerPair()` to handle the new question type parameters.

#### 1.5 Unit Tests for Database Layer
**File**: `test/02_subsequent_api/test_18_add_questions_api.dart`
- Write unit tests for the new `add[TypeName]Question()` function
- Test database schema updates and migration logic
- Test edit functionality for the new question type

**File**: `test/02_subsequent_api/test_19_fetch_and_update_question_records.dart`
- Write unit tests for `updateExistingQuestion()` with the new question type

### Step 2: Validation Layer Implementation

#### 2.1 Answer Validation Function
**File**: `lib/backend_systems/session_manager/answer_validation/session_answer_validation.dart`

Create validation function that implements your designed strategy:
```dart
bool validate[TypeName]Answer({
  required dynamic userAnswer,
  required [TypeSpecificData] correctData,
}) {
  // Implement your validation strategy here
  // Return true if user answer matches validation criteria
  // Return false otherwise
  // In some cases return a map with extra information to provide feedback to users
}
```

#### 2.2 Unit Tests for Validation
**File**: `test/02_subsequent_api/test_22_answer_validation_unit_tests.dart`
- Write unit tests for the new `validate[TypeName]Answer()` function
- Test correct answers, incorrect answers, edge cases, and type validation

### Step 3: Session Manager Integration

#### 3.1 Submit Answer Logic
**File**: `lib/backend_systems/session_manager/session_manager.dart`

Update `submitAnswer()` method:
```dart
case '[question_type]':
  isCorrect = validate[TypeName]Answer(
    userAnswer: userAnswer,
    correctData: correctData,
  );
  break;
```

**File**: `test/02_subsequent_api/test_22_answer_validation_unit_tests.dart`
- Update "Group 2: submitAnswer API tests" to include the new question type
- Test submitAnswer with correct and incorrect answers for the new type

#### 3.2 Add Question Logic
Update `addNewQuestion()` method:
```dart
case '[question_type]':
  if (requiredField == null) {
    throw ArgumentError('Missing required field for [question_type]');
  }
  await add[TypeName]Question(...);
  break;
```

**File**: `test/02_subsequent_api/test_18_add_questions_api.dart`
- Update addNewQuestion tests to include the new question type
- Test question creation via SessionManager for the new type

#### 3.3 Unit Tests for Session Manager
**File**: `test/02_subsequent_api/test_18_add_questions_api.dart`
- Test question creation via SessionManager for the new type
- Test answer submission and validation via SessionManager

### Step 4: UI Widget Implementation

#### 4.1 Question Display Widget
**File**: `lib/UI_systems/question_widgets/widget_[type_name].dart`

```dart
class [TypeName]QuestionWidget extends StatefulWidget {
  final List<Map<String, dynamic>> questionElements;
  final List<Map<String, dynamic>> answerElements;
  // Type-specific parameters
  final VoidCallback onNextQuestion;
  final bool isDisabled;
  final bool autoSubmitAnswer;
  final [TypeSpecificData]? customUserAnswer;
}
```

### Step 5: UI Integration Points

#### 5.1 Home Page Integration
**File**: `lib/UI_systems/02_home_page/home_page.dart`

Update `_buildQuestionWidget()` method with new case:
```dart
case '[question_type]':
  return [TypeName]QuestionWidget(
    key: key,
    onNextQuestion: _requestNextQuestion,
    questionElements: questionElements,
    answerElements: answerElements,
    // Type-specific parameters
  );
```

#### 5.2 Question Type Selection
**File**: `lib/UI_systems/03_add_question_page/widgets/widget_question_type_selection.dart`

Add to `_questionTypes` map:
```dart
const Map<String, String> _questionTypes = {
  // ... existing types
  '[question_type]': '[Display Name]',
};
```

#### 5.3 Add Question Page
**File**: `lib/UI_systems/03_add_question_page/add_question_answer_page.dart`

- Add type-specific validation in `_validateQuestionData()`
- Add type-specific UI controls

#### 5.4 Live Preview
**File**: `lib/UI_systems/03_add_question_page/widgets/widget_live_preview.dart`

Add case in `build()` method:
```dart
case '[question_type]':
  return [TypeName]QuestionWidget(
    // Pass preview data
    isDisabled: true,
  );
```

#### 5.5 Edit Question Dialog
**File**: `lib/UI_systems/global_widgets/widget_edit_question_dialogue.dart`

- Add type-specific validation in `_validateQuestionData()`
- Add type-specific UI controls

## Implementation Checklist

- [ ] Database schema updates and migration logic
- [ ] Add question function in database layer
- [ ] Edit question function updates
- [ ] Unit tests for database layer
- [ ] Answer validation function
- [ ] Unit tests for validation
- [ ] SessionManager submitAnswer integration
- [ ] SessionManager addNewQuestion integration
- [ ] Unit tests for SessionManager
- [ ] Question display widget
- [ ] Home page integration
- [ ] Question type selection integration
- [ ] Add question page integration
- [ ] Live preview integration
- [ ] Edit question dialog integration

## TODO Checklist

```dart
// TODO: Design validation data structure for new question type
// TODO: Add new database column for type-specific validation data
// TODO: Update verifyQuestionAnswerPairTable() with column checks
// TODO: Add migration logic for existing databases
// TODO: Create add[TypeName]Question() function in question_answer_pairs_table.dart
// TODO: Update editQuestionAnswerPair() to handle new question type
// TODO: Write unit tests for add[TypeName]Question() function
// TODO: Write unit tests for database schema updates
// TODO: Create validate[TypeName]Answer() function in session_answer_validation.dart
// TODO: Write unit tests for validate[TypeName]Answer() function
// TODO: Update submitAnswer() method in session_manager.dart for new question type
// TODO: Update addNewQuestion() method in session_manager.dart for new question type
// TODO: Write unit tests for SessionManager question creation
// TODO: Write unit tests for SessionManager answer submission
// TODO: Create [TypeName]QuestionWidget in lib/UI_systems/question_widgets/widget_[type_name].dart
// TODO: Update _buildQuestionWidget() method in home_page.dart
// TODO: Add new question type to _questionTypes map in widget_question_type_selection.dart
// TODO: Add type-specific validation in _validateQuestionData() in add_question_answer_page.dart
// TODO: Add type-specific UI controls in add_question_answer_page.dart
// TODO: Add case in build() method in widget_live_preview.dart
// TODO: Add type-specific validation in _validateQuestionData() in widget_edit_question_dialogue.dart
// TODO: Add type-specific UI controls in widget_edit_question_dialogue.dart
```
