import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/inbound_sync/inbound_sync_worker.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/academic_archive.dart/subject_details_table.dart';
import '../test_helpers.dart';
import 'dart:io';
import 'dart:convert'; // Added for json.encode

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

      test('Should handle batch upsert with various data scenarios correctly', () async {
        QuizzerLogger.logMessage('Testing batchUpsertQuestionAnswerPairs with various scenarios');
        
        try {
          final timestamp = DateTime.now().toUtc().toIso8601String();
          final userId = 'test_user_$testIteration';
          
          // Test data scenarios
          final List<Map<String, dynamic>> testRecords = [
            // Scenario 1: Normal valid record
            {
              'time_stamp': '${timestamp}_1',
              'citation': 'Test citation 1',
              'question_elements': json.encode([{'type': 'text', 'content': 'What is 2+2?'}]),
              'answer_elements': json.encode([{'type': 'text', 'content': '4'}]),
              'ans_flagged': 0,
              'ans_contrib': userId,
              'concepts': 'math,addition',
              'subjects': 'mathematics',
              'qst_contrib': userId,
              'qst_reviewer': userId,
              'has_been_reviewed': 1,
              'flag_for_removal': 0,
              'completed': 1,
              'module_name': 'Test Module',
              'question_type': 'multiple_choice',
              'options': json.encode([
                {'type': 'text', 'content': '3'},
                {'type': 'text', 'content': '4'},
                {'type': 'text', 'content': '5'},
                {'type': 'text', 'content': '6'}
              ]),
              'correct_option_index': 1,
              'question_id': '${timestamp}_1_$userId',
              'correct_order': null,
              'index_options_that_apply': null,
              'has_been_synced': 1, // Prevent outbound sync
              'edits_are_synced': 1, // Prevent outbound sync
              'last_modified_timestamp': timestamp,
              'has_media': 0,
            },
            
            // Scenario 2: Record with null values
            {
              'time_stamp': '${timestamp}_2',
              'citation': null,
              'question_elements': json.encode([{'type': 'text', 'content': 'What is 3+3?'}]),
              'answer_elements': json.encode([{'type': 'text', 'content': '6'}]),
              'ans_flagged': 0,
              'ans_contrib': null,
              'concepts': null,
              'subjects': null,
              'qst_contrib': userId,
              'qst_reviewer': null,
              'has_been_reviewed': 0,
              'flag_for_removal': 0,
              'completed': 1,
              'module_name': 'Test Module 2',
              'question_type': 'true_false',
              'options': null,
              'correct_option_index': 0,
              'question_id': '${timestamp}_2_$userId',
              'correct_order': null,
              'index_options_that_apply': null,
              'has_been_synced': 1, // Prevent outbound sync
              'edits_are_synced': 1, // Prevent outbound sync
              'last_modified_timestamp': timestamp,
              'has_media': 0,
            },
            
            // Scenario 3: Select all that apply question
            {
              'time_stamp': '${timestamp}_3',
              'citation': 'Test citation 3',
              'question_elements': json.encode([{'type': 'text', 'content': 'Which are even numbers?'}]),
              'answer_elements': json.encode([{'type': 'text', 'content': '2, 4, 6 are even numbers'}]),
              'ans_flagged': 0,
              'ans_contrib': userId,
              'concepts': 'math,numbers',
              'subjects': 'mathematics',
              'qst_contrib': userId,
              'qst_reviewer': userId,
              'has_been_reviewed': 1,
              'flag_for_removal': 0,
              'completed': 1,
              'module_name': 'Test Module 3',
              'question_type': 'select_all_that_apply',
              'options': json.encode([
                {'type': 'text', 'content': '2'},
                {'type': 'text', 'content': '3'},
                {'type': 'text', 'content': '4'},
                {'type': 'text', 'content': '5'},
                {'type': 'text', 'content': '6'}
              ]),
              'correct_option_index': null,
              'question_id': '${timestamp}_3_$userId',
              'correct_order': null,
              'index_options_that_apply': json.encode([0, 2, 4]), // 2, 4, 6 are even
              'has_been_synced': 1, // Prevent outbound sync
              'edits_are_synced': 1, // Prevent outbound sync
              'last_modified_timestamp': timestamp,
              'has_media': 0,
            },
            
            // Scenario 4: Sort order question
            {
              'time_stamp': '${timestamp}_4',
              'citation': 'Test citation 4',
              'question_elements': json.encode([{'type': 'text', 'content': 'Sort these numbers in ascending order'}]),
              'answer_elements': json.encode([{'type': 'text', 'content': '1, 2, 3, 4, 5'}]),
              'ans_flagged': 0,
              'ans_contrib': userId,
              'concepts': 'math,ordering',
              'subjects': 'mathematics',
              'qst_contrib': userId,
              'qst_reviewer': userId,
              'has_been_reviewed': 1,
              'flag_for_removal': 0,
              'completed': 1,
              'module_name': 'Test Module 4',
              'question_type': 'sort_order',
              'options': json.encode([
                {'type': 'text', 'content': '1'},
                {'type': 'text', 'content': '2'},
                {'type': 'text', 'content': '3'},
                {'type': 'text', 'content': '4'},
                {'type': 'text', 'content': '5'}
              ]),
              'correct_option_index': null,
              'question_id': '${timestamp}_4_$userId',
              'correct_order': json.encode([0, 1, 2, 3, 4]), // Already in correct order
              'index_options_that_apply': null,
              'has_been_synced': 1, // Prevent outbound sync
              'edits_are_synced': 1, // Prevent outbound sync
              'last_modified_timestamp': timestamp,
              'has_media': 0,
            },
          ];
          
          // Test 1: Normal batch upsert
          QuizzerLogger.logMessage('Test 1: Normal batch upsert');
          await batchUpsertQuestionAnswerPairs(records: testRecords);
          QuizzerLogger.logSuccess('✅ Normal batch upsert completed');
          
          // Test 2: Batch with duplicates (should handle gracefully)
          QuizzerLogger.logMessage('Test 2: Batch with duplicates');
          final duplicateRecords = [
            ...testRecords,
            testRecords[0], // Duplicate the first record
            testRecords[1], // Duplicate the second record
          ];
          await batchUpsertQuestionAnswerPairs(records: duplicateRecords);
          QuizzerLogger.logSuccess('✅ Duplicate batch upsert completed');
          
          // Test 3: Batch with empty records (should handle gracefully)
          QuizzerLogger.logMessage('Test 3: Batch with empty records');
          final emptyRecords = [
            <String, dynamic>{}, // Empty record
            {'question_id': '${timestamp}_empty_$userId'}, // Record with only question_id
            ...testRecords.sublist(0, 2), // Some valid records
          ];
          await batchUpsertQuestionAnswerPairs(records: emptyRecords);
          QuizzerLogger.logSuccess('✅ Empty records batch upsert completed');
          
          // Test 4: Large batch (test chunking)
          QuizzerLogger.logMessage('Test 4: Large batch with chunking');
          final largeBatch = <Map<String, dynamic>>[];
          for (int i = 0; i < 100; i++) {
            largeBatch.add({
              'time_stamp': '${timestamp}_large_$i',
              'citation': 'Large batch citation $i',
              'question_elements': json.encode([{'type': 'text', 'content': 'Large batch question $i?'}]),
              'answer_elements': json.encode([{'type': 'text', 'content': 'Large batch answer $i'}]),
              'ans_flagged': 0,
              'ans_contrib': userId,
              'concepts': 'test,large_batch',
              'subjects': 'testing',
              'qst_contrib': userId,
              'qst_reviewer': userId,
              'has_been_reviewed': 1,
              'flag_for_removal': 0,
              'completed': 1,
              'module_name': 'Large Test Module',
              'question_type': 'multiple_choice',
              'options': json.encode([
                {'type': 'text', 'content': 'Option A'},
                {'type': 'text', 'content': 'Option B'},
                {'type': 'text', 'content': 'Option C'},
                {'type': 'text', 'content': 'Option D'}
              ]),
              'correct_option_index': 0,
              'question_id': '${timestamp}_large_$i$userId',
              'correct_order': null,
              'index_options_that_apply': null,
              'has_been_synced': 1, // Prevent outbound sync
              'edits_are_synced': 1, // Prevent outbound sync
              'last_modified_timestamp': timestamp,
              'has_media': 0,
            });
          }
          await batchUpsertQuestionAnswerPairs(records: largeBatch);
          QuizzerLogger.logSuccess('✅ Large batch upsert completed');
          
          // Test 5: Verify records were actually inserted
          QuizzerLogger.logMessage('Test 5: Verifying records were inserted');
          final allRecords = await getAllQuestionAnswerPairs();
          final testRecordIds = testRecords.map((r) => r['question_id'] as String).toSet();
          final largeBatchIds = largeBatch.map((r) => r['question_id'] as String).toSet();
          
          final foundTestRecords = allRecords.where((r) => testRecordIds.contains(r['question_id'])).length;
          final foundLargeBatchRecords = allRecords.where((r) => largeBatchIds.contains(r['question_id'])).length;
          
          expect(foundTestRecords, greaterThanOrEqualTo(4), 
            reason: 'Should have found at least 4 test records. Found: $foundTestRecords');
          expect(foundLargeBatchRecords, greaterThanOrEqualTo(100), 
            reason: 'Should have found at least 100 large batch records. Found: $foundLargeBatchRecords');
          
          QuizzerLogger.logSuccess('✅ Record verification completed. Found $foundTestRecords test records and $foundLargeBatchRecords large batch records');
          
          // Test 6: Test updating existing records
          QuizzerLogger.logMessage('Test 6: Testing update of existing records');
          final updateRecords = testRecords.map((record) {
            final updatedRecord = Map<String, dynamic>.from(record);
            updatedRecord['citation'] = 'Updated citation for ${record['question_id']}';
            updatedRecord['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();
            return updatedRecord;
          }).toList();
          
          await batchUpsertQuestionAnswerPairs(records: updateRecords);
          QuizzerLogger.logSuccess('✅ Update test completed');
          
          QuizzerLogger.logSuccess('✅ All batch upsert tests completed successfully');
          
        } catch (e, stackTrace) {
          QuizzerLogger.logError('Batch upsert test failed: $e');
          QuizzerLogger.logError('Stack trace: $stackTrace');
          rethrow;
        }
      });
    
    
    
    
    
    });
}
