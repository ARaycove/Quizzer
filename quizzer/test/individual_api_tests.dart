import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'test_helpers.dart';

void main() {
  // Ensure logger is initialized first, setting level to FINE to see logValue messages
  QuizzerLogger.setupLogging(level: Level.FINE);
  test('login and worker start up', () async {
    final sessionManager = getSessionManager();
    const email     = 'example_01@example.com';
    const password  = 'password1';
    const username  = 'example 01';

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

  }, timeout: const Timeout(Duration(minutes: 1))); // Reduced timeout slightly



  test('Question loop test', () async {
    final sessionManager = getSessionManager();
    assert(sessionManager.userLoggedIn, "User must be logged in for this test");

    QuizzerLogger.printHeader('Starting requestNextQuestion loop test (3 iterations)...');

    for (int i = 1; i <= 10; i++) {
    QuizzerLogger.printDivider();
      QuizzerLogger.logMessage('--- Iteration $i ---');
      QuizzerLogger.logMessage('--- State BEFORE requestNextQuestion Call ---');
      // Call the new helper function
      await logCurrentQuestionDetails(sessionManager);
      await logCurrentUserQuestionRecordDetails(sessionManager);
      await logCurrentUserRecordFromDB(sessionManager);
      await waitTime(250);



      QuizzerLogger.logMessage('Calling requestNextQuestion...');
      await sessionManager.requestNextQuestion();
      QuizzerLogger.logMessage('--- State AFTER requestNextQuestion Call ---');
      // Call the new helper function again
      await logCurrentQuestionDetails(sessionManager);
      await waitTime(250);

      QuizzerLogger.logMessage('Submitting random answer');
      if (sessionManager.currentQuestionType == "multiple_choice") {
        await sessionManager.submitAnswer(userAnswer: getRandomMultipleChoiceAnswer(sessionManager));
      } else if (sessionManager.currentQuestionType == "select_all_that_apply") {
        await sessionManager.submitAnswer(userAnswer: getRandomSelectAllAnswer(sessionManager));
      }
      
      await waitTime(250);
      await logCurrentUserQuestionRecordDetails(sessionManager);
      await logCurrentUserRecordFromDB(sessionManager);
      await waitTime(250);

      // Monitor caches to observe changes
      await monitorCaches(monitoringSeconds: 1);
    }

    QuizzerLogger.printHeader('Finished requestNextQuestion loop test.');
  }, timeout: const Timeout(Duration(minutes: 300))); // Allow more time for loops + monitoring


  test('logoutUser test', () async {
    final sessionManager = getSessionManager();
    QuizzerLogger.printHeader('Starting logoutUser test...');

    // Ensure user is logged in before attempting logout
    assert(sessionManager.userLoggedIn, "User must be logged in before testing logout.");
    QuizzerLogger.logMessage('User confirmed logged in. Attempting logout...');

    // Call the logout function
    await sessionManager.logoutUser();

    QuizzerLogger.logSuccess('logoutUser() called. Verifying logged-out state...');

    // Assertions: Verify user is logged out
    expect(sessionManager.userLoggedIn, isFalse, reason: "userLoggedIn should be false after logout.");
    expect(sessionManager.userId, isNull, reason: "userId should be null after logout.");

    // Optional: Add checks for cleared caches if logout is expected to clear them
    // Example: expect(await AnswerHistoryCache().peekHistory(), isEmpty, reason: "AnswerHistoryCache should be empty after logout.");

    QuizzerLogger.logSuccess('logoutUser test completed successfully.');
  });


}