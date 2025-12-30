import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/05_question_queue_server/user_questions/user_question_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common/sqlite_api.dart';

class TotalEligibleQuestions extends StatField{
  static final TotalEligibleQuestions _instance = TotalEligibleQuestions._internal();
  factory TotalEligibleQuestions() => _instance;
  TotalEligibleQuestions._internal();

  @override
  String get name => "total_eligible_questions";

  @override
  String get type => "INTEGER";

  @override
  int get defaultValue => 0;

  int _cachedValue = 0;
  @override
  int get currentValue => _cachedValue;

  set currentValue(int value) {
    _cachedValue = value;
  }

  @override
  String get description => "Total number of questions currently in circulation and not flagged.";

  @override
  bool get isIncremental => false;

  @override
  Future<int> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType}) async {
    try {    
      final int eligibleCount = await UserQuestionManager().getEligibleUserQuestionAnswerPairs(
        txn: txn,
        countOnly: true,
        includeQuestionPairs: false  // We don't need the question pairs for counting
      ) as int;
      
      currentValue = eligibleCount;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to recalculate total_eligible_questions: $e');
      rethrow;
    }
  }

  @override
  Future<int> calculateCarryForwardValue({Transaction? txn, Map<String, dynamic>? previousRecord, Map<String, dynamic>? currentIncompleteRecord}) async {
    try {
      // For global stats, carry forward the previous day's value
      if (previousRecord == null) {
        currentValue = defaultValue;
        return currentValue;
      }
      
      final int previousValue = (previousRecord[name] as int?) ?? defaultValue;
      
      currentValue = previousValue;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to calculate carry-forward for total_eligible_questions: $e');
      rethrow;
    }
  }
}