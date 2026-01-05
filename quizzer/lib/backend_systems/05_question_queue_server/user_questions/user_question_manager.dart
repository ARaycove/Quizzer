import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
import 'package:sqflite_common/sqlite_api.dart';


/// The UserQuestionManager encapsulates all functionality related to the user's relationship with the individual question records
/// There is a distinction between a question answer pair, and how an individual user relates to that pair
class UserQuestionManager {
  static final UserQuestionManager _instance = UserQuestionManager._internal();
  factory UserQuestionManager() => _instance;
  UserQuestionManager._internal();

  final Set<String> _existingUserQuestionRecords = {};
  bool _isCacheInitialized = false;

  Future<List<Map<String, dynamic>>> getAccuracyProbabilityOfQuestions({required Set<String> questionIds}) async {
    if (SessionManager().userId == null) throw Exception('User must be logged in');

    // Ensure records exist before querying
    for (final questionId in questionIds) {await ensureUserQuestionRecordExists(questionId);}

    if (questionIds.isEmpty) return [];

    return UserQuestionAnswerPairsTable().getRecord('''
      SELECT user_question_answer_pairs.question_id, user_question_answer_pairs.accuracy_probability
      FROM user_question_answer_pairs
      INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
      WHERE user_question_answer_pairs.user_uuid = '${SessionManager().userId}'
        AND user_question_answer_pairs.question_id IN (${questionIds.map((id) => "'$id'").join(',')})
        AND user_question_answer_pairs.flagged = 0
    ''');
  }

  Future<List<Map<String, dynamic>>> getCirculatingQuestionsWithNeighbors() async {
    if (SessionManager().userId == null) throw Exception('User must be logged in');

    return UserQuestionAnswerPairsTable().getRecord('''
      SELECT 
        user_question_answer_pairs.question_id,
        question_answer_pairs.k_nearest_neighbors
      FROM user_question_answer_pairs
      INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
      WHERE user_question_answer_pairs.user_uuid = '${SessionManager().userId}'
        AND user_question_answer_pairs.in_circulation = 1
        AND question_vector IS NOT NULL
    ''');
  }

  Future<List<Map<String, dynamic>>> getNonCirculatingQuestionsWithNeighbors() async {
    if (SessionManager().userId == null) throw Exception('User must be logged in');

    return UserQuestionAnswerPairsTable().getRecord('''
      SELECT 
        user_question_answer_pairs.question_id,
        question_answer_pairs.k_nearest_neighbors
      FROM user_question_answer_pairs
      INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
      WHERE user_question_answer_pairs.user_uuid = '${SessionManager().userId}'
        AND user_question_answer_pairs.in_circulation = 0
    ''');
  }

  Future<List<Map<String, dynamic>>> getActiveQuestionsInCirculation() async {
    if (SessionManager().userId == null) throw Exception('User must be logged in');

    QuizzerLogger.logMessage('Fetching active questions in circulation for user: ${SessionManager().userId}...');
    
    final results = await UserQuestionAnswerPairsTable().getRecord('''
      SELECT user_question_answer_pairs.*
      FROM user_question_answer_pairs
      INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
      WHERE user_question_answer_pairs.user_uuid = '${SessionManager().userId}'
        AND user_question_answer_pairs.in_circulation = 1
        AND user_question_answer_pairs.flagged = 0
    ''');

    QuizzerLogger.logSuccess('Found ${results.length} active questions in circulation for user: ${SessionManager().userId}.');
    return results;
  }

  Future<dynamic> getEligibleUserQuestionAnswerPairs({
    Transaction? txn, 
    bool countOnly = false,
    bool includeQuestionPairs = true
  }) async {
    if (SessionManager().userId == null) throw Exception('User must be logged in');

    QuizzerLogger.logMessage('${countOnly ? 'Counting' : 'Fetching'} eligible user question answer pairs for user: ${SessionManager().userId}...');

    final String userId = SessionManager().userId!;
    final List<String> whereConditions = [
      "user_question_answer_pairs.user_uuid = '$userId'",
      "user_question_answer_pairs.in_circulation = 1",
      "user_question_answer_pairs.flagged = 0"
    ];

    String query;
    if (countOnly) {
      query = '''
        SELECT COUNT(*) as eligible_count
        FROM user_question_answer_pairs
        ${includeQuestionPairs ? 'INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id' : ''}
        WHERE ${whereConditions.join(' AND ')}
      ''';
    } else {
      query = '''
        SELECT 
          user_question_answer_pairs.user_uuid,
          user_question_answer_pairs.question_id,
          user_question_answer_pairs.revision_streak,
          user_question_answer_pairs.last_revised,
          user_question_answer_pairs.average_times_shown_per_day,
          user_question_answer_pairs.accuracy_probability,
          user_question_answer_pairs.in_circulation,
          user_question_answer_pairs.total_attempts,
          ${includeQuestionPairs ? '''
            question_answer_pairs.question_elements,
            question_answer_pairs.answer_elements,
            question_answer_pairs.question_type,
            question_answer_pairs.options,
            question_answer_pairs.correct_option_index,
            question_answer_pairs.correct_order,
            question_answer_pairs.index_options_that_apply,
            question_answer_pairs.answers_to_blanks
          ''' : ''}
        FROM user_question_answer_pairs
        ${includeQuestionPairs ? 'INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id' : ''}
        WHERE ${whereConditions.join(' AND ')}
      ''';
    }

    try {
      List<Map<String, dynamic>> results;
      if (txn != null) {
        // Use rawQuery with transaction
        if (countOnly) {
          // Remove the quotes around userId parameter for rawQuery
          final rawQuery = query.replaceFirst("'$userId'", '?');
          results = await txn.rawQuery(rawQuery, [userId]);
        } else {
          results = await txn.rawQuery(query, []);
        }
      } else {
        // Use the table's getRecord method
        results = await UserQuestionAnswerPairsTable().getRecord(query);
      }

      if (countOnly) {
        final int count = results.isNotEmpty ? (results.first['eligible_count'] as int?) ?? 0 : 0;
        QuizzerLogger.logSuccess('Counted $count eligible records for user: $userId');
        return count;
      } else {
        QuizzerLogger.logSuccess('Fetched ${results.length} eligible records for user: $userId');
        return results;
      }
    } catch (e) {
      QuizzerLogger.logError('Failed to ${countOnly ? 'count' : 'fetch'} eligible user question answer pairs: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUserQuestionAnswerPairById(String questionId) async {
    if (SessionManager().userId == null) throw Exception('User must be logged in');
    await ensureUserQuestionRecordExists(questionId);

    final results = await UserQuestionAnswerPairsTable().getRecord('''
      SELECT * FROM user_question_answer_pairs 
      WHERE user_uuid = '${SessionManager().userId}' 
      AND question_id = '$questionId'
    ''');

    if (results.isEmpty) {
      QuizzerLogger.logError('No user question answer pair found for userID: ${SessionManager().userId} and questionId: $questionId.');
      throw StateError('No record found for user ${SessionManager().userId}, question $questionId');
    } else if (results.length > 1) {
      QuizzerLogger.logError('Found multiple records for userID: ${SessionManager().userId} and questionId: $questionId. PK constraint violation?');
      throw StateError('Found multiple records for PK user ${SessionManager().userId}, question $questionId');
    }

    QuizzerLogger.logSuccess('Successfully fetched user_question_answer_pair for User: ${SessionManager().userId}, Q: $questionId');
    return results.first;
  }


  // ----- Update Question Records -----
  /// Updates the passed list of questionId records to have an in_circulation == 1 value,
  /// To update only one question record pass in a list with just the one id ['questionId']
  Future<void> setQuestionsAddToCirculation({required List<String> questionIds}) async {
    if (SessionManager().userId == null) throw Exception('User must be logged in');

    for (final questionId in questionIds) {
      await ensureUserQuestionRecordExists(questionId);
      await UserQuestionAnswerPairsTable().upsertRecord({
        'user_uuid': SessionManager().userId,
        'question_id': questionId,
        'in_circulation': 1,
      });
    }
  }
  
  Future<void> setQuestionsRemoveFromCirculation({required List<String> questionIds}) async {
    if (SessionManager().userId == null) throw Exception('User must be logged in');

    for (final questionId in questionIds) {
      await UserQuestionAnswerPairsTable().upsertRecord({
        'user_uuid': SessionManager().userId,
        'question_id': questionId,
        'in_circulation': 0,
      });
    }
  }
  
  // ----- Get Count Status Calls -----
  Future<int> getCountOfLowProbabilityCirculatingQuestions(double idealThreshold) async {
    if (SessionManager().userId == null) throw Exception('User must be logged in');

    final results = await UserQuestionAnswerPairsTable().getRecord('''
      SELECT COUNT(*) as count
      FROM user_question_answer_pairs
      INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
      WHERE user_question_answer_pairs.user_uuid = '${SessionManager().userId}'
        AND user_question_answer_pairs.in_circulation = 1
        AND user_question_answer_pairs.flagged = 0
        AND user_question_answer_pairs.accuracy_probability < $idealThreshold
    ''');

    return results.isNotEmpty ? (results.first['count'] as int?) ?? 0 : 0;
  }

  // ----- Update User Question Records -----
  /// Updates a user question answer pair with any combination of fields.
  /// Accepts a map of field names to values for maximum flexibility.
  /// Only updates fields that are provided in the updates map.
  Future<int> editUserQuestionAnswerPair({
    required String questionId,
    Map<String, dynamic>? updates
  }) async {
    if (SessionManager().userId == null) throw Exception('User must be logged in');

    QuizzerLogger.logMessage('Starting editUserQuestionAnswerPair for User: ${SessionManager().userId}, Q: $questionId');

    // Build the values map with primary keys
    Map<String, dynamic> values = {
      'user_uuid': SessionManager().userId,
      'question_id': questionId,
    };
    
    // Add updates if provided
    if (updates != null) {
      for (final entry in updates.entries) {
        // Handle boolean conversion for known boolean fields
        if ((entry.key == 'in_circulation' || entry.key == 'flagged') && entry.value is bool) {
          values[entry.key] = entry.value ? 1 : 0;
        } else {
          values[entry.key] = entry.value;
        }
      }
    }

    final result = await UserQuestionAnswerPairsTable().upsertRecord(values);

    if (result > 0) {
      QuizzerLogger.logSuccess('Edited user_question_answer_pair for User: ${SessionManager().userId}, Q: $questionId ($result row affected). Updated fields: ${updates?.keys.join(', ') ?? 'none'}');
    } else {
      QuizzerLogger.logError('Update operation for user_question_answer_pair (User: ${SessionManager().userId}, Q: $questionId) affected 0 rows. Record might not exist.');
      throw StateError('Failed to update user_question_answer_pair for User: ${SessionManager().userId}, Q: $questionId');
    }
    
    return result;
  }

  Future<bool> toggleUserQuestionFlaggedStatus({
    required String questionId,
  }) async {
    if (SessionManager().userId == null) throw Exception('User must be logged in');

    QuizzerLogger.logMessage('Toggling flagged status for User: ${SessionManager().userId}, Q: $questionId');
    
    // Get current flagged status
    final currentRecord = await getUserQuestionAnswerPairById(questionId);
    final currentFlagged = currentRecord['flagged'] as int? ?? 0;
    final newFlaggedStatus = currentFlagged == 0; // Toggle: 0 -> 1, 1 -> 0

    // Update the flagged status and circulation status
    final values = {
      'user_uuid': SessionManager().userId,
      'question_id': questionId,
      'flagged': newFlaggedStatus ? 1 : 0,
      'in_circulation': newFlaggedStatus ? 0 : currentRecord['in_circulation'], // Remove from circulation when flagged
    };

    final result = await UserQuestionAnswerPairsTable().upsertRecord(values);

    if (result > 0) {
      QuizzerLogger.logSuccess('Toggled flagged status for User: ${SessionManager().userId}, Q: $questionId to ${newFlaggedStatus ? 'flagged' : 'unflagged'}${newFlaggedStatus ? ' and removed from circulation' : ''} ($result row affected).');
      return true;
    } else {
      QuizzerLogger.logError('Toggle flagged operation for User: ${SessionManager().userId}, Q: $questionId affected 0 rows. Record might not exist.');
      return false;
    }
  }

  // ===================================
  // ----- PRIVATE helper -----
  // ===================================
  /// Ensures that a user question record exists for the given questionId.
  /// If it does not exist, creates a new record with default values.
  /// Uses an in-memory cache to minimize database lookups.
  /// If the cache is not initialized, it bulk loads existing records for the user.
  /// Optionally accepts a database transaction or connection to use for queries.
  /// This improves performance when ensuring multiple records in a batch.
  /// If no db is provided, uses the default database connection.
  Future<void> ensureUserQuestionRecordExists(String questionId, {dynamic db}) async {
    if (SessionManager().userId == null) {
      throw Exception('User must be logged in to ensure question records');
    }

    // Initialize cache on first run
    if (!_isCacheInitialized) {
      await _initializeExistingRecordsCache(db: db);
      _isCacheInitialized = true;
    }

    // Check cache first - O(1) lookup
    if (_existingUserQuestionRecords.contains(questionId)) {
      return;
    }

    try {
      // Record doesn't exist in cache, create it
      final newRecord = {
        'user_uuid': SessionManager().userId,
        'question_id': questionId,
        'revision_streak': 0,
        'avg_hesitation': 0.0,
        'avg_reaction_time': 0.0,
        'total_incorect_attempts': 0,
        'total_correct_attempts': 0,
        'total_attempts': 0,
        'question_accuracy_rate': 0.0,
        'question_inaccuracy_rate': 0.0,
        'average_times_shown_per_day': 0.0,
        'in_circulation': 0,
        'flagged': 0,
        'accuracy_probability': 0.25,
      };
      
      await UserQuestionAnswerPairsTable().upsertRecord(newRecord, db: db);
      // Add to cache
      _existingUserQuestionRecords.add(questionId);
      QuizzerLogger.logMessage('Created missing user question record for question: $questionId');
    } catch (e) {
      QuizzerLogger.logError('Error ensuring user question record exists for $questionId: $e');
      rethrow;
    }
  }

  /// Initializes the in-memory cache of existing user question records.
  /// Fetches all question IDs for the current user from the database
  /// and populates the _existingUserQuestionRecords set.
  Future<void> _initializeExistingRecordsCache({dynamic db}) async {
    if (SessionManager().userId == null) return;
    
    final results = await UserQuestionAnswerPairsTable().getRecord(
      "SELECT question_id FROM user_question_answer_pairs WHERE user_uuid = '${SessionManager().userId}'",
      db: db,
    );
    
    _existingUserQuestionRecords.addAll(results.map((r) => r['question_id'] as String));
    QuizzerLogger.logMessage('Initialized user question records cache with ${_existingUserQuestionRecords.length} existing records');
  }

}