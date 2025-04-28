import 'dart:math'; // Keep math import if needed for other functions later

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

  // Check if user answer is the correct type and value
  final bool isCorrect = (userAnswer is int && userAnswer == correctIndex);

  return isCorrect;
}

// TODO: Add validation functions for other question types (sort_order, text_input, etc.)

// TODO For every question type, a dedicated function should be written to validate input against actual answer
// Some of these validations are simple, while others become more complex