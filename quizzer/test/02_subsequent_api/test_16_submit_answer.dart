import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/09_data_caches/question_queue_cache.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_attempts_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
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
  late final SwitchBoard switchBoard;
  
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
    switchBoard = getSwitchBoard();
    await sessionManager.initializationComplete;
  });
  
  group('SessionManager Submit Answer Tests', () {
    test('Test 1: Login initialization and verify state', () async {
      QuizzerLogger.logMessage('=== Test 1: Login initialization and verify state ===');
      
      // Step 1: Set all user_question_answer_pairs to ineligible before login
      final String userId = await getUserIdByEmail(testEmail);
      final List<Map<String, dynamic>> allUserQAPairs = await getAllUserQuestionAnswerPairs(userId);
      for (final record in allUserQAPairs) {
        final String questionId = record['question_id'] as String;
        // Set due date to past (so eligible for circulation) but circulation to false (so starts out of circulation)
        await setCirculationStatus(userId, questionId, false);
        // Set revision due date to 1 year in the past
        final DateTime pastDate = DateTime.now().subtract(const Duration(days: 365));
        final String pastDateString = pastDate.toUtc().toIso8601String();
        
        final db = await getDatabaseMonitor().requestDatabaseAccess();
        if (db != null) {
          await db.update(
            'user_question_answer_pairs',
            {'next_revision_due': pastDateString},
            where: 'user_uuid = ? AND question_id = ?',
            whereArgs: [userId, questionId],
          );
          getDatabaseMonitor().releaseDatabaseAccess();
        }
      }
      // Step 2: Login initialization (reuses same credentials as test 15)
      QuizzerLogger.logMessage('Step 2: Calling loginInitialization with testRun=true...');
      loginInitialization(
        email: testEmail, 
        password: testPassword, 
        supabase: sessionManager.supabase, 
        storage: sessionManager.getBox(testAccessPassword),
        testRun: true, // This bypasses sync workers
      );
      
      // Step 2: Wait for circulation worker to complete its cycle
      QuizzerLogger.logMessage('Step 2: Waiting for circulation worker to complete its cycle...');
      await switchBoard.onCirculationWorkerFinished.first;
      QuizzerLogger.logSuccess('Circulation worker cycle completed');
      
      // Step 3: Verify that user is logged in and ready
      expect(sessionManager.userId, isNotNull, reason: 'User should be logged in');
      QuizzerLogger.logSuccess('User is logged in and ready for testing');
      
      // Step 4: Verify that there are eligible questions available
      final List<Map<String, dynamic>> eligibleQuestions = await getEligibleUserQuestionAnswerPairs(sessionManager.userId!);
      expect(eligibleQuestions.length, greaterThan(0), 
        reason: 'Should have eligible questions available for testing. Found: ${eligibleQuestions.length}');
      QuizzerLogger.logSuccess('Verified ${eligibleQuestions.length} eligible questions are available');
      
      // Step 5: Verify that queue cache has questions
      final QuestionQueueCache queueCache = QuestionQueueCache();
      final int queueLength = await queueCache.getLength();
      expect(queueLength, greaterThan(0), 
        reason: 'Queue cache should have questions available. Found: $queueLength');
      QuizzerLogger.logSuccess('Verified queue cache has $queueLength questions');
      
      QuizzerLogger.logSuccess('=== Test 1 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 2: Submit answer and verify circulation/selection worker response', () async {
      QuizzerLogger.logMessage('=== Test 2: Submit answer and verify circulation/selection worker response ===');
      
      // Step 1: Get initial counts
      QuizzerLogger.logMessage('Step 1: Getting initial question counts...');
      
      final List<Map<String, dynamic>> eligibleQuestions = await getEligibleUserQuestionAnswerPairs(sessionManager.userId!);
      final int initialEligibleCount = eligibleQuestions.length;
      expect(initialEligibleCount, equals(100), reason: 'Should have exactly 100 eligible questions. Found: $initialEligibleCount');
      QuizzerLogger.logSuccess('Initial eligible questions: $initialEligibleCount');
      
      final List<Map<String, dynamic>> circulatingQuestions = await getQuestionsInCirculation(sessionManager.userId!);
      final int initialCirculatingCount = circulatingQuestions.length;
      QuizzerLogger.logSuccess('Initial circulating questions: $initialCirculatingCount');
      
      final List<Map<String, dynamic>> nonCirculatingQuestions = await getNonCirculatingQuestionsWithDetails(sessionManager.userId!);
      final int initialNonCirculatingCount = nonCirculatingQuestions.length;
      QuizzerLogger.logSuccess('Initial non-circulating questions: $initialNonCirculatingCount');
      
      // Step 2: Enter loop to test submit answer functionality
      // Loop should run until we get a dummy question, indicating that we have no more eligible questions

      // Loop will conduct these steps:
      // Loop will continue to execute until we get the dummy question:
      
      bool gotDummyQuestion = false;
      String? previousQuestionId; // Track the previous question ID
      
      while (!gotDummyQuestion) {
        // Get total eligible questions
      final List<Map<String, dynamic>> currentEligibleQuestions = await getEligibleUserQuestionAnswerPairs(sessionManager.userId!);
      int currentEligibleCount = currentEligibleQuestions.length;
      // Get total circulating questions
      final List<Map<String, dynamic>> currentCirculatingQuestions = await getQuestionsInCirculation(sessionManager.userId!);
      int currentCirculatingCount = currentCirculatingQuestions.length;
      // Get total non-circulating questions
      final List<Map<String, dynamic>> currentNonCirculatingQuestions = await getNonCirculatingQuestionsWithDetails(sessionManager.userId!);
      int currentNonCirculatingCount = currentNonCirculatingQuestions.length;
      // Get total question answer attempts
      final List<Map<String, dynamic>> currentQuestionAttempts = await getAttemptsByUser(sessionManager.userId!);
      int currentAttemptCount = currentQuestionAttempts.length;
      // ------------------------------------------------------------
      // requestNextQuestion
      await sessionManager.requestNextQuestion();
      
      // CRITICAL: Verify that we don't get the same question twice in a row
      final String currentQuestionId = sessionManager.currentQuestionId;
      if (previousQuestionId != null && currentQuestionId != 'dummy_no_questions') {
        expect(currentQuestionId, isNot(equals(previousQuestionId)), 
          reason: 'Should not get the same question twice in a row. Previous: $previousQuestionId, Current: $currentQuestionId');
      }
      previousQuestionId = currentQuestionId; // Update for next iteration
      // Ensure not dummy question if eligible questions > 0:
      if (currentEligibleCount > 0) {
        expect(sessionManager.currentQuestionId, isNot(equals('dummy_no_questions')), 
          reason: 'Should not get dummy question when eligible questions are available');
      }
      // Ensure is dummy question if eligible questions == 0:
      if (currentEligibleCount == 0) {
        expect(sessionManager.currentQuestionId, equals('dummy_no_questions'), 
          reason: 'Should get dummy question when no eligible questions are available');
      }
      // If dummy question, proceed to submitAnswer for dummy question

      
      // Collect the correct answer for input
      final correctAnswer = await getCorrectAnswerForQuestion(sessionManager.currentQuestionId);
      
      // Start all futures before triggering the action
      final circulationFuture = switchBoard.onCirculationWorkerFinished.first;
      final presentationFuture = switchBoard.onPresentationSelectionWorkerCycleComplete.first;
      
      // Start the submitAnswer future
      final submitFuture = sessionManager.submitAnswer(userAnswer: correctAnswer);
      
      // Wait for all to complete
      final results = await Future.wait([submitFuture, circulationFuture, presentationFuture]);
      final submitResult = results[0] as Map<String, dynamic>;
      
      // Ensure response says isCorrect == True
      expect(submitResult['success'], isTrue, reason: 'Submit answer should succeed');
      
      // We will not be worrying about the stats in this test
      // No delay afte answer submission, this is to enusre that system can handle fast responses
      // ------------------------------------------------------------
      // Get total eligible questions
      final List<Map<String, dynamic>> newEligibleQuestions = await getEligibleUserQuestionAnswerPairs(sessionManager.userId!);
      int newEligibleCount = newEligibleQuestions.length;
      // Get total circulating questions
      final List<Map<String, dynamic>> newCirculatingQuestions = await getQuestionsInCirculation(sessionManager.userId!);
      int newCirculatingCount = newCirculatingQuestions.length;
      // Get total non-circulating questions
      final List<Map<String, dynamic>> newNonCirculatingQuestions = await getNonCirculatingQuestionsWithDetails(sessionManager.userId!);
      int newNonCirculatingCount = newNonCirculatingQuestions.length;
      // Get total question answer attempts
      final List<Map<String, dynamic>> newQuestionAttempts = await getAttemptsByUser(sessionManager.userId!);
      int newAttemptCount = newQuestionAttempts.length;

      // If non-circulating questions was > 0:
      
      // Get total eligible questions
      // - Eligible questions should still be 100 (or 99 if one was processed)
      // - Total circulating questions should have incremented by 1
      // - Total non-circulating questions should have decreased by 1
      if (currentNonCirculatingCount > 0) {
        // - Eligible questions should still be 100
        expect(newEligibleCount, equals(100), reason: 'Eligible questions should remain at 100');
        // - Total circulating questions should have incremented by 1 (or stayed the same if circulation worker didn't add)
        expect(newCirculatingCount, anyOf(equals(currentCirculatingCount + 1), equals(currentCirculatingCount)), 
          reason: 'Circulating questions should increment by 1 or stay the same. Found: $newCirculatingCount, Expected: ${currentCirculatingCount + 1} or $currentCirculatingCount');
        // - Total non-circulating questions should have decreased by 1 (or stayed the same if circulation worker didn't add)
        expect(newNonCirculatingCount, anyOf(equals(currentNonCirculatingCount - 1), equals(currentNonCirculatingCount)), 
          reason: 'Non-circulating questions should decrease by 1 or stay the same. Found: $newNonCirculatingCount, Expected: ${currentNonCirculatingCount - 1} or $currentNonCirculatingCount');
      }

      // If non-circulating questions was == 0:
      // - Eligible questions should have decreased by 1 (but not below 0)
      // - Total circulating questions should have remained the same
      // - Total non-circulating questions should have remained the same
      if (currentNonCirculatingCount == 0) {
        // - Eligible questions should have decreased by 1 (but not below 0)
        final expectedEligibleCount = currentEligibleCount > 0 ? currentEligibleCount - 1 : 0;
        expect(newEligibleCount, anyOf(equals(expectedEligibleCount), equals(currentEligibleCount)), 
          reason: 'Eligible questions should decrease by 1 or stay the same. Expected: $expectedEligibleCount or $currentEligibleCount, Got: $newEligibleCount');
        // - Total circulating questions should have remained the same
        expect(newCirculatingCount, equals(currentCirculatingCount), 
          reason: 'Circulating questions should remain the same');
        // - Total non-circulating questions should have remained the same
        expect(newNonCirculatingCount, equals(currentNonCirculatingCount), 
          reason: 'Non-circulating questions should remain the same');
      }
      
      // If dummy question
      // - Eligible questions should remain 0
      // - Total circulating questions should remain the same
      // - Total non-circulating questions should remain the same
      // - Total question answer attempts should remain the same
      if (sessionManager.currentQuestionId == 'dummy_no_questions') {
        // - Eligible questions should remain 0
        expect(newEligibleCount, equals(0), reason: 'Eligible questions should remain 0');
        // - Total circulating questions should remain the same
        expect(newCirculatingCount, equals(currentCirculatingCount), 
          reason: 'Circulating questions should remain the same');
        // - Total non-circulating questions should remain the same
        expect(newNonCirculatingCount, equals(currentNonCirculatingCount), 
          reason: 'Non-circulating questions should remain the same');
        // - Total question answer attempts should remain the same
        expect(newAttemptCount, equals(currentAttemptCount), 
          reason: 'Question answer attempts should remain the same');
        
        gotDummyQuestion = true;
        QuizzerLogger.logSuccess('Got dummy question - test complete');
      }
    }
    
    expect(gotDummyQuestion, isTrue, reason: 'Should have gotten dummy question');
    
    // Final verification: All questions should be in circulation, none non-circulating
    QuizzerLogger.logMessage('Final verification: Checking all questions are in circulation...');
    
    final List<Map<String, dynamic>> finalCirculatingQuestions = await getQuestionsInCirculation(sessionManager.userId!);
    final List<Map<String, dynamic>> finalNonCirculatingQuestions = await getNonCirculatingQuestionsWithDetails(sessionManager.userId!);
    final List<Map<String, dynamic>> allUserQAPairs = await getAllUserQuestionAnswerPairs(sessionManager.userId!);
    
    final int finalCirculatingCount = finalCirculatingQuestions.length;
    final int finalNonCirculatingCount = finalNonCirculatingQuestions.length;
    final int totalUserQAPairs = allUserQAPairs.length;
    
    expect(finalNonCirculatingCount, equals(0), 
      reason: 'All questions should be in circulation. Found $finalNonCirculatingCount non-circulating questions');
    expect(finalCirculatingCount, equals(totalUserQAPairs), 
      reason: 'All user question answer pairs should be in circulation. Found $finalCirculatingCount circulating, expected $totalUserQAPairs');
    
    QuizzerLogger.logSuccess('Final verification passed: $finalCirculatingCount circulating, $finalNonCirculatingCount non-circulating, $totalUserQAPairs total');
      

      
      QuizzerLogger.logSuccess('=== Test 2 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 10)));
  });
}
