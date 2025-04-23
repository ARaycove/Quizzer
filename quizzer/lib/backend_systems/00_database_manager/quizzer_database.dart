import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite/sqflite.dart';
import 'dart:io' show Platform, Directory;
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

// The database
// Every write operation or complex operation should be ran as an isolated process
// These processes are a wrapper for functionality
// This wrapper contains the write operations to be executed like any normal function
// requests access from the monitor to perform its operations
// if doesn't get access from the monitor idles for a moment then requests access again

// Global database reference
Database? _database;

/// Initializes the database if it doesn't exist
/// Creates all necessary tables during initialization
Future<Database> initDb() async {
  
  DatabaseFactory factory;
  String path;

  // Select the factory and path based on the platform
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // --- Desktop --- 
    ffi.sqfliteFfiInit(); // Initialize FFI *only* for desktop
    factory = ffi.databaseFactoryFfi;
    QuizzerLogger.logMessage("Using sqflite FFI factory (Desktop)");
    
    // Define path within runtime_cache for desktop
    String dbDirectoryPath = join(Directory.current.path, 'runtime_cache', 'sqlite');
    path = join(dbDirectoryPath, 'quizzer.db');
    
    // Ensure the database directory exists
    // If this fails, the app should crash (Fail Fast)
    Directory(dbDirectoryPath).createSync(recursive: true);
    QuizzerLogger.logMessage('Desktop SQLite directory ensured: $dbDirectoryPath');

  } else {
    // --- Mobile --- 
    factory = databaseFactory; // Default factory from sqflite package
    QuizzerLogger.logMessage("Using standard sqflite factory (Mobile)");
    
    // Use the standard path provided by sqflite for mobile
    String databasesPath = await factory.getDatabasesPath();
    path = join(databasesPath, 'quizzer.db');
  }
  
  QuizzerLogger.logMessage('Final Database path: $path');

  // Open the database using the selected factory and path
  // If this fails, the app should crash (Fail Fast)
  _database = await factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (Database db, int version) async {
        QuizzerLogger.logMessage('Database onCreate called.');
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
         QuizzerLogger.logWarning('Database onUpgrade called from $oldVersion to $newVersion.');
      }
    )
  );
  QuizzerLogger.logSuccess('Database initialized successfully at: $path');
  return _database!;
}

/// Returns the current database instance
/// Initializes the database if it hasn't been initialized
Future<Database> getDatabaseForMonitor() async {
  _database ??= await initDb();
  return _database!;
}

// TODO add function that returns the database instance


//------------------------------------------------------------------------------
// User Profile Table Functions
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// Login Attempts Table Functions
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// Question Answer Pair Table Functions
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// Additional table initialization and CRUD functions can be added as needed
//------------------------------------------------------------------------------