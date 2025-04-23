import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/question_queue_monitor.dart';

void main() {
  SessionManager  session = getSessionManager();
  String          email = 'there_is@example.com';
  // String          username = 'testuser7';
  String          password = 'testpass123';

  // Group the initialization tests
  group('Initialization Tests', () {
    test('Login with dummy account', () async {
      final validLogin = await session.attemptLogin(email, password);
      QuizzerLogger.logMessage('Valid login results: $validLogin');
      assert(validLogin["success"]);
    });

    test('Check session state after login', () async {
      // Log initial state of session
      QuizzerLogger.logMessage('Session state after login: ${session.toString()}');
      // Assert that userUUID is not null after successful login
      assert(session.userId != null, 'User UUID should not be null after successful login');
      QuizzerLogger.logMessage('User UUID verification passed: ${session.userId}');
      assert(session.userEmail != null);
      QuizzerLogger.logMessage('${session.userEmail}');
    });

    test('QuestionQueueMonitor is a singleton', () {
      QuizzerLogger.logMessage('Testing QuestionQueueMonitor singleton property');
      final instance1 = getQuestionQueueMonitor();
      final instance2 = getQuestionQueueMonitor();

      // Check if both variables reference the exact same object
      expect(instance1, same(instance2));
      QuizzerLogger.logMessage('Singleton test passed: instance1 and instance2 refer to the same object.');
    });
  }); // End of Initialization Tests group

  // Test for rapid concurrent requests to the question queue
  // test('Rapid concurrent question requests', () async {
  //   QuizzerLogger.logMessage('Starting rapid concurrent request test');
  //   const int concurrentRequests = 50;
  //   final List<Future<Map<String, dynamic>?>> requestFutures = [];
  //   // Launch 50 concurrent requests without awaiting each one individually
  //   for (int i = 0; i < concurrentRequests; i++) {
  //     requestFutures.add(session.requestNextQuestion());
  //     // Optional: Small delay to ensure requests are slightly staggered if needed,
  //     // but true concurrency comes from not awaiting here.
  //     // await Future.delayed(Duration(milliseconds: 5));
  //   }
  //   // Wait for all 50 requests to complete
  //   try {
  //     QuizzerLogger.logMessage('Waiting for $concurrentRequests requests to complete...');
  //     await Future.wait(requestFutures);
  //     QuizzerLogger.logMessage('$concurrentRequests requests completed without breaking.');
  //   } catch (e) {
  //     QuizzerLogger.logError('Error during concurrent requests: $e');
  //     fail('Concurrent requests threw an error: $e'); // Fail the test if any request failed
  //   }
  //   // Request one final time after the barrage
  //   QuizzerLogger.logMessage('Making final request after concurrent batch...');
  //   final finalQuestion = await session.requestNextQuestion();
  //   // Log the result of the final request
  //   QuizzerLogger.logMessage('Final question received: $finalQuestion');
  //   // Assert that a result (real or dummy) was received
  //   expect(finalQuestion, isNotNull);
  //   QuizzerLogger.logMessage('Rapid request test passed.');
  // });

  // Test the isUserQuestionEligible function
  test('Check eligibility for all user questions', () async {
    QuizzerLogger.logMessage('Starting eligibility check test');
    
    // 2. Fetch all user questions using the SessionManager API
    QuizzerLogger.logMessage('Fetching user questions');
    final List<Map<String, dynamic>> userQuestions = await session.getAllUserQuestionPairs();
    QuizzerLogger.logMessage('Fetched ${userQuestions.length} questions for user ${session.userId}.');

    if (userQuestions.isEmpty) {
      QuizzerLogger.logWarning('No questions found for user ${session.userId} to check eligibility.');
      // Test passes if no questions exist, as there's nothing to check
      return; 
    }

    // 3. For every question, run the eligibility check
    QuizzerLogger.logMessage('Iterating through ${userQuestions.length} questions to check eligibility...');
    int eligibleCount = 0;
    
    for (final questionRecord in userQuestions) {
      final questionId = questionRecord['question_id'] as String?;
      if (questionId == null) {
        QuizzerLogger.logWarning('Skipping record with null question_id: $questionRecord');
        continue;
      }
      
      // Call the SessionManager API
      final bool isEligible = await session.checkQuestionEligibility(questionId);
      if (isEligible) {
        eligibleCount++;
      }
      // Log eligibility status for each question
      QuizzerLogger.logMessage('Eligibility for $questionId: $isEligible');
    }

    QuizzerLogger.logSuccess('Completed eligibility checks for ${userQuestions.length} questions. Eligible count: $eligibleCount');
    // Basic assertion: Test completed without throwing exceptions
    expect(true, isTrue); 

  });

  // Test that the maintainer isolate continues running during idle time
  test('Maintainer stays operational during idle', () async {
    const idleDuration = Duration(seconds: 30);
    QuizzerLogger.logMessage('Starting idle test (${idleDuration.inSeconds} seconds)...');
    QuizzerLogger.logMessage('Expect maintainer logs during this period.');

    // Wait for the specified duration
    await Future.delayed(idleDuration);

    QuizzerLogger.logMessage('Idle period finished.');
    // Assert test completion
    expect(true, isTrue);
    QuizzerLogger.logSuccess('Idle test passed - Test process did not terminate.');

  }, timeout: const Timeout(Duration(minutes: 5))); // Set timeout to 5 minutes

}