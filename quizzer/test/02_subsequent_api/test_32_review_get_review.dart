import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
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
  
  group('Review API Tests', () {
    test('Test 1: Check review table counts and handle empty tables', () async {
      QuizzerLogger.logMessage('=== Test 1: Check review table counts and handle empty tables ===');
      
      try {
        // Step 1: Get review table counts
        QuizzerLogger.logMessage('Step 1: Getting review table counts');
        final Map<String, int> reviewTableCounts = await getReviewTableCounts();
        
        QuizzerLogger.logMessage('Review table counts: $reviewTableCounts');
        
        // Verify we got valid counts
        expect(reviewTableCounts, isNotNull, reason: 'Should get review table counts');
        expect(reviewTableCounts.containsKey('new_review_count'), isTrue, reason: 'Should have new_review_count');
        expect(reviewTableCounts.containsKey('edits_review_count'), isTrue, reason: 'Should have edits_review_count');
        expect(reviewTableCounts.containsKey('total_review_count'), isTrue, reason: 'Should have total_review_count');
        
        // Log the counts
        QuizzerLogger.logMessage('NEW REVIEW TABLE COUNT: ${reviewTableCounts['new_review_count']}');
        QuizzerLogger.logMessage('EDITS REVIEW TABLE COUNT: ${reviewTableCounts['edits_review_count']}');
        QuizzerLogger.logMessage('TOTAL REVIEW COUNT: ${reviewTableCounts['total_review_count']}');
        
        // Step 2: Test review API based on table state
        QuizzerLogger.logMessage('Step 2: Testing review API based on table state');
        
        if (reviewTableCounts['total_review_count'] == 0) {
          QuizzerLogger.logMessage('Review tables are empty - testing empty state handling');
          
          // Test the review API when tables are empty
          final reviewResult = await sessionManager.getReviewQuestion();
          
          // Ensure we got a response
          expect(reviewResult, isNotNull, reason: 'Review API should return a response even when empty');
          expect(reviewResult, isA<Map<String, dynamic>>(), reason: 'Response should be a Map<String, dynamic>');
          
          // Check the expected structure for empty state
          expect(reviewResult.containsKey('data'), isTrue, reason: 'Response should contain data field');
          expect(reviewResult.containsKey('source_table'), isTrue, reason: 'Response should contain source_table field');
          expect(reviewResult.containsKey('primary_key'), isTrue, reason: 'Response should contain primary_key field');
          expect(reviewResult.containsKey('error'), isTrue, reason: 'Response should contain error field');
          
          // Verify empty state values
          expect(reviewResult['data'], isNull, reason: 'Data should be null when no questions available');
          expect(reviewResult['source_table'], isNull, reason: 'Source table should be null when no questions available');
          expect(reviewResult['primary_key'], isNull, reason: 'Primary key should be null when no questions available');
          expect(reviewResult['error'], isA<String>(), reason: 'Error should be a string message');
          expect(reviewResult['error'], isNotEmpty, reason: 'Error message should not be empty');
          
          QuizzerLogger.logSuccess('✅ Empty review tables handled correctly');
          QuizzerLogger.logMessage('Error message: ${reviewResult['error']}');
          
        } else {
          QuizzerLogger.logMessage('Review tables have data - testing normal operation');
          
          // Test the review API when tables have data
          for (int i = 1; i <= 5; i++) {
            QuizzerLogger.logMessage('Call $i/5: Calling getReviewQuestion() API...');
            final reviewResult = await sessionManager.getReviewQuestion();
            
            // Ensure we got a response
            expect(reviewResult, isNotNull, reason: 'Review API should return a response on call $i');
            expect(reviewResult, isA<Map<String, dynamic>>(), reason: 'Response should be a Map<String, dynamic> on call $i');
            
            // Check the expected structure
            expect(reviewResult.containsKey('data'), isTrue, reason: 'Response should contain data field');
            expect(reviewResult.containsKey('source_table'), isTrue, reason: 'Response should contain source_table field');
            expect(reviewResult.containsKey('primary_key'), isTrue, reason: 'Response should contain primary_key field');
            expect(reviewResult.containsKey('error'), isTrue, reason: 'Response should contain error field');
            
            if (reviewResult['error'] != null) {
              // No more questions available
              QuizzerLogger.logMessage('No more questions available: ${reviewResult['error']}');
              break;
            } else {
              // Got a question
              expect(reviewResult['data'], isNotNull, reason: 'Data should not be null when no error');
              expect(reviewResult['source_table'], isNotNull, reason: 'Source table should not be null when no error');
              expect(reviewResult['primary_key'], isNotNull, reason: 'Primary key should not be null when no error');
              
              QuizzerLogger.logSuccess('✅ Call $i/5 completed - got question data');
              QuizzerLogger.logMessage('Source table: ${reviewResult['source_table']}');
              QuizzerLogger.logMessage('Question ID: ${reviewResult['data']['question_id']}');
            }
          }
          
          QuizzerLogger.logSuccess('✅ Review API calls completed successfully');
        }
        
      } catch (e) {
        QuizzerLogger.logError('Review API test failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
