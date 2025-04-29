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

/// Validates a user's answer for a select-all-that-apply question.
///
/// Args:
///   userAnswer: The answer submitted by the user (expected to be List<int> of selected indices).
///   correctIndices: The list of correct indices stored in the question details.
///
/// Returns:
///   true if the user selected exactly the correct options, false otherwise.
bool validateSelectAllThatApplyAnswer({
  required dynamic userAnswer,
  required List<int> correctIndices,
}) {
  // 1. Check if userAnswer is a List<int>
  if (userAnswer is! List<int>) {
    return false; // Incorrect type
  }

  // 2. Check if the lists have the same length
  if (userAnswer.length != correctIndices.length) {
    return false; // Different number of selections
  }

  // 3. Check if both lists contain the same elements (order doesn't matter)
  // Convert both to Sets for efficient comparison
  final Set<int> userAnswerSet = Set<int>.from(userAnswer);
  final Set<int> correctIndicesSet = Set<int>.from(correctIndices);

  // Check if the sets are equal (contain the same elements)
  return userAnswerSet.length == correctIndicesSet.length && // Ensure no duplicates affected length check
         userAnswerSet.containsAll(correctIndicesSet);
}