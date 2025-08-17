import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

/// Validates a user's answer for a multiple-choice question.
/// 
/// Args:
///   userAnswer: The answer submitted by the user (expected to be the selected index as an int).
///   correctIndex: The correct index stored in the question details.
///
/// Returns:
///   true if the answer is correct, false otherwise.
bool validateMultipleChoiceAnswer({
  required dynamic userAnswer,
  required int? correctIndex,
}) {
  try {
    QuizzerLogger.logMessage('Entering validateMultipleChoiceAnswer()...');
    // Check if user answer is the correct type and value
    final bool isCorrect = (userAnswer is int && userAnswer == correctIndex);
    return isCorrect;
  } catch (e) {
    QuizzerLogger.logError('Error in validateMultipleChoiceAnswer - $e');
    rethrow;
  }
}

/// Validates a user's answer for a select-all-that-apply question.
///
/// Args:
///   userAnswer: The answer submitted by the user (expected to be List<int> of selected indices).
///   correctIndices: The list of correct indices stored in the question details.
///
/// Returns:
///   true if the user selected exactly the correct options, false otherwise.
///   Note: Empty lists are considered valid when both userAnswer and correctIndices are empty.
bool validateSelectAllThatApplyAnswer({
  required dynamic userAnswer,
  required List<int> correctIndices,
}) {
  try {
    QuizzerLogger.logMessage('Entering validateSelectAllThatApplyAnswer()...');
    // 1. Check if userAnswer is a List (allow empty lists)
    if (userAnswer is! List) {
      return false; // Incorrect type
    }

    // 2. Handle empty lists case (both empty is valid)
    if (userAnswer.isEmpty && correctIndices.isEmpty) {
      return true; // Both empty is a valid state
    }

    // 3. For non-empty lists, check if all elements are int
    if (userAnswer.isNotEmpty) {
      for (final element in userAnswer) {
        if (element is! int) {
          return false; // Contains non-int elements
        }
      }
    }

    // 3. Check if the lists have the same length
    if (userAnswer.length != correctIndices.length) {
      return false; // Different number of selections
    }

    // 4. Check if both lists contain the same elements (order doesn't matter)
    // Convert both to Sets for efficient comparison
    final Set<int> userAnswerSet = Set<int>.from(userAnswer);
    final Set<int> correctIndicesSet = Set<int>.from(correctIndices);

    // Check if the sets are equal (contain the same elements)
    return userAnswerSet.length == correctIndicesSet.length && // Ensure no duplicates affected length check
           userAnswerSet.containsAll(correctIndicesSet);
  } catch (e) {
    QuizzerLogger.logError('Error in validateSelectAllThatApplyAnswer - $e');
    rethrow;
  }
}

/// Validates a user's answer for a true/false question.
///
/// Args:
///   userAnswer: The answer submitted by the user (expected to be 0 for True, 1 for False).
///   correctIndex: The correct index stored in the question details (0 or 1).
///
/// Returns:
///   true if the answer is correct, false otherwise.
bool validateTrueFalseAnswer({
  required dynamic userAnswer,
  required int correctIndex,
}) {
  try {
    assert(correctIndex == 0 || correctIndex == 1, 
           'Invalid correctIndex ($correctIndex) for true/false validation.');

    // Normalize string inputs to integers (0 or 1)
    int normalizedAnswer;
    if (userAnswer is String) {
      final String lowerCaseAnswer = userAnswer.toLowerCase();
      if (lowerCaseAnswer == 'true') {
        normalizedAnswer = 1;
      } else if (lowerCaseAnswer == 'false') {
        normalizedAnswer = 0;
      } else {
        // If the string is neither "true" nor "false", treat it as an invalid answer
        return false;
      }
    } else if (userAnswer is int) {
      // Check if the integer input is valid (0 or 1)
      if (userAnswer == 0 || userAnswer == 1) {
        normalizedAnswer = userAnswer;
      } else {
        // Integer is not 0 or 1, treat as invalid
        return false;
      }
    } else {
      // Input is not a valid type (String or int)
      return false;
    }
    
    // Compare the normalized answer to the correct index
    final bool isCorrect = (normalizedAnswer == correctIndex);
    return isCorrect;
  } catch (e) {
    // Log error and rethrow
    rethrow;
  }
}

// --- Sort Order Validation ---

/// Validates a user's answer for a sort_order question.
///
/// Args:
///   userAnswer: The answer submitted by the user (expected to be List<String> in the user's chosen order).
///   correctOrder: The list representing the correct order (typically from the 'options' field).
///
/// Returns:
///   true if the user's list matches the correct order exactly, false otherwise.
bool validateSortOrderAnswer({
  required List<Map<String, dynamic>> userAnswer,
  required List<Map<String, dynamic>> correctOrder,
}) {
  try {
    QuizzerLogger.logMessage('Entering validateSortOrderAnswer()...');
    // 1. Check if lists have the same length
    //    (Type check List<Map<String, dynamic>> is handled by the function signature)
    if (userAnswer.length != correctOrder.length) {
      return false; // Different number of items
    }

    // 2. Compare elements element by element based on 'content' field
    for (int i = 0; i < correctOrder.length; i++) {
      final userMap = userAnswer[i];
      final correctMap = correctOrder[i];

      // Basic check: ensure both are maps and contain 'content'
      // Using `containsKey` for safety, though `[]` access would throw on missing key (Fail Fast)
      if (!userMap.containsKey('content') || !correctMap.containsKey('content')) {
          // Or log error and return false if missing keys are invalid states
          throw StateError('Sort order element map missing \'content\' key at index $i');
      }

      // Compare the content fields
      if (userMap['content'] != correctMap['content']) {
        return false; // Mismatch found at this position
      }
    }

    // If all elements matched in order based on content, the answer is correct
    return true;
  } catch (e) {
    QuizzerLogger.logError('Error in validateSortOrderAnswer - $e');
    rethrow;
  }
}



