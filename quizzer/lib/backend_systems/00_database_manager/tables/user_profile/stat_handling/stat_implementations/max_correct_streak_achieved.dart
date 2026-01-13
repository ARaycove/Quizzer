import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/consecutive_correct_streak.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common/sqlite_api.dart';

class MaxCorrectStreakAchieved extends StatField{
  static final MaxCorrectStreakAchieved _instance = MaxCorrectStreakAchieved._internal();
  factory MaxCorrectStreakAchieved() => _instance;
  MaxCorrectStreakAchieved._internal();

  @override
  String get name => "max_correct_streak_achieved";

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
  String get description => "Historical maximum consecutive correct streak achieved.";

  @override
  bool get isIncremental => false;

  @override
  Future<int> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType}) async {
    try {
      // Get the current consecutive correct streak
      final int currentStreak = ConsecutiveCorrectStreak().currentValue;
      
      // Get the previous max from the most recent daily stats record
      const query = '''
        SELECT max_correct_streak_achieved 
        FROM user_daily_stats 
        WHERE user_id = ? 
        ORDER BY record_date DESC 
        LIMIT 1
      ''';
      
      final results = await txn!.rawQuery(query, [SessionManager().userId]);
      
      int previousMax = defaultValue;
      if (results.isNotEmpty && results.first['max_correct_streak_achieved'] != null) {
        previousMax = (results.first['max_correct_streak_achieved'] as int?) ?? defaultValue;
      }
      
      // The new max is the maximum between previous max and current streak
      final int newMax = (currentStreak > previousMax) ? currentStreak : previousMax;
      
      currentValue = newMax;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to recalculate max_correct_streak_achieved: $e');
      rethrow;
    }
  }

  @override
  Future<int> calculateCarryForwardValue({
    Transaction? txn, 
    Map<String, dynamic>? previousRecord, 
    Map<String, dynamic>? currentIncompleteRecord
  }) async {
    try {
      if (previousRecord == null) {
        currentValue = defaultValue;
        return currentValue;
      }
      
      // For carry-forward, use the previous day's max (which is the historical maximum)
      final int previousValue = (previousRecord[name] as int?) ?? defaultValue;
      
      currentValue = previousValue;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to calculate carry-forward for max_correct_streak_achieved: $e');
      rethrow;
    }
  }
}