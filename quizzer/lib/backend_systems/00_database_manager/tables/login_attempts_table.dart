import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

import 'table_helper.dart'; // Import the helper file
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart'; // Import sync signals
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';

Future<bool> _doesLoginAttemptsTableExist(Database db) async {
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='login_attempts'"
  );
  return tables.isNotEmpty;
}

/// Verifies that all necessary columns, including sync fields, exist in the login_attempts table.
/// Adds missing columns if the table exists but is missing them.
Future<void> _verifyLoginAttemptsTableFields(Database db) async {
  if (!await _doesLoginAttemptsTableExist(db)) {
    // Table doesn't exist, so createLoginAttemptsTable will handle the full schema.
    await _createLoginAttemptsTable(db);
    return;
  }

  // Table exists, check for specific columns.
  final List<Map<String, dynamic>> columns = await db.rawQuery(
    "PRAGMA table_info(login_attempts)"
  );
  
  final Set<String> columnNames = columns.map((column) => column['name'] as String).toSet();

  if (!columnNames.contains('has_been_synced')) {
    QuizzerLogger.logMessage('Adding has_been_synced column to login_attempts table.');
    await db.execute('ALTER TABLE login_attempts ADD COLUMN has_been_synced INTEGER DEFAULT 0');
  }
  if (!columnNames.contains('edits_are_synced')) {
    QuizzerLogger.logMessage('Adding edits_are_synced column to login_attempts table.');
    await db.execute('ALTER TABLE login_attempts ADD COLUMN edits_are_synced INTEGER DEFAULT 0');
  }
  if (!columnNames.contains('last_modified_timestamp')) {
    QuizzerLogger.logMessage('Adding last_modified_timestamp column to login_attempts table.');
    await db.execute('ALTER TABLE login_attempts ADD COLUMN last_modified_timestamp TEXT');
  }
}

Future<void> _createLoginAttemptsTable(Database db) async {
  await db.execute('''
  CREATE TABLE login_attempts(
    login_attempt_id TEXT PRIMARY KEY,
    user_id TEXT,
    email TEXT NOT NULL,
    timestamp TEXT NOT NULL,
    status_code TEXT NOT NULL,
    ip_address TEXT,
    device_info TEXT,
    has_been_synced INTEGER DEFAULT 0,
    edits_are_synced INTEGER DEFAULT 0,
    last_modified_timestamp TEXT,
    FOREIGN KEY (user_id) REFERENCES user_profile(uuid)
  )
  ''');
}

Future<bool> addLoginAttemptRecord({
  required String email,
  required String statusCode,
}) async {
  try {
    String? userId;
    try {
      userId = await getUserIdByEmail(email);
    } on StateError catch (e) {
      if (e.message == "INVALID, NO USERID WITH THAT EMAIL. . .") {
        QuizzerLogger.logWarning('Failed to record login attempt for email "$email": User email not found in local user_profile table. No login attempt will be recorded.');
        return false; // Indicate failure to record, do not proceed to insert.
      } else {
        // For any other StateError, rethrow as it's unexpected.
        QuizzerLogger.logError('Unexpected StateError while getting user ID for login attempt: $e');
        rethrow;
      }
    } catch (e) {
      // Catch any other unexpected error during getUserIdByEmail
      QuizzerLogger.logError('Unexpected error while getting user ID for login attempt: $e');
      rethrow; // Fail fast for other errors
    }
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }


    // If we reach here, userId was successfully retrieved.
    await _verifyLoginAttemptsTableFields(db); 
    
    String ipAddress = await getUserIpAddress();
    String deviceInfo = await getDeviceInfo();
    
    // Current timestamp in ISO 8601 format
    final String timestamp = DateTime.now().toUtc().toIso8601String();
    final String loginAttemptId = timestamp + userId;
    
    // Prepare the raw data map
    final Map<String, dynamic> data = {
      'login_attempt_id': loginAttemptId,
      'user_id': userId, // Can be null if getUserIdByEmail returns invalid
      'email': email,
      'timestamp': timestamp,
      'status_code': statusCode,
      'ip_address': ipAddress,
      'device_info': deviceInfo,
      'has_been_synced': 0,
      'edits_are_synced': 0,
      'last_modified_timestamp': timestamp,
    };

    // Use the universal insert helper
    final int result = await insertRawData('login_attempts', data, db);

    if (result > 0) {
      QuizzerLogger.logMessage('Login attempt recorded successfully: $loginAttemptId');
      // Signal the SwitchBoard that new data might need syncing
      signalOutboundSyncNeeded();
      return true;
    } else {
      // Log a warning if insert returned 0 (should not happen without conflict algorithm)
      QuizzerLogger.logWarning('Insert operation for login attempt $loginAttemptId returned 0. This is unexpected.');
      return false; // Indicate potential failure
    }
  } catch (e) {
    QuizzerLogger.logError('Error adding login attempt record - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Fetches all login attempts that need outbound synchronization.
/// This includes records that have never been synced (`has_been_synced = 0`)
/// or records that have local edits pending sync (`edits_are_synced = 0`).
/// Login attempts are not typically edited, so `edits_are_synced` might always be 0 or 1 after initial sync.
/// Does NOT decode the records.
Future<List<Map<String, dynamic>>> getUnsyncedLoginAttempts() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching unsynced login attempts...');
    await _verifyLoginAttemptsTableFields(db); // Ensure table and sync columns exist

    final List<Map<String, dynamic>> results = await db.query(
      'login_attempts',
      where: 'has_been_synced = 0 OR edits_are_synced = 0', // Though edits_are_synced might be less relevant here
    );

    QuizzerLogger.logSuccess('Fetched ${results.length} unsynced login attempts.');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced login attempts - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// --- Delete Record ---

/// Gets login attempts for a specific user by email
/// Returns a list of login attempt records for the given email
Future<List<Map<String, dynamic>>> getLoginAttemptsByEmail(String email) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching login attempts for email: $email');
    await _verifyLoginAttemptsTableFields(db);

    final List<Map<String, dynamic>> results = await db.query(
      'login_attempts',
      where: 'email = ?',
      whereArgs: [email],
      orderBy: 'timestamp DESC', // Most recent first
    );

    QuizzerLogger.logSuccess('Fetched ${results.length} login attempts for email: $email');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting login attempts for email: $email - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Deletes a specific login attempt record from the local database.
Future<int> deleteLoginAttemptRecord(String loginAttemptId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Deleting local login attempt record: $loginAttemptId');
    // Remove try-catch, let errors propagate (Fail Fast for local DB ops)
    final int count = await db.delete(
      'login_attempts',
      where: 'login_attempt_id = ?',
      whereArgs: [loginAttemptId],
    );
    if (count == 0) {
      QuizzerLogger.logWarning('Attempted to delete login attempt $loginAttemptId, but no record was found.');
    } else {
      QuizzerLogger.logSuccess('Successfully deleted local login attempt $loginAttemptId.');
    }
    return count;
  } catch (e) {
    QuizzerLogger.logError('Error deleting login attempt record - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}