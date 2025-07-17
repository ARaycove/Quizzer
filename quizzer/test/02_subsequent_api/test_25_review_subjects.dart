import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/00_database_manager/review_system/review_subject_nodes.dart';
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
    
    // Perform full login initialization (excluding sync workers for testing)
    final loginResult = await loginInitialization(
      email: testEmail, 
      password: testPassword, 
      supabase: sessionManager.supabase, 
      storage: sessionManager.getBox(testAccessPassword),
      testRun: true, // This bypasses sync workers for faster testing
    );
    
    expect(loginResult['success'], isTrue, reason: 'Login initialization should succeed');
    QuizzerLogger.logSuccess('Full login initialization completed successfully');
  });
  
  group('Subject Review Functions', () {
    test('Test 1: Direct function calls - 5 iterations', () async {
      QuizzerLogger.logMessage('Test 1: Testing subject review functions directly with 5 iterations');
      
      try {
        for (int i = 1; i <= 5; i++) {
          QuizzerLogger.logMessage('Iteration $i/5');
          
          // 1. Get random subject for review
          final reviewResult = await getSubjectForReview();
          
          if (reviewResult['error'] != null) {
            QuizzerLogger.logWarning('No subjects available for review on iteration $i: ${reviewResult['error']}');
            continue; // Skip to next iteration if no subjects available
          }
          
          expect(reviewResult['data'], isNotNull, reason: 'Should have data for iteration $i');
          expect(reviewResult['primary_key'], isNotNull, reason: 'Should have primary key for iteration $i');
          
          final Map<String, dynamic> subjectData = reviewResult['data'] as Map<String, dynamic>;
          final Map<String, dynamic> primaryKey = reviewResult['primary_key'] as Map<String, dynamic>;
          
          // 2. Extract the subject_description
          final String? subjectDescription = subjectData['subject_description'] as String?;
          QuizzerLogger.logMessage('Extracted subject_description: $subjectDescription for subject: ${subjectData['subject']}');
          
          // 3. Set a fresh timestamp to ensure data is new
          subjectData['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();
          QuizzerLogger.logMessage('Set fresh timestamp: ${subjectData['last_modified_timestamp']}');
          
          // 4. Call the update by passing in the same value that was just extracted
          final updateResult = await updateReviewedSubject(subjectData, primaryKey);
          
          expect(updateResult, isTrue, reason: 'Update should succeed for iteration $i');
          QuizzerLogger.logSuccess('Successfully updated subject in iteration $i');
        }
        
        QuizzerLogger.logSuccess('Completed all 5 iterations of Test 1');
        
      } catch (e) {
        QuizzerLogger.logError('Test 1 failed: $e');
        rethrow;
      }
    });

    test('Test 2: SessionManager calls - 5 iterations', () async {
      QuizzerLogger.logMessage('Test 2: Testing subject review functions through SessionManager with 5 iterations');
      
      try {
        for (int i = 1; i <= 5; i++) {
          QuizzerLogger.logMessage('Iteration $i/5');
          
          // 1. Get random subject for review through SessionManager
          final reviewResult = await sessionManager.getSubjectForReview();
          
          if (reviewResult['error'] != null) {
            QuizzerLogger.logWarning('No subjects available for review on iteration $i: ${reviewResult['error']}');
            continue; // Skip to next iteration if no subjects available
          }
          
          expect(reviewResult['data'], isNotNull, reason: 'Should have data for iteration $i');
          expect(reviewResult['primary_key'], isNotNull, reason: 'Should have primary key for iteration $i');
          
          final Map<String, dynamic> subjectData = reviewResult['data'] as Map<String, dynamic>;
          final Map<String, dynamic> primaryKey = reviewResult['primary_key'] as Map<String, dynamic>;
          
          // 2. Extract the subject_description
          final String? subjectDescription = subjectData['subject_description'] as String?;
          QuizzerLogger.logMessage('Extracted subject_description: $subjectDescription for subject: ${subjectData['subject']}');
          
          // 3. Set a fresh timestamp to ensure data is new
          subjectData['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();
          QuizzerLogger.logMessage('Set fresh timestamp: ${subjectData['last_modified_timestamp']}');
          
          // 4. Call the update through SessionManager by passing in the same value that was just extracted
          final updateResult = await sessionManager.updateReviewedSubject(subjectData, primaryKey);
          
          expect(updateResult, isTrue, reason: 'Update should succeed for iteration $i');
          QuizzerLogger.logSuccess('Successfully updated subject in iteration $i');
        }
        
        QuizzerLogger.logSuccess('Completed all 5 iterations of Test 2');
        
      } catch (e) {
        QuizzerLogger.logError('Test 2 failed: $e');
        rethrow;
      }
    });
  });
}
