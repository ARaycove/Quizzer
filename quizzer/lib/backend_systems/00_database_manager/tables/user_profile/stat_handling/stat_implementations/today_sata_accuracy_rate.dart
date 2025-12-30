import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_sata_correct_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_sata_total_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common/sqlite_api.dart';

class TodaySataAccuracyRate extends StatField{
  static final TodaySataAccuracyRate _instance = TodaySataAccuracyRate._internal();
  factory TodaySataAccuracyRate() => _instance;
  TodaySataAccuracyRate._internal();

  @override
  String get name => "today_sata_accuracy_rate";

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
  String get description => "Accuracy rate for today's Select All That Apply attempts. Null if no SATA attempts today.";

  @override
  bool get isIncremental => false;

  @override
  Future<double?> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType}) async {
    try {
      // Get today's SATA stats from their respective singletons
      final int todaySataCorrect = TodaySataCorrectAttempts().currentValue;
      final int todaySataTotal = TodaySataTotalAttempts().currentValue;
      
      // Calculate accuracy: today_sata_correct / today_sata_total
      double? accuracy;
      if (todaySataTotal > 0) {
        accuracy = todaySataCorrect / todaySataTotal;
      }
      
      currentValue = accuracy;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to recalculate today_sata_accuracy_rate: $e');
      rethrow;
    }
  }

  @override
  Future<double?> calculateCarryForwardValue({Transaction? txn, Map<String, dynamic>? previousRecord, Map<String, dynamic>? currentIncompleteRecord}) async {
    try {
      // For missing days, set to null because no SATA attempts were made
      currentValue = null;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to calculate carry-forward for today_sata_accuracy_rate: $e');
      rethrow;
    }
  }
}