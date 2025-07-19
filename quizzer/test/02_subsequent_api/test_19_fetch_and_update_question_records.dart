import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';
import '../test_helpers.dart';
import 'dart:io';
import 'dart:math';

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
  final List<String> questionIds = []; // Store question IDs for testing
  
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
  
  group('SessionManager Fetch and Update Question Records Tests', () {
    test('Test 1: Login initialization and verify existing questions', () async {
      QuizzerLogger.logMessage('=== Test 1: Login initialization and verify existing questions ===');
      
      // Step 1: Login initialization
      QuizzerLogger.logMessage('Step 1: Calling loginInitialization with testRun=true...');
      final loginResult = await loginInitialization(
        email: testEmail, 
        password: testPassword, 
        supabase: sessionManager.supabase, 
        storage: sessionManager.getBox(testAccessPassword),
        testRun: true, // This bypasses sync workers
      );
      expect(loginResult['success'], isTrue, reason: 'Login initialization should succeed');
      QuizzerLogger.logSuccess('Login initialization completed successfully');
      
      // Step 2: Verify that user is logged in and ready
      expect(sessionManager.userId, isNotNull, reason: 'User should be logged in');
      QuizzerLogger.logSuccess('User is logged in and ready for testing');
      
      // Step 3: Get all existing questions from test_18
      QuizzerLogger.logMessage('Step 3: Getting all existing questions...');
      final List<Map<String, dynamic>> allQuestions = await getAllQuestionAnswerPairs();
      expect(allQuestions.length, greaterThanOrEqualTo(12), 
        reason: 'Should have at least 12 questions from previous test. Found: ${allQuestions.length}');
      QuizzerLogger.logSuccess('Found ${allQuestions.length} questions from previous test');
      
      // Step 4: Store question IDs for testing
      for (final question in allQuestions) {
        questionIds.add(question['question_id'] as String);
      }
      QuizzerLogger.logSuccess('Stored ${questionIds.length} question IDs for testing');
      
      // Store results for final report
      testResults['total_questions_found'] = allQuestions.length;
      testResults['question_ids_stored'] = questionIds.length;
      
      QuizzerLogger.logSuccess('=== Test 1 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 2: Test fetchQuestionDetailsById with valid question IDs', () async {
      QuizzerLogger.logMessage('=== Test 2: Test fetchQuestionDetailsById with valid question IDs ===');
      
      expect(questionIds.length, greaterThan(0), reason: 'Should have question IDs to test with');
      
      int successfulFetches = 0;
      int failedFetches = 0;
      
      // Test fetching each question
      for (final String questionId in questionIds) {
        QuizzerLogger.logMessage('Fetching details for question: $questionId');
        
        try {
          final Map<String, dynamic> questionDetails = await sessionManager.fetchQuestionDetailsById(questionId);
          
          // Verify the returned data structure
          expect(questionDetails, isNotNull, reason: 'Question details should not be null');
          expect(questionDetails['question_id'], equals(questionId), 
            reason: 'Returned question ID should match requested ID');
          expect(questionDetails['question_type'], isNotNull, 
            reason: 'Question type should be present');
          expect(questionDetails['question_elements'], isNotNull, 
            reason: 'Question elements should be present');
          expect(questionDetails['answer_elements'], isNotNull, 
            reason: 'Answer elements should be present');
          expect(questionDetails['module_name'], isNotNull, 
            reason: 'Module name should be present');
          
          QuizzerLogger.logSuccess('Successfully fetched question: $questionId (${questionDetails['question_type']})');
          successfulFetches++;
          
        } catch (e) {
          QuizzerLogger.logError('Failed to fetch question $questionId: $e');
          failedFetches++;
        }
      }
      
      expect(successfulFetches, equals(questionIds.length), reason: 'Should have successfully fetched all ${questionIds.length} questions. Got: $successfulFetches successful, $failedFetches failed');
      expect(failedFetches, equals(0), reason: 'Should have no failed fetches. Got: $failedFetches failed');
      QuizzerLogger.logSuccess('Fetch test completed: $successfulFetches successful, $failedFetches failed');
      
      // Store results
      testResults['successful_fetches'] = successfulFetches;
      testResults['failed_fetches'] = failedFetches;
      
      QuizzerLogger.logSuccess('=== Test 2 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 5)));
    
    test('Test 3: Test fetchQuestionDetailsById with invalid question IDs', () async {
      QuizzerLogger.logMessage('=== Test 3: Test fetchQuestionDetailsById with invalid question IDs ===');
      
      final List<String> invalidQuestionIds = [
        'non_existent_question_12345',
        'invalid_id_with_special_chars!@#',
        'very_long_question_id_that_should_not_exist_in_the_database_at_all_123456789012345678901234567890',
        '', // Empty string
      ];
      
      int expectedFailures = 0;
      
      for (final String invalidId in invalidQuestionIds) {
        QuizzerLogger.logMessage('Testing fetch with invalid ID: "$invalidId"');
        
        try {
          final Map<String, dynamic> questionDetails = await sessionManager.fetchQuestionDetailsById(invalidId);
          
          // If we get here, it means the API returned something for an invalid ID
          // This might be acceptable behavior (returning empty map) or might indicate an issue
          if (questionDetails.isEmpty) {
            QuizzerLogger.logSuccess('Invalid ID "$invalidId" correctly returned empty result');
          } else {
            QuizzerLogger.logWarning('Invalid ID "$invalidId" returned non-empty result: $questionDetails');
          }
          
        } catch (e) {
          QuizzerLogger.logSuccess('Invalid ID "$invalidId" correctly threw exception: $e');
          expectedFailures++;
        }
      }
      
      expect(expectedFailures, greaterThan(0), reason: 'Should have some expected failures for invalid IDs');
      QuizzerLogger.logSuccess('Invalid ID test completed: $expectedFailures expected failures');
      
      // Store results
      testResults['invalid_id_tests'] = invalidQuestionIds.length;
      testResults['expected_failures'] = expectedFailures;
      
      QuizzerLogger.logSuccess('=== Test 3 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 4: Test updateExistingQuestion with valid updates', () async {
      QuizzerLogger.logMessage('=== Test 4: Test updateExistingQuestion with valid updates ===');
      
      expect(questionIds.length, greaterThan(0), reason: 'Should have question IDs to test with');
      
      int successfulUpdates = 0;
      int failedUpdates = 0;
      
      // Test updating each question with different types of changes
      for (int i = 0; i < questionIds.length; i++) {
        final String questionId = questionIds[i];
        QuizzerLogger.logMessage('Updating question $i: $questionId');
        
        try {
          // Get original question details
          final Map<String, dynamic> originalDetails = await sessionManager.fetchQuestionDetailsById(questionId);
          
          // Create update data based on question type
          final Map<String, dynamic> updateData = _createUpdateDataForQuestion(originalDetails, i);
          
          // Perform the update
          final int rowsAffected = await sessionManager.updateExistingQuestion(
            questionId: questionId,
            citation: updateData['citation'],
            concepts: updateData['concepts'],
            subjects: updateData['subjects'],
            ansContrib: updateData['ansContrib'],
            hasBeenReviewed: updateData['hasBeenReviewed'],
            flagForRemoval: updateData['flagForRemoval'],
          );
          
          // Verify update was successful
          expect(rowsAffected, equals(1), reason: 'Should have updated exactly 1 row');
          
          // Fetch the updated question and verify changes
          final Map<String, dynamic> updatedDetails = await sessionManager.fetchQuestionDetailsById(questionId);
          
          // Verify the changes were applied
          expect(updatedDetails['citation'], equals(updateData['citation']), 
            reason: 'Citation should be updated');
          expect(updatedDetails['concepts'], equals(updateData['concepts']), 
            reason: 'Concepts should be updated');
          expect(updatedDetails['subjects'], equals(updateData['subjects']), 
            reason: 'Subjects should be updated');
          expect(updatedDetails['ans_contrib'], equals(updateData['ansContrib']), 
            reason: 'Answer contributor should be updated');
          expect(updatedDetails['has_been_reviewed'], equals(updateData['hasBeenReviewed'] ? 1 : 0), 
            reason: 'Has been reviewed should be updated');
          expect(updatedDetails['flag_for_removal'], equals(updateData['flagForRemoval'] ? 1 : 0), 
            reason: 'Flag for removal should be updated');
          
          QuizzerLogger.logSuccess('Successfully updated question: $questionId');
          successfulUpdates++;
          
        } catch (e) {
          QuizzerLogger.logError('Failed to update question $questionId: $e');
          failedUpdates++;
        }
      }
      
      expect(successfulUpdates, greaterThan(0), reason: 'Should have at least one successful update');
      QuizzerLogger.logSuccess('Update test completed: $successfulUpdates successful, $failedUpdates failed');
      
      // Store results
      testResults['successful_updates'] = successfulUpdates;
      testResults['failed_updates'] = failedUpdates;
      
      QuizzerLogger.logSuccess('=== Test 4 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 10)));
    
    test('Test 5: Test updateExistingQuestion with question content updates', () async {
      QuizzerLogger.logMessage('=== Test 5: Test updateExistingQuestion with question content updates ===');
      
      // Test updating question and answer elements for a few questions
      final int questionsToTest = min(3, questionIds.length);
      int successfulContentUpdates = 0;
      
      for (int i = 0; i < questionsToTest; i++) {
        final String questionId = questionIds[i];
        QuizzerLogger.logMessage('Testing content update for question: $questionId');
        
        try {          
          // Create new question and answer elements
          final List<Map<String, dynamic>> newQuestionElements = [
            {'type': 'text', 'content': 'Updated question content for test $i - ${DateTime.now().millisecondsSinceEpoch}'}
          ];
          
          final List<Map<String, dynamic>> newAnswerElements = [
            {'type': 'text', 'content': 'Updated answer content for test $i - ${DateTime.now().millisecondsSinceEpoch}'}
          ];
          
          // Perform the update
          final int rowsAffected = await sessionManager.updateExistingQuestion(
            questionId: questionId,
            questionElements: newQuestionElements,
            answerElements: newAnswerElements,
          );
          
          // Verify update was successful
          expect(rowsAffected, equals(1), reason: 'Should have updated exactly 1 row');
          
          // Fetch the updated question and verify changes
          final Map<String, dynamic> updatedDetails = await sessionManager.fetchQuestionDetailsById(questionId);
          
          // Verify the question elements were updated
          final List<dynamic> updatedQuestionElements = updatedDetails['question_elements'] as List<dynamic>;
          expect(updatedQuestionElements.length, equals(1), reason: 'Should have one question element');
          expect(updatedQuestionElements[0]['content'], equals(newQuestionElements[0]['content']), 
            reason: 'Question content should be updated');
          
          // Verify the answer elements were updated
          final List<dynamic> updatedAnswerElements = updatedDetails['answer_elements'] as List<dynamic>;
          expect(updatedAnswerElements.length, equals(1), reason: 'Should have one answer element');
          expect(updatedAnswerElements[0]['content'], equals(newAnswerElements[0]['content']), 
            reason: 'Answer content should be updated');
          
          QuizzerLogger.logSuccess('Successfully updated content for question: $questionId');
          successfulContentUpdates++;
          
        } catch (e) {
          QuizzerLogger.logError('Failed to update content for question $questionId: $e');
        }
      }
      
      expect(successfulContentUpdates, equals(questionsToTest), 
        reason: 'Should have successfully updated all test questions');
      QuizzerLogger.logSuccess('Content update test completed: $successfulContentUpdates successful');
      
      // Store results
      testResults['successful_content_updates'] = successfulContentUpdates;
      
      QuizzerLogger.logSuccess('=== Test 5 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 5)));
    
    test('Test 6: Test updateExistingQuestion with invalid parameters', () async {
      QuizzerLogger.logMessage('=== Test 6: Test updateExistingQuestion with invalid parameters ===');
      
      if (questionIds.isEmpty) {
        QuizzerLogger.logWarning('No question IDs available for invalid parameter testing');
        return;
      }
      
      final String testQuestionId = questionIds.first;
      int expectedFailures = 0;
      
      // Test 1: Invalid question ID
      QuizzerLogger.logMessage('Test 1: Testing with invalid question ID');
      try {
        await sessionManager.updateExistingQuestion(
          questionId: 'non_existent_question_12345',
          citation: 'Test citation',
        );
        QuizzerLogger.logWarning('Invalid question ID did not throw exception');
      } catch (e) {
        QuizzerLogger.logSuccess('Invalid question ID correctly threw exception: $e');
        expectedFailures++;
      }
      
      // Test 2: Null question ID
      QuizzerLogger.logMessage('Test 2: Testing with null question ID');
      try {
        await sessionManager.updateExistingQuestion(
          questionId: '', // Empty string
          citation: 'Test citation',
        );
        QuizzerLogger.logWarning('Empty question ID did not throw exception');
      } catch (e) {
        QuizzerLogger.logSuccess('Empty question ID correctly threw exception: $e');
        expectedFailures++;
      }
      
      // Test 3: Invalid question elements (null instead of list)
      QuizzerLogger.logMessage('Test 3: Testing with invalid question elements');
      try {
        await sessionManager.updateExistingQuestion(
          questionId: testQuestionId,
          questionElements: null, // This should be a list
        );
        QuizzerLogger.logWarning('Null question elements did not throw exception');
      } catch (e) {
        QuizzerLogger.logSuccess('Null question elements correctly threw exception: $e');
        expectedFailures++;
      }
      
      // Test 4: Invalid answer elements (empty list)
      QuizzerLogger.logMessage('Test 4: Testing with empty answer elements');
      try {
        await sessionManager.updateExistingQuestion(
          questionId: testQuestionId,
          answerElements: <Map<String, dynamic>>[], // Empty list
        );
        QuizzerLogger.logWarning('Empty answer elements did not throw exception');
      } catch (e) {
        QuizzerLogger.logSuccess('Empty answer elements correctly threw exception: $e');
        expectedFailures++;
      }
      
      expect(expectedFailures, greaterThan(0), reason: 'Should have some expected failures for invalid parameters');
      QuizzerLogger.logSuccess('Invalid parameter test completed: $expectedFailures expected failures');
      
      // Store results
      testResults['invalid_parameter_tests'] = 4;
      testResults['invalid_parameter_failures'] = expectedFailures;
      
      QuizzerLogger.logSuccess('=== Test 6 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 7: Test updateExistingQuestion with module name changes', () async {
      QuizzerLogger.logMessage('=== Test 7: Test updateExistingQuestion with module name changes ===');
      
      if (questionIds.length < 2) {
        QuizzerLogger.logWarning('Need at least 2 questions to test module name changes');
        return;
      }
      
      // Test updating module name for a few questions
      final int questionsToTest = min(2, questionIds.length);
      int successfulModuleUpdates = 0;
      
      for (int i = 0; i < questionsToTest; i++) {
        final String questionId = questionIds[i];
        final String newModuleName = 'UpdatedModule_${DateTime.now().millisecondsSinceEpoch}_$i';
        
        QuizzerLogger.logMessage('Testing module name update for question: $questionId -> $newModuleName');
        
        try {
          // Get original question details
          final Map<String, dynamic> originalDetails = await sessionManager.fetchQuestionDetailsById(questionId);
          final String originalModuleName = originalDetails['module_name'] as String;
          
          // Perform the update
          final int rowsAffected = await sessionManager.updateExistingQuestion(
            questionId: questionId,
            moduleName: newModuleName,
            originalModuleName: originalModuleName, // Provide original module name
          );
          
          // Verify update was successful
          expect(rowsAffected, equals(1), reason: 'Should have updated exactly 1 row');
          
          // Fetch the updated question and verify changes
          final Map<String, dynamic> updatedDetails = await sessionManager.fetchQuestionDetailsById(questionId);
          
          // Verify the module name was updated
          expect(updatedDetails['module_name'], equals(newModuleName), 
            reason: 'Module name should be updated');
          
          QuizzerLogger.logSuccess('Successfully updated module name for question: $questionId');
          successfulModuleUpdates++;
          
        } catch (e) {
          QuizzerLogger.logError('Failed to update module name for question $questionId: $e');
        }
      }
      
      expect(successfulModuleUpdates, equals(questionsToTest), 
        reason: 'Should have successfully updated all test questions');
      QuizzerLogger.logSuccess('Module name update test completed: $successfulModuleUpdates successful');
      
      // Store results
      testResults['successful_module_updates'] = successfulModuleUpdates;
      
      QuizzerLogger.logSuccess('=== Test 7 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 5)));
    
    test('Test 8: Final verification and comprehensive report', () async {
      QuizzerLogger.logMessage('=== Test 8: Final verification and comprehensive report ===');
      
      // Step 1: Verify all questions are still accessible
      QuizzerLogger.logMessage('Step 1: Verifying all questions are still accessible...');
      int accessibleQuestions = 0;
      
      for (final String questionId in questionIds) {
        try {
          final Map<String, dynamic> questionDetails = await sessionManager.fetchQuestionDetailsById(questionId);
          expect(questionDetails, isNotNull, reason: 'Question should still be accessible');
          expect(questionDetails['question_id'], equals(questionId), 
            reason: 'Question ID should match');
          accessibleQuestions++;
        } catch (e) {
          QuizzerLogger.logError('Question $questionId is no longer accessible: $e');
        }
      }
      
      expect(accessibleQuestions, equals(questionIds.length), 
        reason: 'All questions should still be accessible');
      QuizzerLogger.logSuccess('All $accessibleQuestions questions are still accessible');
      
      // Step 2: Generate comprehensive test report
      QuizzerLogger.logMessage('Step 2: Generating comprehensive test report...');
      
      final Map<String, dynamic> finalReport = {
        'test_summary': {
          'total_questions_tested': questionIds.length,
          'successful_fetches': testResults['successful_fetches'] ?? 0,
          'failed_fetches': testResults['failed_fetches'] ?? 0,
          'successful_updates': testResults['successful_updates'] ?? 0,
          'failed_updates': testResults['failed_updates'] ?? 0,
          'successful_content_updates': testResults['successful_content_updates'] ?? 0,
          'successful_module_updates': testResults['successful_module_updates'] ?? 0,
          'invalid_parameter_tests': testResults['invalid_parameter_tests'] ?? 0,
          'invalid_parameter_failures': testResults['invalid_parameter_failures'] ?? 0,
          'accessible_questions_final': accessibleQuestions,
        },
        'api_performance': {
          'fetch_api_working': (testResults['successful_fetches'] ?? 0) > 0,
          'update_api_working': (testResults['successful_updates'] ?? 0) > 0,
          'content_updates_working': (testResults['successful_content_updates'] ?? 0) > 0,
          'module_updates_working': (testResults['successful_module_updates'] ?? 0) > 0,
          'error_handling_working': (testResults['invalid_parameter_failures'] ?? 0) > 0,
        },
        'test_coverage': {
          'valid_fetch_tests': true,
          'invalid_fetch_tests': true,
          'valid_update_tests': true,
          'invalid_update_tests': true,
          'content_update_tests': true,
          'module_update_tests': true,
          'error_handling_tests': true,
        }
      };
      
      // Log the final report
      QuizzerLogger.printHeader('=== COMPREHENSIVE TEST REPORT ===');
      QuizzerLogger.logMessage('Total Questions Tested: ${finalReport['test_summary']['total_questions_tested']}');
      QuizzerLogger.logMessage('Successful Fetches: ${finalReport['test_summary']['successful_fetches']}');
      QuizzerLogger.logMessage('Failed Fetches: ${finalReport['test_summary']['failed_fetches']}');
      QuizzerLogger.logMessage('Successful Updates: ${finalReport['test_summary']['successful_updates']}');
      QuizzerLogger.logMessage('Failed Updates: ${finalReport['test_summary']['failed_updates']}');
      QuizzerLogger.logMessage('Content Updates: ${finalReport['test_summary']['successful_content_updates']}');
      QuizzerLogger.logMessage('Module Updates: ${finalReport['test_summary']['successful_module_updates']}');
      QuizzerLogger.logMessage('Invalid Parameter Tests: ${finalReport['test_summary']['invalid_parameter_tests']}');
      QuizzerLogger.logMessage('Invalid Parameter Failures: ${finalReport['test_summary']['invalid_parameter_failures']}');
      QuizzerLogger.logMessage('Final Accessible Questions: ${finalReport['test_summary']['accessible_questions_final']}');
      
      // Verify all APIs are working
      expect(finalReport['api_performance']['fetch_api_working'], isTrue, 
        reason: 'Fetch API should be working');
      expect(finalReport['api_performance']['update_api_working'], isTrue, 
        reason: 'Update API should be working');
      expect(finalReport['api_performance']['content_updates_working'], isTrue, 
        reason: 'Content updates should be working');
      expect(finalReport['api_performance']['module_updates_working'], isTrue, 
        reason: 'Module updates should be working');
      expect(finalReport['api_performance']['error_handling_working'], isTrue, 
        reason: 'Error handling should be working');
      
      QuizzerLogger.logSuccess('=== All APIs are functioning correctly ===');
      QuizzerLogger.logSuccess('=== Test 8 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

/// Helper function to create update data for a question based on its type and index
Map<String, dynamic> _createUpdateDataForQuestion(Map<String, dynamic> originalDetails, int index) {
  final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  
  return {
    'citation': 'Updated Citation $index - $timestamp',
    'concepts': 'Updated Concepts $index - $timestamp',
    'subjects': 'Updated Subjects $index - $timestamp',
    'ansContrib': 'test_user_$index',
    'hasBeenReviewed': index % 2 == 0, // Alternate between true and false
    'flagForRemoval': index % 3 == 0, // Every third question flagged
  };
}
