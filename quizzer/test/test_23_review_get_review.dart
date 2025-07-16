import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
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
    // Global variable to store review table counts
    Map<String, int>? reviewTableCounts;
    
    test('Test 1: Call the review API 10 times and ensure we get something back each time', () async {
      QuizzerLogger.logMessage('=== Test 1: Call the review API 10 times and ensure we get something back each time ===');
      
      try {
        for (int i = 1; i <= 10; i++) {
          QuizzerLogger.logMessage('Call ${i}/10: Calling getReviewQuestion() API...');
          final reviewResult = await sessionManager.getReviewQuestion();
          
          // Ensure we got a response
          expect(reviewResult, isNotNull, reason: 'Review API should return a response on call $i');
          expect(reviewResult, isA<Map<String, dynamic>>(), reason: 'Response should be a Map<String, dynamic> on call $i');
          
          QuizzerLogger.logSuccess('✅ Call $i/10 completed - got response back');
          QuizzerLogger.logMessage('Response keys: ${reviewResult.keys.join(', ')}');
          QuizzerLogger.logMessage('Full response: $reviewResult');
        }
        
        QuizzerLogger.logSuccess('✅ All 10 review API calls completed successfully');
        
      } catch (e) {
        QuizzerLogger.logError('Review API test failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
    
    test('Test 2: Check review table counts and store them in global variable', () async {
      QuizzerLogger.logMessage('=== Test 2: Check review table counts and store them in global variable ===');
      
      try {
        QuizzerLogger.logMessage('About to call getReviewTableCounts()...');
        
        // Get review table counts
        reviewTableCounts = await getReviewTableCounts();
        
        QuizzerLogger.logMessage('getReviewTableCounts() completed, result: $reviewTableCounts');
        
        // Verify we got valid counts
        expect(reviewTableCounts, isNotNull, reason: 'Should get review table counts');
        expect(reviewTableCounts!.containsKey('new_review_count'), isTrue, reason: 'Should have new_review_count');
        expect(reviewTableCounts!.containsKey('edits_review_count'), isTrue, reason: 'Should have edits_review_count');
        expect(reviewTableCounts!.containsKey('total_review_count'), isTrue, reason: 'Should have total_review_count');
        
        // Log the counts with explicit messages
        QuizzerLogger.logMessage('NEW REVIEW TABLE COUNT: ${reviewTableCounts!['new_review_count']}');
        QuizzerLogger.logMessage('EDITS REVIEW TABLE COUNT: ${reviewTableCounts!['edits_review_count']}');
        QuizzerLogger.logMessage('TOTAL REVIEW COUNT: ${reviewTableCounts!['total_review_count']}');
        
        QuizzerLogger.logSuccess('✅ Review table counts retrieved and stored in global variable');
        
      } catch (e) {
        QuizzerLogger.logError('Test 2 failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
