import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

/// Internal Validator, encapsulates all functionality and definitions relating to what
/// makes a question valid and verifies that all data entered is of the appropriate type
/// and structure. For example, the question_text field must be Map with specific key 
/// names and values for those fields, this contains the methods that can be called to 
/// ensure that before submitting everything is structured as expected
class QuestionValidator {
  static final QuestionValidator _instance = QuestionValidator._internal();
  factory QuestionValidator() => _instance;
  QuestionValidator._internal();
}