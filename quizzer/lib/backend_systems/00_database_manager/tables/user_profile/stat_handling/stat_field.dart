import 'package:sqflite/sqflite.dart';

/// Abstract base class for all statistics fields.
/// Each concrete implementation is a singleton that encapsulates
/// its own calculation logic, incremental behavior, and carry-forward logic.
abstract class StatField {
  /// Name of the database column for this stat (matches table column name)
  String get name;
  
  /// SQL data type for this stat (matches table column type)
  String get type;
  
  /// Whether this stat can be incremented with optional parameters
  bool get isIncremental;
  
  
  /// Current cached value of the stat
  dynamic get currentValue;

  /// Default value, what should this be given a new profile and no previous history
  dynamic get defaultValue;
  
  /// Description/tooltip for this stat
  String get description;

  /// Recalculates the stat value.
  /// [txn]: Optional database transaction for efficient querying
  /// [increment]: Optional increment value for incremental stats
  Future<dynamic> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType});

  /// Calculates the carry-forward value for missing days.
  /// [txn]: Optional database transaction for efficient querying
  /// [previousRecord]: Previous day's record for reference
  Future<dynamic> calculateCarryForwardValue({
    Transaction? txn,
    Map<String, dynamic>? previousRecord,
    Map<String, dynamic>? currentIncompleteRecord,
  });
}