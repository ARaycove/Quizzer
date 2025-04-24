import 'package:sqflite/sqflite.dart';

// Import platform-specific database initialization
import 'platform/database_native.dart' if (dart.library.html) 'platform/database_web.dart' as platform_db;

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
  // Delegate to platform-specific implementation
  _database = await platform_db.initializeDatabase();
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