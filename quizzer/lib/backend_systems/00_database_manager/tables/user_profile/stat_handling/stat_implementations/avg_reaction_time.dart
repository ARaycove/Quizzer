import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common/sqlite_api.dart';

class AvgReactionTime extends StatField{
  static final AvgReactionTime _instance = AvgReactionTime._internal();
  factory AvgReactionTime() => _instance;
  AvgReactionTime._internal();

  @override
  String get name => "avg_reaction_time";

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
  String get description => "The global average reaction time across all attempts for the user, in seconds.";

  @override
  bool get isIncremental => false;

  @override
  Future<double> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType}) async {
    try {
      // Query to get the weighted average of reaction times across all questions
      // We calculate: Σ(avg_reaction_time * total_attempts) / Σ(total_attempts)
      const query = '''
        SELECT 
          SUM(uqap.avg_reaction_time * uqap.total_attempts) / SUM(uqap.total_attempts) as global_avg_reaction_time
        FROM user_question_answer_pairs uqap
        WHERE uqap.user_uuid = ? AND uqap.total_attempts > 0
      ''';
      
      final results = await txn!.rawQuery(query, [SessionManager().userId]);
      
      double avgReactionTime = defaultValue;
      if (results.isNotEmpty && results.first['global_avg_reaction_time'] != null) {
        avgReactionTime = (results.first['global_avg_reaction_time'] as num?)?.toDouble() ?? defaultValue;
      }
      
      currentValue = avgReactionTime;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to recalculate avg_reaction_time: $e');
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
      
      // For carry-forward, we simply use the previous day's value
      // This assumes reaction time doesn't change unless questions are answered
      final double previousValue = (previousRecord[name] as double?) ?? defaultValue;
      
      currentValue = previousValue;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to calculate carry-forward for avg_reaction_time: $e');
      rethrow;
    }
  }
}