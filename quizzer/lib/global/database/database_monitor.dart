import 'dart:async';
import 'package:quizzer/global/functionality/quizzer_logging.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quizzer/global/database/quizzer_database.dart';

/// A monitor for controlling database access
class DatabaseMonitor {
  static final DatabaseMonitor _instance = DatabaseMonitor._internal();
  factory DatabaseMonitor() => _instance;
  DatabaseMonitor._internal();

  // Database instance
  late final Database _database;
  bool _isInitialized = false;
  bool _isLocked = false;
  final _accessQueue = <Completer<Database>>[];
  final _initializationLock = Completer<void>();
  bool _isInitializing = false;

  /// Initializes the database instance
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_isInitializing) {
      await _initializationLock.future;
      return;
    }

    _isInitializing = true;
    try {
      QuizzerLogger.logMessage('Starting database initialization');
      
      // Initialize SQLite
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      QuizzerLogger.logMessage('SQLite FFI initialized');
      
      _database = await initDb();
      _isInitialized = true;
      QuizzerLogger.logSuccess('Database instance initialized in monitor');
    } catch (e) {
      QuizzerLogger.logError('Database initialization failed: $e');
      _isInitializing = false;
      rethrow;
    } finally {
      _initializationLock.complete();
    }
  }

  /// Requests access to the database
  /// Returns the database instance if available, null if locked
  Future<Database?> requestDatabaseAccess() async {
    if (!_isInitialized) {
      QuizzerLogger.logMessage('Database not initialized, attempting initialization');
      try {
        await initialize();
      } catch (e) {
        QuizzerLogger.logError('Failed to initialize database: $e');
        return null;
      }
    }

    if (_isLocked) {
      final completer = Completer<Database>();
      _accessQueue.add(completer);
      QuizzerLogger.logMessage('Database access queued');
      return await completer.future;
    }

    _isLocked = true;
    QuizzerLogger.logMessage('Database access granted');
    return _database;
  }

  /// Releases the database lock
  void releaseDatabaseAccess() async{
    if (!_isLocked) return;

    if (_accessQueue.isNotEmpty) {
      final nextCompleter = _accessQueue.removeAt(0);
      nextCompleter.complete(_database);
      QuizzerLogger.logMessage('Database access passed to next in queue');
    } else {
      _isLocked = false;
      QuizzerLogger.logMessage('Database access released');
    }
  }
}
