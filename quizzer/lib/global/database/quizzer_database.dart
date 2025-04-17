import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/features/user_profile_management/database/user_profile_table.dart';
import 'package:quizzer/features/question_management/database/question_answer_pairs_table.dart';
import 'package:quizzer/features/modules/database/modules_table.dart';

// Global database reference
Database? _database;

/// Initializes the database if it doesn't exist
/// Creates all necessary tables during initialization
Future<Database> initDb() async {
  if (_database != null) return _database!;
  
  String databasesPath = await getDatabasesPath();
  String path = join(databasesPath, 'quizzer.db');
  print('Database path: $path');

  _database = await openDatabase(
    path,
    version: 1,
    onCreate: (Database db, int version) async {
      // Create tables during database creation
      await verifyUserProfileTable();
      await verifyQuestionAnswerPairTable();
      await verifyModulesTable();
    },
    onUpgrade: (Database db, int oldVersion, int newVersion) async {
      // Handle database upgrades if needed
    }
  );
  
  // Verify tables exist even if database already exists
  await verifyUserProfileTable();
  await verifyQuestionAnswerPairTable();
  await verifyModulesTable();
  
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