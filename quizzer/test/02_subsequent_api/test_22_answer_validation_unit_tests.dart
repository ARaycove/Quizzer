import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/answer_validation/session_answer_validation.dart' as answer_validator;
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'dart:io';
import '../test_helpers.dart';

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
  
  group('Group 1: Answer Validation Unit Tests', () {
    test('Test 1: Multiple Choice Answer Validation', () async {
      QuizzerLogger.logMessage('=== Test 1: Multiple Choice Answer Validation ===');
      
      // Define expected behavior:
      // - Should return true when userAnswer is int and matches correctIndex
      // - Should return false when userAnswer is wrong type (not int)
      // - Should return false when userAnswer is int but wrong value
      // - Should handle null correctIndex gracefully
      
      try {
        // Test case 1: Correct answer (should return true)
        QuizzerLogger.logMessage('Test case 1: Correct answer');
        final bool result1 = answer_validator.validateMultipleChoiceAnswer(
          userAnswer: 2,
          correctIndex: 2,
        );
        expect(result1, isTrue, reason: 'Correct answer should return true');
        QuizzerLogger.logSuccess('Correct answer validation passed');
        
        // Test case 2: Wrong answer (should return false)
        QuizzerLogger.logMessage('Test case 2: Wrong answer');
        final bool result2 = answer_validator.validateMultipleChoiceAnswer(
          userAnswer: 1,
          correctIndex: 2,
        );
        expect(result2, isFalse, reason: 'Wrong answer should return false');
        QuizzerLogger.logSuccess('Wrong answer validation passed');
        
        // Test case 3: Wrong type (should return false)
        QuizzerLogger.logMessage('Test case 3: Wrong type');
        final bool result3 = answer_validator.validateMultipleChoiceAnswer(
          userAnswer: '2', // String instead of int
          correctIndex: 2,
        );
        expect(result3, isFalse, reason: 'Wrong type should return false');
        QuizzerLogger.logSuccess('Wrong type validation passed');
        
        // Test case 4: Null correctIndex (should return false)
        QuizzerLogger.logMessage('Test case 4: Null correctIndex');
        final bool result4 = answer_validator.validateMultipleChoiceAnswer(
          userAnswer: 2,
          correctIndex: null,
        );
        expect(result4, isFalse, reason: 'Null correctIndex should return false');
        QuizzerLogger.logSuccess('Null correctIndex validation passed');
        
        // Test case 5: Edge case - zero index
        QuizzerLogger.logMessage('Test case 5: Zero index');
        final bool result5 = answer_validator.validateMultipleChoiceAnswer(
          userAnswer: 0,
          correctIndex: 0,
        );
        expect(result5, isTrue, reason: 'Zero index should work correctly');
        QuizzerLogger.logSuccess('Zero index validation passed');
        
        QuizzerLogger.logSuccess('✅ Multiple choice validation tests completed successfully');
        
      } catch (e) {
        QuizzerLogger.logError('Multiple choice validation test failed: $e');
        rethrow;
      }
    });
    
    test('Test 2: Select All That Apply Answer Validation', () async {
      QuizzerLogger.logMessage('=== Test 2: Select All That Apply Answer Validation ===');
      
      // Define expected behavior:
      // - Should return true when userAnswer is List<int> and matches correctIndices exactly
      // - Should return false when userAnswer is wrong type (not List<int>)
      // - Should return false when userAnswer has different length than correctIndices
      // - Should return false when userAnswer has same length but different elements
      // - Should handle order-independent matching (same elements in different order should be correct)
      
      try {
        // Test case 1: Correct answer in correct order
        QuizzerLogger.logMessage('Test case 1: Correct answer in correct order');
        final bool result1 = answer_validator.validateSelectAllThatApplyAnswer(
          userAnswer: [0, 2, 4],
          correctIndices: [0, 2, 4],
        );
        expect(result1, isTrue, reason: 'Correct answer in correct order should return true');
        QuizzerLogger.logSuccess('Correct answer in order validation passed');
        
        // Test case 2: Correct answer in different order
        QuizzerLogger.logMessage('Test case 2: Correct answer in different order');
        final bool result2 = answer_validator.validateSelectAllThatApplyAnswer(
          userAnswer: [4, 0, 2],
          correctIndices: [0, 2, 4],
        );
        expect(result2, isTrue, reason: 'Correct answer in different order should return true');
        QuizzerLogger.logSuccess('Correct answer different order validation passed');
        
        // Test case 3: Wrong answer (missing correct option)
        QuizzerLogger.logMessage('Test case 3: Wrong answer (missing correct option)');
        final bool result3 = answer_validator.validateSelectAllThatApplyAnswer(
          userAnswer: [0, 2],
          correctIndices: [0, 2, 4],
        );
        expect(result3, isFalse, reason: 'Missing correct option should return false');
        QuizzerLogger.logSuccess('Missing option validation passed');
        
        // Test case 4: Wrong answer (extra incorrect option)
        QuizzerLogger.logMessage('Test case 4: Wrong answer (extra incorrect option)');
        final bool result4 = answer_validator.validateSelectAllThatApplyAnswer(
          userAnswer: [0, 2, 4, 6],
          correctIndices: [0, 2, 4],
        );
        expect(result4, isFalse, reason: 'Extra incorrect option should return false');
        QuizzerLogger.logSuccess('Extra option validation passed');
        
        // Test case 5: Wrong type
        QuizzerLogger.logMessage('Test case 5: Wrong type');
        final bool result5 = answer_validator.validateSelectAllThatApplyAnswer(
          userAnswer: '0,2,4', // String instead of List<int>
          correctIndices: [0, 2, 4],
        );
        expect(result5, isFalse, reason: 'Wrong type should return false');
        QuizzerLogger.logSuccess('Wrong type validation passed');
        
        // Test case 6: Empty lists
        QuizzerLogger.logMessage('Test case 6: Empty lists');
        final bool result6 = answer_validator.validateSelectAllThatApplyAnswer(
          userAnswer: [],
          correctIndices: [],
        );
        expect(result6, isTrue, reason: 'Empty lists should return true when both are empty');
        QuizzerLogger.logSuccess('Empty lists validation passed');
        
        // Test case 6b: Empty user answer with non-empty correct indices
        QuizzerLogger.logMessage('Test case 6b: Empty user answer with non-empty correct indices');
        final bool result6b = answer_validator.validateSelectAllThatApplyAnswer(
          userAnswer: [],
          correctIndices: [0, 1],
        );
        expect(result6b, isFalse, reason: 'Empty user answer with non-empty correct indices should return false');
        QuizzerLogger.logSuccess('Empty user answer with non-empty correct validation passed');
        
        // Test case 7: Single element
        QuizzerLogger.logMessage('Test case 7: Single element');
        final bool result7 = answer_validator.validateSelectAllThatApplyAnswer(
          userAnswer: [3],
          correctIndices: [3],
        );
        expect(result7, isTrue, reason: 'Single element should return true');
        QuizzerLogger.logSuccess('Single element validation passed');
        
        QuizzerLogger.logSuccess('✅ Select all that apply validation tests completed successfully');
        
      } catch (e) {
        QuizzerLogger.logError('Select all that apply validation test failed: $e');
        rethrow;
      }
    });
    
    test('Test 3: True/False Answer Validation', () async {
      QuizzerLogger.logMessage('=== Test 3: True/False Answer Validation ===');
      
      // Define expected behavior:
      // - Should return true when userAnswer is int and matches correctIndex (0 or 1)
      // - Should return false when userAnswer is wrong type (not int)
      // - Should return false when userAnswer is int but wrong value
      // - Should handle correctIndex values of 0 (True) and 1 (False)
      
      try {
        // Test case 1: Correct answer - True (0)
        QuizzerLogger.logMessage('Test case 1: Correct answer - True (0)');
        final bool result1 = answer_validator.validateTrueFalseAnswer(
          userAnswer: 0,
          correctIndex: 0,
        );
        expect(result1, isTrue, reason: 'Correct True answer should return true');
        QuizzerLogger.logSuccess('Correct True answer validation passed');
        
        // Test case 2: Correct answer - False (1)
        QuizzerLogger.logMessage('Test case 2: Correct answer - False (1)');
        final bool result2 = answer_validator.validateTrueFalseAnswer(
          userAnswer: 1,
          correctIndex: 1,
        );
        expect(result2, isTrue, reason: 'Correct False answer should return true');
        QuizzerLogger.logSuccess('Correct False answer validation passed');
        
        // Test case 3: Wrong answer - True when False is correct
        QuizzerLogger.logMessage('Test case 3: Wrong answer - True when False is correct');
        final bool result3 = answer_validator.validateTrueFalseAnswer(
          userAnswer: 0,
          correctIndex: 1,
        );
        expect(result3, isFalse, reason: 'Wrong True answer should return false');
        QuizzerLogger.logSuccess('Wrong True answer validation passed');
        
        // Test case 4: Wrong answer - False when True is correct
        QuizzerLogger.logMessage('Test case 4: Wrong answer - False when True is correct');
        final bool result4 = answer_validator.validateTrueFalseAnswer(
          userAnswer: 1,
          correctIndex: 0,
        );
        expect(result4, isFalse, reason: 'Wrong False answer should return false');
        QuizzerLogger.logSuccess('Wrong False answer validation passed');
        
        // Test case 5: Wrong type
        QuizzerLogger.logMessage('Test case 5: Wrong type');
        final bool result5 = answer_validator.validateTrueFalseAnswer(
          userAnswer: 'True', // String instead of int
          correctIndex: 0,
        );
        expect(result5, isFalse, reason: 'Wrong type should return false');
        QuizzerLogger.logSuccess('Wrong type validation passed');
        
        // Test case 6: Invalid correctIndex (should throw assertion error)
        QuizzerLogger.logMessage('Test case 6: Invalid correctIndex');
        expect(() {
          answer_validator.validateTrueFalseAnswer(
            userAnswer: 0,
            correctIndex: 2, // Invalid: should be 0 or 1
          );
        }, throwsA(isA<AssertionError>()), reason: 'Invalid correctIndex should throw assertion error');
        QuizzerLogger.logSuccess('Invalid correctIndex validation passed');
        
        QuizzerLogger.logSuccess('✅ True/False validation tests completed successfully');
        
      } catch (e) {
        QuizzerLogger.logError('True/False validation test failed: $e');
        rethrow;
      }
    });
    
    test('Test 4: Sort Order Answer Validation', () async {
      QuizzerLogger.logMessage('=== Test 4: Sort Order Answer Validation ===');
      
      // Define expected behavior:
      // - Should return true when userAnswer matches correctOrder exactly (same elements in same order)
      // - Should return false when userAnswer has different length than correctOrder
      // - Should return false when userAnswer has same length but different elements
      // - Should return false when userAnswer has same elements but different order
      // - Should handle List<Map<String, dynamic>> with 'content' field
      
      try {
        // Test case 1: Correct answer in correct order
        QuizzerLogger.logMessage('Test case 1: Correct answer in correct order');
        final List<Map<String, dynamic>> correctOrder = [
          {'content': 'First'},
          {'content': 'Second'},
          {'content': 'Third'},
        ];
        final List<Map<String, dynamic>> userAnswer1 = [
          {'content': 'First'},
          {'content': 'Second'},
          {'content': 'Third'},
        ];
        final bool result1 = answer_validator.validateSortOrderAnswer(
          userAnswer: userAnswer1,
          correctOrder: correctOrder,
        );
        expect(result1, isTrue, reason: 'Correct answer in correct order should return true');
        QuizzerLogger.logSuccess('Correct answer in order validation passed');
        
        // Test case 2: Wrong answer - different order
        QuizzerLogger.logMessage('Test case 2: Wrong answer - different order');
        final List<Map<String, dynamic>> userAnswer2 = [
          {'content': 'Second'},
          {'content': 'First'},
          {'content': 'Third'},
        ];
        final bool result2 = answer_validator.validateSortOrderAnswer(
          userAnswer: userAnswer2,
          correctOrder: correctOrder,
        );
        expect(result2, isFalse, reason: 'Wrong order should return false');
        QuizzerLogger.logSuccess('Wrong order validation passed');
        
        // Test case 3: Wrong answer - different length
        QuizzerLogger.logMessage('Test case 3: Wrong answer - different length');
        final List<Map<String, dynamic>> userAnswer3 = [
          {'content': 'First'},
          {'content': 'Second'},
        ];
        final bool result3 = answer_validator.validateSortOrderAnswer(
          userAnswer: userAnswer3,
          correctOrder: correctOrder,
        );
        expect(result3, isFalse, reason: 'Different length should return false');
        QuizzerLogger.logSuccess('Different length validation passed');
        
        // Test case 4: Wrong answer - different content
        QuizzerLogger.logMessage('Test case 4: Wrong answer - different content');
        final List<Map<String, dynamic>> userAnswer4 = [
          {'content': 'First'},
          {'content': 'Wrong'},
          {'content': 'Third'},
        ];
        final bool result4 = answer_validator.validateSortOrderAnswer(
          userAnswer: userAnswer4,
          correctOrder: correctOrder,
        );
        expect(result4, isFalse, reason: 'Different content should return false');
        QuizzerLogger.logSuccess('Different content validation passed');
        
        // Test case 5: Empty lists
        QuizzerLogger.logMessage('Test case 5: Empty lists');
        final List<Map<String, dynamic>> emptyOrder = [];
        final List<Map<String, dynamic>> emptyAnswer = [];
        final bool result5 = answer_validator.validateSortOrderAnswer(
          userAnswer: emptyAnswer,
          correctOrder: emptyOrder,
        );
        expect(result5, isTrue, reason: 'Empty lists should return true');
        QuizzerLogger.logSuccess('Empty lists validation passed');
        
        // Test case 6: Single element
        QuizzerLogger.logMessage('Test case 6: Single element');
        final List<Map<String, dynamic>> singleOrder = [
          {'content': 'Only'},
        ];
        final List<Map<String, dynamic>> singleAnswer = [
          {'content': 'Only'},
        ];
        final bool result6 = answer_validator.validateSortOrderAnswer(
          userAnswer: singleAnswer,
          correctOrder: singleOrder,
        );
        expect(result6, isTrue, reason: 'Single element should return true');
        QuizzerLogger.logSuccess('Single element validation passed');
        
        // Test case 7: Missing 'content' field (should throw error)
        QuizzerLogger.logMessage('Test case 7: Missing content field');
        final List<Map<String, dynamic>> invalidOrder = [
          {'content': 'Valid'},
        ];
        final List<Map<String, dynamic>> invalidAnswer = [
          {'wrong_field': 'Invalid'},
        ];
        expect(() {
          answer_validator.validateSortOrderAnswer(
            userAnswer: invalidAnswer,
            correctOrder: invalidOrder,
          );
        }, throwsA(isA<StateError>()), reason: 'Missing content field should throw StateError');
        QuizzerLogger.logSuccess('Missing content field validation passed');
        
        QuizzerLogger.logSuccess('✅ Sort order validation tests completed successfully');
        
      } catch (e) {
        QuizzerLogger.logError('Sort order validation test failed: $e');
        rethrow;
      }
    });
  });

  group('Group 2: submitAnswer API tests', () {
    test('Test 1: SubmitAnswer API with real questions from database', () async {
      QuizzerLogger.logMessage('=== Test 1: SubmitAnswer API with real questions from database ===');
      
      // Step 1: Initialize login without sync and queue server
      QuizzerLogger.logMessage('Step 1: Initializing login...');
      final SessionManager sessionManager = getSessionManager();
      final loginResult = await loginInitialization(
        email: testEmail,
        password: testPassword,
        supabase: sessionManager.supabase,
        storage: sessionManager.getBox(testAccessPassword),
        testRun: true,
        noQueueServer: true,
      );
      
      // Step 2: Get questions from database (created by test_18)
      QuizzerLogger.logMessage('Step 2: Getting questions from database...');
      final List<Map<String, dynamic>> allQuestions = await getAllQuestionAnswerPairs();
      expect(allQuestions.length, greaterThan(0), reason: 'Should have questions in database from test_18');
      
      // Group questions by type
      final Map<String, Map<String, dynamic>> questionsByType = {};
      for (final question in allQuestions) {
        final String questionType = question['question_type'] as String;
        if (!questionsByType.containsKey(questionType)) {
          questionsByType[questionType] = question;
        }
      }
      
      QuizzerLogger.logMessage('Found question types: ${questionsByType.keys.join(', ')}');
      
      // Step 3: Test each question type
      for (final questionType in questionsByType.keys) {
        QuizzerLogger.logMessage('Testing submitAnswer for question type: $questionType');
        
        final Map<String, dynamic> question = questionsByType[questionType]!;
        final String questionId = question['question_id'] as String;
        
        // Step 4: Use the global SessionManager and create a real user question record in the database
        final String userId = sessionManager.userId!;
        
        // Create user question record using the proper function
        QuizzerLogger.logMessage('Creating user question record for question $questionId...');
        await insertOrUpdateUserQuestionAnswerPair(
          userUuid: userId,
          questionId: questionId,
          revisionStreak: 0,
          lastRevised: DateTime.now().toUtc().toIso8601String(),
          predictedRevisionDueHistory: '[]',
          nextRevisionDue: DateTime.now().toUtc().toIso8601String(),
          timeBetweenRevisions: 1.0,
          averageTimesShownPerDay: 1.0,
        );
        QuizzerLogger.logMessage('User question record created successfully');
        
        // Step 5: Use requestNextQuestion with testDebug to bypass queue cache
        
        // Create a test record that combines question data with user record
        final Map<String, dynamic> testRecord = Map<String, dynamic>.from(question);
        testRecord.addAll({
          'user_uuid': userId,
          'question_id': questionId,
          'revision_streak': 0,
          'last_revised': DateTime.now().toUtc().toIso8601String(),
          'next_revision_due': DateTime.now().toUtc().toIso8601String(),
          'time_between_revisions': 1.0,
          'average_times_shown_per_day': 1.0,
          'total_attempts': 0,
          'is_eligible': 1,
          'in_circulation': 1,
        });
        
        // Use the testDebug parameter to bypass queue cache
        QuizzerLogger.logMessage('Calling requestNextQuestion with testDebug for question $questionId...');
        await sessionManager.requestNextQuestion(testDebug: testRecord);
        QuizzerLogger.logMessage('requestNextQuestion completed successfully');
        
        // Verify the question is loaded
        expect(sessionManager.currentQuestionId, equals(questionId), 
          reason: 'SessionManager should have loaded the test question');
        
        // Step 6: Get correct answer for this question type
        QuizzerLogger.logMessage('Getting correct answer for question $questionId...');
        final dynamic correctAnswer = await getCorrectAnswerForQuestion(questionId);
        expect(correctAnswer, isNotNull, reason: 'Should be able to get correct answer for question $questionId');
        QuizzerLogger.logMessage('Correct answer retrieved successfully');
        
        // Step 7: Test submitAnswer API with correct answer
        QuizzerLogger.logMessage('Testing correct answer for $questionType question...');
        final Map<String, dynamic> correctResult = await sessionManager.submitAnswer(userAnswer: correctAnswer);
        expect(correctResult['success'], isTrue, reason: 'submitAnswer should succeed for correct $questionType answer');
        
                      // Step 8: Test submitAnswer API with incorrect answer
        QuizzerLogger.logMessage('Testing incorrect answer for $questionType question...');
        final dynamic incorrectAnswer = 999; // Just some junk value
        final Map<String, dynamic> incorrectResult = await sessionManager.submitAnswer(userAnswer: incorrectAnswer);
        expect(incorrectResult['success'], isFalse, reason: 'submitAnswer should fail for incorrect $questionType answer');
        
        QuizzerLogger.logSuccess('submitAnswer API test passed for $questionType (correct and incorrect)');
      }
      
      QuizzerLogger.logSuccess('✅ All submitAnswer API tests completed successfully');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
} 