import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// Global database reference
Database? _database;

/// Initializes the database if it doesn't exist
/// Does not create any tables - tables will be created when first accessed
Future<Database> initDb() async {
  if (_database != null) return _database!;
  
  String databasesPath = await getDatabasesPath();
  String path = join(databasesPath, 'quizzer.db');
  print('Database path: $path');

  _database = await openDatabase(
    path, 
    version: 1
  );
  
  return _database!;
}

/// Gets the database instance
Future<Database> getDatabase() async {
  return _database ?? await initDb();
}


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