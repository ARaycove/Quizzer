// import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
// import 'package:quizzer/backend_systems/12_answer_validator/type_validators/fill_in_the_blank_validator.dart';

// TODO Write a class singleton object that encapsulates all functionality related to validating whether a user response to a question was correct (1)
// or incorrect (0), validation functions should return true or false booleans.

class AnswerAssessmentAPI {
  static final AnswerAssessmentAPI _instance = AnswerAssessmentAPI._internal();
  factory AnswerAssessmentAPI() => _instance;
  AnswerAssessmentAPI._internal();

}