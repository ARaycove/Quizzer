import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/12_answer_validator/answer_validation/text_analysis_tools.dart';
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
  
  // Track created test modules for cleanup
  final List<String> createdTestModules = [];
  
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
      noQueueServer: true
    );
    
    expect(loginResult['success'], isTrue, reason: 'Login initialization should succeed');
    QuizzerLogger.logSuccess('Full login initialization completed successfully');
  });
  
  tearDownAll(() async {
    QuizzerLogger.logMessage('Cleaning up test modules created during tests...');
    if (createdTestModules.isNotEmpty) {
      await cleanupTestModules(createdTestModules);
      QuizzerLogger.logSuccess('Cleaned up ${createdTestModules.length} test modules');
    }
  });
  
  group('Module Rename Tests', () {
    test('Test 1: Test module rename API with custom module setup', () async {
      QuizzerLogger.logMessage('=== Test 1: Test module rename API with custom module setup ===');
      
      try {
        // Step 1: Clear database tables to ensure clean state
        QuizzerLogger.logMessage('Step 1: Clearing database tables for clean state');
        await deleteAllRecordsFromTable('question_answer_pairs');
        await deleteAllRecordsFromTable('modules');
        QuizzerLogger.logSuccess('Database tables cleared');
        
        // Step 2: Create a custom module with questions using helper function
        QuizzerLogger.logMessage('Step 2: Creating custom module with questions');
        final String customModuleName = 'test_rename_module_${testIteration}_${DateTime.now().millisecondsSinceEpoch}';
        final String normalizedModuleName = await normalizeString(customModuleName);
        createdTestModules.add(normalizedModuleName);
        
        // Generate 50 questions for the custom module
        final List<Map<String, dynamic>> questionData = generateQuestionInputData(
          questionType: 'multiple_choice',
          numberOfQuestions: 50,
          numberOfModules: 1,
          customModuleName: normalizedModuleName,
        );
        
        // Add questions to database using API
        int questionsAdded = 0;
        for (final data in questionData) {
          final Map<String, dynamic> result = await sessionManager.addNewQuestion(
            questionElements: data['questionElements'] as List<Map<String, dynamic>>,
            answerElements: data['answerElements'] as List<Map<String, dynamic>>,
            moduleName: data['moduleName'] as String,
            questionType: data['questionType'] as String,
            options: data['options'] as List<Map<String, dynamic>>,
            correctOptionIndex: data['correctOptionIndex'] as int,
          );
          expect(result, isNotNull, reason: 'Add question should return a result');
          questionsAdded++;
        }
        
        expect(questionsAdded, equals(50), reason: 'Should have added 50 questions to custom module');
        QuizzerLogger.logSuccess('Added $questionsAdded questions to custom module: $normalizedModuleName');
        
        // Step 3: Verify the custom module exists and has questions
        QuizzerLogger.logMessage('Step 3: Verifying custom module setup');
        final Map<String, dynamic>? moduleData = await getModule(normalizedModuleName);
        expect(moduleData, isNotNull, reason: 'Custom module should exist');
        
        // Direct database query to verify questions exist
        final db = await getDatabaseMonitor().requestDatabaseAccess();
        try {
          final List<Map<String, dynamic>> questions = await db!.query(
            'question_answer_pairs',
            where: 'module_name = ?',
            whereArgs: [normalizedModuleName],
          );
          expect(questions.length, equals(50), reason: 'Custom module should have 50 questions');
          QuizzerLogger.logSuccess('Verified custom module has 50 questions via direct query');
        } finally {
          getDatabaseMonitor().releaseDatabaseAccess();
        }
        
        // Step 4: Attempt to rename the custom module
        QuizzerLogger.logMessage('Step 4: Testing module rename functionality');
        final String newModuleName = 'renamed_module_${testIteration}_${DateTime.now().millisecondsSinceEpoch}';
        createdTestModules.add(newModuleName);
        
        final bool renameResult = await sessionManager.renameModule(normalizedModuleName, newModuleName);
        expect(renameResult, isTrue, reason: 'Module rename should succeed');
        QuizzerLogger.logSuccess('Successfully renamed module from $normalizedModuleName to $newModuleName');
        
        // Step 5: Verify questions moved to new module name
        QuizzerLogger.logMessage('Step 5: Verifying questions moved to new module');
        final String normalizedNewModuleName = await normalizeString(newModuleName);
        
        // Direct database query to verify questions moved to new module
        final db2 = await getDatabaseMonitor().requestDatabaseAccess();
        try {
          final List<Map<String, dynamic>> questionsAfterRename = await db2!.query(
            'question_answer_pairs',
            where: 'module_name = ?',
            whereArgs: [normalizedNewModuleName],
          );
          expect(questionsAfterRename.length, equals(50), reason: 'Should have 50 questions in renamed module');
          
          // Verify no questions exist with old module name
          final List<Map<String, dynamic>> questionsWithOldName = await db2.query(
            'question_answer_pairs',
            where: 'module_name = ?',
            whereArgs: [normalizedModuleName],
          );
          expect(questionsWithOldName.length, equals(0), reason: 'No questions should exist with old module name');
        } finally {
          getDatabaseMonitor().releaseDatabaseAccess();
        }
        
        QuizzerLogger.logSuccess('Verified all 50 questions moved to renamed module');
        
        // Step 6: Rename the module back to its original name
        QuizzerLogger.logMessage('Step 6: Renaming module back to original name');
        final bool revertResult = await sessionManager.renameModule(normalizedNewModuleName, normalizedModuleName);
        expect(revertResult, isTrue, reason: 'Module revert should succeed');
        QuizzerLogger.logSuccess('Successfully reverted module from $normalizedNewModuleName to $normalizedModuleName');
        
        // Step 7: Verify the module is back to its original state
        QuizzerLogger.logMessage('Step 7: Verifying module is back to original state');
        final Map<String, dynamic>? moduleDataAfterRevert = await getModule(normalizedModuleName);
        expect(moduleDataAfterRevert, isNotNull, reason: 'Module should exist after revert');
        
        // Direct database query to verify questions are back to original state
        final db3 = await getDatabaseMonitor().requestDatabaseAccess();
        try {
          final List<Map<String, dynamic>> questionsAfterRevert = await db3!.query(
            'question_answer_pairs',
            where: 'module_name = ?',
            whereArgs: [normalizedModuleName],
          );
          expect(questionsAfterRevert.length, equals(50), reason: 'Should have 50 questions after revert (same as original)');
          
          // Verify no questions exist with the temporary new name
          final List<Map<String, dynamic>> questionsWithTempName = await db3.query(
            'question_answer_pairs',
            where: 'module_name = ?',
            whereArgs: [normalizedNewModuleName],
          );
          expect(questionsWithTempName.length, equals(0), reason: 'No questions should exist with temporary module name');
        } finally {
          getDatabaseMonitor().releaseDatabaseAccess();
        }
        
        QuizzerLogger.logSuccess('✅ Module rename API test completed successfully - full cycle with revert validation');
        
      } catch (e) {
        QuizzerLogger.logError('Test 1 failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
