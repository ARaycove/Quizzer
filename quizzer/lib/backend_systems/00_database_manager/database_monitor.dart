import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quizzer/backend_systems/00_database_manager/quizzer_database.dart';
import 'package:quizzer/backend_systems/09_switch_board/sb_database_signals.dart';

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
    
    // Check if database is accessible and try to fix if it's not
    try {
      Database db = await getDatabaseForMonitor();
      if (await _isDatabaseAccessible(db)) {
        return db;
      } else {
        // Database exists but is not accessible, try to reset connection
        QuizzerLogger.logWarning('Database not accessible, attempting to reset connection...');
        await resetDatabaseConnection();
        
        // Try to get a fresh database reference
        db = await getDatabaseForMonitor();
        if (await _isDatabaseAccessible(db)) {
          QuizzerLogger.logSuccess('Database connection reset successfully');
          return db;
        } else {
          // If still not accessible after reset, the database file might be deleted
          // Try to close and recreate the database connection
          QuizzerLogger.logWarning('Database still not accessible after reset, attempting to recreate connection...');
          await closeDatabase();
          
          // Wait a moment for file system to settle
          await Future.delayed(const Duration(milliseconds: 100));
          
          // Try one more time
          db = await getDatabaseForMonitor();
          if (await _isDatabaseAccessible(db)) {
            QuizzerLogger.logSuccess('Database connection recreated successfully');
            return db;
          } else {
            throw Exception('Failed to establish accessible database connection after multiple attempts');
          }
        }
      }
    } catch (e) {
      // Release lock and rethrow if we can't get a working database
      _isLocked = false;
      _currentLockHolder = null;
      QuizzerLogger.logError('Failed to provide accessible database to $caller: $e');
      rethrow;
    }
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
      
      // Signal that the queue is now empty
      signalDatabaseMonitorQueueEmpty();
    }
  }

  /// Resets the database connection when the database file has been deleted
  /// This ensures that subsequent database operations will create a fresh connection
  Future<void> resetDatabaseConnection() async {
    try {
      QuizzerLogger.logMessage('Resetting database connection after database deletion...');
      
      // Close the current database connection if it exists
      await closeDatabase();
      
      // Clear the lock state since the database is no longer valid
      _isLocked = false;
      _currentLockHolder = null;
      
      // Don't clear the queue - pending requests should still get access after reset
      // _priorityQueue.clear();
      // _syncQueue.clear();
      
      QuizzerLogger.logSuccess('Database connection reset successfully');
    } catch (e) {
      QuizzerLogger.logError('Error resetting database connection: $e');
      // Even if there's an error, clear the lock state to prevent deadlocks
      _isLocked = false;
      _currentLockHolder = null;
      // Don't clear the queue on error either
      // _priorityQueue.clear();
      // _syncQueue.clear();
    }
  }

  /// Checks if the database is accessible and can perform operations
  /// Returns true if the database is accessible, false otherwise
  Future<bool> isDatabaseAccessible() async {
    try {
      final db = await getDatabaseForMonitor();
      
      // Try a simple query to test if the database is accessible
      await db.rawQuery('SELECT 1');
      return true;
    } catch (e) {
      QuizzerLogger.logWarning('Database accessibility check failed: $e');
      return false;
    }
  }

  /// Private method to check if a specific database instance is accessible
  /// Returns true if the database is accessible, false otherwise
  Future<bool> _isDatabaseAccessible(Database db) async {
    try {
      // Try a simple query to test if the database is accessible
      await db.rawQuery('SELECT 1');
      return true;
    } catch (e) {
      // Check for specific database file deletion errors
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('disk i/o error') || 
          errorString.contains('readonly database') ||
          errorString.contains('no such table') ||
          errorString.contains('database is locked')) {
        QuizzerLogger.logWarning('Database accessibility check failed - database file likely deleted or corrupted: $e');
        return false;
      }
      QuizzerLogger.logWarning('Database accessibility check failed: $e');
      return false;
    }
  }

  /// Clears all pending database requests from both priority and sync queues
  /// This method is used during logout to ensure no pending requests remain
  /// that could cause issues after the database is reset
  Future<void> clearAllQueues() async {
    try {
      QuizzerLogger.logMessage('Clearing all pending database request queues...');
      
      // Clear both queues
      _priorityQueue.clear();
      _syncQueue.clear();
      
      // Clear the lock state to ensure clean shutdown
      _isLocked = false;
      _currentLockHolder = null;
      
      QuizzerLogger.logSuccess('All database request queues cleared successfully');
    } catch (e) {
      QuizzerLogger.logError('Error clearing database request queues: $e');
      // Even if there's an error, clear the lock state to prevent deadlocks
      _isLocked = false;
      _currentLockHolder = null;
    }
  }
}
