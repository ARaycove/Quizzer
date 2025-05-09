import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import '00_table_helper.dart'; // Import the helper file
import 'package:quizzer/backend_systems/12_switch_board/switch_board.dart'; // Import SwitchBoard

Future<void> verifyUserQuestionAnswerPairTable(Database db) async {
  
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
  required String questionAnswerReference, // Renamed to questionId for consistency?
  required int revisionStreak,
  required String? lastRevised,
  required String predictedRevisionDueHistory,
  required String nextRevisionDue,
  required double timeBetweenRevisions,
  required double averageTimesShownPerDay,
  required Database db,
}) async {
  await verifyUserQuestionAnswerPairTable(db);

  // Prepare raw data map
  final Map<String, dynamic> data = {
    'user_uuid': userUuid,
    'question_id': questionAnswerReference, // Use the parameter name
    'revision_streak': revisionStreak,
    'last_revised': lastRevised,
    'predicted_revision_due_history': predictedRevisionDueHistory,
    'next_revision_due': nextRevisionDue,
    'time_between_revisions': timeBetweenRevisions,
    'average_times_shown_per_day': averageTimesShownPerDay,
    'in_circulation': false, // Default to false, pass bool directly
    'total_attempts': 0, // Initialize total_attempts on creation
    // Sync Fields
    'has_been_synced': 0,
    'edits_are_synced': 0,
    'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(), // Use current time
  };

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
    QuizzerLogger.logWarning('Insert operation for user_question_answer_pair (User: $userUuid, Q: $questionAnswerReference) returned $result.');
  }
  return result; 
}

Future<int> editUserQuestionAnswerPair({
  required String userUuid,
  required String questionId,
  required Database db,
  int? revisionStreak,
  String? lastRevised,
  String? predictedRevisionDueHistory,
  String? nextRevisionDue,
  double? timeBetweenRevisions,
  double? averageTimesShownPerDay,
  bool? isEligible,
  bool? inCirculation,
}) async {
  await verifyUserQuestionAnswerPairTable(db);

  // Prepare raw data map
  Map<String, dynamic> values = {};
  
  if (revisionStreak != null) values['revision_streak'] = revisionStreak;
  if (lastRevised != null) values['last_revised'] = lastRevised;
  if (predictedRevisionDueHistory != null) values['predicted_revision_due_history'] = predictedRevisionDueHistory;
  if (nextRevisionDue != null) values['next_revision_due'] = nextRevisionDue;
  if (timeBetweenRevisions != null) values['time_between_revisions'] = timeBetweenRevisions;
  if (averageTimesShownPerDay != null) values['average_times_shown_per_day'] = averageTimesShownPerDay;
  if (isEligible != null) values['is_eligible'] = isEligible; // Pass bool directly
  if (inCirculation != null) values['in_circulation'] = inCirculation; // Pass bool directly
  
  // Add sync fields for edit
  values['edits_are_synced'] = 0;
  values['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();

  // If only last_updated was set (e.g. from setCirculationStatus without other changes),
  // the map might still be empty excluding that. Check if other keys exist.
  if (values.keys.where((k) => k != 'edits_are_synced' && k != 'last_modified_timestamp').isEmpty) {
     QuizzerLogger.logWarning('editUserQuestionAnswerPair called for User: $userUuid, Q: $questionId with no fields to update besides sync/timestamp fields.');
     // Optionally return 0 if only sync/timestamp fields were updated implicitly?
     // For now, let the update proceed.
  }

  // Use universal update helper
  final int result = await updateRawData(
    'user_question_answer_pairs',
    values,
    'user_uuid = ? AND question_id = ?', // where clause
    [userUuid, questionId],             // whereArgs
    db,
  );

  // Log based on result
  if (result > 0) {
    QuizzerLogger.logSuccess('Edited user_question_answer_pair for User: $userUuid, Q: $questionId ($result row affected).');
    // Signal SwitchBoard
    final SwitchBoard switchBoard = getSwitchBoard();
    switchBoard.signalOutboundSyncNeeded();
  } else {
    QuizzerLogger.logWarning('Update operation for user_question_answer_pair (User: $userUuid, Q: $questionId) affected 0 rows. Record might not exist.');
  }
  return result;
}

Future<Map<String, dynamic>> getUserQuestionAnswerPairById(String userUuid, String questionId, Database db) async {
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

Future<List<Map<String, dynamic>>> getUserQuestionAnswerPairsByUser(String userUuid, Database db) async {
  await verifyUserQuestionAnswerPairTable(db);
  // Use universal query helper
  return await queryAndDecodeDatabase(
    'user_question_answer_pairs',
    db,
    where: 'user_uuid = ?',
    whereArgs: [userUuid],
  );
}

Future<List<Map<String, dynamic>>> getQuestionsInCirculation(String userUuid, Database db) async {
  await verifyUserQuestionAnswerPairTable(db);
  // Use universal query helper
  return await queryAndDecodeDatabase(
    'user_question_answer_pairs',
    db,
    where: 'user_uuid = ? AND in_circulation = ?',
    whereArgs: [userUuid, 1], // Query for in_circulation = 1 (true)
  );
}

Future<List<Map<String, dynamic>>> getAllUserQuestionAnswerPairs(Database db, String userUuid) async {
  await verifyUserQuestionAnswerPairTable(db);
  // Use universal query helper
  return await queryAndDecodeDatabase(
      'user_question_answer_pairs',
      db,
      where: 'user_uuid = ?',
      whereArgs: [userUuid]
  );
}

Future<int> removeUserQuestionAnswerPair(String userUuid, String questionAnswerReference, Database db) async {
  await verifyUserQuestionAnswerPairTable(db);

  return await db.delete(
    'user_question_answer_pairs',
    where: 'user_uuid = ? AND question_id = ?',
    whereArgs: [userUuid, questionAnswerReference],
  );
}

// --- Helper Functions ---

/// Increments the total_attempts count for a specific user-question pair.
Future<void> incrementTotalAttempts(String userUuid, String questionId, Database db) async {
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

// --- Set Circulation Status --- 

/// Updates the user-specific record for a question's circulation status.
/// Takes a boolean [isInCirculation] to set the status accordingly.
/// Throws an Exception if the record is not found, adhering to fail-fast.
Future<void> setCirculationStatus(
    String userUuid, String questionId, bool isInCirculation, Database db) async {
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

// Optional: Add a similar function to set inCirculation to false if needed later.
// Future<void> removeQuestionFromCirculation(...) async { ... inCirculation: false ... } // This comment is now redundant

// --- Get Unsynced Records ---

/// Fetches all user-question-answer pairs that need outbound synchronization.
/// This includes records that have never been synced (`has_been_synced = 0`)
/// or records that have local edits pending sync (`edits_are_synced = 0`).
/// Does NOT decode the records.
Future<List<Map<String, dynamic>>> getUnsyncedUserQuestionAnswerPairs(Database db) async {
  QuizzerLogger.logMessage('Fetching unsynced user-question-answer pairs...');
  // Ensure table and sync columns exist (verification is usually called by other functions,
  // but good to have if this is called independently)
  await verifyUserQuestionAnswerPairTable(db);

  // Use the universal query helper. Since we want raw, undecoded data for the sync worker,
  // we can use db.query directly or ensure queryAndDecodeDatabase can return raw if needed.
  // For now, assuming queryAndDecodeDatabase is acceptable or a raw query is preferred.
  // Sticking to queryAndDecodeDatabase for consistency if it handles raw data well,
  // otherwise, a direct db.query would be fine here.
  // Let's use db.query for clarity that we want raw data, as the QAP table does.
  final List<Map<String, dynamic>> results = await db.query(
    'user_question_answer_pairs',
    where: 'has_been_synced = 0 OR edits_are_synced = 0',
  );

  QuizzerLogger.logSuccess('Fetched ${results.length} unsynced user-question-answer pairs.');
  return results;
}