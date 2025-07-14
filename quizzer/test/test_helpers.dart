import 'dart:io';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart' as uqap_table;
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'dart:math'; // Import for max function
// import 'dart:convert'; // ADDED for jsonDecode
// import 'dart:io'; // ADDED for File operations

// ==========================================
// Helper Function to Log Current Question Details
// ==========================================
Future<void> logCurrentQuestionDetails(SessionManager manager) async {
  QuizzerLogger.logMessage("--- Logging Current Question Details (All Fields) ---");
  // Access the underlying map directly via the getter
  final Map<String, dynamic>? details = manager.currentQuestionStaticData; 

  if (details == null) {
    QuizzerLogger.logValue("currentQuestionStaticData: null");
    QuizzerLogger.printDivider();
    return;
  }

  // Check if it's the dummy question (can check a known field like question_id)
  if (details['question_id'] == null) {
     QuizzerLogger.logValue("currentQuestionStaticData: Dummy 'No Questions' Record");
  } else {
    // Iterate through all key-value pairs in the map and log them
    QuizzerLogger.logMessage("Raw _currentQuestionDetails Map:");
    details.forEach((key, value) {
      QuizzerLogger.logValue("  $key: $value");
    });
  }
  QuizzerLogger.printDivider();
}

// ==========================================
// Helper Function to Log Current User Question Record Details
// ==========================================
Future<void> logCurrentUserQuestionRecordDetails(SessionManager manager) async {
  QuizzerLogger.logMessage("--- Logging Current User Question Record Details ---");
  final record = manager.currentQuestionUserRecord;

  if (record == null) {
    QuizzerLogger.logValue("currentQuestionUserRecord: null");
    QuizzerLogger.printDivider();
    return;
  }

  // Log each key-value pair in the record
  record.forEach((key, value) {
    QuizzerLogger.logValue("  $key: $value");
  });

  QuizzerLogger.printDivider();
}

// ==========================================
// Helper Function to Generate Random MC Answer
// ==========================================
int? getRandomMultipleChoiceAnswer(SessionManager manager) {
  QuizzerLogger.logMessage("--- Generating Random Multiple Choice Answer ---");
  final details = manager.currentQuestionStaticData;

  if (details == null) {
    QuizzerLogger.logWarning("Cannot generate answer: currentQuestionStaticData is null.");
    QuizzerLogger.printDivider();
    return null;
  }

  if (manager.currentQuestionType != 'multiple_choice') {
    QuizzerLogger.logWarning(
        "Cannot generate MC answer: Current question type is '${manager.currentQuestionType}'.");
    QuizzerLogger.printDivider();
    return null;
  }

  final options = manager.currentQuestionOptions;
  if (options.isEmpty) {
    QuizzerLogger.logError(
        "Cannot generate MC answer: Options list is empty.");
    QuizzerLogger.printDivider();
    return null; // Or throw an error, depending on desired strictness
  }

  final randomIndex = Random().nextInt(options.length);
  QuizzerLogger.logValue("Selected random option index: $randomIndex");
  QuizzerLogger.printDivider();
  return randomIndex;
}

// ==========================================
// Helper Function to Generate Random Select-All Answer
// ==========================================
/// Generates a random answer (List<int>) for a select_all_that_apply question.
/// Randomly selects a number of options and returns their indices.
List<int>? getRandomSelectAllAnswer(SessionManager manager) {
  QuizzerLogger.logMessage("--- Generating Random Select-All-That-Apply Answer ---");
  final details = manager.currentQuestionStaticData;

  if (details == null) {
    QuizzerLogger.logWarning("Cannot generate answer: currentQuestionStaticData is null.");
    QuizzerLogger.printDivider();
    return null;
  }

  if (manager.currentQuestionType != 'select_all_that_apply') {
    QuizzerLogger.logWarning(
        "Cannot generate Select-All answer: Current question type is '${manager.currentQuestionType}'.");
    QuizzerLogger.printDivider();
    return null;
  }

  final options = manager.currentQuestionOptions; // This is List<Map<String, dynamic>>
  final optionCount = options.length;

  if (optionCount == 0) {
    QuizzerLogger.logError(
        "Cannot generate Select-All answer: Options list is empty.");
    QuizzerLogger.printDivider();
    return []; // Return empty list if no options exist
  }

  final random = Random();
  // Determine how many options to select (at least 1, up to total options)
  final int numSelections = random.nextInt(optionCount) + 1; 
  
  final Set<int> selectedIndicesSet = {};
  // Randomly pick unique indices
  while (selectedIndicesSet.length < numSelections) {
    selectedIndicesSet.add(random.nextInt(optionCount)); // Indices 0 to optionCount-1
  }

  final List<int> selectedIndicesList = selectedIndicesSet.toList();
  // Optionally sort for consistency, though validation doesn't require it
  selectedIndicesList.sort(); 

  QuizzerLogger.logValue("Selected random indices: $selectedIndicesList");
  QuizzerLogger.printDivider();
  return selectedIndicesList;
}

// ==========================================
// Helper Function to Generate Random Sort Order Answer
// ==========================================
/// Generates a randomly shuffled answer (List<Map<String, dynamic>>) for a sort_order question.
/// Takes the correctly ordered options from the SessionManager and shuffles them.
List<Map<String, dynamic>>? getRandomSortOrderAnswer(SessionManager manager) {
  QuizzerLogger.logMessage("--- Generating Random Sort Order Answer ---");
  final details = manager.currentQuestionStaticData;

  if (details == null) {
    QuizzerLogger.logWarning("Cannot generate answer: currentQuestionStaticData is null.");
    QuizzerLogger.printDivider();
    return null;
  }

  if (manager.currentQuestionType != 'sort_order') {
    QuizzerLogger.logWarning(
        "Cannot generate Sort Order answer: Current question type is '${manager.currentQuestionType}'.");
    QuizzerLogger.printDivider();
    return null;
  }

  final options = manager.currentQuestionOptions; // This is List<Map<String, dynamic>> representing the correct order
  
  if (options.isEmpty) {
    QuizzerLogger.logError(
        "Cannot generate Sort Order answer: Options list (correct order) is empty.");
    QuizzerLogger.printDivider();
    return []; // Return empty list if no options exist
  }

  // Create a mutable copy of the options list to shuffle
  final List<Map<String, dynamic>> shuffledOptions = List.from(options);
  
  // Shuffle the copy randomly
  shuffledOptions.shuffle(Random()); 

  QuizzerLogger.logValue("Generated shuffled order."); // Don't log the full shuffled list, could be large
  QuizzerLogger.printDivider();
  return shuffledOptions;
}

// ==========================================
// Helper Function for Waiting
// ==========================================
Future<void> waitTime(int milliseconds) async {
  final double seconds = milliseconds / 1000.0;
  QuizzerLogger.logMessage("Waiting for ${seconds.toStringAsFixed(1)} seconds...");
  await Future.delayed(Duration(milliseconds: milliseconds));
  QuizzerLogger.logMessage("Wait complete.");
}

// ==========================================
// Helper Function to Log User Record From DB
// ==========================================
Future<void> logCurrentUserRecordFromDB(SessionManager manager) async {
  QuizzerLogger.logMessage("--- Logging Current User Question Record from DB ---");
  final dbMonitor = getDatabaseMonitor(); // Get monitor instance
  final userId = manager.userId;
  final questionId = manager.currentQuestionStaticData?['question_id'] as String?;

  if (userId == null) {
    QuizzerLogger.logWarning("Cannot log from DB: User not logged in (userId is null).");
    QuizzerLogger.printDivider();
    return;
  }
  if (questionId == null) {
    QuizzerLogger.logWarning("Cannot log from DB: No current question loaded (questionId is null).");
    QuizzerLogger.printDivider();
    return;
  }

  Database? db;
  db = await dbMonitor.requestDatabaseAccess();
  if (db == null) {
    // Fail fast if DB is unavailable during the test
    throw StateError('Database access unavailable during test logging.');
  }

  final Map<String, dynamic> record = await uqap_table.getUserQuestionAnswerPairById(
    userId,      // Positional argument 1
    questionId,  // Positional argument 2
  );

  // Release lock IMMEDIATELY after the DB operation completes or throws
  dbMonitor.releaseDatabaseAccess();
  QuizzerLogger.logMessage("DB access released.");
  db = null; // Prevent reuse after release


  // Log the record
  QuizzerLogger.logMessage("DB Record for User: $userId, Question: $questionId");
  record.forEach((key, value) {
    QuizzerLogger.logValue("  $key: $value");
  });
    
  QuizzerLogger.printDivider();
}

// ==========================================
// Helper Function to Truncate ALL Tables
// ==========================================

/// Deletes all rows from ALL user-defined tables in the database.
/// Queries sqlite_master to find tables.
/// USE WITH EXTREME CAUTION - This clears ALL data.
Future<void> truncateAllTables(Database db) async {
  QuizzerLogger.printHeader("--- TRUNCATING ALL DATABASE TABLES --- ");

  // 1. Get all user-defined table names
  QuizzerLogger.logMessage("Fetching list of all user tables...");
  // Exclude sqlite system tables and android metadata table
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'"
  );

  if (tables.isEmpty) {
    QuizzerLogger.logWarning("No user tables found to truncate.");
    QuizzerLogger.printHeader("--- TABLE TRUNCATION COMPLETE (No tables found) --- ");
    return;
  }

  final List<String> tableNames = tables.map((row) => row['name'] as String).toList();
  QuizzerLogger.logValue("Tables to truncate: ${tableNames.join(', ')}");

  // 2. Truncate each table (DELETE FROM)
  // If any delete fails, an exception will be thrown (Fail Fast)
  for (final tableName in tableNames) {
    QuizzerLogger.logMessage("Truncating table: $tableName...");
    final int rowsDeleted = await db.delete(tableName); // No WHERE clause = delete all
    QuizzerLogger.logSuccess("Truncated $tableName ($rowsDeleted rows deleted).");
  }

  QuizzerLogger.printHeader("--- ALL TABLE TRUNCATION COMPLETE --- ");
}

// ==========================================
// System Test Initialization Helper
// ==========================================

/// Initializes the logger and SessionManager for system tests.
/// This function should be called at the beginning of each system test.
Future<SessionManager> initializeSystemTest() async {
  QuizzerLogger.printHeader('Initializing System Test');
  
  // Initialize logger with FINE level to see all messages
  QuizzerLogger.setupLogging(level: Level.FINE);
  QuizzerLogger.logMessage('Logger initialized with FINE level');
  
  // Get SessionManager instance and wait for initialization
  final sessionManager = getSessionManager();
  QuizzerLogger.logMessage('SessionManager instance obtained');
  
  // Wait for async initialization to complete
  await sessionManager.initializationComplete;
  QuizzerLogger.logMessage('SessionManager initialization completed');
  
  QuizzerLogger.logSuccess('System test initialization complete');
  QuizzerLogger.printDivider();
  
  return sessionManager;
}

// ==========================================
// Test Account Management
// ==========================================

/// Saves test account credentials to a file for use by other tests
Future<void> saveTestAccountCredentials({
  required String email,
  required String username,
  required String password,
  String filename = 'test_account_credentials.json',
}) async {
  QuizzerLogger.logMessage('Saving test account credentials...');
  
  final credentials = {
    'email': email,
    'username': username,
    'password': password,
    'created_at': DateTime.now().toIso8601String(),
  };
  
  // Save to test directory
  final file = File('test/$filename');
  await file.writeAsString(jsonEncode(credentials));
  
  QuizzerLogger.logValue('Credentials saved to: ${file.path}');
  QuizzerLogger.logValue('Email: $email');
  QuizzerLogger.logValue('Username: $username');
  QuizzerLogger.logSuccess('Test account credentials saved successfully');
}

/// Loads test account credentials from file
Future<Map<String, dynamic>?> loadTestAccountCredentials({
  String filename = 'test_account_credentials.json',
}) async {
  QuizzerLogger.logMessage('Loading test account credentials...');
  
  try {
    final file = File('test/$filename');
    if (!await file.exists()) {
      QuizzerLogger.logWarning('Test credentials file not found: ${file.path}');
      return null;
    }
    
    final content = await file.readAsString();
    final credentials = jsonDecode(content) as Map<String, dynamic>;
    
    QuizzerLogger.logValue('Credentials loaded from: ${file.path}');
    QuizzerLogger.logValue('Email: ${credentials['email']}');
    QuizzerLogger.logValue('Username: ${credentials['username']}');
    QuizzerLogger.logSuccess('Test account credentials loaded successfully');
    
    return credentials;
  } catch (e) {
    QuizzerLogger.logError('Error loading test credentials: $e');
    return null;
  }
}

/// Cleans up test account credentials file
Future<void> cleanupTestAccountCredentials({
  String filename = 'test_account_credentials.json',
}) async {
  QuizzerLogger.logMessage('Cleaning up test account credentials...');
  
  try {
    final file = File('test/$filename');
    if (await file.exists()) {
      await file.delete();
      QuizzerLogger.logSuccess('Test credentials file deleted: ${file.path}');
    } else {
      QuizzerLogger.logMessage('Test credentials file not found, nothing to delete');
    }
  } catch (e) {
    QuizzerLogger.logError('Error cleaning up test credentials: $e');
  }
}

/// Loads the test configuration from test_config.json
Future<Map<String, dynamic>> getTestConfig() async {
    final configFile = File('test/test_config.json');
    final jsonString = await configFile.readAsString();
    return json.decode(jsonString) as Map<String, dynamic>;
}

// ==========================================
// Test State Reset Functions
// ==========================================

/// Resets the user question answer pairs table to a clean state.
/// This function clears ALL records from the user_question_answer_pairs table
/// and verifies the table is empty after clearing.
/// 
/// Parameters:
/// - userId: The user ID to clear records for (optional, clears all if null)
/// 
/// Returns:
/// - true if reset was successful, false otherwise
Future<bool> resetUserQuestionAnswerPairsTable({String? userId}) async {
  QuizzerLogger.logMessage('Resetting user_question_answer_pairs table...');
  
  try {
    // Step 1: Clear the user_question_answer_pairs table - ALL RECORDS
    QuizzerLogger.logMessage('Clearing ALL records from user_question_answer_pairs table...');
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      QuizzerLogger.logError('Failed to acquire database access');
      return false;
    }
    
    if (userId != null) {
      // Clear only records for specific user
      final int deletedCount = await db.delete(
        'user_question_answer_pairs',
        where: 'user_uuid = ?',
        whereArgs: [userId],
      );
      QuizzerLogger.logMessage('Deleted $deletedCount records for user $userId');
    } else {
      // Clear all records
      await db.execute('DELETE FROM user_question_answer_pairs');
      QuizzerLogger.logMessage('Deleted ALL records from user_question_answer_pairs table');
    }
    
    getDatabaseMonitor().releaseDatabaseAccess();
    QuizzerLogger.logSuccess('ALL records cleared from user_question_answer_pairs table');

    // Step 2: Verify that the user_question_answer_pairs table is empty
    QuizzerLogger.logMessage('Verifying user_question_answer_pairs table is empty...');
    final dbVerify = await getDatabaseMonitor().requestDatabaseAccess();
    if (dbVerify == null) {
      QuizzerLogger.logError('Failed to acquire database access for verification');
      return false;
    }
    
    final List<Map<String, dynamic>> verificationRecords = await dbVerify.query('user_question_answer_pairs');
    getDatabaseMonitor().releaseDatabaseAccess();
    
    if (verificationRecords.isEmpty) {
      QuizzerLogger.logSuccess('Verified user_question_answer_pairs table is empty');
      return true;
    } else {
      QuizzerLogger.logError('Verification failed: Found ${verificationRecords.length} records after clearing');
      return false;
    }
    
  } catch (e) {
    QuizzerLogger.logError('Error resetting user_question_answer_pairs table: $e');
    return false;
  }
}

/// Resets the user module activation status table to a clean state.
/// This function clears ALL records from the user_module_activation_status table
/// and verifies the table is empty after clearing.
/// 
/// Parameters:
/// - userId: The user ID to clear records for (optional, clears all if null)
/// 
/// Returns:
/// - true if reset was successful, false otherwise
Future<bool> resetUserModuleActivationStatusTable({String? userId}) async {
  QuizzerLogger.logMessage('Resetting user_module_activation_status table...');
  
  try {
    // Step 1: Clear the user_module_activation_status table - ALL RECORDS
    QuizzerLogger.logMessage('Clearing ALL records from user_module_activation_status table...');
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      QuizzerLogger.logError('Failed to acquire database access');
      return false;
    }
    
    if (userId != null) {
      // Clear only records for specific user
      final int deletedCount = await db.delete(
        'user_module_activation_status',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      QuizzerLogger.logMessage('Deleted $deletedCount records for user $userId');
    } else {
      // Clear all records
      await db.execute('DELETE FROM user_module_activation_status');
      QuizzerLogger.logMessage('Deleted ALL records from user_module_activation_status table');
    }
    
    getDatabaseMonitor().releaseDatabaseAccess();
    QuizzerLogger.logSuccess('ALL records cleared from user_module_activation_status table');

    // Step 2: Verify that the user_module_activation_status table is empty
    QuizzerLogger.logMessage('Verifying user_module_activation_status table is empty...');
    final dbVerify = await getDatabaseMonitor().requestDatabaseAccess();
    if (dbVerify == null) {
      QuizzerLogger.logError('Failed to acquire database access for verification');
      return false;
    }
    
    final List<Map<String, dynamic>> verificationRecords = await dbVerify.query('user_module_activation_status');
    getDatabaseMonitor().releaseDatabaseAccess();
    
    if (verificationRecords.isEmpty) {
      QuizzerLogger.logSuccess('Verified user_module_activation_status table is empty');
      return true;
    } else {
      QuizzerLogger.logError('Verification failed: Found ${verificationRecords.length} records after clearing');
      return false;
    }
    
  } catch (e) {
    QuizzerLogger.logError('Error resetting user_module_activation_status table: $e');
    return false;
  }
}

/// Comprehensive test state reset function that resets multiple tables to clean state.
/// This function resets the most commonly used tables for testing.
/// 
/// Parameters:
/// - userId: The user ID to clear records for (optional, clears all if null)
/// - resetUserQuestions: Whether to reset user_question_answer_pairs table (default: true)
/// - resetModuleActivation: Whether to reset user_module_activation_status table (default: true)
/// 
/// Returns:
/// - true if all resets were successful, false if any failed
Future<bool> resetTestState({
  String? userId,
  bool resetUserQuestions = true,
  bool resetModuleActivation = true,
}) async {
  QuizzerLogger.logMessage('=== COMPREHENSIVE TEST STATE RESET ===');
  
  bool allSuccessful = true;
  
  try {
    // Reset user question answer pairs table
    if (resetUserQuestions) {
      QuizzerLogger.logMessage('Step 1: Resetting user question answer pairs table...');
      final userQuestionsReset = await resetUserQuestionAnswerPairsTable(userId: userId);
      if (!userQuestionsReset) {
        QuizzerLogger.logError('Failed to reset user question answer pairs table');
        allSuccessful = false;
      }
    }
    
    // Reset user module activation status table
    if (resetModuleActivation) {
      QuizzerLogger.logMessage('Step 2: Resetting user module activation status table...');
      final moduleActivationReset = await resetUserModuleActivationStatusTable(userId: userId);
      if (!moduleActivationReset) {
        QuizzerLogger.logError('Failed to reset user module activation status table');
        allSuccessful = false;
      }
    }
    
    if (allSuccessful) {
      QuizzerLogger.logSuccess('=== TEST STATE RESET COMPLETED SUCCESSFULLY ===');
    } else {
      QuizzerLogger.logError('=== TEST STATE RESET FAILED ===');
    }
    
    return allSuccessful;
    
  } catch (e) {
    QuizzerLogger.logError('Error during comprehensive test state reset: $e');
    return false;
  }
}

// ==========================================
// Test Data Generation Functions
// ==========================================

/// Ensures a user question answer pair record is eligible for selection.
/// This function sets the circulation status to true and the revision due date to the past.
/// 
/// Parameters:
/// - userId: The user ID
/// - questionId: The question ID to make eligible
/// 
/// Returns:
/// - true if the record was successfully made eligible, false otherwise
Future<bool> ensureRecordEligible(String userId, String questionId) async {
  QuizzerLogger.logMessage('Making question $questionId eligible for user $userId...');
  
  try {
    // Set circulation status to true (in circulation)
    await setCirculationStatus(userId, questionId, true);
    
    // Set revision due date to 1 year in the past
    final DateTime pastDate = DateTime.now().subtract(const Duration(days: 365));
    final String pastDateString = pastDate.toUtc().toIso8601String();
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      QuizzerLogger.logError('Failed to acquire database access');
      return false;
    }
    
    final int result = await db.update(
      'user_question_answer_pairs',
      {'next_revision_due': pastDateString},
      where: 'user_uuid = ? AND question_id = ?',
      whereArgs: [userId, questionId],
    );
    
    getDatabaseMonitor().releaseDatabaseAccess();
    
    if (result > 0) {
      // QuizzerLogger.logSuccess('Successfully made question $questionId eligible');
      return true;
    } else {
      QuizzerLogger.logWarning('No records updated for question $questionId');
      return false;
    }
    
  } catch (e) {
    QuizzerLogger.logError('Error making question $questionId eligible: $e');
    return false;
  }
}

/// Makes a user question answer pair record ineligible for selection.
/// This function sets the circulation status to false and the revision due date to the future.
/// 
/// Parameters:
/// - userId: The user ID
/// - questionId: The question ID to make ineligible
/// 
/// Returns:
/// - true if the record was successfully made ineligible, false otherwise
Future<bool> makeRecordIneligible(String userId, String questionId) async {
  QuizzerLogger.logMessage('Making question $questionId ineligible for user $userId...');
  
  try {
    // Set circulation status to false (not in circulation)
    await setCirculationStatus(userId, questionId, false);
    
    // Set revision due date to 1 year in the future
    final DateTime futureDate = DateTime.now().add(const Duration(days: 365));
    final String futureDateString = futureDate.toUtc().toIso8601String();
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      QuizzerLogger.logError('Failed to acquire database access');
      return false;
    }
    
    final int result = await db.update(
      'user_question_answer_pairs',
      {'next_revision_due': futureDateString},
      where: 'user_uuid = ? AND question_id = ?',
      whereArgs: [userId, questionId],
    );
    
    getDatabaseMonitor().releaseDatabaseAccess();
    
    if (result > 0) {
      // QuizzerLogger.logSuccess('Successfully made question $questionId ineligible');
      return true;
    } else {
      QuizzerLogger.logWarning('No records updated for question $questionId');
      return false;
    }
    
  } catch (e) {
    QuizzerLogger.logError('Error making question $questionId ineligible: $e');
    return false;
  }
}

/// Deletes all local app data to simulate a brand new user state.
/// This function deletes all app directories and ensures a completely clean state.
/// 
/// Returns:
/// - true if cleanup was successful, false otherwise
Future<bool> deleteAllLocalAppData() async {
  QuizzerLogger.logMessage('Performing complete cleanup of local app data...');
  
  try {
    // Delete all app directories
    final directories = [
      'QuizzerApp',
      'QuizzerAppHive', 
      'QuizzerAppLogs',
      'QuizzerAppMedia'
    ];
    
    for (final dirName in directories) {
      final dir = Directory(dirName);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        QuizzerLogger.logMessage('Deleted directory: $dirName');
      }
    }
    
    QuizzerLogger.logSuccess('Complete cleanup finished - simulating brand new user state');
    return true;
  } catch (e) {
    QuizzerLogger.logError('Error during complete cleanup: $e');
    return false;
  }
}

/// Gets the correct answer for a question based on its type and data.
/// 
/// Parameters:
/// - questionId: The question ID to get the correct answer for
/// 
/// Returns:
/// - The correct answer in the appropriate format for the question type
Future<dynamic> getCorrectAnswerForQuestion(String questionId) async {
  QuizzerLogger.logMessage('Getting correct answer for question: $questionId');
  
  // Handle dummy question case
  if (questionId == 'dummy_no_questions') {
    QuizzerLogger.logMessage('Handling dummy question - returning predefined answer');
    // Return the correct answer for the dummy question (index 0 for 'Okay' option)
    return 0;
  }
  
  try {
    final Map<String, dynamic> questionDetails = await getQuestionAnswerPairById(questionId);
    if (questionDetails.isEmpty) {
      throw Exception('Question $questionId not found');
    }
    
    final String questionType = questionDetails['question_type'] as String;
    
    switch (questionType) {
      case 'multiple_choice':
        // For multiple choice, the correct answer is the index stored in correct_option_index
        final int? correctIndex = questionDetails['correct_option_index'] as int?;
        if (correctIndex == null) {
          throw Exception('No correct_option_index found for multiple choice question $questionId');
        }
        QuizzerLogger.logSuccess('Found correct multiple choice answer at index: $correctIndex');
        return correctIndex;
        
      case 'true_false':
        // For true/false, the correct answer is the index stored in correct_option_index (0 for True, 1 for False)
        final int? correctIndex = questionDetails['correct_option_index'] as int?;
        if (correctIndex == null) {
          throw Exception('No correct_option_index found for true/false question $questionId');
        }
        if (correctIndex != 0 && correctIndex != 1) {
          throw Exception('Invalid correct_option_index ($correctIndex) for true/false question $questionId');
        }
        QuizzerLogger.logSuccess('Found correct true/false answer at index: $correctIndex');
        return correctIndex;
        
      case 'select_all_that_apply':
        // For select all that apply, the correct answers are stored in index_options_that_apply
        final String? indexOptionsString = questionDetails['index_options_that_apply'] as String?;
        if (indexOptionsString == null || indexOptionsString.isEmpty) {
          throw Exception('No index_options_that_apply found for select-all question $questionId');
        }
        
        // Parse the CSV string into a list of integers
        final List<int> correctIndices = indexOptionsString
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .where((i) => i != null)
            .cast<int>()
            .toList();
            
        if (correctIndices.isEmpty) {
          throw Exception('No valid indices found in index_options_that_apply for select-all question $questionId');
        }
        QuizzerLogger.logSuccess('Found correct select-all answers at indices: $correctIndices');
        return correctIndices;
        
      case 'sort_order':
        // For sort order, the correct order is stored in the options field
        final List<Map<String, dynamic>> options = List<Map<String, dynamic>>.from(questionDetails['options'] as List);
        if (options.isEmpty) {
          throw Exception('No options found for sort order question $questionId');
        }
        
        // Return the correct order as List<Map<String, dynamic>> with 'content' field
        // The validation function expects each option to have a 'content' field
        final List<Map<String, dynamic>> correctOrder = options
            .map((option) => {
              'content': option['content'] ?? option['text'] ?? option['type'],
            })
            .toList();
        QuizzerLogger.logSuccess('Found correct sort order for question $questionId');
        return correctOrder;
        
      default:
        throw Exception('Unsupported question type: $questionType');
    }
  } catch (e) {
    QuizzerLogger.logError('Error getting correct answer for question $questionId: $e');
    rethrow;
  }
}

/// Generates a list of random question records for testing purposes.
/// 
/// Parameters:
/// - count: Number of question records to generate (default: 100)
/// - prefix: Prefix for question IDs (default: 'test_question_')
/// 
/// Returns:
/// - List of Map<String, dynamic> question records
List<Map<String, dynamic>> generateTestQuestionRecords({
  int count = 100,
  String prefix = 'test_question_',
}) {
  final List<Map<String, dynamic>> testRecords = [];
  
  for (int i = 0; i < count; i++) {
    final Map<String, dynamic> record = {
      'question_id': '$prefix$i',
      'question_type': 'multiple_choice',
      'question_elements': [
        {'type': 'text', 'content': 'Test question $i - What is the answer?'}
      ],
      'answer_elements': [
        {'type': 'text', 'content': 'Answer for question $i'}
      ],
      'options': [
        {'type': 'text', 'content': 'Option A for question $i'},
        {'type': 'text', 'content': 'Option B for question $i'},
        {'type': 'text', 'content': 'Option C for question $i'},
        {'type': 'text', 'content': 'Option D for question $i'},
      ],
      'correct_option_index': i % 4, // Cycle through 0-3
      'module_name': 'TestModule${i % 5}', // Cycle through 5 different modules
      'subjects': 'Test Subject ${i % 3}',
      'concepts': 'Test Concept ${i % 4}',
      'time_stamp': DateTime.now().millisecondsSinceEpoch.toString(),
      'qst_contrib': 'test_user',
      'ans_contrib': 'test_user',
      'citation': 'Test Citation $i',
      'ans_flagged': false,
      'has_been_reviewed': true,
      'flag_for_removal': false,
      'completed': true,
      'correct_order': '',
    };
    testRecords.add(record);
  }
  
  return testRecords;
}