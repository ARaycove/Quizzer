import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

/// Initializes the database for web platform
Future<Database> initializeDatabase() async {
  // --- Web ---
  // Use databaseFactoryFfi with in-memory database for web
  ffi.sqfliteFfiInit();
  final factory = ffi.databaseFactoryFfi;
  const path = ':memory:'; // Use in-memory database for web
  QuizzerLogger.logMessage("Using in-memory database for Web platform");
  
  // Open the database using the selected factory and path
  // If this fails, the app should crash (Fail Fast)
  final database = await factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (Database db, int version) async {
        QuizzerLogger.logMessage('Web database onCreate called.');
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        QuizzerLogger.logWarning('Web database onUpgrade called from $oldVersion to $newVersion.');
      }
    )
  );
  QuizzerLogger.logSuccess('Web database initialized successfully in memory');
  return database;
} 