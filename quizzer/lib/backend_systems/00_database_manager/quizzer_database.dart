import 'package:sqflite/sqflite.dart';

// Import platform-specific database initialization
import 'platform/database_native.dart';

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
  _database = await initializeDatabase();
  return _database!;
}

/// Returns the current database instance
/// Initializes the database if it hasn't been initialized
Future<Database> getDatabaseForMonitor() async {
  _database ??= await initDb();
  return _database!;
}

/// Properly closes the database and ensures data is persisted to disk
/// This should be called when the app is shutting down or when you want to ensure data is saved
Future<void> closeDatabase() async {
  if (_database != null && _database!.isOpen) {
    await _database!.close();
    _database = null;
  }
}