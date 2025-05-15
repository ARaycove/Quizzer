import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'table_helper.dart'; // Import the helper file
import 'package:quizzer/backend_systems/12_switch_board/switch_board.dart'; // Import SwitchBoard
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart'; // Use package import for user_question_answer_pairs_table

/// Verifies the existence and schema of the question_answer_attempts table.
Future<void> verifyQuestionAnswerAttemptTable(Database db) async {
  QuizzerLogger.logMessage('Verifying question_answer_attempts table...');
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='question_answer_attempts'"
  );

  if (tables.isEmpty) {
    QuizzerLogger.logMessage('question_answer_attempts table not found, creating...');
    await db.execute('''
      CREATE TABLE question_answer_attempts (
        time_stamp TEXT NOT NULL,            -- ISO8601 DateTime string
        question_id TEXT NOT NULL,           
        participant_id TEXT NOT NULL,        -- user_uuid
        response_time REAL NOT NULL,         -- time in seconds (double)
        response_result INTEGER NOT NULL,    -- Accuracy rating (0=incorrect, 1=correct)
        was_first_attempt INTEGER NOT NULL,  -- 0 for false, 1 for true
        knowledge_base REAL NULL,            -- Calculation result (double), nullable
        question_context_csv TEXT NOT NULL,  -- JSON {subject: list, concept, list}
        last_revised_date TEXT NULL,         -- Timestamp of last revision (nullable)
        days_since_last_revision REAL NULL,  -- Calculated days since last revision (nullable)
        total_attempts INTEGER NOT NULL,     -- Renamed: Count of previous attempts + 1 (i.e., attempt number)
        revision_streak INTEGER NOT NULL,    -- Renamed: Streak *before* this attempt
        -- Sync Fields --
        has_been_synced INTEGER DEFAULT 0,
        edits_are_synced INTEGER DEFAULT 0,
        last_modified_timestamp TEXT,        -- Store as ISO8601 UTC string
        -- ------------- --
        PRIMARY KEY (participant_id, question_id, time_stamp) 
      )
    ''');
    QuizzerLogger.logSuccess('question_answer_attempts table created successfully.');
  } else {
    QuizzerLogger.logMessage('question_answer_attempts table already exists. Checking columns...');
    // Check for new columns and add if missing
    final List<Map<String, dynamic>> columns = await db.rawQuery(
      "PRAGMA table_info(question_answer_attempts)"
    );
    final Set<String> columnNames = columns.map((col) => col['name'] as String).toSet();

    // Check for potentially renamed/new columns
    if (!columnNames.contains('last_revised_date')) {
      QuizzerLogger.logWarning('Adding missing column: last_revised_date');
      await db.execute("ALTER TABLE question_answer_attempts ADD COLUMN last_revised_date TEXT NULL");
    }
    if (!columnNames.contains('days_since_last_revision')) {
      QuizzerLogger.logWarning('Adding missing column: days_since_last_revision');
      await db.execute("ALTER TABLE question_answer_attempts ADD COLUMN days_since_last_revision REAL NULL");
    }
    if (!columnNames.contains('total_attempts')) {
      QuizzerLogger.logWarning('Adding missing column: total_attempts (renamed from total_attempts_before)');
      // Add with default 0 for existing rows - Adjust default if needed
      await db.execute("ALTER TABLE question_answer_attempts ADD COLUMN total_attempts INTEGER NOT NULL DEFAULT 1"); 
    }
    if (!columnNames.contains('revision_streak')) {
       QuizzerLogger.logWarning('Adding missing column: revision_streak (renamed from revision_streak_before)');
      // Add with default 0 for existing rows
      await db.execute("ALTER TABLE question_answer_attempts ADD COLUMN revision_streak INTEGER NOT NULL DEFAULT 0");
    }

    // Add checks for new sync columns
    if (!columnNames.contains('has_been_synced')) {
      QuizzerLogger.logMessage('Adding has_been_synced column to question_answer_attempts table.');
      await db.execute('ALTER TABLE question_answer_attempts ADD COLUMN has_been_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('edits_are_synced')) {
      QuizzerLogger.logMessage('Adding edits_are_synced column to question_answer_attempts table.');
      await db.execute('ALTER TABLE question_answer_attempts ADD COLUMN edits_are_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('last_modified_timestamp')) {
      QuizzerLogger.logMessage('Adding last_modified_timestamp column to question_answer_attempts table.');
      await db.execute('ALTER TABLE question_answer_attempts ADD COLUMN last_modified_timestamp TEXT');
    }

    QuizzerLogger.logMessage('Column check complete.');
  }
}

// --- Private Helper Functions ---

/// Checks if this is the first attempt for a given user and question.
Future<bool> _checkWasFirstAttempt(String questionId, String userId, Database db) async {
  QuizzerLogger.logMessage('Checking if first attempt for Q: $questionId, User: $userId');
  // Get the user-question pair record to check total_attempts
  final Map<String, dynamic> pairRecord = await getUserQuestionAnswerPairById(userId, questionId, db);
  final int totalAttempts = pairRecord['total_attempts'] as int;
  final bool isFirst = totalAttempts == 0;
  QuizzerLogger.logMessage('Is first attempt? $isFirst (total_attempts: $totalAttempts)');
  return isFirst;
}

// --- Public Database Operations ---

/// Adds a new question answer attempt record to the database.
/// Calculates `was_first_attempt` automatically.
Future<int> addQuestionAnswerAttempt({
  required String timeStamp,          // Should be DateTime.now().toIso8601String()
  required String questionId,         
  required String participantId,      
  required double responseTime,       
  required int responseResult,       // Accuracy rating (0=incorrect, 1=correct)
  required String questionContextCsv, // NOTE: Schema expects TEXT, ensure input is string/JSON
  required int totalAttempts,        // Renamed: Total attempts *before* this one
  required int revisionStreak,       // Renamed: Streak *before* this attempt
  String? lastRevisedDate,           // Nullable timestamp of last revision
  double? daysSinceLastRevision,   // New: Nullable calculated days
  double? knowledgeBase,             
  required Database db,
}) async {
  await verifyQuestionAnswerAttemptTable(db);

  final bool wasFirstAttempt = await _checkWasFirstAttempt(questionId, participantId, db);

  QuizzerLogger.logMessage('Adding question attempt for Q: $questionId, User: $participantId');
  
  // Prepare the raw data map
  final Map<String, dynamic> attemptData = {
    'time_stamp': timeStamp,
    'question_id': questionId,
    'participant_id': participantId,
    'response_time': responseTime,
    'response_result': responseResult, 
    'was_first_attempt': wasFirstAttempt, // Pass bool, helper encodes to 1/0
    'knowledge_base': knowledgeBase,
    'question_context_csv': questionContextCsv, // Expecting String/JSON based on schema comment
    'last_revised_date': lastRevisedDate, 
    'days_since_last_revision': daysSinceLastRevision,
    'total_attempts': totalAttempts,
    'revision_streak': revisionStreak,
    // Add sync fields
    'has_been_synced': 0,
    'edits_are_synced': 0,
    'last_modified_timestamp': timeStamp, // Use creation timestamp for initial last_modified
  };

  // Use the universal insert helper
  final int resultId = await insertRawData(
    'question_answer_attempts',
    attemptData,
    db,
    conflictAlgorithm: ConflictAlgorithm.ignore, // Or .fail if duplicates are critical errors
  );

  if (resultId > 0) {
    QuizzerLogger.logSuccess('Successfully added question attempt record with result ID: $resultId. Data: $attemptData');
    // Signal the SwitchBoard that new data might need syncing
    final SwitchBoard switchBoard = getSwitchBoard(); // Get SwitchBoard instance
    switchBoard.signalOutboundSyncNeeded();
  } else {
    QuizzerLogger.logWarning('Insert operation for attempt (Q: $questionId, User: $participantId, Time: $timeStamp) returned $resultId. Might be ignored duplicate.');
  }
  return resultId;
}

/// Deletes a question answer attempt record by its composite primary key.
Future<int> deleteQuestionAnswerAttemptRecord(String participantId, String questionId, String timeStamp, Database db) async {
  QuizzerLogger.logMessage('Deleting question answer attempt (PID: $participantId, QID: $questionId, TS: $timeStamp)');
  await verifyQuestionAnswerAttemptTable(db);
  final int rowsDeleted = await db.delete(
    'question_answer_attempts',
    where: 'participant_id = ? AND question_id = ? AND time_stamp = ?',
    whereArgs: [participantId, questionId, timeStamp],
  );
  if (rowsDeleted == 0) {
    QuizzerLogger.logWarning('No question answer attempt found to delete for (PID: $participantId, QID: $questionId, TS: $timeStamp)');
  } else {
    QuizzerLogger.logSuccess('Deleted $rowsDeleted question answer attempt(s) for (PID: $participantId, QID: $questionId, TS: $timeStamp)');
  }
  return rowsDeleted;
}

// --- Optional Getter Functions ---

/// Retrieves all attempts for a specific question by a specific user.
Future<List<Map<String, dynamic>>> getAttemptsByQuestionAndUser(String questionId, String userId, Database db) async {
  await verifyQuestionAnswerAttemptTable(db);
  QuizzerLogger.logMessage('Fetching attempts for Q: $questionId, User: $userId');
  // Use the universal query helper
  return await queryAndDecodeDatabase(
    'question_answer_attempts',
    db,
    where: 'participant_id = ? AND question_id = ?',
    whereArgs: [userId, questionId],
    orderBy: 'time_stamp DESC', // Order by most recent first
  );
}

/// Retrieves all attempts made by a specific user.
Future<List<Map<String, dynamic>>> getAttemptsByUser(String userId, Database db) async {
  await verifyQuestionAnswerAttemptTable(db);
  QuizzerLogger.logMessage('Fetching all attempts for User: $userId');
  // Use the universal query helper
  return await queryAndDecodeDatabase(
    'question_answer_attempts',
    db,
    where: 'participant_id = ?',
    whereArgs: [userId],
    orderBy: 'time_stamp DESC', // Order by most recent first
  );
}

// --- Get Unsynced Records ---

/// Fetches all question answer attempts that need outbound synchronization.
/// This includes records that have never been synced (`has_been_synced = 0`)
/// or records that have local edits pending sync (`edits_are_synced = 0`).
/// Does NOT decode the records.
Future<List<Map<String, dynamic>>> getUnsyncedQuestionAnswerAttempts(Database db) async {
  QuizzerLogger.logMessage('Fetching unsynced question answer attempts...');
  await verifyQuestionAnswerAttemptTable(db); // Ensure table and sync columns exist

  final List<Map<String, dynamic>> results = await db.query(
    'question_answer_attempts',
    where: 'has_been_synced = 0 OR edits_are_synced = 0',
  );

  QuizzerLogger.logSuccess('Fetched ${results.length} unsynced question answer attempts.');
  return results;
}
