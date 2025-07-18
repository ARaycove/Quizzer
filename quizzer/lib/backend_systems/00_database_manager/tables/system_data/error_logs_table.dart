import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'dart:io'; // Ensure dart:io is imported
import 'package:uuid/uuid.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:path/path.dart' as path; // Import path package
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';

// ==========================================
//          error_logs Table Helper
// ==========================================

const String _errorLogsTableName = 'error_logs';

// --- Private Helper Function to Read Log File ---
Future<String> _readLogFileContent() async {
  // --- Determine the correct log file path --- 
  String logFilePath;
  if (Platform.isAndroid || Platform.isIOS) {
    final logsDir = await getQuizzerLogsPath();
    logFilePath = path.join(logsDir, 'quizzer_log.txt');
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    final logsDir = await getQuizzerLogsPath();
    logFilePath = path.join(logsDir, 'quizzer_log.txt');
  } else {
    // Fallback for unsupported platforms (should match QuizzerLogger's fallback)
    logFilePath = path.join('runtime_cache', 'quizzer_log.txt'); 
    QuizzerLogger.logWarning('_readLogFileContent: Unsupported platform, attempting to read from default relative path: $logFilePath');
  }
  // --- End Determine Path --- 
  
  final file = File(logFilePath);
  String content;
  // No try-catch for file operations, as per instruction.
  if (await file.exists()) {
    // Read all lines from the file
    final List<String> allLines = await file.readAsLines();
    
    // Truncate to last 1000 lines to prevent database size issues
    final int totalLines = allLines.length;
    const int maxLines = 1000;
    
    if (totalLines > maxLines) {
      // Take only the last 1000 lines
      final List<String> truncatedLines = allLines.sublist(totalLines - maxLines);
      content = truncatedLines.join('\n');
      QuizzerLogger.logMessage('Successfully read and truncated log file from $totalLines lines to $maxLines lines from $logFilePath.');
    } else {
      // File is small enough, use all lines
      content = allLines.join('\n');
      QuizzerLogger.logMessage('Successfully read content from $logFilePath ($totalLines lines).');
    }
  } else {
    content = "Log file '$logFilePath' not found or unreadable."; // Keep the path in the message
    QuizzerLogger.logWarning('$logFilePath does not exist. Storing placeholder.');
  }
  return content;
}

/// Verifies the existence and schema of the error_logs table.
Future<void> _verifyErrorLogsTable(Database db) async {
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
  String? userId,
  String? errorMessage,
  String? userFeedback,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await _verifyErrorLogsTable(db);
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
    signalOutboundSyncNeeded();
    return newId;
  } catch (e) {
    QuizzerLogger.logError('Error adding error log - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Updates an existing error log record in the local database.
/// Can be used to add user_feedback or update other fields.
Future<int> updateErrorLog({
  required String id,
  // Provide specific updatable fields as nullable parameters
  String? userFeedback,
  String? logFile, // For instance, if log file is appended or re-fetched
  bool? isResolved, // Though typically server-side, allow local update if needed for some flow
  bool? hasBeenSynced, // Allow explicit setting by sync worker if needed
  // Add other fields from the table that are legitimately updatable locally
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await _verifyErrorLogsTable(db);
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
          signalOutboundSyncNeeded();
      }
    } else {
      QuizzerLogger.logWarning('Failed to update error log id: $id or no changes made. Rows affected: $rowsAffected.');
    }
    return rowsAffected;
  } catch (e) {
    QuizzerLogger.logError('Error updating error log - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Upserts an error log: Inserts if no ID is provided or if ID doesn't exist,
/// otherwise updates the existing log with the given ID.
/// This acts as a routing function to either addErrorLog or updateErrorLog.
Future<String> upsertErrorLog({
  String? id,
  String? userId,
  String? errorMessage,
  String? userFeedback,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await _verifyErrorLogsTable(db);

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
        id: currentId,
        userFeedback: userFeedback,
      );
      return currentId;
    } else {
      QuizzerLogger.logMessage('upsertErrorLog: Adding new error log. Provided ID (if any): $id');
      final String newLogId = await addErrorLog(
        userId: userId,
        errorMessage: errorMessage,
        userFeedback: userFeedback,
      );
      return newLogId;
    }
  } catch (e) {
    QuizzerLogger.logError('Error upserting error log - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Retrieves all error logs that need to be sent to the server.
/// Only returns records that are at least 1 hour old.
/// Uses table helper functions for proper encoding/decoding and works within default cursor window size.
Future<List<Map<String, dynamic>>> getUnsyncedErrorLogs() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await _verifyErrorLogsTable(db);
    
    QuizzerLogger.logMessage('Fetching unsynced error logs (older than 1 hour) from $_errorLogsTableName...');
    
    // Use table helper function for proper querying and decoding
    // Only select essential columns to avoid cursor window overflow
    final List<Map<String, dynamic>> allUnsyncedRecords = await queryAndDecodeDatabase(
      _errorLogsTableName,
      db,
      columns: [
        'id',
        'created_at',
        'user_id',
        'app_version',
        'operating_system',
        'is_resolved',
        'has_been_synced',
        'edits_are_synced',
        'last_modified_timestamp'
      ],
      where: 'has_been_synced = 0 OR edits_are_synced = 0',
    );

    final List<Map<String, dynamic>> filteredRecords = [];
    final DateTime oneHourAgo = DateTime.now().toUtc().subtract(const Duration(hours: 1));

    for (final record in allUnsyncedRecords) {
      final String? createdAtString = record['created_at'] as String?;
      assert(createdAtString != null, 'Error log record (ID: ${record['id']}) has null created_at, but schema expects NOT NULL.');
      
      final DateTime createdAtDateTime = DateTime.parse(createdAtString!);

      if (createdAtDateTime.isBefore(oneHourAgo)) {
        // Truncate large text fields to prevent cursor window issues
        final Map<String, dynamic> truncatedRecord = Map<String, dynamic>.from(record);
        
        // Truncate error_message to 1000 characters
        if (truncatedRecord['error_message'] != null) {
          final String errorMsg = truncatedRecord['error_message'] as String;
          if (errorMsg.length > 1000) {
            truncatedRecord['error_message'] = '${errorMsg.substring(0, 1000)}... (truncated)';
          }
        }
        
        // Truncate log_file to 2000 characters
        if (truncatedRecord['log_file'] != null) {
          final String logFile = truncatedRecord['log_file'] as String;
          if (logFile.length > 2000) {
            truncatedRecord['log_file'] = '${logFile.substring(0, 2000)}... (truncated)';
          }
        }
        
        // Truncate user_feedback to 500 characters
        if (truncatedRecord['user_feedback'] != null) {
          final String userFeedback = truncatedRecord['user_feedback'] as String;
          if (userFeedback.length > 500) {
            truncatedRecord['user_feedback'] = '${userFeedback.substring(0, 500)}... (truncated)';
          }
        }
        
        filteredRecords.add(truncatedRecord);
      }
    }

    QuizzerLogger.logSuccess('Fetched ${allUnsyncedRecords.length} total unsynced records. ${filteredRecords.length} are older than 1 hour.');
    return filteredRecords;
  } catch (e) {
    // Check if this is the specific cursor window error
    if (e.toString().contains('Row too big to fit into CursorWindow')) {
      QuizzerLogger.logError('❌ CURSOR WINDOW ERROR DETECTED - DELETING ALL APP DATA FILES AND FORCING RESTART');
      
      // Delete ALL app data directories to force complete reset
      try {
        // Delete QuizzerApp directory (database)
        final dbPath = await getQuizzerDatabasePath();
        final dbDir = Directory(dbPath).parent;
        if (await dbDir.exists()) {
          await dbDir.delete(recursive: true);
          QuizzerLogger.logMessage('Deleted database directory: ${dbDir.path}');
        }
        
        // Delete QuizzerAppMedia directory (media files)
        final mediaPath = await getQuizzerMediaPath();
        final mediaDir = Directory(mediaPath).parent;
        if (await mediaDir.exists()) {
          await mediaDir.delete(recursive: true);
          QuizzerLogger.logMessage('Deleted media directory: ${mediaDir.path}');
        }
        
        // Delete QuizzerAppHive directory (Hive data)
        final hivePath = await getQuizzerHivePath();
        final hiveDir = Directory(hivePath);
        if (await hiveDir.exists()) {
          await hiveDir.delete(recursive: true);
          QuizzerLogger.logMessage('Deleted Hive directory: ${hiveDir.path}');
        }
        
        // Delete QuizzerAppLogs directory (log files)
        final logsPath = await getQuizzerLogsPath();
        final logsDir = Directory(logsPath);
        if (await logsDir.exists()) {
          await logsDir.delete(recursive: true);
          QuizzerLogger.logMessage('Deleted logs directory: ${logsDir.path}');
        }
        
        QuizzerLogger.logSuccess('DELETED ALL APP DATA FILES - Complete reset forced');
      } catch (deleteError) {
        QuizzerLogger.logError('Failed to delete app data files: $deleteError');
      }
    }
    
    QuizzerLogger.logError('Error getting unsynced error logs - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Deletes an error log record from the local database by its ID.
/// This is typically used after an error log has been successfully synced and confirmed by the server,
/// or for local housekeeping if logs are not meant to be kept indefinitely.
Future<int> deleteLocalErrorLog(String id) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await _verifyErrorLogsTable(db);
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
  } catch (e) {
    QuizzerLogger.logError('Error deleting local error log - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}