import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common/sqlite_api.dart';

class TodayTotalAttempts extends StatField{
  static final TodayTotalAttempts _instance = TodayTotalAttempts._internal();
  factory TodayTotalAttempts() => _instance;
  TodayTotalAttempts._internal();

  @override
  String get name => "today_total_attempts";

  @override
  String get type => "INTEGER";

  @override
  int get defaultValue => 0;

  int _cachedValue = 0;
  String _currentDate = '';
  
  @override
  int get currentValue => _cachedValue;

  set currentValue(int value) {
    _cachedValue = value;
  }

  @override
  String get description => "Total number of attempts made today (all question types).";

  @override
  bool get isIncremental => true;

  @override
  Future<int> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType}) async {
    try {
      final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      
      // Check if date has changed - if so, reset the counter
      if (_currentDate != today) {
        _cachedValue = 0;
        _currentDate = today;
      }
      
      // If we have a new answer (regardless of type or correctness), increment
      if (isCorrect != null) {
        _cachedValue += 1;
      }
      
      return _cachedValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to recalculate today_total_attempts: $e');
      rethrow;
    }
  }

  @override
  Future<int> calculateCarryForwardValue({Transaction? txn, Map<String, dynamic>? previousRecord, Map<String, dynamic>? currentIncompleteRecord}) async {
    try {
      // Always reset to 0 for new/missing days
      currentValue = defaultValue;
      // Also reset the date tracking
      if (currentIncompleteRecord != null && currentIncompleteRecord['record_date'] != null) {
        _currentDate = currentIncompleteRecord['record_date'] as String;
      }
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to calculate carry-forward for today_total_attempts: $e');
      rethrow;
    }
  }
}