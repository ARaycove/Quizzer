import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_sata_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_sata_correct_attempts.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common/sqlite_api.dart';

class GlobalSataAccuracy extends StatField{
  static final GlobalSataAccuracy _instance = GlobalSataAccuracy._internal();
  factory GlobalSataAccuracy() => _instance;
  GlobalSataAccuracy._internal();

  @override
  String get name => "global_sata_accuracy";

  @override
  String get type => "REAL";

  @override
  double get defaultValue => 1.0;

  double _cachedValue = 1.0;
  @override
  double get currentValue => _cachedValue;

  set currentValue(double value) {
    _cachedValue = value;
  }

  @override
  String get description => "Global accuracy rate for Select All That Apply questions (correct/attempts).";

  @override
  bool get isIncremental => false;

  @override
  Future<double> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType}) async {
    try {
      // Get the required stats directly from their singletons
      final int sataCorrect = TotalSataCorrectAttempts().currentValue;
      final int sataAttempts = TotalSataAttempts().currentValue;
      
      // Calculate accuracy: sata_correct / sata_attempts
      double accuracy = defaultValue;
      if (sataAttempts > 0) {
        accuracy = sataCorrect / sataAttempts;
      }
      
      currentValue = accuracy;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to recalculate global_sata_accuracy: $e');
      rethrow;
    }
  }

  @override
  Future<double> calculateCarryForwardValue({
    Transaction? txn, 
    Map<String, dynamic>? previousRecord, 
    Map<String, dynamic>? currentIncompleteRecord
  }) async {
    try {
      if (previousRecord == null) {
        currentValue = defaultValue;
        return currentValue;
      }
      
      // For carry-forward, use the previous day's value
      final double previousValue = (previousRecord[name] as double?) ?? defaultValue;
      
      currentValue = previousValue;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to calculate carry-forward for global_sata_accuracy: $e');
      rethrow;
    }
  }
}