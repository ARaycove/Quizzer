import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'table_helper.dart'; // Import the helper file
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart'; // Import sync signals
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
final List<Map<String, String>> expectedColumns = [
  // ===================================
  // Meta Data
  // ===================================
  // When was this entered?
  {'name': 'time_stamp',                'type': 'TEXT NOT NULL'},
  // What question was answered
  {'name': 'question_id',               'type': 'TEXT NOT NULL'},
  // The uuid of the user in question
  {'name': 'participant_id',            'type': 'TEXT NOT NULL'},
  // ===================================
  // Question_Metrics (not performance related, what is the question?)
  // ===================================
  {'name': "question_vector",           'type': 'TEXT NOT NULL'}, // What does the transformer say?
  {'name': "module_name",               'type': 'TEXT NOT NULL'}, // Which module is this question in?
  {'name': "question_type",             'type': 'TEXT NOT NULL'}, // What is the question type?
  {'name': "num_mcq_options",           'type': 'INTEGER NULL DEFAULT 0'}, // How many mcq options does this have (should be 0 if the type is not mcq)
  {'name': "num_so_options",            'type': 'INTEGER NULL DEFAULT 0'},
  {'name': "num_sata_options",          'type': 'INTEGER NULL DEFAULT 0'},
  {'name': "num_blanks",                'type': 'INTEGER NULL DEFAULT 0'},
  // ===================================
  // Individual Question Performance
  // ===================================
  {'name': 'avg_react_time',             'type': 'REAL NOT NULL'}, // FIXME
  {'name': 'response_result',           'type': 'INTEGER NOT NULL'}, // Did the user get this question correct after presentation 0 or 1
  {'name': 'was_first_attempt',         'type': 'INTEGER NOT NULL'}, // At time of presentation, had user attempted this before? 0 or 1
  {'name': 'total_correct_attempts',    'type': 'INTEGER NOT NULL'},
  {'name': 'total_incorrect_attempts',  'type': 'INTEGER NOT NULL'},
  {'name': 'total_attempts',            'type': 'INTEGER NOT NULL'},
  {'name': 'accuracy_rate',             'type': 'REAL NOT NULL'},
  {'name': 'revision_streak',           'type': 'INTEGER NOT NULL'},

  // Temporal metrics
  {'name': 'time_of_presentation',      'type': 'TEXT NULL'},
  {'name': 'last_revised_date',         'type': 'TEXT NULL'},
  {'name': 'days_since_last_revision',  'type': 'REAL NULL'},
  {'name': 'days_since_first_introduced','type':'REAL NULL'},
  {'name': 'attempt_day_ratio',         'type': 'REAL NULL'}, // total_attempts/days_since_introduced
  

  // User Stats metrics Vector
  // The current state of global statistics at time of answer, array of maps
  {'name': 'user_stats_vector',         'type': 'TEXT'},
  // User Modules Metrics Vector
  // Array of Maps, that contains the user's performance metric for every module in their profile:
  {'name': 'module_performance_vector',        'type': 'TEXT NULL'},
  // User Profile at time of presentation -> Vector (Fixed)
  {'name': 'user_profile_record',              'type': 'TEXT NULL'},
  // Sync tracking metrics
  {'name': 'has_been_synced',           'type': 'INTEGER DEFAULT 0'},
  {'name': 'edits_are_synced',          'type': 'INTEGER DEFAULT 0'},
  {'name': 'last_modified_timestamp',   'type': 'TEXT'},
];

/// Verifies the existence and schema of the question_answer_attempts table.
Future<void> verifyQuestionAnswerAttemptTable(dynamic db) async {
  try {
    QuizzerLogger.logMessage('Verifying question_answer_attempts table existence');
    
    // Check if the table exists
    final List<Map<String, dynamic>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      ['question_answer_attempts']
    );

    if (tables.isEmpty) {
      // Create the table if it doesn't exist
      QuizzerLogger.logMessage('question_answer_attempts table not found, creating...');
      
      String createTableSQL = 'CREATE TABLE question_answer_attempts(\n';
      createTableSQL += expectedColumns.map((col) => '  ${col['name']} ${col['type']}').join(',\n');
      createTableSQL += ',\n  PRIMARY KEY (participant_id, question_id, time_stamp)\n)';
      
      await db.execute(createTableSQL);
      QuizzerLogger.logSuccess('question_answer_attempts table created successfully.');
    } else {
      // Table exists, check for column differences
      QuizzerLogger.logMessage('question_answer_attempts table already exists. Checking column structure...');
      
      // Get current table structure
      final List<Map<String, dynamic>> currentColumns = await db.rawQuery(
        "PRAGMA table_info(question_answer_attempts)"
      );
      
      final Set<String> currentColumnNames = currentColumns
          .map((column) => column['name'] as String)
          .toSet();
      
      final Set<String> expectedColumnNames = expectedColumns
          .map((column) => column['name']!)
          .toSet();
      
      // Find columns to add (expected but not current)
      final Set<String> columnsToAdd = expectedColumnNames.difference(currentColumnNames);
      
      // Find columns to remove (current but not expected)
      final Set<String> columnsToRemove = currentColumnNames.difference(expectedColumnNames);
      
      // Add missing columns
      for (String columnName in columnsToAdd) {
        final columnDef = expectedColumns.firstWhere((col) => col['name'] == columnName);
        QuizzerLogger.logMessage('Adding missing column: $columnName');
        await db.execute('ALTER TABLE question_answer_attempts ADD COLUMN ${columnDef['name']} ${columnDef['type']}');
      }
      
      // Remove unexpected columns (SQLite doesn't support DROP COLUMN directly)
      if (columnsToRemove.isNotEmpty) {
        QuizzerLogger.logMessage('Removing unexpected columns: ${columnsToRemove.join(', ')}');
        
        // Create temporary table with only expected columns
        String tempTableSQL = 'CREATE TABLE question_answer_attempts_temp(\n';
        tempTableSQL += expectedColumns.map((col) => '  ${col['name']} ${col['type']}').join(',\n');
        tempTableSQL += ',\n  PRIMARY KEY (participant_id, question_id, time_stamp)\n)';
        
        await db.execute(tempTableSQL);
        
        // Copy data from old table to temp table (only expected columns)
        String columnList = expectedColumnNames.join(', ');
        await db.execute('INSERT INTO question_answer_attempts_temp ($columnList) SELECT $columnList FROM question_answer_attempts');
        
        // Drop old table and rename temp table
        await db.execute('DROP TABLE question_answer_attempts');
        await db.execute('ALTER TABLE question_answer_attempts_temp RENAME TO question_answer_attempts');
        
        QuizzerLogger.logSuccess('Removed unexpected columns and restructured table');
      }
      
      if (columnsToAdd.isEmpty && columnsToRemove.isEmpty) {
        QuizzerLogger.logMessage('Table structure is already up to date');
      } else {
        QuizzerLogger.logSuccess('Table structure updated successfully');
      }
    }
  } catch (e) {
    QuizzerLogger.logError('Error verifying question_answer_attempts table - $e');
    rethrow;
  }
}

// --- Public Database Operations ---

/// Adds a new question answer attempt record to the database.
/// Accepts any dynamic field data and validates against the schema.
/// Logs warnings for any fields that don't exist in the expected schema.
Future<int> addQuestionAnswerAttempt({
  required String participantId,
  required String questionId, 
  required String timeStamp,
  Map<String, dynamic>? additionalFields,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Adding question attempt for Q: $questionId, User: $participantId');
    
    // Create set of valid column names for validation
    final Set<String> validColumnNames = expectedColumns
        .map((col) => col['name']!)
        .toSet();
    
    // Start with primary key fields
    final Map<String, dynamic> attemptData = {
      'participant_id': participantId,
      'question_id': questionId,
      'time_stamp': timeStamp,
    };
    
    // Process additional fields if provided
    if (additionalFields != null) {
      for (final entry in additionalFields.entries) {
        final String fieldName = entry.key;
        final dynamic fieldValue = entry.value;
        
        // Validate field exists in schema
        if (validColumnNames.contains(fieldName)) {
          attemptData[fieldName] = fieldValue;
        } else {
          // Log warning for invalid field names
          QuizzerLogger.logWarning('Attempted to insert invalid field "$fieldName" with value "$fieldValue" into question_answer_attempts table. Field not found in expected schema. Skipping field.');
        }
      }
    }

    QuizzerLogger.logMessage('Prepared attempt data with ${attemptData.length} fields: ${attemptData.keys.join(', ')}');

    // Use the universal insert helper
    final int resultId = await insertRawData(
      'question_answer_attempts',
      attemptData,
      db,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    if (resultId > 0) {
      QuizzerLogger.logSuccess('Successfully added question attempt record with result ID: $resultId for Q: $questionId, User: $participantId');
      // Signal the SwitchBoard that new data might need syncing
      signalOutboundSyncNeeded();
    } else {
      QuizzerLogger.logWarning('Insert operation for attempt (Q: $questionId, User: $participantId) returned $resultId. Might be ignored duplicate.');
    }
    return resultId;
  } catch (e) {
    QuizzerLogger.logError('Error adding question answer attempt - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Deletes a question answer attempt record by its composite primary key.
Future<int> deleteQuestionAnswerAttemptRecord(String participantId, String questionId, String timeStamp) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Deleting question answer attempt (PID: $participantId, QID: $questionId, TS: $timeStamp)');
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
  } catch (e) {
    QuizzerLogger.logError('Error deleting question answer attempt record - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// --- Optional Getter Functions ---

/// Retrieves all attempts for a specific question by a specific user.
Future<List<Map<String, dynamic>>> getAttemptsByQuestionAndUser(String questionId, String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching attempts for Q: $questionId, User: $userId');
    // Use the universal query helper
    return await queryAndDecodeDatabase(
      'question_answer_attempts',
      db,
      where: 'participant_id = ? AND question_id = ?',
      whereArgs: [userId, questionId],
      orderBy: 'time_stamp DESC', // Order by most recent first
    );
  } catch (e) {
    QuizzerLogger.logError('Error getting attempts by question and user - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Retrieves all attempts made by a specific user.
Future<List<Map<String, dynamic>>> getAttemptsByUser(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching all attempts for User: $userId');
    // Use the universal query helper
    return await queryAndDecodeDatabase(
      'question_answer_attempts',
      db,
      where: 'participant_id = ?',
      whereArgs: [userId],
      orderBy: 'time_stamp DESC', // Order by most recent first
    );
  } catch (e) {
    QuizzerLogger.logError('Error getting attempts by user - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// --- Get Unsynced Records ---

/// Fetches all question answer attempts that need outbound synchronization.
/// This includes records that have never been synced (`has_been_synced = 0`)
/// or records that have local edits pending sync (`edits_are_synced = 0`).
/// Does NOT decode the records.
Future<List<Map<String, dynamic>>> getUnsyncedQuestionAnswerAttempts() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching unsynced question answer attempts...');
    final List<Map<String, dynamic>> results = await db.query(
      'question_answer_attempts',
      where: 'has_been_synced = 0 OR edits_are_synced = 0',
    );

    QuizzerLogger.logSuccess('Fetched ${results.length} unsynced question answer attempts.');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced question answer attempts - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}
