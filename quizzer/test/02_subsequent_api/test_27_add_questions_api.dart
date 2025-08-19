import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/session_manager/answer_validation/text_analysis_tools.dart';
import '../test_helpers.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Manual iteration variable for reusing accounts across tests
  late int testIteration;
  
  // Test credentials - defined once and reused
  late String testEmail;
  late String testPassword;
  late String testAccessPassword;
  
  // Global instances used across tests
  late final SessionManager sessionManager;
  
  // Global test results tracking
  final Map<String, dynamic> testResults = {};
  
  // Track created test modules for cleanup
  final List<String> createdTestModules = [];
  
  setUpAll(() async {
    await QuizzerLogger.setupLogging();
    HttpOverrides.global = null;
    
    // Load test configuration
    final config = await getTestConfig();
    testIteration = config['testIteration'] as int;
    testPassword = config['testPassword'] as String;
    testAccessPassword = config['testAccessPassword'] as String;
    
    // Set up test credentials
    testEmail = 'test_user_$testIteration@example.com';
    
    sessionManager = getSessionManager();
    await sessionManager.initializationComplete;
    
    // Login initialization with sync and queue servers disabled
    final loginResult = await loginInitialization(
      email: testEmail, 
      password: testPassword, 
      supabase: sessionManager.supabase, 
      storage: sessionManager.getBox(testAccessPassword),
      testRun: true, // This bypasses sync workers
      noQueueServer: true
    );
    expect(loginResult['success'], isTrue, reason: 'Login initialization should succeed');
  });
  
  tearDownAll(() async {
    QuizzerLogger.logMessage('Cleaning up test modules created during tests...');
    if (createdTestModules.isNotEmpty) {
      await cleanupTestModules(createdTestModules);
      QuizzerLogger.logSuccess('Cleaned up ${createdTestModules.length} test modules');
    }
  });
  
  group('SessionManager Add Questions API Tests', () {

    
    test('Test 1: Add multiple choice questions and verify', () async {
      QuizzerLogger.logMessage('=== Test 1: Add multiple choice questions and verify ===');
      
      // Step 1: Clear database state for clean test
      QuizzerLogger.logMessage('Step 1: Clearing database state...');
      
      // Clear question_answer_pairs table
      final bool questionsCleared = await deleteAllRecordsFromTable('question_answer_pairs');
      expect(questionsCleared, isTrue, reason: 'Failed to clear question_answer_pairs table');
      QuizzerLogger.logSuccess('Question_answer_pairs table cleared successfully');
      
      // Clear modules table
      final bool modulesCleared = await deleteAllRecordsFromTable('modules');
      expect(modulesCleared, isTrue, reason: 'Failed to clear modules table');
      QuizzerLogger.logSuccess('Modules table cleared successfully');
      
      // Clear user_module_activation_status table
      final bool userModuleStatusCleared = await deleteAllRecordsFromTable('user_module_activation_status', userId: sessionManager.userId!, userIdColumn: 'user_id');
      expect(userModuleStatusCleared, isTrue, reason: 'Failed to clear user_module_activation_status table');
      QuizzerLogger.logSuccess('User_module_activation_status table cleared successfully');
      
      // Step 2: Generate multiple choice questions using helper function
      QuizzerLogger.logMessage('Step 2: Generating multiple choice questions...');
      final String testModule = 'TestModule_${DateTime.now().millisecondsSinceEpoch}';
      QuizzerLogger.logMessage('Using test module: $testModule');
      createdTestModules.add(testModule);
      final List<Map<String, dynamic>> questionData = generateQuestionInputData(
        questionType: 'multiple_choice',
        numberOfQuestions: 3,
        numberOfModules: 1,
        numberOfOptions: 4,
        customModuleName: testModule,
      );
      
      // Step 3: Add multiple choice questions
      QuizzerLogger.logMessage('Step 3: Adding multiple choice questions...');
      final stopwatch = Stopwatch()..start();
      
      int totalQuestionsAdded = 0;
      for (int i = 0; i < questionData.length; i++) {
        final Map<String, dynamic> data = questionData[i];
        
        final Map<String, dynamic> addResult = await sessionManager.addNewQuestion(
          questionType: data['questionType'],
          questionElements: data['questionElements'],
          answerElements: data['answerElements'],
          moduleName: data['moduleName'],
          options: data['options'],
          correctOptionIndex: data['correctOptionIndex'],
        );
          
        expect(addResult, isNotNull, reason: 'Add question ${i + 1} should return a result');
        totalQuestionsAdded++;
      }
      
      stopwatch.stop();
      final int elapsedMilliseconds = stopwatch.elapsedMilliseconds;
      QuizzerLogger.logMessage('Add multiple choice questions API calls took ${elapsedMilliseconds}ms');
      
      // Step 4: Verify questions were added
      QuizzerLogger.logMessage('Step 4: Verifying questions were added...');
      final List<Map<String, dynamic>> questionsAfterAdd = await getAllQuestionAnswerPairs();
      final int afterAddCount = questionsAfterAdd.length;
      expect(afterAddCount, equals(totalQuestionsAdded), reason: 'Should have exactly $totalQuestionsAdded questions after adding');
      
      // Step 5: Verify question details
      final String normalizedModuleName = await normalizeString(testModule);
      final List<Map<String, dynamic>> moduleQuestions = questionsAfterAdd.where((q) => q['module_name'] == normalizedModuleName).toList();
      expect(moduleQuestions.length, equals(totalQuestionsAdded), reason: 'Should have $totalQuestionsAdded questions in the test module');
      
      // Verify all questions are multiple choice
      for (final question in moduleQuestions) {
        expect(question['question_type'], equals('multiple_choice'), 
          reason: 'All questions should be multiple_choice type');
        expect(question['module_name'], equals(normalizedModuleName), 
          reason: 'All questions should be in correct module');
      }
      
      // Step 6: Verify module was created
      QuizzerLogger.logMessage('Step 6: Verifying module was created...');
      final db = getDatabaseMonitor().requestDatabaseAccess();
      final List<Map<String, dynamic>> modulesAfterAdd = await getAllModules(db);
      getDatabaseMonitor().releaseDatabaseAccess();

      final int moduleCount = modulesAfterAdd.length;
      expect(moduleCount, equals(1), reason: 'Should have exactly 1 module after adding questions');
      
      final Map<String, dynamic> createdModule = modulesAfterAdd.first;
      expect(createdModule['module_name'], equals(normalizedModuleName), 
        reason: 'Module name should match the test module');
      
      // Store results for final report
      testResults['multiple_choice_added'] = true;
      testResults['multiple_choice_count'] = totalQuestionsAdded;
      testResults['multiple_choice_performance_ms'] = elapsedMilliseconds;
      testResults['module_created'] = true;
      
      QuizzerLogger.logSuccess('Multiple choice questions added and module created successfully');
      QuizzerLogger.logSuccess('=== Test 2 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 2: Add true/false questions and verify', () async {
      QuizzerLogger.logMessage('=== Test 2: Add true/false questions and verify ===');
      
      // Step 1: Clear database state for clean test
      QuizzerLogger.logMessage('Step 1: Clearing database state...');
      
      // Clear question_answer_pairs table
      final bool questionsCleared = await deleteAllRecordsFromTable('question_answer_pairs');
      expect(questionsCleared, isTrue, reason: 'Failed to clear question_answer_pairs table');
      QuizzerLogger.logSuccess('Question_answer_pairs table cleared successfully');
      
      // Clear modules table
      final bool modulesCleared = await deleteAllRecordsFromTable('modules');
      expect(modulesCleared, isTrue, reason: 'Failed to clear modules table');
      QuizzerLogger.logSuccess('Modules table cleared successfully');
      
      // Clear user_module_activation_status table
      final bool userModuleStatusCleared = await deleteAllRecordsFromTable('user_module_activation_status', userId: sessionManager.userId!, userIdColumn: 'user_id');
      expect(userModuleStatusCleared, isTrue, reason: 'Failed to clear user_module_activation_status table');
      QuizzerLogger.logSuccess('User_module_activation_status table cleared successfully');
      
      // Step 2: Generate true/false questions using helper function
      QuizzerLogger.logMessage('Step 2: Generating true/false questions...');
      final String testModule = 'TestModule_${DateTime.now().millisecondsSinceEpoch}';
      QuizzerLogger.logMessage('Using test module: $testModule');
      createdTestModules.add(testModule);
      final List<Map<String, dynamic>> questionData = generateQuestionInputData(
        questionType: 'true_false',
        numberOfQuestions: 3,
        numberOfModules: 1,
        customModuleName: testModule,
      );
      
      // Step 3: Add true/false questions
      QuizzerLogger.logMessage('Step 3: Adding true/false questions...');
      final stopwatch = Stopwatch()..start();
      
      int totalQuestionsAdded = 0;
      for (int i = 0; i < questionData.length; i++) {
        final Map<String, dynamic> data = questionData[i];
        
        final Map<String, dynamic> addResult = await sessionManager.addNewQuestion(
          questionType: data['questionType'],
          questionElements: data['questionElements'],
          answerElements: data['answerElements'],
          moduleName: data['moduleName'],
          correctOptionIndex: data['correctOptionIndex'],
        );
          
        expect(addResult, isNotNull, reason: 'Add question ${i + 1} should return a result');
        totalQuestionsAdded++;
      }
      
      stopwatch.stop();
      final int elapsedMilliseconds = stopwatch.elapsedMilliseconds;
      QuizzerLogger.logMessage('Add true/false questions API calls took ${elapsedMilliseconds}ms');
      
      // Step 4: Verify questions were added
      QuizzerLogger.logMessage('Step 4: Verifying true/false questions were added...');
      final List<Map<String, dynamic>> questionsAfterAdd = await getAllQuestionAnswerPairs();
      final int afterAddCount = questionsAfterAdd.length;
      expect(afterAddCount, equals(totalQuestionsAdded), reason: 'Should have exactly $totalQuestionsAdded questions after adding');
      
      // Step 5: Verify question details
      final String normalizedModuleName = await normalizeString(testModule);
      final List<Map<String, dynamic>> moduleQuestions = questionsAfterAdd.where((q) => q['module_name'] == normalizedModuleName).toList();
      expect(moduleQuestions.length, equals(totalQuestionsAdded), reason: 'Should have $totalQuestionsAdded questions in the test module');
      
      // Verify all questions are true/false
      for (final question in moduleQuestions) {
        expect(question['question_type'], equals('true_false'), 
          reason: 'All questions should be true_false type');
        expect(question['module_name'], equals(normalizedModuleName), 
          reason: 'All questions should be in correct module');
      }
      
      // Step 6: Verify module was created
      QuizzerLogger.logMessage('Step 6: Verifying module was created...');
      final db = getDatabaseMonitor().requestDatabaseAccess();
      final List<Map<String, dynamic>> modulesAfterAdd = await getAllModules(db);
      getDatabaseMonitor().releaseDatabaseAccess();

      final int moduleCount = modulesAfterAdd.length;
      expect(moduleCount, equals(1), reason: 'Should have exactly 1 module after adding questions');
      
      final bool moduleExists = modulesAfterAdd.any((m) => m['module_name'] == normalizedModuleName);
      expect(moduleExists, isTrue, reason: 'Test module should exist in modules table');
      
      // Store results for final report
      testResults['true_false_added'] = true;
      testResults['true_false_count'] = totalQuestionsAdded;
      testResults['true_false_performance_ms'] = elapsedMilliseconds;
      
      QuizzerLogger.logSuccess('True/false questions added and module created successfully');
      QuizzerLogger.logSuccess('=== Test 3 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 3: Add select_all_that_apply questions and verify', () async {
      QuizzerLogger.logMessage('=== Test 3: Add select_all_that_apply questions and verify ===');
      
      // Step 1: Clear database state for clean test
      QuizzerLogger.logMessage('Step 1: Clearing database state...');
      
      // Clear question_answer_pairs table
      final bool questionsCleared = await deleteAllRecordsFromTable('question_answer_pairs');
      expect(questionsCleared, isTrue, reason: 'Failed to clear question_answer_pairs table');
      QuizzerLogger.logSuccess('Question_answer_pairs table cleared successfully');
      
      // Clear modules table
      final bool modulesCleared = await deleteAllRecordsFromTable('modules');
      expect(modulesCleared, isTrue, reason: 'Failed to clear modules table');
      QuizzerLogger.logSuccess('Modules table cleared successfully');
      
      // Clear user_module_activation_status table
      final bool userModuleStatusCleared = await deleteAllRecordsFromTable('user_module_activation_status', userId: sessionManager.userId!, userIdColumn: 'user_id');
      expect(userModuleStatusCleared, isTrue, reason: 'Failed to clear user_module_activation_status table');
      QuizzerLogger.logSuccess('User_module_activation_status table cleared successfully');
      
      // Step 2: Generate select_all_that_apply questions using helper function
      QuizzerLogger.logMessage('Step 2: Generating select_all_that_apply questions...');
      final String testModule = 'TestModule_${DateTime.now().millisecondsSinceEpoch}';
      QuizzerLogger.logMessage('Using test module: $testModule');
      createdTestModules.add(testModule);
      final List<Map<String, dynamic>> questionData = generateQuestionInputData(
        questionType: 'select_all_that_apply',
        numberOfQuestions: 3,
        numberOfModules: 1,
        numberOfOptions: 4,
        customModuleName: testModule,
      );
      
      // Step 3: Add select_all_that_apply questions
      QuizzerLogger.logMessage('Step 3: Adding select_all_that_apply questions...');
      final stopwatch = Stopwatch()..start();
      
      int totalQuestionsAdded = 0;
      for (int i = 0; i < questionData.length; i++) {
        final Map<String, dynamic> data = questionData[i];
        
        final Map<String, dynamic> addResult = await sessionManager.addNewQuestion(
          questionType: data['questionType'],
          questionElements: data['questionElements'],
          answerElements: data['answerElements'],
          moduleName: data['moduleName'],
          options: data['options'],
          indexOptionsThatApply: data['indexOptionsThatApply'],
        );
          
        expect(addResult, isNotNull, reason: 'Add question ${i + 1} should return a result');
        totalQuestionsAdded++;
      }
      
      stopwatch.stop();
      final int elapsedMilliseconds = stopwatch.elapsedMilliseconds;
      QuizzerLogger.logMessage('Add select_all_that_apply questions API calls took ${elapsedMilliseconds}ms');
      
      // Step 4: Verify questions were added
      QuizzerLogger.logMessage('Step 4: Verifying select_all_that_apply questions were added...');
      final List<Map<String, dynamic>> questionsAfterAdd = await getAllQuestionAnswerPairs();
      final int afterAddCount = questionsAfterAdd.length;
      expect(afterAddCount, equals(totalQuestionsAdded), reason: 'Should have exactly $totalQuestionsAdded questions after adding');
      
      // Step 5: Verify question details
      final String normalizedModuleName = await normalizeString(testModule);
      final List<Map<String, dynamic>> moduleQuestions = questionsAfterAdd.where((q) => q['module_name'] == normalizedModuleName).toList();
      expect(moduleQuestions.length, equals(totalQuestionsAdded), reason: 'Should have $totalQuestionsAdded questions in the test module');
      
      // Verify all questions are select_all_that_apply
      for (final question in moduleQuestions) {
        expect(question['question_type'], equals('select_all_that_apply'), 
          reason: 'All questions should be select_all_that_apply type');
        expect(question['module_name'], equals(normalizedModuleName), 
          reason: 'All questions should be in correct module');
      }
      
      // Step 6: Verify module was created
      QuizzerLogger.logMessage('Step 6: Verifying module was created...');
      final db = getDatabaseMonitor().requestDatabaseAccess();
      final List<Map<String, dynamic>> modulesAfterAdd = await getAllModules(db);
      getDatabaseMonitor().releaseDatabaseAccess();

      final int moduleCount = modulesAfterAdd.length;
      expect(moduleCount, equals(1), reason: 'Should have exactly 1 module after adding questions');
      
      final bool moduleExists = modulesAfterAdd.any((m) => m['module_name'] == normalizedModuleName);
      expect(moduleExists, isTrue, reason: 'Test module should exist in modules table');
      
      // Store results for final report
      testResults['select_all_added'] = true;
      testResults['select_all_count'] = totalQuestionsAdded;
      testResults['select_all_performance_ms'] = elapsedMilliseconds;
      
      QuizzerLogger.logSuccess('Select all that apply questions added and module created successfully');
      QuizzerLogger.logSuccess('=== Test 4 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 4: Add sort_order questions and verify', () async {
      QuizzerLogger.logMessage('=== Test 4: Add sort_order questions and verify ===');
      
      // Step 1: Clear database state for clean test
      QuizzerLogger.logMessage('Step 1: Clearing database state...');
      
      // Clear question_answer_pairs table
      final bool questionsCleared = await deleteAllRecordsFromTable('question_answer_pairs');
      expect(questionsCleared, isTrue, reason: 'Failed to clear question_answer_pairs table');
      QuizzerLogger.logSuccess('Question_answer_pairs table cleared successfully');
      
      // Clear modules table
      final bool modulesCleared = await deleteAllRecordsFromTable('modules');
      expect(modulesCleared, isTrue, reason: 'Failed to clear modules table');
      QuizzerLogger.logSuccess('Modules table cleared successfully');
      
      // Clear user_module_activation_status table
      final bool userModuleStatusCleared = await deleteAllRecordsFromTable('user_module_activation_status', userId: sessionManager.userId!, userIdColumn: 'user_id');
      expect(userModuleStatusCleared, isTrue, reason: 'Failed to clear user_module_activation_status table');
      QuizzerLogger.logSuccess('User_module_activation_status table cleared successfully');
      
      // Step 2: Generate sort_order questions using helper function
      QuizzerLogger.logMessage('Step 2: Generating sort_order questions...');
      final String testModule = 'TestModule_${DateTime.now().millisecondsSinceEpoch}';
      QuizzerLogger.logMessage('Using test module: $testModule');
      createdTestModules.add(testModule);
      final List<Map<String, dynamic>> questionData = generateQuestionInputData(
        questionType: 'sort_order',
        numberOfQuestions: 3,
        numberOfModules: 1,
        numberOfOptions: 4,
        customModuleName: testModule,
      );
      
      // Step 3: Add sort_order questions
      QuizzerLogger.logMessage('Step 3: Adding sort_order questions...');
      final stopwatch = Stopwatch()..start();
      
      int totalQuestionsAdded = 0;
      for (int i = 0; i < questionData.length; i++) {
        final Map<String, dynamic> data = questionData[i];
        
        final Map<String, dynamic> addResult = await sessionManager.addNewQuestion(
          questionType: data['questionType'],
          questionElements: data['questionElements'],
          answerElements: data['answerElements'],
          moduleName: data['moduleName'],
          options: data['options'],
        );
          
        expect(addResult, isNotNull, reason: 'Add question ${i + 1} should return a result');
        totalQuestionsAdded++;
      }
      
      stopwatch.stop();
      final int elapsedMilliseconds = stopwatch.elapsedMilliseconds;
      QuizzerLogger.logMessage('Add sort_order questions API calls took ${elapsedMilliseconds}ms');
      
      // Step 4: Verify questions were added
      QuizzerLogger.logMessage('Step 4: Verifying sort_order questions were added...');
      final List<Map<String, dynamic>> questionsAfterAdd = await getAllQuestionAnswerPairs();
      final int afterAddCount = questionsAfterAdd.length;
      expect(afterAddCount, equals(totalQuestionsAdded), reason: 'Should have exactly $totalQuestionsAdded questions after adding');
      
      // Step 5: Verify question details
      final String normalizedModuleName = await normalizeString(testModule);
      final List<Map<String, dynamic>> moduleQuestions = questionsAfterAdd.where((q) => q['module_name'] == normalizedModuleName).toList();
      expect(moduleQuestions.length, equals(totalQuestionsAdded), reason: 'Should have $totalQuestionsAdded questions in the test module');
      
      // Verify all questions are sort_order
      for (final question in moduleQuestions) {
        expect(question['question_type'], equals('sort_order'), 
          reason: 'All questions should be sort_order type');
        expect(question['module_name'], equals(normalizedModuleName), 
          reason: 'All questions should be in correct module');
      }
      
      // Step 6: Verify module was created
      QuizzerLogger.logMessage('Step 6: Verifying module was created...');
      final db = getDatabaseMonitor().requestDatabaseAccess();
      final List<Map<String, dynamic>> modulesAfterAdd = await getAllModules(db);
      getDatabaseMonitor().releaseDatabaseAccess();

      final int moduleCount = modulesAfterAdd.length;
      expect(moduleCount, equals(1), reason: 'Should have exactly 1 module after adding questions');
      
      final bool moduleExists = modulesAfterAdd.any((m) => m['module_name'] == normalizedModuleName);
      expect(moduleExists, isTrue, reason: 'Test module should exist in modules table');
      
      // Store results for final report
      testResults['sort_order_added'] = true;
      testResults['sort_order_count'] = totalQuestionsAdded;
      testResults['sort_order_performance_ms'] = elapsedMilliseconds;
      
      QuizzerLogger.logSuccess('Sort order questions added and module created successfully');
      QuizzerLogger.logSuccess('=== Test 5 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 5: Add fill_in_the_blank questions and verify', () async {
      QuizzerLogger.logMessage('=== Test 5: Add fill_in_the_blank questions and verify ===');
      
      // Step 1: Clear database state for clean test
      QuizzerLogger.logMessage('Step 1: Clearing database state...');
      
      // Clear question_answer_pairs table
      final bool questionsCleared = await deleteAllRecordsFromTable('question_answer_pairs');
      expect(questionsCleared, isTrue, reason: 'Failed to clear question_answer_pairs table');
      QuizzerLogger.logSuccess('Question_answer_pairs table cleared successfully');
      
      // Clear modules table
      final bool modulesCleared = await deleteAllRecordsFromTable('modules');
      expect(modulesCleared, isTrue, reason: 'Failed to clear modules table');
      QuizzerLogger.logSuccess('Modules table cleared successfully');
      
      // Clear user_module_activation_status table
      final bool userModuleStatusCleared = await deleteAllRecordsFromTable('user_module_activation_status', userId: sessionManager.userId!, userIdColumn: 'user_id');
      expect(userModuleStatusCleared, isTrue, reason: 'Failed to clear user_module_activation_status table');
      QuizzerLogger.logSuccess('User_module_activation_status table cleared successfully');
      
      // Step 2: Generate fill_in_the_blank questions using helper function
      QuizzerLogger.logMessage('Step 2: Generating fill_in_the_blank questions...');
      final String testModule = 'TestModule_${DateTime.now().millisecondsSinceEpoch}';
      QuizzerLogger.logMessage('Using test module: $testModule');
      createdTestModules.add(testModule);
      final List<Map<String, dynamic>> questionData = generateQuestionInputData(
        questionType: 'fill_in_the_blank',
        numberOfQuestions: 3,
        numberOfModules: 1,
        customModuleName: testModule,
      );
      
      // Step 3: Add fill_in_the_blank questions
      QuizzerLogger.logMessage('Step 3: Adding fill_in_the_blank questions...');
      final stopwatch = Stopwatch()..start();
      
      int totalQuestionsAdded = 0;
      for (int i = 0; i < questionData.length; i++) {
        final Map<String, dynamic> data = questionData[i];
        
        final Map<String, dynamic> addResult = await sessionManager.addNewQuestion(
          questionType: data['questionType'],
          questionElements: data['questionElements'],
          answerElements: data['answerElements'],
          moduleName: data['moduleName'],
          answersToBlanks: data['answersToBlanks'],
        );
          
        expect(addResult, isNotNull, reason: 'Add question ${i + 1} should return a result');
        totalQuestionsAdded++;
      }
      
      stopwatch.stop();
      final int elapsedMilliseconds = stopwatch.elapsedMilliseconds;
      QuizzerLogger.logMessage('Add fill_in_the_blank questions API calls took ${elapsedMilliseconds}ms');
      
      // Step 4: Verify questions were added
      QuizzerLogger.logMessage('Step 4: Verifying fill_in_the_blank questions were added...');
      final List<Map<String, dynamic>> questionsAfterAdd = await getAllQuestionAnswerPairs();
      final int afterAddCount = questionsAfterAdd.length;
      expect(afterAddCount, equals(totalQuestionsAdded), reason: 'Should have exactly $totalQuestionsAdded questions after adding');
      
      // Step 5: Verify question details
      final String normalizedModuleName = await normalizeString(testModule);
      final List<Map<String, dynamic>> moduleQuestions = questionsAfterAdd.where((q) => q['module_name'] == normalizedModuleName).toList();
      expect(moduleQuestions.length, equals(totalQuestionsAdded), reason: 'Should have $totalQuestionsAdded questions in the test module');
      
      // Verify all questions are fill_in_the_blank
      for (final question in moduleQuestions) {
        expect(question['question_type'], equals('fill_in_the_blank'), 
          reason: 'All questions should be fill_in_the_blank type');
        expect(question['module_name'], equals(normalizedModuleName), 
          reason: 'All questions should be in correct module');
      }
      
      // Step 6: Verify module was created
      QuizzerLogger.logMessage('Step 6: Verifying module was created...');
      final db = getDatabaseMonitor().requestDatabaseAccess();
      final List<Map<String, dynamic>> modulesAfterAdd = await getAllModules(db);
      getDatabaseMonitor().requestDatabaseAccess();

      final int moduleCount = modulesAfterAdd.length;
      expect(moduleCount, equals(1), reason: 'Should have exactly 1 module after adding questions');
      
      final bool moduleExists = modulesAfterAdd.any((m) => m['module_name'] == normalizedModuleName);
      expect(moduleExists, isTrue, reason: 'Test module should exist in modules table');
      
      // Store results for final report
      testResults['fill_in_the_blank_added'] = true;
      testResults['fill_in_the_blank_count'] = totalQuestionsAdded;
      testResults['fill_in_the_blank_performance_ms'] = elapsedMilliseconds;
      
      QuizzerLogger.logSuccess('Fill-in-the-blank questions added and module created successfully');
      QuizzerLogger.logSuccess('=== Test 6 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('Test 6: Final comprehensive report', () async {
      QuizzerLogger.logMessage('=== Test 6: Final comprehensive report ===');
      
      // Get final counts
      final List<Map<String, dynamic>> finalQuestions = await getAllQuestionAnswerPairs();
      final db = getDatabaseMonitor().requestDatabaseAccess();
      final List<Map<String, dynamic>> finalModules = await getAllModules(db);
      getDatabaseMonitor().releaseDatabaseAccess();

      final int finalQuestionCount = finalQuestions.length;
      final int finalModuleCount = finalModules.length;
      
      // Calculate average performance
      final List<int> performanceTimes = [
        testResults['multiple_choice_performance_ms'] ?? 0,
        testResults['true_false_performance_ms'] ?? 0,
        testResults['select_all_performance_ms'] ?? 0,
        testResults['sort_order_performance_ms'] ?? 0,
        testResults['fill_in_the_blank_performance_ms'] ?? 0,
      ];
      final double averagePerformance = performanceTimes.reduce((a, b) => a + b) / performanceTimes.length;
      
      QuizzerLogger.printHeader('=== ADD QUESTIONS API COMPREHENSIVE REPORT ===');
      QuizzerLogger.printHeader('=== CLEANUP METRICS ===');
      QuizzerLogger.logMessage('Initial Questions Count: ${testResults['initial_questions_count']}');
      QuizzerLogger.logMessage('Initial Modules Count: ${testResults['initial_modules_count']}');
      QuizzerLogger.logMessage('Tables Cleared: ${testResults['tables_cleared'] == true ? 'YES' : 'NO'}');
      QuizzerLogger.logMessage('Final Questions Count: $finalQuestionCount');
      QuizzerLogger.logMessage('Final Modules Count: $finalModuleCount');
      QuizzerLogger.logMessage('');
      QuizzerLogger.printHeader('=== FUNCTIONALITY TESTS ===');
      QuizzerLogger.logMessage('Multiple Choice Questions: ${testResults['multiple_choice_added'] == true ? 'PASS' : 'FAIL'} (${testResults['multiple_choice_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('True/False Questions: ${testResults['true_false_added'] == true ? 'PASS' : 'FAIL'} (${testResults['true_false_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('Select All That Apply Questions: ${testResults['select_all_added'] == true ? 'PASS' : 'FAIL'} (${testResults['select_all_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('Sort Order Questions: ${testResults['sort_order_added'] == true ? 'PASS' : 'FAIL'} (${testResults['sort_order_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('Fill-in-the-Blank Questions: ${testResults['fill_in_the_blank_added'] == true ? 'PASS' : 'FAIL'} (${testResults['fill_in_the_blank_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('Module Creation: ${testResults['module_created'] == true ? 'PASS' : 'FAIL'} (5 modules created)');
      QuizzerLogger.logMessage('');
      QuizzerLogger.printHeader('=== PERFORMANCE METRICS ===');
      QuizzerLogger.logMessage('Average Add Question Time: ${averagePerformance.toStringAsFixed(1)}ms');
      QuizzerLogger.logMessage('Multiple Choice Performance: ${testResults['multiple_choice_performance_ms']}ms');
      QuizzerLogger.logMessage('True/False Performance: ${testResults['true_false_performance_ms']}ms');
      QuizzerLogger.logMessage('Select All Performance: ${testResults['select_all_performance_ms']}ms');
      QuizzerLogger.logMessage('Sort Order Performance: ${testResults['sort_order_performance_ms']}ms');
      QuizzerLogger.logMessage('Fill-in-the-Blank Performance: ${testResults['fill_in_the_blank_performance_ms']}ms');
      QuizzerLogger.printHeader('=== END COMPREHENSIVE REPORT ===');
      
      QuizzerLogger.logSuccess('=== Test 6 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('Test 7: Bulk question creation - 5 modules with 50 questions each', () async {
      QuizzerLogger.logMessage('=== Test 7: Bulk question creation - 5 modules with 50 questions each ===');
      
      // Step 1: Clear database state for clean test
      QuizzerLogger.logMessage('Step 1: Clearing database state...');
      
      // Clear question_answer_pairs table
      final bool questionsCleared = await deleteAllRecordsFromTable('question_answer_pairs');
      expect(questionsCleared, isTrue, reason: 'Failed to clear question_answer_pairs table');
      
      // Clear modules table
      final bool modulesCleared = await deleteAllRecordsFromTable('modules');
      expect(modulesCleared, isTrue, reason: 'Failed to clear modules table');
      
      // Clear user_module_activation_status table
      final bool activationCleared = await deleteAllRecordsFromTable('user_module_activation_status');
      expect(activationCleared, isTrue, reason: 'Failed to clear user_module_activation_status table');
      
      // Step 2: Get current counts after clearing (should be 0)
      QuizzerLogger.logMessage('Step 2: Getting current counts after clearing...');
      final List<Map<String, dynamic>> questionsBeforeBulk = await getAllQuestionAnswerPairs();
      final db = getDatabaseMonitor().requestDatabaseAccess();
      final List<Map<String, dynamic>> modulesBeforeBulk = await getAllModules(db);
      getDatabaseMonitor().releaseDatabaseAccess();
      final int questionsBeforeCount = questionsBeforeBulk.length;
      final int modulesBeforeCount = modulesBeforeBulk.length;
      QuizzerLogger.logMessage('Questions before bulk: $questionsBeforeCount');
      QuizzerLogger.logMessage('Modules before bulk: $modulesBeforeCount');
      
      // Verify tables are empty
      expect(questionsBeforeCount, equals(0), reason: 'Question_answer_pairs table should be empty after clearing');
      expect(modulesBeforeCount, equals(0), reason: 'Modules table should be empty after clearing');
      
      // Step 3: Create 5 test modules with 50 questions each using helper function
      QuizzerLogger.logMessage('Step 3: Creating 5 test modules with 50 questions each...');
      final stopwatch = Stopwatch()..start();
      
      final int timestamp = DateTime.now().millisecondsSinceEpoch;
      final List<String> testModules = [
        'BulkTestModule1_$timestamp',
        'BulkTestModule2_$timestamp',
        'BulkTestModule3_$timestamp',
        'BulkTestModule4_$timestamp',
        'BulkTestModule5_$timestamp',
      ];
      
      // Add bulk test modules to cleanup list
      createdTestModules.addAll(testModules);
      
      // Step 4: Generate all questions using helper function
      QuizzerLogger.logMessage('Step 4: Generating all questions...');
      
      final List<Map<String, dynamic>> allQuestionData = [];
      
      // Generate 10 questions of each type for each module (5 types × 10 = 50 per module)
      for (String moduleName in testModules) {
        
        // Generate 10 multiple choice questions
        final List<Map<String, dynamic>> multipleChoiceData = generateQuestionInputData(
          questionType: 'multiple_choice',
          numberOfQuestions: 10,
          numberOfModules: 1,
          numberOfOptions: 4,
          customModuleName: moduleName,
        );
        allQuestionData.addAll(multipleChoiceData);
        
        // Generate 10 true/false questions
        final List<Map<String, dynamic>> trueFalseData = generateQuestionInputData(
          questionType: 'true_false',
          numberOfQuestions: 10,
          numberOfModules: 1,
          numberOfOptions: 4,
          customModuleName: moduleName,
        );
        allQuestionData.addAll(trueFalseData);
        
        // Generate 10 select all that apply questions
        final List<Map<String, dynamic>> selectAllData = generateQuestionInputData(
          questionType: 'select_all_that_apply',
          numberOfQuestions: 10,
          numberOfModules: 1,
          numberOfOptions: 4,
          customModuleName: moduleName,
        );
        allQuestionData.addAll(selectAllData);
        
        // Generate 10 sort order questions
        final List<Map<String, dynamic>> sortOrderData = generateQuestionInputData(
          questionType: 'sort_order',
          numberOfQuestions: 10,
          numberOfModules: 1,
          numberOfOptions: 4,
          customModuleName: moduleName,
        );
        allQuestionData.addAll(sortOrderData);
        
        // Generate 10 fill in the blank questions
        final List<Map<String, dynamic>> fillInBlankData = generateQuestionInputData(
          questionType: 'fill_in_the_blank',
          numberOfQuestions: 10,
          numberOfModules: 1,
          numberOfOptions: 4,
          customModuleName: moduleName,
        );
        allQuestionData.addAll(fillInBlankData);
      }
      
      QuizzerLogger.logMessage('Generated ${allQuestionData.length} questions total');
      
      // Step 5: Add all questions to database
      QuizzerLogger.logMessage('Step 5: Adding all questions to database...');
      int totalQuestionsAdded = 0;
      
      for (int i = 0; i < allQuestionData.length; i++) {
        final Map<String, dynamic> data = allQuestionData[i];
        
        final Map<String, dynamic> addResult = await sessionManager.addNewQuestion(
          questionType: data['questionType'],
          questionElements: data['questionElements'],
          answerElements: data['answerElements'],
          moduleName: data['moduleName'],
          options: data['options'],
          correctOptionIndex: data['correctOptionIndex'],
          indexOptionsThatApply: data['indexOptionsThatApply'],
          answersToBlanks: data['answersToBlanks'],
        );
          
        expect(addResult, isNotNull, reason: 'Add question ${i + 1} should return a result');
        totalQuestionsAdded++;
        
        // Log progress every 50 questions
        if ((i + 1) % 50 == 0) {
          QuizzerLogger.logMessage('Added ${i + 1}/${allQuestionData.length} questions total');
        }
      }
      
      stopwatch.stop();
      final int elapsedMilliseconds = stopwatch.elapsedMilliseconds;
      final double averageTimePerQuestion = elapsedMilliseconds / totalQuestionsAdded;
      
      // Step 6: Verify all questions were added
      QuizzerLogger.logMessage('Step 6: Verifying all questions were added...');
      final List<Map<String, dynamic>> questionsAfterBulk = await getAllQuestionAnswerPairs();
      final db2 = getDatabaseMonitor().requestDatabaseAccess();
      final List<Map<String, dynamic>> modulesAfterBulk = await getAllModules(db2);
      getDatabaseMonitor().releaseDatabaseAccess();
      final int questionsAfterCount = questionsAfterBulk.length;
      final int modulesAfterCount = modulesAfterBulk.length;
      // Log all module names to see what they are
      QuizzerLogger.logMessage('All modules found:');
      for (int i = 0; i < modulesAfterBulk.length; i++) {
        final String moduleName = modulesAfterBulk[i]['module_name'] ?? 'unknown';
        QuizzerLogger.logMessage('  Module $i: $moduleName');
      }   
      expect(questionsAfterCount, equals(questionsBeforeCount + totalQuestionsAdded), 
        reason: 'Should have added exactly $totalQuestionsAdded questions');
      expect(modulesAfterCount, equals(modulesBeforeCount + testModules.length), 
        reason: 'Should have added exactly ${testModules.length} modules');
      
      // Step 7: Verify each module has the correct number of questions
      QuizzerLogger.logMessage('Step 7: Verifying question distribution...');
      for (final moduleName in testModules) {
        // Normalize the module name using the same function the app uses
        final String normalizedModuleName = await normalizeString(moduleName);
        final List<Map<String, dynamic>> moduleQuestions = questionsAfterBulk.where((q) => q['module_name'] == normalizedModuleName).toList();
        expect(moduleQuestions.length, equals(50), 
          reason: 'Module $normalizedModuleName should have exactly 50 questions');
        
        // Verify question types are distributed
        final Map<String, int> typeCounts = {};
        for (final question in moduleQuestions) {
          final String questionType = question['question_type'] as String;
          typeCounts[questionType] = (typeCounts[questionType] ?? 0) + 1;
        }
        
        // Should have roughly equal distribution of question types
        expect(typeCounts['multiple_choice'], greaterThan(8), 
          reason: 'Module $moduleName should have multiple choice questions');
        expect(typeCounts['true_false'], greaterThan(8), 
          reason: 'Module $moduleName should have true/false questions');
        expect(typeCounts['select_all_that_apply'], greaterThan(8), 
          reason: 'Module $moduleName should have select all questions');
        expect(typeCounts['sort_order'], greaterThan(8), 
          reason: 'Module $moduleName should have sort order questions');
        expect(typeCounts['fill_in_the_blank'], greaterThan(8), 
          reason: 'Module $moduleName should have fill-in-the-blank questions');
      }
      
      // Store results for final report
      testResults['bulk_questions_added'] = true;
      testResults['bulk_questions_count'] = totalQuestionsAdded;
      testResults['bulk_modules_count'] = testModules.length;
      testResults['bulk_performance_ms'] = elapsedMilliseconds;
      testResults['bulk_average_time_per_question'] = averageTimePerQuestion;
      
      QuizzerLogger.logSuccess('Bulk question creation completed successfully');
      QuizzerLogger.logValue('Total questions added: $totalQuestionsAdded');
      QuizzerLogger.logValue('Total modules created: ${testModules.length}');
      QuizzerLogger.logValue('Total time: ${elapsedMilliseconds}ms');
      QuizzerLogger.logValue('Average time per question: ${averageTimePerQuestion.toStringAsFixed(1)}ms');
      QuizzerLogger.logSuccess('=== Test 7 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 15)));
    
    test('Test 8: Final comprehensive report with bulk data', () async {
      QuizzerLogger.logMessage('=== Test 8: Final comprehensive report with bulk data ===');
      
      // Get final counts
      final List<Map<String, dynamic>> finalQuestions = await getAllQuestionAnswerPairs();
      final db = getDatabaseMonitor().requestDatabaseAccess();
      final List<Map<String, dynamic>> finalModules = await getAllModules(db);
      getDatabaseMonitor().releaseDatabaseAccess();
      final int finalQuestionCount = finalQuestions.length;
      final int finalModuleCount = finalModules.length;
      
      // Calculate performance metrics
      final List<int> performanceTimes = [
        testResults['multiple_choice_performance_ms'] ?? 0,
        testResults['true_false_performance_ms'] ?? 0,
        testResults['select_all_performance_ms'] ?? 0,
        testResults['sort_order_performance_ms'] ?? 0,
        testResults['fill_in_the_blank_performance_ms'] ?? 0,
      ];
      final double averagePerformance = performanceTimes.reduce((a, b) => a + b) / performanceTimes.length;
      
      QuizzerLogger.printHeader('=== FINAL COMPREHENSIVE REPORT ===');
      QuizzerLogger.printHeader('=== DATABASE METRICS ===');
      QuizzerLogger.logMessage('Initial Questions Count: ${testResults['initial_questions_count']}');
      QuizzerLogger.logMessage('Initial Modules Count: ${testResults['initial_modules_count']}');
      QuizzerLogger.logMessage('Tables Cleared: ${testResults['tables_cleared'] == true ? 'YES' : 'NO'}');
      QuizzerLogger.logMessage('Final Questions Count: $finalQuestionCount');
      QuizzerLogger.logMessage('Final Modules Count: $finalModuleCount');
      QuizzerLogger.logMessage('Total Questions Added: ${finalQuestionCount - (testResults['initial_questions_count'] ?? 0)}');
      QuizzerLogger.logMessage('Total Modules Added: ${finalModuleCount - (testResults['initial_modules_count'] ?? 0)}');
      QuizzerLogger.logMessage('');
      QuizzerLogger.printHeader('=== FUNCTIONALITY TESTS ===');
      QuizzerLogger.logMessage('Multiple Choice Questions: ${testResults['multiple_choice_added'] == true ? 'PASS' : 'FAIL'} (${testResults['multiple_choice_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('True/False Questions: ${testResults['true_false_added'] == true ? 'PASS' : 'FAIL'} (${testResults['true_false_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('Select All That Apply Questions: ${testResults['select_all_added'] == true ? 'PASS' : 'FAIL'} (${testResults['select_all_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('Sort Order Questions: ${testResults['sort_order_added'] == true ? 'PASS' : 'FAIL'} (${testResults['sort_order_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('Fill-in-the-Blank Questions: ${testResults['fill_in_the_blank_added'] == true ? 'PASS' : 'FAIL'} (${testResults['fill_in_the_blank_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('Module Creation: ${testResults['module_created'] == true ? 'PASS' : 'FAIL'} (5 initial modules created)');
      QuizzerLogger.logMessage('Bulk Question Creation: ${testResults['bulk_questions_added'] == true ? 'PASS' : 'FAIL'} (${testResults['bulk_questions_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('Bulk Module Creation: ${testResults['bulk_modules_count'] == true ? 'PASS' : 'FAIL'} (${testResults['bulk_modules_count'] ?? 0} modules)');
      QuizzerLogger.logMessage('');
      QuizzerLogger.printHeader('=== PERFORMANCE METRICS ===');
      QuizzerLogger.logMessage('Average Add Question Time (Initial): ${averagePerformance.toStringAsFixed(1)}ms');
      QuizzerLogger.logMessage('Bulk Creation Time: ${testResults['bulk_performance_ms']}ms');
      QuizzerLogger.logMessage('Bulk Average Time Per Question: ${testResults['bulk_average_time_per_question']?.toStringAsFixed(1)}ms');
      QuizzerLogger.logMessage('Multiple Choice Performance: ${testResults['multiple_choice_performance_ms']}ms');
      QuizzerLogger.logMessage('True/False Performance: ${testResults['true_false_performance_ms']}ms');
      QuizzerLogger.logMessage('Select All Performance: ${testResults['select_all_performance_ms']}ms');
      QuizzerLogger.logMessage('Sort Order Performance: ${testResults['sort_order_performance_ms']}ms');
      QuizzerLogger.logMessage('Fill-in-the-Blank Performance: ${testResults['fill_in_the_blank_performance_ms']}ms');
      QuizzerLogger.printHeader('=== END FINAL COMPREHENSIVE REPORT ===');
      
      QuizzerLogger.logSuccess('=== Test 8 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
