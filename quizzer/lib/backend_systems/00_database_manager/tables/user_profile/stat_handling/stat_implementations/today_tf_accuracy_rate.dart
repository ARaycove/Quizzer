import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_tf_correct_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_tf_total_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common/sqlite_api.dart';

class TodayTfAccuracyRate extends StatField{
  static final TodayTfAccuracyRate _instance = TodayTfAccuracyRate._internal();
  factory TodayTfAccuracyRate() => _instance;
  TodayTfAccuracyRate._internal();

  @override
  String get name => "today_tf_accuracy_rate";

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
  String get description => "Accuracy rate for today's True/False attempts. Null if no TF attempts today.";

  @override
  bool get isIncremental => false;

  @override
  Future<double?> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType}) async {
    try {
      // Get today's TF stats from their respective singletons
      final int todayTfCorrect = TodayTfCorrectAttempts().currentValue;
      final int todayTfTotal = TodayTfTotalAttempts().currentValue;
      
      // Calculate accuracy: today_tf_correct / today_tf_total
      double? accuracy;
      if (todayTfTotal > 0) {
        accuracy = todayTfCorrect / todayTfTotal;
      }
      
      currentValue = accuracy;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to recalculate today_tf_accuracy_rate: $e');
      rethrow;
    }
  }

  @override
  Future<double?> calculateCarryForwardValue({Transaction? txn, Map<String, dynamic>? previousRecord, Map<String, dynamic>? currentIncompleteRecord}) async {
    try {
      // For missing days, set to null because no TF attempts were made
      currentValue = null;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to calculate carry-forward for today_tf_accuracy_rate: $e');
      rethrow;
    }
  }
}