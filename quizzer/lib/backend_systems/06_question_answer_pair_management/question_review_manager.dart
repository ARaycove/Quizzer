import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

/// Should be available to admin and contributor accounts only, all methods in this object will immediately return if the user does not have the correct permissions
/// Encapsulates all functionality related to the Review Panel, this coordinates which question out of the backlog will get presented to the reviewer for active review
class QuestionReviewManager {
  static final QuestionReviewManager _instance = QuestionReviewManager._internal();
  factory QuestionReviewManager() => _instance;
  QuestionReviewManager._internal();

  // ----- Get Questions based on conditions -----
}