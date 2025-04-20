import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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
  // Initialize FFI
  sqfliteFfiInit();
  // Change the default factory
  databaseFactory = databaseFactoryFfi;
  
  String databasesPath = await getDatabasesPath();
  String path = join(databasesPath, 'quizzer.db');
  QuizzerLogger.logMessage('Database path: $path');

  _database = await openDatabase(
    path,
    version: 1,
    onCreate: (Database db, int version) async {
      // Tables will be created by the worker
    },
    onUpgrade: (Database db, int oldVersion, int newVersion) async {
      // Handle database upgrades if needed
    }
  );

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