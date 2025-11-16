import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/09_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/05_question_queue_server/circulation_worker.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_module_activation_status_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
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
  late CirculationWorker circulationWorker;
  
  // Global instances used across tests
  late final SessionManager sessionManager;
  late final SwitchBoard switchBoard;
  
  setUpAll(() async {
    await QuizzerLogger.setupLogging();
    HttpOverrides.global = null;
    // Initialize the CirculationWorker
    circulationWorker = CirculationWorker();
    
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
    await performLoginProcess(
      email: testEmail, 
      password: testPassword, 
      supabase: sessionManager.supabase, 
      storage: sessionManager.getBox(testAccessPassword));
  });
  
  group('Test Group Name', () {
    test('Should be a singleton - multiple instances should be the same', () async {
      QuizzerLogger.logMessage('Testing CirculationWorker singleton pattern');
      
      try {
        // Create multiple instances
        final worker1 = CirculationWorker();
        final worker2 = CirculationWorker();
        final worker3 = CirculationWorker();
        
        // Verify all instances are the same (singleton)
        expect(identical(worker1, worker2), isTrue, reason: 'Worker1 and Worker2 should be identical');
        expect(identical(worker2, worker3), isTrue, reason: 'Worker2 and Worker3 should be identical');
        expect(identical(worker1, worker3), isTrue, reason: 'Worker1 and Worker3 should be identical');
        
        QuizzerLogger.logSuccess('✅ CirculationWorker singleton pattern verified');
        
      } catch (e) {
        QuizzerLogger.logError('CirculationWorker singleton test failed: $e');
        rethrow;
      }
    });

    test('Should add questions to circulation until 100 eligible questions are reached', () async {
      QuizzerLogger.logMessage('Starting circulation worker test...');
      
      try {
        // Set state:
        // First, deactivate all modules
        QuizzerLogger.logMessage('Deactivating all modules...');
        final db = getDatabaseMonitor().requestDatabaseAccess();
        final List<Map<String, dynamic>> allModules = await getAllModules(db);
        getDatabaseMonitor().releaseDatabaseAccess();
        for (final module in allModules) {
          final String moduleName = module['module_name'] as String;
          final bool result = await updateModuleActivationStatus(sessionManager.userId!, moduleName, false);
          expect(result, isTrue, reason: 'Failed to deactivate module: $moduleName');
        }
        QuizzerLogger.logSuccess('All modules deactivated');
        
        // Clear the user_question_answer_pairs table using helper function
        QuizzerLogger.logMessage('Clearing user_question_answer_pairs table using helper function...');
        final resetSuccess = await deleteAllRecordsFromTable('user_question_answer_pairs', userId: sessionManager.userId!);
        expect(resetSuccess, isTrue, reason: 'Failed to reset user_question_answer_pairs table');
        QuizzerLogger.logSuccess('User question answer pairs table cleared successfully');

        // Now we can begin our test:
        // Activate all modules
        QuizzerLogger.logMessage('Activating all modules...');
        for (final module in allModules) {
          final String moduleName = module['module_name'] as String;
          final bool result = await updateModuleActivationStatus(sessionManager.userId!, moduleName, true);
          expect(result, isTrue, reason: 'Failed to activate module: $moduleName');
        }
        QuizzerLogger.logSuccess('All modules activated');

        // Verify that questions were added to user profile after module activation
        QuizzerLogger.logMessage('Verifying questions were added to user profile...');
        final db2 = await getDatabaseMonitor().requestDatabaseAccess();
        if (db2 == null) {
          throw Exception('Failed to acquire database access');
        }
        final List<Map<String, dynamic>> userQuestionCount = await db2.rawQuery(
          'SELECT COUNT(*) as count FROM user_question_answer_pairs WHERE user_uuid = ?',
          [sessionManager.userId!]
        );
        getDatabaseMonitor().releaseDatabaseAccess();
        final int totalUserQuestions = userQuestionCount.first['count'] as int;
        expect(totalUserQuestions, greaterThan(0), reason: 'Should have questions in user profile after activating all modules');
        QuizzerLogger.logSuccess('Verified $totalUserQuestions questions added to user profile');

        // Start the CirculationWorker
        QuizzerLogger.logMessage('Starting CirculationWorker...');
        await circulationWorker.start();

        // Wait for the CirculationWorker to finish
        QuizzerLogger.logMessage('Waiting for CirculationWorker to finish...');
        await switchBoard.onCirculationWorkerFinished.first;
        QuizzerLogger.logSuccess('CirculationWorker finished signal received');

        // There should be exactly 10 eligible questions in the user_question_answer_pairs table
        QuizzerLogger.logMessage('Checking eligible questions count...');
        final List<Map<String, dynamic>> eligibleQuestions = await getEligibleUserQuestionAnswerPairs(sessionManager.userId!);
        QuizzerLogger.logMessage('DEBUG: Found ${eligibleQuestions.length} eligible questions');
        expect(eligibleQuestions.length, equals(10), reason: 'Should have exactly 10 eligible questions');

        // Total number of circulating questions should be 10
        QuizzerLogger.logMessage('Checking circulating questions count...');
        final List<Map<String, dynamic>> circulatingQuestions = await getQuestionsInCirculation(sessionManager.userId!);
        QuizzerLogger.logMessage('DEBUG: Found ${circulatingQuestions.length} circulating questions');
        expect(circulatingQuestions.length, equals(10), reason: 'Should have exactly 10 circulating questions');
        
        // Stop the CirculationWorker
        QuizzerLogger.logMessage('Stopping CirculationWorker...');
        await circulationWorker.stop();
        QuizzerLogger.logSuccess('CirculationWorker stopped');
        
        // Generate comprehensive test report
        QuizzerLogger.logMessage('=== CIRCULATION WORKER TEST REPORT ===');
        
        // Get final counts
        final List<Map<String, dynamic>> finalEligibleQuestions = await getEligibleUserQuestionAnswerPairs(sessionManager.userId!);
        final List<Map<String, dynamic>> finalCirculatingQuestions = await getQuestionsInCirculation(sessionManager.userId!);
        
        // Get module activation status
        final Map<String, bool> moduleActivationStatus = await getModuleActivationStatus(sessionManager.userId!);
        final int activeModules = moduleActivationStatus.values.where((isActive) => isActive).length;
        final int totalModules = moduleActivationStatus.length;
        
        // Get total user questions count
        final dbFinal = await getDatabaseMonitor().requestDatabaseAccess();
        if (dbFinal == null) {
          throw Exception('Failed to acquire database access for final report');
        }
        final List<Map<String, dynamic>> totalUserQuestionsCount = await dbFinal.rawQuery(
          'SELECT COUNT(*) as count FROM user_question_answer_pairs WHERE user_uuid = ?',
          [sessionManager.userId!]
        );
        getDatabaseMonitor().releaseDatabaseAccess();
        final int finalTotalUserQuestions = totalUserQuestionsCount.first['count'] as int;
        
        // Log the comprehensive report
        QuizzerLogger.logMessage('📊 FINAL METRICS:');
        QuizzerLogger.logMessage('   • Eligible Questions: ${finalEligibleQuestions.length}');
        QuizzerLogger.logMessage('   • Circulating Questions: ${finalCirculatingQuestions.length}');
        QuizzerLogger.logMessage('   • Total User Questions: $finalTotalUserQuestions');
        QuizzerLogger.logMessage('   • Active Modules: $activeModules/$totalModules');
        
        // Log module details
        QuizzerLogger.logMessage('📋 MODULE STATUS:');
        for (final entry in moduleActivationStatus.entries) {
          final String status = entry.value ? '✅ ACTIVE' : '❌ INACTIVE';
          QuizzerLogger.logMessage('   • ${entry.key}: $status');
        }
        
        // Log test expectations vs actual results
        QuizzerLogger.logMessage('🎯 TEST EXPECTATIONS:');
        QuizzerLogger.logMessage('   • Expected Eligible Questions: 10');
        QuizzerLogger.logMessage('   • Expected Circulating Questions: 10');
        QuizzerLogger.logMessage('   • Actual Eligible Questions: ${finalEligibleQuestions.length}');
        QuizzerLogger.logMessage('   • Actual Circulating Questions: ${finalCirculatingQuestions.length}');
        
        // Determine test success
        final bool eligibleQuestionsCorrect = finalEligibleQuestions.length == 10;
        final bool circulatingQuestionsCorrect = finalCirculatingQuestions.length == 10;
        final bool allModulesActive = activeModules == totalModules;
        
        if (eligibleQuestionsCorrect && circulatingQuestionsCorrect && allModulesActive) {
          QuizzerLogger.logSuccess('✅ TEST PASSED: All expectations met!');
        } else {
          QuizzerLogger.logError('❌ TEST FAILED: Some expectations not met');
          if (!eligibleQuestionsCorrect) {
            QuizzerLogger.logError('   • Eligible questions count mismatch: expected 10, got ${finalEligibleQuestions.length}');
          }
          if (!circulatingQuestionsCorrect) {
            QuizzerLogger.logError('   • Circulating questions count mismatch: expected 10, got ${finalCirculatingQuestions.length}');
          }
          if (!allModulesActive) {
            QuizzerLogger.logError('   • Not all modules are active: $activeModules/$totalModules');
          }
        }
        
        QuizzerLogger.logMessage('=== END TEST REPORT ===');
        
        QuizzerLogger.logSuccess('Test completed successfully');
        
      } catch (e) {
        QuizzerLogger.logError('Test failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
