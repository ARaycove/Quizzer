import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'table_helper.dart'; // Import the helper file
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart'; // Import SwitchBoard
import 'package:quizzer/backend_systems/06_question_queue_server/eligibility_check_worker.dart'; // Import for isUserRecordEligible

Future<void> verifyUserQuestionAnswerPairTable(dynamic db) async {
  
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
        is_eligible INTEGER,
        in_circulation INTEGER,
        total_attempts INTEGER NOT NULL DEFAULT 0,
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
  required dynamic db, // Accept either Database or Transaction
}) async {
  QuizzerLogger.logMessage('Starting addUserQuestionAnswerPair for User: $userUuid, Q: $questionAnswerReference');
  await verifyUserQuestionAnswerPairTable(db);

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
    final SwitchBoard switchBoard = getSwitchBoard();
    switchBoard.signalOutboundSyncNeeded();
  } else {
    QuizzerLogger.logError('Insert operation for user_question_answer_pair (User: $userUuid, Q: $questionAnswerReference) returned $result.');
    throw StateError('Failed to insert user_question_answer_pair for User: $userUuid, Q: $questionAnswerReference');
  }
  return result; 
}

Future<int> editUserQuestionAnswerPair({
  required String userUuid,
  required String questionId,
  required dynamic db, // Accept either Database or Transaction
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
  QuizzerLogger.logMessage('Starting editUserQuestionAnswerPair for User: $userUuid, Q: $questionId');
  await verifyUserQuestionAnswerPairTable(db);

  // Fetch the current record from the DB to build the full record for eligibility check
  QuizzerLogger.logMessage('Fetching current record for eligibility check...');
  final Map<String, dynamic> currentRecord = await getUserQuestionAnswerPairById(userUuid, questionId, db);
  // Build the new record with updated values
  final Map<String, dynamic> newRecord = Map<String, dynamic>.from(currentRecord);
  if (revisionStreak != null) newRecord['revision_streak'] = revisionStreak;
  if (lastRevised != null) newRecord['last_revised'] = lastRevised;
  if (predictedRevisionDueHistory != null) newRecord['predicted_revision_due_history'] = predictedRevisionDueHistory;
  if (nextRevisionDue != null) newRecord['next_revision_due'] = nextRevisionDue;
  if (timeBetweenRevisions != null) newRecord['time_between_revisions'] = timeBetweenRevisions;
  if (averageTimesShownPerDay != null) newRecord['average_times_shown_per_day'] = averageTimesShownPerDay;
  if (inCirculation != null) newRecord['in_circulation'] = inCirculation ? 1 : 0;

  final bool eligible = await isUserRecordEligible(newRecord, db);
  newRecord['is_eligible'] = eligible ? 1 : 0;

  Map<String, dynamic> values = {};
  if (revisionStreak != null) values['revision_streak'] = revisionStreak;
  if (lastRevised != null) values['last_revised'] = lastRevised;
  if (predictedRevisionDueHistory != null) values['predicted_revision_due_history'] = predictedRevisionDueHistory;
  if (nextRevisionDue != null) values['next_revision_due'] = nextRevisionDue;
  if (timeBetweenRevisions != null) values['time_between_revisions'] = timeBetweenRevisions;
  if (averageTimesShownPerDay != null) values['average_times_shown_per_day'] = averageTimesShownPerDay;
  if (inCirculation != null) values['in_circulation'] = inCirculation;
  values['is_eligible'] = eligible ? 1 : 0;
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
      final SwitchBoard switchBoard = getSwitchBoard();
      switchBoard.signalOutboundSyncNeeded();
    }
  } else {
    QuizzerLogger.logError('Update operation for user_question_answer_pair (User: $userUuid, Q: $questionId) affected 0 rows. Record might not exist.');
    throw StateError('Failed to update user_question_answer_pair for User: $userUuid, Q: $questionId');
  }
  return result;
}

Future<Map<String, dynamic>> getUserQuestionAnswerPairById(String userUuid, String questionId, dynamic db) async {
  await verifyUserQuestionAnswerPairTable(db);
  
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
}

Future<List<Map<String, dynamic>>> getUserQuestionAnswerPairsByUser(String userUuid, dynamic db) async {
  await verifyUserQuestionAnswerPairTable(db);
  // Use universal query helper
  return await queryAndDecodeDatabase(
    'user_question_answer_pairs',
    db,
    where: 'user_uuid = ?',
    whereArgs: [userUuid],
  );
}

Future<List<Map<String, dynamic>>> getQuestionsInCirculation(String userUuid, dynamic db) async {
  await verifyUserQuestionAnswerPairTable(db);
  // Use universal query helper
  return await queryAndDecodeDatabase(
    'user_question_answer_pairs',
    db,
    where: 'user_uuid = ? AND in_circulation = ?',
    whereArgs: [userUuid, 1], // Query for in_circulation = 1 (true)
  );
}

Future<List<Map<String, dynamic>>> getAllUserQuestionAnswerPairs(dynamic db, String userUuid) async {
  await verifyUserQuestionAnswerPairTable(db);
  // Use universal query helper
  return await queryAndDecodeDatabase(
      'user_question_answer_pairs',
      db,
      where: 'user_uuid = ?',
      whereArgs: [userUuid]
  );
}

Future<int> removeUserQuestionAnswerPair(String userUuid, String questionAnswerReference, dynamic db) async {
  await verifyUserQuestionAnswerPairTable(db);

  return await db.delete(
    'user_question_answer_pairs',
    where: 'user_uuid = ? AND question_id = ?',
    whereArgs: [userUuid, questionAnswerReference],
  );
}

/// Increments the total_attempts count for a specific user-question pair.
Future<void> incrementTotalAttempts(String userUuid, String questionId, dynamic db) async {
  QuizzerLogger.logMessage('Incrementing total attempts for User: $userUuid, Question: $questionId');
  
  // Ensure the table and column exist before attempting update
  await verifyUserQuestionAnswerPairTable(db);

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
    final SwitchBoard switchBoard = getSwitchBoard();
    switchBoard.signalOutboundSyncNeeded();
  }
}

/// Updates the user-specific record for a question's circulation status.
/// Takes a boolean [isInCirculation] to set the status accordingly.
/// Throws an Exception if the record is not found, adhering to fail-fast.
Future<void> setCirculationStatus(
    String userUuid, String questionId, bool isInCirculation, dynamic db) async {
  final String statusString = isInCirculation ? 'IN' : 'OUT OF';
  QuizzerLogger.logMessage(
      'DB Table: Setting question $questionId $statusString circulation for user $userUuid');

  // Ensure table exists before update
  await verifyUserQuestionAnswerPairTable(db);

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
  final SwitchBoard switchBoard = getSwitchBoard();
  switchBoard.signalOutboundSyncNeeded();
}

/// Updates the eligibility status for a specific user-question pair.
/// Takes a boolean [isEligible] to set the status accordingly.
/// Throws an Exception if the record is not found, adhering to fail-fast.
Future<void> setEligibilityStatus(
    String userUuid, String questionId, bool isEligible, dynamic db) async {
  final String statusString = isEligible ? 'ELIGIBLE' : 'INELIGIBLE';
  QuizzerLogger.logMessage(
      'DB Table: Setting question $questionId to $statusString for user $userUuid');

  // Ensure table exists before update
  await verifyUserQuestionAnswerPairTable(db);

  // Perform the update using the universal update helper directly
  final Map<String, dynamic> updateData = {
    'is_eligible': isEligible ? 1 : 0,
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
        'Update eligibility status failed: No record found for user $userUuid and question $questionId');
    throw StateError(
        'Record not found for user $userUuid and question $questionId during eligibility update.');
  }

  QuizzerLogger.logSuccess(
      'Successfully set eligibility status ($statusString) for question $questionId. Rows affected: $rowsAffected');
}

/// Fetches all user-question-answer pairs for a specific user that need outbound synchronization.
/// This includes records that have never been synced (`has_been_synced = 0`)
/// or records that have local edits pending sync (`edits_are_synced = 0`).
/// Does NOT decode the records.
Future<List<Map<String, dynamic>>> getUnsyncedUserQuestionAnswerPairs(dynamic db, String userId) async {
  QuizzerLogger.logMessage('Fetching unsynced user-question-answer pairs for user: $userId...');
  await verifyUserQuestionAnswerPairTable(db);

  final List<Map<String, dynamic>> results = await db.query(
    'user_question_answer_pairs',
    where: '(has_been_synced = 0 OR edits_are_synced = 0) AND user_uuid = ?',
    whereArgs: [userId],
  );

  QuizzerLogger.logSuccess('Fetched ${results.length} unsynced user-question-answer pairs for user $userId.');
  return results;
}

/// Updates the synchronization flags for a specific user_question_answer_pair.
/// Does NOT trigger a new sync signal.
Future<void> updateUserQuestionAnswerPairSyncFlags({
  required String userUuid,
  required String questionId,
  required bool hasBeenSynced,
  required bool editsAreSynced,
  required dynamic db,
}) async {
  QuizzerLogger.logMessage('Updating sync flags for UserQuestionAnswerPair (User: $userUuid, QID: $questionId) -> Synced: $hasBeenSynced, Edits Synced: $editsAreSynced');
  await verifyUserQuestionAnswerPairTable(db); // Ensure table/columns exist

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
  required dynamic db, // Accept either Database or Transaction
}) async {
  QuizzerLogger.logMessage('Starting insertOrUpdateUserQuestionAnswerPair for User: $userUuid, Q: $questionId');
  await verifyUserQuestionAnswerPairTable(db);

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
    return await addUserQuestionAnswerPair(
      userUuid: userUuid,
      questionAnswerReference: questionId,
      revisionStreak: revisionStreak,
      lastRevised: lastRevised,
      predictedRevisionDueHistory: predictedRevisionDueHistory,
      nextRevisionDue: nextRevisionDue,
      timeBetweenRevisions: timeBetweenRevisions,
      averageTimesShownPerDay: averageTimesShownPerDay,
      db: db,
    );
  } else {
    // Record exists, use edit
    QuizzerLogger.logMessage('Existing record found, using editUserQuestionAnswerPair...');
    return await editUserQuestionAnswerPair(
      userUuid: userUuid,
      questionId: questionId,
      revisionStreak: revisionStreak,
      lastRevised: lastRevised,
      predictedRevisionDueHistory: predictedRevisionDueHistory,
      nextRevisionDue: nextRevisionDue,
      timeBetweenRevisions: timeBetweenRevisions,
      averageTimesShownPerDay: averageTimesShownPerDay,
      db: db,
    );
  }
}

/// True batch upsert for user_question_answer_pairs using a single SQL statement
Future<void> batchUpsertUserQuestionAnswerPairs({
  required List<Map<String, dynamic>> records,
  required dynamic db,
  int chunkSize = 500,
}) async {
  if (records.isEmpty) return;
  QuizzerLogger.logMessage('Starting TRUE batch upsert for user_question_answer_pairs: ${records.length} records');
  await verifyUserQuestionAnswerPairTable(db);

  // List of all columns in the table
  final columns = [
    'user_uuid',
    'question_id',
    'revision_streak',
    'last_revised',
    'predicted_revision_due_history',
    'next_revision_due',
    'time_between_revisions',
    'average_times_shown_per_day',
    'is_eligible',
    'in_circulation',
    'total_attempts',
    'has_been_synced',
    'edits_are_synced',
    'last_modified_timestamp',
  ];

  // Helper to get value or null/default
  dynamic getVal(Map<String, dynamic> r, String k, dynamic def) => r[k] ?? def;

  for (int i = 0; i < records.length; i += chunkSize) {
    final batch = records.sublist(i, i + chunkSize > records.length ? records.length : i + chunkSize);
    final values = <dynamic>[];
    final valuePlaceholders = batch.map((r) {
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
}