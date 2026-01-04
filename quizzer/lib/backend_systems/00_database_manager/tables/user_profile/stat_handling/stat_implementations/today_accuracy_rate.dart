import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_correct_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_total_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common/sqlite_api.dart';

class TodayAccuracyRate extends StatField{
  static final TodayAccuracyRate _instance = TodayAccuracyRate._internal();
  factory TodayAccuracyRate() => _instance;
  TodayAccuracyRate._internal();

  @override
  String get name => "today_accuracy_rate";

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
  String get description => "Accuracy rate for today's attempts (today_correct / today_total). Null if no attempts today.";

  @override
  bool get isIncremental => false;

  @override
  Future<double?> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType}) async {
    try {
      // Get today's stats from their respective singletons
      final int todayCorrect = TodayCorrectAttempts().currentValue;
      final int todayTotal = TodayTotalAttempts().currentValue;
      
      // Calculate accuracy: today_correct / today_total
      double? accuracy;
      if (todayTotal > 0) {
        accuracy = todayCorrect / todayTotal;
      }
      
      currentValue = accuracy;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to recalculate today_accuracy_rate: $e');
      rethrow;
    }
  }

  @override
  Future<double?> calculateCarryForwardValue({Transaction? txn, Map<String, dynamic>? previousRecord, Map<String, dynamic>? currentIncompleteRecord}) async {
    try {
      // For missing days, set to null because no attempts were made
      currentValue = null;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to calculate carry-forward for today_accuracy_rate: $e');
      rethrow;
    }
  }
}