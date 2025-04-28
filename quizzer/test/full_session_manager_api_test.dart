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
      QuizzerLogger.logValue("  Options: ${manager.currentQuestionOptions}");
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

// ==========================================
// Main Test Suite
// ==========================================
void main() {
  // Ensure logger is initialized first, setting level to FINE to see logValue messages
  QuizzerLogger.setupLogging(level: Level.FINE);
  test('login and worker start up', () async {
    final sessionManager = getSessionManager();
    final email     = 'example_01@example.com';
    final password  = 'password1';
    final username  = 'example 01';

    QuizzerLogger.printHeader('Attempting initial login for $email...');
    Map<String, dynamic> loginResult = await sessionManager.attemptLogin(email, password);

    // If initial login failed, try creating the user
    if (loginResult['success'] != true) {
      QuizzerLogger.logWarning('Initial login failed for $email. Attempting user creation...');
      final creationResult = await sessionManager.createNewUserAccount(
        email: email,
        username: username,
        password: password,
      );
      
      assert(creationResult['success'] == true, 
             'Failed to create test user $email: ${creationResult['message']}');
      QuizzerLogger.logSuccess('Test user $email created successfully.');

      QuizzerLogger.printHeader('Re-attempting login for $email after creation...');
      loginResult = await sessionManager.attemptLogin(email, password);
    }

    // Assert that the FINAL login attempt was successful
    expect(loginResult['success'], isTrue, 
           reason: 'Login failed even after attempting user creation: ${loginResult['message']}');
    expect(sessionManager.userLoggedIn, isTrue);
    expect(sessionManager.userId, isNotNull);
    QuizzerLogger.logMessage("Workers initialized as intended???");
  });

  test('simulate activating all modules', () async {
    final sessionManager = getSessionManager();
    assert(sessionManager.userLoggedIn, "User must be logged in for this test");

    QuizzerLogger.printHeader('Loading module data...');
    final moduleData = await sessionManager.loadModules();
    final List<Map<String, dynamic>> modules = moduleData['modules'] as List<Map<String, dynamic>>? ?? [];
    final Map<String, bool> initialActivationStatus = moduleData['activationStatus'] as Map<String, bool>? ?? {};
    
    QuizzerLogger.logSuccess('Loaded ${modules.length} modules. Initial status: $initialActivationStatus');
    expect(modules, isNotEmpty, reason: "No modules found in the database to test activation.");

    // Activate each module
    QuizzerLogger.printHeader('Activating all modules...');
    for (final module in modules) {
      final moduleName = module['module_name'] as String;
      // Only activate if not already active (optional optimization)
      if (!(initialActivationStatus[moduleName] ?? false)) {
           QuizzerLogger.logMessage('Activating module: $moduleName');
           sessionManager.toggleModuleActivation(moduleName, true);
      } else {
           QuizzerLogger.logMessage('Module $moduleName already active, skipping.');
      }
    }
    QuizzerLogger.logSuccess('Finished activating all modules.');

    // Pause slightly after triggering activations before test block finishes
    await Future.delayed(const Duration(seconds: 2)); 

    // REMOVED Cache Monitoring Loop from here

  }, timeout: Timeout(Duration(minutes: 1))); // Reduced timeout slightly


  test('Update Module Description Test', () async {
    final sessionManager = getSessionManager();
    assert(sessionManager.userLoggedIn, "User must be logged in for this test");

    QuizzerLogger.printHeader('Starting Update Module Description Test...');

    // 1. Load modules
    QuizzerLogger.logMessage('Loading modules to get current description...');
    Map<String, dynamic> moduleData = await sessionManager.loadModules();
    List<Map<String, dynamic>> modules = moduleData['modules'] as List<Map<String, dynamic>>? ?? [];
    assert(modules.isNotEmpty, "No modules found to test description update.");

    // Assuming there's at least one module, target the first one
    final targetModule = modules.first;
    final moduleName = targetModule['module_name'] as String;
    final originalDescription = targetModule['description'] as String? ?? ''; // Handle null case

    // 2. Log original description
    QuizzerLogger.logMessage('Module Name: $moduleName');
    QuizzerLogger.logValue('Original Description: $originalDescription');

    // 3. Update description
    final newDescription = 'This is the updated test description - ${DateTime.now()}.';
    QuizzerLogger.logMessage('Attempting to update description to: $newDescription');
    bool updateSuccess = await sessionManager.updateModuleDescription(moduleName, newDescription);
    expect(updateSuccess, isTrue, reason: "Failed to update module description.");
    QuizzerLogger.logSuccess('Description update call successful.');
    await waitTime(500); // Brief pause for potential async operations

    // 4. Load modules again and log the new description
    QuizzerLogger.logMessage('Re-loading modules to verify description update...');
    moduleData = await sessionManager.loadModules();
    modules = moduleData['modules'] as List<Map<String, dynamic>>? ?? [];
    final updatedModule = modules.firstWhere((m) => m['module_name'] == moduleName, orElse: () => {});
    assert(updatedModule.isNotEmpty, "Target module disappeared after update?");
    final currentDescriptionAfterUpdate = updatedModule['description'] as String? ?? '';
    QuizzerLogger.logValue('Description after update: $currentDescriptionAfterUpdate');
    expect(currentDescriptionAfterUpdate, equals(newDescription), reason: "Description did not update correctly.");

    // 5. Revert description
    QuizzerLogger.logMessage('Attempting to revert description to original: $originalDescription');
    updateSuccess = await sessionManager.updateModuleDescription(moduleName, originalDescription);
    expect(updateSuccess, isTrue, reason: "Failed to revert module description.");
    QuizzerLogger.logSuccess('Description revert call successful.');
    await waitTime(500);

    // 6. Load modules final time and log reverted description
    QuizzerLogger.logMessage('Re-loading modules to verify description revert...');
    moduleData = await sessionManager.loadModules();
    modules = moduleData['modules'] as List<Map<String, dynamic>>? ?? [];
    final revertedModule = modules.firstWhere((m) => m['module_name'] == moduleName, orElse: () => {});
    assert(revertedModule.isNotEmpty, "Target module disappeared after revert?");
    final currentDescriptionAfterRevert = revertedModule['description'] as String? ?? '';
    QuizzerLogger.logValue('Description after revert: $currentDescriptionAfterRevert');
    expect(currentDescriptionAfterRevert, equals(originalDescription), reason: "Description did not revert correctly.");

    QuizzerLogger.printHeader('Finished Update Module Description Test.');
  });
}

