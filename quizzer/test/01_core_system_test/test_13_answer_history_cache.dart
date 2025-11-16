import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/08_data_caches/answer_history_cache.dart';
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
    await performLoginProcess(
      email: testEmail, 
      password: testPassword, 
      supabase: sessionManager.supabase, 
      storage: sessionManager.getBox(testAccessPassword));
  });
  
  group('AnswerHistoryCache Tests', () {
    test('Should be a singleton - multiple instances should be the same', () async {
      QuizzerLogger.logMessage('Testing AnswerHistoryCache singleton pattern');
      
      try {
        // Create multiple instances
        final cache1 = AnswerHistoryCache();
        final cache2 = AnswerHistoryCache();
        final cache3 = AnswerHistoryCache();
        
        // Verify all instances are the same (singleton)
        expect(identical(cache1, cache2), isTrue, reason: 'Cache1 and Cache2 should be identical');
        expect(identical(cache2, cache3), isTrue, reason: 'Cache2 and Cache3 should be identical');
        expect(identical(cache1, cache3), isTrue, reason: 'Cache1 and Cache3 should be identical');
        
        QuizzerLogger.logSuccess('✅ AnswerHistoryCache singleton pattern verified');
        
      } catch (e) {
        QuizzerLogger.logError('AnswerHistoryCache singleton test failed: $e');
        rethrow;
      }
    });

    test('Should add question IDs and move duplicates to front', () async {
      QuizzerLogger.logMessage('Testing AnswerHistoryCache addRecord functionality');
      
      try {
        // Get the cache instance
        final cache = AnswerHistoryCache();
        
        // Clear the cache to ensure clean state
        QuizzerLogger.logMessage('Clearing cache to ensure clean state...');
        await cache.clear();
        
        // Generate test question IDs using helper
        final List<Map<String, dynamic>> testRecords = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 5);
        final List<String> testQuestionIds = testRecords.map((r) => r['question_id'] as String).toList();
        
        QuizzerLogger.logMessage('Generated test question IDs: $testQuestionIds');
        
        // Step 1: Add questions in sequence
        QuizzerLogger.logMessage('Step 1: Adding questions in sequence...');
        for (final String questionId in testQuestionIds) {
          await cache.addRecord(questionId);
        }
        
        // Step 2: Verify all questions are in history (most recent first)
        QuizzerLogger.logMessage('Step 2: Verifying questions are in history (most recent first)...');
        final List<String> history = await cache.peekHistory();
        expect(history.length, equals(5), reason: 'Should have 5 questions in history');
        
        // Verify order is most recent first (reversed from addition order)
        for (int i = 0; i < testQuestionIds.length; i++) {
          expect(history[i], equals(testQuestionIds[testQuestionIds.length - 1 - i]), 
            reason: 'History should be in reverse order (most recent first)');
        }
        QuizzerLogger.logSuccess('Verified questions are in correct order (most recent first)');
        
        // Step 3: Test duplicate handling - add a question that's already in the middle
        QuizzerLogger.logMessage('Step 3: Testing duplicate handling...');
        final String duplicateId = testQuestionIds[2]; // Middle question
        await cache.addRecord(duplicateId);
        
        // Verify the duplicate moved to the front
        final List<String> historyAfterDuplicate = await cache.peekHistory();
        expect(historyAfterDuplicate.length, equals(5), reason: 'Should still have 5 questions (no duplicates)');
        expect(historyAfterDuplicate.first, equals(duplicateId), reason: 'Duplicate should be moved to front');
        
        // Verify the duplicate is no longer in its original position
        final int originalPosition = historyAfterDuplicate.indexOf(duplicateId);
        expect(originalPosition, equals(0), reason: 'Duplicate should only appear at the front');
        
        QuizzerLogger.logSuccess('✅ Successfully verified addRecord and duplicate handling');
        
      } catch (e) {
        QuizzerLogger.logError('Add record test failed: $e');
        rethrow;
      }
    });

    test('Should correctly check if question is in recent history', () async {
      QuizzerLogger.logMessage('Testing AnswerHistoryCache isInRecentHistory functionality');
      
      try {
        // Get the cache instance
        final cache = AnswerHistoryCache();
        
        // Clear the cache to ensure clean state
        QuizzerLogger.logMessage('Clearing cache to ensure clean state...');
        await cache.clear();
        
        // Test 1: Empty cache
        QuizzerLogger.logMessage('Test 1: Testing empty cache...');
        final bool emptyResult = await cache.isInRecentHistory('test_question_1');
        expect(emptyResult, isFalse, reason: 'Empty cache should return false for any question');
        QuizzerLogger.logSuccess('Verified empty cache returns false');
        
        // Test 2: Add 3 questions and check recent history
        QuizzerLogger.logMessage('Test 2: Adding 3 questions and checking recent history...');
        final List<Map<String, dynamic>> testRecords = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 3);
        final List<String> testQuestionIds = testRecords.map((r) => r['question_id'] as String).toList();
        
        for (final String questionId in testQuestionIds) {
          await cache.addRecord(questionId);
        }
        
        // Check that all 3 questions are in recent history
        for (final String questionId in testQuestionIds) {
          final bool inRecent = await cache.isInRecentHistory(questionId);
          expect(inRecent, isTrue, reason: 'Question $questionId should be in recent history');
        }
        QuizzerLogger.logSuccess('Verified all 3 questions are in recent history');
        
        // Test 3: Add 2 more questions (total 5) and check recent history
        QuizzerLogger.logMessage('Test 3: Adding 2 more questions (total 5) and checking recent history...');
        final List<Map<String, dynamic>> additionalRecords = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 2);
        final List<String> additionalQuestionIds = additionalRecords.map((r) => r['question_id'] as String).toList();
        
        for (final String questionId in additionalQuestionIds) {
          await cache.addRecord(questionId);
        }
        
        // All 5 questions should be in recent history
        final List<String> allQuestionIds = [...testQuestionIds, ...additionalQuestionIds];
        for (final String questionId in allQuestionIds) {
          final bool inRecent = await cache.isInRecentHistory(questionId);
          expect(inRecent, isTrue, reason: 'Question $questionId should be in recent history');
        }
        QuizzerLogger.logSuccess('Verified all 5 questions are in recent history');
        
        // Test 4: Add 3 more questions (total 8) and check that oldest 3 are not in recent history
        QuizzerLogger.logMessage('Test 4: Adding 3 more questions (total 8) and checking recent history...');
        final List<Map<String, dynamic>> moreRecords = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 3);
        final List<String> moreQuestionIds = moreRecords.map((r) => r['question_id'] as String).toList();
        
        for (final String questionId in moreQuestionIds) {
          await cache.addRecord(questionId);
        }
        
        // Only the 5 most recent questions should be in recent history
        final List<String> recentQuestionIds = [...moreQuestionIds.reversed, ...additionalQuestionIds.reversed];
        for (final String questionId in recentQuestionIds) {
          final bool inRecent = await cache.isInRecentHistory(questionId);
          expect(inRecent, isTrue, reason: 'Recent question $questionId should be in recent history');
        }
        
        // Oldest questions should not be in recent history
        for (final String questionId in testQuestionIds) {
          final bool inRecent = await cache.isInRecentHistory(questionId);
          expect(inRecent, isFalse, reason: 'Old question $questionId should not be in recent history');
        }
        QuizzerLogger.logSuccess('Verified only 5 most recent questions are in recent history');
        
        QuizzerLogger.logSuccess('✅ Successfully verified isInRecentHistory functionality');
        
      } catch (e) {
        QuizzerLogger.logError('Recent history test failed: $e');
        rethrow;
      }
    });

    test('Should return correct last five answered questions', () async {
      QuizzerLogger.logMessage('Testing AnswerHistoryCache getLastFiveAnsweredQuestions functionality');
      
      try {
        // Get the cache instance
        final cache = AnswerHistoryCache();
        
        // Clear the cache to ensure clean state
        QuizzerLogger.logMessage('Clearing cache to ensure clean state...');
        await cache.clear();
        
        // Test 1: Empty cache
        QuizzerLogger.logMessage('Test 1: Testing empty cache...');
        final List<String> emptyResult = await cache.getLastFiveAnsweredQuestions();
        expect(emptyResult, isEmpty, reason: 'Empty cache should return empty list');
        QuizzerLogger.logSuccess('Verified empty cache returns empty list');
        
        // Test 2: Add 3 questions and get last five
        QuizzerLogger.logMessage('Test 2: Adding 3 questions and getting last five...');
        final List<Map<String, dynamic>> testRecords = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 3);
        final List<String> testQuestionIds = testRecords.map((r) => r['question_id'] as String).toList();
        
        for (final String questionId in testQuestionIds) {
          await cache.addRecord(questionId);
        }
        
        final List<String> lastFive = await cache.getLastFiveAnsweredQuestions();
        expect(lastFive.length, equals(3), reason: 'Should return all 3 questions when cache has 3');
        expect(lastFive, equals(testQuestionIds.reversed.toList()), reason: 'Should return questions in most recent first order');
        QuizzerLogger.logSuccess('Verified 3 questions returned in correct order');
        
        // Test 3: Add 2 more questions (total 5) and get last five
        QuizzerLogger.logMessage('Test 3: Adding 2 more questions (total 5) and getting last five...');
        final List<Map<String, dynamic>> additionalRecords = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 2);
        final List<String> additionalQuestionIds = additionalRecords.map((r) => r['question_id'] as String).toList();
        
        for (final String questionId in additionalQuestionIds) {
          await cache.addRecord(questionId);
        }
        
        final List<String> lastFiveWith5 = await cache.getLastFiveAnsweredQuestions();
        expect(lastFiveWith5.length, equals(5), reason: 'Should return all 5 questions when cache has 5');
        
        // Verify order (most recent first)
        final List<String> expectedOrder = [...additionalQuestionIds.reversed, ...testQuestionIds.reversed];
        expect(lastFiveWith5, equals(expectedOrder), reason: 'Should return questions in most recent first order');
        QuizzerLogger.logSuccess('Verified 5 questions returned in correct order');
        
        // Test 4: Add 3 more questions (total 8) and get last five
        QuizzerLogger.logMessage('Test 4: Adding 3 more questions (total 8) and getting last five...');
        final List<Map<String, dynamic>> moreRecords = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 3);
        final List<String> moreQuestionIds = moreRecords.map((r) => r['question_id'] as String).toList();
        
        for (final String questionId in moreQuestionIds) {
          await cache.addRecord(questionId);
        }
        
        final List<String> lastFiveWith8 = await cache.getLastFiveAnsweredQuestions();
        expect(lastFiveWith8.length, equals(5), reason: 'Should return only 5 questions when cache has 8');
        
        // Verify only the 5 most recent questions are returned
        final List<String> expectedRecentOrder = [...moreQuestionIds.reversed, ...additionalQuestionIds.reversed];
        expect(lastFiveWith8, equals(expectedRecentOrder), reason: 'Should return only 5 most recent questions in correct order');
        QuizzerLogger.logSuccess('Verified only 5 most recent questions returned');
        
        QuizzerLogger.logSuccess('✅ Successfully verified getLastFiveAnsweredQuestions functionality');
        
      } catch (e) {
        QuizzerLogger.logError('Get last five test failed: $e');
        rethrow;
      }
    });

    test('Should clear cache correctly', () async {
      QuizzerLogger.logMessage('Testing AnswerHistoryCache clear functionality');
      
      try {
        // Get the cache instance
        final cache = AnswerHistoryCache();
        
        // Test 1: Clear empty cache
        QuizzerLogger.logMessage('Test 1: Clearing empty cache...');
        await cache.clear();
        
        final List<String> emptyHistory = await cache.peekHistory();
        expect(emptyHistory, isEmpty, reason: 'Empty cache should remain empty after clear');
        QuizzerLogger.logSuccess('Verified clearing empty cache works');
        
        // Test 2: Add questions and then clear
        QuizzerLogger.logMessage('Test 2: Adding questions and then clearing...');
        final List<Map<String, dynamic>> testRecords = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 5);
        final List<String> testQuestionIds = testRecords.map((r) => r['question_id'] as String).toList();
        
        for (final String questionId in testQuestionIds) {
          await cache.addRecord(questionId);
        }
        
        // Verify questions were added
        final List<String> historyBeforeClear = await cache.peekHistory();
        expect(historyBeforeClear.length, equals(5), reason: 'Should have 5 questions before clear');
        
        // Clear the cache
        await cache.clear();
        
        // Verify cache is empty
        final List<String> historyAfterClear = await cache.peekHistory();
        expect(historyAfterClear, isEmpty, reason: 'Cache should be empty after clear');
        
        // Verify recent history check returns false
        for (final String questionId in testQuestionIds) {
          final bool inRecent = await cache.isInRecentHistory(questionId);
          expect(inRecent, isFalse, reason: 'Question $questionId should not be in recent history after clear');
        }
        
        // Verify get last five returns empty
        final List<String> lastFive = await cache.getLastFiveAnsweredQuestions();
        expect(lastFive, isEmpty, reason: 'getLastFiveAnsweredQuestions should return empty after clear');
        
        QuizzerLogger.logSuccess('✅ Successfully verified clear functionality');
        
      } catch (e) {
        QuizzerLogger.logError('Clear test failed: $e');
        rethrow;
      }
    });

    test('Should peek history correctly', () async {
      QuizzerLogger.logMessage('Testing AnswerHistoryCache peekHistory functionality');
      
      try {
        // Get the cache instance
        final cache = AnswerHistoryCache();
        
        // Clear the cache to ensure clean state
        QuizzerLogger.logMessage('Clearing cache to ensure clean state...');
        await cache.clear();
        
        // Test 1: Peek empty cache
        QuizzerLogger.logMessage('Test 1: Peeking empty cache...');
        final List<String> emptyHistory = await cache.peekHistory();
        expect(emptyHistory, isEmpty, reason: 'Empty cache should return empty list');
        QuizzerLogger.logSuccess('Verified empty cache returns empty list');
        
        // Test 2: Add questions and peek
        QuizzerLogger.logMessage('Test 2: Adding questions and peeking...');
        final List<Map<String, dynamic>> testRecords = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 3);
        final List<String> testQuestionIds = testRecords.map((r) => r['question_id'] as String).toList();
        
        for (final String questionId in testQuestionIds) {
          await cache.addRecord(questionId);
        }
        
        final List<String> peekedHistory = await cache.peekHistory();
        expect(peekedHistory.length, equals(3), reason: 'Should return all 3 questions');
        expect(peekedHistory, equals(testQuestionIds.reversed.toList()), reason: 'Should return questions in most recent first order');
        QuizzerLogger.logSuccess('Verified peek returns correct questions in correct order');
        
        // Test 3: Verify peek doesn't modify the cache
        QuizzerLogger.logMessage('Test 3: Verifying peek doesn\'t modify cache...');
        final List<String> peekedAgain = await cache.peekHistory();
        expect(peekedAgain.length, equals(3), reason: 'Cache should still have 3 questions after peek');
        expect(peekedAgain, equals(peekedHistory), reason: 'Peek should return same result');
        QuizzerLogger.logSuccess('Verified peek doesn\'t modify cache');
        
        // Test 4: Add more questions and verify peek reflects changes
        QuizzerLogger.logMessage('Test 4: Adding more questions and verifying peek reflects changes...');
        final List<Map<String, dynamic>> additionalRecords = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 2);
        final List<String> additionalQuestionIds = additionalRecords.map((r) => r['question_id'] as String).toList();
        
        for (final String questionId in additionalQuestionIds) {
          await cache.addRecord(questionId);
        }
        
        final List<String> updatedHistory = await cache.peekHistory();
        expect(updatedHistory.length, equals(5), reason: 'Should return all 5 questions after additions');
        
        // Verify order (most recent first)
        final List<String> expectedOrder = [...additionalQuestionIds.reversed, ...testQuestionIds.reversed];
        expect(updatedHistory, equals(expectedOrder), reason: 'Should return questions in most recent first order');
        QuizzerLogger.logSuccess('Verified peek reflects cache changes correctly');
        
        QuizzerLogger.logSuccess('✅ Successfully verified peekHistory functionality');
        
      } catch (e) {
        QuizzerLogger.logError('Peek history test failed: $e');
        rethrow;
      }
    });

    test('Should handle edge cases correctly', () async {
      QuizzerLogger.logMessage('Testing AnswerHistoryCache edge cases');
      
      try {
        // Get the cache instance
        final cache = AnswerHistoryCache();
        
        // Clear the cache to ensure clean state
        QuizzerLogger.logMessage('Clearing cache to ensure clean state...');
        await cache.clear();
        
        // Test 1: Empty question ID (should assert)
        QuizzerLogger.logMessage('Test 1: Testing empty question ID...');
        try {
          await cache.addRecord('');
          fail('Should have thrown assertion error for empty question ID');
        } catch (e) {
          // Expected assertion error
          QuizzerLogger.logSuccess('Verified empty question ID throws assertion error');
        }
        
        // Test 2: Rapid add/remove cycles
        QuizzerLogger.logMessage('Test 2: Testing rapid add/remove cycles...');
        final List<Map<String, dynamic>> testRecords = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 10);
        final List<String> testQuestionIds = testRecords.map((r) => r['question_id'] as String).toList();
        
        // Add questions rapidly
        for (final String questionId in testQuestionIds) {
          await cache.addRecord(questionId);
        }
        
        // Verify cache state is consistent
        final List<String> history = await cache.peekHistory();
        expect(history.length, equals(10), reason: 'Should have all 10 questions after rapid additions');
        
        // Clear and verify
        await cache.clear();
        final List<String> emptyHistory = await cache.peekHistory();
        expect(emptyHistory, isEmpty, reason: 'Cache should be empty after clear');
        
        QuizzerLogger.logSuccess('✅ Successfully verified edge case handling');
        
      } catch (e) {
        QuizzerLogger.logError('Edge cases test failed: $e');
        rethrow;
      }
    });
  });
}
