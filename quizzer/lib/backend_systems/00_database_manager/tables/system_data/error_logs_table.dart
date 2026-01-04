import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/sql_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';

class ErrorLogsTable extends SqlTable {
  static final ErrorLogsTable _instance = ErrorLogsTable._internal();
  factory ErrorLogsTable() => _instance;
  ErrorLogsTable._internal();

  @override
  bool get isTransient => true;

  @override
  bool requiresInboundSync = false;

  @override
  dynamic get additionalFiltersForInboundSync => null;

  @override
  bool get useLastLoginForInboundSync => false;

  @override
  String get tableName => 'error_logs';

  @override
  List<String> get primaryKeyConstraints => ['id'];

  @override
  List<Map<String, String>> get expectedColumns => [
    {'name': 'id', 'type': 'TEXT KEY'},
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

  Future<String> _readLogFileContent() async {
    String logFilePath;
    if (Platform.isAndroid || Platform.isIOS || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final logsDir = await getQuizzerLogsPath();
      logFilePath = path.join(logsDir, 'quizzer_log.txt');
    } else {
      logFilePath = path.join('runtime_cache', 'quizzer_log.txt');
      QuizzerLogger.logWarning('Unsupported platform, reading from default relative path: $logFilePath');
    }

    final file = File(logFilePath);
    if (!await file.exists()) {
      QuizzerLogger.logWarning('$logFilePath does not exist. Storing placeholder.');
      return "Log file '$logFilePath' not found or unreadable.";
    }

    final List<String> allLines = await file.readAsLines();
    const int maxLines = 1000;
    final int totalLines = allLines.length;

    if (totalLines > maxLines) {
      final List<String> truncatedLines = allLines.sublist(totalLines - maxLines);
      QuizzerLogger.logMessage('Successfully read and truncated log file from $totalLines lines to $maxLines lines.');
      return truncatedLines.join('\n');
    } else {
      QuizzerLogger.logMessage('Successfully read content from $logFilePath ($totalLines lines).');
      return allLines.join('\n');
    }
  }

  @override
  Future<bool> validateRecord(Map<String, dynamic> dataToInsert) async {
    final String? id = dataToInsert['id'] as String?;
    final String? createdAt = dataToInsert['created_at'] as String?;
    
    if (id == null || id.isEmpty) {
      QuizzerLogger.logError('Error log validation failed: ID is missing.');
      return false;
    }
    if (createdAt == null || createdAt.isEmpty) {
      QuizzerLogger.logError('Error log validation failed: created_at is missing.');
      return false;
    }
    return true;
  }

  @override
  Future<Map<String, dynamic>> finishRecord(Map<String, dynamic> dataToInsert) async {
    final String now = DateTime.now().toUtc().toIso8601String();
    const Uuid uuid = Uuid();
    
    // Inject mandatory ID and creation time if missing (for new records)
    dataToInsert.putIfAbsent('id', () => uuid.v4());
    dataToInsert.putIfAbsent('created_at', () => now);
    
    // Inject sync/audit fields (always true for any upsert operation)
    dataToInsert['last_modified_timestamp'] = now;
    
    // Check if we are creating a *new* record (no app_version provided)
    if (!dataToInsert.containsKey('app_version')) {
      // Gather complex, asynchronous data for a new log submission
      dataToInsert['app_version'] = await getAppVersionInfo();
      dataToInsert['operating_system'] = await getDeviceInfo();
      dataToInsert['log_file'] = await _readLogFileContent();
      
      // Mark as needing sync
      dataToInsert['has_been_synced'] = 0;
      dataToInsert['edits_are_synced'] = 0;
    } else {
      // Existing record update: mark edits for sync if not already synced
      if (dataToInsert['has_been_synced'] != 1) {
         dataToInsert['edits_are_synced'] = 0;
      }
    }

    return dataToInsert;
  }
}