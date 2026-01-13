// import 'dart:io';
// import 'dart:convert';
// import 'package:logging/logging.dart';
// import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
// import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
// import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
// import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
// import 'package:supabase/supabase.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'dart:math'; // Import for max function
// import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';

// // ==========================================
// // Helper Function to Log Current Question Details
// // ==========================================
// Future<void> logCurrentQuestionDetails(SessionManager manager) async {
//   QuizzerLogger.logMessage("--- Logging Current Question Details (All Fields) ---");
//   // Access the underlying map directly via the getter
//   final Map<String, dynamic>? details = manager.currentQuestionStaticData; 

//   if (details == null) {
//     QuizzerLogger.logValue("currentQuestionStaticData: null");
//     QuizzerLogger.printDivider();
//     return;
//   }

//   // Check if it's the dummy question (can check a known field like question_id)
//   if (details['question_id'] == null) {
//      QuizzerLogger.logValue("currentQuestionStaticData: Dummy 'No Questions' Record");
//   } else {
//     // Iterate through all key-value pairs in the map and log them
//     QuizzerLogger.logMessage("Raw _currentQuestionDetails Map:");
//     details.forEach((key, value) {
//       QuizzerLogger.logValue("  $key: $value");
//     });
//   }
//   QuizzerLogger.printDivider();
// }

// // ==========================================
// // Helper Function to Log Current User Question Record Details
// // ==========================================
// Future<void> logCurrentUserQuestionRecordDetails(SessionManager manager) async {
//   QuizzerLogger.logMessage("--- Logging Current User Question Record Details ---");
//   final record = manager.currentQuestionUserRecord;

//   if (record == null) {
//     QuizzerLogger.logValue("currentQuestionUserRecord: null");
//     QuizzerLogger.printDivider();
//     return;
//   }

//   // Log each key-value pair in the record
//   record.forEach((key, value) {
//     QuizzerLogger.logValue("  $key: $value");
//   });

//   QuizzerLogger.printDivider();
// }

// // ==========================================
// // Helper Function for Waiting
// // ==========================================
// Future<void> waitTime(int milliseconds) async {
//   final double seconds = milliseconds / 1000.0;
//   QuizzerLogger.logMessage("Waiting for ${seconds.toStringAsFixed(1)} seconds...");
//   await Future.delayed(Duration(milliseconds: milliseconds));
//   QuizzerLogger.logMessage("Wait complete.");
// }

// // ==========================================
// // Helper Function to Log User Record From DB
// // ==========================================
// Future<void> logCurrentUserRecordFromDB(SessionManager manager) async {
//   QuizzerLogger.logMessage("--- Logging Current User Question Record from DB ---");
//   final dbMonitor = getDatabaseMonitor(); // Get monitor instance
//   final userId = manager.userId;
//   final questionId = manager.currentQuestionStaticData?['question_id'] as String?;

//   if (userId == null) {
//     QuizzerLogger.logWarning("Cannot log from DB: User not logged in (userId is null).");
//     QuizzerLogger.printDivider();
//     return;
//   }
//   if (questionId == null) {
//     QuizzerLogger.logWarning("Cannot log from DB: No current question loaded (questionId is null).");
//     QuizzerLogger.printDivider();
//     return;
//   }

//   Database? db;
//   db = await dbMonitor.requestDatabaseAccess();
//   if (db == null) {
//     // Fail fast if DB is unavailable during the test
//     throw StateError('Database access unavailable during test logging.');
//   }

//   final Map<String, dynamic> record = await getUserQuestionAnswerPairById(
//     userId,      // Positional argument 1
//     questionId,  // Positional argument 2
//   );

//   // Release lock IMMEDIATELY after the DB operation completes or throws
//   dbMonitor.releaseDatabaseAccess();
//   QuizzerLogger.logMessage("DB access released.");
//   db = null; // Prevent reuse after release


//   // Log the record
//   QuizzerLogger.logMessage("DB Record for User: $userId, Question: $questionId");
//   record.forEach((key, value) {
//     QuizzerLogger.logValue("  $key: $value");
//   });
    
//   QuizzerLogger.printDivider();
// }

// // ==========================================
// // Helper Function to Truncate ALL Tables
// // ==========================================

// /// Deletes all rows from ALL user-defined tables in the database.
// /// Queries sqlite_master to find tables.
// /// USE WITH EXTREME CAUTION - This clears ALL data.
// Future<void> truncateAllTables(Database db) async {
//   QuizzerLogger.printHeader("--- TRUNCATING ALL DATABASE TABLES --- ");

//   // 1. Get all user-defined table names
//   QuizzerLogger.logMessage("Fetching list of all user tables...");
//   // Exclude sqlite system tables and android metadata table
//   final List<Map<String, dynamic>> tables = await db.rawQuery(
//     "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'"
//   );

//   if (tables.isEmpty) {
//     QuizzerLogger.logWarning("No user tables found to truncate.");
//     QuizzerLogger.printHeader("--- TABLE TRUNCATION COMPLETE (No tables found) --- ");
//     return;
//   }

//   final List<String> tableNames = tables.map((row) => row['name'] as String).toList();
//   QuizzerLogger.logValue("Tables to truncate: ${tableNames.join(', ')}");

//   // 2. Truncate each table (DELETE FROM)
//   // If any delete fails, an exception will be thrown (Fail Fast)
//   for (final tableName in tableNames) {
//     QuizzerLogger.logMessage("Truncating table: $tableName...");
//     final int rowsDeleted = await db.delete(tableName); // No WHERE clause = delete all
//     QuizzerLogger.logSuccess("Truncated $tableName ($rowsDeleted rows deleted).");
//   }

//   QuizzerLogger.printHeader("--- ALL TABLE TRUNCATION COMPLETE --- ");
// }

// // ==========================================
// // System Test Initialization Helper
// // ==========================================

// /// Initializes the logger and SessionManager for system tests.
// /// This function should be called at the beginning of each system test.
// Future<SessionManager> initializeSystemTest() async {
//   QuizzerLogger.printHeader('Initializing System Test');
  
//   // Initialize logger with FINE level to see all messages
//   QuizzerLogger.setupLogging(level: Level.FINE);
//   QuizzerLogger.logMessage('Logger initialized with FINE level');
  
//   // Get SessionManager instance and wait for initialization
//   final sessionManager = getSessionManager();
//   QuizzerLogger.logMessage('SessionManager instance obtained');
  
//   // Wait for async initialization to complete
//   await sessionManager.initializationComplete;
//   QuizzerLogger.logMessage('SessionManager initialization completed');
  
//   QuizzerLogger.logSuccess('System test initialization complete');
//   QuizzerLogger.printDivider();
  
//   return sessionManager;
// }

// // ==========================================
// // Test Account Management
// // ==========================================

// /// Saves test account credentials to a file for use by other tests
// Future<void> saveTestAccountCredentials({
//   required String email,
//   required String username,
//   required String password,
//   String filename = 'test_account_credentials.json',
// }) async {
//   QuizzerLogger.logMessage('Saving test account credentials...');
  
//   final credentials = {
//     'email': email,
//     'username': username,
//     'password': password,
//     'created_at': DateTime.now().toIso8601String(),
//   };
  
//   // Save to test directory
//   final file = File('test/$filename');
//   await file.writeAsString(jsonEncode(credentials));
  
//   QuizzerLogger.logValue('Credentials saved to: ${file.path}');
//   QuizzerLogger.logValue('Email: $email');
//   QuizzerLogger.logValue('Username: $username');
//   QuizzerLogger.logSuccess('Test account credentials saved successfully');
// }

// /// Loads test account credentials from file
// Future<Map<String, dynamic>?> loadTestAccountCredentials({
//   String filename = 'test_account_credentials.json',
// }) async {
//   QuizzerLogger.logMessage('Loading test account credentials...');
  
//   try {
//     final file = File('test/$filename');
//     if (!await file.exists()) {
//       QuizzerLogger.logWarning('Test credentials file not found: ${file.path}');
//       return null;
//     }
    
//     final content = await file.readAsString();
//     final credentials = jsonDecode(content) as Map<String, dynamic>;
    
//     QuizzerLogger.logValue('Credentials loaded from: ${file.path}');
//     QuizzerLogger.logValue('Email: ${credentials['email']}');
//     QuizzerLogger.logValue('Username: ${credentials['username']}');
//     QuizzerLogger.logSuccess('Test account credentials loaded successfully');
    
//     return credentials;
//   } catch (e) {
//     QuizzerLogger.logError('Error loading test credentials: $e');
//     return null;
//   }
// }

// /// Cleans up test account credentials file
// Future<void> cleanupTestAccountCredentials({
//   String filename = 'test_account_credentials.json',
// }) async {
//   QuizzerLogger.logMessage('Cleaning up test account credentials...');
  
//   try {
//     final file = File('test/$filename');
//     if (await file.exists()) {
//       await file.delete();
//       QuizzerLogger.logSuccess('Test credentials file deleted: ${file.path}');
//     } else {
//       QuizzerLogger.logMessage('Test credentials file not found, nothing to delete');
//     }
//   } catch (e) {
//     QuizzerLogger.logError('Error cleaning up test credentials: $e');
//   }
// }

// /// Loads the test configuration from test_config.json
// Future<Map<String, dynamic>> getTestConfig() async {
//     final configFile = File('test/test_config.json');
//     final jsonString = await configFile.readAsString();
//     return json.decode(jsonString) as Map<String, dynamic>;
// }

// // ==========================================
// // Test State Reset Functions
// // ==========================================

// /// Deletes all records from a specified table.
// /// This function clears ALL records from the specified table and verifies the table is empty after clearing.
// /// 
// /// Parameters:
// /// - tableName: The name of the table to clear records from
// /// - userId: The user ID to clear records for (optional, clears all if null)
// /// - userIdColumn: The column name for the user ID (default: 'user_uuid')
// /// 
// /// Returns:
// /// - true if deletion was successful, false otherwise
// Future<bool> deleteAllRecordsFromTable(String tableName, {String? userId, String userIdColumn = 'user_uuid'}) async {
//   QuizzerLogger.logMessage('Deleting all records from table: $tableName');
  
//   try {
//     // Step 1: Clear the specified table - ALL RECORDS
//     QuizzerLogger.logMessage('Clearing ALL records from $tableName table...');
//     final db = await getDatabaseMonitor().requestDatabaseAccess();
//     if (db == null) {
//       QuizzerLogger.logError('Failed to acquire database access');
//       return false;
//     }
    
//     if (userId != null) {
//       // Clear only records for specific user
//       final int deletedCount = await db.delete(
//         tableName,
//         where: '$userIdColumn = ?',
//         whereArgs: [userId],
//       );
//       QuizzerLogger.logMessage('Deleted $deletedCount records for user $userId from $tableName');
//     } else {
//       // Clear all records
//       await db.execute('DELETE FROM $tableName');
//       QuizzerLogger.logMessage('Deleted ALL records from $tableName table');
//     }
    
//     getDatabaseMonitor().releaseDatabaseAccess();
//     QuizzerLogger.logSuccess('ALL records cleared from $tableName table');

//     // Step 2: Verify that the table is empty
//     QuizzerLogger.logMessage('Verifying $tableName table is empty...');
//     final dbVerify = await getDatabaseMonitor().requestDatabaseAccess();
//     if (dbVerify == null) {
//       QuizzerLogger.logError('Failed to acquire database access for verification');
//       return false;
//     }
    
//     final List<Map<String, dynamic>> verificationRecords = await dbVerify.query(tableName);
//     getDatabaseMonitor().releaseDatabaseAccess();
    
//     if (verificationRecords.isEmpty) {
//       QuizzerLogger.logSuccess('Verified $tableName table is empty');
//       return true;
//     } else {
//       QuizzerLogger.logError('Verification failed: Found ${verificationRecords.length} records after clearing');
//       return false;
//     }
    
//   } catch (e) {
//     QuizzerLogger.logError('Error deleting records from $tableName table: $e');
//     return false;
//   }
// }

// /// Drops a table entirely from the database.
// /// This function completely removes the table and all its data.
// /// 
// /// Parameters:
// /// - tableName: The name of the table to drop
// /// 
// /// Returns:
// /// - true if table was successfully dropped, false otherwise
// Future<bool> dropTable(String tableName) async {
//   QuizzerLogger.logMessage('Dropping table: $tableName');
  
//   try {
//     final db = await getDatabaseMonitor().requestDatabaseAccess();
//     if (db == null) {
//       QuizzerLogger.logError('Failed to acquire database access');
//       return false;
//     }
    
//     // Drop the table
//     await db.execute('DROP TABLE IF EXISTS $tableName');
//     getDatabaseMonitor().releaseDatabaseAccess();
    
//     QuizzerLogger.logSuccess('Successfully dropped table: $tableName');
//     return true;
    
//   } catch (e) {
//     QuizzerLogger.logError('Error dropping table $tableName: $e');
//     return false;
//   }
// }

// /// Deletes all local app data to simulate a brand new user state.
// /// This function deletes all app directories and ensures a completely clean state.
// /// 
// /// Returns:
// /// - true if cleanup was successful, false otherwise
// Future<bool> deleteAllLocalAppData() async {
//   QuizzerLogger.logMessage('Performing complete cleanup of local app data...');
  
//   try {
//     // Delete all app directories
//     final directories = [
//       'QuizzerApp',
//       'QuizzerAppHive', 
//       'QuizzerAppLogs',
//       'QuizzerAppMedia'
//     ];
    
//     for (final dirName in directories) {
//       final dir = Directory(dirName);
//       if (await dir.exists()) {
//         await dir.delete(recursive: true);
//         QuizzerLogger.logMessage('Deleted directory: $dirName');
//       }
//     }
    
//     QuizzerLogger.logSuccess('Complete cleanup finished - simulating brand new user state');
//     return true;
//   } catch (e) {
//     QuizzerLogger.logError('Error during complete cleanup: $e');
//     return false;
//   }
// }

// /// Deletes test question records from Supabase review tables.
// /// This function attempts to delete the specified question IDs from both
// /// question_answer_pair_new_review and question_answer_pair_edits_review tables.
// /// 
// /// Parameters:
// /// - questionIds: List of question IDs to delete from Supabase
// /// 
// /// Returns:
// /// - true if cleanup was successful, false otherwise
// Future<bool> deleteTestQuestionsFromSupabase(List<String> questionIds) async {
//   QuizzerLogger.logMessage('Cleaning up test questions from Supabase: ${questionIds.length} questions');
  
//   try {
//     final sessionManager = getSessionManager();
//     final supabase = sessionManager.supabase;
    
//     if (questionIds.isEmpty) {
//       QuizzerLogger.logMessage('No question IDs provided for cleanup');
//       return true;
//     }
    
//     int deletedFromNewReview = 0;
//     int deletedFromEditsReview = 0;
//     int deletedFromMain = 0;
//     int notFoundInNewReview = 0;
//     int notFoundInEditsReview = 0;
//     int notFoundInMain = 0;
    
//     // Delete from new_review table
//     for (final questionId in questionIds) {
//       try {
//         final response = await supabase
//           .from('question_answer_pair_new_review')
//           .delete()
//           .eq('question_id', questionId);
        
//         // Check if any rows were actually deleted
//         if (response != null) {
//           deletedFromNewReview++;
//           QuizzerLogger.logMessage('Deleted question $questionId from new_review table');
//         } else {
//           notFoundInNewReview++;
//           QuizzerLogger.logMessage('Question $questionId not found in new_review table');
//         }
//       } catch (e) {
//         // Question might not exist in this table, which is fine
//         notFoundInNewReview++;
//         QuizzerLogger.logMessage('Question $questionId not found in new_review table (or already deleted): $e');
//       }
//     }
    
//     // Delete from edits_review table
//     for (final questionId in questionIds) {
//       try {
//         final response = await supabase
//           .from('question_answer_pair_edits_review')
//           .delete()
//           .eq('question_id', questionId);
        
//         // Check if any rows were actually deleted
//         if (response != null) {
//           deletedFromEditsReview++;
//           QuizzerLogger.logMessage('Deleted question $questionId from edits_review table');
//         } else {
//           notFoundInEditsReview++;
//           QuizzerLogger.logMessage('Question $questionId not found in edits_review table');
//         }
//       } catch (e) {
//         // Question might not exist in this table, which is fine
//         notFoundInEditsReview++;
//         QuizzerLogger.logMessage('Question $questionId not found in edits_review table (or already deleted): $e');
//       }
//     }
    
//     // Delete from main table (in case they were manually inserted for testing)
//     for (final questionId in questionIds) {
//       try {
//         final response = await supabase
//           .from('question_answer_pairs')
//           .delete()
//           .eq('question_id', questionId);
        
//         // Check if any rows were actually deleted
//         if (response != null) {
//           deletedFromMain++;
//           QuizzerLogger.logMessage('Deleted question $questionId from main table');
//         } else {
//           notFoundInMain++;
//           QuizzerLogger.logMessage('Question $questionId not found in main table');
//         }
//       } catch (e) {
//         // Question might not exist in this table, which is fine
//         notFoundInMain++;
//         QuizzerLogger.logMessage('Question $questionId not found in main table (or already deleted): $e');
//       }
//     }
    
//     QuizzerLogger.logSuccess('Cleanup summary: Deleted $deletedFromNewReview from new_review, $deletedFromEditsReview from edits_review, $deletedFromMain from main table');
//     QuizzerLogger.logMessage('Not found: $notFoundInNewReview in new_review, $notFoundInEditsReview in edits_review, $notFoundInMain in main table');
//     QuizzerLogger.logSuccess('Successfully processed cleanup for ${questionIds.length} test questions from Supabase');
//     return true;
//   } catch (e) {
//     QuizzerLogger.logError('Error cleaning up test questions from Supabase: $e');
//     return false;
//   }
// }

// // Question State
// // ------------------------------------------
// /// Ensures a user question answer pair record is eligible for selection.
// /// This function sets the circulation status to true and the revision due date to the past.
// /// 
// /// Parameters:
// /// - userId: The user ID
// /// - questionId: The question ID to make eligible
// /// 
// /// Returns:
// /// - true if the record was successfully made eligible, false otherwise
// Future<bool> ensureRecordEligible(String userId, String questionId) async {
//   QuizzerLogger.logMessage('Making question $questionId eligible for user $userId...');
  
//   try {
//     // Set circulation status to true (in circulation)
//     await setCirculationStatus(userId, questionId, true);
    
//     // Set revision due date to 1 year in the past
//     final DateTime pastDate = DateTime.now().subtract(const Duration(days: 365));
//     final String pastDateString = pastDate.toUtc().toIso8601String();
    
//     final db = await getDatabaseMonitor().requestDatabaseAccess();
//     if (db == null) {
//       QuizzerLogger.logError('Failed to acquire database access');
//       return false;
//     }
    
//     final int result = await db.update(
//       'user_question_answer_pairs',
//       {'next_revision_due': pastDateString},
//       where: 'user_uuid = ? AND question_id = ?',
//       whereArgs: [userId, questionId],
//     );
    
//     getDatabaseMonitor().releaseDatabaseAccess();
    
//     if (result > 0) {
//       // QuizzerLogger.logSuccess('Successfully made question $questionId eligible');
//       return true;
//     } else {
//       QuizzerLogger.logWarning('No records updated for question $questionId');
//       return false;
//     }
    
//   } catch (e) {
//     QuizzerLogger.logError('Error making question $questionId eligible: $e');
//     return false;
//   }
// }

// /// Makes a user question answer pair record ineligible for selection.
// /// This function sets the circulation status to false and the revision due date to the future.
// /// 
// /// Parameters:
// /// - userId: The user ID
// /// - questionId: The question ID to make ineligible
// /// 
// /// Returns:
// /// - true if the record was successfully made ineligible, false otherwise
// Future<bool> makeRecordIneligible(String userId, String questionId) async {
//   QuizzerLogger.logMessage('Making question $questionId ineligible for user $userId...');
  
//   try {
//     // Set circulation status to false (not in circulation)
//     await setCirculationStatus(userId, questionId, false);
    
//     // Set revision due date to 1 year in the future
//     final DateTime futureDate = DateTime.now().add(const Duration(days: 365));
//     final String futureDateString = futureDate.toUtc().toIso8601String();
    
//     final db = await getDatabaseMonitor().requestDatabaseAccess();
//     if (db == null) {
//       QuizzerLogger.logError('Failed to acquire database access');
//       return false;
//     }
    
//     final int result = await db.update(
//       'user_question_answer_pairs',
//       {'next_revision_due': futureDateString},
//       where: 'user_uuid = ? AND question_id = ?',
//       whereArgs: [userId, questionId],
//     );
    
//     getDatabaseMonitor().releaseDatabaseAccess();
    
//     if (result > 0) {
//       // QuizzerLogger.logSuccess('Successfully made question $questionId ineligible');
//       return true;
//     } else {
//       QuizzerLogger.logWarning('No records updated for question $questionId');
//       return false;
//     }
    
//   } catch (e) {
//     QuizzerLogger.logError('Error making question $questionId ineligible: $e');
//     return false;
//   }
// }

// // ==========================================
// // Test Data Generation Functions
// // ==========================================

// /// Generates question input data for use with addQuestion functions.
// /// This function creates properly formatted input data that can be passed directly to addQuestion* functions.
// /// 
// /// Parameters:
// /// - questionType: String - Type of question to generate. Must be one of: 'multiple_choice', 'select_all_that_apply', 'true_false', 'sort_order', 'fill_in_the_blank'. Determines the structure and type-specific fields in the generated data.
// /// - numberOfQuestions: int - Number of questions to generate (default: 1). Controls how many question data maps are returned in the list.
// /// - numberOfModules: int - Number of different modules to cycle through (default: 3). Questions will be distributed across this many modules (e.g., TestModule0, TestModule1, TestModule2).
// /// - numberOfOptions: int - Number of options for multiple choice/select all questions (default: 4). Controls how many options are generated for questions that require options.
// /// - numberOfBlanks: int - Number of blanks for fill-in-the-blank questions (default: 1). Controls how many fill-in-the-blank spaces are created in the question.
// /// - numberOfSynonymsPerBlank: int - Number of synonyms per blank (default: 2). For fill-in-the-blank questions, controls how many acceptable answers are generated for each blank.
// /// - randomNumberOfOptions: bool - Whether to randomize number of options (default: false). If true, will generate between 2 and numberOfOptions options instead of exactly numberOfOptions.
// /// - randomNumberOfBlanks: bool - Whether to randomize number of blanks (default: false). If true, will generate between 1 and numberOfBlanks blanks instead of exactly numberOfBlanks.
// /// - randomNumberOfSynonyms: bool - Whether to randomize number of synonyms per blank (default: false). If true, will generate between 1 and numberOfSynonymsPerBlank synonyms instead of exactly numberOfSynonymsPerBlank.
// /// - includeMedia: bool - Whether to include image elements in questions and answers (default: false). If true, adds image elements alongside text elements.
// /// - customModuleName: String? - Optional custom module name to use for all questions (default: null). If provided, overrides the cycling module names and uses this name for all generated questions.
// /// 
// /// Returns:
// /// - List<Map<String, dynamic>> where each map contains:
// ///   - 'moduleName': String - the module name for the question
// ///   - 'questionType': String - the type of question ('multiple_choice', 'select_all_that_apply', 'true_false', 'sort_order', 'fill_in_the_blank')
// ///   - 'questionElements': List<Map<String, dynamic>> - list of question elements with 'type' ('text', 'image', 'blank') and 'content'
// ///   - 'answerElements': List<Map<String, dynamic>> - list of answer elements with 'type' ('text', 'image') and 'content'
// ///   - Type-specific fields:
// ///     - multiple_choice: 'options' (List<Map>), 'correctOptionIndex' (int)
// ///     - select_all_that_apply: 'options' (List<Map>), 'indexOptionsThatApply' (List<int>)
// ///     - true_false: 'options' (List<Map>), 'correctOptionIndex' (int)
// ///     - sort_order: 'options' (List<Map>), 'correctOrder' (List<Map>)
// ///     - fill_in_the_blank: 'answersToBlanks' (List<Map<String, List<String>>>)
// List<Map<String, dynamic>> generateQuestionInputData({
//   required String questionType,
//   int numberOfQuestions = 1,
//   int numberOfModules = 3,
//   int numberOfOptions = 4,
//   int numberOfBlanks = 1,
//   int numberOfSynonymsPerBlank = 2,
//   bool randomNumberOfOptions = false,
//   bool randomNumberOfBlanks = false,
//   bool randomNumberOfSynonyms = false,
//   bool includeMedia = false,
//   String? customModuleName,
// }) {
//   final List<Map<String, dynamic>> inputData = [];
//   final Random random = Random();
  
//   for (int i = 0; i < numberOfQuestions; i++) {
//     final Map<String, dynamic> questionData = {
//       'moduleName': customModuleName ?? 'TestModule${i % numberOfModules}',
//       'questionType': questionType,
//       'questionElements': includeMedia 
//         ? [
//             {'type': 'text', 'content': 'Test Question $i - What is the answer?'},
//             {'type': 'image', 'content': 'question_image_$i.png'}
//           ]
//         : [
//             {'type': 'text', 'content': 'Test Question $i - What is the answer?'}
//           ],
//       'answerElements': includeMedia
//         ? [
//             {'type': 'text', 'content': 'Test Answer $i'},
//             {'type': 'image', 'content': 'answer_image_$i.png'}
//           ]
//         : [
//             {'type': 'text', 'content': 'Test Answer $i'}
//           ],
//     };
    
//     // Add type-specific data
//     switch (questionType) {
//       case 'multiple_choice':
//         final int actualOptions = randomNumberOfOptions ? random.nextInt(3) + 2 : numberOfOptions; // 2-4 options
//         final List<Map<String, dynamic>> options = [];
//         for (int j = 0; j < actualOptions; j++) {
//           options.add({'type': 'text', 'content': 'Option ${String.fromCharCode(65 + j)} for question $i'});
//           if (includeMedia && j == actualOptions - 1) {
//             options.add({'type': 'image', 'content': 'option_image_$i.png'});
//           }
//         }
//         questionData['options'] = options;
//         questionData['correctOptionIndex'] = i % actualOptions;
//         break;
        
//       case 'select_all_that_apply':
//         final int actualOptions = randomNumberOfOptions ? random.nextInt(3) + 2 : numberOfOptions; // 2-4 options
//         questionData['options'] = List.generate(actualOptions, (j) => 
//           {'type': 'text', 'content': 'Option ${String.fromCharCode(65 + j)} for question $i'}
//         );
//         // Randomly select 1-3 options that apply
//         final int numToSelect = random.nextInt(actualOptions - 1) + 1;
//         final List<int> selectedIndices = List.generate(actualOptions, (j) => j)..shuffle(random);
//         questionData['indexOptionsThatApply'] = selectedIndices.take(numToSelect).toList()..sort();
//         break;
        
//       case 'true_false':
//         questionData['options'] = [
//           {'type': 'text', 'content': 'True'},
//           {'type': 'text', 'content': 'False'}
//         ];
//         questionData['correctOptionIndex'] = i % 2; // Alternate between true and false
//         break;
        
//       case 'sort_order':
//         final int actualOptions = randomNumberOfOptions ? random.nextInt(3) + 2 : numberOfOptions; // 2-4 options
//         questionData['options'] = List.generate(actualOptions, (j) => 
//           {'type': 'text', 'content': 'Item ${j + 1} for question $i'}
//         );
//         questionData['correctOrder'] = List.generate(actualOptions, (j) => 
//           {'type': 'text', 'content': 'Item ${j + 1} for question $i'}
//         );
//         break;
        
//       case 'fill_in_the_blank':
//         final int actualBlanks = randomNumberOfBlanks ? random.nextInt(3) + 1 : numberOfBlanks; // 1-3 blanks
        
//         // Build question elements with blanks
//         final List<Map<String, dynamic>> questionElements = [];
//         for (int j = 0; j < actualBlanks; j++) {
//           if (j > 0) {
//             questionElements.add({'type': 'text', 'content': ' and '});
//           }
//           questionElements.add({'type': 'text', 'content': 'The answer to question $i blank ${j + 1} is '});
//           questionElements.add({'type': 'blank', 'content': '10'});
//         }
//         questionElements.add({'type': 'text', 'content': '.'});
//         questionData['questionElements'] = questionElements;
        
//         // Build answers for each blank
//         final List<Map<String, List<String>>> answersToBlanks = [];
//         for (int j = 0; j < actualBlanks; j++) {
//           final int actualSynonyms = randomNumberOfSynonyms ? random.nextInt(3) + 1 : numberOfSynonymsPerBlank; // 1-3 synonyms
//           final List<String> synonyms = List.generate(actualSynonyms, (k) => 'Answer $i blank ${j + 1} synonym ${k + 1}');
//           answersToBlanks.add({'blank_${j + 1}': synonyms});
//         }
//         questionData['answersToBlanks'] = answersToBlanks;
//         break;
        
//       default:
//         throw ArgumentError('Unsupported question type: $questionType');
//     }
    
//     inputData.add(questionData);
//   }
  
//   return inputData;
// }

// /// Generates complete question answer pair records for testing batch operations.
// /// This function creates fully formatted records that can be used with batchUpsertQuestionAnswerPairs.
// /// 
// /// Parameters:
// /// - numberOfQuestions: Number of questions to generate (default: 1)
// /// - questionType: Type of question to generate (default: 'multiple_choice')
// /// - includeMedia: If true, all records will have media elements (default: false)
// /// - includeSomeMedia: If true, some records (even indices) will have media elements (default: false)
// /// - generateInvalidStructure: If true, adds invalid structure elements (default: false)
// /// - generateMalformedJson: If true, generates malformed JSON for testing (default: false)
// /// - generateEmptyRecord: If true, generates empty records for testing (default: false)
// /// 
// /// Returns:
// /// - List of Map<String, dynamic> containing complete question records
// List<Map<String, dynamic>> generateCompleteQuestionAnswerPairRecord({
//   int numberOfQuestions = 1,
//   String questionType = 'multiple_choice',
//   bool includeMedia = false,
//   bool includeSomeMedia = false,
//   bool generateInvalidStructure = false,
//   bool generateMalformedJson = false,
//   bool generateEmptyRecord = false,
//   String? invalidImagePathType, // 'directory', 'absolute', 'url'
// }) {
//   final List<Map<String, dynamic>> records = [];
//   final String qstContrib = getSessionManager().userId!;
  
//   for (int i = 0; i < numberOfQuestions; i++) {
//     final String timeStamp = DateTime.now().add(Duration(seconds: i)).toUtc().toIso8601String();
//     final String questionId = '${timeStamp}_$qstContrib';
    
//     // Determine content based on parameters
//     String questionElements;
//     String answerElements;
//     int hasMedia = 0;
    
//     if (generateEmptyRecord) {
//       // Empty record for testing
//       questionElements = '';
//       answerElements = '';
//       hasMedia = 0;
//     } else if (generateMalformedJson) {
//       // Malformed JSON for testing
//       questionElements = generateFormattedElements(elementType: 'question', formatType: 'malformed_json');
//       answerElements = generateFormattedElements(elementType: 'answer', formatType: 'malformed_json');
//       hasMedia = 0;
//     } else if (invalidImagePathType != null) {
//       // Generate records with invalid image paths for testing
//       questionElements = generateFormattedElements(elementType: 'question', formatType: 'complex_valid', includeImage: true, invalidImagePathType: invalidImagePathType);
//       answerElements = generateFormattedElements(elementType: 'answer', formatType: 'complex_valid', includeImage: true, invalidImagePathType: invalidImagePathType);
//       hasMedia = 1;
//     } else if (includeMedia) {
//       // All records have media
//       questionElements = generateFormattedElements(elementType: 'question', formatType: 'complex_valid', includeImage: true);
//       answerElements = generateFormattedElements(elementType: 'answer', formatType: 'complex_valid', includeImage: true);
//       hasMedia = 1;
//     } else if (includeSomeMedia && i % 2 == 0) {
//       // Some records have media (even indices)
//       questionElements = generateFormattedElements(elementType: 'question', formatType: 'complex_valid', includeImage: true);
//       answerElements = generateFormattedElements(elementType: 'answer', formatType: 'valid', includeImage: false);
//       hasMedia = 1;
//     } else {
//       // No media
//       questionElements = generateFormattedElements(elementType: 'question', formatType: 'valid', includeImage: false);
//       answerElements = generateFormattedElements(elementType: 'answer', formatType: 'valid', includeImage: false);
//       hasMedia = 0;
//     }
    
//     final Map<String, dynamic> record = {
//       'question_id': questionId,
//       'time_stamp': timeStamp,
//       'question_elements': questionElements,
//       'answer_elements': answerElements,
//       'module_name': 'TestModule${i % 3}',
//       'question_type': questionType,
//       'qst_contrib': qstContrib,
//       'ans_contrib': qstContrib,
//       'qst_reviewer': null,
//       'has_been_reviewed': 0,
//       'ans_flagged': 0,
//       'flag_for_removal': 0,
//       'last_modified_timestamp': timeStamp,
//       'has_media': hasMedia,
//       'has_been_synced': 0,
//       'edits_are_synced': 0,
//     };
    
//     // Add invalid structure elements if requested
//     if (generateInvalidStructure) {
//       record['image'] = 'invalid_image.png'; // Direct image field (invalid structure)
//     }
    
//     // Add type-specific fields
//     switch (questionType) {
//       case 'multiple_choice':
//         if (includeMedia) {
//           record['options'] = generateFormattedElements(elementType: 'option', formatType: 'complex_valid', includeImage: true, numberOfElements: 4);
//         } else {
//           record['options'] = generateFormattedElements(elementType: 'option', formatType: 'valid', includeImage: false, numberOfElements: 4);
//         }
//         record['correct_option_index'] = i % 4;
//         record['correct_order'] = null;
//         record['index_options_that_apply'] = null;
//         record['answers_to_blanks'] = null;
//         break;
        
//       case 'select_all_that_apply':
//         record['options'] = '[{"type":"text","content":"Option A"},{"type":"text","content":"Option B"},{"type":"text","content":"Option C"}]';
//         record['correct_option_index'] = null;
//         record['correct_order'] = null;
//         record['index_options_that_apply'] = '[0,2]';
//         record['answers_to_blanks'] = null;
//         break;
        
//       case 'true_false':
//         record['options'] = '[{"type":"text","content":"True"},{"type":"text","content":"False"}]';
//         record['correct_option_index'] = i % 2;
//         record['correct_order'] = null;
//         record['index_options_that_apply'] = null;
//         record['answers_to_blanks'] = null;
//         break;
        
//       case 'sort_order':
//         record['options'] = '[{"type":"text","content":"Item 1"},{"type":"text","content":"Item 2"},{"type":"text","content":"Item 3"}]';
//         record['correct_option_index'] = null;
//         record['correct_order'] = '[{"type":"text","content":"Item 1"},{"type":"text","content":"Item 2"},{"type":"text","content":"Item 3"}]';
//         record['index_options_that_apply'] = null;
//         record['answers_to_blanks'] = null;
//         break;
        
//       case 'fill_in_the_blank':
//         record['question_elements'] = '[{"type":"text","content":"The answer to question $i is "},{"type":"blank","content":"10"}]';
//         record['options'] = null;
//         record['correct_option_index'] = null;
//         record['correct_order'] = null;
//         record['index_options_that_apply'] = null;
//         record['answers_to_blanks'] = '[{"blank_1":["Answer $i"]}]';
//         break;
        
//       default:
//         throw ArgumentError('Unsupported question type: $questionType');
//     }
    
//     records.add(record);
//   }
  
//   return records;
// }

// /// Generates malformed question data for testing validation and error handling.
// /// This function creates intentionally invalid data to test how the system handles bad input.
// /// 
// /// Parameters:
// /// - malformationType: Type of malformation ('empty_module', 'empty_question', 'empty_answer', 'invalid_type', 'missing_options', 'invalid_options', 'malformed_json', 'wrong_data_types')
// /// - questionType: Base question type to malform (default: 'multiple_choice')
// /// - numberOfQuestions: Number of malformed questions to generate (default: 1)
// /// 
// /// Returns:
// /// - List of Map<String, dynamic> containing malformed question data
// List<Map<String, dynamic>> generateMalformedQuestionData({
//   required String malformationType,
//   String questionType = 'multiple_choice',
//   int numberOfQuestions = 1,
// }) {
//   final List<Map<String, dynamic>> malformedData = [];
  
//   for (int i = 0; i < numberOfQuestions; i++) {
//     Map<String, dynamic> questionData;
    
//     switch (malformationType) {
//       case 'empty_module':
//         questionData = {
//           'moduleName': '', // Empty module name
//           'questionElements': <Map<String, dynamic>>[{'type': 'text', 'content': 'Test question $i'}],
//           'answerElements': <Map<String, dynamic>>[{'type': 'text', 'content': 'Test answer $i'}],
//         };
//         // Add appropriate field based on question type
//         if (questionType == 'select_all_that_apply') {
//           questionData['options'] = <Map<String, dynamic>>[
//             {'type': 'text', 'content': 'Option A'},
//             {'type': 'text', 'content': 'Option B'},
//           ];
//           questionData['indexOptionsThatApply'] = <int>[0];
//         } else if (questionType == 'fill_in_the_blank') {
//           questionData['answersToBlanks'] = <Map<String, List<String>>>[{'answer1': ['answer1']}];
//         } else {
//           questionData['options'] = <Map<String, dynamic>>[
//             {'type': 'text', 'content': 'Option A'},
//             {'type': 'text', 'content': 'Option B'},
//           ];
//           questionData['correctOptionIndex'] = 0;
//         }
//         break;
        
//       case 'empty_question':
//         questionData = {
//           'moduleName': 'TestModule',
//           'questionElements': [], // Empty question elements
//           'answerElements': [{'type': 'text', 'content': 'Test answer $i'}],
//         };
//         break;
        
//       case 'empty_answer':
//         questionData = {
//           'moduleName': 'TestModule',
//           'questionElements': [{'type': 'text', 'content': 'Test question $i'}],
//           'answerElements': [], // Empty answer elements
//         };
//         break;
        
//       case 'invalid_type':
//         questionData = {
//           'moduleName': 'TestModule',
//           'questionElements': [{'type': 'text', 'content': 'Test question $i'}],
//           'answerElements': [{'type': 'text', 'content': 'Test answer $i'}],
//           'questionType': 'invalid_question_type', // Invalid question type
//         };
//         break;
        
//       case 'missing_options':
//         questionData = {
//           'moduleName': 'TestModule',
//           'questionElements': [{'type': 'text', 'content': 'Test question $i'}],
//           'answerElements': [{'type': 'text', 'content': 'Test answer $i'}],
//           // Missing options for multiple choice
//         };
//         break;
        
//       case 'invalid_options':
//         questionData = {
//           'moduleName': 'TestModule',
//           'questionElements': [{'type': 'text', 'content': 'Test question $i'}],
//           'answerElements': [{'type': 'text', 'content': 'Test answer $i'}],
//           'options': [{'type': 'text', 'content': 'Option A'}], // Only one option (invalid for multiple choice)
//           'correctOptionIndex': 1, // Index out of bounds
//         };
//         break;
        
//       case 'malformed_json':
//         questionData = {
//           'moduleName': 'TestModule',
//           'questionElements': '[{"type":"text","content":"Test question $i"', // Malformed JSON
//           'answerElements': '[{"type":"text","content":"Test answer $i"}]',
//         };
//         break;
        
//       case 'wrong_data_types':
//         questionData = {
//           'moduleName': 123, // Should be string
//           'questionElements': 'not_a_list', // Should be list
//           'answerElements': [{'type': 'text', 'content': 'Test answer $i'}],
//         };
//         break;
        
//       case 'negative_index':
//         questionData = {
//           'moduleName': 'TestModule',
//           'questionElements': [{'type': 'text', 'content': 'Test question $i'}],
//           'answerElements': [{'type': 'text', 'content': 'Test answer $i'}],
//           'options': [
//             {'type': 'text', 'content': 'Option A'},
//             {'type': 'text', 'content': 'Option B'},
//           ],
//           'correctOptionIndex': -1, // Negative index
//         };
//         break;
        
//       case 'empty_options':
//         questionData = {
//           'moduleName': 'TestModule',
//           'questionElements': <Map<String, dynamic>>[{'type': 'text', 'content': 'Test question $i'}],
//           'answerElements': <Map<String, dynamic>>[{'type': 'text', 'content': 'Test answer $i'}],
//           'options': <Map<String, dynamic>>[], // Empty options list
//         };
//         // Add appropriate field based on question type
//         if (questionType == 'select_all_that_apply') {
//           questionData['indexOptionsThatApply'] = <int>[];
//         } else {
//           questionData['correctOptionIndex'] = 0;
//         }
//         break;
        
//       case 'invalid_option_index':
//         questionData = {
//           'moduleName': 'TestModule',
//           'questionElements': [{'type': 'text', 'content': 'Test question $i'}],
//           'answerElements': [{'type': 'text', 'content': 'Test answer $i'}],
//           'options': [
//             {'type': 'text', 'content': 'Option A'},
//             {'type': 'text', 'content': 'Option B'},
//           ],
//         };
//         // Add appropriate field based on question type
//         if (questionType == 'select_all_that_apply') {
//           questionData['indexOptionsThatApply'] = <int>[5]; // Index out of bounds
//         } else {
//           questionData['correctOptionIndex'] = 5; // Index out of bounds
//         }
//         break;
        
//       case 'empty_question_elements':
//         questionData = {
//           'moduleName': 'TestModule',
//           'questionElements': <Map<String, dynamic>>[], // Empty question elements
//           'answerElements': <Map<String, dynamic>>[{'type': 'text', 'content': 'Test answer $i'}],
//         };
//         // Add appropriate field based on question type
//         if (questionType == 'select_all_that_apply') {
//           questionData['options'] = <Map<String, dynamic>>[
//             {'type': 'text', 'content': 'Option A'},
//             {'type': 'text', 'content': 'Option B'},
//           ];
//           questionData['indexOptionsThatApply'] = <int>[0];
//         } else if (questionType == 'fill_in_the_blank') {
//           questionData['answersToBlanks'] = <Map<String, List<String>>>[{'answer1': ['answer1']}];
//         } else {
//           questionData['options'] = <Map<String, dynamic>>[
//             {'type': 'text', 'content': 'Option A'},
//             {'type': 'text', 'content': 'Option B'},
//           ];
//           questionData['correctOptionIndex'] = 0;
//         }
//         break;
        
//       case 'empty_answer_elements':
//         questionData = {
//           'moduleName': 'TestModule',
//           'questionElements': <Map<String, dynamic>>[{'type': 'text', 'content': 'Test question $i'}],
//           'answerElements': <Map<String, dynamic>>[], // Empty answer elements
//         };
//         // Add appropriate field based on question type
//         if (questionType == 'select_all_that_apply') {
//           questionData['options'] = <Map<String, dynamic>>[
//             {'type': 'text', 'content': 'Option A'},
//             {'type': 'text', 'content': 'Option B'},
//           ];
//           questionData['indexOptionsThatApply'] = <int>[0];
//         } else if (questionType == 'fill_in_the_blank') {
//           questionData['answersToBlanks'] = <Map<String, List<String>>>[{'answer1': ['answer1']}];
//         } else {
//           questionData['options'] = <Map<String, dynamic>>[
//             {'type': 'text', 'content': 'Option A'},
//             {'type': 'text', 'content': 'Option B'},
//           ];
//           questionData['correctOptionIndex'] = 0;
//         }
//         break;
        
//       case 'negative_option_index':
//         questionData = {
//           'moduleName': 'TestModule',
//           'questionElements': [{'type': 'text', 'content': 'Test question $i'}],
//           'answerElements': [{'type': 'text', 'content': 'Test answer $i'}],
//           'options': [
//             {'type': 'text', 'content': 'Option A'},
//             {'type': 'text', 'content': 'Option B'},
//           ],
//         };
//         // Add appropriate field based on question type
//         if (questionType == 'select_all_that_apply') {
//           questionData['indexOptionsThatApply'] = <int>[-1]; // Negative index
//         } else {
//           questionData['correctOptionIndex'] = -1; // Negative index
//         }
//         break;
        
//       case 'empty_answers_to_blanks':
//         questionData = {
//           'moduleName': 'TestModule',
//           'questionElements': [
//             {'type': 'text', 'content': 'Test question $i'},
//             {'type': 'blank', 'content': '10'},
//           ],
//           'answerElements': [{'type': 'text', 'content': 'Test answer $i'}],
//           'answersToBlanks': <Map<String, List<String>>>[], // Empty answers to blanks
//         };
//         break;
        
//       case 'missing_blank_elements':
//         questionData = {
//           'moduleName': 'TestModule',
//           'questionElements': [{'type': 'text', 'content': 'Test question $i'}], // No blank elements
//           'answerElements': [{'type': 'text', 'content': 'Test answer $i'}],
//           'answersToBlanks': [{'blank_1': ['Answer $i']}], // But has answers to blanks
//         };
//         break;
        
//       case 'mismatched_blanks':
//         questionData = {
//           'moduleName': 'TestModule',
//           'questionElements': [
//             {'type': 'text', 'content': 'Test question $i'},
//             {'type': 'blank', 'content': '10'},
//             {'type': 'blank', 'content': '10'}, // Two blanks
//           ],
//           'answerElements': [{'type': 'text', 'content': 'Test answer $i'}],
//           'answersToBlanks': [{'blank_1': ['Answer $i']}], // Only one blank answered
//         };
//         break;
        
//       default:
//         throw ArgumentError('Unsupported malformation type: $malformationType');
//     }
    
//     malformedData.add(questionData);
//   }
  
//   return malformedData;
// }

// /// Generates properly formatted or malformed question/answer elements for testing.
// /// This function creates JSON strings that can be used for testing validation functions.
// /// 
// /// Parameters:
// /// - elementType: Type of element ('question' or 'answer')
// /// - formatType: Format type ('valid', 'malformed_json', 'missing_content', 'empty_array', 'whitespace_content', 'invalid_structure', 'complex_valid')
// /// - includeImage: Whether to include image elements (default: false)
// /// - numberOfElements: Number of elements to generate (default: 1)
// /// 
// /// Returns:
// /// - String containing the formatted elements as JSON
// String generateFormattedElements({
//   required String elementType,
//   required String formatType,
//   bool includeImage = false,
//   int numberOfElements = 1,
//   String? invalidImagePathType, // 'directory', 'absolute', 'url'
// }) {
//   switch (formatType) {
//     case 'valid':
//       final List<Map<String, dynamic>> elements = [];
//       for (int i = 0; i < numberOfElements; i++) {
//         elements.add({'type': 'text', 'content': '$elementType element $i'});
//         if (includeImage && i == numberOfElements - 1) {
//           elements.add({'type': 'image', 'content': '${elementType}_image_$i.png'});
//         }
//       }
//       return json.encode(elements);
      
//     case 'malformed_json':
//       return '[{"type":"text","content":"$elementType element"'; // Missing closing bracket
      
//     case 'missing_content':
//       return '[{"type":"text"}]'; // Missing content field
      
//     case 'empty_array':
//       return '[]';
      
//     case 'whitespace_content':
//       return '[{"type":"text","content":"   "}]'; // Whitespace-only content
      
//     case 'invalid_structure':
//       return 'not_a_json_array';
      
//     case 'complex_valid':
//       final List<Map<String, dynamic>> elements = [
//         {'type': 'text', 'content': 'Complex $elementType with multiple elements'},
//         {'type': 'text', 'content': 'More $elementType content'},
//       ];
      
//       if (includeImage) {
//         String imageContent = '${elementType}_image.png';
        
//         // Generate invalid image paths for testing
//         if (invalidImagePathType != null) {
//           switch (invalidImagePathType) {
//             case 'directory':
//               imageContent = 'path/to/${elementType}_image.png';
//               break;
//             case 'absolute':
//               imageContent = '/absolute/path/${elementType}_image.png';
//               break;
//             case 'url':
//               imageContent = 'https://example.com/${elementType}_image.png';
//               break;
//           }
//         }
        
//         elements.insert(1, {'type': 'image', 'content': imageContent});
//       }
      
//       return json.encode(elements);
      
//     default:
//       throw ArgumentError('Unsupported format type: $formatType');
//   }
// }

// // ========================

// /// Gets the correct answer for a question based on its type and data.
// /// 
// /// Parameters:
// /// - questionId: The question ID to get the correct answer for
// /// 
// /// Returns:
// /// - The correct answer in the appropriate format for the question type
// Future<dynamic> getCorrectAnswerForQuestion(String questionId) async {
//   QuizzerLogger.logMessage('Getting correct answer for question: $questionId');
  
//   // Handle dummy question case
//   if (questionId == 'dummy_no_questions') {
//     QuizzerLogger.logMessage('Handling dummy question - returning predefined answer');
//     // Return the correct answer for the dummy question (index 0 for 'Okay' option)
//     return 0;
//   }
  
//   try {
//     final Map<String, dynamic> questionDetails = await getQuestionAnswerPairById(questionId);
//     if (questionDetails.isEmpty) {
//       throw Exception('Question $questionId not found');
//     }
    
//     final String questionType = questionDetails['question_type'] as String;
    
//     switch (questionType) {
//       case 'multiple_choice':
//         // For multiple choice, the correct answer is the index stored in correct_option_index
//         final int? correctIndex = questionDetails['correct_option_index'] as int?;
//         if (correctIndex == null) {
//           throw Exception('No correct_option_index found for multiple choice question $questionId');
//         }
//         QuizzerLogger.logSuccess('Found correct multiple choice answer at index: $correctIndex');
//         return correctIndex;
        
//       case 'true_false':
//         // For true/false, the correct answer is the index stored in correct_option_index (0 for True, 1 for False)
//         final int? correctIndex = questionDetails['correct_option_index'] as int?;
//         if (correctIndex == null) {
//           throw Exception('No correct_option_index found for true/false question $questionId');
//         }
//         if (correctIndex != 0 && correctIndex != 1) {
//           throw Exception('Invalid correct_option_index ($correctIndex) for true/false question $questionId');
//         }
//         QuizzerLogger.logSuccess('Found correct true/false answer at index: $correctIndex');
//         return correctIndex;
        
//       case 'select_all_that_apply':
//         // For select all that apply, the correct answers are stored in index_options_that_apply
//         final List<dynamic> indexOptionsList = questionDetails['index_options_that_apply'] as List;
//         if (indexOptionsList.isEmpty) {
//           throw Exception('No index_options_that_apply found for select-all question $questionId');
//         }
        
//         // Convert the list to List<int>
//         final List<int> correctIndices = indexOptionsList
//             .map((item) => item as int)
//             .toList();
            
//         if (correctIndices.isEmpty) {
//           throw Exception('No valid indices found in index_options_that_apply for select-all question $questionId');
//         }
//         QuizzerLogger.logSuccess('Found correct select-all answers at indices: $correctIndices');
//         return correctIndices;
        
//       case 'sort_order':
//         // For sort order, the correct order is stored in the options field
//         final List<Map<String, dynamic>> options = List<Map<String, dynamic>>.from(questionDetails['options'] as List);
//         if (options.isEmpty) {
//           throw Exception('No options found for sort order question $questionId');
//         }
        
//         // Return the correct order as List<Map<String, dynamic>> with 'content' field
//         // The validation function expects each option to have a 'content' field
//         final List<Map<String, dynamic>> correctOrder = options
//             .map((option) => {
//               'content': option['content'] ?? option['text'] ?? option['type'],
//             })
//             .toList();
//         QuizzerLogger.logSuccess('Found correct sort order for question $questionId');
//         return correctOrder;
        
//       case 'fill_in_the_blank':
//         // For fill in the blank, extract the primary answers from answers_to_blanks
//         final List<dynamic> answersToBlanksList = questionDetails['answers_to_blanks'] as List;
//         if (answersToBlanksList.isEmpty) {
//           throw Exception('No answers_to_blanks found for fill_in_the_blank question $questionId');
//         }
        
//         // Extract the primary answer (key) from each blank's answer group
//         final List<String> correctAnswers = answersToBlanksList
//             .map((blankAnswers) => (blankAnswers as Map<String, dynamic>).keys.first)
//             .toList();
//         QuizzerLogger.logSuccess('Found correct fill_in_the_blank answers for question $questionId');
//         return correctAnswers;
        
//       default:
//         throw Exception('Unsupported question type: $questionType');
//     }
//   } catch (e) {
//     QuizzerLogger.logError('Error getting correct answer for question $questionId: $e');
//     rethrow;
//   }
// }


// /// Gets the count of questions in the review tables from Supabase.
// /// 
// /// Returns:
// /// - Map containing counts for both review tables
// Future<Map<String, int>> getReviewTableCounts() async {
//   try {
//     final sessionManager = getSessionManager();
//     final supabase = sessionManager.supabase;
    
//     // Get count from new review table
//     final int newReviewCount = await supabase
//         .from('question_answer_pair_new_review')
//         .count(CountOption.exact);
    
//     // Get count from edits review table  
//     final int editsReviewCount = await supabase
//         .from('question_answer_pair_edits_review')
//         .count(CountOption.exact);
    
//     final Map<String, int> counts = {
//       'new_review_count': newReviewCount,
//       'edits_review_count': editsReviewCount,
//       'total_review_count': newReviewCount + editsReviewCount,
//     };
    
//     return counts;
//   } catch (e) {
//     QuizzerLogger.logError('Error getting review table counts: $e');
//     rethrow;
//   }
// }

// /// Loads the subject taxonomy JSON file and extracts all subjects with their immediate parents.
// /// 
// /// Returns:
// /// - List<Map<String, String>> where each map contains 'subject' and 'immediate_parent'
// Future<List<Map<String, String>>> extractAllSubjectsFromTaxonomy() async {
//   // Load the subject taxonomy JSON file
//   final file = File('runtime_cache/subject_data/subject_taxonomy.json');
//   final jsonString = await file.readAsString();
//   final Map<String, dynamic> taxonomy = json.decode(jsonString);
  
//   final List<Map<String, String>> allSubjects = [];
  
//   void traverseSubjects(Map<String, dynamic> subjects, String? parentSubject) {
//     for (final entry in subjects.entries) {
//       final String subjectName = entry.key;
//       final Map<String, dynamic> children = entry.value as Map<String, dynamic>;
      
//       // Add this subject with its parent
//       allSubjects.add({
//         'subject': subjectName,
//         'immediate_parent': parentSubject ?? '',
//       });
      
//       // Recursively process children if they exist
//       if (children.isNotEmpty) {
//         traverseSubjects(children, subjectName);
//       }
//     }
//   }
  
//   // Start the recursive traversal
//   traverseSubjects(taxonomy, null);
  
//   return allSubjects;
// }

// /// Extracts duplicate subjects from the taxonomy data.
// /// 
// /// Returns:
// /// - Map<String, List<String>> where key is the subject name and value is list of all its parents
// Future<Map<String, List<String>>> extractDuplicateSubjectsFromTaxonomy() async {
//   // Load the subject taxonomy JSON file
//   final file = File('runtime_cache/subject_data/subject_taxonomy.json');
//   final jsonString = await file.readAsString();
//   final Map<String, dynamic> taxonomy = json.decode(jsonString);
  
//   final Map<String, List<String>> subjectParents = {};
  
//   void traverseSubjects(Map<String, dynamic> subjects, String? parentSubject) {
//     for (final entry in subjects.entries) {
//       final String subjectName = entry.key;
//       final Map<String, dynamic> children = entry.value as Map<String, dynamic>;
      
//       // Add this subject with its parent
//       if (subjectParents.containsKey(subjectName)) {
//         // Subject already exists, add this parent to the list
//         subjectParents[subjectName]!.add(parentSubject ?? '');
//       } else {
//         // First occurrence of this subject
//         subjectParents[subjectName] = [parentSubject ?? ''];
//       }
      
//       // Recursively process children if they exist
//       if (children.isNotEmpty) {
//         traverseSubjects(children, subjectName);
//       }
//     }
//   }
  
//   // Start the recursive traversal
//   traverseSubjects(taxonomy, null);
  
//   // Filter to only subjects that have multiple parents (duplicates)
//   final Map<String, List<String>> duplicates = {};
//   for (final entry in subjectParents.entries) {
//     if (entry.value.length > 1) {
//       duplicates[entry.key] = entry.value;
//     }
//   }
  
//   return duplicates;
// }

// /// Gets the count of unique subjects in the taxonomy
// /// This is different from the total count because some subjects appear multiple times
// Future<int> getUniqueSubjectCountFromTaxonomy() async {
//   try {
//     // Use the existing function to get all subjects
//     final List<Map<String, String>> allSubjects = await extractAllSubjectsFromTaxonomy();
    
//     // Extract unique subject names using a Set
//     final Set<String> uniqueSubjects = allSubjects.map((subject) => subject['subject']!).toSet();
    
//     return uniqueSubjects.length;
//   } catch (e) {
//     QuizzerLogger.logError('Error getting unique subject count from taxonomy: $e');
//     rethrow;
//   }
// }

// // ==========================================
// // Supabase Pagination Helper Functions
// // ==========================================

// /// Fetches ALL records from a Supabase table using proper pagination.
// /// 
// /// Parameters:
// /// - tableName: The name of the table to fetch records from
// /// 
// /// Returns:
// /// - List<Map<String, dynamic>> containing ALL records from the table
// Future<List<Map<String, dynamic>>> fetchAllRecordsFromSupabaseTable(String tableName) async {
//   QuizzerLogger.logMessage('Fetching ALL records from table: $tableName');
  
//   try {
//     final sessionManager = getSessionManager();
//     final supabase = sessionManager.supabase;
    
//     // First get the total count
//     final int totalCount = await supabase
//         .from(tableName)
//         .count(CountOption.exact);
    
//     QuizzerLogger.logMessage('Total records in table: $totalCount');
    
//     final List<Map<String, dynamic>> allRecords = [];
//     int offset = 0;
//     const int pageSize = 500;
    
//     while (allRecords.length < totalCount) {
//       QuizzerLogger.logMessage('Fetching page starting at offset: $offset');
      
//       // Execute the query with range
//       final List<Map<String, dynamic>> pageData = await supabase
//           .from(tableName)
//           .select()
//           .range(offset, offset + pageSize - 1);
      
//       QuizzerLogger.logMessage('Fetched ${pageData.length} records');
      
//       // Add the page data to our accumulated results
//       allRecords.addAll(pageData);
      
//       // Move to next page
//       offset += pageSize;
//     }
    
//     QuizzerLogger.logSuccess('Successfully fetched ALL ${allRecords.length} records from table: $tableName');
//     return allRecords;
    
//   } catch (e) {
//     QuizzerLogger.logError('Error fetching all records from table $tableName: $e');
//     rethrow;
//   }
// }

// /// Fetches ALL records from a local SQLite table.
// /// 
// /// Parameters:
// /// - tableName: The name of the table to fetch records from
// /// 
// /// Returns:
// /// - List<Map<String, dynamic>> containing ALL records from the local table
// Future<List<Map<String, dynamic>>> getAllRecordsFromLocalTable(String tableName) async {
//   QuizzerLogger.logMessage('Fetching ALL records from local table: $tableName');
  
//   try {
//     final db = await getDatabaseMonitor().requestDatabaseAccess();
//     if (db == null) {
//       throw Exception('Failed to acquire database access');
//     }
    
//     final List<Map<String, dynamic>> allRecords = await db.query(tableName);
    
//     QuizzerLogger.logSuccess('Successfully fetched ${allRecords.length} records from local table: $tableName');
//     return allRecords;
    
//   } catch (e) {
//     QuizzerLogger.logError('Error fetching all records from local table $tableName: $e');
//     rethrow;
//   } finally {
//     getDatabaseMonitor().releaseDatabaseAccess();
//   }
// }

// /// Sends a batch of records to Supabase using async gather functionality.
// /// Processes updates in chunks of 100 to avoid flooding the server.
// /// 
// /// Parameters:
// /// - tableName: The name of the table to update
// /// - batchUpdates: List of update operations, each containing the data to update
// /// - updateFunction: Function that performs the actual update operation
// /// - chunkSize: Number of updates to process at once (default: 100)
// /// 
// /// Returns:
// /// - Number of successful updates
// Future<int> batchUpdateRecords<T>({
//   required String tableName,
//   required List<T> batchUpdates,
//   required Future<bool> Function(T update) updateFunction,
//   int chunkSize = 100,
// }) async {
//   QuizzerLogger.logMessage('Processing batch of ${batchUpdates.length} updates for table: $tableName in chunks of $chunkSize');
  
//   try {
//     int totalSuccessfulUpdates = 0;
//     int totalFailedUpdates = 0;
    
//     // Process updates in chunks
//     for (int i = 0; i < batchUpdates.length; i += chunkSize) {
//       final int endIndex = (i + chunkSize < batchUpdates.length) ? i + chunkSize : batchUpdates.length;
//       final List<T> chunk = batchUpdates.sublist(i, endIndex);
      
//       QuizzerLogger.logMessage('Processing chunk ${(i ~/ chunkSize) + 1}: ${chunk.length} updates (${i + 1}-$endIndex of ${batchUpdates.length})');
      
//       // Use Future.wait to process this chunk concurrently
//       final List<Future<bool>> updateFutures = chunk.map(updateFunction).toList();
//       final List<bool> results = await Future.wait(updateFutures);
      
//       // Count successful updates in this chunk
//       final int successfulUpdates = results.where((result) => result).length;
//       final int failedUpdates = results.length - successfulUpdates;
      
//       totalSuccessfulUpdates += successfulUpdates;
//       totalFailedUpdates += failedUpdates;
      
//       QuizzerLogger.logMessage('Chunk ${(i ~/ chunkSize) + 1} completed: $successfulUpdates successful, $failedUpdates failed');
      
//       // Add a small delay between chunks to be nice to the server
//       if (endIndex < batchUpdates.length) {
//         await Future.delayed(const Duration(milliseconds: 100));
//       }
//     }
    
//     QuizzerLogger.logSuccess('Batch update completed: $totalSuccessfulUpdates successful, $totalFailedUpdates failed');
    
//     return totalSuccessfulUpdates;
    
//   } catch (e) {
//     QuizzerLogger.logError('Error in batch update for table $tableName: $e');
//     rethrow;
//   }
// }

// // ==========================================
// // Helper Function to Cleanup Test Questions
// // ==========================================

// /// Cleans up test questions by deleting them from both local database and Supabase.
// /// 
// /// Parameters:
// /// - questionIds: List of question IDs to delete
// /// 
// /// This function safely deletes questions from both local database and Supabase,
// /// handling any errors that occur during the cleanup process. It ensures database access is properly 
// /// released even if errors occur.
// Future<void> cleanupTestQuestions(List<String> questionIds) async {
//   QuizzerLogger.logMessage('Cleaning up ${questionIds.length} test questions from local database and Supabase');
  
//   // Get Supabase client
//   final sessionManager = getSessionManager();
//   final supabase = sessionManager.supabase;
  
//   for (final String questionId in questionIds) {
//     try {
//       // First delete from Supabase tables
//       try {
//         // Delete from new_review table
//         await supabase
//           .from('question_answer_pair_new_review')
//           .delete()
//           .eq('question_id', questionId);
//         QuizzerLogger.logMessage('Deleted question $questionId from new_review table');
//       } catch (e) {
//         // Question might not exist in this table, which is fine
//         QuizzerLogger.logMessage('Question $questionId not found in new_review table (or already deleted)');
//       }
      
//       try {
//         // Delete from edits_review table
//         await supabase
//           .from('question_answer_pair_edits_review')
//           .delete()
//           .eq('question_id', questionId);
//         QuizzerLogger.logMessage('Deleted question $questionId from edits_review table');
//       } catch (e) {
//         // Question might not exist in this table, which is fine
//         QuizzerLogger.logMessage('Question $questionId not found in edits_review table (or already deleted)');
//       }
      
//       try {
//         // Delete from main table (in case they were manually inserted for testing)
//         await supabase
//           .from('question_answer_pairs')
//           .delete()
//           .eq('question_id', questionId);
//         QuizzerLogger.logMessage('Deleted question $questionId from main table');
//       } catch (e) {
//         // Question might not exist in this table, which is fine
//         QuizzerLogger.logMessage('Question $questionId not found in main table (or already deleted)');
//       }
      
//       // Then delete from local database
//       final db = await getDatabaseMonitor().requestDatabaseAccess();
//       if (db != null) {
//         final int deletedCount = await db.delete(
//           'question_answer_pairs',
//           where: 'question_id = ?',
//           whereArgs: [questionId],
//         );
        
//         if (deletedCount > 0) {
//           QuizzerLogger.logMessage('Successfully deleted question: $questionId from local database');
//         } else {
//           QuizzerLogger.logWarning('Question not found for deletion in local database: $questionId');
//         }
//       }
//     } catch (e) {
//       QuizzerLogger.logError('Failed to cleanup question $questionId: $e');
//     } finally {
//       getDatabaseMonitor().releaseDatabaseAccess();
//     }
//   }
  
//   QuizzerLogger.logSuccess('Test question cleanup completed for both local database and Supabase');
// }

// /// Cleans up test modules by deleting them and their associated questions from both local database and Supabase.
// /// 
// /// Parameters:
// /// - moduleNames: List of module names to delete
// /// 
// /// This function safely deletes modules and their questions from both local database and Supabase,
// /// handling any errors that occur during the cleanup process. It ensures database access is properly 
// /// released even if errors occur.
// Future<void> cleanupTestModules(List<String> moduleNames) async {
//   QuizzerLogger.logMessage('Cleaning up ${moduleNames.length} test modules from local database and Supabase');
  
//   // Get Supabase client
//   final sessionManager = getSessionManager();
//   final supabase = sessionManager.supabase;
  
//   for (final String moduleName in moduleNames) {
//     try {
//       final db = await getDatabaseMonitor().requestDatabaseAccess();
//       if (db != null) {
//         // First get all question IDs associated with this module for Supabase cleanup
//         final List<Map<String, dynamic>> moduleQuestions = await db.query(
//           'question_answer_pairs',
//           where: 'module_name = ?',
//           whereArgs: [moduleName],
//         );
        
//         final List<String> questionIds = moduleQuestions.map((q) => q['question_id'] as String).toList();
        
//         // Delete questions from Supabase tables
//         if (questionIds.isNotEmpty) {
//           QuizzerLogger.logMessage('Cleaning up ${questionIds.length} questions from Supabase for module: $moduleName');
          
//           // Delete from new_review table
//           for (final questionId in questionIds) {
//             try {
//               await supabase
//                 .from('question_answer_pair_new_review')
//                 .delete()
//                 .eq('question_id', questionId);
//             } catch (e) {
//               // Question might not exist in this table, which is fine
//               QuizzerLogger.logMessage('Question $questionId not found in new_review table (or already deleted)');
//             }
//           }
          
//           // Delete from edits_review table
//           for (final questionId in questionIds) {
//             try {
//               await supabase
//                 .from('question_answer_pair_edits_review')
//                 .delete()
//                 .eq('question_id', questionId);
//             } catch (e) {
//               // Question might not exist in this table, which is fine
//               QuizzerLogger.logMessage('Question $questionId not found in edits_review table (or already deleted)');
//             }
//           }
          
//           // Delete from main table (in case they were manually inserted for testing)
//           for (final questionId in questionIds) {
//             try {
//               await supabase
//                 .from('question_answer_pairs')
//                 .delete()
//                 .eq('question_id', questionId);
//             } catch (e) {
//               // Question might not exist in this table, which is fine
//               QuizzerLogger.logMessage('Question $questionId not found in main table (or already deleted)');
//             }
//           }
          
//           QuizzerLogger.logMessage('Successfully cleaned up ${questionIds.length} questions from Supabase for module: $moduleName');
//         }
        
//         // Delete all questions associated with this module from local database
//         final int questionsDeleted = await db.delete(
//           'question_answer_pairs',
//           where: 'module_name = ?',
//           whereArgs: [moduleName],
//         );
        
//         if (questionsDeleted > 0) {
//           QuizzerLogger.logMessage('Deleted $questionsDeleted questions from local database for module: $moduleName');
//         }
        
//         // Then delete the module itself from local database
//         final int moduleDeleted = await db.delete(
//           'modules',
//           where: 'module_name = ?',
//           whereArgs: [moduleName],
//         );
        
//         if (moduleDeleted > 0) {
//           QuizzerLogger.logMessage('Successfully deleted module: $moduleName from local database');
//         } else {
//           QuizzerLogger.logWarning('Module not found for deletion in local database: $moduleName');
//         }
//       }
//     } catch (e) {
//       QuizzerLogger.logError('Failed to cleanup module $moduleName: $e');
//     } finally {
//       getDatabaseMonitor().releaseDatabaseAccess();
//     }
//   }
  
//   QuizzerLogger.logSuccess('Test module cleanup completed for both local database and Supabase');
// }

// /// Adds test questions to the local database using the session manager.
// /// This helper function generates question data and adds it to the database
// /// using the session manager's addNewQuestion method.
// /// 
// /// Parameters:
// /// - questionType: String - Type of question to generate ('multiple_choice', 'select_all_that_apply', 'true_false', 'sort_order', 'fill_in_the_blank')
// /// - numberOfQuestions: int - Number of questions to add (default: 1)
// /// - customModuleName: String? - Optional custom module name to use for all questions (default: null)
// /// - numberOfOptions: int - Number of options for multiple choice/select all questions (default: 4)
// /// - numberOfBlanks: int - Number of blanks for fill-in-the-blank questions (default: 1)
// /// - numberOfSynonymsPerBlank: int - Number of synonyms per blank (default: 2)
// /// - randomNumberOfOptions: bool - Whether to randomize number of options (default: false)
// /// - randomNumberOfBlanks: bool - Whether to randomize number of blanks (default: false)
// /// - randomNumberOfSynonyms: bool - Whether to randomize number of synonyms per blank (default: false)
// /// - includeMedia: bool - Whether to include image elements in questions and answers (default: false)
// /// 
// /// Returns:
// /// - List<String> - List of question IDs that were added to the database
// Future<List<String>> addTestQuestionsToLocalDatabase({
//   required String questionType,
//   int numberOfQuestions = 1,
//   String? customModuleName,
//   int numberOfOptions = 4,
//   int numberOfBlanks = 1,
//   int numberOfSynonymsPerBlank = 2,
//   bool randomNumberOfOptions = false,
//   bool randomNumberOfBlanks = false,
//   bool randomNumberOfSynonyms = false,
//   bool includeMedia = false,
// }) async {
//   QuizzerLogger.logMessage('Adding $numberOfQuestions $questionType questions to local database');
  
//   final sessionManager = getSessionManager();
//   final List<String> addedQuestionIds = [];
  
//   try {
//     // Generate question input data
//     final List<Map<String, dynamic>> inputData = generateQuestionInputData(
//       questionType: questionType,
//       numberOfQuestions: numberOfQuestions,
//       customModuleName: customModuleName,
//       numberOfOptions: numberOfOptions,
//       numberOfBlanks: numberOfBlanks,
//       numberOfSynonymsPerBlank: numberOfSynonymsPerBlank,
//       randomNumberOfOptions: randomNumberOfOptions,
//       randomNumberOfBlanks: randomNumberOfBlanks,
//       randomNumberOfSynonyms: randomNumberOfSynonyms,
//       includeMedia: includeMedia,
//     );
    
//     // Add each question to the database
//     for (final Map<String, dynamic> input in inputData) {
//       await sessionManager.addNewQuestion(
//         questionType: input['questionType'],
//         questionElements: input['questionElements'],
//         answerElements: input['answerElements'],
//         options: input['options'],
//         correctOptionIndex: input['correctOptionIndex'],
//         indexOptionsThatApply: input['indexOptionsThatApply'],
//         answersToBlanks: input['answersToBlanks'],
//       );
      
//       // Note: We can't easily get the question ID from addNewQuestion since it doesn't return it
//       // The question ID is generated internally by the session manager
//       // For now, we'll just track that we added a question
//       addedQuestionIds.add('added_${addedQuestionIds.length + 1}');
//     }
    
//     QuizzerLogger.logSuccess('Successfully added $numberOfQuestions $questionType questions to local database');
//     return addedQuestionIds;
    
//   } catch (e) {
//     QuizzerLogger.logError('Error adding test questions to local database: $e');
//     rethrow;
//   }
// }

// /// Generates a list of mock user settings with non-default values for testing.
// ///
// /// Parameters:
// /// - userId: The user ID to associate with the mock settings.
// ///
// /// Returns:
// /// - A list of maps, where each map represents a user setting record.
// List<Map<String, dynamic>> generateMockUserSettings(String userId) {
//   return [
//     {
//       'user_id': userId,
//       'setting_name': 'geminiApiKey',
//       'setting_value': 'test-api-key-12345',
//       'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
//       'is_admin_setting': true,
//     },
//     {
//       'user_id': userId,
//       'setting_name': 'home_display_eligible_questions',
//       'setting_value': '1',
//       'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
//       'is_admin_setting': false,
//     },
//     {
//       'user_id': userId,
//       'setting_name': 'home_display_in_circulation_questions',
//       'setting_value': '1',
//       'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
//       'is_admin_setting': false,
//     },
//     {
//       'user_id': userId,
//       'setting_name': 'home_display_non_circulating_questions',
//       'setting_value': '1',
//       'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
//       'is_admin_setting': false,
//     },
//     {
//       'user_id': userId,
//       'setting_name': 'home_display_lifetime_total_questions_answered',
//       'setting_value': '1',
//       'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
//       'is_admin_setting': false,
//     },
//     {
//       'user_id': userId,
//       'setting_name': 'home_display_daily_questions_answered',
//       'setting_value': '1',
//       'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
//       'is_admin_setting': false,
//     },
//     {
//       'user_id': userId,
//       'setting_name': 'home_display_average_daily_questions_learned',
//       'setting_value': '1',
//       'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
//       'is_admin_setting': false,
//     },
//     {
//       'user_id': userId,
//       'setting_name': 'home_display_average_questions_shown_per_day',
//       'setting_value': '1',
//       'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
//       'is_admin_setting': false,
//     },
//     {
//       'user_id': userId,
//       'setting_name': 'home_display_days_left_until_questions_exhaust',
//       'setting_value': '1',
//       'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
//       'is_admin_setting': false,
//     },
//     {
//       'user_id': userId,
//       'setting_name': 'home_display_revision_streak_score',
//       'setting_value': '1',
//       'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
//       'is_admin_setting': false,
//     },
//     {
//       'user_id': userId,
//       'setting_name': 'home_display_last_reviewed',
//       'setting_value': '1',
//       'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
//       'is_admin_setting': false,
//     },
//   ];
// }

// /// Reset local state to replicate a "fresh device"
// /// 
// /// This function performs a complete reset of the local device state by:
// /// 1. Deleting the entire QuizzerApp/sqlite directory containing the SQLite database
// /// 2. Deleting the entire QuizzerAppMedia directory containing media files and staging
// /// 3. Deleting the entire QuizzerAppHive directory containing Hive persistent data
// /// 4. Deleting the entire QuizzerAppLogs directory containing log files
// /// 
// /// This simulates a device that has never had the app installed, ensuring no
// /// cached data, user preferences, or previous session information remains.
// /// 
// /// Use this function when testing scenarios that require a completely clean
// /// local state, such as first-time app launches or device migration testing.
// Future<void> resetToFreshDevice() async {
//   QuizzerLogger.logMessage('Resetting to fresh device state...');
  
//   try {
//     // Get all the app data paths
//     final dbPath = await getQuizzerDatabasePath();
//     final dbDir = Directory(dbPath).parent;
//     final mediaPath = await getQuizzerMediaPath();
//     final mediaDir = Directory(mediaPath).parent;
//     final hivePath = await getQuizzerHivePath();
//     final hiveDir = Directory(hivePath);
//     final logsPath = await getQuizzerLogsPath();
//     final logsDir = Directory(logsPath);
    
//     // Delete database directory and contents
//     if (await dbDir.exists()) {
//       await dbDir.delete(recursive: true);
//       QuizzerLogger.logMessage('Database directory and contents deleted');
//     }
    
//     // Delete media directory and contents
//     if (await mediaDir.exists()) {
//       await mediaDir.delete(recursive: true);
//       QuizzerLogger.logMessage('Media directory and contents deleted');
//     }
    
//     // Delete Hive directory and contents
//     if (await hiveDir.exists()) {
//       await hiveDir.delete(recursive: true);
//       QuizzerLogger.logMessage('Hive directory and contents deleted');
//     }
    
//     // Delete logs directory and contents
//     if (await logsDir.exists()) {
//       await logsDir.delete(recursive: true);
//       QuizzerLogger.logMessage('Logs directory and contents deleted');
//     }
    
//     QuizzerLogger.logSuccess('Fresh device reset complete - all app data removed');
//   } catch (e) {
//     QuizzerLogger.logError('Error during fresh device reset: $e');
//     rethrow;
//   }
// }

// /// Deletes all user settings records for a given user on Supabase
// /// 
// /// This function removes all settings records from the Supabase server
// /// for the specified user, typically used for test cleanup.
// /// 
// /// Parameters:
// /// - userId: The user ID whose settings should be deleted
// /// 
// /// Throws:
// /// - Exception if the deletion operation fails
// Future<void> deleteAllUserSettingsOnSupabase(String userId) async {
//   QuizzerLogger.logMessage('Deleting all user settings on Supabase for user $userId');
  
//   try {
//     final sessionManager = getSessionManager();
    
//     // Delete all settings records for this user from Supabase
//     await sessionManager.supabase
//         .from('user_settings')
//         .delete()
//         .eq('user_id', userId);
    
//     QuizzerLogger.logSuccess('Successfully deleted all user settings on Supabase for user $userId');
//   } catch (e) {
//     QuizzerLogger.logError('Error deleting user settings on Supabase: $e');
//     rethrow;
//   }
// }

