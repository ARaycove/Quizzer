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
  
  // Global variable to store selected modules and their question counts
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
  
  group('Module Merge Tests', () {
    test('Test 1: Select 3 modules at random and collect question counts', () async {
      QuizzerLogger.logMessage('=== Test 1: Select 3 modules at random and collect question counts ===');
      
      try {
        // Step 1: Get all available modules
        QuizzerLogger.logMessage('Step 1: Getting all available modules');
        final List<Map<String, dynamic>> allModules = await getAllModules();
        expect(allModules.length, greaterThanOrEqualTo(3), reason: 'Should have at least 3 modules to test with');
        QuizzerLogger.logSuccess('Found ${allModules.length} total modules');
        
        // Step 2: Select 3 random modules
        QuizzerLogger.logMessage('Step 2: Selecting 3 random modules');
        final random = Random();
        final List<Map<String, dynamic>> modulesToSelect = [];
        
        // Create a copy of the list to avoid modifying the original
        final List<Map<String, dynamic>> availableModules = List.from(allModules);
        
        for (int i = 0; i < 3; i++) {
          if (availableModules.isEmpty) break;
          
          final int randomIndex = random.nextInt(availableModules.length);
          final selectedModule = availableModules.removeAt(randomIndex);
          modulesToSelect.add(selectedModule);
        }
        
        expect(modulesToSelect.length, equals(3), reason: 'Should have selected exactly 3 modules');
        QuizzerLogger.logSuccess('Selected ${modulesToSelect.length} modules for testing');
        
        // Step 3: Collect question counts for each module
        QuizzerLogger.logMessage('Step 3: Collecting question counts for each module');
        final List<Map<String, dynamic>> modulesWithQuestionCounts = [];
        
        for (int i = 0; i < modulesToSelect.length; i++) {
          final String moduleName = modulesToSelect[i]['module_name'] as String;
          final List<Map<String, dynamic>> questions = await getQuestionRecordsForModule(moduleName);
          final int questionCount = questions.length;
          
          final Map<String, dynamic> moduleWithCount = {
            'module_name': moduleName,
            'question_count': questionCount,
            'original_index': i,
          };
          
          modulesWithQuestionCounts.add(moduleWithCount);
          QuizzerLogger.logMessage('Module $i: $moduleName (${questionCount} questions)');
        }
        
        // Step 4: Store in global variable for use by subsequent tests
        selectedModules = modulesWithQuestionCounts;
        QuizzerLogger.logMessage('Stored ${selectedModules!.length} modules with question counts in global variable');
        
        QuizzerLogger.logSuccess('✅ Module selection and question count collection completed');
        
      } catch (e) {
        QuizzerLogger.logError('Test 1 failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
    
    test('Test 2: Merge first two modules and verify results', () async {
      QuizzerLogger.logMessage('=== Test 2: Merge first two modules and verify results ===');
      
      try {
        // Step 1: Use the modules selected in Test 1
        expect(selectedModules, isNotNull, reason: 'Modules should have been selected in Test 1');
        expect(selectedModules!.length, equals(3), reason: 'Should have exactly 3 selected modules');
        
        final String sourceModuleName = selectedModules![0]['module_name'] as String;
        final String targetModuleName = selectedModules![1]['module_name'] as String;
        final int sourceQuestionCount = selectedModules![0]['question_count'] as int;
        final int targetQuestionCount = selectedModules![1]['question_count'] as int;
        final int expectedTotalQuestions = sourceQuestionCount + targetQuestionCount;
        
        QuizzerLogger.logMessage('Step 1: Merging modules');
        QuizzerLogger.logValue('  Source module: $sourceModuleName (${sourceQuestionCount} questions)');
        QuizzerLogger.logValue('  Target module: $targetModuleName (${targetQuestionCount} questions)');
        QuizzerLogger.logValue('  Expected total after merge: $expectedTotalQuestions questions');
        
        // Step 2: Perform the merge
        QuizzerLogger.logMessage('Step 2: Performing merge operation');
        final bool mergeResult = await sessionManager.mergeModules(sourceModuleName, targetModuleName);
        expect(mergeResult, isTrue, reason: 'Module merge should succeed');
        QuizzerLogger.logSuccess('Merge operation completed successfully');
        
        // Step 3: Verify source module has 0 questions
        QuizzerLogger.logMessage('Step 3: Verifying source module has 0 questions');
        final List<Map<String, dynamic>> sourceQuestionsAfterMerge = await getQuestionRecordsForModule(sourceModuleName);
        expect(sourceQuestionsAfterMerge.length, equals(0), 
          reason: 'Source module should have 0 questions after merge');
        QuizzerLogger.logSuccess('Verified source module has 0 questions');
        
        // Step 4: Verify target module has the sum of both question counts
        QuizzerLogger.logMessage('Step 4: Verifying target module has combined question count');
        final List<Map<String, dynamic>> targetQuestionsAfterMerge = await getQuestionRecordsForModule(targetModuleName);
        expect(targetQuestionsAfterMerge.length, equals(expectedTotalQuestions),
          reason: 'Target module should have $expectedTotalQuestions questions after merge. Got: ${targetQuestionsAfterMerge.length}');
        QuizzerLogger.logSuccess('Verified target module has $expectedTotalQuestions questions');
        
        // Step 5: Update the global variable to reflect the merge
        // The target module now contains all questions from both modules
        selectedModules![1]['question_count'] = expectedTotalQuestions;
        // The source module now has 0 questions
        selectedModules![0]['question_count'] = 0;
        
        QuizzerLogger.logSuccess('✅ First merge test completed successfully');
        
      } catch (e) {
        QuizzerLogger.logError('Test 2 failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 3: Merge target module with remaining module and verify final results', () async {
      QuizzerLogger.logMessage('=== Test 3: Merge target module with remaining module and verify final results ===');
      
      try {
        // Step 1: Use the updated modules from Test 2
        expect(selectedModules, isNotNull, reason: 'Modules should have been updated in Test 2');
        expect(selectedModules!.length, equals(3), reason: 'Should have exactly 3 modules');
        
        // After Test 2, module 1 (index 1) is the target module with all questions
        // Module 2 (index 2) is the remaining module
        final String sourceModuleName = selectedModules![1]['module_name'] as String; // Previous target module
        final String targetModuleName = selectedModules![2]['module_name'] as String; // Remaining module
        final int sourceQuestionCount = selectedModules![1]['question_count'] as int; // Combined count from Test 2
        final int targetQuestionCount = selectedModules![2]['question_count'] as int;
        final int expectedFinalTotal = sourceQuestionCount + targetQuestionCount;
        
        QuizzerLogger.logMessage('Step 1: Merging target module with remaining module');
        QuizzerLogger.logValue('  Source module: $sourceModuleName (${sourceQuestionCount} questions)');
        QuizzerLogger.logValue('  Target module: $targetModuleName (${targetQuestionCount} questions)');
        QuizzerLogger.logValue('  Expected final total: $expectedFinalTotal questions');
        
        // Step 2: Perform the merge
        QuizzerLogger.logMessage('Step 2: Performing second merge operation');
        final bool mergeResult = await sessionManager.mergeModules(sourceModuleName, targetModuleName);
        expect(mergeResult, isTrue, reason: 'Second module merge should succeed');
        QuizzerLogger.logSuccess('Second merge operation completed successfully');
        
        // Step 3: Verify the source module (previous target) now has 0 questions
        QuizzerLogger.logMessage('Step 3: Verifying source module (previous target) has 0 questions');
        final List<Map<String, dynamic>> sourceQuestionsAfterMerge = await getQuestionRecordsForModule(sourceModuleName);
        expect(sourceQuestionsAfterMerge.length, equals(0),
          reason: 'Source module (previous target) should have 0 questions after merge');
        QuizzerLogger.logSuccess('Verified source module has 0 questions');
        
        // Step 4: Verify the final target module has all questions
        QuizzerLogger.logMessage('Step 4: Verifying final target module has all questions');
        final List<Map<String, dynamic>> targetQuestionsAfterMerge = await getQuestionRecordsForModule(targetModuleName);
        expect(targetQuestionsAfterMerge.length, equals(expectedFinalTotal),
          reason: 'Final target module should have $expectedFinalTotal questions. Got: ${targetQuestionsAfterMerge.length}');
        QuizzerLogger.logSuccess('Verified final target module has $expectedFinalTotal questions');
        
        // Step 5: Verify the original source module (from Test 2) still has 0 questions
        QuizzerLogger.logMessage('Step 5: Verifying original source module still has 0 questions');
        final String originalSourceModuleName = selectedModules![0]['module_name'] as String;
        final List<Map<String, dynamic>> originalSourceQuestions = await getQuestionRecordsForModule(originalSourceModuleName);
        expect(originalSourceQuestions.length, equals(0),
          reason: 'Original source module should still have 0 questions');
        QuizzerLogger.logSuccess('Verified original source module still has 0 questions');
        
        // Step 6: Calculate and verify the total questions across all modules
        QuizzerLogger.logMessage('Step 6: Verifying total question count across all modules');
        final int originalTotalQuestions = (selectedModules![0]['question_count'] as int) + 
                                        (selectedModules![1]['question_count'] as int) + 
                                        (selectedModules![2]['question_count'] as int);
        
        final List<Map<String, dynamic>> allQuestions = await getQuestionRecordsForModule(targetModuleName);
        expect(allQuestions.length, equals(originalTotalQuestions),
          reason: 'Final module should contain all original questions. Expected: $originalTotalQuestions, Got: ${allQuestions.length}');
        QuizzerLogger.logSuccess('Verified final module contains all original questions');
        
        QuizzerLogger.logSuccess('✅ Second merge test completed successfully');
        QuizzerLogger.logValue('  Final module: $targetModuleName (${allQuestions.length} questions)');
        QuizzerLogger.logValue('  All other modules: 0 questions each');
        
      } catch (e) {
        QuizzerLogger.logError('Test 3 failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
