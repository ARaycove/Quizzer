import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';


/// The UserQuestionManager encapsulates all functionality related to the user's relationship with the individual question records
/// There is a distinction between a question answer pair, and how an individual user relates to that pair
class UserQuestionManager {
  static final UserQuestionManager _instance = UserQuestionManager._internal();
  factory UserQuestionManager() => _instance;
  UserQuestionManager._internal();

  // ----- Get Questions based on conditions -----
  Future<List<Map<String, dynamic>>> getAccuracyProbabilityOfQuestions({required Set<String> questionIds}) async {
      final List<String> questionIdList = questionIds.toList();

      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db == null) throw Exception('Failed to acquire database access');
      
      final placeholders = List.filled(questionIdList.length, '?').join(',');
      List<dynamic> whereArgs = [SessionManager().userId, ...questionIdList];
      String sql = '''
        SELECT user_question_answer_pairs.question_id, user_question_answer_pairs.accuracy_probability
        FROM user_question_answer_pairs
        INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
        WHERE user_question_answer_pairs.user_uuid = ?
          AND user_question_answer_pairs.question_id IN ($placeholders)
          AND user_question_answer_pairs.flagged = 0
      ''';
      
      final queryResults = await db.rawQuery(sql, whereArgs);
      getDatabaseMonitor().releaseDatabaseAccess();
      // Convert to mutable list before returning
      final List<Map<String, dynamic>> results = List.from(queryResults);
      return results;
  }

  Future<List<Map<String, dynamic>>> getCirculatingQuestionsWithNeighbors() async {
    // Request database access for first query
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) throw Exception('Failed to acquire database access');
    
    // Query all circulating questions with their k_nearest_neighbors
    const circulatingQuery = '''
      SELECT 
        user_question_answer_pairs.question_id,
        question_answer_pairs.k_nearest_neighbors
      FROM user_question_answer_pairs
      INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
      WHERE user_question_answer_pairs.user_uuid = ?
        AND user_question_answer_pairs.in_circulation = 1
    ''';
    
    final circulatingResults = await queryAndDecodeDatabase(
      'user_question_answer_pairs',
      db,
      customQuery: circulatingQuery,
      whereArgs: [SessionManager().userId],
    );
    
    // Release database access immediately after query completes
    getDatabaseMonitor().releaseDatabaseAccess();

    return circulatingResults;
  }

  Future<List<Map<String, dynamic>>> getNonCirculatingQuestionsWithNeighbors() async {
    // Request database access for second query
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) throw Exception('Failed to acquire database access');
    
    // Query all non-circulating questions with their k_nearest_neighbors
    const nonCirculatingQuery = '''
      SELECT 
        user_question_answer_pairs.question_id,
        question_answer_pairs.k_nearest_neighbors
      FROM user_question_answer_pairs
      INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
      WHERE user_question_answer_pairs.user_uuid = ?
        AND user_question_answer_pairs.in_circulation = 0
    ''';
    
    final nonCirculatingResults = await queryAndDecodeDatabase(
      'user_question_answer_pairs',
      db,
      customQuery: nonCirculatingQuery,
      whereArgs: [SessionManager().userId],
    );
    
    // Release database access immediately after query completes
    getDatabaseMonitor().releaseDatabaseAccess();

    return nonCirculatingResults;
  }

  /// Gets questions in circulation with for a specific user.
  /// Returns questions that are in circulation (in_circulation = 1).
  /// Automatically excludes orphaned records (user records that reference non-existent questions).
  Future<List<Map<String, dynamic>>> getActiveQuestionsInCirculation() async {
    try {
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db == null) {
        throw Exception('Failed to acquire database access');
      }
      QuizzerLogger.logMessage('Fetching active questions in circulation for user: ${SessionManager().userId}...');
      // Build the query with proper joins and conditions
      String sql = '''
        SELECT user_question_answer_pairs.*
        FROM user_question_answer_pairs
        INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
        WHERE user_question_answer_pairs.user_uuid = ?
          AND user_question_answer_pairs.in_circulation = 1
          AND user_question_answer_pairs.flagged = 0
        ORDER BY user_question_answer_pairs.next_revision_due ASC
      ''';

      List<dynamic> whereArgs = [SessionManager().userId];
      
      // Use the proper table_helper system for encoding/decoding
      final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
        'user_question_answer_pairs', // Use the main table name for the helper
        db,
        customQuery: sql,
        whereArgs: whereArgs,
      );
      
      QuizzerLogger.logSuccess('Found ${results.length} active questions in circulation for user: ${SessionManager().userId}.');
      return results;
    } catch (e) {
      QuizzerLogger.logError('Error getting active questions in circulation - $e');
      rethrow;
    } finally {
      getDatabaseMonitor().releaseDatabaseAccess();
    }
  }

  /// Fetches all eligible user question answer pairs for a specific user.
  /// This function defines what is an eligible question
  Future<List<Map<String, dynamic>>> getEligibleUserQuestionAnswerPairs() async {
    try {
      // Now we can get DB Access and process the query
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db == null) {
        throw Exception('Failed to acquire database access');
      }
      QuizzerLogger.logMessage('Fetching eligible user question answer pairs for user: ${SessionManager().userId}...');
      // Eligible question criteria:
      // 1. The question must be in circulation -> in_circulation == 1 (see CirculationWorker for information on what makes a question in_circulation == 1)
      // 2. The question must not be flagged -> flagged = 0
      
      // Build the query with proper joins and conditions - only select needed fields
      String sql = '''
        SELECT 
          user_question_answer_pairs.user_uuid,
          user_question_answer_pairs.question_id,
          user_question_answer_pairs.revision_streak,
          user_question_answer_pairs.last_revised,
          user_question_answer_pairs.average_times_shown_per_day,
          user_question_answer_pairs.accuracy_probability,
          user_question_answer_pairs.in_circulation,
          user_question_answer_pairs.total_attempts,
          question_answer_pairs.question_elements,
          question_answer_pairs.answer_elements,
          question_answer_pairs.question_type,
          question_answer_pairs.options,
          question_answer_pairs.correct_option_index,
          question_answer_pairs.correct_order,
          question_answer_pairs.index_options_that_apply,
          question_answer_pairs.answers_to_blanks
        FROM user_question_answer_pairs
        INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
        WHERE user_question_answer_pairs.user_uuid = ?
          AND user_question_answer_pairs.in_circulation = 1
          AND user_question_answer_pairs.flagged = 0
          AND user_question_answer_pairs.accuracy_probability IS NOT NULL
      ''';
      
      List<dynamic> whereArgs = [SessionManager().userId];
      
      final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
        'user_question_answer_pairs',
        db,
        customQuery: sql,
        whereArgs: whereArgs,
      );
      QuizzerLogger.logSuccess('Fetched ${results.length} eligible records for user: ${SessionManager().userId} (fields pre-filtered in SQL query).');
      return results;
    } catch (e) {
      QuizzerLogger.logError('Error getting eligible user question answer pairs - $e');
      rethrow;
    } finally {
      getDatabaseMonitor().releaseDatabaseAccess();
    }
  }

  // ----- Update Question Records -----
  /// Updates the passed list of questionId records to have an in_circulation == 1 value,
  /// To update only one question record pass in a list with just the one id ['questionId']
  Future<void> setQuestionsAddToCirculation({required List<String> questionIds}) async {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) throw Exception('Failed to acquire database access');
    final placeholders = List.filled(questionIds.length, '?').join(',');
    final List<dynamic> whereArgs = [SessionManager().userId, ...questionIds];
    final String sql =
      'UPDATE user_question_answer_pairs SET in_circulation = 1 WHERE user_uuid = ? AND question_id IN ($placeholders)';
    await db.rawUpdate(sql, whereArgs);
    getDatabaseMonitor().releaseDatabaseAccess();
  }
  
  Future<void> setQuestionsRemoveFromCirculation({required List<String> questionIds,}) async {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) throw Exception('Failed to acquire database access');
    final placeholders = List.filled(questionIds.length, '?').join(',');
    final List<dynamic> whereArgs = [SessionManager().userId, ...questionIds];
    final String sql =
      'UPDATE user_question_answer_pairs SET in_circulation = 0 WHERE user_uuid = ? AND question_id IN ($placeholders)';
    await db.rawUpdate(sql, whereArgs);
    getDatabaseMonitor().releaseDatabaseAccess();
  }
  // ----- Get Count Status Calls -----
  Future<int> getCountOfLowProbabilityCirculatingQuestions(double idealThreshold) async {
    // Query to count eligible circulating questions
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) throw Exception('Failed to acquire database access');
    
    List<dynamic> whereArgs = [SessionManager().userId, idealThreshold];

    // Get a count of questions that are actively circulating and below the idealThreshold (calculated in the ML pipeline)
    const String sql = '''
      SELECT COUNT(*) as count
      FROM user_question_answer_pairs
      INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
      WHERE user_question_answer_pairs.user_uuid = ?
        AND user_question_answer_pairs.in_circulation = 1
        AND user_question_answer_pairs.flagged = 0
        AND user_question_answer_pairs.accuracy_probability < ?
      ''';
    
    final result = await db.rawQuery(sql, whereArgs);
    getDatabaseMonitor().releaseDatabaseAccess();
    // The result of COUNT(*) is a List containing a single map: [{'count': N}].
    // We safely extract the integer count, defaulting to 0 if the list is empty or the key is missing.
    final count = result.isNotEmpty 
        ? (result.first['count'] as int?) ?? 0 
        : 0;
        
    return count;
}


}