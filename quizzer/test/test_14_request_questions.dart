import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_module_activation_status_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';
import 'test_helpers.dart';
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
  });
  
  group('SessionManager Request Questions Tests', () {
    test('Test 1: Clear state, login setup, and activate two modules', () async {
      QuizzerLogger.logMessage('=== Test 1: Clear state, login setup, and activate two modules ===');
      
      // Step 1: Clear the user question answer pairs table
      QuizzerLogger.logMessage('Step 1: Clearing user question answer pairs table...');
      final resetSuccess = await resetUserQuestionAnswerPairsTable();
      expect(resetSuccess, isTrue, reason: 'Failed to reset user question answer pairs table');
      QuizzerLogger.logSuccess('User question answer pairs table cleared successfully');
      
      // Step 2: Deactivate all modules (before login)
      QuizzerLogger.logMessage('Step 2: Deactivating all modules...');
      final deactivationResult = await resetUserModuleActivationStatusTable();
      expect(deactivationResult, isTrue, reason: 'Failed to deactivate all modules');
      QuizzerLogger.logSuccess('All modules deactivated successfully');
      
      // Step 3: Login initialization (moved from setUpAll)
      QuizzerLogger.logMessage('Step 3: Calling loginInitialization with testRun=true...');
      final loginResult = await loginInitialization(
      email: testEmail, 
      password: testPassword, 
      supabase: sessionManager.supabase, 
        storage: sessionManager.getBox(testAccessPassword),
        testRun: true, // This bypasses sync workers
      );
      expect(loginResult['success'], isTrue, reason: 'Login initialization should succeed');
      QuizzerLogger.logSuccess('Login initialization completed successfully');
      
      // Step 4: Activate modules to get 101-150 questions total
      QuizzerLogger.logMessage('Step 4: Finding and activating modules to get 101-150 questions total...');
      
      // Find all modules with questions and their counts
      final List<Map<String, dynamic>> allModules = await getAllModules();
      final List<Map<String, dynamic>> modulesWithQuestionCounts = [];
      
      for (final module in allModules) {
        final String moduleName = module['module_name'] as String;
        final List<Map<String, dynamic>> moduleQuestions = await getQuestionRecordsForModule(moduleName);
        
        if (moduleQuestions.isNotEmpty) {
          modulesWithQuestionCounts.add({
            'module_name': moduleName,
            'question_count': moduleQuestions.length,
          });
          QuizzerLogger.logMessage('Found module with questions: $moduleName (${moduleQuestions.length} questions)');
        }
      }
      
      // Sort modules by question count (largest first) for efficient selection
      modulesWithQuestionCounts.sort((a, b) => (b['question_count'] as int).compareTo(a['question_count'] as int));
      
      // Systematically select modules to get 101-150 questions
      final List<String> selectedModules = [];
      int totalQuestions = 0;
      const int minQuestions = 101;
      const int maxQuestions = 150;
      
      for (final module in modulesWithQuestionCounts) {
        final String moduleName = module['module_name'] as String;
        final int questionCount = module['question_count'] as int;
        
        // Check if adding this module would keep us within range
        if (totalQuestions + questionCount <= maxQuestions) {
          selectedModules.add(moduleName);
          totalQuestions += questionCount;
          QuizzerLogger.logMessage('Selected module: $moduleName (+$questionCount questions, total: $totalQuestions)');
          
          // Stop if we have enough questions
          if (totalQuestions >= minQuestions) {
            break;
          }
        }
      }
      
      expect(selectedModules.length, greaterThan(0), 
        reason: 'Should have selected at least one module. Found: ${selectedModules.length}');
      expect(totalQuestions, greaterThanOrEqualTo(minQuestions), 
        reason: 'Should have at least $minQuestions questions. Found: $totalQuestions');
      expect(totalQuestions, lessThanOrEqualTo(maxQuestions), 
        reason: 'Should have no more than $maxQuestions questions. Found: $totalQuestions');
      QuizzerLogger.logSuccess('Selected ${selectedModules.length} modules with $totalQuestions total questions');
      
      // Activate the selected modules
      for (final moduleName in selectedModules) {
        QuizzerLogger.logMessage('Activating module: $moduleName');
        
        final bool activationResult = await updateModuleActivationStatus(sessionManager.userId!, moduleName, true);
        expect(activationResult, isTrue, reason: 'Failed to activate module: $moduleName');
        QuizzerLogger.logSuccess('Activated module: $moduleName');
      }
      
      QuizzerLogger.logSuccess('=== Test 1 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 2: Request next question and verify SessionManager state (expect dummy)', () async {
      QuizzerLogger.logMessage('=== Test 2: Request next question and verify SessionManager state (expect dummy) ===');
      
      // Request the next question
      QuizzerLogger.logMessage('Requesting next question...');
      await sessionManager.requestNextQuestion();
      
      // Verify SessionManager state
      QuizzerLogger.logMessage('Verifying SessionManager state...');
      
      // Check that question details were stored
      expect(sessionManager.currentQuestionStaticData, isNotNull, 
        reason: 'Question static data should be stored after request');
      expect(sessionManager.currentQuestionId, isNotNull, 
        reason: 'Question ID should be available after request');
      expect(sessionManager.currentQuestionType, isNotNull, 
        reason: 'Question type should be available after request');
      expect(sessionManager.timeQuestionDisplayed, isNotNull, 
        reason: 'Question display time should be set after request');
      
      // Check that question details contain required fields
      final questionData = sessionManager.currentQuestionStaticData!;
      expect(questionData['question_id'], isNotNull, 
        reason: 'Question data should contain question_id');
      expect(questionData['question_type'], isNotNull, 
        reason: 'Question data should contain question_type');
      expect(questionData['question_elements'], isNotNull, 
        reason: 'Question data should contain question_elements');
      expect(questionData['answer_elements'], isNotNull, 
        reason: 'Question data should contain answer_elements');
      
      QuizzerLogger.logSuccess('SessionManager state verified successfully');
      QuizzerLogger.logSuccess('=== Test 2 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 3: Verify the requested question is a dummy question (expected)', () async {
      QuizzerLogger.logMessage('=== Test 3: Verify the requested question is a dummy question (expected) ===');
      
      // Check that the current question IS the dummy question (expected after reset)
      final String questionId = sessionManager.currentQuestionId;
      expect(questionId, equals('dummy_no_questions'), 
        reason: 'Should get dummy question when no eligible questions are available');
      
      // Additional verification that it's a dummy question
      expect(sessionManager.currentQuestionStaticData!['module_name'], equals('System'), 
        reason: 'Should have System module name (indicates dummy question)');
      expect(sessionManager.currentQuestionStaticData!['qst_contrib'], equals('system'), 
        reason: 'Should have system contributor (indicates dummy question)');
      
      QuizzerLogger.logSuccess('Verified question is a dummy question (as expected)');
      QuizzerLogger.logSuccess('=== Test 3 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 4: Activate modules and verify activation', () async {
      QuizzerLogger.logMessage('=== Test 4: Activate modules and verify activation ===');
      
      // Find all modules with questions and their counts
      final List<Map<String, dynamic>> allModules = await getAllModules();
      final List<Map<String, dynamic>> modulesWithQuestionCounts = [];
      
      for (final module in allModules) {
        final String moduleName = module['module_name'] as String;
        final List<Map<String, dynamic>> moduleQuestions = await getQuestionRecordsForModule(moduleName);
        
        if (moduleQuestions.isNotEmpty) {
          modulesWithQuestionCounts.add({
            'module_name': moduleName,
            'question_count': moduleQuestions.length,
          });
          QuizzerLogger.logMessage('Found module with questions: $moduleName (${moduleQuestions.length} questions)');
        }
      }
      
      // Sort modules by question count (largest first) for efficient selection
      modulesWithQuestionCounts.sort((a, b) => (b['question_count'] as int).compareTo(a['question_count'] as int));
      
      // Systematically select modules to get 101-150 questions
      final List<String> selectedModules = [];
      int totalQuestions = 0;
      const int minQuestions = 101;
      const int maxQuestions = 150;
      
      for (final module in modulesWithQuestionCounts) {
        final String moduleName = module['module_name'] as String;
        final int questionCount = module['question_count'] as int;
        
        // Check if adding this module would keep us within range
        if (totalQuestions + questionCount <= maxQuestions) {
          selectedModules.add(moduleName);
          totalQuestions += questionCount;
          QuizzerLogger.logMessage('Selected module: $moduleName (+$questionCount questions, total: $totalQuestions)');
          
          // Stop if we have enough questions
          if (totalQuestions >= minQuestions) {
            break;
          }
        }
      }
      
      expect(selectedModules.length, greaterThan(0), 
        reason: 'Should have selected at least one module. Found: ${selectedModules.length}');
      expect(totalQuestions, greaterThanOrEqualTo(minQuestions), 
        reason: 'Should have at least $minQuestions questions. Found: $totalQuestions');
      expect(totalQuestions, lessThanOrEqualTo(maxQuestions), 
        reason: 'Should have no more than $maxQuestions questions. Found: $totalQuestions');
      QuizzerLogger.logSuccess('Selected ${selectedModules.length} modules with $totalQuestions total questions');
      
      // Activate the selected modules
      for (final moduleName in selectedModules) {
        QuizzerLogger.logMessage('Activating module: $moduleName');
        
        final bool activationResult = await updateModuleActivationStatus(sessionManager.userId!, moduleName, true);
        expect(activationResult, isTrue, reason: 'Failed to activate module: $moduleName');
        QuizzerLogger.logSuccess('Activated module: $moduleName');
      }
      
      // Verify that modules are activated
      for (final moduleName in selectedModules) {
        final Map<String, bool> activationStatus = await getModuleActivationStatus(sessionManager.userId!);
        final bool isActive = activationStatus[moduleName] ?? false;
        expect(isActive, isTrue, reason: 'Module $moduleName should be activated');
        QuizzerLogger.logSuccess('Verified module $moduleName is activated');
      }
      
      QuizzerLogger.logSuccess('=== Test 4 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
