import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';


/// The QuestionAnswerPairManager encapsulates all functionality related to the physical question records
/// To access individual user relationships with the question records use the UserQuestionManager object
class QuestionAnswerPairManager {
  static final QuestionAnswerPairManager _instance = QuestionAnswerPairManager._internal();
  factory QuestionAnswerPairManager() => _instance;
  QuestionAnswerPairManager._internal();

  // ----- Get Questions based on conditions -----
}