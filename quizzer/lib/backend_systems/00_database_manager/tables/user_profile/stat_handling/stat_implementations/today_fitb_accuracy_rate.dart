import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_fitb_correct_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_fitb_total_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common/sqlite_api.dart';

class TodayFitbAccuracyRate extends StatField{
  static final TodayFitbAccuracyRate _instance = TodayFitbAccuracyRate._internal();
  factory TodayFitbAccuracyRate() => _instance;
  TodayFitbAccuracyRate._internal();

  @override
  String get name => "today_fitb_accuracy_rate";

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
  String get description => "Accuracy rate for today's Fill-in-the-blank attempts. Null if no FITB attempts today.";

  @override
  bool get isIncremental => false;

  @override
  Future<double?> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType}) async {
    try {
      // Get today's FITB stats from their respective singletons
      final int todayFitbCorrect = TodayFitbCorrectAttempts().currentValue;
      final int todayFitbTotal = TodayFitbTotalAttempts().currentValue;
      
      // Calculate accuracy: today_fitb_correct / today_fitb_total
      double? accuracy;
      if (todayFitbTotal > 0) {
        accuracy = todayFitbCorrect / todayFitbTotal;
      }
      
      currentValue = accuracy;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to recalculate today_fitb_accuracy_rate: $e');
      rethrow;
    }
  }

  @override
  Future<double?> calculateCarryForwardValue({Transaction? txn, Map<String, dynamic>? previousRecord, Map<String, dynamic>? currentIncompleteRecord}) async {
    try {
      // For missing days, set to null because no FITB attempts were made
      currentValue = null;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to calculate carry-forward for today_fitb_accuracy_rate: $e');
      rethrow;
    }
  }
}