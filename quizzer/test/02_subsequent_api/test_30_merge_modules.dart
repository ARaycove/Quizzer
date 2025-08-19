import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/session_manager/answer_validation/text_analysis_tools.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
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
  
  group('Module Merge Tests', () {
    test('Test 1: Test module merge API with custom module setup', () async {
      QuizzerLogger.logMessage('=== Test 1: Test module merge API with custom module setup ===');
      
      try {
        // Step 1: Clear database tables to ensure clean state
        QuizzerLogger.logMessage('Step 1: Clearing database tables for clean state');
        await deleteAllRecordsFromTable('question_answer_pairs');
        await deleteAllRecordsFromTable('modules');
        QuizzerLogger.logSuccess('Database tables cleared');
        
        // Step 2: Create 3 custom modules with questions
        QuizzerLogger.logMessage('Step 2: Creating 3 custom modules with questions');
        final List<String> moduleNames = [
          'merge_test_module_1_${testIteration}_${DateTime.now().millisecondsSinceEpoch}',
          'merge_test_module_2_${testIteration}_${DateTime.now().millisecondsSinceEpoch}',
          'merge_test_module_3_${testIteration}_${DateTime.now().millisecondsSinceEpoch}',
        ];
        
        // Add test modules to cleanup list
        createdTestModules.addAll(moduleNames);
        
        final List<String> normalizedModuleNames = [];
        final List<int> questionCounts = [];
        
        for (int i = 0; i < moduleNames.length; i++) {
          final String moduleName = moduleNames[i];
          final String normalizedModuleName = await normalizeString(moduleName);
          normalizedModuleNames.add(normalizedModuleName);
          
          // Generate 10 questions for each module
          final List<Map<String, dynamic>> questionData = generateQuestionInputData(
            questionType: 'multiple_choice',
            numberOfQuestions: 10,
            numberOfModules: 1,
            customModuleName: normalizedModuleName,
          );
          
          // Add questions to database
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
          
          questionCounts.add(questionsAdded);
          QuizzerLogger.logMessage('Module $i: $normalizedModuleName ($questionsAdded questions)');
        }
        
        expect(normalizedModuleNames.length, equals(3), reason: 'Should have created exactly 3 modules');
        QuizzerLogger.logSuccess('Created ${normalizedModuleNames.length} modules with questions');
        
        // Step 3: Verify initial state - all modules should have 10 questions each
        QuizzerLogger.logMessage('Step 3: Verifying initial state');
        for (int i = 0; i < normalizedModuleNames.length; i++) {
          final String moduleName = normalizedModuleNames[i];
          final int expectedCount = questionCounts[i];
          
          // Direct database query to verify questions exist
          final db = await getDatabaseMonitor().requestDatabaseAccess();
          try {
            final List<Map<String, dynamic>> questions = await db!.query(
              'question_answer_pairs',
              where: 'module_name = ?',
              whereArgs: [moduleName],
            );
            expect(questions.length, equals(expectedCount), reason: 'Module $i should have $expectedCount questions');
            QuizzerLogger.logSuccess('Verified module $i has $expectedCount questions');
          } finally {
            getDatabaseMonitor().releaseDatabaseAccess();
          }
        }
        
        // Step 4: Merge module 1 into module 2
        QuizzerLogger.logMessage('Step 4: Merging module 1 into module 2');
        final String sourceModule1 = normalizedModuleNames[0];
        final String targetModule2 = normalizedModuleNames[1];
        final int sourceCount1 = questionCounts[0];
        final int targetCount2 = questionCounts[1];
        final int expectedAfterFirstMerge = sourceCount1 + targetCount2;
        
        final bool mergeResult1 = await sessionManager.mergeModules(sourceModule1, targetModule2);
        expect(mergeResult1, isTrue, reason: 'First module merge should succeed');
        QuizzerLogger.logSuccess('First merge completed successfully');
        
        // Step 5: Verify first merge results
        QuizzerLogger.logMessage('Step 5: Verifying first merge results');
        final db2 = await getDatabaseMonitor().requestDatabaseAccess();
        try {
          // Verify source module 1 has 0 questions
          final List<Map<String, dynamic>> sourceQuestions1 = await db2!.query(
            'question_answer_pairs',
            where: 'module_name = ?',
            whereArgs: [sourceModule1],
          );
          expect(sourceQuestions1.length, equals(0), reason: 'Source module 1 should have 0 questions after merge');
          
          // Verify target module 2 has combined questions
          final List<Map<String, dynamic>> targetQuestions2 = await db2.query(
            'question_answer_pairs',
            where: 'module_name = ?',
            whereArgs: [targetModule2],
          );
          expect(targetQuestions2.length, equals(expectedAfterFirstMerge), reason: 'Target module 2 should have $expectedAfterFirstMerge questions after first merge');
          
          QuizzerLogger.logSuccess('Verified first merge: module 1 has 0 questions, module 2 has $expectedAfterFirstMerge questions');
        } finally {
          getDatabaseMonitor().releaseDatabaseAccess();
        }
        
        // Step 6: Merge module 2 into module 3
        QuizzerLogger.logMessage('Step 6: Merging module 2 into module 3');
        final String sourceModule2 = normalizedModuleNames[1];
        final String targetModule3 = normalizedModuleNames[2];
        final int sourceCount2 = expectedAfterFirstMerge; // Module 2 now has the combined count
        final int targetCount3 = questionCounts[2];
        final int expectedAfterSecondMerge = sourceCount2 + targetCount3;
        
        final bool mergeResult2 = await sessionManager.mergeModules(sourceModule2, targetModule3);
        expect(mergeResult2, isTrue, reason: 'Second module merge should succeed');
        QuizzerLogger.logSuccess('Second merge completed successfully');
        
        // Step 7: Verify final state - all questions should be in module 3
        QuizzerLogger.logMessage('Step 7: Verifying final state');
        final db3 = await getDatabaseMonitor().requestDatabaseAccess();
        try {
          // Verify module 1 has 0 questions
          final List<Map<String, dynamic>> questions1 = await db3!.query(
            'question_answer_pairs',
            where: 'module_name = ?',
            whereArgs: [sourceModule1],
          );
          expect(questions1.length, equals(0), reason: 'Module 1 should have 0 questions after final merge');
          
          // Verify module 2 has 0 questions
          final List<Map<String, dynamic>> questions2 = await db3.query(
            'question_answer_pairs',
            where: 'module_name = ?',
            whereArgs: [sourceModule2],
          );
          expect(questions2.length, equals(0), reason: 'Module 2 should have 0 questions after final merge');
          
          // Verify module 3 has all questions
          final List<Map<String, dynamic>> questions3 = await db3.query(
            'question_answer_pairs',
            where: 'module_name = ?',
            whereArgs: [targetModule3],
          );
          expect(questions3.length, equals(expectedAfterSecondMerge), reason: 'Module 3 should have all $expectedAfterSecondMerge questions after final merge');
          
          QuizzerLogger.logSuccess('Verified final state: all questions are in module 3');
        } finally {
          getDatabaseMonitor().releaseDatabaseAccess();
        }
        
        QuizzerLogger.logSuccess('✅ Module merge API test completed successfully - all questions merged into final module');
        
      } catch (e) {
        QuizzerLogger.logError('Test 1 failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
