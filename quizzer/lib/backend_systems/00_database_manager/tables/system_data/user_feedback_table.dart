import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import '../table_helper.dart'; // For getDeviceInfo, getAppVersionInfo, insertRawData etc.
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';

// ==========================================
//          user_feedback Table Helper
// ==========================================

const String _userFeedbackTableName = 'user_feedback';

/// Verifies the existence and schema of the user_feedback table.
Future<void> _verifyUserFeedbackTable(Database db) async {
  QuizzerLogger.logMessage('Verifying $_userFeedbackTableName table...');
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='$_userFeedbackTableName'"
  );

  if (tables.isEmpty) {
    QuizzerLogger.logMessage('$_userFeedbackTableName table not found, creating...');
    await db.execute('''
      CREATE TABLE $_userFeedbackTableName (
        id TEXT PRIMARY KEY,
        creation_date TEXT NOT NULL,
        user_id TEXT,
        feedback_type TEXT,
        feedback_content TEXT,
        app_version TEXT,
        operating_system TEXT,
        is_addressed INTEGER DEFAULT 0,
        -- Sync Fields --
        has_been_synced INTEGER DEFAULT 0,
        edits_are_synced INTEGER DEFAULT 0, 
        last_modified_timestamp TEXT
      )
    ''');
    QuizzerLogger.logSuccess('$_userFeedbackTableName table created successfully.');
  } else {
    QuizzerLogger.logMessage('$_userFeedbackTableName table already exists. Checking columns...');
    final List<Map<String, dynamic>> columns = await db.rawQuery(
      "PRAGMA table_info($_userFeedbackTableName)"
    );
    final Set<String> columnNames = columns.map((col) => col['name'] as String).toSet();

    const List<Map<String, String>> expectedColumns = [
      {'name': 'id', 'type': 'TEXT PRIMARY KEY'},
      {'name': 'creation_date', 'type': 'TEXT NOT NULL'},
      {'name': 'user_id', 'type': 'TEXT'},
      {'name': 'feedback_type', 'type': 'TEXT'},
      {'name': 'feedback_content', 'type': 'TEXT'},
      {'name': 'app_version', 'type': 'TEXT'},
      {'name': 'operating_system', 'type': 'TEXT'},
      {'name': 'is_addressed', 'type': 'INTEGER DEFAULT 0'},
      {'name': 'has_been_synced', 'type': 'INTEGER DEFAULT 0'},
      {'name': 'edits_are_synced', 'type': 'INTEGER DEFAULT 0'},
      {'name': 'last_modified_timestamp', 'type': 'TEXT'},
    ];

    for (var colDef in expectedColumns) {
      if (!columnNames.contains(colDef['name']!)) {
        String addColumnSql = 'ALTER TABLE $_userFeedbackTableName ADD COLUMN ${colDef['name']}';
        // Set default for new boolean-like integer columns
        if (colDef['name'] == 'is_addressed' || colDef['name'] == 'has_been_synced' || colDef['name'] == 'edits_are_synced') {
          addColumnSql += ' INTEGER DEFAULT 0';
        } else {
          addColumnSql += ' TEXT'; // Default to TEXT for other new columns
        }
        QuizzerLogger.logWarning('Adding missing column to $_userFeedbackTableName: ${colDef['name']}');
        await db.execute(addColumnSql);
      }
    }
    QuizzerLogger.logMessage('Column check complete for $_userFeedbackTableName.');
  }
}

// --- Database Operations ---

/// Adds a new feedback record to the local database for outbound syncing.
Future<String> addUserFeedback({
  String? userId,
  required String feedbackType,
  required String feedbackContent,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await _verifyUserFeedbackTable(db); // Ensure table exists and is correct
    const uuid = Uuid();
    final String newId = uuid.v4();
    final String now = DateTime.now().toUtc().toIso8601String();

    final String deviceInfo = await getDeviceInfo();
    final String appVersionInfo = await getAppVersionInfo();

    final Map<String, dynamic> feedbackData = {
      'id': newId,
      'creation_date': now,
      'user_id': userId,
      'feedback_type': feedbackType,
      'feedback_content': feedbackContent,
      'app_version': appVersionInfo,
      'operating_system': deviceInfo,
      'is_addressed': 0,
      'has_been_synced': 0,
      'edits_are_synced': 0,
      'last_modified_timestamp': now,
    };

    final int result = await insertRawData(
      _userFeedbackTableName,
      feedbackData,
      db,
      conflictAlgorithm: ConflictAlgorithm.fail,
    );

    if (result <= 0) {
      QuizzerLogger.logError('Failed to add user feedback to local database. Result: $result. Feedback ID: $newId');
      throw Exception('Failed to insert user feedback locally.');
    }

    QuizzerLogger.logSuccess('Successfully added user feedback with id: $newId.');
    signalOutboundSyncNeeded(); // Signal that new data is available for sync
    return newId;
  } catch (e) {
    QuizzerLogger.logError('Error adding user feedback - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Retrieves all user feedback records that need to be sent to the server.
Future<List<Map<String, dynamic>>> getUnsyncedUserFeedback() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await _verifyUserFeedbackTable(db);
    QuizzerLogger.logMessage('Fetching unsynced user feedback from $_userFeedbackTableName...');
    
    // Fetch records where has_been_synced is 0 (false)
    final List<Map<String, dynamic>> unsyncedFeedback = await queryAndDecodeDatabase(
      _userFeedbackTableName,
      db,
      where: 'has_been_synced = 0', 
    );

    QuizzerLogger.logSuccess('Fetched ${unsyncedFeedback.length} unsynced user feedback records.');
    return unsyncedFeedback;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced user feedback - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Marks a list of feedback records as synced in the local database.
Future<void> markUserFeedbackAsSynced(List<String> ids) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    if (ids.isEmpty) {
      QuizzerLogger.logMessage('No feedback IDs provided to mark as synced.');
      return;
    }
    await _verifyUserFeedbackTable(db);
    final String now = DateTime.now().toUtc().toIso8601String();
    
    // Create a String of placeholders for the IN clause
    final String placeholders = List.filled(ids.length, '?').join(',');
    
    final updates = {
      'has_been_synced': 1,
      'edits_are_synced': 1, // Since the original record is now synced, any "edits" are also synced
      'last_modified_timestamp': now,
    };

    final int rowsAffected = await updateRawData(
      _userFeedbackTableName,
      updates,
      'id IN ($placeholders)', // Use IN clause for multiple IDs
      ids, // Pass the list of IDs as arguments
      db,
    );

    QuizzerLogger.logSuccess('Marked $rowsAffected user feedback records as synced.');
  } catch (e) {
    QuizzerLogger.logError('Error marking user feedback as synced - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Deletes user feedback records from the local database by their IDs.
/// Typically used after successful sync and confirmation from the server.
Future<int> deleteLocalUserFeedback(List<String> ids) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    if (ids.isEmpty) {
      QuizzerLogger.logMessage('No feedback IDs provided for deletion.');
      return 0;
    }
    await _verifyUserFeedbackTable(db);
    
    final String placeholders = List.filled(ids.length, '?').join(',');
    final int rowsDeleted = await db.delete(
      _userFeedbackTableName,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );

    if (rowsDeleted == 0) {
      QuizzerLogger.logWarning('No local user feedback found to delete with provided IDs.');
    } else {
      QuizzerLogger.logSuccess('Deleted $rowsDeleted local user feedback record(s).');
    }
    return rowsDeleted;
  } catch (e) {
    QuizzerLogger.logError('Error deleting local user feedback - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}
