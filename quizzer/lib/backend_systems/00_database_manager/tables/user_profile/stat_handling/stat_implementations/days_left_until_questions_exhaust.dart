import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/avg_daily_questions_learned.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common/sqlite_api.dart';

class DaysLeftUntilQuestionsExhaust extends StatField {
  static final DaysLeftUntilQuestionsExhaust _instance = DaysLeftUntilQuestionsExhaust._internal();
  factory DaysLeftUntilQuestionsExhaust() => _instance;
  DaysLeftUntilQuestionsExhaust._internal();

  @override
  String get name => "days_left_until_questions_exhaust";

  @override
  String get type => "REAL";

  @override
  double get defaultValue => 0.0;

  double _cachedValue = 0.0;
  @override
  double get currentValue => _cachedValue;

  set currentValue(double value) {
    _cachedValue = value;
  }

  @override
  String get description => "Estimated days until all available questions are learned, based on current learning rate.";

  @override
  bool get isIncremental => false;

  @override
  Future<double> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType}) async {
    try {
      final double avgDailyQuestionsLearned = AvgDailyQuestionsLearned().currentValue;
      
      // Get total questions and learned questions
      const query = '''
        SELECT 
          COUNT(*) as total_questions,
          SUM(CASE WHEN revision_streak > 0 THEN 1 ELSE 0 END) as learned_questions
        FROM user_question_answer_pairs
        WHERE user_uuid = ?
      ''';
      
      final results = await txn!.rawQuery(query, [SessionManager().userId]);
      
      if (results.isEmpty) {
        currentValue = defaultValue;
        return currentValue;
      }
      
      final int totalQuestions = (results.first['total_questions'] as int?) ?? 0;
      final int learnedQuestions = (results.first['learned_questions'] as int?) ?? 0;
      final int unlearnedQuestions = totalQuestions - learnedQuestions;
      
      // Calculate days left: unlearned / average daily learned
      double daysLeft = defaultValue;
      if (avgDailyQuestionsLearned > 0 && unlearnedQuestions > 0) {
        daysLeft = unlearnedQuestions / avgDailyQuestionsLearned;
      }
      
      currentValue = daysLeft;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to recalculate days_left_until_questions_exhaust: $e');
      rethrow;
    }
  }

  @override
  Future<double> calculateCarryForwardValue({
    Transaction? txn, 
    Map<String, dynamic>? previousRecord, 
    Map<String, dynamic>? currentIncompleteRecord
  }) async {
    try {
      if (previousRecord == null) {
        currentValue = defaultValue;
        return currentValue;
      }
      
      // For carry-forward, use the previous day's value
      final double previousValue = (previousRecord[name] as double?) ?? defaultValue;
      
      currentValue = previousValue;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to calculate carry-forward for days_left_until_questions_exhaust: $e');
      rethrow;
    }
  }
}