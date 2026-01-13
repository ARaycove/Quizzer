import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common/sqlite_api.dart';

class TotalInCircQuestions extends StatField{
  static final TotalInCircQuestions _instance = TotalInCircQuestions._internal();
  factory TotalInCircQuestions() => _instance;
  TotalInCircQuestions._internal();

  @override
  String get name => "total_in_circ_questions";

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
  String get description => "Total number of questions currently in circulation (excluding flagged).";

  @override
  bool get isIncremental => false;

  @override
  Future<int> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType}) async {
    try {
      // Count questions where in_circulation = 1 AND flagged = 0
      const query = '''
        SELECT COUNT(*) as in_circ_count
        FROM user_question_answer_pairs
        WHERE user_uuid = ? AND in_circulation = 1 AND flagged = 0
      ''';
      
      final results = await txn!.rawQuery(query, [SessionManager().userId]);
      
      final int inCircCount = results.isNotEmpty ? (results.first['in_circ_count'] as int?) ?? 0 : 0;
      
      currentValue = inCircCount;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to recalculate total_in_circ_questions: $e');
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
      QuizzerLogger.logError('Failed to calculate carry-forward for total_in_circ_questions: $e');
      rethrow;
    }
  }
}