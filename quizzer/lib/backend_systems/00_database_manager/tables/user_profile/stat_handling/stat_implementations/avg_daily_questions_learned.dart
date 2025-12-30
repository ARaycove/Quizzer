import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common/sqlite_api.dart';

class AvgDailyQuestionsLearned extends StatField{
  static final AvgDailyQuestionsLearned _instance = AvgDailyQuestionsLearned._internal();
  factory AvgDailyQuestionsLearned() => _instance;
  AvgDailyQuestionsLearned._internal();

  @override
  String get name => "avg_daily_questions_learned";

  @override
  String get type => "REAL";

  @override
  double get defaultValue => 0.0;

  double _cachedValue = 0.0;
  @override
  double get currentValue => _cachedValue;

  set currentValue(double value) {
    _cachedValue = value;
  }

  @override
  String get description => "Over the lifespan of this account, how many questions have been learned, to learn a question means to have answered the question at least once";

  @override
  bool get isIncremental => false;


  @override
  Future<double> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType}) async {
    try {
      // Query account creation date directly using transaction
      const accountQuery = '''
        SELECT account_creation_date 
        FROM user_profile 
        WHERE uuid = ? 
        LIMIT 1
      ''';
      
      final accountResults = await txn!.rawQuery(accountQuery, [SessionManager().userId]);
      
      if (accountResults.isEmpty || accountResults.first['account_creation_date'] == null) {
        throw Exception("At no point should account creation date be null");
      }
      
      final DateTime accountCreationDate = DateTime.parse(accountResults.first['account_creation_date'] as String);
      final DateTime today = DateTime.now().toUtc();
      
      // Calculate days since account creation (d)
      final int daysSinceCreation = today.difference(accountCreationDate).inDays + 1; // +1 to include today
      
      // Query for total learned questions (|S|)
      // In the case where a user answers a question correctly once, then answers incorrectly, streak is 0, and we deem they have not properly learned it
      const query = '''
        SELECT COUNT(*) as learned_count
        FROM user_question_answer_pairs
        WHERE user_uuid = ? AND revision_streak > 0
      ''';
      
      final results = await txn.rawQuery(query, [SessionManager().userId]);
      final int learnedCount = (results.first['learned_count'] as int?) ?? 0;
      
      // Calculate k = |S| / d
      final double avg = daysSinceCreation > 0 ? learnedCount / daysSinceCreation : 0.0;
      
      currentValue = avg;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to recalculate avg_daily_questions_learned: $e');
      rethrow;
    }
  }

  @override
  Future<double> calculateCarryForwardValue({
    Transaction? txn,
    Map<String, dynamic>? previousRecord,
    Map<String, dynamic>? currentIncompleteRecord,
  }) async {
    try {
      if (previousRecord == null) {
        currentValue = defaultValue;
        return currentValue;
      }
      
      // Get k from previous record
      final double k = (previousRecord[name] as double?) ?? defaultValue;
      
      // Get the current date we're filling in
      final currentDateStr = currentIncompleteRecord?['record_date'] as String?;
      if (currentDateStr == null) {
        currentValue = k;
        return currentValue;
      }
      
      final currentDate = DateTime.parse(currentDateStr);
      
      // Query account creation date directly using transaction
      const accountQuery = '''
        SELECT account_creation_date 
        FROM user_profile 
        WHERE uuid = ? 
        LIMIT 1
      ''';
      
      final accountResults = await txn!.rawQuery(accountQuery, [SessionManager().userId]);
      
      if (accountResults.isEmpty || accountResults.first['account_creation_date'] == null) {
        currentValue = k;
        return currentValue;
      }
      
      final DateTime accountCreationDate = DateTime.parse(accountResults.first['account_creation_date'] as String);
      
      // Calculate d_prev (days from account creation to previous day)
      final previousDateStr = previousRecord['record_date'] as String;
      final DateTime previousDate = DateTime.parse(previousDateStr);
      final int dPrev = previousDate.difference(accountCreationDate).inDays + 1;
      
      // Calculate d_curr (days from account creation to current day)
      final int dCurr = currentDate.difference(accountCreationDate).inDays + 1;
      
      // Derive |S_prev| from k and d_prev
      // Since k = |S| / d, then |S| = k * d
      final double sPrev = k * dPrev;
      
      // For carry-forward, we assume no new questions were learned on the missing day
      // So |S_curr| = |S_prev|
      final double sCurr = sPrev;
      
      // Calculate new k for current day: k_curr = |S_curr| / d_curr
      final double kCurr = dCurr > 0 ? sCurr / dCurr : 0.0;
      
      currentValue = kCurr;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to calculate carry-forward for avg_daily_questions_learned: $e');
      rethrow;
    }
  }
}