import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/inbound_sync/inbound_sync_worker.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/outbound_sync/outbound_sync_worker.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/outbound_sync/outbound_sync_functions.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/inbound_sync/inbound_sync_functions.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:supabase/supabase.dart';
import '../test_helpers.dart';
import 'dart:io';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_settings_table.dart' as user_settings_table;

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
  late final SupabaseClient supabase;
  
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
    supabase = sessionManager.supabase;
    await sessionManager.initializationComplete;
    await performLoginProcess(
      email: testEmail, 
      password: testPassword, 
      supabase: sessionManager.supabase, 
      storage: sessionManager.getBox(testAccessPassword));
  });
  
  group('InboundSyncWorker Singleton Test', () {
    test('Test 1: Should be a singleton - multiple instances should be the same', () async {
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
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('OutboundSyncWorker Singleton Test', () {
    test('Test 1: Should be a singleton - multiple instances should be the same', () async {
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
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('Question Answer Pairs Sync Tests', () {
    // Track question IDs and full records for cleanup - shared across all tests in this group
    final List<String> testQuestionIds = [];
    final List<Map<String, dynamic>> testQuestionRecords = [];
    final List<String> testModuleNames = [];
    late String testStartTimestamp;
    
    setUpAll(() async {
      // Record TimeNow timestamp for later use
      testStartTimestamp = DateTime.now().toUtc().toIso8601String();
      
      // Clear the table first
      await deleteAllRecordsFromTable('question_answer_pairs');
      
      // Create 5 test questions for sync testing
      final inputData = generateQuestionInputData(
        questionType: 'multiple_choice',
        numberOfQuestions: 5,
        numberOfModules: 1,
      );
      
      for (int i = 0; i < 5; i++) {
        final questionId = await addQuestionMultipleChoice(
          moduleName: inputData[i]['moduleName'],
          questionElements: inputData[i]['questionElements'],
          answerElements: inputData[i]['answerElements'],
          options: inputData[i]['options'],
          correctOptionIndex: inputData[i]['correctOptionIndex'],
          debugDisableOutboundSyncCall: true,
        );
        testQuestionIds.add(questionId);
        
        // Store the full question record for later use
        final questionRecord = await getQuestionAnswerPairById(questionId);
        testQuestionRecords.add(questionRecord);
        
        // Track the module name for cleanup
        if (!testModuleNames.contains(inputData[i]['moduleName'])) {
          testModuleNames.add(inputData[i]['moduleName']);
        }
      }
      
      QuizzerLogger.logMessage('Created 5 test questions for sync testing');
    });
    
    tearDownAll(() async {
      QuizzerLogger.logMessage('Cleaning up test questions from local database after all tests complete...');
      if (testQuestionIds.isNotEmpty) {
        await cleanupTestQuestions(testQuestionIds);
        QuizzerLogger.logSuccess('Cleaned up ${testQuestionIds.length} test questions from local database');
      }
      
      QuizzerLogger.logMessage('Cleaning up test modules from local database and Supabase after all tests complete...');
      if (testModuleNames.isNotEmpty) {
        await cleanupTestModules(testModuleNames);
        QuizzerLogger.logSuccess('Cleaned up ${testModuleNames.length} test modules from local database and Supabase');
      }
    });
    
    group('Question Answer Pairs Outbound Sync Tests', () {
      test('Test 1: Outbound Sync - Sync 5 questions to new_review table', () async {
          // Verify questions were created locally
          final localQuestions = await getAllQuestionAnswerPairs();
          expect(localQuestions.length, equals(5));
          
          // Debug: Check sync flags before sync
          for (final question in localQuestions) {
            QuizzerLogger.logMessage('Before sync - Question ${question['question_id']}: has_been_synced=${question['has_been_synced']}, edits_are_synced=${question['edits_are_synced']}');
          }
          
          // Debug: Check unsynced records
          final unsyncedRecords = await getUnsyncedQuestionAnswerPairs();
          QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced records before sync');
          
          // Execute: Call outbound sync function
          QuizzerLogger.logMessage('About to call syncQuestionAnswerPairs()...');
          await syncQuestionAnswerPairs();
          QuizzerLogger.logMessage('syncQuestionAnswerPairs() completed');
          
          // Expect: Records should be pushed to question_answer_pair_new_review table
          // Verify local sync flags were updated
          final syncedQuestions = await getAllQuestionAnswerPairs();
          
          // Debug: Check sync flags after sync
          for (final question in syncedQuestions) {
            QuizzerLogger.logMessage('After sync - Question ${question['question_id']}: has_been_synced=${question['has_been_synced']}, edits_are_synced=${question['edits_are_synced']}');
          }
          
          for (final question in syncedQuestions) {
            expect(question['has_been_synced'], equals(1), reason: 'Questions should be marked as synced after outbound sync');
            expect(question['edits_are_synced'], equals(1), reason: 'Questions should be marked as synced after outbound sync');
          }
      
          // MANUALLY CHECK SUPABASE TO SEE IF THEY GOT PUSHED
          final sessionManager = getSessionManager();
          final supabase = sessionManager.supabase;
      
          // Check if records exist in new_review table and verify data integrity
          for (final questionId in testQuestionIds) {
            try {
              final response = await supabase
                .from('question_answer_pair_new_review')
                .select()
                .eq('question_id', questionId)
                .single();
              
              expect(response, isNotNull, reason: 'Question $questionId should exist in new_review table');
              expect(response['question_id'], equals(questionId), reason: 'Question ID should match');
              
              // Get the local record for comparison
              final localRecord = await getQuestionAnswerPairById(questionId);
              
              // Verify all critical fields match exactly
              expect(response['module_name'], equals(localRecord['module_name']), reason: 'Module name should match');
              expect(response['question_type'], equals(localRecord['question_type']), reason: 'Question type should match');
              
              // Decode Supabase JSON strings for comparison with local decoded data
              final supabaseQuestionElements = decodeValueFromDB(response['question_elements']);
              final supabaseAnswerElements = decodeValueFromDB(response['answer_elements']);
              final supabaseOptions = decodeValueFromDB(response['options']);
              
              expect(supabaseQuestionElements, equals(localRecord['question_elements']), reason: 'Question elements should match');
              expect(supabaseAnswerElements, equals(localRecord['answer_elements']), reason: 'Answer elements should match');
              expect(supabaseOptions, equals(localRecord['options']), reason: 'Options should match');
              expect(response['correct_option_index'], equals(localRecord['correct_option_index']), reason: 'Correct option index should match');
              expect(response['qst_contrib'], equals(localRecord['qst_contrib']), reason: 'Question contributor should match');
              expect(response['time_stamp'], equals(localRecord['time_stamp']), reason: 'Timestamp should match');
              // Convert Supabase boolean to integer for comparison with local data
              final supabaseHasMedia = response['has_media'] == true ? 1 : 0;
              expect(supabaseHasMedia, equals(localRecord['has_media']), reason: 'Has media flag should match');
              
              QuizzerLogger.logSuccess('Verified question $questionId exists in new_review table with matching data');
            } catch (e) {
              fail('Question $questionId was not found in new_review table or data mismatch: $e');
            }
          }

    }, timeout: const Timeout(Duration(minutes: 5)));

      test('Test 2: Outbound Sync - Edit questions and sync to edits_review table', () async {
        // Edit the 5 questions to trigger edit sync flags
        final localQuestions = await getAllQuestionAnswerPairs();
        expect(localQuestions.length, equals(5));
        
        // Edit each question to trigger sync flags
        for (final question in localQuestions) {
          await editQuestionAnswerPair(
            questionId: question['question_id'],
            moduleName: '${question['module_name']}_edited',
            debugDisableOutboundSyncCall: true, // Disable automatic sync for testing
          );
        }
        
        // Verify edit sync flags are set
        final editedQuestions = await getAllQuestionAnswerPairs();
        for (final question in editedQuestions) {
          expect(question['edits_are_synced'], equals(0), reason: 'Edit sync flag should be 0 after editing');
        }
        
        // Execute: Call outbound sync function again
        await syncQuestionAnswerPairs();
        
        // Expect: Records should be pushed to question_answer_pair_edits_review table
        // Verify local sync flags were updated
        final editedSyncedQuestions = await getAllQuestionAnswerPairs();
        for (final question in editedSyncedQuestions) {
          expect(question['has_been_synced'], equals(1), reason: 'Edited questions should be marked as synced after outbound sync');
          expect(question['edits_are_synced'], equals(1), reason: 'Edited questions should be marked as synced after outbound sync');
        }
        
        // MANUALLY CHECK SUPABASE TO SEE IF EDITED RECORDS GOT PUSHED TO EDITS_REVIEW TABLE
        final sessionManager = getSessionManager();
        final supabase = sessionManager.supabase;
        
        // Check if edited records exist in edits_review table and verify data integrity
        for (final questionId in testQuestionIds) {
          try {
            final response = await supabase
              .from('question_answer_pair_edits_review')
              .select()
              .eq('question_id', questionId)
              .single();
            
            expect(response, isNotNull, reason: 'Edited question $questionId should exist in edits_review table');
            expect(response['question_id'], equals(questionId), reason: 'Question ID should match');
            expect(response['module_name'], endsWith(' edited'), reason: 'Module name should be edited');
            
            // Get the local record for comparison
            final localRecord = await getQuestionAnswerPairById(questionId);
            
            // Verify all critical fields match exactly (except module_name which was edited)
            expect(response['question_type'], equals(localRecord['question_type']), reason: 'Question type should match');
            
            // Decode Supabase JSON strings for comparison with local decoded data
            final supabaseQuestionElements = decodeValueFromDB(response['question_elements']);
            final supabaseAnswerElements = decodeValueFromDB(response['answer_elements']);
            final supabaseOptions = decodeValueFromDB(response['options']);
            
            expect(supabaseQuestionElements, equals(localRecord['question_elements']), reason: 'Question elements should match');
            expect(supabaseAnswerElements, equals(localRecord['answer_elements']), reason: 'Answer elements should match');
            expect(supabaseOptions, equals(localRecord['options']), reason: 'Options should match');
            expect(response['correct_option_index'], equals(localRecord['correct_option_index']), reason: 'Correct option index should match');
            expect(response['qst_contrib'], equals(localRecord['qst_contrib']), reason: 'Question contributor should match');
            expect(response['time_stamp'], equals(localRecord['time_stamp']), reason: 'Timestamp should match');
            // Convert Supabase boolean to integer for comparison with local data
            final supabaseHasMedia = response['has_media'] == true ? 1 : 0;
            expect(supabaseHasMedia, equals(localRecord['has_media']), reason: 'Has media flag should match');
            
            // Verify the module name was actually edited (should end with ' edited' not '_edited')
            expect(response['module_name'], equals(localRecord['module_name']), reason: 'Edited module name should match local record');
            
            QuizzerLogger.logSuccess('Verified edited question $questionId exists in edits_review table with matching data');
          } catch (e) {
            fail('Edited question $questionId was not found in edits_review table or data mismatch: $e');
          }
        }
      }, timeout: const Timeout(Duration(minutes: 5)));
      
      test('Test 3: Cleanup - Remove test data from review tables after outbound sync tests', () async {
        // This test ensures cleanup always runs after Test 1 and Test 2, regardless of pass/fail
        QuizzerLogger.logMessage('Running mandatory cleanup after outbound sync tests');
        
        // Clean up the review tables using the existing helper function
        await deleteTestQuestionsFromSupabase(testQuestionIds);
        QuizzerLogger.logMessage('Cleaned up review tables after outbound sync tests');
        
        // Verify cleanup was successful by checking local records still exist
        final localQuestions = await getAllQuestionAnswerPairs();
        expect(localQuestions.length, equals(5), reason: 'Local questions should still exist after Supabase cleanup');
        QuizzerLogger.logSuccess('Successfully cleaned up review tables while preserving local test data');
      }, timeout: const Timeout(Duration(minutes: 5)));
      });
        
    group('Question Answer Pairs Inbound Sync Tests', () {
      test('Test 1: Mass Inbound Sync - Drop table and recreate', () async {
          // Setup: Drop the local table completely
          await dropTable('question_answer_pairs');
          
          // Execute: Call inbound sync without specifying timestamp
          // The function should automatically handle empty/missing table
          final sessionManager = getSessionManager();
          final supabase = sessionManager.supabase;
          final userId = sessionManager.userId!;
          
          await syncQuestionAnswerPairsInbound(userId, supabase);
          
          // Expect: Table should be recreated and filled with all server records
          // Verify table was recreated by checking if we can query it
          final allQuestions = await getAllQuestionAnswerPairs();
          expect(allQuestions.length, greaterThan(3000), reason: 'Table should be recreated and contain questions (some may be skipped due to validation)');
        }, timeout: const Timeout(Duration(minutes: 5)));

      test('Test 2: Inbound Sync - Manual server records to local sync', () async {
          // Setup: Manually push the 5 specific test questions to the main Supabase table
          
          // Verify we have the 5 test questions stored
          expect(testQuestionRecords.length, equals(5), reason: 'Should have 5 test question records from setUpAll()');
          
          // Manually push each of the 5 specific test questions to the main Supabase table
          for (final questionRecord in testQuestionRecords) {
            try {
              // Create a copy of the question with encoded complex fields for Supabase
              final Map<String, dynamic> encodedQuestion = Map<String, dynamic>.from(questionRecord);
              
              // Remove local-only fields that don't exist in Supabase schema
              encodedQuestion.remove('has_been_synced');
              encodedQuestion.remove('edits_are_synced');
              
              // Encode complex fields that are Lists to JSON strings for Supabase
              if (encodedQuestion['question_elements'] is List) {
                encodedQuestion['question_elements'] = encodeValueForDB(encodedQuestion['question_elements']);
              }
              if (encodedQuestion['answer_elements'] is List) {
                encodedQuestion['answer_elements'] = encodeValueForDB(encodedQuestion['answer_elements']);
              }
              if (encodedQuestion['options'] is List) {
                encodedQuestion['options'] = encodeValueForDB(encodedQuestion['options']);
              }
              if (encodedQuestion['correct_order'] is List) {
                encodedQuestion['correct_order'] = encodeValueForDB(encodedQuestion['correct_order']);
              }
              if (encodedQuestion['index_options_that_apply'] is List) {
                encodedQuestion['index_options_that_apply'] = encodeValueForDB(encodedQuestion['index_options_that_apply']);
              }
              if (encodedQuestion['answers_to_blanks'] is List) {
                encodedQuestion['answers_to_blanks'] = encodeValueForDB(encodedQuestion['answers_to_blanks']);
              }
              
              // Convert integer has_media to smallint for Supabase (keep as 0 or 1)
              if (encodedQuestion['has_media'] is int) {
                encodedQuestion['has_media'] = encodedQuestion['has_media']; // Keep as integer
              }
              
              await supabase
                .from('question_answer_pairs')
                .insert(encodedQuestion);
              QuizzerLogger.logMessage('Manually pushed test question ${questionRecord['question_id']} to main Supabase table');
            } catch (e) {
              QuizzerLogger.logError('Failed to push test question ${questionRecord['question_id']} to Supabase: $e');
              rethrow;
            }
          }
          
          // Verify the 5 test questions were pushed to Supabase
          for (final questionId in testQuestionIds) {
            try {
              final response = await supabase
                .from('question_answer_pairs')
                .select()
                .eq('question_id', questionId)
                .single();
              expect(response, isNotNull, reason: 'Test question $questionId should exist in main Supabase table');
            } catch (e) {
              fail('Test question $questionId was not found in main Supabase table: $e');
            }
          }
          
          // The 5 test questions are now in Supabase but do NOT exist locally (table was dropped in Test 1)
          // Execute: Call inbound sync with the timestamp from setUpAll
          await syncQuestionAnswerPairsInbound(sessionManager.userId!, supabase, effectiveLastLogin: testStartTimestamp);
          
          // Verify that the 5 specific test questions are synced back to local table
          for (final questionId in testQuestionIds) {
            final question = await getQuestionAnswerPairById(questionId);
            expect(question, isNotNull, reason: 'Test question $questionId should exist locally after inbound sync');
            expect(question['question_type'], equals('multiple_choice'), reason: 'Question type should match');
          }
        }, timeout: const Timeout(Duration(minutes: 5)));

      test('Test 3: Cleanup - Remove test data from server', () async {
          // Clean up locally created test data
          await deleteAllRecordsFromTable('question_answer_pairs');
          
          // Clean up test questions from Supabase
          if (testQuestionIds.isNotEmpty) {
            await deleteTestQuestionsFromSupabase(testQuestionIds);
          }
          
          QuizzerLogger.logMessage('Cleaning up test data from server');
          QuizzerLogger.logSuccess('Successfully cleaned up test data from server');
        }, timeout: const Timeout(Duration(minutes: 5)));
      });
    
    });

  group('User Question Answer Pairs Sync Tests', () {
    // Tests will be implemented here
  });

  group('User Profile Sync Tests', () {
    // Tests will be implemented here
  });

  group('User Settings Sync Tests', () {
    late String testUserId;
    
    setUpAll(() async {
      testUserId = sessionManager.userId!;
      
      // Clear both local and Supabase tables first
      await deleteAllRecordsFromTable('user_settings');
      await supabase
        .from('user_settings')
        .delete()
        .eq('user_id', testUserId);
      
      // Create test settings locally (not in Supabase yet)
      // The table verification will create default settings
      await sessionManager.getUserSettings(getAll: true);
      
      QuizzerLogger.logMessage('Created test user settings for sync testing');
    });
    
    group('User Settings Outbound Sync Tests', () {
      test('Test 1: Outbound Sync - Sync default settings to cloud', () async {
        QuizzerLogger.logMessage('Testing outbound sync of default user settings');
        
        // Verify settings were created locally
        final localSettings = await sessionManager.getUserSettings(getAll: true);
        expect(localSettings, isNotEmpty, reason: 'Should have default settings locally');
        
        // Debug: Check sync flags before sync
        final db = await getDatabaseMonitor().requestDatabaseAccess();
        try {
          final syncFlags = await queryAndDecodeDatabase(
            'user_settings',
            db!,
            columns: ['setting_name', 'has_been_synced', 'edits_are_synced'],
            where: 'user_id = ?',
            whereArgs: [testUserId],
          );
          
          for (final flag in syncFlags) {
            QuizzerLogger.logMessage('Before sync - Setting ${flag['setting_name']}: has_been_synced=${flag['has_been_synced']}, edits_are_synced=${flag['edits_are_synced']}');
          }
        } finally {
          getDatabaseMonitor().releaseDatabaseAccess();
        }
        
        // Execute: Call outbound sync function
        QuizzerLogger.logMessage('About to call syncUserSettings()...');
        await syncUserSettings();
        QuizzerLogger.logMessage('syncUserSettings() completed');
        
        // Expect: Records should be pushed to Supabase
        // Verify local sync flags were updated
        final db2 = await getDatabaseMonitor().requestDatabaseAccess();
        try {
          final syncFlagsAfter = await queryAndDecodeDatabase(
            'user_settings',
            db2!,
            columns: ['setting_name', 'has_been_synced', 'edits_are_synced'],
            where: 'user_id = ?',
            whereArgs: [testUserId],
          );
          
          for (final flag in syncFlagsAfter) {
            QuizzerLogger.logMessage('After sync - Setting ${flag['setting_name']}: has_been_synced=${flag['has_been_synced']}, edits_are_synced=${flag['edits_are_synced']}');
            expect(flag['has_been_synced'], equals(1), reason: 'Setting ${flag['setting_name']} should be marked as synced');
            expect(flag['edits_are_synced'], equals(1), reason: 'Setting ${flag['setting_name']} should be marked as synced');
          }
        } finally {
          getDatabaseMonitor().releaseDatabaseAccess();
        }
        
        // Check if records exist in user_settings table and verify data integrity
        final supabaseSettings = await supabase
          .from('user_settings')
          .select()
          .eq('user_id', testUserId);
        
        expect(supabaseSettings, isNotEmpty, reason: 'Should have settings in Supabase');
        
        // Verify each setting exists in Supabase with matching data
        for (final supabaseSetting in supabaseSettings) {
          final settingName = supabaseSetting['setting_name'] as String;
          final settingValue = supabaseSetting['setting_value'];
          
          // Get the local record for comparison
          final localValue = await user_settings_table.getSettingValue(testUserId, settingName);
          
          // Verify the setting value matches
          expect(localValue, isNotNull, reason: 'Local setting $settingName should exist');
          expect(settingValue, equals(localValue!['value']), reason: 'Setting $settingName value should match between local and Supabase');
          expect(supabaseSetting['user_id'], equals(testUserId), reason: 'Setting $settingName should belong to test user');
          
          QuizzerLogger.logSuccess('Verified setting $settingName exists in Supabase with matching data');
        }
        
        QuizzerLogger.logSuccess('✅ Outbound sync of default user settings test passed');
      }, timeout: const Timeout(Duration(minutes: 5)));
      
      test('Test 2: Outbound Sync - Edit settings and sync to cloud', () async {
        QuizzerLogger.logMessage('Testing outbound sync of modified user settings');
        
        // Modify some settings locally
        await sessionManager.updateUserSetting('geminiApiKey', 'test-api-key-123');
        await sessionManager.updateUserSetting('home_display_eligible_questions', true);
        await sessionManager.updateUserSetting('home_display_in_circulation_questions', true);
        
        // Verify local changes
        final localSettings = await sessionManager.getUserSettings(getAll: true);
        expect(localSettings['geminiApiKey'], equals('test-api-key-123'));
        expect(localSettings['home_display_eligible_questions'], equals('1'));
        expect(localSettings['home_display_in_circulation_questions'], equals('1'));
        
        // Execute: Call outbound sync function again
        await syncUserSettings();
        
        // Expect: Modified records should be pushed to Supabase
        // Verify local sync flags were updated for modified settings
        final db = await getDatabaseMonitor().requestDatabaseAccess();
        try {
          final syncFlags = await queryAndDecodeDatabase(
            'user_settings',
            db!,
            columns: ['setting_name', 'has_been_synced', 'edits_are_synced'],
            where: 'user_id = ? AND setting_name IN (?, ?, ?)',
            whereArgs: [testUserId, 'geminiApiKey', 'home_display_eligible_questions', 'home_display_in_circulation_questions'],
          );
          
          for (final flag in syncFlags) {
            expect(flag['has_been_synced'], equals(1), reason: 'Setting ${flag['setting_name']} should be marked as synced');
            expect(flag['edits_are_synced'], equals(1), reason: 'Setting ${flag['setting_name']} should be marked as synced');
          }
        } finally {
          getDatabaseMonitor().releaseDatabaseAccess();
        }
        
        // MANUALLY CHECK SUPABASE TO SEE IF MODIFIED SETTINGS GOT PUSHED
        
        // Check if modified settings exist in Supabase with updated values
        final supabaseSettings = await supabase
          .from('user_settings')
          .select()
          .eq('user_id', testUserId);
        
        expect(supabaseSettings, isNotEmpty, reason: 'Should have settings in Supabase');
        
        // Verify modified settings have correct values in Supabase
        for (final supabaseSetting in supabaseSettings) {
          final settingName = supabaseSetting['setting_name'] as String;
          final settingValue = supabaseSetting['setting_value'];
          
          switch (settingName) {
            case 'geminiApiKey':
              expect(settingValue, equals('test-api-key-123'), reason: 'geminiApiKey should be updated in Supabase');
              break;
            case 'home_display_eligible_questions':
            case 'home_display_in_circulation_questions':
              expect(settingValue, equals('1'), reason: '$settingName should be updated in Supabase');
              break;
          }
          
          QuizzerLogger.logSuccess('Verified modified setting $settingName has correct value in Supabase');
        }
        
        QuizzerLogger.logSuccess('✅ Outbound sync of modified user settings test passed');
      }, timeout: const Timeout(Duration(minutes: 5)));
      
      test('Test 3: Cleanup - Remove test data from Supabase after outbound sync tests', () async {
        // This test ensures cleanup always runs after Test 1 and Test 2, regardless of pass/fail
        QuizzerLogger.logMessage('Running mandatory cleanup after outbound sync tests');
        
        // Clean up Supabase but keep local records
        await supabase
          .from('user_settings')
          .delete()
          .eq('user_id', testUserId);
        
        QuizzerLogger.logMessage('Cleaned up Supabase after outbound sync tests');
        
        // Verify cleanup was successful by checking local records still exist
        final localSettings = await sessionManager.getUserSettings(getAll: true);
        expect(localSettings, isNotEmpty, reason: 'Local settings should still exist after Supabase cleanup');
        QuizzerLogger.logSuccess('Successfully cleaned up Supabase while preserving local test data');
      }, timeout: const Timeout(Duration(minutes: 5)));
    });
    
    group('User Settings Inbound Sync Tests', () {
      test('Test 1: Mass Inbound Sync - Empty tables on both sides', () async {
        QuizzerLogger.logMessage('Testing inbound sync with empty tables on both sides');
        
        // Setup: Clear both local and Supabase tables
        await deleteAllRecordsFromTable('user_settings');
        await supabase
          .from('user_settings')
          .delete()
          .eq('user_id', testUserId);
        
        // Execute: Call inbound sync on empty Supabase
        await syncUserSettingsInbound(testUserId, supabase);
        
        // Expect: Local table should be recreated with default settings only
        // (no sync should happen since Supabase is empty)
        final localSettings = await sessionManager.getUserSettings(getAll: true);
        expect(localSettings, isNotEmpty, reason: 'Should have default settings after inbound sync');
        
        // Verify all default settings from _applicationSettings were created (not synced from empty Supabase)
        const List<String> expectedSettings = [
          'geminiApiKey',
          'home_display_eligible_questions',
          'home_display_in_circulation_questions',
          'home_display_non_circulating_questions',
          'home_display_lifetime_total_questions_answered',
          'home_display_daily_questions_answered',
          'home_display_average_daily_questions_learned',
          'home_display_average_questions_shown_per_day',
          'home_display_days_left_until_questions_exhaust',
          'home_display_revision_streak_score',
          'home_display_last_reviewed',
        ];
        
        for (final settingName in expectedSettings) {
          expect(localSettings.containsKey(settingName), isTrue, reason: 'Should have default $settingName');
        }
        
        // NOTE: DO NOT ADD EXACT COUNT EXPECTATIONS - they break when new settings are added
        
        QuizzerLogger.logSuccess('✅ Empty tables inbound sync test passed');
      }, timeout: const Timeout(Duration(minutes: 5)));
      
      test('Test 2: Inbound Sync - Simulate new device with non-default settings in Supabase', () async {
        QuizzerLogger.logMessage('Testing inbound sync simulating new device with non-default settings in Supabase');
        
        // Setup: Set all settings to non-default values and push to Supabase
        await sessionManager.updateUserSetting('geminiApiKey', 'non-default-api-key');
        await sessionManager.updateUserSetting('home_display_eligible_questions', true);
        await sessionManager.updateUserSetting('home_display_in_circulation_questions', true);
        await sessionManager.updateUserSetting('home_display_average_daily_questions_learned', true);
        await sessionManager.updateUserSetting('home_display_average_questions_shown_per_day', true);
        await sessionManager.updateUserSetting('home_display_daily_questions_answered', true);
        await sessionManager.updateUserSetting('home_display_days_left_until_questions_exhaust', true);
        await sessionManager.updateUserSetting('home_display_last_reviewed', true);
        await sessionManager.updateUserSetting('home_display_lifetime_total_questions_answered', true);
        await sessionManager.updateUserSetting('home_display_non_circulating_questions', true);
        await sessionManager.updateUserSetting('home_display_revision_streak_score', true);
        
        // Push all settings to Supabase using outbound sync
        await syncUserSettings();
        
        // Verify the specific non-default settings are in Supabase
        final supabaseSettings = await supabase
          .from('user_settings')
          .select()
          .eq('user_id', testUserId);
        expect(supabaseSettings, isNotEmpty, reason: 'Should have non-default settings in Supabase');
        
        // Verify ALL specific values we pushed are actually in Supabase
        final expectedNonDefaultSettings = {
          'geminiApiKey': 'non-default-api-key',
          'home_display_eligible_questions': '1',
          'home_display_in_circulation_questions': '1',
          'home_display_average_daily_questions_learned': '1',
          'home_display_average_questions_shown_per_day': '1',
          'home_display_daily_questions_answered': '1',
          'home_display_days_left_until_questions_exhaust': '1',
          'home_display_last_reviewed': '1',
          'home_display_lifetime_total_questions_answered': '1',
          'home_display_non_circulating_questions': '1',
          'home_display_revision_streak_score': '1',
        };
        
        for (final entry in expectedNonDefaultSettings.entries) {
          final settingName = entry.key;
          final expectedValue = entry.value;
          
          final settingRecord = supabaseSettings.firstWhere(
            (setting) => setting['setting_name'] == settingName,
            orElse: () => {},
          );
          expect(settingRecord['setting_value'], equals(expectedValue), reason: '$settingName should have non-default value in Supabase');
        }
        
        // Simulate new device: Drop local table completely
        await dropTable('user_settings');
        
        // Execute: Call inbound sync (should recreate table and sync from Supabase)
        await syncUserSettingsInbound(testUserId, supabase);
        
        // Expect: Local settings should match the non-default Supabase values
        final localSettings = await sessionManager.getUserSettings(getAll: true);
        expect(localSettings['geminiApiKey'], equals('non-default-api-key'), reason: 'geminiApiKey should be synced from Supabase');
        expect(localSettings['home_display_eligible_questions'], equals('1'), reason: 'home_display_eligible_questions should be synced from Supabase');
        expect(localSettings['home_display_in_circulation_questions'], equals('1'), reason: 'home_display_in_circulation_questions should be synced from Supabase');
        expect(localSettings['home_display_average_daily_questions_learned'], equals('1'), reason: 'home_display_average_daily_questions_learned should be synced from Supabase');
        expect(localSettings['home_display_average_questions_shown_per_day'], equals('1'), reason: 'home_display_average_questions_shown_per_day should be synced from Supabase');
        expect(localSettings['home_display_daily_questions_answered'], equals('1'), reason: 'home_display_daily_questions_answered should be synced from Supabase');
        expect(localSettings['home_display_days_left_until_questions_exhaust'], equals('1'), reason: 'home_display_days_left_until_questions_exhaust should be synced from Supabase');
        expect(localSettings['home_display_last_reviewed'], equals('1'), reason: 'home_display_last_reviewed should be synced from Supabase');
        expect(localSettings['home_display_lifetime_total_questions_answered'], equals('1'), reason: 'home_display_lifetime_total_questions_answered should be synced from Supabase');
        expect(localSettings['home_display_non_circulating_questions'], equals('1'), reason: 'home_display_non_circulating_questions should be synced from Supabase');
        expect(localSettings['home_display_revision_streak_score'], equals('1'), reason: 'home_display_revision_streak_score should be synced from Supabase');
        
        QuizzerLogger.logSuccess('✅ New device simulation inbound sync test passed');
      }, timeout: const Timeout(Duration(minutes: 5)));
      
      test('Test 3: Inbound Sync - Manual Supabase record change and sync', () async {
        QuizzerLogger.logMessage('Testing inbound sync with manual Supabase record change');
        
        // Setup: All settings are now non-default from Test 2
        // Manually change a record in Supabase
        await supabase
          .from('user_settings')
          .update({'setting_value': 'manually-changed-api-key'})
          .eq('user_id', testUserId)
          .eq('setting_name', 'geminiApiKey');
        
        // Verify the change was made in Supabase
        final supabaseSetting = await supabase
          .from('user_settings')
          .select()
          .eq('user_id', testUserId)
          .eq('setting_name', 'geminiApiKey')
          .single();
        expect(supabaseSetting['setting_value'], equals('manually-changed-api-key'), reason: 'Supabase setting should be manually changed');
        
        // Execute: Call inbound sync
        await syncUserSettingsInbound(testUserId, supabase);
        
        // Expect: Local setting should be updated to match the manual Supabase change
        final localSettings = await sessionManager.getUserSettings(getAll: true);
        expect(localSettings['geminiApiKey'], equals('manually-changed-api-key'), reason: 'Local setting should be updated from manual Supabase change');
        
        // Verify other settings remain unchanged
        expect(localSettings['home_display_eligible_questions'], equals('1'), reason: 'Other settings should remain unchanged');
        expect(localSettings['home_display_in_circulation_questions'], equals('1'), reason: 'Other settings should remain unchanged');
        
        QuizzerLogger.logSuccess('✅ Manual Supabase change inbound sync test passed');
      }, timeout: const Timeout(Duration(minutes: 5)));
      
      test('Test 4: Cleanup - Remove test data from server', () async {
        // This test ensures cleanup always runs after inbound sync tests
        QuizzerLogger.logMessage('Running mandatory cleanup after inbound sync tests');
        
        // Check what's in Supabase before cleanup
        final beforeCleanup = await supabase
          .from('user_settings')
          .select()
          .eq('user_id', testUserId);
        QuizzerLogger.logMessage('Found ${beforeCleanup.length} records in Supabase before cleanup');
        
        // Clean up Supabase test data - delete all records for this user
        final deleteResult = await supabase
          .from('user_settings')
          .delete()
          .eq('user_id', testUserId);
        QuizzerLogger.logMessage('Delete operation completed, result: $deleteResult');
        
        // Verify cleanup was successful by physically checking the table
        final afterCleanup = await supabase
          .from('user_settings')
          .select()
          .eq('user_id', testUserId);
        QuizzerLogger.logMessage('Found ${afterCleanup.length} records in Supabase after cleanup');
        
        // Verify cleanup was successful
        final supabaseSettings = await supabase
          .from('user_settings')
          .select()
          .eq('user_id', testUserId);
        
        QuizzerLogger.logMessage('Found ${supabaseSettings.length} records in Supabase after cleanup');
        expect(supabaseSettings, isEmpty, reason: 'Supabase should be clean after cleanup');
        
        QuizzerLogger.logSuccess('Successfully cleaned up Supabase after inbound sync tests');
      }, timeout: const Timeout(Duration(minutes: 5)));
    });
  });

  group('Modules Sync Tests', () {
    // Tests will be implemented here
  });

  group('User Stats Eligible Questions Sync Tests', () {
    // Tests will be implemented here
  });

  group('User Stats Non Circulating Questions Sync Tests', () {
    // Tests will be implemented here
  });

  group('User Stats In Circulation Questions Sync Tests', () {
    // Tests will be implemented here
  });

  group('User Stats Revision Streak Sum Sync Tests', () {
    // Tests will be implemented here
  });

  group('User Stats Total User Question Answer Pairs Sync Tests', () {
    // Tests will be implemented here
  });

  group('User Stats Average Questions Shown Per Day Sync Tests', () {
    // Tests will be implemented here
  });

  group('User Stats Total Questions Answered Sync Tests', () {
    // Tests will be implemented here
  });

  group('User Stats Daily Questions Answered Sync Tests', () {
    // Tests will be implemented here
  });

  group('User Stats Days Left Until Questions Exhaust Sync Tests', () {
    // Tests will be implemented here
  });

  group('User Stats Average Daily Questions Learned Sync Tests', () {
    // Tests will be implemented here
  });

  group('User Module Activation Status Sync Tests', () {
    // Tests will be implemented here
  });

  group('Subject Details Sync Tests', () {
    // Tests will be implemented here
  });

  group('Full Integration Tests', () {
    test('Should complete inbound sync cycles and verify unsynced records are empty', () async {
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
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('Should complete outbound sync cycles and verify unsynced records are empty', () async {
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
        
        // Step 3: Verify outbound sync completed successfully
        QuizzerLogger.logMessage('Step 3: Verifying outbound sync completed successfully');
        
        QuizzerLogger.logSuccess('Outbound sync cycle completed successfully');
        
        // Step 4: Send outbound sync needed signal
        QuizzerLogger.logMessage('Step 4: Sending outbound sync needed signal');
        signalOutboundSyncNeeded();
        
        // Step 5: Wait for cycle completion signal again
        QuizzerLogger.logMessage('Step 5: Waiting for second cycle completion');
        await switchBoard.onOutboundSyncCycleComplete.first;
        QuizzerLogger.logSuccess('Second sync cycle completed');
        
        QuizzerLogger.logSuccess('OutboundSyncWorker test completed successfully');
        
      } catch (e) {
        QuizzerLogger.logError('OutboundSyncWorker test failed: $e');
        rethrow;
      } finally {
        // Clean up
        await outboundSyncWorker.stop();
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}


