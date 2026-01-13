import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common/sqlite_api.dart';

class TotalTfCorrectAttempts extends StatField{
  static final TotalTfCorrectAttempts _instance = TotalTfCorrectAttempts._internal();
  factory TotalTfCorrectAttempts() => _instance;
  TotalTfCorrectAttempts._internal();

  @override
  String get name => "total_tf_correct_attempts";

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
  String get description => "Total number of correct True/False attempts made across all time.";

  @override
  bool get isIncremental => true;

  @override
  Future<int> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType}) async {
    try {
      // If we have a new correct True/False answer, increment the total
      if (isCorrect != null && isCorrect && questionType == 'true_false') {
        _cachedValue += 1;
      }
      // If isCorrect is null (just recalculating), keep current value
      return _cachedValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to recalculate total_tf_correct_attempts: $e');
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
      QuizzerLogger.logError('Failed to calculate carry-forward for total_tf_correct_attempts: $e');
      rethrow;
    }
  }
}