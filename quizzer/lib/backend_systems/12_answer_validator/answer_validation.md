(Will be done in a future update)
How Answer Validation Works

Every question record has a question_type associated with it,
Based on the question type involved, validating the provided input is correct requires a custom approach.

The abstraction layer to make this easier to build out new question_type would include
1. A QuestionTypeValidator abstract class
2. Individual concrete implementations for each QuestionType
3. A new internal check during initialization that checks if all question types have validation,
    - This would be there to ensure that developers not forgot critical components
4. An AnswerValidator class that unifies this structure
    - Contains a list of every question_type, similar to an enum, perhaps just use enum
    - Allows a single point of entry by which a question record, and the provided input is passed to the validator, 
    the validator decides which validation method it needs to use, then returns true or false for correctness, or 
    more information depending on. Should return a Map<String, dynamic> where the first key isCorrect: bool