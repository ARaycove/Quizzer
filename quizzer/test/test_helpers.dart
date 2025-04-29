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
import 'package:logging/logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart' as uqap_table;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quizzer/backend_systems/09_data_caches/past_due_cache.dart';
import 'dart:convert'; // ADDED for jsonDecode
import 'dart:io'; // ADDED for File operations
import 'test_helpers.dart'; // Import helper functions

// ==========================================
// Helper Function to Log Current Question Details
// ==========================================
Future<void> logCurrentQuestionDetails(SessionManager manager) async {
  QuizzerLogger.logMessage("--- Logging Current Question Details ---");
  final details = manager.currentQuestionStaticData;

  if (details == null) {
    QuizzerLogger.logValue("currentQuestionStaticData: null");
    QuizzerLogger.printDivider();
    return;
  }

  // Check if it's the dummy question (assuming dummy has null question_id)
  if (details['question_id'] == null) {
     QuizzerLogger.logValue("currentQuestionStaticData: Dummy 'No Questions' Record");
  } else {
    // Log details using getters for a real question, formatting as key: value
    QuizzerLogger.logValue("  Question ID: ${manager.currentQuestionId}");
    QuizzerLogger.logValue("  Question Type: ${manager.currentQuestionType}");
    QuizzerLogger.logValue("  Module Name: ${manager.currentModuleName}");
    // Log actual content
    QuizzerLogger.logValue("  Question Elements: ${manager.currentQuestionElements}");
    QuizzerLogger.logValue("  Answer Elements: ${manager.currentQuestionAnswerElements}");
    // Log options and correct index/order based on type
    if (manager.currentQuestionType == 'multiple_choice') {
      // Extract just the 'content' for logging readability
      final optionContents = manager.currentQuestionOptions
          .map((opt) => opt['content']?.toString() ?? '[invalid option format]')
          .toList();
      QuizzerLogger.logValue("  Options: $optionContents");
      QuizzerLogger.logValue("  Correct Index: ${manager.currentCorrectOptionIndex}");
    } else if (manager.currentQuestionType == 'sort_order') {
      QuizzerLogger.logValue("  Correct Order: ${manager.currentCorrectOrder}"); // Log the list itself
    }
    // Log other optional fields
    QuizzerLogger.logValue("  Citation: ${manager.currentCitation ?? 'N/A'}");
    QuizzerLogger.logValue("  Concepts: ${manager.currentConcepts ?? 'N/A'}");
    QuizzerLogger.logValue("  Subjects: ${manager.currentSubjects ?? 'N/A'}");
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

  final Map<String, dynamic>? record = await uqap_table.getUserQuestionAnswerPairById(
    userId,      // Positional argument 1
    questionId,  // Positional argument 2
    db,          // Positional argument 3
  );

  // Release lock IMMEDIATELY after the DB operation completes or throws
  dbMonitor.releaseDatabaseAccess();
  QuizzerLogger.logMessage("DB access released.");
  db = null; // Prevent reuse after release

  if (record == null) {
      // This case should ideally not be hit if the function throws as documented
      QuizzerLogger.logError("getUserQuestionAnswerPairById returned null unexpectedly for User: $userId, Question: $questionId");
  } else {
    // Log the record
    QuizzerLogger.logMessage("DB Record for User: $userId, Question: $questionId");
    record.forEach((key, value) {
      QuizzerLogger.logValue("  $key: $value");
    });
  }
    
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