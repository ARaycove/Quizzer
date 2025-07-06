import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quizzer/backend_systems/00_database_manager/quizzer_database.dart';

// Global database monitor instance
final DatabaseMonitor _globalDatabaseMonitor = DatabaseMonitor._internal();

/// Gets the global database monitor instance
DatabaseMonitor getDatabaseMonitor() => _globalDatabaseMonitor;

/// A monitor for controlling database access
class DatabaseMonitor {
  static final DatabaseMonitor _instance = DatabaseMonitor._internal();
  factory DatabaseMonitor() => _instance;
  DatabaseMonitor._internal();

  // Access control state
  bool _isLocked = false;
  final _accessQueue = <Completer<Database>>[];

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

  /// Requests access to the database
  /// Returns the database instance if available, null if locked
  Future<Database?> requestDatabaseAccess() async {
    final caller = _getCallerInfo(StackTrace.current);
    
    if (_isLocked) {
      final completer = Completer<Database>();
      _accessQueue.add(completer);
      QuizzerLogger.logMessage('Database access queued by $caller, waiting for lock release');
      return await completer.future;
    }

    _isLocked = true;
    QuizzerLogger.logMessage('Database access granted to $caller with lock');
    return getDatabaseForMonitor();
  }

  /// Releases the database lock
  void releaseDatabaseAccess() {
    final caller = _getCallerInfo(StackTrace.current);
    
    if (!_isLocked) {
      QuizzerLogger.logMessage('$caller attempted to release unlocked database');
      return;
    } else {
      QuizzerLogger.logMessage("Database Lock Released by $caller!");
    }

    if (_accessQueue.isNotEmpty) {
      final nextCompleter = _accessQueue.removeAt(0);
      final nextCaller = _getCallerInfo(StackTrace.current);
      QuizzerLogger.logMessage('Database access passed to next in queue (originally requested by $nextCaller)');
      nextCompleter.complete(getDatabaseForMonitor());
    } else {
      _isLocked = false;
      QuizzerLogger.logMessage('Database lock released by $caller');
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
    return getDatabaseForMonitor();
  }
}
