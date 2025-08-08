import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
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
  
  group('SessionManager Real Questions Tests', () {
    test('Test 1: Login initialization (without resetting state)', () async {
      QuizzerLogger.logMessage('=== Test 1: Login initialization (without resetting state) ===');
      
      // Login initialization (moved from setUpAll)
      QuizzerLogger.logMessage('Calling loginInitialization with testRun=true...');
      final loginResult = await loginInitialization(
        email: testEmail,
        password: testPassword,
        supabase: sessionManager.supabase,
        storage: sessionManager.getBox(testAccessPassword),
        testRun: true, // This bypasses sync workers
      );
      expect(loginResult['success'], isTrue, reason: 'Login initialization should succeed');
      QuizzerLogger.logSuccess('Login initialization completed successfully');
      
      QuizzerLogger.logSuccess('=== Test 1 completed successfully ===');
      
      // Give the Circulation Worker time to cycle and put questions into circulation
      QuizzerLogger.logMessage('Waiting 5 seconds for Circulation Worker to cycle...');
      await Future.delayed(const Duration(milliseconds: 1000));
      QuizzerLogger.logSuccess('Circulation Worker cycle wait completed');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 2: Expect eligible questions (should get real questions)', () async {
      QuizzerLogger.logMessage('=== Test 2: Expect eligible questions (should get real questions) ===');
      
      // Check that we have eligible questions
      QuizzerLogger.logMessage('Checking for eligible questions...');
      final eligibleQuestions = await getEligibleUserQuestionAnswerPairs(sessionManager.userId!);
      expect(eligibleQuestions.length, greaterThan(0), 
        reason: 'Should have eligible questions since modules were activated in test_14');
      QuizzerLogger.logSuccess('Found ${eligibleQuestions.length} eligible questions');
      
      QuizzerLogger.logSuccess('Verified we have eligible questions available');
      QuizzerLogger.logSuccess('=== Test 2 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 3: Request a question and verify it\'s not a dummy question', () async {
      QuizzerLogger.logMessage('=== Test 3: Request a question and verify it\'s not a dummy question ===');
      
      // Request a question
      QuizzerLogger.logMessage('Requesting next question...');
      await sessionManager.requestNextQuestion();
      
      // Verify we got a real question, not a dummy
      final String questionId = sessionManager.currentQuestionId;
      expect(questionId, isNot(equals('dummy_no_questions')), 
        reason: 'Should get real question when eligible questions are available');
      
      // Additional verification that it's a real question
      expect(sessionManager.currentQuestionStaticData!['module_name'], isNot(equals('System')), 
        reason: 'Should not have System module name (indicates dummy question)');
      expect(sessionManager.currentQuestionStaticData!['qst_contrib'], isNot(equals('system')), 
        reason: 'Should not have system contributor (indicates dummy question)');
      
      // Verify SessionManager state is properly set
      expect(sessionManager.currentQuestionStaticData, isNotNull, 
        reason: 'Question static data should be stored after request');
      expect(sessionManager.currentQuestionType, isNotNull, 
        reason: 'Question type should be available after request');
      expect(sessionManager.timeQuestionDisplayed, isNotNull, 
        reason: 'Question display time should be set after request');
      
      QuizzerLogger.logSuccess('Verified we got a real question, not a dummy');
      QuizzerLogger.logSuccess('=== Test 3 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
