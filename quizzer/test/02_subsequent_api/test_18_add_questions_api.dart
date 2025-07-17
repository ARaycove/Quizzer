import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
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
  
  group('SessionManager Add Questions API Tests', () {
    test('Test 1: Clean database and login initialization', () async {
      QuizzerLogger.logMessage('=== Test 1: Clean database and login initialization ===');
      
      // Step 1: Get initial counts
      QuizzerLogger.logMessage('Step 1: Getting initial counts...');
      final List<Map<String, dynamic>> initialQuestions = await getAllQuestionAnswerPairs();
      final List<Map<String, dynamic>> initialModules = await getAllModules();
      final int initialQuestionCount = initialQuestions.length;
      final int initialModuleCount = initialModules.length;
      QuizzerLogger.logMessage('Initial question count: $initialQuestionCount');
      QuizzerLogger.logMessage('Initial module count: $initialModuleCount');
      
      // Step 2: Clear the question_answer_pairs table
      QuizzerLogger.logMessage('Step 2: Clearing question_answer_pairs table...');
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db == null) {
        throw Exception('Failed to acquire database access');
      }
      
      await db.execute('DELETE FROM question_answer_pairs');
      getDatabaseMonitor().releaseDatabaseAccess();
      QuizzerLogger.logSuccess('Question_answer_pairs table cleared');
      
      // Step 3: Clear the modules table
      QuizzerLogger.logMessage('Step 3: Clearing modules table...');
      final db2 = await getDatabaseMonitor().requestDatabaseAccess();
      if (db2 == null) {
        throw Exception('Failed to acquire database access');
      }
      
      await db2.execute('DELETE FROM modules');
      getDatabaseMonitor().releaseDatabaseAccess();
      QuizzerLogger.logSuccess('Modules table cleared');
      
      // Step 4: Verify tables are empty
      QuizzerLogger.logMessage('Step 4: Verifying tables are empty...');
      final List<Map<String, dynamic>> questionsAfterClear = await getAllQuestionAnswerPairs();
      final List<Map<String, dynamic>> modulesAfterClear = await getAllModules();
      final int afterClearQuestionCount = questionsAfterClear.length;
      final int afterClearModuleCount = modulesAfterClear.length;
      expect(afterClearQuestionCount, equals(0), reason: 'Question_answer_pairs table should be empty after clearing');
      expect(afterClearModuleCount, equals(0), reason: 'Modules table should be empty after clearing');
      QuizzerLogger.logSuccess('Verified tables are empty (questions: $afterClearQuestionCount, modules: $afterClearModuleCount)');
      
      // Step 5: Login initialization
      QuizzerLogger.logMessage('Step 5: Calling loginInitialization with testRun=true...');
      final loginResult = await loginInitialization(
        email: testEmail, 
        password: testPassword, 
        supabase: sessionManager.supabase, 
        storage: sessionManager.getBox(testAccessPassword),
        testRun: true, // This bypasses sync workers
      );
      expect(loginResult['success'], isTrue, reason: 'Login initialization should succeed');
      QuizzerLogger.logSuccess('Login initialization completed successfully');
      
      // Step 6: Verify that user is logged in and ready
      expect(sessionManager.userId, isNotNull, reason: 'User should be logged in');
      QuizzerLogger.logSuccess('User is logged in and ready for testing');
      
      // Store results for final report
      testResults['initial_questions_count'] = initialQuestionCount;
      testResults['initial_modules_count'] = initialModuleCount;
      testResults['tables_cleared'] = true;
      
      QuizzerLogger.logSuccess('=== Test 1 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 2: Add multiple choice questions and verify', () async {
      QuizzerLogger.logMessage('=== Test 2: Add multiple choice questions and verify ===');
      
      // Step 1: Add multiple choice questions with new module name
      QuizzerLogger.logMessage('Step 1: Adding multiple choice questions with new module...');
      final String testModule = 'TestModule_${DateTime.now().millisecondsSinceEpoch}';
      QuizzerLogger.logMessage('Using new test module: $testModule');
      
      // Step 2: Add multiple choice questions
      QuizzerLogger.logMessage('Step 2: Adding multiple choice questions...');
      final stopwatch = Stopwatch()..start();
      
      // Question 1: Geography
      final Map<String, dynamic> addResult1 = await sessionManager.addNewQuestion(
        questionType: 'multiple_choice',
        questionElements: [
          {'type': 'text', 'content': 'What is the capital of France?'}
        ],
        answerElements: [
          {'type': 'text', 'content': 'Paris is the capital of France.'}
        ],
        moduleName: testModule,
        options: [
          {'type': 'text', 'content': 'London'},
          {'type': 'text', 'content': 'Paris'},
          {'type': 'text', 'content': 'Berlin'},
          {'type': 'text', 'content': 'Madrid'},
        ],
        correctOptionIndex: 1, // Paris
        citation: 'Geography Textbook',
        concepts: 'Geography, Capitals',
        subjects: 'Geography',
      );
      
      // Question 2: History
      final Map<String, dynamic> addResult2 = await sessionManager.addNewQuestion(
        questionType: 'multiple_choice',
        questionElements: [
          {'type': 'text', 'content': 'Who was the first President of the United States?'}
        ],
        answerElements: [
          {'type': 'text', 'content': 'George Washington was the first President.'}
        ],
        moduleName: testModule,
        options: [
          {'type': 'text', 'content': 'Thomas Jefferson'},
          {'type': 'text', 'content': 'George Washington'},
          {'type': 'text', 'content': 'John Adams'},
          {'type': 'text', 'content': 'Benjamin Franklin'},
        ],
        correctOptionIndex: 1, // George Washington
        citation: 'History Textbook',
        concepts: 'History, Presidents',
        subjects: 'History',
      );
      
      // Question 3: Science
      final Map<String, dynamic> addResult3 = await sessionManager.addNewQuestion(
        questionType: 'multiple_choice',
        questionElements: [
          {'type': 'text', 'content': 'What is the chemical symbol for gold?'}
        ],
        answerElements: [
          {'type': 'text', 'content': 'Au is the chemical symbol for gold.'}
        ],
        moduleName: testModule,
        options: [
          {'type': 'text', 'content': 'Ag'},
          {'type': 'text', 'content': 'Au'},
          {'type': 'text', 'content': 'Fe'},
          {'type': 'text', 'content': 'Cu'},
        ],
        correctOptionIndex: 1, // Au
        citation: 'Chemistry Textbook',
        concepts: 'Chemistry, Elements',
        subjects: 'Science',
      );
      
      stopwatch.stop();
      final int elapsedMilliseconds = stopwatch.elapsedMilliseconds;
      
      expect(addResult1, isNotNull, reason: 'Add question 1 should return a result');
      expect(addResult2, isNotNull, reason: 'Add question 2 should return a result');
      expect(addResult3, isNotNull, reason: 'Add question 3 should return a result');
      QuizzerLogger.logMessage('Add multiple choice questions API calls took ${elapsedMilliseconds}ms');
      
      // Step 3: Verify questions were added
      QuizzerLogger.logMessage('Step 3: Verifying questions were added...');
      final List<Map<String, dynamic>> questionsAfterAdd = await getAllQuestionAnswerPairs();
      final int afterAddCount = questionsAfterAdd.length;
      expect(afterAddCount, equals(3), reason: 'Should have exactly 3 questions after adding');
      
      // Step 4: Verify question details
      final List<Map<String, dynamic>> moduleQuestions = questionsAfterAdd.where((q) => q['module_name'] == testModule).toList();
      expect(moduleQuestions.length, equals(3), reason: 'Should have 3 questions in the test module');
      
      // Verify all questions are multiple choice
      for (final question in moduleQuestions) {
        expect(question['question_type'], equals('multiple_choice'), 
          reason: 'All questions should be multiple_choice type');
        expect(question['module_name'], equals(testModule), 
          reason: 'All questions should be in correct module');
      }
      
      // Step 5: Verify module was created
      QuizzerLogger.logMessage('Step 5: Verifying module was created...');
      final List<Map<String, dynamic>> modulesAfterAdd = await getAllModules();
      final int moduleCount = modulesAfterAdd.length;
      expect(moduleCount, equals(1), reason: 'Should have exactly 1 module after adding questions');
      
      final Map<String, dynamic> createdModule = modulesAfterAdd.first;
      expect(createdModule['module_name'], equals(testModule), 
        reason: 'Module name should match the test module');
      
      // Store results for final report
      testResults['multiple_choice_added'] = true;
      testResults['multiple_choice_count'] = 3;
      testResults['multiple_choice_performance_ms'] = elapsedMilliseconds;
      testResults['module_created'] = true;
      
      QuizzerLogger.logSuccess('Multiple choice questions added and module created successfully');
      QuizzerLogger.logSuccess('=== Test 2 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 3: Add true/false questions and verify', () async {
      QuizzerLogger.logMessage('=== Test 3: Add true/false questions and verify ===');
      
      // Step 1: Add true/false questions with new module name
      final String testModule = 'ScienceModule_${DateTime.now().millisecondsSinceEpoch}';
      QuizzerLogger.logMessage('Using new science module: $testModule');
      
      // Step 2: Add true/false questions
      QuizzerLogger.logMessage('Step 2: Adding true/false questions...');
      final stopwatch = Stopwatch()..start();
      
      // Question 1: Earth Science
      final Map<String, dynamic> addResult1 = await sessionManager.addNewQuestion(
        questionType: 'true_false',
        questionElements: [
          {'type': 'text', 'content': 'The Earth is round.'}
        ],
        answerElements: [
          {'type': 'text', 'content': 'True, the Earth is approximately spherical.'}
        ],
        moduleName: testModule,
        correctOptionIndex: 0, // True
        citation: 'Science Textbook',
        concepts: 'Science, Earth',
        subjects: 'Science',
      );
      
      // Question 2: Biology
      final Map<String, dynamic> addResult2 = await sessionManager.addNewQuestion(
        questionType: 'true_false',
        questionElements: [
          {'type': 'text', 'content': 'Humans have 206 bones in their body.'}
        ],
        answerElements: [
          {'type': 'text', 'content': 'True, adult humans typically have 206 bones.'}
        ],
        moduleName: testModule,
        correctOptionIndex: 0, // True
        citation: 'Biology Textbook',
        concepts: 'Biology, Anatomy',
        subjects: 'Science',
      );
      
      // Question 3: Physics
      final Map<String, dynamic> addResult3 = await sessionManager.addNewQuestion(
        questionType: 'true_false',
        questionElements: [
          {'type': 'text', 'content': 'Light travels faster than sound.'}
        ],
        answerElements: [
          {'type': 'text', 'content': 'True, light travels much faster than sound.'}
        ],
        moduleName: testModule,
        correctOptionIndex: 0, // True
        citation: 'Physics Textbook',
        concepts: 'Physics, Waves',
        subjects: 'Science',
      );
      
      stopwatch.stop();
      final int elapsedMilliseconds = stopwatch.elapsedMilliseconds;
      
      expect(addResult1, isNotNull, reason: 'Add question 1 should return a result');
      expect(addResult2, isNotNull, reason: 'Add question 2 should return a result');
      expect(addResult3, isNotNull, reason: 'Add question 3 should return a result');
      QuizzerLogger.logMessage('Add true/false questions API calls took ${elapsedMilliseconds}ms');
      
      // Step 3: Verify questions were added
      QuizzerLogger.logMessage('Step 3: Verifying true/false questions were added...');
      final List<Map<String, dynamic>> questionsAfterAdd = await getAllQuestionAnswerPairs();
      final int afterAddCount = questionsAfterAdd.length;
      expect(afterAddCount, equals(6), reason: 'Should have exactly 6 questions after adding (3 MC + 3 TF)');
      
      // Step 4: Verify question details
      final List<Map<String, dynamic>> moduleQuestions = questionsAfterAdd.where((q) => q['module_name'] == testModule).toList();
      expect(moduleQuestions.length, equals(3), reason: 'Should have 3 questions in the science module');
      
      // Verify all questions are true/false
      for (final question in moduleQuestions) {
        expect(question['question_type'], equals('true_false'), 
          reason: 'All questions should be true_false type');
        expect(question['module_name'], equals(testModule), 
          reason: 'All questions should be in correct module');
      }
      
      // Step 5: Verify module was created
      QuizzerLogger.logMessage('Step 5: Verifying module was created...');
      final List<Map<String, dynamic>> modulesAfterAdd = await getAllModules();
      final int moduleCount = modulesAfterAdd.length;
      expect(moduleCount, equals(2), reason: 'Should have exactly 2 modules after adding questions');
      
      final bool moduleExists = modulesAfterAdd.any((m) => m['module_name'] == testModule);
      expect(moduleExists, isTrue, reason: 'Science module should exist in modules table');
      
      // Store results for final report
      testResults['true_false_added'] = true;
      testResults['true_false_count'] = 3;
      testResults['true_false_performance_ms'] = elapsedMilliseconds;
      
      QuizzerLogger.logSuccess('True/false questions added and module created successfully');
      QuizzerLogger.logSuccess('=== Test 3 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 4: Add select_all_that_apply questions and verify', () async {
      QuizzerLogger.logMessage('=== Test 4: Add select_all_that_apply questions and verify ===');
      
      // Step 1: Add select_all_that_apply questions with new module name
      final String testModule = 'ProgrammingModule_${DateTime.now().millisecondsSinceEpoch}';
      QuizzerLogger.logMessage('Using new programming module: $testModule');
      
      // Step 2: Add select_all_that_apply questions
      QuizzerLogger.logMessage('Step 2: Adding select_all_that_apply questions...');
      final stopwatch = Stopwatch()..start();
      
      // Question 1: Programming Languages
      final Map<String, dynamic> addResult1 = await sessionManager.addNewQuestion(
        questionType: 'select_all_that_apply',
        questionElements: [
          {'type': 'text', 'content': 'Which of the following are programming languages?'}
        ],
        answerElements: [
          {'type': 'text', 'content': 'Python, Java, and JavaScript are programming languages.'}
        ],
        moduleName: testModule,
        options: [
          {'type': 'text', 'content': 'Python'},
          {'type': 'text', 'content': 'Java'},
          {'type': 'text', 'content': 'JavaScript'},
          {'type': 'text', 'content': 'HTML'},
        ],
        indexOptionsThatApply: [0, 1, 2], // Python, Java, JavaScript
        citation: 'Programming Textbook',
        concepts: 'Programming, Languages',
        subjects: 'Computer Science',
      );
      
      // Question 2: Data Types
      final Map<String, dynamic> addResult2 = await sessionManager.addNewQuestion(
        questionType: 'select_all_that_apply',
        questionElements: [
          {'type': 'text', 'content': 'Which of the following are primitive data types in Java?'}
        ],
        answerElements: [
          {'type': 'text', 'content': 'int, double, and boolean are primitive data types.'}
        ],
        moduleName: testModule,
        options: [
          {'type': 'text', 'content': 'int'},
          {'type': 'text', 'content': 'double'},
          {'type': 'text', 'content': 'boolean'},
          {'type': 'text', 'content': 'String'},
        ],
        indexOptionsThatApply: [0, 1, 2], // int, double, boolean
        citation: 'Java Textbook',
        concepts: 'Programming, Data Types',
        subjects: 'Computer Science',
      );
      
      // Question 3: Web Technologies
      final Map<String, dynamic> addResult3 = await sessionManager.addNewQuestion(
        questionType: 'select_all_that_apply',
        questionElements: [
          {'type': 'text', 'content': 'Which of the following are web technologies?'}
        ],
        answerElements: [
          {'type': 'text', 'content': 'HTML, CSS, and JavaScript are web technologies.'}
        ],
        moduleName: testModule,
        options: [
          {'type': 'text', 'content': 'HTML'},
          {'type': 'text', 'content': 'CSS'},
          {'type': 'text', 'content': 'JavaScript'},
          {'type': 'text', 'content': 'Python'},
        ],
        indexOptionsThatApply: [0, 1, 2], // HTML, CSS, JavaScript
        citation: 'Web Development Textbook',
        concepts: 'Programming, Web Development',
        subjects: 'Computer Science',
      );
      
      stopwatch.stop();
      final int elapsedMilliseconds = stopwatch.elapsedMilliseconds;
      
      expect(addResult1, isNotNull, reason: 'Add question 1 should return a result');
      expect(addResult2, isNotNull, reason: 'Add question 2 should return a result');
      expect(addResult3, isNotNull, reason: 'Add question 3 should return a result');
      QuizzerLogger.logMessage('Add select_all_that_apply questions API calls took ${elapsedMilliseconds}ms');
      
      // Step 3: Verify questions were added
      QuizzerLogger.logMessage('Step 3: Verifying select_all_that_apply questions were added...');
      final List<Map<String, dynamic>> questionsAfterAdd = await getAllQuestionAnswerPairs();
      final int afterAddCount = questionsAfterAdd.length;
      expect(afterAddCount, equals(9), reason: 'Should have exactly 9 questions after adding (3 MC + 3 TF + 3 SA)');
      
      // Step 4: Verify question details
      final List<Map<String, dynamic>> moduleQuestions = questionsAfterAdd.where((q) => q['module_name'] == testModule).toList();
      expect(moduleQuestions.length, equals(3), reason: 'Should have 3 questions in the programming module');
      
      // Verify all questions are select_all_that_apply
      for (final question in moduleQuestions) {
        expect(question['question_type'], equals('select_all_that_apply'), 
          reason: 'All questions should be select_all_that_apply type');
        expect(question['module_name'], equals(testModule), 
          reason: 'All questions should be in correct module');
      }
      
      // Step 5: Verify module was created
      QuizzerLogger.logMessage('Step 5: Verifying module was created...');
      final List<Map<String, dynamic>> modulesAfterAdd = await getAllModules();
      final int moduleCount = modulesAfterAdd.length;
      expect(moduleCount, equals(3), reason: 'Should have exactly 3 modules after adding questions');
      
      final bool moduleExists = modulesAfterAdd.any((m) => m['module_name'] == testModule);
      expect(moduleExists, isTrue, reason: 'Programming module should exist in modules table');
      
      // Store results for final report
      testResults['select_all_added'] = true;
      testResults['select_all_count'] = 3;
      testResults['select_all_performance_ms'] = elapsedMilliseconds;
      
      QuizzerLogger.logSuccess('Select all that apply questions added and module created successfully');
      QuizzerLogger.logSuccess('=== Test 4 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 5: Add sort_order questions and verify', () async {
      QuizzerLogger.logMessage('=== Test 5: Add sort_order questions and verify ===');
      
      // Step 1: Add sort_order questions with new module name
      final String testModule = 'MathModule_${DateTime.now().millisecondsSinceEpoch}';
      QuizzerLogger.logMessage('Using new math module: $testModule');
      
      // Step 2: Add sort_order questions
      QuizzerLogger.logMessage('Step 2: Adding sort_order questions...');
      final stopwatch = Stopwatch()..start();
      
      // Question 1: Number Ordering
      final Map<String, dynamic> addResult1 = await sessionManager.addNewQuestion(
        questionType: 'sort_order',
        questionElements: [
          {'type': 'text', 'content': 'Sort these numbers from smallest to largest:'}
        ],
        answerElements: [
          {'type': 'text', 'content': 'The correct order is 1, 2, 3, 4.'}
        ],
        moduleName: testModule,
        options: [
          {'type': 'text', 'content': '1'},
          {'type': 'text', 'content': '2'},
          {'type': 'text', 'content': '3'},
          {'type': 'text', 'content': '4'},
        ],
        citation: 'Math Textbook',
        concepts: 'Math, Ordering',
        subjects: 'Mathematics',
      );
      
      // Question 2: Fraction Ordering
      final Map<String, dynamic> addResult2 = await sessionManager.addNewQuestion(
        questionType: 'sort_order',
        questionElements: [
          {'type': 'text', 'content': 'Sort these fractions from smallest to largest:'}
        ],
        answerElements: [
          {'type': 'text', 'content': 'The correct order is 1/4, 1/2, 3/4, 1.'}
        ],
        moduleName: testModule,
        options: [
          {'type': 'text', 'content': '1/4'},
          {'type': 'text', 'content': '1/2'},
          {'type': 'text', 'content': '3/4'},
          {'type': 'text', 'content': '1'},
        ],
        citation: 'Math Textbook',
        concepts: 'Math, Fractions',
        subjects: 'Mathematics',
      );
      
      // Question 3: Decimal Ordering
      final Map<String, dynamic> addResult3 = await sessionManager.addNewQuestion(
        questionType: 'sort_order',
        questionElements: [
          {'type': 'text', 'content': 'Sort these decimals from smallest to largest:'}
        ],
        answerElements: [
          {'type': 'text', 'content': 'The correct order is 0.1, 0.5, 0.75, 1.0.'}
        ],
        moduleName: testModule,
        options: [
          {'type': 'text', 'content': '0.1'},
          {'type': 'text', 'content': '0.5'},
          {'type': 'text', 'content': '0.75'},
          {'type': 'text', 'content': '1.0'},
        ],
        citation: 'Math Textbook',
        concepts: 'Math, Decimals',
        subjects: 'Mathematics',
      );
      
      stopwatch.stop();
      final int elapsedMilliseconds = stopwatch.elapsedMilliseconds;
      
      expect(addResult1, isNotNull, reason: 'Add question 1 should return a result');
      expect(addResult2, isNotNull, reason: 'Add question 2 should return a result');
      expect(addResult3, isNotNull, reason: 'Add question 3 should return a result');
      QuizzerLogger.logMessage('Add sort_order questions API calls took ${elapsedMilliseconds}ms');
      
      // Step 3: Verify questions were added
      QuizzerLogger.logMessage('Step 3: Verifying sort_order questions were added...');
      final List<Map<String, dynamic>> questionsAfterAdd = await getAllQuestionAnswerPairs();
      final int afterAddCount = questionsAfterAdd.length;
      expect(afterAddCount, equals(12), reason: 'Should have exactly 12 questions after adding (3 MC + 3 TF + 3 SA + 3 SO)');
      
      // Step 4: Verify question details
      final List<Map<String, dynamic>> moduleQuestions = questionsAfterAdd.where((q) => q['module_name'] == testModule).toList();
      expect(moduleQuestions.length, equals(3), reason: 'Should have 3 questions in the math module');
      
      // Verify all questions are sort_order
      for (final question in moduleQuestions) {
        expect(question['question_type'], equals('sort_order'), 
          reason: 'All questions should be sort_order type');
        expect(question['module_name'], equals(testModule), 
          reason: 'All questions should be in correct module');
      }
      
      // Step 5: Verify module was created
      QuizzerLogger.logMessage('Step 5: Verifying module was created...');
      final List<Map<String, dynamic>> modulesAfterAdd = await getAllModules();
      final int moduleCount = modulesAfterAdd.length;
      expect(moduleCount, equals(4), reason: 'Should have exactly 4 modules after adding questions');
      
      final bool moduleExists = modulesAfterAdd.any((m) => m['module_name'] == testModule);
      expect(moduleExists, isTrue, reason: 'Math module should exist in modules table');
      
      // Store results for final report
      testResults['sort_order_added'] = true;
      testResults['sort_order_count'] = 3;
      testResults['sort_order_performance_ms'] = elapsedMilliseconds;
      
      QuizzerLogger.logSuccess('Sort order questions added and module created successfully');
      QuizzerLogger.logSuccess('=== Test 5 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 6: Performance and functionality report', () async {
      QuizzerLogger.logMessage('=== Test 6: Performance and functionality report ===');
      
      // Get final counts
      final List<Map<String, dynamic>> finalQuestions = await getAllQuestionAnswerPairs();
      final List<Map<String, dynamic>> finalModules = await getAllModules();
      final int finalQuestionCount = finalQuestions.length;
      final int finalModuleCount = finalModules.length;
      
      // Calculate average performance
      final List<int> performanceTimes = [
        testResults['multiple_choice_performance_ms'] ?? 0,
        testResults['true_false_performance_ms'] ?? 0,
        testResults['select_all_performance_ms'] ?? 0,
        testResults['sort_order_performance_ms'] ?? 0,
      ];
      final double averagePerformance = performanceTimes.reduce((a, b) => a + b) / performanceTimes.length;
      
      QuizzerLogger.printHeader('=== ADD QUESTIONS API COMPREHENSIVE REPORT ===');
      QuizzerLogger.printHeader('=== CLEANUP METRICS ===');
      QuizzerLogger.logMessage('Initial Questions Count: ${testResults['initial_questions_count']}');
      QuizzerLogger.logMessage('Initial Modules Count: ${testResults['initial_modules_count']}');
      QuizzerLogger.logMessage('Tables Cleared: ${testResults['tables_cleared'] == true ? 'YES' : 'NO'}');
      QuizzerLogger.logMessage('Final Questions Count: $finalQuestionCount');
      QuizzerLogger.logMessage('Final Modules Count: $finalModuleCount');
      QuizzerLogger.logMessage('');
      QuizzerLogger.printHeader('=== FUNCTIONALITY TESTS ===');
      QuizzerLogger.logMessage('Multiple Choice Questions: ${testResults['multiple_choice_added'] == true ? 'PASS' : 'FAIL'} (${testResults['multiple_choice_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('True/False Questions: ${testResults['true_false_added'] == true ? 'PASS' : 'FAIL'} (${testResults['true_false_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('Select All That Apply Questions: ${testResults['select_all_added'] == true ? 'PASS' : 'FAIL'} (${testResults['select_all_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('Sort Order Questions: ${testResults['sort_order_added'] == true ? 'PASS' : 'FAIL'} (${testResults['sort_order_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('Module Creation: ${testResults['module_created'] == true ? 'PASS' : 'FAIL'} (4 modules created)');
      QuizzerLogger.logMessage('');
      QuizzerLogger.printHeader('=== PERFORMANCE METRICS ===');
      QuizzerLogger.logMessage('Average Add Question Time: ${averagePerformance.toStringAsFixed(1)}ms');
      QuizzerLogger.logMessage('Multiple Choice Performance: ${testResults['multiple_choice_performance_ms']}ms');
      QuizzerLogger.logMessage('True/False Performance: ${testResults['true_false_performance_ms']}ms');
      QuizzerLogger.logMessage('Select All Performance: ${testResults['select_all_performance_ms']}ms');
      QuizzerLogger.logMessage('Sort Order Performance: ${testResults['sort_order_performance_ms']}ms');
      QuizzerLogger.printHeader('=== END COMPREHENSIVE REPORT ===');
      
      QuizzerLogger.logSuccess('=== Test 6 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
    
    test('Test 7: Bulk question creation - 5 modules with 50 questions each', () async {
      QuizzerLogger.logMessage('=== Test 7: Bulk question creation - 5 modules with 50 questions each ===');
      
      // Step 1: Get current counts before bulk creation
      QuizzerLogger.logMessage('Step 1: Getting current counts...');
      final List<Map<String, dynamic>> questionsBeforeBulk = await getAllQuestionAnswerPairs();
      final List<Map<String, dynamic>> modulesBeforeBulk = await getAllModules();
      final int questionsBeforeCount = questionsBeforeBulk.length;
      final int modulesBeforeCount = modulesBeforeBulk.length;
      QuizzerLogger.logMessage('Questions before bulk: $questionsBeforeCount');
      QuizzerLogger.logMessage('Modules before bulk: $modulesBeforeCount');
      
      // Step 2: Create 5 test modules with 50 questions each
      QuizzerLogger.logMessage('Step 2: Creating 5 test modules with 50 questions each...');
      final stopwatch = Stopwatch()..start();
      
      final List<String> testModules = [
        'BulkTestModule1_${DateTime.now().millisecondsSinceEpoch}',
        'BulkTestModule2_${DateTime.now().millisecondsSinceEpoch}',
        'BulkTestModule3_${DateTime.now().millisecondsSinceEpoch}',
        'BulkTestModule4_${DateTime.now().millisecondsSinceEpoch}',
        'BulkTestModule5_${DateTime.now().millisecondsSinceEpoch}',
      ];
      
      final List<String> subjects = ['Science', 'History', 'Geography', 'Literature', 'Mathematics'];
      final List<String> concepts = ['Physics', 'Ancient Civilizations', 'World Capitals', 'Classic Novels', 'Algebra'];
      
      int totalQuestionsAdded = 0;
      final Map<String, int> questionsPerModule = {};
      
      for (int moduleIndex = 0; moduleIndex < testModules.length; moduleIndex++) {
        final String moduleName = testModules[moduleIndex];
        final String subject = subjects[moduleIndex];
        final String concept = concepts[moduleIndex];
        
        QuizzerLogger.logMessage('Creating module $moduleIndex: $moduleName');
        int questionsInModule = 0;
        
        // Add 50 questions to this module
        for (int questionIndex = 0; questionIndex < 50; questionIndex++) {
          // Cycle through question types
          final String questionType = ['multiple_choice', 'true_false', 'select_all_that_apply', 'sort_order'][questionIndex % 4];
          
          Map<String, dynamic> addResult;
          
          switch (questionType) {
            case 'multiple_choice':
              addResult = await sessionManager.addNewQuestion(
                questionType: 'multiple_choice',
                questionElements: [
                  {'type': 'text', 'content': 'Bulk question ${questionIndex + 1} for $moduleName: What is the answer?'}
                ],
                answerElements: [
                  {'type': 'text', 'content': 'This is the answer for bulk question ${questionIndex + 1}.'}
                ],
                moduleName: moduleName,
                options: [
                  {'type': 'text', 'content': 'Option A for question ${questionIndex + 1}'},
                  {'type': 'text', 'content': 'Option B for question ${questionIndex + 1}'},
                  {'type': 'text', 'content': 'Option C for question ${questionIndex + 1}'},
                  {'type': 'text', 'content': 'Option D for question ${questionIndex + 1}'},
                ],
                correctOptionIndex: questionIndex % 4,
                citation: 'Bulk Test Citation ${questionIndex + 1}',
                concepts: concept,
                subjects: subject,
              );
              break;
              
            case 'true_false':
              addResult = await sessionManager.addNewQuestion(
                questionType: 'true_false',
                questionElements: [
                  {'type': 'text', 'content': 'Bulk question ${questionIndex + 1} for $moduleName: Is this true?'}
                ],
                answerElements: [
                  {'type': 'text', 'content': 'This is the explanation for bulk question ${questionIndex + 1}.'}
                ],
                moduleName: moduleName,
                correctOptionIndex: questionIndex % 2, // Alternate between true and false
                citation: 'Bulk Test Citation ${questionIndex + 1}',
                concepts: concept,
                subjects: subject,
              );
              break;
              
            case 'select_all_that_apply':
              addResult = await sessionManager.addNewQuestion(
                questionType: 'select_all_that_apply',
                questionElements: [
                  {'type': 'text', 'content': 'Bulk question ${questionIndex + 1} for $moduleName: Which apply?'}
                ],
                answerElements: [
                  {'type': 'text', 'content': 'This is the explanation for bulk question ${questionIndex + 1}.'}
                ],
                moduleName: moduleName,
                options: [
                  {'type': 'text', 'content': 'Option A for question ${questionIndex + 1}'},
                  {'type': 'text', 'content': 'Option B for question ${questionIndex + 1}'},
                  {'type': 'text', 'content': 'Option C for question ${questionIndex + 1}'},
                  {'type': 'text', 'content': 'Option D for question ${questionIndex + 1}'},
                ],
                indexOptionsThatApply: [0, 1], // Select first two options
                citation: 'Bulk Test Citation ${questionIndex + 1}',
                concepts: concept,
                subjects: subject,
              );
              break;
              
            case 'sort_order':
              addResult = await sessionManager.addNewQuestion(
                questionType: 'sort_order',
                questionElements: [
                  {'type': 'text', 'content': 'Bulk question ${questionIndex + 1} for $moduleName: Sort these items:'}
                ],
                answerElements: [
                  {'type': 'text', 'content': 'This is the explanation for bulk question ${questionIndex + 1}.'}
                ],
                moduleName: moduleName,
                options: [
                  {'type': 'text', 'content': 'Item 1 for question ${questionIndex + 1}'},
                  {'type': 'text', 'content': 'Item 2 for question ${questionIndex + 1}'},
                  {'type': 'text', 'content': 'Item 3 for question ${questionIndex + 1}'},
                  {'type': 'text', 'content': 'Item 4 for question ${questionIndex + 1}'},
                ],
                citation: 'Bulk Test Citation ${questionIndex + 1}',
                concepts: concept,
                subjects: subject,
              );
              break;
              
            default:
              throw Exception('Unknown question type: $questionType');
          }
          
          expect(addResult, isNotNull, reason: 'Add question ${questionIndex + 1} should return a result');
          questionsInModule++;
          totalQuestionsAdded++;
          
          // Log progress every 10 questions
          if (questionIndex % 10 == 9) {
            QuizzerLogger.logMessage('Added ${questionIndex + 1}/50 questions to module $moduleName');
          }
        }
        
        questionsPerModule[moduleName] = questionsInModule;
        QuizzerLogger.logSuccess('Completed module $moduleName with $questionsInModule questions');
      }
      
      stopwatch.stop();
      final int elapsedMilliseconds = stopwatch.elapsedMilliseconds;
      final double averageTimePerQuestion = elapsedMilliseconds / totalQuestionsAdded;
      
      // Step 3: Verify all questions were added
      QuizzerLogger.logMessage('Step 3: Verifying all questions were added...');
      final List<Map<String, dynamic>> questionsAfterBulk = await getAllQuestionAnswerPairs();
      final List<Map<String, dynamic>> modulesAfterBulk = await getAllModules();
      final int questionsAfterCount = questionsAfterBulk.length;
      final int modulesAfterCount = modulesAfterBulk.length;
      
      expect(questionsAfterCount, equals(questionsBeforeCount + totalQuestionsAdded), 
        reason: 'Should have added exactly $totalQuestionsAdded questions');
      expect(modulesAfterCount, equals(modulesBeforeCount + testModules.length), 
        reason: 'Should have added exactly ${testModules.length} modules');
      
      // Step 4: Verify each module has the correct number of questions
      QuizzerLogger.logMessage('Step 4: Verifying question distribution...');
      for (final moduleName in testModules) {
        final List<Map<String, dynamic>> moduleQuestions = questionsAfterBulk.where((q) => q['module_name'] == moduleName).toList();
        expect(moduleQuestions.length, equals(50), 
          reason: 'Module $moduleName should have exactly 50 questions');
        
        // Verify question types are distributed
        final Map<String, int> typeCounts = {};
        for (final question in moduleQuestions) {
          final String questionType = question['question_type'] as String;
          typeCounts[questionType] = (typeCounts[questionType] ?? 0) + 1;
        }
        
        // Should have roughly equal distribution of question types
        expect(typeCounts['multiple_choice'], greaterThan(10), 
          reason: 'Module $moduleName should have multiple choice questions');
        expect(typeCounts['true_false'], greaterThan(10), 
          reason: 'Module $moduleName should have true/false questions');
        expect(typeCounts['select_all_that_apply'], greaterThan(10), 
          reason: 'Module $moduleName should have select all questions');
        expect(typeCounts['sort_order'], greaterThan(10), 
          reason: 'Module $moduleName should have sort order questions');
      }
      
      // Store results for final report
      testResults['bulk_questions_added'] = true;
      testResults['bulk_questions_count'] = totalQuestionsAdded;
      testResults['bulk_modules_count'] = testModules.length;
      testResults['bulk_performance_ms'] = elapsedMilliseconds;
      testResults['bulk_average_time_per_question'] = averageTimePerQuestion;
      
      QuizzerLogger.logSuccess('Bulk question creation completed successfully');
      QuizzerLogger.logValue('Total questions added: $totalQuestionsAdded');
      QuizzerLogger.logValue('Total modules created: ${testModules.length}');
      QuizzerLogger.logValue('Total time: ${elapsedMilliseconds}ms');
      QuizzerLogger.logValue('Average time per question: ${averageTimePerQuestion.toStringAsFixed(1)}ms');
      QuizzerLogger.logSuccess('=== Test 7 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 15)));
    
    test('Test 8: Final comprehensive report with bulk data', () async {
      QuizzerLogger.logMessage('=== Test 8: Final comprehensive report with bulk data ===');
      
      // Get final counts
      final List<Map<String, dynamic>> finalQuestions = await getAllQuestionAnswerPairs();
      final List<Map<String, dynamic>> finalModules = await getAllModules();
      final int finalQuestionCount = finalQuestions.length;
      final int finalModuleCount = finalModules.length;
      
      // Calculate performance metrics
      final List<int> performanceTimes = [
        testResults['multiple_choice_performance_ms'] ?? 0,
        testResults['true_false_performance_ms'] ?? 0,
        testResults['select_all_performance_ms'] ?? 0,
        testResults['sort_order_performance_ms'] ?? 0,
      ];
      final double averagePerformance = performanceTimes.reduce((a, b) => a + b) / performanceTimes.length;
      
      QuizzerLogger.printHeader('=== FINAL COMPREHENSIVE REPORT ===');
      QuizzerLogger.printHeader('=== DATABASE METRICS ===');
      QuizzerLogger.logMessage('Initial Questions Count: ${testResults['initial_questions_count']}');
      QuizzerLogger.logMessage('Initial Modules Count: ${testResults['initial_modules_count']}');
      QuizzerLogger.logMessage('Tables Cleared: ${testResults['tables_cleared'] == true ? 'YES' : 'NO'}');
      QuizzerLogger.logMessage('Final Questions Count: $finalQuestionCount');
      QuizzerLogger.logMessage('Final Modules Count: $finalModuleCount');
      QuizzerLogger.logMessage('Total Questions Added: ${finalQuestionCount - (testResults['initial_questions_count'] ?? 0)}');
      QuizzerLogger.logMessage('Total Modules Added: ${finalModuleCount - (testResults['initial_modules_count'] ?? 0)}');
      QuizzerLogger.logMessage('');
      QuizzerLogger.printHeader('=== FUNCTIONALITY TESTS ===');
      QuizzerLogger.logMessage('Multiple Choice Questions: ${testResults['multiple_choice_added'] == true ? 'PASS' : 'FAIL'} (${testResults['multiple_choice_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('True/False Questions: ${testResults['true_false_added'] == true ? 'PASS' : 'FAIL'} (${testResults['true_false_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('Select All That Apply Questions: ${testResults['select_all_added'] == true ? 'PASS' : 'FAIL'} (${testResults['select_all_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('Sort Order Questions: ${testResults['sort_order_added'] == true ? 'PASS' : 'FAIL'} (${testResults['sort_order_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('Module Creation: ${testResults['module_created'] == true ? 'PASS' : 'FAIL'} (4 initial modules created)');
      QuizzerLogger.logMessage('Bulk Question Creation: ${testResults['bulk_questions_added'] == true ? 'PASS' : 'FAIL'} (${testResults['bulk_questions_count'] ?? 0} questions)');
      QuizzerLogger.logMessage('Bulk Module Creation: ${testResults['bulk_modules_count'] == true ? 'PASS' : 'FAIL'} (${testResults['bulk_modules_count'] ?? 0} modules)');
      QuizzerLogger.logMessage('');
      QuizzerLogger.printHeader('=== PERFORMANCE METRICS ===');
      QuizzerLogger.logMessage('Average Add Question Time (Initial): ${averagePerformance.toStringAsFixed(1)}ms');
      QuizzerLogger.logMessage('Bulk Creation Time: ${testResults['bulk_performance_ms']}ms');
      QuizzerLogger.logMessage('Bulk Average Time Per Question: ${testResults['bulk_average_time_per_question']?.toStringAsFixed(1)}ms');
      QuizzerLogger.logMessage('Multiple Choice Performance: ${testResults['multiple_choice_performance_ms']}ms');
      QuizzerLogger.logMessage('True/False Performance: ${testResults['true_false_performance_ms']}ms');
      QuizzerLogger.logMessage('Select All Performance: ${testResults['select_all_performance_ms']}ms');
      QuizzerLogger.logMessage('Sort Order Performance: ${testResults['sort_order_performance_ms']}ms');
      QuizzerLogger.printHeader('=== END FINAL COMPREHENSIVE REPORT ===');
      
      QuizzerLogger.logSuccess('=== Test 8 completed successfully ===');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
