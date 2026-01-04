import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_mcq_correct_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_mcq_total_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common/sqlite_api.dart';

class TodayMcqAccuracyRate extends StatField{
  static final TodayMcqAccuracyRate _instance = TodayMcqAccuracyRate._internal();
  factory TodayMcqAccuracyRate() => _instance;
  TodayMcqAccuracyRate._internal();

  @override
  String get name => "today_mcq_accuracy_rate";

  @override
  String get type => "REAL";

  @override
  double? get defaultValue => null;

  double? _cachedValue;
  @override
  double? get currentValue => _cachedValue;

  set currentValue(double? value) {
    _cachedValue = value;
  }

  @override
  String get description => "Accuracy rate for today's Multiple Choice attempts. Null if no MCQ attempts today.";

  @override
  bool get isIncremental => false;

  @override
  Future<double?> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType}) async {
    try {
      // Get today's MCQ stats from their respective singletons
      final int todayMcqCorrect = TodayMcqCorrectAttempts().currentValue;
      final int todayMcqTotal = TodayMcqTotalAttempts().currentValue;
      
      // Calculate accuracy: today_mcq_correct / today_mcq_total
      double? accuracy;
      if (todayMcqTotal > 0) {
        accuracy = todayMcqCorrect / todayMcqTotal;
      }
      
      currentValue = accuracy;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to recalculate today_mcq_accuracy_rate: $e');
      rethrow;
    }
  }

  @override
  Future<double?> calculateCarryForwardValue({Transaction? txn, Map<String, dynamic>? previousRecord, Map<String, dynamic>? currentIncompleteRecord}) async {
    try {
      // For missing days, set to null because no MCQ attempts were made
      currentValue = null;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to calculate carry-forward for today_mcq_accuracy_rate: $e');
      rethrow;
    }
  }
}