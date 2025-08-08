import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import '../table_helper.dart'; // Import the helper file
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart'; // Import for _verifyQuestionAnswerPairTable
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart'; // Import sync signals
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_module_activation_status_table.dart';

Future<void> _verifyUserQuestionAnswerPairTable(dynamic db) async {
  
  // Check if the table exists
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='user_question_answer_pairs'"
  );
  
  if (tables.isEmpty) {
    await db.execute('''
      CREATE TABLE user_question_answer_pairs (
        user_uuid TEXT,
        question_id TEXT,
        revision_streak INTEGER,
        last_revised TEXT,
        predicted_revision_due_history TEXT,
        next_revision_due TEXT,
        time_between_revisions REAL,
        average_times_shown_per_day REAL,
        in_circulation INTEGER,
        total_attempts INTEGER NOT NULL DEFAULT 0,
        flagged INTEGER DEFAULT 0,
        -- Sync Fields --
        has_been_synced INTEGER DEFAULT 0,
        edits_are_synced INTEGER DEFAULT 0,
        last_modified_timestamp TEXT,
        -- ------------- --
        PRIMARY KEY (user_uuid, question_id)
      )
    ''');
    

  } else {
    // Table exists, check columns
    final List<Map<String, dynamic>> columns = await db.rawQuery(
      "PRAGMA table_info(user_question_answer_pairs)"
    );
    final Set<String> columnNames = columns.map((col) => col['name'] as String).toSet();

    // Check for total_attempts (new check)
    if (!columnNames.contains('total_attempts')) {
       QuizzerLogger.logWarning('Adding missing column: total_attempts');
      // Add with default 0 for existing rows
      await db.execute("ALTER TABLE user_question_answer_pairs ADD COLUMN total_attempts INTEGER NOT NULL DEFAULT 0");
    }

    // Check for flagged column
    if (!columnNames.contains('flagged')) {
      QuizzerLogger.logMessage('Adding flagged column to user_question_answer_pairs table.');
      await db.execute('ALTER TABLE user_question_answer_pairs ADD COLUMN flagged INTEGER DEFAULT 0');
    }

    // Add checks for new sync columns
    if (!columnNames.contains('has_been_synced')) {
      QuizzerLogger.logMessage('Adding has_been_synced column to user_question_answer_pairs table.');
      await db.execute('ALTER TABLE user_question_answer_pairs ADD COLUMN has_been_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('edits_are_synced')) {
      QuizzerLogger.logMessage('Adding edits_are_synced column to user_question_answer_pairs table.');
      await db.execute('ALTER TABLE user_question_answer_pairs ADD COLUMN edits_are_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('last_modified_timestamp')) {
      QuizzerLogger.logMessage('Adding last_modified_timestamp column to user_question_answer_pairs table.');
      await db.execute('ALTER TABLE user_question_answer_pairs ADD COLUMN last_modified_timestamp TEXT');
      // Optionally backfill with last_updated for existing rows
      // await db.rawUpdate('UPDATE user_question_answer_pairs SET last_modified_timestamp = last_updated WHERE last_modified_timestamp IS NULL');
    }
    

  }
}

/// questionAnswerReference is question_id field
Future<int> addUserQuestionAnswerPair({
  required String userUuid,
  required String questionAnswerReference,
  required int revisionStreak,
  required String? lastRevised,
  required String predictedRevisionDueHistory,
  required String nextRevisionDue,
  required double timeBetweenRevisions,
  required double averageTimesShownPerDay,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Starting addUserQuestionAnswerPair for User: $userUuid, Q: $questionAnswerReference');
    await _verifyUserQuestionAnswerPairTable(db);

    // Prepare raw data map
    final Map<String, dynamic> data = {
      'user_uuid': userUuid,
      'question_id': questionAnswerReference,
      'revision_streak': revisionStreak,
      'last_revised': lastRevised,
      'predicted_revision_due_history': predictedRevisionDueHistory,
      'next_revision_due': nextRevisionDue,
      'time_between_revisions': timeBetweenRevisions,
      'average_times_shown_per_day': averageTimesShownPerDay,
      'in_circulation': false,
      'total_attempts': 0,
      'flagged': 0,
      // Sync Fields
      'has_been_synced': 0,
      'edits_are_synced': 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    QuizzerLogger.logMessage('Prepared data map for insert...');
    // Use universal insert helper
    final int result = await insertRawData(
        'user_question_answer_pairs',
        data,
        db,
    );
    // Log success/failure based on result
    if (result > 0) {
      QuizzerLogger.logSuccess('Added user_question_answer_pair for User: $userUuid, Q: $questionAnswerReference');
      // Signal SwitchBoard
      signalOutboundSyncNeeded();
    } else {
      QuizzerLogger.logError('Insert operation for user_question_answer_pair (User: $userUuid, Q: $questionAnswerReference) returned $result.');
      throw StateError('Failed to insert user_question_answer_pair for User: $userUuid, Q: $questionAnswerReference');
    }
    return result;
  } catch (e) {
    QuizzerLogger.logError('Error adding user question answer pair - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<int> editUserQuestionAnswerPair({
  required String userUuid,
  required String questionId,
  int? revisionStreak,
  String? lastRevised,
  String? predictedRevisionDueHistory,
  String? nextRevisionDue,
  double? timeBetweenRevisions,
  double? averageTimesShownPerDay,
  bool? isEligible,
  bool? inCirculation,
  bool disableOutboundSync = false,
}) async {
  try {
    final Map<String, dynamic> currentRecord = await getUserQuestionAnswerPairById(userUuid, questionId);
    // Build the new record with updated values
    final Map<String, dynamic> newRecord = Map<String, dynamic>.from(currentRecord);
    if (revisionStreak != null) newRecord['revision_streak'] = revisionStreak;
    if (lastRevised != null) newRecord['last_revised'] = lastRevised;
    if (predictedRevisionDueHistory != null) newRecord['predicted_revision_due_history'] = predictedRevisionDueHistory;
    if (nextRevisionDue != null) newRecord['next_revision_due'] = nextRevisionDue;
    if (timeBetweenRevisions != null) newRecord['time_between_revisions'] = timeBetweenRevisions;
    if (averageTimesShownPerDay != null) newRecord['average_times_shown_per_day'] = averageTimesShownPerDay;
    if (inCirculation != null) newRecord['in_circulation'] = inCirculation ? 1 : 0;
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Starting editUserQuestionAnswerPair for User: $userUuid, Q: $questionId');
    await _verifyUserQuestionAnswerPairTable(db);

    Map<String, dynamic> values = {};
    if (revisionStreak != null) values['revision_streak'] = revisionStreak;
    if (lastRevised != null) values['last_revised'] = lastRevised;
    if (predictedRevisionDueHistory != null) values['predicted_revision_due_history'] = predictedRevisionDueHistory;
    if (nextRevisionDue != null) values['next_revision_due'] = nextRevisionDue;
    if (timeBetweenRevisions != null) values['time_between_revisions'] = timeBetweenRevisions;
    if (averageTimesShownPerDay != null) values['average_times_shown_per_day'] = averageTimesShownPerDay;
    if (inCirculation != null) values['in_circulation'] = inCirculation;
    values['edits_are_synced'] = 0;
    values['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();

    final int result = await updateRawData(
      'user_question_answer_pairs',
      values,
      'user_uuid = ? AND question_id = ?',
      [userUuid, questionId],
      db,
    );

    // Log based on result
    if (result > 0) {
      QuizzerLogger.logSuccess('Edited user_question_answer_pair for User: $userUuid, Q: $questionId ($result row affected).');
      // Signal SwitchBoard conditionally
      if (!disableOutboundSync) {
        signalOutboundSyncNeeded();
      }
    } else {
      QuizzerLogger.logError('Update operation for user_question_answer_pair (User: $userUuid, Q: $questionId) affected 0 rows. Record might not exist.');
      throw StateError('Failed to update user_question_answer_pair for User: $userUuid, Q: $questionId');
    }
    return result;
  } catch (e) {
    QuizzerLogger.logError('Error editing user question answer pair - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<Map<String, dynamic>> getUserQuestionAnswerPairById(String userUuid, String questionId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await _verifyUserQuestionAnswerPairTable(db);
    
    // Use the universal query helper
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'user_question_answer_pairs',
      db,
      where: 'user_uuid = ? AND question_id = ?',
      whereArgs: [userUuid, questionId],
      limit: 2, // Limit to 2 to detect if more than one exists
    );
    
    // Check if the result is empty or has too many rows
    if (results.isEmpty) {
      QuizzerLogger.logError('No user question answer pair found for userUuid: $userUuid and questionId: $questionId.');
      throw StateError('No record found for user $userUuid, question $questionId');
    } else if (results.length > 1) {
      QuizzerLogger.logError('Found multiple records for userUuid: $userUuid and questionId: $questionId. PK constraint violation?');
      throw StateError('Found multiple records for PK user $userUuid, question $questionId');
    }
    
    // Return the single, decoded record
    QuizzerLogger.logSuccess('Successfully fetched user_question_answer_pair for User: $userUuid, Q: $questionId');
    return results.first;
  } catch (e) {
    QuizzerLogger.logError('Error getting user question answer pair by ID - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<List<Map<String, dynamic>>> getUserQuestionAnswerPairsByUser(String userUuid) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await _verifyUserQuestionAnswerPairTable(db);
    // Use universal query helper
    return await queryAndDecodeDatabase(
      'user_question_answer_pairs',
      db,
      where: 'user_uuid = ?',
      whereArgs: [userUuid],
    );
  } catch (e) {
    QuizzerLogger.logError('Error getting user question answer pairs by user - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Gets questions in circulation with active modules for a specific user.
/// Returns questions that are in circulation (in_circulation = 1) and from active modules.
/// Automatically excludes orphaned records (user records that reference non-existent questions).
Future<List<Map<String, dynamic>>> getActiveQuestionsInCirculation(String userUuid) async {
  try {
    // Get all active module names for the user
    final List<String> activeModuleNames = await getActiveModuleNames(userUuid);
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching active questions in circulation for user: $userUuid...');
    await _verifyUserQuestionAnswerPairTable(db);

    // Build the query with proper joins and conditions
    String sql = '''
      SELECT user_question_answer_pairs.*
      FROM user_question_answer_pairs
      INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
      WHERE user_question_answer_pairs.user_uuid = ?
        AND user_question_answer_pairs.in_circulation = 1
        AND user_question_answer_pairs.flagged = 0
    ''';
    
    List<dynamic> whereArgs = [userUuid];
    
    // Add module filter if there are active modules
    if (activeModuleNames.isNotEmpty) {
      final placeholders = List.filled(activeModuleNames.length, '?').join(',');
      sql += ' AND question_answer_pairs.module_name IN ($placeholders)';
      whereArgs.addAll(activeModuleNames);
    }
    
    // Add ORDER BY for consistent results
    sql += ' ORDER BY user_question_answer_pairs.next_revision_due ASC';
    
    QuizzerLogger.logMessage('Executing active questions in circulation query with ${activeModuleNames.length} active modules');
    
    // Use the proper table_helper system for encoding/decoding
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'user_question_answer_pairs', // Use the main table name for the helper
      db,
      customQuery: sql,
      whereArgs: whereArgs,
    );
    
    QuizzerLogger.logSuccess('Found ${results.length} active questions in circulation for user: $userUuid.');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting active questions in circulation - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<List<Map<String, dynamic>>> getQuestionsInCirculation(String userUuid) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await _verifyUserQuestionAnswerPairTable(db);
    await verifyQuestionAnswerPairTable(db);
    
    // Use a JOIN to exclude orphaned records (user records that reference non-existent questions)
    String sql = '''
      SELECT user_question_answer_pairs.*
      FROM user_question_answer_pairs
      INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
      WHERE user_question_answer_pairs.user_uuid = ?
        AND user_question_answer_pairs.in_circulation = 1
    ''';
    
    List<dynamic> whereArgs = [userUuid];
    
    QuizzerLogger.logMessage('Executing questions in circulation query (automatically excluding orphaned records)');
    final List<Map<String, dynamic>> results = await db.rawQuery(sql, whereArgs);
    
    QuizzerLogger.logSuccess('Found ${results.length} questions in circulation for user: $userUuid.');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting questions in circulation - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<List<Map<String, dynamic>>> getAllUserQuestionAnswerPairs(String userUuid) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await _verifyUserQuestionAnswerPairTable(db);
    // Use universal query helper
    return await queryAndDecodeDatabase(
        'user_question_answer_pairs',
        db,
        where: 'user_uuid = ?',
        whereArgs: [userUuid]
    );
  } catch (e) {
    QuizzerLogger.logError('Error getting all user question answer pairs - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<int> removeUserQuestionAnswerPair(String userUuid, String questionAnswerReference) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await _verifyUserQuestionAnswerPairTable(db);

    return await db.delete(
      'user_question_answer_pairs',
      where: 'user_uuid = ? AND question_id = ?',
      whereArgs: [userUuid, questionAnswerReference],
    );
  } catch (e) {
    QuizzerLogger.logError('Error removing user question answer pair - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Increments the total_attempts count for a specific user-question pair.
Future<void> incrementTotalAttempts(String userUuid, String questionId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Incrementing total attempts for User: $userUuid, Question: $questionId');
    
    // Ensure the table and column exist before attempting update
    await _verifyUserQuestionAnswerPairTable(db);

    final String currentTime = DateTime.now().toUtc().toIso8601String();
    final int rowsAffected = await db.rawUpdate(
      'UPDATE user_question_answer_pairs SET total_attempts = total_attempts + 1, edits_are_synced = 0, last_modified_timestamp = ? WHERE user_uuid = ? AND question_id = ?',
      [currentTime, userUuid, questionId] // No longer setting last_updated here
    );

    if (rowsAffected == 0) {
      QuizzerLogger.logWarning('Failed to increment total attempts: No matching record found for User: $userUuid, Question: $questionId');
      // Depending on desired behavior, could throw an exception here if the record *should* exist.
    } else {
      QuizzerLogger.logSuccess('Successfully incremented total attempts for User: $userUuid, Question: $questionId');
      // Signal SwitchBoard
      signalOutboundSyncNeeded();
    }
  } catch (e) {
    QuizzerLogger.logError('Error incrementing total attempts - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Updates the user-specific record for a question's circulation status.
/// Takes a boolean [isInCirculation] to set the status accordingly.
/// Throws an Exception if the record is not found, adhering to fail-fast.
Future<void> setCirculationStatus(String userUuid, String questionId, bool isInCirculation) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    final String statusString = isInCirculation ? 'IN' : 'OUT OF';
    QuizzerLogger.logMessage(
        'DB Table: Setting question $questionId $statusString circulation for user $userUuid');

    // Ensure table exists before update
    await _verifyUserQuestionAnswerPairTable(db);

    // Perform the update using the universal update helper directly
    final Map<String, dynamic> updateData = {
      'in_circulation': isInCirculation, // Pass bool directly
      'edits_are_synced': 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    
    final int rowsAffected = await updateRawData(
      'user_question_answer_pairs',
      updateData,
      'user_uuid = ? AND question_id = ?', // where
      [userUuid, questionId],             // whereArgs
      db,
    );

    if (rowsAffected == 0) {
      // Fail fast if the specific record wasn't found for update
      QuizzerLogger.logError(
          'Update circulation status failed: No record found for user $userUuid and question $questionId');
      // NOTE: Throwing here because if this is called, the record SHOULD exist.
      throw StateError(
          'Record not found for user $userUuid and question $questionId during circulation update.');
    }

    QuizzerLogger.logSuccess(
        'Successfully set circulation status ($statusString) for question $questionId. Rows affected: $rowsAffected');
    // Signal SwitchBoard
    signalOutboundSyncNeeded();
  } catch (e) {
    QuizzerLogger.logError('Error setting circulation status - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}





/// Fetches all user-question-answer pairs for a specific user that need outbound synchronization.
/// This includes records that have never been synced (`has_been_synced = 0`)
/// or records that have local edits pending sync (`edits_are_synced = 0`).
/// Does NOT decode the records.
Future<List<Map<String, dynamic>>> getUnsyncedUserQuestionAnswerPairs(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching unsynced user-question-answer pairs for user: $userId...');
    await _verifyUserQuestionAnswerPairTable(db);

    final List<Map<String, dynamic>> results = await db.query(
      'user_question_answer_pairs',
      where: '(has_been_synced = 0 OR edits_are_synced = 0) AND user_uuid = ?',
      whereArgs: [userId],
    );

    QuizzerLogger.logSuccess('Fetched ${results.length} unsynced user-question-answer pairs for user $userId.');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced user question answer pairs - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Updates the synchronization flags for a specific user_question_answer_pair.
/// Does NOT trigger a new sync signal.
Future<void> updateUserQuestionAnswerPairSyncFlags({
  required String userUuid,
  required String questionId,
  required bool hasBeenSynced,
  required bool editsAreSynced,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Updating sync flags for UserQuestionAnswerPair (User: $userUuid, QID: $questionId) -> Synced: $hasBeenSynced, Edits Synced: $editsAreSynced');
    await _verifyUserQuestionAnswerPairTable(db); // Ensure table/columns exist

    final Map<String, dynamic> updates = {
      'has_been_synced': hasBeenSynced ? 1 : 0,
      'edits_are_synced': editsAreSynced ? 1 : 0,
    };

    final int rowsAffected = await updateRawData(
      'user_question_answer_pairs',
      updates,
      'user_uuid = ? AND question_id = ?', // Where clause using composite PK
      [userUuid, questionId],              // Where args
      db,
    );

    if (rowsAffected == 0) {
      QuizzerLogger.logWarning('updateUserQuestionAnswerPairSyncFlags affected 0 rows for UserQuestionAnswerPair (User: $userUuid, QID: $questionId). Record might not exist?');
    } else {
      QuizzerLogger.logSuccess('Successfully updated flags for UserQuestionAnswerPair (User: $userUuid, QID: $questionId).');
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating user question answer pair sync flags - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Inserts a new user question answer pair or updates an existing one.
/// Uses the composite primary key (user_uuid, question_id) to determine if record exists.
Future<int> insertOrUpdateUserQuestionAnswerPair({
  required String userUuid,
  required String questionId,
  required int revisionStreak,
  required String? lastRevised,
  required String predictedRevisionDueHistory,
  required String nextRevisionDue,
  required double timeBetweenRevisions,
  required double averageTimesShownPerDay,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Starting insertOrUpdateUserQuestionAnswerPair for User: $userUuid, Q: $questionId');
    await _verifyUserQuestionAnswerPairTable(db);

    // First try to get existing record
    QuizzerLogger.logMessage('Checking for existing record...');
    final List<Map<String, dynamic>> existing = await queryAndDecodeDatabase(
      'user_question_answer_pairs',
      db,
      where: 'user_uuid = ? AND question_id = ?',
      whereArgs: [userUuid, questionId],
    );

    if (existing.isEmpty) {
      // No existing record, use add
      QuizzerLogger.logMessage('No existing record found, using addUserQuestionAnswerPair...');
      getDatabaseMonitor().releaseDatabaseAccess(); // Release before calling add
      return await addUserQuestionAnswerPair(
        userUuid: userUuid,
        questionAnswerReference: questionId,
        revisionStreak: revisionStreak,
        lastRevised: lastRevised,
        predictedRevisionDueHistory: predictedRevisionDueHistory,
        nextRevisionDue: nextRevisionDue,
        timeBetweenRevisions: timeBetweenRevisions,
        averageTimesShownPerDay: averageTimesShownPerDay,
      );
    } else {
      // Record exists, use edit
      QuizzerLogger.logMessage('Existing record found, using editUserQuestionAnswerPair...');
      getDatabaseMonitor().releaseDatabaseAccess(); // Release before calling edit
      return await editUserQuestionAnswerPair(
        userUuid: userUuid,
        questionId: questionId,
        revisionStreak: revisionStreak,
        lastRevised: lastRevised,
        predictedRevisionDueHistory: predictedRevisionDueHistory,
        nextRevisionDue: nextRevisionDue,
        timeBetweenRevisions: timeBetweenRevisions,
        averageTimesShownPerDay: averageTimesShownPerDay,
      );
    }
  } catch (e) {
    QuizzerLogger.logError('Error inserting or updating user question answer pair - $e');
    getDatabaseMonitor().releaseDatabaseAccess(); // Release in case of error
    rethrow;
  }
}

/// True batch upsert for user_question_answer_pairs using a single SQL statement
Future<void> batchUpsertUserQuestionAnswerPairs({
  required List<Map<String, dynamic>> records,
  int chunkSize = 500,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    if (records.isEmpty) return;
    QuizzerLogger.logMessage('Starting TRUE batch upsert for user_question_answer_pairs: ${records.length} records');
    await _verifyUserQuestionAnswerPairTable(db);

    // Get all columns dynamically from the table
    final List<Map<String, dynamic>> columnInfo = await db.rawQuery("PRAGMA table_info(user_question_answer_pairs)");
    final List<String> columns = columnInfo.map((col) => col['name'] as String).toList();

    // Helper to get value or null/default
    dynamic getVal(Map<String, dynamic> r, String k, dynamic def) => r[k] ?? def;

    for (int i = 0; i < records.length; i += chunkSize) {
      final batch = records.sublist(i, i + chunkSize > records.length ? records.length : i + chunkSize);
      final values = <dynamic>[];
      final valuePlaceholders = batch.map((r) {
        // Ensure sync flags are set to 1 for inbound sync
        r = Map<String, dynamic>.from(r);
        r['has_been_synced'] = 1;
        r['edits_are_synced'] = 1;
        for (final col in columns) {
          values.add(getVal(r, col, null));
        }
        return '(${List.filled(columns.length, '?').join(',')})';
      }).join(', ');

      final updateSet = columns.where((c) => c != 'user_uuid' && c != 'question_id').map((c) => '$c=excluded.$c').join(', ');
      final sql = 'INSERT INTO user_question_answer_pairs (${columns.join(',')}) VALUES $valuePlaceholders ON CONFLICT(user_uuid, question_id) DO UPDATE SET $updateSet;';
      await db.rawInsert(sql, values);
    }
    QuizzerLogger.logSuccess('TRUE batch upsert for user_question_answer_pairs complete.');
  } catch (e) {
    QuizzerLogger.logError('Error batch upserting user question answer pairs - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}



/// Fetches all eligible user question answer pairs for a specific user.
/// Ensures all modules have activation status records before running the query.
/// Does NOT decode the records.
Future<List<Map<String, dynamic>>> getEligibleUserQuestionAnswerPairs(String userUuid) async {
  try {
    // Ensure all modules have activation status records before checking eligibility
    await ensureAllModulesHaveActivationStatus(userUuid);
    // Get all active module names for the user
    final List<String> activeModuleNames = await getActiveModuleNames(userUuid);
    
    // Now we can get DB Access and process the query
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching eligible user question answer pairs for user: $userUuid...');
    await _verifyUserQuestionAnswerPairTable(db);

    // Eligible question criteria:
    // 1. The question must be in circulation -> in_circulation = 1
    // 2. The question must be past due -> next_revision_due < now
    // 3. The question's module must be active OR it's concept must be active
    // We have the list of active modules above, so we can use that to filter the questions
    // We do not have a system for concept activation yet, so we will not filter by concept right now
    
    final String now = DateTime.now().toUtc().toIso8601String();
    
    // Build the query with proper joins and conditions - only select needed fields
    String sql = '''
      SELECT 
        user_question_answer_pairs.user_uuid,
        user_question_answer_pairs.question_id,
        user_question_answer_pairs.revision_streak,
        user_question_answer_pairs.last_revised,
        user_question_answer_pairs.predicted_revision_due_history,
        user_question_answer_pairs.next_revision_due,
        user_question_answer_pairs.time_between_revisions,
        user_question_answer_pairs.average_times_shown_per_day,
        user_question_answer_pairs.in_circulation,
        user_question_answer_pairs.total_attempts,
        question_answer_pairs.question_elements,
        question_answer_pairs.answer_elements,
        question_answer_pairs.module_name,
        question_answer_pairs.question_type,
        question_answer_pairs.options,
        question_answer_pairs.correct_option_index,
        question_answer_pairs.correct_order,
        question_answer_pairs.index_options_that_apply
      FROM user_question_answer_pairs
      INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
      WHERE user_question_answer_pairs.user_uuid = ?
        AND user_question_answer_pairs.in_circulation = 1
        AND user_question_answer_pairs.next_revision_due < ?
        AND user_question_answer_pairs.flagged = 0
    ''';
    
    List<dynamic> whereArgs = [userUuid, now];
    
    // Add module filter if there are active modules
    if (activeModuleNames.isNotEmpty) {
      final placeholders = List.filled(activeModuleNames.length, '?').join(',');
      sql += ' AND question_answer_pairs.module_name IN ($placeholders)';
      whereArgs.addAll(activeModuleNames);
    }
    
    // Add ORDER BY for consistent results
    sql += ' ORDER BY user_question_answer_pairs.next_revision_due ASC';
    
    QuizzerLogger.logMessage('Executing eligibility query with ${activeModuleNames.length} active modules');
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'user_question_answer_pairs', // Use the main table name for the helper
      db,
      customQuery: sql,
      whereArgs: whereArgs,
    );

    QuizzerLogger.logSuccess('Fetched ${results.length} eligible records for user: $userUuid (fields pre-filtered in SQL query).');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting eligible user question answer pairs - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Gets the count of eligible questions with revision_score == 0 for a specific user.
/// Stops counting once it reaches 10 results for performance optimization.
/// Uses the same eligibility logic as getEligibleUserQuestionAnswerPairs.
Future<int> getLowRevisionStreakEligibleCount(String userUuid) async {
  try {
    // Ensure all modules have activation status records before checking eligibility
    await ensureAllModulesHaveActivationStatus(userUuid);
    // Get all active module names for the user
    final List<String> activeModuleNames = await getActiveModuleNames(userUuid);
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Counting revision_score == 0 eligible questions for user: $userUuid...');
    await _verifyUserQuestionAnswerPairTable(db);

    final String now = DateTime.now().toUtc().toIso8601String();
    
    // Build the query with proper joins and conditions, limiting to 10 results
    String sql = '''
      SELECT COUNT(*) as count
      FROM (
        SELECT user_question_answer_pairs.question_id
        FROM user_question_answer_pairs
        INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
        WHERE user_question_answer_pairs.user_uuid = ?
          AND user_question_answer_pairs.in_circulation = 1
          AND user_question_answer_pairs.next_revision_due < ?
          AND user_question_answer_pairs.revision_streak = 0
          AND user_question_answer_pairs.flagged = 0
    ''';
    
    List<dynamic> whereArgs = [userUuid, now];
    
    // Add module filter if there are active modules
    if (activeModuleNames.isNotEmpty) {
      final placeholders = List.filled(activeModuleNames.length, '?').join(',');
      sql += ' AND question_answer_pairs.module_name IN ($placeholders)';
      whereArgs.addAll(activeModuleNames);
    }
    
    // Add ORDER BY and LIMIT for consistent results
    sql += ' ORDER BY user_question_answer_pairs.next_revision_due ASC LIMIT 10) as subquery';
    
    QuizzerLogger.logMessage('Executing revision_score == 0 count query with ${activeModuleNames.length} active modules');
    final List<Map<String, dynamic>> results = await db.rawQuery(sql, whereArgs);
    
    final int count = results.isNotEmpty ? (results.first['count'] as int) : 0;
    QuizzerLogger.logSuccess('Found $count revision_score == 0 eligible questions for user: $userUuid.');
    return count;
  } catch (e) {
    QuizzerLogger.logError('Error counting revision_score == 0 eligible questions - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Gets the total count of eligible questions for a specific user.
/// Stops counting once it reaches 100 results for performance optimization.
/// Uses the same eligibility logic as getEligibleUserQuestionAnswerPairs.
Future<int> getTotalEligibleCount(String userUuid) async {
  try {
    // Ensure all modules have activation status records before checking eligibility
    await ensureAllModulesHaveActivationStatus(userUuid);
    // Get all active module names for the user
    final List<String> activeModuleNames = await getActiveModuleNames(userUuid);
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Counting total eligible questions for user: $userUuid...');
    await _verifyUserQuestionAnswerPairTable(db);

    final String now = DateTime.now().toUtc().toIso8601String();
    
    // Build the query with proper joins and conditions, limiting to 100 results
    String sql = '''
      SELECT COUNT(*) as count
      FROM (
        SELECT user_question_answer_pairs.question_id
        FROM user_question_answer_pairs
        INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
        WHERE user_question_answer_pairs.user_uuid = ?
          AND user_question_answer_pairs.in_circulation = 1
          AND user_question_answer_pairs.next_revision_due < ?
          AND user_question_answer_pairs.flagged = 0
    ''';
    
    List<dynamic> whereArgs = [userUuid, now];
    
    // Add module filter if there are active modules
    if (activeModuleNames.isNotEmpty) {
      final placeholders = List.filled(activeModuleNames.length, '?').join(',');
      sql += ' AND question_answer_pairs.module_name IN ($placeholders)';
      whereArgs.addAll(activeModuleNames);
    }
    
    // Add ORDER BY and LIMIT for consistent results
    sql += ' ORDER BY user_question_answer_pairs.next_revision_due ASC LIMIT 100) as subquery';
    
    QuizzerLogger.logMessage('Executing total eligible count query with ${activeModuleNames.length} active modules');
    final List<Map<String, dynamic>> results = await db.rawQuery(sql, whereArgs);
    
    final int count = results.isNotEmpty ? (results.first['count'] as int) : 0;
    QuizzerLogger.logSuccess('Found $count total eligible questions for user: $userUuid.');
    return count;
  } catch (e) {
    QuizzerLogger.logError('Error counting total eligible questions - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Gets non-circulating questions with full question details for a specific user.
/// Returns questions that are not in circulation (in_circulation = 0) and not flagged (flagged = 0) with their complete details.
/// Automatically excludes orphaned records (user records that reference non-existent questions).
Future<List<Map<String, dynamic>>> getNonCirculatingQuestionsWithDetails(String userUuid) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching non-circulating questions with details for user: $userUuid...');
    // Ensure BOTH tables exist before running the query
    await _verifyUserQuestionAnswerPairTable(db);
    await verifyQuestionAnswerPairTable(db);

    // Build the query with proper joins to get both user question data and question details
    String sql = '''
      SELECT user_question_answer_pairs.*, question_answer_pairs.*
      FROM user_question_answer_pairs
      INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
      WHERE user_question_answer_pairs.user_uuid = ?
        AND user_question_answer_pairs.in_circulation = 0
        AND user_question_answer_pairs.flagged = 0
      ORDER BY user_question_answer_pairs.next_revision_due ASC
    ''';
    
    List<dynamic> whereArgs = [userUuid];
    
    QuizzerLogger.logMessage('Executing non-circulating questions query');
    final List<Map<String, dynamic>> results = await db.rawQuery(sql, whereArgs);
    
    QuizzerLogger.logSuccess('Found ${results.length} non-circulating questions for user: $userUuid.');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting non-circulating questions with details - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Toggles the flagged status of a user question answer pair.
/// Returns true if the operation was successful, false otherwise.
Future<bool> toggleUserQuestionFlaggedStatus({
  required String userUuid,
  required String questionId,
  bool disableOutboundSync = false,
}) async {
  try {
    QuizzerLogger.logMessage('Toggling flagged status for User: $userUuid, Q: $questionId');
    
    // Get current flagged status (this function handles its own database access)
    final Map<String, dynamic> currentRecord = await getUserQuestionAnswerPairById(userUuid, questionId);
    final int currentFlagged = currentRecord['flagged'] as int? ?? 0;
    final bool newFlaggedStatus = currentFlagged == 0; // Toggle: 0 -> 1, 1 -> 0

    // Get database access for the update operation
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    
    try {
      await _verifyUserQuestionAnswerPairTable(db);

      // Update the flagged status and circulation status
      final Map<String, dynamic> values = {
        'flagged': newFlaggedStatus ? 1 : 0,
        'in_circulation': newFlaggedStatus ? 0 : currentRecord['in_circulation'], // Remove from circulation when flagged
        'edits_are_synced': 0,
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      final int result = await updateRawData(
        'user_question_answer_pairs',
        values,
        'user_uuid = ? AND question_id = ?',
        [userUuid, questionId],
        db,
      );

      // Log based on result
      if (result > 0) {
        QuizzerLogger.logSuccess('Toggled flagged status for User: $userUuid, Q: $questionId to ${newFlaggedStatus ? 'flagged' : 'unflagged'}${newFlaggedStatus ? ' and removed from circulation' : ''} ($result row affected).');
        // Signal SwitchBoard conditionally
        if (!disableOutboundSync) {
          signalOutboundSyncNeeded();
        }
        return true;
      } else {
        QuizzerLogger.logError('Toggle flagged operation for User: $userUuid, Q: $questionId affected 0 rows. Record might not exist.');
        return false;
      }
    } finally {
      getDatabaseMonitor().releaseDatabaseAccess();
    }
  } catch (e) {
    QuizzerLogger.logError('Error toggling user question flagged status - $e');
    return false;
  }
}

