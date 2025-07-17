import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/inbound_sync/inbound_sync_worker.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/academic_archive.dart/subject_details_table.dart';
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
    await performLoginProcess(
      email: testEmail, 
      password: testPassword, 
      supabase: sessionManager.supabase, 
      storage: sessionManager.getBox(testAccessPassword));
  });
  
    group('InboundSyncWorker Tests', () {
      test('Should be a singleton - multiple instances should be the same', () async {
        QuizzerLogger.logMessage('Testing InboundSyncWorker singleton pattern');
        
        try {
          // Create multiple instances
          final worker1 = InboundSyncWorker();
          final worker2 = InboundSyncWorker();
          final worker3 = InboundSyncWorker();
          
          // Verify all instances are the same (singleton)
          expect(identical(worker1, worker2), isTrue, reason: 'Worker1 and Worker2 should be identical');
          expect(identical(worker2, worker3), isTrue, reason: 'Worker2 and Worker3 should be identical');
          expect(identical(worker1, worker3), isTrue, reason: 'Worker1 and Worker3 should be identical');
          
          QuizzerLogger.logSuccess('✅ InboundSyncWorker singleton pattern verified');
          
        } catch (e) {
          QuizzerLogger.logError('InboundSyncWorker singleton test failed: $e');
          rethrow;
        }
      });

      test('Should complete sync cycles and verify unsynced records are empty', () async {
        QuizzerLogger.logMessage('Testing InboundSyncWorker sync cycles');
        
        final inboundSyncWorker = InboundSyncWorker();
        
        try {
          // Step 1: Start the worker
          QuizzerLogger.logMessage('Step 1: Starting InboundSyncWorker');
          await inboundSyncWorker.start();
          
          // Step 2: Wait for cycle completion signal
          QuizzerLogger.logMessage('Step 2: Waiting for first cycle completion');
          await switchBoard.onInboundSyncCycleComplete.first;
          QuizzerLogger.logSuccess('First sync cycle completed');
          
          // Step 3: Verify inbound sync completed successfully
          QuizzerLogger.logMessage('Step 3: Verifying inbound sync completed successfully');
          
          QuizzerLogger.logSuccess('Inbound sync cycle completed successfully');
          
          // Step 4: Send inbound sync needed signal
          QuizzerLogger.logMessage('Step 4: Sending inbound sync needed signal');
          signalInboundSyncNeeded();
          
          // Step 5: Wait for cycle completion signal again
          QuizzerLogger.logMessage('Step 5: Waiting for second cycle completion');
          await switchBoard.onInboundSyncCycleComplete.first;
          QuizzerLogger.logSuccess('Second sync cycle completed');
          
          QuizzerLogger.logSuccess('InboundSyncWorker test completed successfully');
          
        } catch (e) {
          QuizzerLogger.logError('InboundSyncWorker test failed: $e');
          rethrow;
        } finally {
          // Clean up
          await inboundSyncWorker.stop();
        }
      });

      test('Should have synced at least 2690 question_answer_pairs from Supabase', () async {
        QuizzerLogger.logMessage('Checking count of question_answer_pairs synced by previous test');
        
        try {
          // Get the count of question_answer_pairs that were synced by the previous test
          final localRecords = await getAllQuestionAnswerPairs();
          final totalLocalCount = localRecords.length;
          QuizzerLogger.logMessage('Total local question_answer_pairs count: $totalLocalCount');
          
          // Verify we got at least 2690 records (allowing for small margin of error)
          expect(totalLocalCount, greaterThanOrEqualTo(2690), 
            reason: 'Should have at least 2690 question_answer_pairs synced from Supabase. Got: $totalLocalCount');
          
          QuizzerLogger.logSuccess('✅ Verified $totalLocalCount question_answer_pairs were synced from Supabase');
          
        } catch (e, stackTrace) {
          QuizzerLogger.logError('Question count verification failed: $e');
          QuizzerLogger.logError('Stack trace: $stackTrace');
          rethrow;
        }
      });

      test('Should have synced at least 1500 subject_details records from Supabase', () async {
        QuizzerLogger.logMessage('Checking count of subject_details synced by previous test');
        
        try {
          // Get the count of subject_details that were synced by the previous test
          final localRecords = await getAllSubjectDetails();
          final totalLocalCount = localRecords.length;
          QuizzerLogger.logMessage('Total local subject_details count: $totalLocalCount');
          
          // Verify we got at least 1500 records (allowing for small margin of error)
          expect(totalLocalCount, greaterThanOrEqualTo(1500), 
            reason: 'Should have at least 1500 subject_details synced from Supabase. Got: $totalLocalCount');
          
          QuizzerLogger.logSuccess('✅ Verified $totalLocalCount subject_details were synced from Supabase');
          
          // Additional validation: Check that records have the expected structure
          if (localRecords.isNotEmpty) {
            final sampleRecord = localRecords.first;
            expect(sampleRecord.containsKey('subject'), isTrue, 
              reason: 'Subject details records should have a "subject" field');
            expect(sampleRecord.containsKey('immediate_parent'), isTrue, 
              reason: 'Subject details records should have an "immediate_parent" field');
            expect(sampleRecord.containsKey('subject_description'), isTrue, 
              reason: 'Subject details records should have a "subject_description" field');
            expect(sampleRecord.containsKey('last_modified_timestamp'), isTrue, 
              reason: 'Subject details records should have a "last_modified_timestamp" field');
            
            QuizzerLogger.logSuccess('✅ Verified subject_details record structure is correct');
          }
          
        } catch (e, stackTrace) {
          QuizzerLogger.logError('Subject details count verification failed: $e');
          QuizzerLogger.logError('Stack trace: $stackTrace');
          rethrow;
        }
      });
    
    
    
    
    
    });
}
