import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quizzer/backend_systems/database_manager/quizzer_database.dart';

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

  /// Requests access to the database
  /// Returns the database instance if available, null if locked
  Future<Database?> requestDatabaseAccess() async {
    if (_isLocked) {
      final completer = Completer<Database>();
      _accessQueue.add(completer);
      QuizzerLogger.logMessage('Database access queued, waiting for lock release');
      return await completer.future;
    }

    _isLocked = true;
    QuizzerLogger.logMessage('Database access granted with lock');
    return getDatabaseForMonitor();
  }

  /// Releases the database lock
  void releaseDatabaseAccess() {
    
    if (!_isLocked) {
      QuizzerLogger.logMessage('Attempted to release unlocked database');
      return;
    } else {
      QuizzerLogger.logMessage("Database Lock Released!");
    }

    if (_accessQueue.isNotEmpty) {
      final nextCompleter = _accessQueue.removeAt(0);
      QuizzerLogger.logMessage('Database access passed to next in queue');
      nextCompleter.complete(getDatabaseForMonitor());
    } else {
      _isLocked = false;
      QuizzerLogger.logMessage('Database lock released');
    }
  }
}
