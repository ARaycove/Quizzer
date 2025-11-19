import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

/// QuestionGenerator encapsulates all functionality related to the creation of new questions
/// For exclusive use with the AddQuestionPage, holds all individual question generation methods for each question type.
class QuestionGenerator {
  static final QuestionGenerator _instance = QuestionGenerator._internal();
  factory QuestionGenerator() => _instance;
  QuestionGenerator._internal();

  // ----- Get Questions based on conditions -----
}