import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'dart:io'; // Ensure dart:io is imported
import 'package:uuid/uuid.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'table_helper.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
import 'package:path/path.dart' as path; // Import path package

// ==========================================
//          error_logs Table Helper
// ==========================================

const String _errorLogsTableName = 'error_logs';

// --- Private Helper Function to Read Log File ---
Future<String> _readLogFileContent() async {
  // Construct path platform-agnostically using path.join
  final String logFilePath = path.join('runtime_cache', 'quizzer_log.txt');
  
  final file = File(logFilePath);
  String content;
  // No try-catch for file operations, as per instruction.
  if (await file.exists()) {
    content = await file.readAsString();
    QuizzerLogger.logMessage('Successfully read content from $logFilePath.');
  } else {
    content = "Log file '$logFilePath' not found or unreadable."; // Keep the path in the message
    QuizzerLogger.logWarning('$logFilePath does not exist. Storing placeholder.');
  }
  return content;
}

/// Verifies the existence and schema of the error_logs table.
Future<void> verifyErrorLogsTable(Database db) async {
  QuizzerLogger.logMessage('Verifying $_errorLogsTableName table...');
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='$_errorLogsTableName'"
  );

  if (tables.isEmpty) {
    QuizzerLogger.logMessage('$_errorLogsTableName table not found, creating...');
    await db.execute('''
      CREATE TABLE $_errorLogsTableName (
        id TEXT PRIMARY KEY,                   
        created_at TEXT NOT NULL,              
        user_id TEXT,                          
        app_version TEXT,
        operating_system TEXT,
        error_message TEXT,
        log_file TEXT,
        user_feedback TEXT,
        is_resolved INTEGER DEFAULT 0,         
        -- Sync Fields --
        has_been_synced INTEGER DEFAULT 0,     
        edits_are_synced INTEGER DEFAULT 0,
        last_modified_timestamp TEXT           
      )
    ''');
    QuizzerLogger.logSuccess('$_errorLogsTableName table created successfully.');
  } else {
    QuizzerLogger.logMessage('$_errorLogsTableName table already exists. Checking columns...');
    final List<Map<String, dynamic>> columns = await db.rawQuery(
      "PRAGMA table_info($_errorLogsTableName)"
    );
    final Set<String> columnNames = columns.map((col) => col['name'] as String).toSet();

    const List<Map<String, String>> expectedColumns = [
      {'name': 'id', 'type': 'TEXT PRIMARY KEY'},
      {'name': 'created_at', 'type': 'TEXT NOT NULL'},
      {'name': 'user_id', 'type': 'TEXT'},
      {'name': 'app_version', 'type': 'TEXT'},
      {'name': 'operating_system', 'type': 'TEXT'},
      {'name': 'error_message', 'type': 'TEXT'},
      {'name': 'log_file', 'type': 'TEXT'},
      {'name': 'user_feedback', 'type': 'TEXT'},
      {'name': 'is_resolved', 'type': 'INTEGER DEFAULT 0'},
      {'name': 'has_been_synced', 'type': 'INTEGER DEFAULT 0'},
      {'name': 'edits_are_synced', 'type': 'INTEGER DEFAULT 0'},
      {'name': 'last_modified_timestamp', 'type': 'TEXT'},
    ];

    for (var colDef in expectedColumns) {
      if (!columnNames.contains(colDef['name']!)) {
        String addColumnSql = 'ALTER TABLE $_errorLogsTableName ADD COLUMN ${colDef['name']}';
        if (colDef['name'] == 'is_resolved' || colDef['name'] == 'has_been_synced' || colDef['name'] == 'edits_are_synced') {
          addColumnSql += ' INTEGER DEFAULT 0';
        } else {
          addColumnSql += ' TEXT'; 
        }
        QuizzerLogger.logWarning('Adding missing column to $_errorLogsTableName: ${colDef['name']}');
        await db.execute(addColumnSql);
      }
    }
    QuizzerLogger.logMessage('Column check complete for $_errorLogsTableName.');
  }
}

// --- Database Operations ---

/// Adds a new error log record to the local database for outbound syncing.
Future<String> addErrorLog({
  required Database db,
  String? userId,
  String? errorMessage,
  String? userFeedback,
}) async {
  await verifyErrorLogsTable(db);
  const uuid = Uuid();
  final String newId = uuid.v4();
  final String now = DateTime.now().toUtc().toIso8601String();

  // Fetch device information and app version programmatically
  final String deviceInfo = await getDeviceInfo(); 
  final String appVersionInfo = await getAppVersionInfo();

  // Call the internal helper to get log file content
  final String logFile = await _readLogFileContent();

  final Map<String, dynamic> logData = {
    'id': newId,
    'created_at': now,
    'user_id': userId,
    'app_version': appVersionInfo, // Use fetched app version
    'operating_system': deviceInfo, // Use fetched device info
    'error_message': errorMessage,
    'log_file': logFile,
    'user_feedback': userFeedback,
    'is_resolved': 0, 
    'has_been_synced': 0, 
    'edits_are_synced': 0, 
    'last_modified_timestamp': now, 
  };

  final int result = await insertRawData(
    _errorLogsTableName,
    logData,
    db,
    conflictAlgorithm: ConflictAlgorithm.fail, 
  );

  if (result <= 0) { 
    QuizzerLogger.logError('Failed to add error log to local database. Result: $result. Error Log ID: $newId');
    throw Exception('Failed to insert error log locally.');
  }
  
  QuizzerLogger.logSuccess('Successfully added error log with id: $newId. Log file content included.');
  final SwitchBoard switchBoard = getSwitchBoard();
  switchBoard.signalOutboundSyncNeeded(); 
  return newId;
}

/// Updates an existing error log record in the local database.
/// Can be used to add user_feedback or update other fields.
Future<int> updateErrorLog({
  required Database db,
  required String id,
  // Provide specific updatable fields as nullable parameters
  String? userFeedback,
  String? logFile, // For instance, if log file is appended or re-fetched
  bool? isResolved, // Though typically server-side, allow local update if needed for some flow
  bool? hasBeenSynced, // Allow explicit setting by sync worker if needed
  // Add other fields from the table that are legitimately updatable locally
}) async {
  await verifyErrorLogsTable(db);
  final String now = DateTime.now().toUtc().toIso8601String();

  final Map<String, dynamic> updates = {};

  if (userFeedback != null) updates['user_feedback'] = userFeedback;
  if (logFile != null) updates['log_file'] = logFile;
  if (isResolved != null) updates['is_resolved'] = isResolved ? 1 : 0;
  if (hasBeenSynced != null) updates['has_been_synced'] = hasBeenSynced ? 1 : 0;
  // Add other updatable fields here

  if (updates.isEmpty) {
    QuizzerLogger.logMessage('No updates provided for error log id: $id.');
    return 0;
  }

  updates['last_modified_timestamp'] = now;
  // If hasBeenSynced is being set to true, edits_are_synced should also be true (or 1).
  // Otherwise, any other update means there are local edits needing sync.
  if (hasBeenSynced == true) {
    updates['edits_are_synced'] = 1; // Edits are now considered synced because the record itself is.
  } else {
    updates['edits_are_synced'] = 0; // Mark that this record has local changes pending sync
  }

  final int rowsAffected = await updateRawData(
    _errorLogsTableName,
    updates,
    'id = ?',
    [id],
    db,
  );

  if (rowsAffected > 0) {
    QuizzerLogger.logSuccess('Successfully updated error log id: $id. Rows affected: $rowsAffected. Updates: $updates');
    // Only signal outbound sync if it wasn't an update to set hasBeenSynced to true
    // (which implies the sync worker is making the call and doesn't need re-signaling for the same data).
    if (hasBeenSynced != true) {
        final SwitchBoard switchBoard = getSwitchBoard();
        switchBoard.signalOutboundSyncNeeded();
    }
  } else {
    QuizzerLogger.logWarning('Failed to update error log id: $id or no changes made. Rows affected: $rowsAffected.');
  }
  return rowsAffected;
}

/// Upserts an error log: Inserts if no ID is provided or if ID doesn't exist,
/// otherwise updates the existing log with the given ID.
/// This acts as a routing function to either addErrorLog or updateErrorLog.
Future<String> upsertErrorLog({
  required Database db,
  String? id,
  String? userId,
  String? errorMessage,
  String? userFeedback,
}) async {
  await verifyErrorLogsTable(db);

  String currentId = id ?? const Uuid().v4();
  bool recordExists = false;

  if (id != null) {
    final List<Map<String, dynamic>> existingRecords = await db.query(
      _errorLogsTableName,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    recordExists = existingRecords.isNotEmpty;
  }

  if (recordExists) {
    QuizzerLogger.logMessage('upsertErrorLog: Updating existing error log with ID: $currentId for userFeedback.');
    await updateErrorLog(
      db: db,
      id: currentId,
      userFeedback: userFeedback,
    );
    return currentId;
  } else {
    QuizzerLogger.logMessage('upsertErrorLog: Adding new error log. Provided ID (if any): $id');
    final String newLogId = await addErrorLog(
      db: db,
      userId: userId,
      errorMessage: errorMessage,
      userFeedback: userFeedback,
    );
    return newLogId;
  }
}

/// Retrieves all error logs that need to be sent to the server.
/// Only returns records that are at least 1 hour old.
Future<List<Map<String, dynamic>>> getUnsyncedErrorLogs(Database db) async {
  await verifyErrorLogsTable(db);
  QuizzerLogger.logMessage('Fetching unsynced error logs (older than 1 hour) from $_errorLogsTableName...');
  
  // First, get all records that are marked as unsynced or have unsynced edits.
  final List<Map<String, dynamic>> allUnsyncedRecords = await queryAndDecodeDatabase(
    _errorLogsTableName,
    db,
    where: 'has_been_synced = 0 OR edits_are_synced = 0',
  );

  final List<Map<String, dynamic>> filteredRecords = [];
  final DateTime oneHourAgo = DateTime.now().toUtc().subtract(const Duration(hours: 1));

  for (final record in allUnsyncedRecords) {
    final String? createdAtString = record['created_at'] as String?;
    // Assert that createdAtString is not null because the schema defines it as NOT NULL.
    // If it were null, it indicates a data integrity issue or schema mismatch.
    assert(createdAtString != null, 'Error log record (ID: ${record['id']}) has null created_at, but schema expects NOT NULL.');
    
    final DateTime createdAtDateTime = DateTime.parse(createdAtString!); // Safe to use ! due to assertion

    if (createdAtDateTime.isBefore(oneHourAgo)) {
      filteredRecords.add(record);
    }
  }

  QuizzerLogger.logSuccess('Fetched ${allUnsyncedRecords.length} total unsynced records. ${filteredRecords.length} are older than 1 hour.');
  return filteredRecords;
}

/// Deletes an error log record from the local database by its ID.
/// This is typically used after an error log has been successfully synced and confirmed by the server,
/// or for local housekeeping if logs are not meant to be kept indefinitely.
Future<int> deleteLocalErrorLog(String id, Database db) async {
  await verifyErrorLogsTable(db);
  QuizzerLogger.logMessage('Deleting local error log with id: $id from $_errorLogsTableName');
  
  final int rowsDeleted = await db.delete(
    _errorLogsTableName,
    where: 'id = ?',
    whereArgs: [id],
  );

  if (rowsDeleted == 0) {
    QuizzerLogger.logWarning('No local error log found to delete with id: $id.');
  } else {
    QuizzerLogger.logSuccess('Deleted $rowsDeleted local error log(s) with id: $id.');
  }
  // No SwitchBoard signal needed for local deletion post-sync or housekeeping.
  return rowsDeleted;
}