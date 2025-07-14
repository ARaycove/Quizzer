import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quizzer/backend_systems/00_database_manager/quizzer_database.dart';

// Global database monitor instance
final DatabaseMonitor _globalDatabaseMonitor = DatabaseMonitor._internal();

/// Gets the global database monitor instance
DatabaseMonitor getDatabaseMonitor() => _globalDatabaseMonitor;

/// Internal class for queue entries
class _QueueEntry {
  final Completer<Database> completer;
  final String caller;
  final bool isSyncRequest;
  
  _QueueEntry({
    required this.completer,
    required this.caller,
    required this.isSyncRequest,
  });
}

/// A monitor for controlling database access with priority queue
class DatabaseMonitor {
  static final DatabaseMonitor _instance = DatabaseMonitor._internal();
  factory DatabaseMonitor() => _instance;
  DatabaseMonitor._internal();

  // Access control state
  bool _isLocked = false;
  String? _currentLockHolder;
  
  // Priority queue system
  final List<_QueueEntry> _priorityQueue = []; // High priority (non-sync) requests
  final List<_QueueEntry> _syncQueue = [];     // Low priority (sync) requests

  /// Returns whether the database is currently locked
  bool get isLocked => _isLocked;

  /// Returns the number of requests currently waiting in the queue
  int get queueLength => _priorityQueue.length + _syncQueue.length;

  /// Returns the current lock holder (function name and location)
  String? get currentLockHolder => _currentLockHolder;

  /// Extracts caller information from stack trace
  String _getCallerInfo(StackTrace stackTrace) {
    final lines = stackTrace.toString().split('\n');
    
    // Look for the first line that contains 'quizzer' and isn't from database_monitor.dart
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.contains('quizzer') && !line.contains('database_monitor.dart')) {
        // Extract file and function info - be more permissive
        final match = RegExp(r'#\d+\s+(.+?)\s+\((.+?):(\d+):(\d+)\)').firstMatch(line);
        if (match != null) {
          final function = match.group(1) ?? 'unknown_function';
          final file = match.group(2)?.split('/').last ?? 'unknown_file';
          final lineNum = match.group(3) ?? 'unknown_line';
          return '$function ($file:$lineNum)';
        }
        
        // If regex doesn't match, try to extract basic info
        if (line.contains('(') && line.contains(')')) {
          final parts = line.split('(');
          if (parts.length >= 2) {
            final functionPart = parts[0].trim();
            final filePart = parts[1].split(')')[0];
            final fileName = filePart.split('/').last;
            return '$functionPart ($fileName)';
          }
        }
        
        // Last resort - just return the line number and file
        return 'caller (${line.split('/').last})';
      }
    }
    
    // If we can't find any quizzer lines, return the first non-empty line
    for (final line in lines) {
      if (line.trim().isNotEmpty && !line.contains('database_monitor.dart')) {
        return 'caller (${line.trim()})';
      }
    }
    
    return 'unknown caller (stack trace parsing failed)';
  }

  /// Determines if a caller is a sync-related function (involves network sync with central server)
  bool _isSyncRequest(String caller) {
    final lowerCaller = caller.toLowerCase();
    return lowerCaller.contains('inbound_sync_worker.dart') ||
           lowerCaller.contains('inbound_sync_functions.dart') ||
           lowerCaller.contains('outbound_sync_worker.dart') ||
           lowerCaller.contains('outbound_sync_functions.dart') ||
           lowerCaller.contains('media_sync_worker.dart');
  }

  /// Requests access to the database with priority queue
  /// Returns the database instance if available, null if locked
  Future<Database?> requestDatabaseAccess() async {
    final caller = _getCallerInfo(StackTrace.current);
    final isSyncRequest = _isSyncRequest(caller);
    
    if (_isLocked) {
      final completer = Completer<Database>();
      final queueEntry = _QueueEntry(
        completer: completer,
        caller: caller,
        isSyncRequest: isSyncRequest,
      );
      
      // Add to appropriate queue based on priority
      if (isSyncRequest) {
        _syncQueue.add(queueEntry);
        QuizzerLogger.logMessage('Sync database access queued by $caller, waiting for lock release (currently held by: ${_currentLockHolder ?? 'unknown'})');
      } else {
        _priorityQueue.add(queueEntry);
        QuizzerLogger.logMessage('Priority database access queued by $caller, waiting for lock release (currently held by: ${_currentLockHolder ?? 'unknown'})');
      }
      
      return await completer.future;
    }

    _isLocked = true;
    _currentLockHolder = caller;
    QuizzerLogger.logMessage('Database access granted to $caller with lock (${isSyncRequest ? 'sync' : 'priority'} request)');
    return getDatabaseForMonitor();
  }

  /// Releases the database lock and gives access to the next highest priority request
  void releaseDatabaseAccess() {
    final caller = _getCallerInfo(StackTrace.current);
    
    if (!_isLocked) {
      QuizzerLogger.logMessage('$caller attempted to release unlocked database');
      return;
    } else {
      QuizzerLogger.logMessage("Database Lock Released by $caller!");
    }

    // Give priority to non-sync requests first
    _QueueEntry? nextEntry;
    if (_priorityQueue.isNotEmpty) {
      nextEntry = _priorityQueue.removeAt(0);
      QuizzerLogger.logMessage('Database access passed to priority queue (originally requested by ${nextEntry.caller})');
    } else if (_syncQueue.isNotEmpty) {
      nextEntry = _syncQueue.removeAt(0);
      QuizzerLogger.logMessage('Database access passed to sync queue (originally requested by ${nextEntry.caller})');
    }

    if (nextEntry != null) {
      _currentLockHolder = nextEntry.caller;
      nextEntry.completer.complete(getDatabaseForMonitor());
    } else {
      _isLocked = false;
      _currentLockHolder = null;
      QuizzerLogger.logMessage('Database lock released by $caller - no more requests in queue');
    }
  }

  /// !!! CRITICAL OVERRIDE !!!
  /// Provides direct, UNLOCKED access to the database instance.
  /// This method BYPASSES the entire locking mechanism (_isLocked, _accessQueue).
  /// 
  /// **WARNING:** This should ONLY be used by the critical error logging system
  /// (`SessionManager.reportError`) to ensure errors can be logged even if the
  /// database is otherwise locked (potentially by the operation that CAUSED the error).
  /// 
  /// Using this for any other purpose can lead to race conditions, data corruption,
  /// or deadlocks.
  /// 
  /// Since this method does NOT acquire a lock, `releaseDatabaseAccess()` 
  /// MUST NOT be called by the user of this method for the obtained Database instance.
  /// PERMANENTLY LOCKS THE DB MONITOR, locking all other functionality from working.
  Future<Database?> getDirectDatabaseAccessForCriticalLogging() async {
    final caller = _getCallerInfo(StackTrace.current);
    QuizzerLogger.logWarning('DATABASE_MONITOR: CRITICAL OVERRIDE - Providing direct, unlocked DB access for error logging to $caller.');
    _isLocked = true;
    _currentLockHolder = caller;
    return getDatabaseForMonitor();
  }

  /// Checks if the database is in a fresh state (only user_profile and login_attempts tables exist).
  /// This is used to determine whether to await sync workers during login initialization.
  /// 
  /// Returns:
  /// - true if database is fresh (only basic tables exist)
  /// - false if database has additional tables (indicating previous data exists)
  Future<bool> isDatabaseFresh() async {
    try {
      QuizzerLogger.logMessage('Checking if database is in fresh state...');
      
      final db = await requestDatabaseAccess();
      if (db == null) {
        throw Exception('Failed to acquire database access');
      }
      
      // Get all table names
      final List<Map<String, dynamic>> tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'"
      );
      
      final List<String> tableNames = tables.map((row) => row['name'] as String).toList();
      QuizzerLogger.logMessage('Found tables: ${tableNames.join(', ')}');
      
      // Check if question_answer_pairs table exists
      final bool hasQuestionAnswerPairs = tableNames.contains('question_answer_pairs');
      
      // Fresh state means only user_profile and login_attempts tables exist
      final bool isFresh = !hasQuestionAnswerPairs;
      
      QuizzerLogger.logMessage('Database fresh state check: $isFresh (question_answer_pairs exists: $hasQuestionAnswerPairs)');
      
      return isFresh;
      
    } catch (e) {
      QuizzerLogger.logError('Error checking database fresh state: $e');
      rethrow;
    } finally {
      releaseDatabaseAccess();
    }
  }
}
