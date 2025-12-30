import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart' as table_helper;
import 'package:sqflite_common/sqlite_api.dart';

class RevisionStreakSum extends StatField{
  static final RevisionStreakSum _instance = RevisionStreakSum._internal();
  factory RevisionStreakSum() => _instance;
  RevisionStreakSum._internal();

  @override
  String get name => "revision_streak_sum";

  @override
  String get type => "TEXT";

  @override
  String get defaultValue => "[]";

  String _cachedValue = "[]";
  @override
  String get currentValue => _cachedValue;

  set currentValue(String value) {
    _cachedValue = value;
  }

  @override
  String get description => "Distribution of revision streaks across all questions in circulation.";

  @override
  bool get isIncremental => false;

  @override
  Future<String> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType}) async {
    try {
      // Query to get revision streak distribution
      const revisionStreakQuery = '''
        SELECT 
          revision_streak,
          COUNT(*) as count
        FROM user_question_answer_pairs
        WHERE user_uuid = ? AND in_circulation = 1 AND flagged = 0
        GROUP BY revision_streak
      ''';
      
      final revisionStreakResults = await txn!.rawQuery(revisionStreakQuery, [SessionManager().userId]);
      
      // Build a list of maps for the distribution
      final List<Map<String, dynamic>> streakList = [];
      for (final row in revisionStreakResults) {
        streakList.add({
          'revision_streak': row['revision_streak'] ?? 0,
          'count': row['count'] ?? 0,
        });
      }
      
      // Encode the list as a JSON string using the table_helper method
      final String encodedValue = table_helper.encodeValueForDB(streakList) as String;
      
      currentValue = encodedValue;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to recalculate revision_streak_sum: $e');
      rethrow;
    }
  }

  @override
  Future<String> calculateCarryForwardValue({
    Transaction? txn, 
    Map<String, dynamic>? previousRecord, 
    Map<String, dynamic>? currentIncompleteRecord
  }) async {
    try {
      if (previousRecord == null) {
        currentValue = defaultValue;
        return currentValue;
      }
      
      dynamic previousValue = previousRecord[name];
      
      if (previousValue == null) {
        currentValue = defaultValue;
      } else if (previousValue is String) {
        // It's already a JSON string
        currentValue = previousValue;
      } else if (previousValue is List) {
        // It's been decoded to a List, need to re-encode it
        currentValue = table_helper.encodeValueForDB(previousValue) as String;
      } else {
        // Unexpected type, fall back to default
        QuizzerLogger.logWarning('Unexpected type for revision_streak_sum in previousRecord: ${previousValue.runtimeType}');
        currentValue = defaultValue;
      }
      
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to calculate carry-forward for revision_streak_sum: $e');
      rethrow;
    }
  }
}