import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/08_data_caches/question_queue_cache.dart';
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
  
  // Real questions from database - loaded once for all tests
  List<Map<String, dynamic>> realQuestions = [];
  
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
    
    // Get real questions from database once for all tests
    QuizzerLogger.logMessage('Loading real questions from database for all tests...');
    realQuestions = await getAllQuestionAnswerPairs();
    QuizzerLogger.logMessage('Loaded ${realQuestions.length} real questions for testing');
  });
  
  group('QuestionQueueCache Tests', () {
    test('Should be a singleton - multiple instances should be the same', () async {
      QuizzerLogger.logMessage('Testing QuestionQueueCache singleton pattern');
      
      try {
        // Create multiple instances
        final cache1 = QuestionQueueCache();
        final cache2 = QuestionQueueCache();
        final cache3 = QuestionQueueCache();
        
        // Verify all instances are the same (singleton)
        expect(identical(cache1, cache2), isTrue, reason: 'Cache1 and Cache2 should be identical');
        expect(identical(cache2, cache3), isTrue, reason: 'Cache2 and Cache3 should be identical');
        expect(identical(cache1, cache3), isTrue, reason: 'Cache1 and Cache3 should be identical');
        
        QuizzerLogger.logSuccess('✅ QuestionQueueCache singleton pattern verified');
        
      } catch (e) {
        QuizzerLogger.logError('QuestionQueueCache singleton test failed: $e');
        rethrow;
              }
      });

      test('Should return dummy record when cache is empty', () async {
        QuizzerLogger.logMessage('Testing QuestionQueueCache returns dummy record when empty');
        
        try {
          // Get the cache instance
          final cache = QuestionQueueCache();
          
          // Clear the cache to ensure it's empty
          QuizzerLogger.logMessage('Clearing cache to ensure empty state...');
          await cache.clear();
          
          // Verify cache is empty
          final isEmpty = await cache.isEmpty();
          expect(isEmpty, isTrue, reason: 'Cache should be empty after clearing');
          QuizzerLogger.logSuccess('Verified cache is empty');
          
          // Try to get a record from empty cache
          QuizzerLogger.logMessage('Attempting to get record from empty cache...');
          final record = await cache.getAndRemoveRecord();
          
          // Verify we got the dummy record structure
          expect(record, isA<Map<String, dynamic>>(), reason: 'Should return a Map');
          expect(record.containsKey('question_id'), isTrue, reason: 'Dummy record should have question_id');
          expect(record['question_id'], equals('dummy_no_questions'), reason: 'Dummy record should have correct question_id');
          expect(record.containsKey('question_type'), isTrue, reason: 'Dummy record should have question_type');
          expect(record['question_type'], equals('multiple_choice'), reason: 'Dummy record should be multiple_choice type');
          expect(record.containsKey('question_elements'), isTrue, reason: 'Dummy record should have question_elements');
          expect(record.containsKey('answer_elements'), isTrue, reason: 'Dummy record should have answer_elements');
          expect(record.containsKey('options'), isTrue, reason: 'Dummy record should have options');
          QuizzerLogger.logSuccess('✅ Successfully received proper dummy record from empty cache');
          
        } catch (e) {
          QuizzerLogger.logError('Empty cache test failed: $e');
          rethrow;
        }
      });

      test('Should add real questions and verify getAndRemove returns random questions', () async {
        QuizzerLogger.logMessage('Testing QuestionQueueCache with real questions - verifying random behavior');
        
        try {
          // Get the cache instance
          final cache = QuestionQueueCache();
          
          // Clear the cache to ensure clean state
          QuizzerLogger.logMessage('Clearing cache to ensure clean state...');
          await cache.clear();
          
          if (realQuestions.isEmpty) {
            QuizzerLogger.logWarning('No real questions found in database. Skipping this test.');
            return;
          }
          
          // Limit to 50 questions to avoid overwhelming the test
          final List<Map<String, dynamic>> testRecords = realQuestions.take(50).toList();
          QuizzerLogger.logSuccess('Got ${testRecords.length} real questions from database');
          
          // Step 2: Add all real records to the cache
          QuizzerLogger.logMessage('Step 2: Adding all real records to cache...');
          int addedCount = 0;
          for (final record in testRecords) {
            final bool added = await cache.addRecord(record);
            if (added) {
              addedCount++;
            }
          }
          QuizzerLogger.logSuccess('Added $addedCount records to cache');
          
          // Step 3: Verify the length of cache
          QuizzerLogger.logMessage('Step 3: Verifying cache length...');
          final int cacheLength = await cache.getLength();
          expect(cacheLength, equals(testRecords.length), reason: 'Cache should contain exactly ${testRecords.length} records');
          QuizzerLogger.logSuccess('Verified cache length: $cacheLength');
          
          // Step 4: Test getAndRemove functionality - should return random questions
          QuizzerLogger.logMessage('Step 4: Testing getAndRemove random behavior...');
          final List<String> retrievedQuestionIds = [];
          
          // Remove 10 questions and verify they come out randomly
          final int questionsToRemove = testRecords.length > 10 ? 10 : testRecords.length;
          for (int iteration = 0; iteration < questionsToRemove; iteration++) {
            QuizzerLogger.logMessage('Iteration ${iteration + 1}: Getting and removing a question...');
            
            // Get and remove a question
            final Map<String, dynamic> retrievedRecord = await cache.getAndRemoveRecord();
            final String questionId = retrievedRecord['question_id'] as String;
            
            // Verify it's not a dummy record
            expect(questionId, isNot(equals('dummy_no_questions')), 
              reason: 'Should not get dummy record when cache has questions');
            
            // Record the question ID
            retrievedQuestionIds.add(questionId);
            QuizzerLogger.logMessage('Retrieved question ID: $questionId');
            
            // Verify cache length decreased by 1
            final int currentLength = await cache.getLength();
            expect(currentLength, equals(testRecords.length - iteration - 1), 
              reason: 'Cache should have ${testRecords.length - iteration - 1} records after removing ${iteration + 1} questions');
          }
          
          // Step 5: Verify random behavior - should NOT get questions in sequential order
          QuizzerLogger.logMessage('Step 5: Verifying random behavior...');
          expect(retrievedQuestionIds.length, equals(questionsToRemove), reason: 'Should have retrieved $questionsToRemove question IDs');
          
          // Check that we did NOT get questions in the same order they were added
          // If the cache is truly random, we should NOT get the first N questions in the same order
          bool isSequential = true;
          final List<String> originalQuestionIds = testRecords.map((r) => r['question_id'] as String).toList();
          for (int i = 0; i < retrievedQuestionIds.length; i++) {
            if (i < originalQuestionIds.length && retrievedQuestionIds[i] != originalQuestionIds[i]) {
              isSequential = false;
              break;
            }
          }
          
          // The test should FAIL if we get sequential order (FIFO behavior)
          // The test should PASS if we get random order
          expect(isSequential, isFalse, 
            reason: 'Cache should return random questions, not sequential FIFO order. Got: ${retrievedQuestionIds.toList()}');
          
          QuizzerLogger.logSuccess('Retrieved questions in random order: ${retrievedQuestionIds.toList()}');
          
          // Step 6: Verify remaining cache length
          final int finalLength = await cache.getLength();
          expect(finalLength, equals(testRecords.length - questionsToRemove), reason: 'Cache should have ${testRecords.length - questionsToRemove} records remaining after removing $questionsToRemove');
          QuizzerLogger.logSuccess('Final cache length: $finalLength');
          
          QuizzerLogger.logSuccess('✅ Successfully verified QuestionQueueCache random behavior with ${testRecords.length} real questions');
          
        } catch (e) {
          QuizzerLogger.logError('Random test failed: $e');
          rethrow;
        }
      });

      test('Should correctly report cache length after adding different numbers of questions', () async {
        QuizzerLogger.logMessage('Testing QuestionQueueCache getLength() method with various question counts');
        
        try {
          // Get the cache instance
          final cache = QuestionQueueCache();
          
          if (realQuestions.isEmpty) {
            QuizzerLogger.logWarning('No real questions found in database. Skipping this test.');
            return;
          }
          
          // Generate 5 random numbers between 1 and min(20, realQuestions.length)
          final random = Random();
          final int maxQuestions = realQuestions.length > 20 ? 20 : realQuestions.length;
          final List<int> testCounts = [];
          for (int i = 0; i < 5; i++) {
            testCounts.add(random.nextInt(maxQuestions) + 1); // 1 to maxQuestions inclusive
          }
          
          QuizzerLogger.logMessage('Generated test counts: $testCounts');
          
          // Test each count
          for (int testIndex = 0; testIndex < testCounts.length; testIndex++) {
            final int questionCount = testCounts[testIndex];
            QuizzerLogger.logMessage('Test ${testIndex + 1}: Testing with $questionCount questions');
            
            // Clear the cache to ensure clean state
            QuizzerLogger.logMessage('Clearing cache for test ${testIndex + 1}...');
            await cache.clear();
            
            // Verify cache is empty
            final bool isEmpty = await cache.isEmpty();
            expect(isEmpty, isTrue, reason: 'Cache should be empty after clearing');
            final int emptyLength = await cache.getLength();
            expect(emptyLength, equals(0), reason: 'Cache length should be 0 after clearing');
            QuizzerLogger.logSuccess('Verified cache is empty (length: $emptyLength)');
            
            // Get real questions for this test
            QuizzerLogger.logMessage('Getting $questionCount real questions...');
            final List<Map<String, dynamic>> testRecords = realQuestions.take(questionCount).toList();
            
            // Add all questions to cache
            QuizzerLogger.logMessage('Adding $questionCount questions to cache...');
            int addedCount = 0;
            for (final record in testRecords) {
              final bool added = await cache.addRecord(record);
              if (added) {
                addedCount++;
              }
            }
            QuizzerLogger.logSuccess('Added $addedCount questions to cache');
            
            // Verify the length using getLength()
            QuizzerLogger.logMessage('Verifying cache length using getLength()...');
            final int reportedLength = await cache.getLength();
            expect(reportedLength, equals(questionCount), 
              reason: 'Cache length should be $questionCount, but getLength() reported $reportedLength');
            QuizzerLogger.logSuccess('Verified cache length: $reportedLength (expected: $questionCount)');
            
            // Additional verification: Check that isEmpty() returns false
            final bool isNotEmpty = await cache.isEmpty();
            expect(isNotEmpty, isFalse, reason: 'Cache should not be empty after adding questions');
            QuizzerLogger.logSuccess('Verified cache is not empty');
            
            // Clear cache for next iteration
            QuizzerLogger.logMessage('Clearing cache for next test...');
            await cache.clear();
            
            // Verify cache is empty again
            final int finalLength = await cache.getLength();
            expect(finalLength, equals(0), reason: 'Cache should be empty after clearing');
            QuizzerLogger.logSuccess('Verified cache is empty again (length: $finalLength)');
            
            QuizzerLogger.logSuccess('✅ Test ${testIndex + 1} completed successfully with $questionCount questions');
          }
          
          QuizzerLogger.logSuccess('✅ Successfully verified getLength() method with all test counts: $testCounts');
          
        } catch (e) {
          QuizzerLogger.logError('Length test failed: $e');
          rethrow;
        }
      });

      test('Should correctly report empty state using isEmpty() method', () async {
        QuizzerLogger.logMessage('Testing QuestionQueueCache isEmpty() method');
        
        try {
          // Get the cache instance
          final cache = QuestionQueueCache();
          
          if (realQuestions.isEmpty) {
            QuizzerLogger.logWarning('No real questions found in database. Skipping this test.');
            return;
          }
          
          // Test 1: Verify cache starts empty
          QuizzerLogger.logMessage('Test 1: Verifying cache starts empty...');
          final bool startsEmpty = await cache.isEmpty();
          expect(startsEmpty, isTrue, reason: 'Cache should start empty');
          QuizzerLogger.logSuccess('Verified cache starts empty');
          
          // Test 2: Add one question and verify not empty
          QuizzerLogger.logMessage('Test 2: Adding one question and verifying not empty...');
          final Map<String, dynamic> singleQuestion = realQuestions.first;
          final bool added = await cache.addRecord(singleQuestion);
          expect(added, isTrue, reason: 'Should be able to add question to cache');
          
          final bool notEmptyAfterAdd = await cache.isEmpty();
          expect(notEmptyAfterAdd, isFalse, reason: 'Cache should not be empty after adding a question');
          QuizzerLogger.logSuccess('Verified cache is not empty after adding one question');
          
          // Test 3: Remove the question and verify empty again
          QuizzerLogger.logMessage('Test 3: Removing question and verifying empty again...');
          final removedRecord = await cache.getAndRemoveRecord();
          expect(removedRecord['question_id'], equals(singleQuestion['question_id']), 
            reason: 'Should get the question we added');
          
          final bool emptyAfterRemove = await cache.isEmpty();
          expect(emptyAfterRemove, isTrue, reason: 'Cache should be empty after removing the question');
          QuizzerLogger.logSuccess('Verified cache is empty after removing the question');
          
          // Test 4: Add multiple questions and verify not empty
          QuizzerLogger.logMessage('Test 4: Adding multiple questions and verifying not empty...');
          final List<Map<String, dynamic>> multipleQuestions = realQuestions.take(5).toList();
          int addedCount = 0;
          for (final record in multipleQuestions) {
            final bool questionAdded = await cache.addRecord(record);
            if (questionAdded) {
              addedCount++;
            }
          }
          expect(addedCount, equals(5), reason: 'Should have added 5 questions');
          
          final bool notEmptyWithMultiple = await cache.isEmpty();
          expect(notEmptyWithMultiple, isFalse, reason: 'Cache should not be empty with multiple questions');
          QuizzerLogger.logSuccess('Verified cache is not empty with multiple questions');
          
          // Test 5: Clear cache and verify empty
          QuizzerLogger.logMessage('Test 5: Clearing cache and verifying empty...');
          await cache.clear();
          
          final bool emptyAfterClear = await cache.isEmpty();
          expect(emptyAfterClear, isTrue, reason: 'Cache should be empty after clearing');
          QuizzerLogger.logSuccess('Verified cache is empty after clearing');
          
          // Test 6: Add and remove questions one by one, checking empty state each time
          QuizzerLogger.logMessage('Test 6: Testing empty state during add/remove cycle...');
          final List<Map<String, dynamic>> cycleQuestions = realQuestions.take(3).toList();
          
          for (int i = 0; i < cycleQuestions.length; i++) {
            final Map<String, dynamic> question = cycleQuestions[i];
            final String questionId = question['question_id'] as String;
            
            // Add question
            final bool questionAdded = await cache.addRecord(question);
            expect(questionAdded, isTrue, reason: 'Should be able to add question $i');
            
            // Verify not empty
            final bool notEmpty = await cache.isEmpty();
            expect(notEmpty, isFalse, reason: 'Cache should not be empty after adding question $i');
            
            // Remove question
            final removedRecord = await cache.getAndRemoveRecord();
            expect(removedRecord['question_id'], equals(questionId), 
              reason: 'Should get the question we just added');
            
            // Verify empty (since we're removing one by one)
            final bool empty = await cache.isEmpty();
            expect(empty, isTrue, reason: 'Cache should be empty after removing question $i');
            
            QuizzerLogger.logSuccess('Completed cycle $i: add → not empty → remove → empty');
          }
          
          // Test 7: Verify final empty state
          QuizzerLogger.logMessage('Test 7: Verifying final empty state...');
          final bool finalEmpty = await cache.isEmpty();
          expect(finalEmpty, isTrue, reason: 'Cache should be empty at the end');
          QuizzerLogger.logSuccess('Verified final empty state');
          
          QuizzerLogger.logSuccess('✅ Successfully verified isEmpty() method with all test scenarios');
          
        } catch (e) {
          QuizzerLogger.logError('isEmpty test failed: $e');
          rethrow;
        }
      });

      test('Should correctly return all records using peekAllRecords() method', () async {
        QuizzerLogger.logMessage('Testing QuestionQueueCache peekAllRecords() method');
        
        try {
          // Get the cache instance
          final cache = QuestionQueueCache();
          
          // Step 1: Clear cache to ensure clean state
          QuizzerLogger.logMessage('Step 1: Clearing cache to ensure clean state...');
          await cache.clear();
          
          // Verify cache is empty
          final bool isEmpty = await cache.isEmpty();
          expect(isEmpty, isTrue, reason: 'Cache should be empty after clearing');
          QuizzerLogger.logSuccess('Verified cache is empty after clearing');
          
          if (realQuestions.isEmpty) {
            QuizzerLogger.logWarning('No real questions found in database. Skipping this test.');
            return;
          }
          
          final List<Map<String, dynamic>> testRecords = realQuestions.take(5).toList();
          
          // Step 3: Add the questions to cache
          QuizzerLogger.logMessage('Step 3: Adding questions to cache...');
          int addedCount = 0;
          for (final record in testRecords) {
            final bool added = await cache.addRecord(record);
            if (added) {
              addedCount++;
            }
          }
          expect(addedCount, equals(5), reason: 'Should have added all 5 questions');
          QuizzerLogger.logSuccess('Added $addedCount questions to cache');
          
          // Step 4: Use peekAllRecords and compare with real questions
          QuizzerLogger.logMessage('Step 4: Using peekAllRecords and comparing with real questions...');
          final List<Map<String, dynamic>> peekedRecords = await cache.peekAllRecords();
          
          // Verify peekAllRecords returns the correct number of records
          expect(peekedRecords.length, equals(testRecords.length), 
            reason: 'peekAllRecords should return same number of records as real questions');
          
          // Verify all real questions are present in peeked records
          for (final Map<String, dynamic> realRecord in testRecords) {
            final String realQuestionId = realRecord['question_id'] as String;
            final bool foundInPeeked = peekedRecords.any((peekedRecord) => 
              peekedRecord['question_id'] == realQuestionId);
            expect(foundInPeeked, isTrue, 
              reason: 'Real question $realQuestionId should be found in peeked records');
          }
          QuizzerLogger.logSuccess('Verified all real questions are present in peeked records');
          
          // Verify peekAllRecords doesn't remove records (cache length unchanged)
          final int lengthBeforePeek = await cache.getLength();
          final List<Map<String, dynamic>> peekedAgain = await cache.peekAllRecords();
          final int lengthAfterPeek = await cache.getLength();
          
          expect(lengthBeforePeek, equals(lengthAfterPeek), 
            reason: 'Cache length should be unchanged after peekAllRecords');
          expect(peekedAgain.length, equals(testRecords.length), 
            reason: 'Should still have all questions after peek');
          QuizzerLogger.logSuccess('Verified peekAllRecords doesn\'t remove records (length: $lengthAfterPeek)');
          
          // Verify record structure is correct
          for (final Map<String, dynamic> peekedRecord in peekedRecords) {
            expect(peekedRecord.containsKey('question_id'), isTrue, reason: 'Peeked record should have question_id');
            expect(peekedRecord.containsKey('question_type'), isTrue, reason: 'Peeked record should have question_type');
            expect(peekedRecord.containsKey('question_elements'), isTrue, reason: 'Peeked record should have question_elements');
            expect(peekedRecord.containsKey('answer_elements'), isTrue, reason: 'Peeked record should have answer_elements');
            expect(peekedRecord.containsKey('options'), isTrue, reason: 'Peeked record should have options');
          }
          QuizzerLogger.logSuccess('Verified all peeked records have correct structure');
          
          QuizzerLogger.logSuccess('✅ Successfully verified peekAllRecords() method');
          
        } catch (e) {
          QuizzerLogger.logError('peekAllRecords test failed: $e');
          rethrow;
        }
      });

      test('Should correctly check for question existence using containsQuestionId() method', () async {
        QuizzerLogger.logMessage('Testing QuestionQueueCache containsQuestionId() method');
        
        try {
          // Get the cache instance
          final cache = QuestionQueueCache();
          
          // Step 1: Clear cache to ensure clean state
          QuizzerLogger.logMessage('Step 1: Clearing cache to ensure clean state...');
          await cache.clear();
          
          // Verify cache is empty
          final bool isEmpty = await cache.isEmpty();
          expect(isEmpty, isTrue, reason: 'Cache should be empty after clearing');
          QuizzerLogger.logSuccess('Verified cache is empty after clearing');
          
          if (realQuestions.isEmpty) {
            QuizzerLogger.logWarning('No real questions found in database. Skipping this test.');
            return;
          }
          
          final List<Map<String, dynamic>> testRecords = realQuestions.take(5).toList();
          
          // Step 3: Add questions one by one and verify containsQuestionId after each addition
          QuizzerLogger.logMessage('Step 3: Adding questions one by one and verifying containsQuestionId...');
          for (int i = 0; i < testRecords.length; i++) {
            final Map<String, dynamic> record = testRecords[i];
            final String questionId = record['question_id'] as String;
            
            // Add the question
            final bool added = await cache.addRecord(record);
            expect(added, isTrue, reason: 'Should be able to add question $questionId');
            
            // Verify containsQuestionId returns true for this question
            final bool contains = await cache.containsQuestionId(questionId);
            expect(contains, isTrue, reason: 'Cache should contain question $questionId after adding it');
            
            // Verify containsQuestionId returns false for non-existent questions
            final bool containsNonExistent = await cache.containsQuestionId('non_existent_$questionId');
            expect(containsNonExistent, isFalse, reason: 'Cache should not contain non-existent question non_existent_$questionId');
            
            QuizzerLogger.logSuccess('Verified question $questionId: added successfully and containsQuestionId works correctly');
          }
          
          // Step 4: Verify all questions are found after all additions
          QuizzerLogger.logMessage('Step 4: Verifying all questions are found after all additions...');
          for (final Map<String, dynamic> record in testRecords) {
            final String questionId = record['question_id'] as String;
            final bool contains = await cache.containsQuestionId(questionId);
            expect(contains, isTrue, reason: 'Cache should contain question $questionId');
          }
          QuizzerLogger.logSuccess('Verified all questions are found after all additions');
          
          // Step 5: Remove questions one by one and verify containsQuestionId reflects changes
          QuizzerLogger.logMessage('Step 5: Removing questions one by one and verifying containsQuestionId...');
          for (int i = 0; i < testRecords.length; i++) {
            final removedRecord = await cache.getAndRemoveRecord();
            final String removedQuestionId = removedRecord['question_id'] as String;
            
            // Verify the removed question is no longer found
            final bool containsRemoved = await cache.containsQuestionId(removedQuestionId);
            expect(containsRemoved, isFalse, reason: 'Cache should not contain removed question $removedQuestionId');
            
            // Verify remaining questions are still found (if any remain)
            final int remainingCount = testRecords.length - i - 1;
            if (remainingCount > 0) {
              // Check a few remaining questions (we can't predict which ones due to random removal)
              final int currentLength = await cache.getLength();
              expect(currentLength, equals(remainingCount), reason: 'Cache should have $remainingCount questions remaining');
            }
            
            QuizzerLogger.logSuccess('Verified removal of question $removedQuestionId: no longer found in cache');
          }
          
          // Step 6: Verify cache is empty and containsQuestionId returns false for all questions
          QuizzerLogger.logMessage('Step 6: Verifying cache is empty and containsQuestionId returns false...');
          final bool finalEmpty = await cache.isEmpty();
          expect(finalEmpty, isTrue, reason: 'Cache should be empty after removing all questions');
          
          // Check that no questions are found
          for (final Map<String, dynamic> record in testRecords) {
            final String questionId = record['question_id'] as String;
            final bool contains = await cache.containsQuestionId(questionId);
            expect(contains, isFalse, reason: 'Cache should not contain question $questionId after removing all');
          }
          QuizzerLogger.logSuccess('Verified cache is empty and containsQuestionId returns false for all questions');
          
          QuizzerLogger.logSuccess('✅ Successfully verified containsQuestionId() method');
          
        } catch (e) {
          QuizzerLogger.logError('containsQuestionId test failed: $e');
          rethrow;
        }
      });
    });
  }
