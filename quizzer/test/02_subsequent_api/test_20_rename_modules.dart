import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';
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
  
  // Global instances used across tests
  late final SessionManager sessionManager;
  
  // Track selected modules across tests
  List<Map<String, dynamic>>? selectedModules;
  
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
    
    // Perform full login initialization (excluding sync workers for testing)
    final loginResult = await loginInitialization(
      email: testEmail, 
      password: testPassword, 
      supabase: sessionManager.supabase, 
      storage: sessionManager.getBox(testAccessPassword),
      testRun: true, // This bypasses sync workers for faster testing
    );
    
    expect(loginResult['success'], isTrue, reason: 'Login initialization should succeed');
    QuizzerLogger.logSuccess('Full login initialization completed successfully');
  });
  
  group('Module Rename Tests', () {
    test('Test 1: Verify test setup and get available modules', () async {
      QuizzerLogger.logMessage('=== Test 1: Verify test setup and get available modules ===');
      
      try {
        // Step 1: Get all available modules
        QuizzerLogger.logMessage('Step 1: Getting all available modules');
        final List<Map<String, dynamic>> allModules = await getAllModules();
        expect(allModules.length, greaterThan(0), reason: 'Should have at least one module to test with');
        QuizzerLogger.logSuccess('Found ${allModules.length} total modules');
        
        // Step 2: Verify we can access module data
        for (final module in allModules) {
          final String moduleName = module['module_name'] as String;
          final Map<String, dynamic>? moduleData = await getModule(moduleName);
          expect(moduleData, isNotNull, reason: 'Should be able to get module data for $moduleName');
          
          // Verify module has questions
          final List<Map<String, dynamic>> questions = await getQuestionRecordsForModule(moduleName);
          expect(questions.length, greaterThan(0), reason: 'Module $moduleName should have questions');
        }
        
        QuizzerLogger.logSuccess('✅ Test setup verified - all modules accessible with questions');
        
      } catch (e) {
        QuizzerLogger.logError('Test 1 failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
    
    test('Test 2: Select random modules for testing', () async {
      QuizzerLogger.logMessage('=== Test 2: Select random modules for testing ===');
      
      try {
        // Step 1: Get all available modules
        final List<Map<String, dynamic>> allModules = await getAllModules();
        final random = Random();
        final int modulesToTest = allModules.length < 5 ? allModules.length : 5;
        final List<Map<String, dynamic>> modulesToSelect = [];
        
        // Create a copy of the list to avoid modifying the original
        final List<Map<String, dynamic>> availableModules = List.from(allModules);
        
        for (int i = 0; i < modulesToTest; i++) {
          if (availableModules.isEmpty) break;
          
          final int randomIndex = random.nextInt(availableModules.length);
          final selectedModule = availableModules.removeAt(randomIndex);
          modulesToSelect.add(selectedModule);
        }
        
        expect(modulesToSelect.length, greaterThan(0), reason: 'Should have selected at least one module');
        QuizzerLogger.logSuccess('Selected ${modulesToSelect.length} modules for testing');
        
        // Log selected modules for debugging
        for (int i = 0; i < modulesToSelect.length; i++) {
          final String moduleName = modulesToSelect[i]['module_name'] as String;
          final List<Map<String, dynamic>> questions = await getQuestionRecordsForModule(moduleName);
          QuizzerLogger.logMessage('Module $i: $moduleName (${questions.length} questions)');
        }
        
        // Store selected modules in global variable for use in subsequent tests
        selectedModules = modulesToSelect;
        QuizzerLogger.logMessage('Stored ${selectedModules!.length} modules in global variable for subsequent tests');
        
        QuizzerLogger.logSuccess('✅ Module selection completed');
        
      } catch (e) {
        QuizzerLogger.logError('Test 2 failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
    
    test('Test 3: Test module rename API with revert validation', () async {
      QuizzerLogger.logMessage('=== Test 3: Test module rename API with revert validation ===');
      
      try {
        // Step 1: Use the modules selected in Test 2
        expect(selectedModules, isNotNull, reason: 'Modules should have been selected in Test 2');
        expect(selectedModules!.length, greaterThan(0), reason: 'Should have at least one selected module');
        
        // Store original module names and their questions for later validation
        final Map<String, List<Map<String, dynamic>>> originalModuleQuestions = {};
        final List<String> originalModuleNames = [];
        
        for (final module in selectedModules!) {
          final String moduleName = module['module_name'] as String;
          originalModuleNames.add(moduleName);
          
          // Get questions for this module before any changes
          final List<Map<String, dynamic>> questions = await getQuestionRecordsForModule(moduleName);
          originalModuleQuestions[moduleName] = questions;
          
          QuizzerLogger.logMessage('Stored original data for module: $moduleName (${questions.length} questions)');
        }
        
        QuizzerLogger.logSuccess('Stored original data for ${originalModuleNames.length} modules');
        
        // Step 2: For each module, call rename module API
        final Map<String, String> renameMappings = {};
        
        for (int i = 0; i < selectedModules!.length; i++) {
          final String oldModuleName = selectedModules![i]['module_name'] as String;
          final String newModuleName = 'test_rename_api_${testIteration}_${DateTime.now().millisecondsSinceEpoch}_$i';
          
          QuizzerLogger.logMessage('Renaming module $i: "$oldModuleName" -> "$newModuleName"');
          
          // Call the rename API
          final bool renameResult = await sessionManager.renameModule(oldModuleName, newModuleName);
          expect(renameResult, isTrue, reason: 'Module rename should succeed for $oldModuleName');
          
          renameMappings[oldModuleName] = newModuleName;
          QuizzerLogger.logSuccess('Successfully renamed module $i');
        }
        
        // Step 3: For each iteration, manually check that no questions exist with the old module names
        QuizzerLogger.logMessage('Step 3: Verifying no questions exist with old module names...');
        
        for (final String oldModuleName in originalModuleNames) {
          final List<Map<String, dynamic>> questionsWithOldName = await getQuestionRecordsForModule(oldModuleName);
          expect(questionsWithOldName.length, equals(0), 
            reason: 'No questions should exist with old module name: $oldModuleName');
          
          QuizzerLogger.logSuccess('Verified no questions exist with old module name: $oldModuleName');
        }
        
        // Step 4: Verify questions now exist with new module names
        QuizzerLogger.logMessage('Step 4: Verifying questions exist with new module names...');
        
        for (final entry in renameMappings.entries) {
          final String oldModuleName = entry.key;
          final String newModuleName = entry.value;
          final List<Map<String, dynamic>> originalQuestions = originalModuleQuestions[oldModuleName]!;
          
          final List<Map<String, dynamic>> questionsWithNewName = await getQuestionRecordsForModule(newModuleName);
          expect(questionsWithNewName.length, equals(originalQuestions.length),
            reason: 'Should have same number of questions with new module name: $newModuleName');
          
          // Verify each question has the new module name
          for (final question in questionsWithNewName) {
            final String questionModuleName = question['module_name'] as String;
            expect(questionModuleName, equals(newModuleName),
              reason: 'Question should have new module name: $newModuleName');
          }
          
          QuizzerLogger.logSuccess('Verified ${questionsWithNewName.length} questions moved to new module: $newModuleName');
        }
        
        // Step 5: Revert the now changed modules back to original names
        QuizzerLogger.logMessage('Step 5: Reverting modules back to original names...');
        
        for (final entry in renameMappings.entries) {
          final String newModuleName = entry.value;
          final String originalModuleName = entry.key;
          
          QuizzerLogger.logMessage('Reverting: "$newModuleName" -> "$originalModuleName"');
          
          final bool revertResult = await sessionManager.renameModule(newModuleName, originalModuleName);
          expect(revertResult, isTrue, reason: 'Module revert should succeed for $newModuleName');
          
          QuizzerLogger.logSuccess('Successfully reverted module: $newModuleName -> $originalModuleName');
        }
        
        // Step 6: Validate they are matching the original again
        QuizzerLogger.logMessage('Step 6: Validating modules match original state...');
        
        for (final String originalModuleName in originalModuleNames) {
          final List<Map<String, dynamic>> questionsAfterRevert = await getQuestionRecordsForModule(originalModuleName);
          final List<Map<String, dynamic>> originalQuestions = originalModuleQuestions[originalModuleName]!;
          
          expect(questionsAfterRevert.length, equals(originalQuestions.length),
            reason: 'Should have same number of questions after revert for: $originalModuleName');
          
          // Verify each question has the original module name
          for (final question in questionsAfterRevert) {
            final String questionModuleName = question['module_name'] as String;
            expect(questionModuleName, equals(originalModuleName),
              reason: 'Question should have original module name: $originalModuleName');
          }
          
          QuizzerLogger.logSuccess('Verified module $originalModuleName matches original state (${questionsAfterRevert.length} questions)');
        }
        
        // Step 7: Verify no questions exist with the temporary new names
        QuizzerLogger.logMessage('Step 7: Verifying no questions exist with temporary new names...');
        
        for (final String newModuleName in renameMappings.values) {
          final List<Map<String, dynamic>> questionsWithTempName = await getQuestionRecordsForModule(newModuleName);
          expect(questionsWithTempName.length, equals(0),
            reason: 'No questions should exist with temporary module name: $newModuleName');
          
          QuizzerLogger.logSuccess('Verified no questions exist with temporary name: $newModuleName');
        }
        
        QuizzerLogger.logSuccess('✅ Module rename API test completed successfully with full revert validation');
        
      } catch (e) {
        QuizzerLogger.logError('Test 3 failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
