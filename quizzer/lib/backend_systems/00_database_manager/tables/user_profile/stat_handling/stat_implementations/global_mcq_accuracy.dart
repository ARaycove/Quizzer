import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_mcq_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_mcq_correct_attempts.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common/sqlite_api.dart';

class GlobalMcqAccuracy extends StatField{
  static final GlobalMcqAccuracy _instance = GlobalMcqAccuracy._internal();
  factory GlobalMcqAccuracy() => _instance;
  GlobalMcqAccuracy._internal();

  @override
  String get name => "global_mcq_accuracy";

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
  String get description => "Global accuracy rate for Multiple Choice questions (correct/attempts).";

  @override
  bool get isIncremental => false;

  @override
  Future<double> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType}) async {
    try {
      // Get the required stats directly from their singletons
      final int mcqCorrect = TotalMcqCorrectAttempts().currentValue;
      final int mcqAttempts = TotalMcqAttempts().currentValue;
      
      // Calculate accuracy: mcq_correct / mcq_attempts
      double accuracy = defaultValue;
      if (mcqAttempts > 0) {
        accuracy = mcqCorrect / mcqAttempts;
      }
      
      currentValue = accuracy;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to recalculate global_mcq_accuracy: $e');
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
      QuizzerLogger.logError('Failed to calculate carry-forward for global_mcq_accuracy: $e');
      rethrow;
    }
  }
}