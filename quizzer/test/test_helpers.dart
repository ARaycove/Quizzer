import 'package:flutter_test/flutter_test.dart';
import 'dart:math'; // Import for max function
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/09_data_caches/unprocessed_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/non_circulating_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/module_inactive_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/circulating_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/due_date_beyond_24hrs_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/due_date_within_24hrs_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/eligible_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/question_queue_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/answer_history_cache.dart';
// import 'package:logging/logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart' as uqap_table;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quizzer/backend_systems/09_data_caches/past_due_cache.dart';
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
// Helper Function for Cache Monitoring
// ==========================================
Future<void> monitorCaches({int monitoringSeconds = 10}) async {
  QuizzerLogger.printHeader('Starting cache monitoring loop ($monitoringSeconds seconds)...');
  // Get cache instances directly using factory constructors
  final unprocessedCache      = UnprocessedCache();
  final nonCirculatingCache   = NonCirculatingQuestionsCache();
  final moduleInactiveCache   = ModuleInactiveCache();
  final circulatingCache      = CirculatingQuestionsCache();
  final dueDateBeyondCache    = DueDateBeyond24hrsCache();
  final dueDateWithinCache    = DueDateWithin24hrsCache();
  final pastDueCache          = PastDueCache();
  final eligibleCache         = EligibleQuestionsCache();
  final queueCache            = QuestionQueueCache();
  final historyCache          = AnswerHistoryCache();

  final stopwatch = Stopwatch()..start();
  const checkInterval = Duration(seconds: 3);
  int checkCount = 0;

  while (stopwatch.elapsed.inSeconds < monitoringSeconds) {
    // Perform the check first
    checkCount++;
    QuizzerLogger.logMessage('--- Cache State Check $checkCount at ${stopwatch.elapsed} (Target: ${monitoringSeconds}s) ---');
    // Peek into each cache and log its length
    final unprocessedList = await unprocessedCache.peekAllRecords();
    QuizzerLogger.logValue('UnprocessedCache length: ${unprocessedList.length}');
    final nonCirculatingList = await nonCirculatingCache.peekAllRecords();
    QuizzerLogger.logValue('NonCirculatingCache length: ${nonCirculatingList.length}');
    final moduleInactiveLength = await moduleInactiveCache.peekTotalRecordCount();
    QuizzerLogger.logValue('ModuleInactiveCache length: $moduleInactiveLength');
    final circulatingList = await circulatingCache.peekAllQuestionIds();
    QuizzerLogger.logValue('CirculatingCache length: ${circulatingList.length}');
    final beyond24List = await dueDateBeyondCache.peekAllRecords();
    QuizzerLogger.logValue('DueDateBeyond24hrsCache length: ${beyond24List.length}');
    final within24List = await dueDateWithinCache.peekAllRecords();
    QuizzerLogger.logValue('DueDateWithin24hrsCache length: ${within24List.length}');
    final pastDueList = await pastDueCache.peekAllRecords();
    QuizzerLogger.logValue('PastDueCache length: ${pastDueList.length}');
    final eligibleList = await eligibleCache.peekAllRecords();
    QuizzerLogger.logValue('EligibleQuestionsCache length: ${eligibleList.length}');
    final queueList = await queueCache.peekAllRecords();
    QuizzerLogger.logValue('QuestionQueueCache length: ${queueList.length}');
    final historyList = await historyCache.peekHistory();
    QuizzerLogger.logValue('AnswerHistoryCache length: ${historyList.length}');
    QuizzerLogger.printDivider();

    // Wait for the next interval, unless the total duration is already met
    if (stopwatch.elapsed.inSeconds < monitoringSeconds) {
      await Future.delayed(checkInterval);
    }
  }
  stopwatch.stop();
  QuizzerLogger.logSuccess('Cache monitoring loop finished after ${stopwatch.elapsed}.');
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