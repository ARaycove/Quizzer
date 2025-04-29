import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'dart:math';
import 'test_helpers.dart';
import 'dart:convert';
import 'dart:io';

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

  test('add all number_properties questions', () async {
    final sessionManager = getSessionManager();
    assert(sessionManager.userLoggedIn, "User must be logged in for this test");

    QuizzerLogger.printHeader('Starting Add All Number Properties Questions Test...');

    // 1. Read the JSON file
    final filePath = 'runtime_cache/number_properties_questions.json';
    QuizzerLogger.logMessage('Reading questions from: $filePath');
    final file = File(filePath);
    assert(await file.exists(), "JSON file not found: $filePath. Run the generation script first.");
    final jsonString = await file.readAsString();

    // 2. Decode JSON (Removed try-catch for Fail Fast)
    List<dynamic> questionsJson = jsonDecode(jsonString) as List<dynamic>;
    QuizzerLogger.logSuccess('Successfully decoded ${questionsJson.length} questions from JSON.');

    // 3. Loop and add each question
    int addedCount = 0;
    for (final questionData in questionsJson) {
      // Cast to Map<String, dynamic> for easier access
      final questionMap = questionData as Map<String, dynamic>; 

      // Extract parameters (with type casting)
      final String moduleName = questionMap['moduleName'] as String;
      final String questionType = questionMap['questionType'] as String;
      // Cast inner list elements too
      final List<Map<String, dynamic>> questionElements = (questionMap['questionElements'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final List<Map<String, dynamic>> answerElements = (questionMap['answerElements'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final List<Map<String, dynamic>> options = (questionMap['options'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      // Specifically cast indexOptionsThatApply to List<int>
      final List<int> indexOptionsThatApply = (questionMap['indexOptionsThatApply'] as List<dynamic>)
          .map((e) => e as int).toList(); 

      // Assert the type is correct before calling addNewQuestion
      assert(questionType == 'select_all_that_apply', 
             "Unexpected question type found in JSON: $questionType");

      // Call addNewQuestion
      final response = await sessionManager.addNewQuestion(
        questionType: questionType,
        moduleName: moduleName,
        questionElements: questionElements,
        answerElements: answerElements,
        options: options,
        indexOptionsThatApply: indexOptionsThatApply,
        // Set other common fields to defaults or null as needed
        citation: null,
        concepts: null,
        subjects: null,
        // Correct option index is not used for this type
        correctOptionIndex: null, 
        correctOrderElements: null,
      );

      // Assert success
      expect(response['success'], isTrue,
             reason: 'Failed to add question ${questionMap['questionElements']}: ${response['message']}');
      addedCount++;
      
      // Log current state (Note: Won't show the *just added* question details)
      await logCurrentQuestionDetails(sessionManager);
      // Wait 250ms between adds
      await waitTime(250); 
    }

    QuizzerLogger.logSuccess('Successfully attempted to add $addedCount questions.');
    QuizzerLogger.printHeader('Finished Add All Number Properties Questions Test.');

    // Monitor caches to see if questions were processed
    await monitorCaches(monitoringSeconds: 60);
  
  }, timeout: Timeout(Duration(minutes: 3))); // Increased timeout for monitoring

}