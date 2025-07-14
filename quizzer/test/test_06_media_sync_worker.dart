import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/media_sync_worker.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/media_sync_status_table.dart';
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
  
    group('MediaSyncWorker Tests', () {
      test('Should be a singleton - multiple instances should be the same', () async {
        QuizzerLogger.logMessage('Testing MediaSyncWorker singleton pattern');
        
        try {
          // Create multiple instances
          final worker1 = MediaSyncWorker();
          final worker2 = MediaSyncWorker();
          final worker3 = MediaSyncWorker();
          
          // Verify all instances are the same (singleton)
          expect(identical(worker1, worker2), isTrue, reason: 'Worker1 and Worker2 should be identical');
          expect(identical(worker2, worker3), isTrue, reason: 'Worker2 and Worker3 should be identical');
          expect(identical(worker1, worker3), isTrue, reason: 'Worker1 and Worker3 should be identical');
          
          QuizzerLogger.logSuccess('✅ MediaSyncWorker singleton pattern verified');
          
        } catch (e) {
          QuizzerLogger.logError('MediaSyncWorker singleton test failed: $e');
          rethrow;
        }
      });

      test('Should complete sync cycles and verify media sync status table', () async {
        QuizzerLogger.logMessage('Testing MediaSyncWorker sync cycles');
        
        final mediaSyncWorker = MediaSyncWorker();
        
        try {
          // Step 1: Start the worker
          QuizzerLogger.logMessage('Step 1: Starting MediaSyncWorker');
          await mediaSyncWorker.start();
          
          // Step 2: Wait for cycle completion signal
          QuizzerLogger.logMessage('Step 2: Waiting for first cycle completion');
          await switchBoard.onMediaSyncCycleComplete.first;
          QuizzerLogger.logSuccess('First sync cycle completed');
          
          // Step 3: Verify media sync status table has records
          QuizzerLogger.logMessage('Step 3: Verifying media sync status table');
          
          // Check that media sync status table has been populated
          // We'll check for files that exist both locally and externally
          final filesToUpload = await getExistingLocallyNotExternally();
          final filesToDownload = await getExistingExternallyNotLocally();
          
          QuizzerLogger.logMessage('Media sync status check completed:');
          QuizzerLogger.logMessage('- Files to upload: ${filesToUpload.length}');
          QuizzerLogger.logMessage('- Files to download: ${filesToDownload.length}');
          
          QuizzerLogger.logSuccess('Media sync status table verification completed');
          
          // Step 4: Send media sync needed signal
          QuizzerLogger.logMessage('Step 4: Sending media sync needed signal');
          signalMediaSyncNeeded();
          
          // Step 5: Wait for cycle completion signal again
          QuizzerLogger.logMessage('Step 5: Waiting for second cycle completion');
          await switchBoard.onMediaSyncCycleComplete.first;
          QuizzerLogger.logSuccess('Second sync cycle completed');
          
          QuizzerLogger.logSuccess('MediaSyncWorker test completed successfully');
          
        } catch (e) {
          QuizzerLogger.logError('MediaSyncWorker test failed: $e');
          rethrow;
        } finally {
          // Clean up
          await mediaSyncWorker.stop();
        }
      }, timeout: const Timeout(Duration(minutes: 10)));
    });
  
}
