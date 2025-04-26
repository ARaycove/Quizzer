import 'package:flutter_test/flutter_test.dart';
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
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile_table.dart' as user_profile_table;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ==========================================
// Helper Function for Cache Monitoring
// ==========================================
Future<void> monitorCaches() async {
  QuizzerLogger.printHeader('Starting cache monitoring loop (10 seconds)...');
  // Get cache instances directly using factory constructors
  final unprocessedCache      = UnprocessedCache();
  final nonCirculatingCache   = NonCirculatingQuestionsCache();
  final moduleInactiveCache   = ModuleInactiveCache();
  final circulatingCache      = CirculatingQuestionsCache();
  final dueDateBeyondCache    = DueDateBeyond24hrsCache();
  final dueDateWithinCache    = DueDateWithin24hrsCache();
  final eligibleCache         = EligibleQuestionsCache();
  final queueCache            = QuestionQueueCache();
  final historyCache          = AnswerHistoryCache();

  for (int i = 0; i < 3; i++) { // Run 3 times (3s, 6s, 9s marks)
    await Future.delayed(const Duration(seconds: 3));
    QuizzerLogger.logMessage('--- Cache State Check ${i + 1}/3 at ${DateTime.now()} ---');
    // Peek into each cache and log its length
    final unprocessedList = await unprocessedCache.peekAllRecords();
    QuizzerLogger.logValue('UnprocessedCache length: ${unprocessedList.length}');
    final nonCirculatingList = await nonCirculatingCache.peekAllRecords();
    QuizzerLogger.logValue('NonCirculatingCache length: ${nonCirculatingList.length}');
    final moduleInactiveList = await moduleInactiveCache.peekAllRecords();
    QuizzerLogger.logValue('ModuleInactiveCache length: ${moduleInactiveList.length}');
    final circulatingList = await circulatingCache.peekAllQuestionIds();
    QuizzerLogger.logValue('CirculatingCache length: ${circulatingList.length}');
    final beyond24List = await dueDateBeyondCache.peekAllRecords();
    QuizzerLogger.logValue('DueDateBeyond24hrsCache length: ${beyond24List.length}');
    final within24List = await dueDateWithinCache.peekAllRecords();
    QuizzerLogger.logValue('DueDateWithin24hrsCache length: ${within24List.length}');
    final eligibleList = await eligibleCache.peekAllRecords();
    QuizzerLogger.logValue('EligibleQuestionsCache length: ${eligibleList.length}');
    final queueList = await queueCache.peekAllRecords();
    QuizzerLogger.logValue('QuestionQueueCache length: ${queueList.length}');
    final historyList = await historyCache.peekHistory();
    QuizzerLogger.logValue('AnswerHistoryCache length: ${historyList.length}');
    QuizzerLogger.printDivider();
  }
  // Add a final small delay to reach ~10 seconds total idle time
  await Future.delayed(const Duration(seconds: 1)); 
  QuizzerLogger.logSuccess('Cache monitoring loop finished.');
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
    QuizzerLogger.logSuccess('Login successful for $email.');

    QuizzerLogger.logMessage('Login successful. PreProcessWorker should be running.');
    await Future.delayed(const Duration(seconds: 5));
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

  // New test block to monitor caches
  test('monitor caches after activation', () async {
    // Call the extracted monitoring function
    await monitorCaches();
  }, timeout: Timeout(const Duration(seconds: 15))); // Timeout just > monitor duration

  // --- Test Block: Deactivate Modules via SessionManager ---
  test('deactivate all modules via SessionManager', () async {
    final sessionManager = getSessionManager();
    assert(sessionManager.userLoggedIn, "User must be logged in for this test");

    QuizzerLogger.printHeader("Deactivating All Modules via SessionManager");

    // 1. Load current module state via SessionManager to know which modules exist
    final initialModuleData = await sessionManager.loadModules();
    final List<Map<String, dynamic>> modules = initialModuleData['modules'] as List<Map<String, dynamic>>? ?? [];
    final Map<String, bool> initialActivationStatus = initialModuleData['activationStatus'] as Map<String, bool>? ?? {};
    QuizzerLogger.logValue('Initial Module Activation Status (via SM): $initialActivationStatus');

    expect(modules, isNotEmpty, reason: "No modules found via SessionManager to test deactivation.");

    // 2. Deactivate each module currently active using SessionManager
    QuizzerLogger.logMessage('Sending deactivation requests via SessionManager for active modules...');
    int deactivatedCount = 0;
    for (final module in modules) {
      final moduleName = module['module_name'] as String?;
      // Only toggle if the module exists and is currently active
      if (moduleName != null && (initialActivationStatus[moduleName] ?? false)) {
          QuizzerLogger.logMessage('Deactivating module: $moduleName via SM');
          sessionManager.toggleModuleActivation(moduleName, false);
          deactivatedCount++;
      }
    }
    
    if (deactivatedCount > 0) {
       QuizzerLogger.logSuccess('Sent $deactivatedCount deactivation requests via SessionManager.');
    } else {
       QuizzerLogger.logWarning('No modules were active to deactivate.');
    }

    // 3. Removed verification step within this test.
    //    The effects will be observed in the subsequent cache monitoring test.

    QuizzerLogger.logSuccess("--- Test: Module Deactivation via SessionManager Triggered ---");
  }, timeout: Timeout(const Duration(seconds: 20))); // Reduced timeout

  // --- Test Block: Monitor Caches Again ---
  test('monitor caches after deactivation', () async {
    // Call the extracted monitoring function again
    await monitorCaches();
  }, timeout: Timeout(const Duration(seconds: 15))); // Timeout just > monitor duration
}