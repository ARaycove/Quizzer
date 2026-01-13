abstract class UserAnswerQuestionTypeValidator {
  /// For this validator, what question_type does it validate
  String get questionType;

  /// Key field names, what are the key fields stored in the question_answer_pair_table by which this question is validated
  /// Necessary to force understanding of what is involved in validation
  List<String> get validationFields;

  /// How will the question be validated
  Future<Map<String, dynamic>> validateAnswerToQuestion();
}