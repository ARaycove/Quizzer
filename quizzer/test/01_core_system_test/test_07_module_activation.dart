import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_module_activation_status_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import '../test_helpers.dart';
import 'dart:io';
import 'dart:math';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Manual iteration variable for reusing accounts across tests
  late int testIteration;
  
  // Test credentials - defined once and reused
  late String testEmail;
  late String testPassword;
  late String testAccessPassword;

  // Track the activated module across tests
  String? activatedModuleName;
  
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
    await performLoginProcess(
      email: testEmail, 
      password: testPassword, 
      supabase: sessionManager.supabase, 
      storage: sessionManager.getBox(testAccessPassword));
  });
  
  group('Module Activation Tests', () {
    test('Should deactivate all modules successfully', () async {
      QuizzerLogger.logMessage('Testing module deactivation...');
      
      try {
        // TRUNCATE user_module_activation_status table to ensure fresh state
        QuizzerLogger.logMessage('Truncating user_module_activation_status table for fresh state...');
        final db = await getDatabaseMonitor().requestDatabaseAccess();
        if (db == null) {
          throw Exception('Failed to acquire database access');
        }
        await db.delete('user_module_activation_status'); // Only truncate this specific table
        getDatabaseMonitor().releaseDatabaseAccess();
        QuizzerLogger.logSuccess('user_module_activation_status table truncated');
        
        // Verify the table is actually empty
        QuizzerLogger.logMessage('Verifying user_module_activation_status table is empty...');
        final dbVerify = await getDatabaseMonitor().requestDatabaseAccess();
        if (dbVerify == null) {
          throw Exception('Failed to acquire database access for verification');
        }
        final List<Map<String, dynamic>> activationRecords = await dbVerify.query('user_module_activation_status');
        getDatabaseMonitor().releaseDatabaseAccess();
        expect(activationRecords.isEmpty, isTrue, reason: 'user_module_activation_status table should be empty after truncation');
        QuizzerLogger.logSuccess('Verified user_module_activation_status table is empty');
        
        final List<Map<String, dynamic>> allModules = await getAllModules();
        for (final module in allModules) {
          final String moduleName = module['module_name'] as String;
          final bool result = await updateModuleActivationStatus(sessionManager.userId!, moduleName, false);
          expect(result, isTrue, reason: 'Failed to deactivate module: $moduleName');
        }
        QuizzerLogger.logSuccess('All modules deactivated successfully');
        
        // Verify all modules are deactivated
        final Map<String, bool> activationStatus = await getModuleActivationStatus(sessionManager.userId!);
        for (final status in activationStatus.values) {
          expect(status, isFalse, reason: 'All modules should be deactivated');
        }
        
      } catch (e) {
        QuizzerLogger.logError('Module deactivation test failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
    
    test('Should activate module and create user question answer pairs', () async {
      QuizzerLogger.logMessage('Testing module activation and user question answer pairs creation');
      
      try {
        // Step 1: Truncate the user_question_answer_pairs table
        QuizzerLogger.logMessage('Step 1: Truncating user_question_answer_pairs table');
        final db = await getDatabaseMonitor().requestDatabaseAccess();
        if (db == null) {
          throw Exception('Failed to acquire database access');
        }
        await db.delete('user_question_answer_pairs');
        getDatabaseMonitor().releaseDatabaseAccess();
        QuizzerLogger.logSuccess('user_question_answer_pairs table truncated');
        
        // Step 2: Ensure table is empty
        QuizzerLogger.logMessage('Step 2: Ensuring user_question_answer_pairs table is empty');
        final dbVerify = await getDatabaseMonitor().requestDatabaseAccess();
        if (dbVerify == null) {
          throw Exception('Failed to acquire database access for verification');
        }
        final List<Map<String, dynamic>> questionRecords = await dbVerify.query('user_question_answer_pairs');
        getDatabaseMonitor().releaseDatabaseAccess();
        expect(questionRecords.isEmpty, isTrue, reason: 'user_question_answer_pairs table should be empty after truncation');
        QuizzerLogger.logSuccess('Verified user_question_answer_pairs table is empty');
        
        // Step 3: Select a random module with questions
        QuizzerLogger.logMessage('Step 3: Selecting a random module with questions');
        final List<Map<String, dynamic>> allModules = await getAllModules();
        final random = Random();
        String selectedModuleName = '';
        int questionCount = 0;
        List<Map<String, dynamic>> moduleQuestions = [];
        
        // Try up to 10 random modules to find one with questions
        for (int attempt = 0; attempt < 10; attempt++) {
          final int randomIndex = random.nextInt(allModules.length);
          final String candidateModuleName = allModules[randomIndex]['module_name'] as String;
          QuizzerLogger.logMessage('Attempt ${attempt + 1}: Checking module: $candidateModuleName');
          
          moduleQuestions = await getQuestionRecordsForModule(candidateModuleName);
          questionCount = moduleQuestions.length;
          
          if (questionCount > 0) {
            selectedModuleName = candidateModuleName;
            QuizzerLogger.logMessage('Found module with questions: $selectedModuleName ($questionCount questions)');
            break;
          } else {
            QuizzerLogger.logMessage('Module $candidateModuleName has no questions, trying another...');
          }
        }
        
        // Step 4: Ensure we selected a module with questions
        expect(selectedModuleName, isNotEmpty, reason: 'Should have selected a valid module name');
        expect(questionCount, greaterThan(0), reason: 'Selected module should have at least one question');
        QuizzerLogger.logSuccess('Module selection verified: $selectedModuleName with $questionCount questions');
        
        // Step 5: Log the total number of questions in that module
        QuizzerLogger.logMessage('Step 5: Confirming total number of questions in module: $selectedModuleName');
        QuizzerLogger.logMessage('Total questions in module $selectedModuleName: $questionCount');
        
        // Step 6: Activate that selected module
        QuizzerLogger.logMessage('Step 6: Activating module: $selectedModuleName');
        final bool activationResult = await updateModuleActivationStatus(sessionManager.userId!, selectedModuleName, true);
        expect(activationResult, isTrue, reason: 'Failed to activate module: $selectedModuleName');
        QuizzerLogger.logSuccess('Module activated successfully: $selectedModuleName');
        
        // Store the activated module name in the global variable for use in subsequent tests
        activatedModuleName = selectedModuleName;
        QuizzerLogger.logMessage('Stored activated module name in global variable: $activatedModuleName');
        
        // Step 7: Ensure the module is now marked active in the module activation status table
        QuizzerLogger.logMessage('Step 7: Verifying module is marked active in activation status table');
        final Map<String, bool> activationStatus = await getModuleActivationStatus(sessionManager.userId!);
        expect(activationStatus[selectedModuleName], isTrue, reason: 'Module should be marked as active in activation status table');
        QuizzerLogger.logSuccess('Module activation status verified: $selectedModuleName is active');
        
        // Step 8: Ensure that n records are now stored in user_question_answer_pairs table
        QuizzerLogger.logMessage('Step 8: Verifying user_question_answer_pairs table has records');
        final dbFinal = await getDatabaseMonitor().requestDatabaseAccess();
        if (dbFinal == null) {
          throw Exception('Failed to acquire database access for final verification');
        }
        final List<Map<String, dynamic>> finalQuestionRecords = await dbFinal.query('user_question_answer_pairs');
        getDatabaseMonitor().releaseDatabaseAccess();
        
        final int finalRecordCount = finalQuestionRecords.length;
        QuizzerLogger.logMessage('Final user_question_answer_pairs count: $finalRecordCount');
        
        expect(finalRecordCount, greaterThan(0), reason: 'Should have records in user_question_answer_pairs table after module activation');
        expect(finalRecordCount, equals(questionCount), reason: 'Should have same number of records as questions in the module. Expected: $questionCount, Got: $finalRecordCount');
        
        QuizzerLogger.logSuccess('✅ Successfully verified $finalRecordCount records in user_question_answer_pairs table');
        
      } catch (e, stackTrace) {
        QuizzerLogger.logError('Module activation and user question answer pairs test failed: $e');
        QuizzerLogger.logError('Stack trace: $stackTrace');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
    
    test('Should return 0 eligible questions when all modules are deactivated', () async {
      QuizzerLogger.logMessage('Testing eligible questions with all modules deactivated...');
      
      try {
        // Step 1: Deactivate all modules
        QuizzerLogger.logMessage('Step 1: Deactivating all modules');
        final List<Map<String, dynamic>> allModules = await getAllModules();
        for (final module in allModules) {
          final String moduleName = module['module_name'] as String;
          final bool result = await updateModuleActivationStatus(sessionManager.userId!, moduleName, false);
          expect(result, isTrue, reason: 'Failed to deactivate module: $moduleName');
        }
        QuizzerLogger.logSuccess('All modules deactivated successfully');
        
        // Step 2: Ensure that all modules are deactivated
        QuizzerLogger.logMessage('Step 2: Verifying all modules are deactivated');
        final Map<String, bool> activationStatus = await getModuleActivationStatus(sessionManager.userId!);
        for (final status in activationStatus.values) {
          expect(status, isFalse, reason: 'All modules should be deactivated');
        }
        QuizzerLogger.logSuccess('Verified all modules are deactivated');
        
        // Step 3: Ensure that there are no eligible questions
        QuizzerLogger.logMessage('Step 3: Checking for eligible questions with all modules deactivated');
        final List<Map<String, dynamic>> eligibleQuestions = await getEligibleUserQuestionAnswerPairs(sessionManager.userId!);
        expect(eligibleQuestions.length, equals(0), reason: 'Should have 0 eligible questions when all modules are deactivated');
        QuizzerLogger.logSuccess('Confirmed 0 eligible questions with all modules deactivated');
        
      } catch (e) {
        QuizzerLogger.logError('Eligible questions test failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
    
    test('Should return eligible questions when module is activated and questions are in circulation', () async {
      QuizzerLogger.logMessage('Testing eligible questions with activated module...');
      
      try {
        // Step 1: Reactivate the previously selected module
        expect(activatedModuleName, isNotNull, reason: 'Module should have been activated in previous test');
        QuizzerLogger.logMessage('Step 1: Reactivating module: $activatedModuleName');
        
        final bool reactivationResult = await updateModuleActivationStatus(sessionManager.userId!, activatedModuleName!, true);
        expect(reactivationResult, isTrue, reason: 'Failed to reactivate module: $activatedModuleName');
        QuizzerLogger.logSuccess('Module reactivated successfully: $activatedModuleName');
        
        // Step 2: Verify the module is active
        QuizzerLogger.logMessage('Step 2: Verifying module is active');
        final Map<String, bool> activationStatus = await getModuleActivationStatus(sessionManager.userId!);
        expect(activationStatus[activatedModuleName], isTrue, reason: 'Module should be activated');
        QuizzerLogger.logSuccess('Module activation status verified: $activatedModuleName is active');
        
        // Get questions from the activated module
        final List<Map<String, dynamic>> moduleQuestions = await getQuestionRecordsForModule(activatedModuleName!);
        
        // Put all user questions from this module into circulation
        int questionsInCirculation = 0;
        for (final question in moduleQuestions) {
          final String questionId = question['question_id'] as String;
          try {
            await setCirculationStatus(sessionManager.userId!, questionId, true);
            questionsInCirculation++;
          } catch (e) {
            // This should never happen - module activation should have added all questions
            fail('User does not have question $questionId after module activation. Module activation failed.');
          }
        }
        QuizzerLogger.logSuccess('Put $questionsInCirculation questions into circulation');
        
        // Get eligible questions
        final List<Map<String, dynamic>> eligibleQuestions = await getEligibleUserQuestionAnswerPairs(sessionManager.userId!);
        expect(eligibleQuestions.length, equals(questionsInCirculation), reason: 'Should have $questionsInCirculation eligible questions when module is activated');
        QuizzerLogger.logSuccess('Confirmed ${eligibleQuestions.length} eligible questions with module activated');
        
      } catch (e) {
        QuizzerLogger.logError('Eligible questions with activated module test failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
    
    test('Should return 0 eligible questions when all revision due dates are set to future', () async {
      QuizzerLogger.logMessage('Testing eligible questions with future revision due dates...');
      
      try {
        // Use the module that was activated in previous tests
        expect(activatedModuleName, isNotNull, reason: 'Module should have been activated in previous test');
        QuizzerLogger.logMessage('Using activated module: $activatedModuleName');
        
        // Get questions from the activated module
        final List<Map<String, dynamic>> moduleQuestions = await getQuestionRecordsForModule(activatedModuleName!);
        
        // Set all revision due dates to 1 year in the future using direct database access
        final DateTime futureDate = DateTime.now().add(const Duration(days: 365));
        final String futureDateString = futureDate.toUtc().toIso8601String();
        int updatedCount = 0;
        
        final db = await getDatabaseMonitor().requestDatabaseAccess();
        if (db == null) {
          throw Exception('Failed to acquire database access');
        }
        
        for (final question in moduleQuestions) {
          final String questionId = question['question_id'] as String;
          try {
            final int result = await db.update(
              'user_question_answer_pairs',
              {'next_revision_due': futureDateString},
              where: 'user_uuid = ? AND question_id = ?',
              whereArgs: [sessionManager.userId!, questionId],
            );
            if (result > 0) {
              updatedCount++;
            }
          } catch (e) {
            fail('Failed to update revision due date for question $questionId: $e');
          }
        }
        getDatabaseMonitor().releaseDatabaseAccess();
        QuizzerLogger.logSuccess('Updated revision due dates for $updatedCount questions to future date');
        
        // Get eligible questions - should return 0 since nothing is due
        final List<Map<String, dynamic>> eligibleQuestions = await getEligibleUserQuestionAnswerPairs(sessionManager.userId!);
        expect(eligibleQuestions.length, equals(0), reason: 'Should have 0 eligible questions when all revision due dates are in the future');
        QuizzerLogger.logSuccess('Confirmed 0 eligible questions with future revision due dates');
        
      } catch (e) {
        QuizzerLogger.logError('Future revision due date test failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
    
    test('Should return all questions when revision due dates are set to past', () async {
      QuizzerLogger.logMessage('Testing eligible questions with past revision due dates...');
      
      try {
        // Use the module that was activated in previous tests
        expect(activatedModuleName, isNotNull, reason: 'Module should have been activated in previous test');
        QuizzerLogger.logMessage('Using activated module: $activatedModuleName');
        
        // Get questions from the activated module
        final List<Map<String, dynamic>> moduleQuestions = await getQuestionRecordsForModule(activatedModuleName!);
        
        // Set all revision due dates to 1 year in the past using direct database access
        final DateTime pastDate = DateTime.now().subtract(const Duration(days: 365));
        final String pastDateString = pastDate.toUtc().toIso8601String();
        int updatedCount = 0;
        
        final db = await getDatabaseMonitor().requestDatabaseAccess();
        if (db == null) {
          throw Exception('Failed to acquire database access');
        }
        
        for (final question in moduleQuestions) {
          final String questionId = question['question_id'] as String;
          try {
            final int result = await db.update(
              'user_question_answer_pairs',
              {'next_revision_due': pastDateString},
              where: 'user_uuid = ? AND question_id = ?',
              whereArgs: [sessionManager.userId!, questionId],
            );
            if (result > 0) {
              updatedCount++;
            }
          } catch (e) {
            fail('Failed to update revision due date for question $questionId: $e');
          }
        }
        getDatabaseMonitor().releaseDatabaseAccess();
        QuizzerLogger.logSuccess('Updated revision due dates for $updatedCount questions to past date');
        
        // Ensure all questions are in circulation
        int circulationCount = 0;
        for (final question in moduleQuestions) {
          final String questionId = question['question_id'] as String;
          try {
            await setCirculationStatus(sessionManager.userId!, questionId, true);
            circulationCount++;
          } catch (e) {
            fail('Failed to set circulation status for question $questionId: $e');
          }
        }
        QuizzerLogger.logSuccess('Set $circulationCount questions to in circulation');
        
        // Get eligible questions - should return all since they are past due and in circulation
        final List<Map<String, dynamic>> eligibleQuestions = await getEligibleUserQuestionAnswerPairs(sessionManager.userId!);
        expect(eligibleQuestions.length, equals(moduleQuestions.length), reason: 'Should have all questions eligible when revision due dates are in the past and questions are in circulation');
        QuizzerLogger.logSuccess('Confirmed ${eligibleQuestions.length} eligible questions with past revision due dates');
        
      } catch (e) {
        QuizzerLogger.logError('Past revision due date test failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
    
    test('Should return 0 eligible questions when all questions are set to not in circulation', () async {
      QuizzerLogger.logMessage('Testing eligible questions with questions not in circulation...');
      
      try {
        // Use the module that was activated in previous tests
        expect(activatedModuleName, isNotNull, reason: 'Module should have been activated in previous test');
        QuizzerLogger.logMessage('Using activated module: $activatedModuleName');
        
        // Get questions from the activated module
        final List<Map<String, dynamic>> moduleQuestions = await getQuestionRecordsForModule(activatedModuleName!);
        
        // Set all questions to not in circulation
        int updatedCount = 0;
        
        for (final question in moduleQuestions) {
          final String questionId = question['question_id'] as String;
          try {
            await setCirculationStatus(sessionManager.userId!, questionId, false);
            updatedCount++;
          } catch (e) {
            fail('Failed to set circulation status for question $questionId: $e');
          }
        }
        QuizzerLogger.logSuccess('Set $updatedCount questions to not in circulation');
        
        // Get eligible questions - should return 0 since nothing is in circulation
        final List<Map<String, dynamic>> eligibleQuestions = await getEligibleUserQuestionAnswerPairs(sessionManager.userId!);
        expect(eligibleQuestions.length, equals(0), reason: 'Should have 0 eligible questions when all questions are not in circulation');
        QuizzerLogger.logSuccess('Confirmed 0 eligible questions with questions not in circulation');
        
      } catch (e) {
        QuizzerLogger.logError('Not in circulation test failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
    
    test('Should return complete question records with both user and question details', () async {
      QuizzerLogger.logMessage('Testing structure of returned eligible question records...');
      
      try {
        // Step 1: Reset user question answer pairs table
        QuizzerLogger.logMessage('Step 1: Resetting user_question_answer_pairs table...');
        final bool resetSuccess = await resetUserQuestionAnswerPairsTable();
        expect(resetSuccess, isTrue, reason: 'Failed to reset user question answer pairs table');
        QuizzerLogger.logSuccess('user_question_answer_pairs table reset');
        
        // Step 2: Activate only the previously selected module
        QuizzerLogger.logMessage('Step 2: Activating only the previously selected module...');
        expect(activatedModuleName, isNotNull, reason: 'No module was previously selected');
        final bool result = await updateModuleActivationStatus(sessionManager.userId!, activatedModuleName!, true);
        expect(result, isTrue, reason: 'Failed to activate module: $activatedModuleName');
        QuizzerLogger.logSuccess('Activated module: $activatedModuleName');
        
        // Step 3: Put all user question answer pairs into circulation
        QuizzerLogger.logMessage('Step 3: Putting all user question answer pairs into circulation...');
        final List<Map<String, dynamic>> userQuestionPairs = await getAllUserQuestionAnswerPairs(sessionManager.userId!);
        QuizzerLogger.logMessage('Found ${userQuestionPairs.length} user question answer pairs');
        
        // Verify we have records to work with
        expect(userQuestionPairs.length, greaterThan(0), 
          reason: 'Should have user question answer pairs after module activation. Got: ${userQuestionPairs.length}');
        QuizzerLogger.logSuccess('Verified we have ${userQuestionPairs.length} user question answer pairs to work with');
        
        // Set all questions to in circulation
        int circulationCount = 0;
        for (final userPair in userQuestionPairs) {
          final String questionId = userPair['question_id'] as String;
          try {
            await setCirculationStatus(sessionManager.userId!, questionId, true);
            circulationCount++;
          } catch (e) {
            fail('Failed to set circulation status for question $questionId: $e');
          }
        }
        QuizzerLogger.logSuccess('Set $circulationCount questions to in circulation');
        
        // Step 4: Get eligible questions
        QuizzerLogger.logMessage('Step 4: Getting eligible questions...');
        final List<Map<String, dynamic>> eligibleQuestions = await getEligibleUserQuestionAnswerPairs(sessionManager.userId!);
        QuizzerLogger.logMessage('Retrieved ${eligibleQuestions.length} eligible questions');
        
        // Verify we have eligible questions to test
        expect(eligibleQuestions.length, greaterThan(0), 
          reason: 'Should have eligible questions after putting them in circulation. Got: ${eligibleQuestions.length}');
        QuizzerLogger.logSuccess('Verified we have ${eligibleQuestions.length} eligible questions to test');
        
        // Step 5: Verify the structure of returned records
        QuizzerLogger.logMessage('Step 5: Verifying record structure contains fields from both tables...');
        
        // Log the first record to see what we're actually working with
        if (eligibleQuestions.isNotEmpty) {
          final Map<String, dynamic> firstRecord = eligibleQuestions.first;
          QuizzerLogger.logMessage('=== FIRST ELIGIBLE QUESTION RECORD STRUCTURE ===');
          QuizzerLogger.logMessage('Record keys: ${firstRecord.keys.toList()}');
          QuizzerLogger.logMessage('Full record structure:');
          for (final entry in firstRecord.entries) {
            QuizzerLogger.logMessage('  ${entry.key}: ${entry.value}');
          }
          QuizzerLogger.logMessage('=== END FIRST RECORD STRUCTURE ===');
        } else {
          QuizzerLogger.logWarning('No eligible questions found to log');
          fail('No eligible questions found to log');
        }
        
        // Define expected fields from user_question_answer_pairs table
        final List<String> expectedUserFields = [
          'user_uuid',
          'question_id',
          'revision_streak',
          'last_revised',
          'predicted_revision_due_history',
          'next_revision_due',
          'time_between_revisions',
          'average_times_shown_per_day',
          'in_circulation',
          'total_attempts',
        ];
        
        // Define expected fields from question_answer_pairs table (excluding removed fields)
        final List<String> expectedQuestionFields = [
          'citation',
          'question_elements',
          'answer_elements',
          'module_name',
          'question_type',
          'options',
          'correct_option_index',
          'question_id',
          'correct_order',
          'index_options_that_apply',
        ];
        
        // Define sync fields that should NOT be present (these are now removed by the function)
        final List<String> syncFieldsThatShouldNotBePresent = [
          'has_been_synced',
          'edits_are_synced',
          'last_modified_timestamp',
        ];
        
        // Verify each record has the correct structure
        for (int i = 0; i < eligibleQuestions.length; i++) {
          final Map<String, dynamic> record = eligibleQuestions[i];
          final Set<String> recordKeys = record.keys.toSet();
          
          // Verify all user fields are present
          for (final String field in expectedUserFields) {
            expect(recordKeys.contains(field), isTrue, 
              reason: 'Record $i missing user field: $field');
          }
          
          // Verify all question fields are present
          for (final String field in expectedQuestionFields) {
            expect(recordKeys.contains(field), isTrue, 
              reason: 'Record $i missing question field: $field');
          }
          
          // Verify sync fields are NOT present
          for (final String field in syncFieldsThatShouldNotBePresent) {
            expect(recordKeys.contains(field), isFalse, 
              reason: 'Record $i should not contain sync field: $field');
          }
        }
        
        QuizzerLogger.logSuccess('✅ Verified all ${eligibleQuestions.length} records have correct structure');
        
        // Step 5: Log a complete record for examination
        if (eligibleQuestions.isNotEmpty) {
          final Map<String, dynamic> sampleRecord = eligibleQuestions.first;
          QuizzerLogger.logMessage('=== COMPLETE ELIGIBLE QUESTION RECORD STRUCTURE ===');
          QuizzerLogger.logMessage('Record keys: ${sampleRecord.keys.toList()}');
          QuizzerLogger.logMessage('Full record: $sampleRecord');
          QuizzerLogger.logMessage('=== END RECORD STRUCTURE ===');
        }
        
        QuizzerLogger.logSuccess('✅ Successfully verified and logged eligible question record structure');
        
      } catch (e) {
        QuizzerLogger.logError('Question record structure test failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
