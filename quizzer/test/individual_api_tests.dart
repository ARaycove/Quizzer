import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'test_helpers.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math'; // Import for Random class
import 'package:sqflite/sqflite.dart'; // Import for Database type
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart'; // Import for getDatabaseMonitor

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

  test('monitor caches for 5 seconds after login', () async {
    await monitorCaches(monitoringSeconds: 5);
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


// =============================================================================================
// Rest of Tests (environment set up)
  // marked skipped right now [x]
  test('requestNextQuestion cycle test (50 iterations)', () async {
    final sessionManager = getSessionManager();
    assert(sessionManager.userLoggedIn, "User must be logged in for this test");

    QuizzerLogger.printHeader('Starting requestNextQuestion cycle test (50 iterations)...');

    for (int i = 1; i <= 50; i++) {
    QuizzerLogger.printDivider();
      QuizzerLogger.logMessage('--- Cycle Test Iteration $i ---');
      
      QuizzerLogger.logMessage('Calling requestNextQuestion...');
      await sessionManager.requestNextQuestion();
      
      QuizzerLogger.logMessage('Logging current question details...');
      await logCurrentQuestionDetails(sessionManager);
      
      QuizzerLogger.logMessage('Monitoring caches for 1 second...');
      await monitorCaches(monitoringSeconds: 1);
    }

    QuizzerLogger.printHeader('Finished requestNextQuestion cycle test.');
  }, timeout: const Timeout(Duration(minutes: 5)), skip: true); // Timeout allows for 50s monitoring + overhead

  test('Question loop test', () async {
    final sessionManager = getSessionManager();
    assert(sessionManager.userLoggedIn, "User must be logged in for this test");

    QuizzerLogger.printHeader('Starting requestNextQuestion loop test (3 iterations)...');

    for (int i = 1; i <= 100; i++) {
    QuizzerLogger.printDivider();
      QuizzerLogger.logMessage('--- Iteration $i ---');
      QuizzerLogger.logMessage('--- State BEFORE requestNextQuestion Call ---');
      // Call the new helper function
      await logCurrentQuestionDetails(sessionManager);
      await logCurrentUserQuestionRecordDetails(sessionManager);
      await logCurrentUserRecordFromDB(sessionManager);
      await waitTime(100);



      QuizzerLogger.logMessage('Calling requestNextQuestion...');
      await sessionManager.requestNextQuestion();
      QuizzerLogger.logMessage('--- State AFTER requestNextQuestion Call ---');
      // Call the new helper function again
      await logCurrentQuestionDetails(sessionManager);
      await waitTime(100);

      // Log duplicated so we can find it!!
      QuizzerLogger.logMessage('Submitted random answer to question of type: ${sessionManager.currentQuestionType}');
      // Test has been modified to answer correctly for multiple choice and select_all_that_apply
      dynamic provided;
      if (sessionManager.currentQuestionType == "multiple_choice") {
        // provided = getRandomMultipleChoiceAnswer(sessionManager);
        provided = sessionManager.currentCorrectOptionIndex;
        await sessionManager.submitAnswer(userAnswer: provided);

      } 
      else if (sessionManager.currentQuestionType == "select_all_that_apply") {
        // provided = getRandomSelectAllAnswer(sessionManager);
        provided = sessionManager.currentCorrectIndices;
        await sessionManager.submitAnswer(userAnswer: provided);

      } 
      else if (sessionManager.currentQuestionType == "true_false") {
        // provided = Random().nextInt(2);
        provided = sessionManager.currentCorrectOptionIndex;
        await sessionManager.submitAnswer(userAnswer: provided);
      }
      else if (sessionManager.currentQuestionType == "sort_order") {
        provided = getRandomSortOrderAnswer(sessionManager);
        await sessionManager.submitAnswer(userAnswer: provided);
      }
      
      await waitTime(100);
      await logCurrentUserQuestionRecordDetails(sessionManager);
      await logCurrentUserRecordFromDB(sessionManager);
      QuizzerLogger.logMessage('Submitted random answer to question of type: ${sessionManager.currentQuestionType}');
      QuizzerLogger.logMessage("Provided answer: $provided");
      await waitTime(100);

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