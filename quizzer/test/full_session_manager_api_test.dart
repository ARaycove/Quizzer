import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:logging/logging.dart';
import 'test_helpers.dart'; // Import helper functions
import 'dart:io';
import 'dart:convert';
import 'package:sqflite/sqflite.dart'; // Import for Database type
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart'; // Import for getDatabaseMonitor
// ==========================================
// Main Test Suite
// ==========================================
// This is a full test of all Quizzer functionality.
// All tests are ran in sequence
// We first truncate the test database, add questions, activate modules
// Run a spam test, test the results of that, edit module description
// Run the requestNextQuestion on a loop to ensure questions are cycling (without answer submissions)
// Run the main Question Loop with answer submissions and monitor caches to see how questions move

void main() {
  // Ensure logger is initialized first, setting level to FINE to see logValue messages
  QuizzerLogger.setupLogging(level: Level.FINE);
  /// CLEAR FIRST (simulating first time user / empty database for testing)
  /// WARNING TEST ENVIRONMENT, CLEARS TABLES FOR CLEAN TESTS EVERYTIME
  test('Truncate all database tables', () async {
    QuizzerLogger.printHeader('Starting database truncation test...');
    final dbMonitor = getDatabaseMonitor(); // Get the monitor instance
    Database? db;
    db = await dbMonitor.requestDatabaseAccess();
    assert(db != null, 'Failed to acquire database access for truncation.');
    QuizzerLogger.logMessage('Database access acquired for truncation.');
    // Call the truncate helper function, asserting non-null db
    await truncateAllTables(db!); // Use null assertion operator
    QuizzerLogger.logSuccess('truncateAllTables helper function completed.');
    dbMonitor.releaseDatabaseAccess(); // Release is likely synchronous
    QuizzerLogger.logWarning('DB was null, could not release access (might not have been acquired).');
    QuizzerLogger.printHeader('Database truncation test finished.');
  });

  /// login and initiate question server background processes (simulates both the attemptLogin and creation of NewUsers)
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
  /// Test Add Question Functionality (monitoring caches after each individual block add)
  // --- Test for adding Vowel/Consonant True/False questions --- 
  test('add all Vowel or Consonant questions', () async {
    final sessionManager = getSessionManager();
    assert(sessionManager.userLoggedIn, "User must be logged in for this test");

    QuizzerLogger.printHeader('Starting Add All Vowel/Consonant Questions Test...');

    // 1. Read the JSON file
    const filePath = 'runtime_cache/is_vowel_or_consonant_questions.json'; // Updated path
    QuizzerLogger.logMessage('Reading questions from: $filePath');
    final file = File(filePath);
    assert(await file.exists(), "JSON file not found: $filePath. Run the generation script first.");
    final jsonString = await file.readAsString();

    // 2. Decode JSON
    List<dynamic> questionsJson = jsonDecode(jsonString) as List<dynamic>;
    QuizzerLogger.logSuccess('Successfully decoded ${questionsJson.length} questions from JSON.');

    // 3. Loop and add each question
    int addedCount = 0;
    for (final questionData in questionsJson) {
      final questionMap = questionData as Map<String, dynamic>; 

      // Extract parameters 
      final String moduleName = questionMap['module_name'] as String;
      final String questionType = questionMap['question_type'] as String;
      final List<Map<String, dynamic>> questionElements = (questionMap['question_elements'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final List<Map<String, dynamic>> answerElements = (questionMap['answer_elements'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      // Extract correct_option_index for true_false
      final int correctOptionIndex = questionMap['correct_option_index'] as int; 

      // Assert the type is correct before calling addNewQuestion
      assert(questionType == 'true_false', 
             "Unexpected question type found in JSON: $questionType. Expected 'true_false'.");

      // Call addNewQuestion for true_false type
      sessionManager.addNewQuestion(
        questionType: questionType,
        moduleName: moduleName,
        questionElements: questionElements,
        answerElements: answerElements,
        correctOptionIndex: correctOptionIndex, // Pass the index
      );
      
      addedCount++;
    }
    await monitorCaches(monitoringSeconds: 10);
    QuizzerLogger.logSuccess('Successfully attempted to add $addedCount vowel/consonant questions.');
    QuizzerLogger.printHeader('Finished Add All Vowel/Consonant Questions Test.');
  }, timeout: const Timeout(Duration(minutes: 20))); // Adjust timeout as needed
  // Select all that apply questions
  test('add all Is Even or Odd questions', () async {
      final sessionManager = getSessionManager();
      assert(sessionManager.userLoggedIn, "User must be logged in for this test");

      QuizzerLogger.printHeader('Starting Add All Number Properties Questions Test...');

      // 1. Read the JSON file
      const filePath = 'runtime_cache/number_properties_questions.json';
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
        await sessionManager.addNewQuestion(
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
        );

        addedCount++;
        
        // Log current state (Note: Won't show the *just added* question details)
        await logCurrentQuestionDetails(sessionManager);
        // Wait 250ms between adds
        await waitTime(50); 
      }

      QuizzerLogger.logSuccess('Successfully attempted to add $addedCount questions.');
      QuizzerLogger.printHeader('Finished Add All Number Properties Questions Test.');

      // Monitor caches to see if questions were processed
      await monitorCaches(monitoringSeconds: 10);
    
    }, timeout: const Timeout(Duration(minutes: 3))); // Increased timeout for monitoring
  //  Multiple choice
  test('Add Questions From JSON Test', () async {
  final sessionManager = getSessionManager();
  assert(sessionManager.userLoggedIn, "User must be logged in for this test");

  QuizzerLogger.printHeader('Starting Add Questions From JSON Test...');

  // 1. Load the JSON file
  const String jsonPath = 'runtime_cache/elementary_addition_questions.json';
  QuizzerLogger.logMessage('Loading questions from: $jsonPath');
  final File jsonFile = File(jsonPath);
  if (!await jsonFile.exists()) {
    throw Exception('JSON test data file not found at $jsonPath. Run generate_math_questions.dart first.');
  }
  final String jsonString = await jsonFile.readAsString();
  final List<dynamic> questionsData = jsonDecode(jsonString) as List<dynamic>;
  QuizzerLogger.logSuccess('Loaded ${questionsData.length} questions from JSON.');

  int successCount = 0;
  int failureCount = 0;

  // 2. Iterate and add questions
  for (final questionDynamic in questionsData) {
    final questionMap = questionDynamic as Map<String, dynamic>; // Cast

    // 3. Use SessionManager to add the question
    QuizzerLogger.logMessage('Adding question: ${questionMap['questionElements']?[0]?['content'] ?? 'N/A'}');

    // Ensure data types match the API expectations
    final List<Map<String, dynamic>> questionElements = 
        List<Map<String, dynamic>>.from(questionMap['questionElements'] ?? []);
    final List<Map<String, dynamic>> answerElements = 
        List<Map<String, dynamic>>.from(questionMap['answerElements'] ?? []);
    final List<Map<String, dynamic>>? options = 
        (questionMap['options'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map)).toList(); 
    final int? correctOptionIndex = questionMap['correctOptionIndex'] as int?;

    await sessionManager.addNewQuestion(
      questionType: questionMap['questionType'] as String,
      questionElements: questionElements,
      answerElements: answerElements,
      moduleName: questionMap['moduleName'] as String,
      options: options,
      correctOptionIndex: correctOptionIndex,
      // Pass other potential fields if they exist in JSON, otherwise they default
      citation: questionMap['citation'] as String?,
      concepts: questionMap['concepts'] as String?,
      subjects: questionMap['subjects'] as String?,
    );
    // 5. Wait
    await waitTime(50);
  }

  await monitorCaches(monitoringSeconds: 15);
  QuizzerLogger.printDivider();
  QuizzerLogger.logSuccess('Finished adding questions. Success: $successCount, Failed: $failureCount');
  QuizzerLogger.printHeader('Finished Add Questions From JSON Test.');

}, timeout: const Timeout(Duration(minutes: 5))); // Increase timeout for file IO and looping
  // Sort Order Questions
  test('add generated periodic table sort_order questions', () async {
    final sessionManager = getSessionManager();
    assert(sessionManager.userLoggedIn, "User must be logged in for this test");
    assert(sessionManager.userId != null, "User ID must be available");

    QuizzerLogger.printHeader('Starting Test: Add Periodic Table Sort Order Questions');

    const jsonFilePath = 'runtime_cache/generated_periodic_table_sort_questions.json';
    final jsonFile = File(jsonFilePath);

    if (!await jsonFile.exists()) {
      throw StateError('Generated question file not found at: $jsonFilePath. Run generate script first.');
    }

    List<dynamic> questionsJson = [];
    try {
      final jsonString = await jsonFile.readAsString();
      questionsJson = jsonDecode(jsonString) as List<dynamic>;
      QuizzerLogger.logSuccess('Successfully read and parsed ${questionsJson.length} questions from $jsonFilePath');
    } catch (e) {
      throw StateError('Error reading or parsing JSON file $jsonFilePath: $e');
    }

    int addedCount = 0;
    int errorCount = 0;

    for (final questionData in questionsJson) {
      if (questionData is! Map<String, dynamic>) {
        QuizzerLogger.logWarning('Skipping invalid data entry (not a Map): $questionData');
        errorCount++;
        continue;
      }

      try {
        // Extract parameters, performing necessary casts
        final String questionType = questionData['questionType'] as String;
        final String moduleName = questionData['moduleName'] as String;
        // Safely cast lists of maps
        final List<Map<String, dynamic>> questionElements = 
            List<Map<String, dynamic>>.from((questionData['questionElements'] as List<dynamic>)
                .map((e) => Map<String, dynamic>.from(e as Map)));
        final List<Map<String, dynamic>> answerElements = 
            List<Map<String, dynamic>>.from((questionData['answerElements'] as List<dynamic>)
                .map((e) => Map<String, dynamic>.from(e as Map)));
        // Options for sort_order are expected as List<Map<String, dynamic>> containing {'type': 'text', 'content': 'Symbol - Name'}
        final List<Map<String, dynamic>> options = 
            List<Map<String, dynamic>>.from((questionData['options'] as List<dynamic>)
                .map((e) => Map<String, dynamic>.from(e as Map)));

        // Assert the type is correct before calling addNewQuestion
        assert(questionType == 'sort_order', 
              "Unexpected question type found in JSON: $questionType");

        // Call addNewQuestion - use the 'options' field as SessionManager expects
        await sessionManager.addNewQuestion(
          questionType: questionType,
          moduleName: moduleName,
          questionElements: questionElements,
          answerElements: answerElements,
          options: options, // Pass the List<Map<String, dynamic>>
          // Other fields are null/not applicable for sort_order
          correctOptionIndex: null, 
          indexOptionsThatApply: null,
          citation: null,
          concepts: null,
          subjects: null,
        );
        addedCount++;
        // Optional: Add a small delay if needed, e.g., await waitTime(50);
      } catch (e, stackTrace) {
        QuizzerLogger.logError('Error adding sort_order question: $e\n$stackTrace');
        errorCount++;
        // Decide whether to continue or stop on error
        // continue;
        rethrow; // Re-throwing will stop the test on the first error
      }
    }

    QuizzerLogger.logSuccess('Attempted to add ${questionsJson.length} questions. Added: $addedCount, Errors: $errorCount');
    expect(errorCount, 0, reason: "Errors occurred while adding sort_order questions.");
    QuizzerLogger.printHeader('Finished Test: Add Periodic Table Sort Order Questions');

    // Optional: Monitor caches or add further checks after adding questions
    // await monitorCaches(monitoringSeconds: 5);
  });
  /// Simulate activation of modules
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

  /// Test Robustness of system
  test('spam module activation toggle', () async {
    final sessionManager = getSessionManager();
    assert(sessionManager.userLoggedIn, "User must be logged in for this test");

    QuizzerLogger.printHeader('Starting Module Activation Spam Test (50 Cycles)...');

    // Load modules once
    final moduleData = await sessionManager.loadModules();
    final List<Map<String, dynamic>> modules = moduleData['modules'] as List<Map<String, dynamic>>? ?? [];
    expect(modules, isNotEmpty, reason: "No modules found to perform spam test.");
    QuizzerLogger.logMessage('Loaded ${modules.length} modules for spam test.');

    const int spamCycles = 50;
    for (int i = 0; i < spamCycles; i++) {
      final bool activate = i % 2 == 0; // Activate on even, deactivate on odd
      // QuizzerLogger.logMessage('Spam Cycle ${i + 1}/$spamCycles: Setting all modules to active=$activate');
      for (final module in modules) {
        final moduleName = module['module_name'] as String?;
        if (moduleName != null) {
          // Fire and forget - DO NOT await
          sessionManager.toggleModuleActivation(moduleName, activate);
        }
      }
    }

    QuizzerLogger.logSuccess('Finished sending $spamCycles toggle cycles (with 67-100ms random delay) for ${modules.length} modules.');

    // Explicitly activate all modules after the spam loop
    QuizzerLogger.logMessage('Explicitly activating all modules after spam cycle...');
    for (final module in modules) {
        final moduleName = module['module_name'] as String?;
        if (moduleName != null) {
            // Fire and forget
            sessionManager.toggleModuleActivation(moduleName, true);
        }
    }
    QuizzerLogger.logSuccess('Finished final explicit activation call for all modules.');

  }, timeout: const Timeout(Duration(minutes: 2))); // Allow slightly more time for the loop

  // --- Test Block: Monitor Caches After Spam ---
  test('monitor caches after spam toggle', () async {
      // Call the extracted monitoring function again to see the result of the spam
      // Monitor for 30 seconds this time
      await monitorCaches(monitoringSeconds: 30);
    }, timeout: const Timeout( Duration(seconds: 120))); // Timeout > monitor duration + buffer

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

