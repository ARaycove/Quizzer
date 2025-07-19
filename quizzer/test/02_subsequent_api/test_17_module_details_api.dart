import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_module_activation_status_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/custom_queries.dart';
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
  
  // Global test results tracking
  final Map<String, dynamic> testResults = {};
  
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
  });
  
  group('SessionManager Module Details API Tests', () {
    test('Test 1: Login initialization and verify state', () async {
      QuizzerLogger.logMessage('=== Test 1: Login initialization and verify state ===');
      
      // Step 1: Login initialization
      QuizzerLogger.logMessage('Step 1: Calling loginInitialization with testRun=true...');
      final loginResult = await loginInitialization(
        email: testEmail, 
        password: testPassword, 
        supabase: sessionManager.supabase, 
        storage: sessionManager.getBox(testAccessPassword),
        testRun: true, // This bypasses sync workers
      );
      expect(loginResult['success'], isTrue, reason: 'Login initialization should succeed');
      QuizzerLogger.logSuccess('Login initialization completed successfully');
      
      // Step 2: Verify that user is logged in and ready
      expect(sessionManager.userId, isNotNull, reason: 'User should be logged in');
      QuizzerLogger.logSuccess('User is logged in and ready for testing');
      
      QuizzerLogger.logSuccess('=== Test 1 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 2: Get module data and verify structure', () async {
      QuizzerLogger.logMessage('=== Test 2: Get module data and verify structure ===');
      
      // Step 1: Get module data from SessionManager with performance measurement
      QuizzerLogger.logMessage('Step 1: Getting module data from SessionManager...');
      final stopwatch = Stopwatch()..start();
      final Map<String, Map<String, dynamic>> moduleData = await sessionManager.getModuleData();
      stopwatch.stop();
      
      final int elapsedMilliseconds = stopwatch.elapsedMilliseconds;
      QuizzerLogger.logMessage('getModuleData API call took ${elapsedMilliseconds}ms');
      
      // Store results for final report
      testResults['getModuleData_performance_ms'] = elapsedMilliseconds;
      testResults['getModuleData_modules_count'] = moduleData.length;
      
      // Verify performance: should be less than 1 second
      expect(elapsedMilliseconds, lessThan(1000), 
        reason: 'getModuleData API call should complete in less than 1 second. Actual time: ${elapsedMilliseconds}ms');
      
      expect(moduleData, isNotNull, reason: 'Module data should not be null');
      expect(moduleData, isNotEmpty, reason: 'Module data should not be empty');
      QuizzerLogger.logSuccess('Retrieved ${moduleData.length} modules from SessionManager');
      
      // Step 2: Get all modules from database for comparison
      QuizzerLogger.logMessage('Step 2: Getting all modules from database for comparison...');
      final List<Map<String, dynamic>> allModules = await getAllModules();
      expect(allModules, isNotEmpty, reason: 'Should have modules in database');
      QuizzerLogger.logSuccess('Found ${allModules.length} modules in database');
      
      // Step 3: Get user module activation status for comparison
      QuizzerLogger.logMessage('Step 3: Getting user module activation status for comparison...');
      final Map<String, bool> activationStatus = await getModuleActivationStatus(sessionManager.userId!);
      QuizzerLogger.logSuccess('Retrieved activation status for ${activationStatus.length} modules');
      
      // Step 4: Single iteration to verify all requirements
      QuizzerLogger.logMessage('Step 4: Verifying module data structure and content...');
      
      final Set<String> verifiedModules = {};
      
      for (final entry in moduleData.entries) {
        final String moduleName = entry.key;
        final Map<String, dynamic> moduleInfo = entry.value;
        
        // Track that we've verified this module
        verifiedModules.add(moduleName);
        
        // 0. Verify module_name field exists and matches the key
        expect(moduleInfo.containsKey('module_name'), isTrue, 
          reason: 'Module $moduleName should have module_name field');
        expect(moduleInfo['module_name'], equals(moduleName), 
          reason: 'Module $moduleName module_name field should match the key');
        
        // 1. Verify questions field is a List
        expect(moduleInfo.containsKey('questions'), isTrue, 
          reason: 'Module $moduleName should have questions field');
        expect(moduleInfo['questions'], isA<List>(), 
          reason: 'Module $moduleName questions field should be a List');
        // --- NEW: Validate question fields are Dart types ---
        for (final q in moduleInfo['questions'] as List) {
          if (q == null) continue;
          expect(q['question_elements'], anyOf(isNull, isA<List>()), reason: 'question_elements should be a List or null');
          expect(q['answer_elements'], anyOf(isNull, isA<List>()), reason: 'answer_elements should be a List or null');
          expect(q['options'], anyOf(isNull, isA<List>()), reason: 'options should be a List or null');
        }
        
        // 2. Verify is_active field matches database activation status
        expect(moduleInfo.containsKey('is_active'), isTrue, 
          reason: 'Module $moduleName should have is_active field');
        final bool isActiveInData = moduleInfo['is_active'] as bool;
        final bool isActiveInDB = activationStatus[moduleName] ?? false;
        expect(isActiveInData, equals(isActiveInDB), 
          reason: 'Module $moduleName activation status should match database');
        
        // 3. Verify other required fields exist
        expect(moduleInfo.containsKey('description'), isTrue, 
          reason: 'Module $moduleName should have description field');
        expect(moduleInfo.containsKey('total_questions'), isTrue, 
          reason: 'Module $moduleName should have total_questions field');
        
        // 4. Verify total_questions matches actual number of questions
        final int totalQuestions = moduleInfo['total_questions'] as int;
        final int actualQuestionCount = (moduleInfo['questions'] as List).length;
        expect(totalQuestions, equals(actualQuestionCount), 
          reason: 'Module $moduleName total_questions ($totalQuestions) should match actual questions count ($actualQuestionCount)');
        
        // 5. Verify against direct database query for this module
        final List<Map<String, dynamic>> directQuestions = await getQuestionRecordsForModule(moduleName);
        final int directQuestionCount = directQuestions.length;
        expect(actualQuestionCount, equals(directQuestionCount), 
          reason: 'Module $moduleName questions count from optimized query ($actualQuestionCount) should match direct database query ($directQuestionCount)');
        
        QuizzerLogger.logMessage('Verified module: $moduleName (active: $isActiveInData, questions: $actualQuestionCount, direct: $directQuestionCount)');
      }
      
      // 5. Verify all database modules are present in returned data
      QuizzerLogger.logMessage('Step 5: Verifying all database modules are present in returned data...');
      for (final module in allModules) {
        final String moduleName = module['module_name'] as String;
        expect(verifiedModules.contains(moduleName), isTrue, 
          reason: 'Module $moduleName from database should be present in returned data');
      }
      
      QuizzerLogger.logSuccess('All ${verifiedModules.length} modules verified successfully');
      QuizzerLogger.logSuccess('=== Test 2 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 3: Update module description API', () async {
      QuizzerLogger.logMessage('=== Test 3: Update module description API ===');
      
      // Step 1: Get all modules from database
      QuizzerLogger.logMessage('Step 1: Getting all modules from database...');
      final List<Map<String, dynamic>> allModules = await getAllModules();
      expect(allModules, isNotEmpty, reason: 'Should have modules in database');
      QuizzerLogger.logSuccess('Found ${allModules.length} modules to test');
      
      // Step 2: Test description update for each module
      QuizzerLogger.logMessage('Step 2: Testing description update for each module...');
      
      for (final module in allModules) {
        final String moduleName = module['module_name'] as String;
        QuizzerLogger.logMessage('Testing module: $moduleName');
        
        // Get original description
        final String originalDescription = module['description'] as String? ?? '';
        QuizzerLogger.logMessage('Original description: "$originalDescription"');
        
        // Test description 1: Change to test string
        final String testDescription1 = 'TEST_DESCRIPTION_${DateTime.now().millisecondsSinceEpoch}';
        QuizzerLogger.logMessage('Updating to test description: "$testDescription1"');
        
        final bool updateResult1 = await sessionManager.updateModuleDescription(moduleName, testDescription1);
        expect(updateResult1, isTrue, reason: 'Failed to update description for module: $moduleName');
        
        // Verify the change
        final List<Map<String, dynamic>> moduleAfterUpdate1 = await getAllModules();
        final Map<String, dynamic> updatedModule1 = moduleAfterUpdate1.firstWhere(
          (m) => m['module_name'] == moduleName,
          orElse: () => <String, dynamic>{},
        );
        expect(updatedModule1, isNotEmpty, reason: 'Module $moduleName should be found after update');
        expect(updatedModule1['description'], equals(testDescription1), 
          reason: 'Module $moduleName description should be updated to test string');
        
        // Test description 2: Change back to original
        QuizzerLogger.logMessage('Reverting to original description: "$originalDescription"');
        
        final bool updateResult2 = await sessionManager.updateModuleDescription(moduleName, originalDescription);
        expect(updateResult2, isTrue, reason: 'Failed to revert description for module: $moduleName');
        
        // Verify the reversion
        final List<Map<String, dynamic>> moduleAfterUpdate2 = await getAllModules();
        final Map<String, dynamic> updatedModule2 = moduleAfterUpdate2.firstWhere(
          (m) => m['module_name'] == moduleName,
          orElse: () => <String, dynamic>{},
        );
        expect(updatedModule2, isNotEmpty, reason: 'Module $moduleName should be found after reversion');
        expect(updatedModule2['description'], equals(originalDescription), 
          reason: 'Module $moduleName description should be reverted to original');
        
        QuizzerLogger.logSuccess('Module $moduleName description update test completed successfully');
      }
      
      QuizzerLogger.logSuccess('All ${allModules.length} modules description update tests completed successfully');
      
      // Store results for final report
      testResults['updateDescription_modules_tested'] = allModules.length;
      testResults['updateDescription_test_passed'] = true;
      
      QuizzerLogger.logSuccess('=== Test 3 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 5)));
    
    test('Test 4: Individual module data query and structure verification', () async {
      QuizzerLogger.logMessage('=== Test 4: Individual module data query and structure verification ===');
      
      // Step 1: Get all modules to find one to test with
      QuizzerLogger.logMessage('Step 1: Getting all modules to select one for testing...');
      final List<Map<String, dynamic>> allModules = await getAllModules();
      expect(allModules, isNotEmpty, reason: 'Should have modules in database');
      
      // Select the first module for testing
      final String testModuleName = allModules.first['module_name'] as String;
      QuizzerLogger.logMessage('Selected test module: $testModuleName');
      
      // Step 2: Get individual module data using the new query
      QuizzerLogger.logMessage('Step 2: Getting individual module data...');
      final Map<String, dynamic>? individualModuleData = await getIndividualModuleData(sessionManager.userId!, testModuleName);
      
      expect(individualModuleData, isNotNull, reason: 'Individual module data should not be null');
      expect(individualModuleData!['module_name'], equals(testModuleName), 
        reason: 'Individual module data should have the correct module name');
      
      QuizzerLogger.logSuccess('Retrieved individual module data for: $testModuleName');
      
      // Step 3: Get the same module from the getAll function for comparison
      QuizzerLogger.logMessage('Step 3: Getting the same module from getAll function for comparison...');
      final Map<String, Map<String, dynamic>> allModulesData = await sessionManager.getModuleData();
      final Map<String, dynamic>? getAllModuleData = allModulesData[testModuleName];
      
      expect(getAllModuleData, isNotNull, reason: 'Module should be found in getAll data');
      
      QuizzerLogger.logSuccess('Retrieved module data from getAll function for comparison');
      
      // Step 4: Verify both data structures have the same fields
      QuizzerLogger.logMessage('Step 4: Verifying data structure consistency...');
      
      final Set<String> individualKeys = individualModuleData.keys.toSet();
      final Set<String> getAllKeys = getAllModuleData!.keys.toSet();
      
      // Log the keys for debugging
      QuizzerLogger.logMessage('Individual module keys: ${individualKeys.toList()}');
      QuizzerLogger.logMessage('GetAll module keys: ${getAllKeys.toList()}');
      
      // Verify all required fields are present in both
      final List<String> requiredFields = [
        'module_name',
        'description',
        'primary_subject',
        'subjects',
        'related_concepts',
        'creation_date',
        'creator_id',
        'is_active',
        'total_questions',
        'questions',
      ];
      
      for (final field in requiredFields) {
        expect(individualKeys.contains(field), isTrue, 
          reason: 'Individual module data should contain field: $field');
        expect(getAllKeys.contains(field), isTrue, 
          reason: 'GetAll module data should contain field: $field');
      }
      
      QuizzerLogger.logSuccess('Verified all required fields are present in both data structures');
      
      // Step 5: Verify field values match between individual and getAll
      QuizzerLogger.logMessage('Step 5: Verifying field values match between individual and getAll...');
      
      for (final field in requiredFields) {
        final individualValue = individualModuleData[field];
        final getAllValue = getAllModuleData[field];
        
        expect(individualValue, equals(getAllValue), 
          reason: 'Field $field should have the same value in both data structures');
      }
      
      QuizzerLogger.logSuccess('Verified all field values match between individual and getAll data');
      
      // Step 6: Verify questions structure and count
      QuizzerLogger.logMessage('Step 6: Verifying questions structure and count...');
      final List<Map<String, dynamic>> individualQuestions = List<Map<String, dynamic>>.from(individualModuleData['questions'] as List);
      final List<Map<String, dynamic>> getAllQuestions = List<Map<String, dynamic>>.from(getAllModuleData['questions'] as List);
      // --- NEW: Validate question fields are Dart types for both sources ---
      for (final q in individualQuestions) {
        expect(q['question_elements'], anyOf(isNull, isA<List>()), reason: 'individualModuleData: question_elements should be a List or null');
        expect(q['answer_elements'], anyOf(isNull, isA<List>()), reason: 'individualModuleData: answer_elements should be a List or null');
        expect(q['options'], anyOf(isNull, isA<List>()), reason: 'individualModuleData: options should be a List or null');
      }
      for (final q in getAllQuestions) {
        expect(q['question_elements'], anyOf(isNull, isA<List>()), reason: 'getAllModuleData: question_elements should be a List or null');
        expect(q['answer_elements'], anyOf(isNull, isA<List>()), reason: 'getAllModuleData: answer_elements should be a List or null');
        expect(q['options'], anyOf(isNull, isA<List>()), reason: 'getAllModuleData: options should be a List or null');
      }
      
      expect(individualQuestions.length, equals(getAllQuestions.length), 
        reason: 'Question count should match between individual and getAll data');
      
      final int totalQuestions = individualModuleData['total_questions'] as int;
      expect(individualQuestions.length, equals(totalQuestions), 
        reason: 'Question count should match total_questions field');
      
      QuizzerLogger.logSuccess('Verified questions structure and count consistency');
      
      // Step 7: Performance comparison
      QuizzerLogger.logMessage('Step 7: Performance comparison...');
      
      final stopwatch = Stopwatch()..start();
      await getIndividualModuleData(sessionManager.userId!, testModuleName);
      stopwatch.stop();
      
      final int individualQueryTime = stopwatch.elapsedMilliseconds;
      QuizzerLogger.logMessage('Individual module query took ${individualQueryTime}ms');
      
      // Store results for final report
      testResults['individual_module_query_time_ms'] = individualQueryTime;
      testResults['individual_module_test_passed'] = true;
      
      QuizzerLogger.logSuccess('=== Test 4 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 5: Final Performance Report Card', () async {
      QuizzerLogger.logMessage('=== Test 5: Final Performance Report Card ===');
      
      // Run the API call again to get final performance metrics
      final stopwatch = Stopwatch()..start();
      final Map<String, Map<String, dynamic>> moduleData = await sessionManager.getModuleData();
      stopwatch.stop();
      
      final int elapsedMilliseconds = stopwatch.elapsedMilliseconds;
      final int moduleCount = moduleData.length;
      int totalQuestions = 0;
      
      for (final module in moduleData.values) {
        totalQuestions += (module['questions'] as List).length;
      }
      
      // Store final performance metrics
      testResults['final_performance_ms'] = elapsedMilliseconds;
      testResults['final_modules_count'] = moduleCount;
      testResults['final_total_questions'] = totalQuestions;
      
      QuizzerLogger.printHeader('=== MODULE DETAILS API COMPREHENSIVE REPORT ===');
      QuizzerLogger.printHeader('=== PERFORMANCE METRICS ===');
      QuizzerLogger.logMessage('Initial API Call Duration: ${testResults['getModuleData_performance_ms']}ms');
      QuizzerLogger.logMessage('Final API Call Duration: ${testResults['final_performance_ms']}ms');
      QuizzerLogger.logMessage('Performance Target: < 1000ms');
      QuizzerLogger.logMessage('Performance Status: ${elapsedMilliseconds < 1000 ? 'PASS' : 'FAIL'}');
      QuizzerLogger.logMessage('');
      QuizzerLogger.printHeader('=== DATA METRICS ===');
      QuizzerLogger.logMessage('Modules Retrieved: $moduleCount');
      QuizzerLogger.logMessage('Total Questions: $totalQuestions');
      QuizzerLogger.logMessage('Average Questions per Module: ${moduleCount > 0 ? (totalQuestions / moduleCount).toStringAsFixed(1) : 0}');
      QuizzerLogger.logMessage('Questions per Millisecond: ${elapsedMilliseconds > 0 ? (totalQuestions / elapsedMilliseconds).toStringAsFixed(2) : 0}');
      QuizzerLogger.logMessage('');
      QuizzerLogger.printHeader('=== FUNCTIONALITY TESTS ===');
      QuizzerLogger.logMessage('Description Update Tests: ${testResults['updateDescription_test_passed'] == true ? 'PASS' : 'FAIL'}');
      QuizzerLogger.logMessage('Modules Tested for Description Updates: ${testResults['updateDescription_modules_tested']}');
      QuizzerLogger.printHeader('=== END COMPREHENSIVE REPORT ===');
      
      QuizzerLogger.logSuccess('=== Test 5 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
