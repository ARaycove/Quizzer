import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common/sqlite_api.dart';

class ConsecutiveCorrectStreak extends StatField{
  static final ConsecutiveCorrectStreak _instance = ConsecutiveCorrectStreak._internal();
  factory ConsecutiveCorrectStreak() => _instance;
  ConsecutiveCorrectStreak._internal();

  @override
  String get name => "consecutive_correct_streak";

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
  String get description => "Current streak of consecutively correct answers. Resets to 0 when an incorrect answer is given.";

  @override
  bool get isIncremental => false;

  @override
  Future<int> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType}) async {
    try {
      if (isCorrect == null) {
        // When recalculating without a new answer (e.g., during initialization or daily stat filling),
        // we fetch the current streak from the most recent daily stats record
        const query = '''
          SELECT consecutive_correct_streak 
          FROM user_daily_stats 
          WHERE user_id = ? 
          ORDER BY record_date DESC 
          LIMIT 1
        ''';
        
        final results = await txn!.rawQuery(query, [SessionManager().userId]);
        
        if (results.isNotEmpty && results.first['consecutive_correct_streak'] != null) {
          currentValue = (results.first['consecutive_correct_streak'] as int?) ?? defaultValue;
        } else {
          currentValue = defaultValue;
        }
        
        return currentValue;
      } else {
        // When a question is answered, update the streak based on correctness
        const query = '''
          SELECT consecutive_correct_streak 
          FROM user_daily_stats 
          WHERE user_id = ? 
          ORDER BY record_date DESC 
          LIMIT 1
        ''';
        
        final results = await txn!.rawQuery(query, [SessionManager().userId]);
        
        int currentStreak = defaultValue;
        if (results.isNotEmpty && results.first['consecutive_correct_streak'] != null) {
          currentStreak = (results.first['consecutive_correct_streak'] as int?) ?? defaultValue;
        }
        
        // Update streak based on answer correctness
        if (isCorrect) {
          currentStreak += 1;
        } else {
          currentStreak = 0; // Reset to 0 on incorrect answer
        }
        
        currentValue = currentStreak;
        return currentValue;
      }
    } catch (e) {
      QuizzerLogger.logError('Failed to recalculate consecutive_correct_streak: $e');
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
      
      // For carry-forward, we use the previous day's streak value
      // This assumes no answers were given on the missing day
      final int previousValue = (previousRecord[name] as int?) ?? defaultValue;
      
      currentValue = previousValue;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to calculate carry-forward for consecutive_correct_streak: $e');
      rethrow;
    }
  }
}