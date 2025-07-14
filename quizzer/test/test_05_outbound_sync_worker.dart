import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/outbound_sync/outbound_sync_worker.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_module_activation_status_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_settings_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_feedback_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/error_logs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/login_attempts_table.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'test_helpers.dart';
import 'dart:io';
import 'dart:async';

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
    await performLoginProcess(
      email: testEmail, 
      password: testPassword, 
      supabase: sessionManager.supabase, 
      storage: sessionManager.getBox(testAccessPassword));
  });
  
    group('OutboundSyncWorker Tests', () {
      test('Should be a singleton - multiple instances should be the same', () async {
        QuizzerLogger.logMessage('Testing OutboundSyncWorker singleton pattern');
        
        try {
          // Create multiple instances
          final worker1 = OutboundSyncWorker();
          final worker2 = OutboundSyncWorker();
          final worker3 = OutboundSyncWorker();
          
          // Verify all instances are the same (singleton)
          expect(identical(worker1, worker2), isTrue, reason: 'Worker1 and Worker2 should be identical');
          expect(identical(worker2, worker3), isTrue, reason: 'Worker2 and Worker3 should be identical');
          expect(identical(worker1, worker3), isTrue, reason: 'Worker1 and Worker3 should be identical');
          
          QuizzerLogger.logSuccess('✅ OutboundSyncWorker singleton pattern verified');
          
        } catch (e) {
          QuizzerLogger.logError('OutboundSyncWorker singleton test failed: $e');
          rethrow;
        }
      });

      test('Should complete sync cycles and verify unsynced records are empty', () async {
        QuizzerLogger.logMessage('Testing OutboundSyncWorker sync cycles');
        
        final outboundSyncWorker = OutboundSyncWorker();
        
        try {
          // Step 1: Start the worker
          QuizzerLogger.logMessage('Step 1: Starting OutboundSyncWorker');
          await outboundSyncWorker.start();
          
          // Step 2: Wait for cycle completion signal
          QuizzerLogger.logMessage('Step 2: Waiting for first cycle completion');
          await switchBoard.onOutboundSyncCycleComplete.first;
          QuizzerLogger.logSuccess('First sync cycle completed');
          
          // Step 3: Verify all getUnsyncedRecords functions return empty
          QuizzerLogger.logMessage('Step 3: Verifying all unsynced records are empty');
          
          // Check all table types for unsynced records
          final unsyncedProfiles = await getUnsyncedUserProfiles(sessionManager.userId!);
          final unsyncedUserQAPairs = await getUnsyncedUserQuestionAnswerPairs(sessionManager.userId!);
          final unsyncedModules = await getUnsyncedModules();
          final unsyncedModuleActivation = await getUnsyncedModuleActivationStatusRecords(sessionManager.userId!);
          final unsyncedSettings = await getUnsyncedUserSettings(sessionManager.userId!);
          final unsyncedFeedback = await getUnsyncedUserFeedback();
          final unsyncedErrorLogs = await getUnsyncedErrorLogs();
          final unsyncedLoginAttempts = await getUnsyncedLoginAttempts();
          
          // Verify all are empty
          expect(unsyncedProfiles, isEmpty, reason: 'User profiles should be synced');
          expect(unsyncedUserQAPairs, isEmpty, reason: 'User question answer pairs should be synced');
          expect(unsyncedModules, isEmpty, reason: 'Modules should be synced');
          expect(unsyncedModuleActivation, isEmpty, reason: 'Module activation status should be synced');
          expect(unsyncedSettings, isEmpty, reason: 'User settings should be synced');
          expect(unsyncedFeedback, isEmpty, reason: 'User feedback should be synced');
          expect(unsyncedErrorLogs, isEmpty, reason: 'Error logs should be synced');
          expect(unsyncedLoginAttempts, isEmpty, reason: 'Login attempts should be synced');
          
          QuizzerLogger.logSuccess('All unsynced records verified as empty');
          
          // Step 4: Send outbound sync needed signal
          QuizzerLogger.logMessage('Step 4: Sending outbound sync needed signal');
          signalOutboundSyncNeeded();
          
          // Step 5: Wait for cycle completion signal again (with extended timeout for cooldown)
          QuizzerLogger.logMessage('Step 5: Waiting for second cycle completion (120s timeout)');
          await switchBoard.onOutboundSyncCycleComplete.first.timeout(
            const Duration(seconds: 120),
            onTimeout: () {
              throw TimeoutException('Second outbound sync cycle timed out after 120 seconds');
            },
          );
          QuizzerLogger.logSuccess('Second sync cycle completed');
          
          QuizzerLogger.logSuccess('OutboundSyncWorker test completed successfully');
          
        } catch (e) {
          QuizzerLogger.logError('OutboundSyncWorker test failed: $e');
          rethrow;
        } finally {
          // Clean up
          await outboundSyncWorker.stop();
        }
      }, timeout: const Timeout(Duration(seconds: 120)));
    });
}
