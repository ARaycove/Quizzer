import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_so_correct_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_so_total_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common/sqlite_api.dart';

class TodaySoAccuracyRate extends StatField{
  static final TodaySoAccuracyRate _instance = TodaySoAccuracyRate._internal();
  factory TodaySoAccuracyRate() => _instance;
  TodaySoAccuracyRate._internal();

  @override
  String get name => "today_so_accuracy_rate";

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
  String get description => "Accuracy rate for today's Sort Order attempts. Null if no SO attempts today.";

  @override
  bool get isIncremental => false;

  @override
  Future<double?> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType}) async {
    try {
      // Get today's SO stats from their respective singletons
      final int todaySoCorrect = TodaySoCorrectAttempts().currentValue;
      final int todaySoTotal = TodaySoTotalAttempts().currentValue;
      
      // Calculate accuracy: today_so_correct / today_so_total
      double? accuracy;
      if (todaySoTotal > 0) {
        accuracy = todaySoCorrect / todaySoTotal;
      }
      
      currentValue = accuracy;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to recalculate today_so_accuracy_rate: $e');
      rethrow;
    }
  }

  @override
  Future<double?> calculateCarryForwardValue({Transaction? txn, Map<String, dynamic>? previousRecord, Map<String, dynamic>? currentIncompleteRecord}) async {
    try {
      // For missing days, set to null because no SO attempts were made
      currentValue = null;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to calculate carry-forward for today_so_accuracy_rate: $e');
      rethrow;
    }
  }
}