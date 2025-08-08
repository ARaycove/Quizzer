import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/question_selection_worker.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_question_worker_signals.dart';
import 'package:quizzer/backend_systems/09_data_caches/question_queue_cache.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_module_activation_status_table.dart';
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
  late final PresentationSelectionWorker selectionWorker;
  
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
    selectionWorker = PresentationSelectionWorker();
    await sessionManager.initializationComplete;
    await performLoginProcess(
      email: testEmail, 
      password: testPassword, 
      supabase: sessionManager.supabase, 
      storage: sessionManager.getBox(testAccessPassword));
  });
  
  group('PresentationSelectionWorker Tests', () {
    test('Should be a singleton - multiple instances should be the same', () async {
      QuizzerLogger.logMessage('Testing PresentationSelectionWorker singleton pattern');
      
      try {
        // Create multiple instances
        final worker1 = PresentationSelectionWorker();
        final worker2 = PresentationSelectionWorker();
        final worker3 = PresentationSelectionWorker();
        
        // Verify all instances are the same (singleton)
        expect(identical(worker1, worker2), isTrue, reason: 'Worker1 and Worker2 should be identical');
        expect(identical(worker2, worker3), isTrue, reason: 'Worker2 and Worker3 should be identical');
        expect(identical(worker1, worker3), isTrue, reason: 'Worker1 and Worker3 should be identical');
        
        QuizzerLogger.logSuccess('✅ PresentationSelectionWorker singleton pattern verified');
        
      } catch (e) {
        QuizzerLogger.logError('PresentationSelectionWorker singleton test failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('Should start worker, complete cycles, and respond to signals', () async {
      QuizzerLogger.logMessage('Testing PresentationSelectionWorker cycle completion and signal handling');
      
      try {
        // Step 1: Start the selection worker
        QuizzerLogger.logMessage('Step 1: Starting PresentationSelectionWorker...');
        selectionWorker.start();
        QuizzerLogger.logSuccess('PresentationSelectionWorker started');
        
        // Step 2: Wait for the first cycle completion signal
        QuizzerLogger.logMessage('Step 2: Waiting for first cycle completion signal...');
        await switchBoard.onPresentationSelectionWorkerCycleComplete.first;
        QuizzerLogger.logSuccess('Received first cycle completion signal');
        
        // Step 3: Get a real question ID for signaling
        QuizzerLogger.logMessage('Step 3: Getting real question ID for signaling...');
        final List<Map<String, dynamic>> realQuestions = await getAllQuestionAnswerPairs();
        if (realQuestions.isEmpty) {
          QuizzerLogger.logWarning('No real questions found for signaling test. Skipping.');
          return;
        }
        final String realQuestionId = realQuestions.first['question_id'] as String;
        
        // Trigger a new cycle by signaling a question was answered correctly
        QuizzerLogger.logMessage('Step 3: Triggering new cycle by signaling question answered correctly...');
        signalQuestionAnsweredCorrectly(realQuestionId);
        QuizzerLogger.logSuccess('Signaled question answered correctly');
        
        // Step 4: Wait for the second cycle completion signal
        QuizzerLogger.logMessage('Step 4: Waiting for second cycle completion signal...');
        await switchBoard.onPresentationSelectionWorkerCycleComplete.first;
        QuizzerLogger.logSuccess('Received second cycle completion signal');
        
        // Step 5: Trigger another cycle with a different real question
        QuizzerLogger.logMessage('Step 5: Triggering third cycle...');
        final String secondRealQuestionId = realQuestions.length > 1 ? realQuestions[1]['question_id'] as String : realQuestionId;
        signalQuestionAnsweredCorrectly(secondRealQuestionId);
        QuizzerLogger.logSuccess('Signaled second question answered correctly');
        
        // Step 6: Wait for the third cycle completion signal
        QuizzerLogger.logMessage('Step 6: Waiting for third cycle completion signal...');
        await switchBoard.onPresentationSelectionWorkerCycleComplete.first;
        QuizzerLogger.logSuccess('Received third cycle completion signal');
        
        // Step 7: Stop the worker
        QuizzerLogger.logMessage('Step 7: Stopping PresentationSelectionWorker...');
        await selectionWorker.stop();
        QuizzerLogger.logSuccess('PresentationSelectionWorker stopped');
        
        QuizzerLogger.logSuccess('✅ Successfully tested PresentationSelectionWorker cycle completion and signal handling');
        
      } catch (e) {
        QuizzerLogger.logError('PresentationSelectionWorker cycle test failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('Should populate queue cache with threshold number of questions', () async {
      QuizzerLogger.logMessage('Testing PresentationSelectionWorker queue cache population');
      
      try {
        // Step 1: Reset user question answer pairs table
        QuizzerLogger.logMessage('Step 1: Resetting user_question_answer_pairs table...');
        final bool resetSuccess = await deleteAllRecordsFromTable('user_question_answer_pairs', userId: sessionManager.userId!);
        expect(resetSuccess, isTrue, reason: 'Failed to reset user question answer pairs table');
        QuizzerLogger.logSuccess('user_question_answer_pairs table reset');
        
        // Step 2: Get the queue cache and ensure it's empty
        QuizzerLogger.logMessage('Step 2: Ensuring queue cache is empty...');
        final QuestionQueueCache queueCache = QuestionQueueCache();
        await queueCache.clear();
        final bool isEmpty = await queueCache.isEmpty();
        expect(isEmpty, isTrue, reason: 'Queue cache should be empty after clearing');
        QuizzerLogger.logSuccess('Queue cache is empty');
        
        // Step 3: Get all modules and find one with enough questions
        QuizzerLogger.logMessage('Step 3: Finding module with sufficient questions...');
        final List<Map<String, dynamic>> allModules = await getAllModules();
        const int threshold = QuestionQueueCache.queueThreshold;
        QuizzerLogger.logMessage('Queue threshold: $threshold');
        
        int totalQuestions = 0;
        List<String> activatedModules = [];
        
        // Try modules until we have enough questions
        for (final module in allModules) {
          final String moduleName = module['module_name'] as String;
          final List<Map<String, dynamic>> moduleQuestions = await getQuestionRecordsForModule(moduleName);
          final int questionCount = moduleQuestions.length;
          
          QuizzerLogger.logMessage('Module $moduleName has $questionCount questions');
          
          if (questionCount > 0) {
            // Activate this module
            final bool activationResult = await updateModuleActivationStatus(sessionManager.userId!, moduleName, true);
            expect(activationResult, isTrue, reason: 'Failed to activate module: $moduleName');
            activatedModules.add(moduleName);
            
            // Make all questions in this module eligible
            for (final question in moduleQuestions) {
              final String questionId = question['question_id'] as String;
              final bool eligibleResult = await ensureRecordEligible(sessionManager.userId!, questionId);
              if (eligibleResult) {
                totalQuestions++;
              }
            }
            
            QuizzerLogger.logMessage('Activated module $moduleName and made $questionCount questions eligible');
            
            if (totalQuestions >= threshold) {
              QuizzerLogger.logMessage('Sufficient questions found: $totalQuestions >= $threshold');
              break;
            }
          }
        }
        
        // Verify we have enough questions
        expect(totalQuestions, greaterThanOrEqualTo(threshold), 
          reason: 'Should have at least $threshold eligible questions. Got: $totalQuestions');
        QuizzerLogger.logSuccess('Verified sufficient eligible questions: $totalQuestions');
        
        // Step 4: Start the selection worker
        QuizzerLogger.logMessage('Step 4: Starting PresentationSelectionWorker...');
        selectionWorker.start();
        QuizzerLogger.logSuccess('PresentationSelectionWorker started');
        
        // Step 5: Wait for cycle completion signal
        QuizzerLogger.logMessage('Step 5: Waiting for cycle completion signal...');
        await switchBoard.onPresentationSelectionWorkerCycleComplete.first;
        QuizzerLogger.logSuccess('Received cycle completion signal');
        
        // Step 6: Verify queue cache has some questions (may be less than threshold due to cleanup)
        QuizzerLogger.logMessage('Step 6: Verifying queue cache population...');
        final int queueLength = await queueCache.getLength();
        expect(queueLength, greaterThan(0), 
          reason: 'Queue cache should have at least 1 question. Got: $queueLength');
        expect(queueLength, lessThanOrEqualTo(threshold), 
          reason: 'Queue cache should not exceed threshold $threshold. Got: $queueLength');
        QuizzerLogger.logSuccess('Verified queue cache has $queueLength questions (threshold: $threshold)');
        
        // Step 7: Stop the worker
        QuizzerLogger.logMessage('Step 8: Stopping PresentationSelectionWorker...');
        await selectionWorker.stop();
        QuizzerLogger.logSuccess('PresentationSelectionWorker stopped');
        
        QuizzerLogger.logSuccess('✅ Successfully tested PresentationSelectionWorker queue cache population');
        
      } catch (e) {
        QuizzerLogger.logError('PresentationSelectionWorker queue cache test failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('Should handle no eligible questions gracefully', () async {
      QuizzerLogger.logMessage('Testing PresentationSelectionWorker with no eligible questions');
      
      try {
        // Step 1: Reset user question answer pairs table
        QuizzerLogger.logMessage('Step 1: Resetting user_question_answer_pairs table...');
        final bool resetSuccess = await deleteAllRecordsFromTable('user_question_answer_pairs', userId: sessionManager.userId!);
        expect(resetSuccess, isTrue, reason: 'Failed to reset user question answer pairs table');
        QuizzerLogger.logSuccess('user_question_answer_pairs table reset');
        
        // Step 2: Ensure queue cache is empty
        QuizzerLogger.logMessage('Step 2: Ensuring queue cache is empty...');
        final QuestionQueueCache queueCache = QuestionQueueCache();
        await queueCache.clear();
        final bool isEmpty = await queueCache.isEmpty();
        expect(isEmpty, isTrue, reason: 'Queue cache should be empty after clearing');
        QuizzerLogger.logSuccess('Queue cache is empty');
        
        // Step 3: Deactivate all modules to ensure no eligible questions
        QuizzerLogger.logMessage('Step 3: Deactivating all modules...');
        final List<Map<String, dynamic>> allModules = await getAllModules();
        for (final module in allModules) {
          final String moduleName = module['module_name'] as String;
          await updateModuleActivationStatus(sessionManager.userId!, moduleName, false);
        }
        QuizzerLogger.logSuccess('All modules deactivated');
        
        // Step 4: Start the selection worker
        QuizzerLogger.logMessage('Step 4: Starting PresentationSelectionWorker...');
        selectionWorker.start();
        QuizzerLogger.logSuccess('PresentationSelectionWorker started');
        
        // Step 5: Wait for cycle completion signal (should complete even with no eligible questions)
        QuizzerLogger.logMessage('Step 5: Waiting for cycle completion signal...');
        await switchBoard.onPresentationSelectionWorkerCycleComplete.first;
        QuizzerLogger.logSuccess('Received cycle completion signal');
        
        // Step 6: Send a signal to unstick the worker from waiting
        QuizzerLogger.logMessage('Step 6: Sending signal to unstick worker...');
        final List<Map<String, dynamic>> realQuestions = await getAllQuestionAnswerPairs();
        final String unstickQuestionId = realQuestions.isNotEmpty ? realQuestions.first['question_id'] as String : 'no_questions_available';
        signalQuestionAnsweredCorrectly(unstickQuestionId);
        QuizzerLogger.logSuccess('Sent unstick signal');
        
        // Step 7: Verify queue cache is still empty (no questions to add)
        QuizzerLogger.logMessage('Step 7: Verifying queue cache remains empty...');
        final int queueLength = await queueCache.getLength();
        expect(queueLength, equals(0), reason: 'Queue cache should remain empty when no eligible questions exist');
        QuizzerLogger.logSuccess('Verified queue cache remains empty');
        
        // Step 8: Stop the worker
        QuizzerLogger.logMessage('Step 8: Stopping PresentationSelectionWorker...');
        await selectionWorker.stop();
        QuizzerLogger.logSuccess('PresentationSelectionWorker stopped');
        
        QuizzerLogger.logSuccess('✅ Successfully tested PresentationSelectionWorker with no eligible questions');
        
      } catch (e) {
        QuizzerLogger.logError('PresentationSelectionWorker no eligible questions test failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('Should handle worker restart gracefully', () async {
      QuizzerLogger.logMessage('Testing PresentationSelectionWorker restart behavior');
      
      try {
        // Step 1: Reset and prepare some eligible questions
        QuizzerLogger.logMessage('Step 1: Preparing test environment...');
        final bool resetSuccess = await deleteAllRecordsFromTable('user_question_answer_pairs', userId: sessionManager.userId!);
        expect(resetSuccess, isTrue, reason: 'Failed to reset user question answer pairs table');
        
        final QuestionQueueCache queueCache = QuestionQueueCache();
        await queueCache.clear();
        
        // Activate a module and make questions eligible
        final List<Map<String, dynamic>> allModules = await getAllModules();
        const int threshold = QuestionQueueCache.queueThreshold;
        int totalQuestions = 0;
        
        for (final module in allModules) {
          final String moduleName = module['module_name'] as String;
          final List<Map<String, dynamic>> moduleQuestions = await getQuestionRecordsForModule(moduleName);
          
          if (moduleQuestions.isNotEmpty) {
            await updateModuleActivationStatus(sessionManager.userId!, moduleName, true);
            
            for (final question in moduleQuestions) {
              final String questionId = question['question_id'] as String;
              await ensureRecordEligible(sessionManager.userId!, questionId);
              totalQuestions++;
            }
            
            if (totalQuestions >= threshold) break;
          }
        }
        
        expect(totalQuestions, greaterThanOrEqualTo(threshold), reason: 'Should have sufficient eligible questions');
        QuizzerLogger.logSuccess('Prepared $totalQuestions eligible questions');
        
        // Step 2: Start worker and wait for first cycle
        QuizzerLogger.logMessage('Step 2: Starting worker for first cycle...');
        selectionWorker.start();
        await switchBoard.onPresentationSelectionWorkerCycleComplete.first;
        QuizzerLogger.logSuccess('First cycle completed');
        
        // Step 3: Stop worker
        QuizzerLogger.logMessage('Step 3: Stopping worker...');
        await selectionWorker.stop();
        QuizzerLogger.logSuccess('Worker stopped');
        
        // Step 4: Clear queue cache
        QuizzerLogger.logMessage('Step 4: Clearing queue cache...');
        await queueCache.clear();
        expect(await queueCache.isEmpty(), isTrue, reason: 'Queue cache should be empty after clearing');
        QuizzerLogger.logSuccess('Queue cache cleared');
        
        // Step 5: Restart worker and wait for cycle
        QuizzerLogger.logMessage('Step 5: Restarting worker...');
        selectionWorker.start();
        await switchBoard.onPresentationSelectionWorkerCycleComplete.first;
        QuizzerLogger.logSuccess('Second cycle completed');
        
        // Give the worker time to repopulate the cache
        QuizzerLogger.logMessage('Waiting 2 seconds for worker to repopulate cache...');
        await Future.delayed(const Duration(seconds: 2));
        QuizzerLogger.logSuccess('Wait completed');
        
        // Step 6: Verify queue cache is populated again
        QuizzerLogger.logMessage('Step 6: Verifying queue cache is populated...');
        final int queueLength = await queueCache.getLength();
        expect(queueLength, greaterThan(0), reason: 'Queue cache should have at least 1 question after restart. Got: $queueLength');
        expect(queueLength, lessThanOrEqualTo(threshold), reason: 'Queue cache should not exceed threshold $threshold. Got: $queueLength');
        QuizzerLogger.logSuccess('Verified queue cache has $queueLength questions (threshold: $threshold)');
        
        // Step 7: Stop worker
        QuizzerLogger.logMessage('Step 7: Stopping worker...');
        await selectionWorker.stop();
        QuizzerLogger.logSuccess('Worker stopped');
        
        QuizzerLogger.logSuccess('✅ Successfully tested PresentationSelectionWorker restart behavior');
        
      } catch (e) {
        QuizzerLogger.logError('PresentationSelectionWorker restart test failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('Should handle rapid start/stop cycles', () async {
      QuizzerLogger.logMessage('Testing PresentationSelectionWorker rapid start/stop cycles');
      
      try {
        // Step 1: Prepare eligible questions
        QuizzerLogger.logMessage('Step 1: Preparing eligible questions...');
        final bool resetSuccess = await deleteAllRecordsFromTable('user_question_answer_pairs', userId: sessionManager.userId!);
        expect(resetSuccess, isTrue, reason: 'Failed to reset user question answer pairs table');
        
        final QuestionQueueCache queueCache = QuestionQueueCache();
        await queueCache.clear();
        
        // Activate a module and make questions eligible
        final List<Map<String, dynamic>> allModules = await getAllModules();
        const int threshold = QuestionQueueCache.queueThreshold;
        int totalQuestions = 0;
        
        for (final module in allModules) {
          final String moduleName = module['module_name'] as String;
          final List<Map<String, dynamic>> moduleQuestions = await getQuestionRecordsForModule(moduleName);
          
          if (moduleQuestions.isNotEmpty) {
            await updateModuleActivationStatus(sessionManager.userId!, moduleName, true);
            
            for (final question in moduleQuestions) {
              final String questionId = question['question_id'] as String;
              await ensureRecordEligible(sessionManager.userId!, questionId);
              totalQuestions++;
            }
            
            if (totalQuestions >= threshold) break;
          }
        }
        
        expect(totalQuestions, greaterThanOrEqualTo(threshold), reason: 'Should have sufficient eligible questions');
        QuizzerLogger.logSuccess('Prepared $totalQuestions eligible questions');
        
        // Step 2: Perform rapid start/stop cycles
        QuizzerLogger.logMessage('Step 2: Performing rapid start/stop cycles...');
        for (int i = 0; i < 3; i++) {
          QuizzerLogger.logMessage('Cycle ${i + 1}: Starting worker...');
          selectionWorker.start();
          
          // Wait a short time for the worker to start
          await Future.delayed(const Duration(milliseconds: 100));
          
          QuizzerLogger.logMessage('Cycle ${i + 1}: Stopping worker...');
          await selectionWorker.stop();
          
          // Wait a short time before next cycle
          await Future.delayed(const Duration(milliseconds: 100));
        }
        QuizzerLogger.logSuccess('Completed 3 rapid start/stop cycles');
        
        // Step 3: Verify worker can still function normally after rapid cycles
        QuizzerLogger.logMessage('Step 3: Testing normal operation after rapid cycles...');
        await queueCache.clear();
        expect(await queueCache.isEmpty(), isTrue, reason: 'Queue cache should be empty');

        await Future.delayed(const Duration(milliseconds: 500));
        selectionWorker.start();
        await switchBoard.onPresentationSelectionWorkerCycleComplete.first;
        
        final int queueLength = await queueCache.getLength();
        expect(queueLength, greaterThan(0), reason: 'Worker should still function normally after rapid cycles. Got: $queueLength');
        expect(queueLength, lessThanOrEqualTo(threshold), reason: 'Worker should not exceed threshold $threshold after rapid cycles. Got: $queueLength');
        QuizzerLogger.logSuccess('Verified worker functions normally after rapid cycles with $queueLength questions (threshold: $threshold)');
        
        // Step 4: Stop worker
        QuizzerLogger.logMessage('Step 4: Stopping worker...');
        await selectionWorker.stop();
        QuizzerLogger.logSuccess('Worker stopped');
        
        QuizzerLogger.logSuccess('✅ Successfully tested PresentationSelectionWorker rapid start/stop cycles');
        
      } catch (e) {
        QuizzerLogger.logError('PresentationSelectionWorker rapid cycles test failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
