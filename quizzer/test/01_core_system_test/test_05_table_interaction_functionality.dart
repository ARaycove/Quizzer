import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_settings_table.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import '../test_expectations.dart';
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
  
  // Helper function to track test modules
  void trackTestModule(String moduleName) {
    if (!createdTestModules.contains(moduleName)) {
      createdTestModules.add(moduleName);
    }
  }
  
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
    
    // Perform login process for testing
    await performLoginProcess(
      email: testEmail, 
      password: testPassword, 
      supabase: sessionManager.supabase, 
      storage: sessionManager.getBox(testAccessPassword));
  });
  
  tearDownAll(() async {
    QuizzerLogger.logMessage('Cleaning up test modules from local database and Supabase after all tests complete...');
    if (createdTestModules.isNotEmpty) {
      await cleanupTestModules(createdTestModules);
      QuizzerLogger.logSuccess('Cleaned up ${createdTestModules.length} test modules from local database and Supabase');
    }
  });

  // Unit testing for local table interactions

  group('Question Answer Pairs Table Tests', () {    
    group('verifyQuestionAnswerPairTable Tests', () {
      test('Test 1: Should create table with correct schema when table does not exist', () async {
      QuizzerLogger.logMessage('Testing verifyQuestionAnswerPairTable - table creation');
      
      // Setup: Ensure clean state by deleting table if it exists
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db != null) {
        try {
          // Drop the table if it exists to test creation
          await db.execute('DROP TABLE IF EXISTS question_answer_pairs');
          await db.execute('DROP INDEX IF EXISTS idx_question_answer_pairs_module_name');
          await db.execute('DROP INDEX IF EXISTS idx_question_answer_pairs_question_id_unique');
          
          QuizzerLogger.logMessage('Cleaned up existing table and indexes');
        } finally {
          getDatabaseMonitor().releaseDatabaseAccess();
        }
      }
      
      // Execute: Call the verification function
      final db2 = await getDatabaseMonitor().requestDatabaseAccess();
      if (db2 != null) {
        try {
          await verifyQuestionAnswerPairTable(db2);
          
          // Verify: Check that table was created with correct schema
          final List<Map<String, dynamic>> tables = await db2.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='question_answer_pairs'"
          );
          expect(tables.length, equals(1), reason: 'Table should exist');
          
          // Check table structure
          final List<Map<String, dynamic>> columns = await db2.rawQuery(
            "PRAGMA table_info(question_answer_pairs)"
          );
          
          // Verify all required columns exist
          final List<String> columnNames = columns.map((col) => col['name'] as String).toList();
          
          expect(columnNames, contains('time_stamp'), reason: 'time_stamp column should exist');
          expect(columnNames, contains('question_elements'), reason: 'question_elements column should exist');
          expect(columnNames, contains('answer_elements'), reason: 'answer_elements column should exist');
          expect(columnNames, contains('ans_flagged'), reason: 'ans_flagged column should exist');
          expect(columnNames, contains('ans_contrib'), reason: 'ans_contrib column should exist');
          expect(columnNames, contains('qst_contrib'), reason: 'qst_contrib column should exist');
          expect(columnNames, contains('qst_reviewer'), reason: 'qst_reviewer column should exist');
          expect(columnNames, contains('has_been_reviewed'), reason: 'has_been_reviewed column should exist');
          expect(columnNames, contains('flag_for_removal'), reason: 'flag_for_removal column should exist');
          expect(columnNames, contains('module_name'), reason: 'module_name column should exist');
          expect(columnNames, contains('question_type'), reason: 'question_type column should exist');
          expect(columnNames, contains('options'), reason: 'options column should exist');
          expect(columnNames, contains('correct_option_index'), reason: 'correct_option_index column should exist');
          expect(columnNames, contains('question_id'), reason: 'question_id column should exist');
          expect(columnNames, contains('correct_order'), reason: 'correct_order column should exist');
          expect(columnNames, contains('index_options_that_apply'), reason: 'index_options_that_apply column should exist');
          expect(columnNames, contains('answers_to_blanks'), reason: 'answers_to_blanks column should exist');
          expect(columnNames, contains('has_been_synced'), reason: 'has_been_synced column should exist');
          expect(columnNames, contains('edits_are_synced'), reason: 'edits_are_synced column should exist');
          expect(columnNames, contains('last_modified_timestamp'), reason: 'last_modified_timestamp column should exist');
          expect(columnNames, contains('has_media'), reason: 'has_media column should exist');
          
          // Check that indexes were created
          final List<Map<String, dynamic>> indexes = await db2.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='question_answer_pairs'"
          );
          final List<String> indexNames = indexes.map((idx) => idx['name'] as String).toList();
          
          expect(indexNames, contains('idx_question_answer_pairs_module_name'), reason: 'module_name index should exist');
          // Note: question_id unique index is only created when table already exists, not on fresh creation
          
          QuizzerLogger.logSuccess('✅ verifyQuestionAnswerPairTable table creation test passed');
          
        } finally {
          getDatabaseMonitor().releaseDatabaseAccess();
        }
      }
      
      // Cleanup: Remove the test table
      final db3 = await getDatabaseMonitor().requestDatabaseAccess();
      if (db3 != null) {
        try {
          await db3.execute('DROP TABLE IF EXISTS question_answer_pairs');
          await db3.execute('DROP INDEX IF EXISTS idx_question_answer_pairs_module_name');
          await db3.execute('DROP INDEX IF EXISTS idx_question_answer_pairs_question_id_unique');
        } finally {
          getDatabaseMonitor().releaseDatabaseAccess();
        }
      }
    });
    });

    group('checkCompletionStatus Tests', () {
      final String validQuestionElements = generateFormattedElements(elementType: 'question', formatType: 'valid');
      final String validAnswerElements = generateFormattedElements(elementType: 'answer', formatType: 'valid');
      final String complexQuestionElements = generateFormattedElements(elementType: 'question', formatType: 'complex_valid', includeImage: true);
      final String complexAnswerElements = generateFormattedElements(elementType: 'answer', formatType: 'complex_valid', includeImage: true);
      final String malformedQuestionElements = generateFormattedElements(elementType: 'question', formatType: 'malformed_json');
      final String malformedAnswerElements = generateFormattedElements(elementType: 'answer', formatType: 'malformed_json');
      final String missingContentQuestionElements = generateFormattedElements(elementType: 'question', formatType: 'missing_content');
      final String emptyArrayQuestionElements = generateFormattedElements(elementType: 'question', formatType: 'empty_array');
      final String whitespaceContentQuestionElements = generateFormattedElements(elementType: 'question', formatType: 'whitespace_content');
      final String invalidStructureAnswerElements = generateFormattedElements(elementType: 'answer', formatType: 'invalid_structure');

      test('Test 1: Should return 1 when both question and answer elements are non-empty', () async {
        final int result = checkCompletionStatus(validQuestionElements, validAnswerElements);
        expect(result, equals(1), reason: 'Should return 1 when both question and answer elements are non-empty');
      });

      test('Test 2: Should return 0 when question_elements is empty', () async {
        final int result = checkCompletionStatus('', validAnswerElements);
        expect(result, equals(0), reason: 'Should return 0 when question_elements is empty');
      });

      test('Test 3: Should return 0 when answer_elements is empty', () async {
        final int result = checkCompletionStatus(validQuestionElements, '');
        expect(result, equals(0), reason: 'Should return 0 when answer_elements is empty');
      });

      test('Test 4: Should return 0 when both question and answer elements are empty', () async {
        final int result = checkCompletionStatus('', '');
        expect(result, equals(0), reason: 'Should return 0 when both question and answer elements are empty');
      });

      test('Test 5: Should return 1 for complex question and answer elements', () async {
        final int result = checkCompletionStatus(complexQuestionElements, complexAnswerElements);
        expect(result, equals(1), reason: 'Should return 1 for complex question and answer elements');
      });

      test('Test 6: Should return 0 for whitespace-only strings', () async {
        final int result = checkCompletionStatus('   ', '  \t\n  ');
        expect(result, equals(0), reason: 'Should return 0 for whitespace-only strings');
      });

      test('Test 7: Should return 0 when question elements have empty content', () async {
        final int result = checkCompletionStatus('[{"type": "text", "content": ""}]', validAnswerElements);
        expect(result, equals(0), reason: 'Should return 0 when question elements have empty content');
      });

      test('Test 8: Should return 0 for invalid JSON format', () async {
        final int result = checkCompletionStatus(validQuestionElements, invalidStructureAnswerElements);
        expect(result, equals(0), reason: 'Should return 0 for invalid JSON format');
      });

      test('Test 9: Should return 0 for malformed JSON', () async {
        final int result = checkCompletionStatus(malformedQuestionElements, malformedAnswerElements);
        expect(result, equals(0), reason: 'Should return 0 for malformed JSON');
      });

      test('Test 10: Should return 0 for empty JSON arrays', () async {
        final int result = checkCompletionStatus(emptyArrayQuestionElements, validAnswerElements);
        expect(result, equals(0), reason: 'Should return 0 for empty JSON arrays');
      });

      test('Test 11: Should return 0 when elements have whitespace-only content', () async {
        final int result = checkCompletionStatus(whitespaceContentQuestionElements, validAnswerElements);
        expect(result, equals(0), reason: 'Should return 0 when elements have whitespace-only content');
      });

      test('Test 12: Should return 0 when elements are missing content field', () async {
        final int result = checkCompletionStatus(missingContentQuestionElements, validAnswerElements);
        expect(result, equals(0), reason: 'Should return 0 when elements are missing content field');
      });
    });

    group('hasMediaCheck Tests', () {
      late Map<String, dynamic> textOnlyRecord;
      late Map<String, dynamic> questionWithImageRecord;
      late Map<String, dynamic> answerWithImageRecord;
      late Map<String, dynamic> bothWithImagesRecord;
      late Map<String, dynamic> invalidImageRecord;
      late Map<String, dynamic> emptyRecord;
      late Map<String, dynamic> blankElementRecord;
      late Map<String, dynamic> complexRecord;
      late Map<String, dynamic> malformedQuestionRecord;
      late Map<String, dynamic> malformedAnswerRecord;
      late Map<String, dynamic> invalidImagePathRecord;
      late Map<String, dynamic> absoluteImagePathRecord;
      late Map<String, dynamic> urlImagePathRecord;

      setUp(() {
        textOnlyRecord           = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 1, includeMedia: false)[0];
        questionWithImageRecord  = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 1, includeMedia: true)[0];
        answerWithImageRecord    = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 1, includeMedia: true)[0];
        bothWithImagesRecord     = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 1, includeMedia: true)[0];
        invalidImageRecord       = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 1, generateInvalidStructure: true)[0];
        emptyRecord              = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 1, generateEmptyRecord: true)[0];
        blankElementRecord       = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 1, questionType: 'fill_in_the_blank')[0];
        complexRecord            = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 1, includeMedia: true)[0];
        malformedQuestionRecord  = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 1, generateMalformedJson: true)[0];
        malformedAnswerRecord    = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 1, generateMalformedJson: true)[0];
        invalidImagePathRecord   = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 1, invalidImagePathType: 'directory')[0];
        absoluteImagePathRecord  = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 1, invalidImagePathType: 'absolute')[0];
        urlImagePathRecord       = generateCompleteQuestionAnswerPairRecord(numberOfQuestions: 1, invalidImagePathType: 'url')[0];
      });

      test('Test 1:   Should return false for text-only question record', () async {
        final bool result = await hasMediaCheck(textOnlyRecord);
        expect(result, isFalse, reason: 'Should return false for text-only question record');
      });
      test('Test 2:   Should return true when question contains image element', () async {
        final bool result = await hasMediaCheck(questionWithImageRecord);
        expect(result, isTrue, reason: 'Should return true when question contains image element');
      });
      test('Test 3:   Should return true when answer contains image element', () async {
        final bool result = await hasMediaCheck(answerWithImageRecord);
        expect(result, isTrue, reason: 'Should return true when answer contains image element');
      }); 
      test('Test 4:   Should return true when both question and answer contain images', () async {
        final bool result = await hasMediaCheck(bothWithImagesRecord);
        expect(result, isTrue, reason: 'Should return true when both question and answer contain images');
      });   
      test('Test 5:   Should return false for invalid structure with direct image field', () async {
        final bool result = await hasMediaCheck(invalidImageRecord);
        expect(result, isFalse, reason: 'Should return false for invalid structure with direct image field');
      });
      test('Test 6:   Should return false for empty question record', () async {
        final bool result = await hasMediaCheck(emptyRecord);
        expect(result, isFalse, reason: 'Should return false for empty question record');
      });
      test('Test 7:   Should return false for blank elements (not media)', () async {
        final bool result = await hasMediaCheck(blankElementRecord);
        expect(result, isFalse, reason: 'Should return false for blank elements (not media)');
      });
      test('Test 8:   Should return true for complex nested structure with media', () async {
        final bool result = await hasMediaCheck(complexRecord);
        expect(result, isTrue, reason: 'Should return true for complex nested structure with media');
      });
      test('Test 9:   Should return false for malformed JSON in question_elements', () async {
        final bool result = await hasMediaCheck(malformedQuestionRecord);
        expect(result, isFalse, reason: 'Should return false for malformed JSON in question_elements');
      });
      test('Test 10:  Should return false for malformed JSON in answer_elements', () async {
        final bool result = await hasMediaCheck(malformedAnswerRecord);
        expect(result, isFalse, reason: 'Should return false for malformed JSON in answer_elements');
      });
      test('Test 11:  Should return false for invalid image path with directory structure', () async {
        final bool result = await hasMediaCheck(invalidImagePathRecord);
        expect(result, isFalse, reason: 'Should return false for invalid image path with directory structure');
      });
      test('Test 12:  Should return false for absolute image path', () async {
        final bool result = await hasMediaCheck(absoluteImagePathRecord);
        expect(result, isFalse, reason: 'Should return false for absolute image path');
      });
      test('Test 13:  Should return false for URL image path', () async {
        final bool result = await hasMediaCheck(urlImagePathRecord);
        expect(result, isFalse, reason: 'Should return false for URL image path');
      });
    });

    // ==================================================
    // Add question calls:
    // ==================================================
    group('addQuestionMultipleChoice Tests', () {
      late Map<String, dynamic> validInputData;
      late Map<String, dynamic> mediaInputData;
      late Map<String, dynamic> complexOptionsInputData;
      late Map<String, dynamic> minimalInputData;

      setUp(() {
        validInputData = generateQuestionInputData(questionType: 'multiple_choice',numberOfQuestions: 1,numberOfModules: 1,numberOfOptions: 4)[0];
        
        mediaInputData = generateQuestionInputData(questionType: 'multiple_choice',numberOfQuestions: 1,          numberOfModules: 1,numberOfOptions: 4,includeMedia: true)[0];
        
        complexOptionsInputData = generateQuestionInputData(questionType: 'multiple_choice',numberOfQuestions: 1,numberOfModules: 1,numberOfOptions: 4,includeMedia: true)[0];
        
        minimalInputData = generateQuestionInputData(questionType: 'multiple_choice',numberOfQuestions: 1,numberOfModules: 1,numberOfOptions: 2)[0];
      });

      test('Test 1: Should create basic multiple choice question with all required fields', () async {
        final String questionId = await addQuestionMultipleChoice(moduleName: validInputData['moduleName'], questionElements: validInputData['questionElements'], answerElements: validInputData['answerElements'], options: validInputData['options'], correctOptionIndex: validInputData['correctOptionIndex'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify the question was created correctly
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['module_name'], equals(validInputData['moduleName'].toLowerCase()));
        expect(question['question_type'], equals('multiple_choice'));
        expect(question['correct_option_index'], equals(validInputData['correctOptionIndex']));
        expect(question['qst_contrib'], isNotEmpty, reason: 'Should have a contributor ID from session manager');
        expect(question['has_been_synced'], equals(0), reason: 'Should be marked as needing sync');
        expect(question['edits_are_synced'], equals(0), reason: 'Should be marked as needing sync');
        
        // Verify question and answer elements (already decoded by table functions)
        final List<dynamic> questionElements = question['question_elements'] as List<dynamic>;
        final List<dynamic> answerElements = question['answer_elements'] as List<dynamic>;
        expect(questionElements.length, equals(validInputData['questionElements'].length));
        expect(answerElements.length, equals(validInputData['answerElements'].length));
        
        // Verify options (already decoded by table functions)
        final List<dynamic> options = question['options'] as List<dynamic>;
        expect(options.length, equals(validInputData['options'].length));
      });
      test('Test 2: Should create multiple choice question with media elements', () async {
        final String questionId = await addQuestionMultipleChoice(moduleName: mediaInputData['moduleName'], questionElements: mediaInputData['questionElements'], answerElements: mediaInputData['answerElements'], options: mediaInputData['options'], correctOptionIndex: mediaInputData['correctOptionIndex'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify media detection
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['has_media'], equals(1), reason: 'Should detect media presence');
      });
      test('Test 3: Should create multiple choice question with complex options including media', () async {
        final String questionId = await addQuestionMultipleChoice(moduleName: complexOptionsInputData['moduleName'], questionElements: complexOptionsInputData['questionElements'], answerElements: complexOptionsInputData['answerElements'], options: complexOptionsInputData['options'], correctOptionIndex: complexOptionsInputData['correctOptionIndex'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify options with media
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['has_media'], equals(1), reason: 'Should detect media in options');
      });
      test('Test 4: Should create multiple choice question with correct option at first position', () async {
        final inputData = generateQuestionInputData(questionType: 'multiple_choice', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 4)[0];
        
        final String questionId = await addQuestionMultipleChoice(moduleName: inputData['moduleName'], questionElements: inputData['questionElements'], answerElements: inputData['answerElements'], options: inputData['options'], correctOptionIndex: 0, debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify correct option at index 0
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['correct_option_index'], equals(0));
      });
      test('Test 5: Should create multiple choice question with correct option at last position', () async {
        final inputData = generateQuestionInputData(questionType: 'multiple_choice', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 4)[0];
        
        final String questionId = await addQuestionMultipleChoice(moduleName: inputData['moduleName'], questionElements: inputData['questionElements'], answerElements: inputData['answerElements'], options: inputData['options'], correctOptionIndex: 3, debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify correct option at last index
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['correct_option_index'], equals(3));
      });
      test('Test 6: Should create multiple choice question with minimal content', () async {
        final String questionId = await addQuestionMultipleChoice(moduleName: minimalInputData['moduleName'], questionElements: minimalInputData['questionElements'], answerElements: minimalInputData['answerElements'], options: minimalInputData['options'], correctOptionIndex: minimalInputData['correctOptionIndex'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify minimal question works
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['question_id'], isNotEmpty, reason: 'Should have a valid question ID');
      });
      test('Test 7: Should throw error for invalid correct option index', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'invalid_option_index', questionType: 'multiple_choice', numberOfQuestions: 1)[0];
        
        expect(() => addQuestionMultipleChoice(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], options: malformedData['options'], correctOptionIndex: malformedData['correctOptionIndex'], debugDisableOutboundSyncCall: true),
          throwsA(isA<Exception>()),
          reason: 'Should throw error for invalid correct option index'
        );
      });
      test('Test 8: Should throw error for empty question elements (completion check fails)', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'empty_question_elements', questionType: 'multiple_choice', numberOfQuestions: 1)[0];
        
        expect(() => addQuestionMultipleChoice(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], options: malformedData['options'], correctOptionIndex: malformedData['correctOptionIndex'], debugDisableOutboundSyncCall: true),
          throwsA(isA<Exception>()),
          reason: 'Should throw error for incomplete question with empty question elements'
        );
      });
      test('Test 9: Should throw error for empty answer elements (completion check fails)', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'empty_answer_elements', questionType: 'multiple_choice', numberOfQuestions: 1)[0];
        
        expect(() => addQuestionMultipleChoice(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], options: malformedData['options'], correctOptionIndex: malformedData['correctOptionIndex'], debugDisableOutboundSyncCall: true),
          throwsA(isA<Exception>()),
          reason: 'Should throw error for incomplete question with empty answer elements'
        );
      });
      test('Test 10: Should throw error for empty options list', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'empty_options', questionType: 'multiple_choice', numberOfQuestions: 1)[0];
        
        expect(() => addQuestionMultipleChoice(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], options: malformedData['options'], correctOptionIndex: malformedData['correctOptionIndex'], debugDisableOutboundSyncCall: true),
          throwsA(isA<Exception>()),
          reason: 'Should throw error for empty options list'
        );
      });
      test('Test 11: Should throw error for negative correct option index', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'negative_option_index', questionType: 'multiple_choice', numberOfQuestions: 1)[0];
        
        expect(() => addQuestionMultipleChoice(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], options: malformedData['options'], correctOptionIndex: malformedData['correctOptionIndex'], debugDisableOutboundSyncCall: true),
          throwsA(isA<Exception>()),
          reason: 'Should throw error for negative correct option index'
        );
      });
      test('Test 12: Should throw error for empty module name', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'empty_module', questionType: 'multiple_choice', numberOfQuestions: 1)[0];
        
        expect(() => addQuestionMultipleChoice(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], options: malformedData['options'], correctOptionIndex: malformedData['correctOptionIndex'], debugDisableOutboundSyncCall: true),
          throwsA(isA<Exception>()),
          reason: 'Should throw error for empty module name'
        );
      });
      test('Test 13: Should succeed and trim module name whitespace', () async {
        final inputData = generateQuestionInputData(questionType: 'multiple_choice', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 2)[0];
        
        final String questionId = await addQuestionMultipleChoice(moduleName: '  ${inputData['moduleName']}  ', questionElements: inputData['questionElements'], answerElements: inputData['answerElements'], options: inputData['options'], correctOptionIndex: inputData['correctOptionIndex'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should succeed and trim module name whitespace');
        
        // Verify the trimmed module name was stored correctly
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['module_name'], equals(inputData['moduleName'].toLowerCase()), reason: 'Module name should be trimmed and normalized');
      });
      test('Test 14: Cleanup - Truncate question_answer_pairs table', () async {
        QuizzerLogger.logMessage('Cleaning up question_answer_pairs table after addQuestionMultipleChoice Tests');
        await deleteAllRecordsFromTable('question_answer_pairs');
        QuizzerLogger.logSuccess('Successfully cleaned up question_answer_pairs table after addQuestionMultipleChoice Tests');
      });
    });

    group('addQuestionSelectAllThatApply Tests', () {
      // Test data variables declared at the top of the group
      late Map<String, dynamic> validInputData;
      late Map<String, dynamic> mediaInputData;
      late Map<String, dynamic> complexOptionsInputData;
      late Map<String, dynamic> minimalInputData;
      
      setUp(() {
        // Initialize test data using helper functions
        validInputData = generateQuestionInputData(questionType: 'select_all_that_apply', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 4)[0];
        mediaInputData = generateQuestionInputData(questionType: 'select_all_that_apply', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 4, includeMedia: true)[0];
        complexOptionsInputData = generateQuestionInputData(questionType: 'select_all_that_apply', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 6, includeMedia: true)[0];
        minimalInputData = generateQuestionInputData(questionType: 'select_all_that_apply', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 2)[0];
      });
      
      test('Test 1: Should create basic select all that apply question with all required fields', () async {
        final String questionId = await addQuestionSelectAllThatApply(moduleName: validInputData['moduleName'], questionElements: validInputData['questionElements'], answerElements: validInputData['answerElements'], options: validInputData['options'], indexOptionsThatApply: validInputData['indexOptionsThatApply'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify the question was created correctly
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['module_name'], equals(validInputData['moduleName'].toLowerCase()));
        expect(question['question_type'], equals('select_all_that_apply'));
        expect(question['index_options_that_apply'], equals(validInputData['indexOptionsThatApply']));
        expect(question['qst_contrib'], isNotEmpty, reason: 'Should have a contributor ID from session manager');
        expect(question['has_been_synced'], equals(0), reason: 'Should be marked as needing sync');
        expect(question['edits_are_synced'], equals(0), reason: 'Should be marked as needing sync');
        
        // Verify question and answer elements (already decoded by table functions)
        final List<dynamic> questionElements = question['question_elements'] as List<dynamic>;
        final List<dynamic> answerElements = question['answer_elements'] as List<dynamic>;
        expect(questionElements.length, equals(validInputData['questionElements'].length));
        expect(answerElements.length, equals(validInputData['answerElements'].length));
        
        // Verify options (already decoded by table functions)
        final List<dynamic> options = question['options'] as List<dynamic>;
        expect(options.length, equals(validInputData['options'].length));
      });
      test('Test 2: Should create select all that apply question with media elements', () async {
        final String questionId = await addQuestionSelectAllThatApply(moduleName: mediaInputData['moduleName'], questionElements: mediaInputData['questionElements'], answerElements: mediaInputData['answerElements'], options: mediaInputData['options'], indexOptionsThatApply: mediaInputData['indexOptionsThatApply'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify media detection
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['has_media'], equals(1), reason: 'Should detect media presence');
      });
      test('Test 3: Should create select all that apply question with complex options including media', () async {
        final String questionId = await addQuestionSelectAllThatApply(moduleName: complexOptionsInputData['moduleName'], questionElements: complexOptionsInputData['questionElements'], answerElements: complexOptionsInputData['answerElements'], options: complexOptionsInputData['options'], indexOptionsThatApply: complexOptionsInputData['indexOptionsThatApply'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify options with media
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['has_media'], equals(1), reason: 'Should detect media in options');
      });
      test('Test 4: Should create select all that apply question with single correct option', () async {
        final inputData = generateQuestionInputData(questionType: 'select_all_that_apply', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 4)[0];
        
        final String questionId = await addQuestionSelectAllThatApply(moduleName: inputData['moduleName'], questionElements: inputData['questionElements'], answerElements: inputData['answerElements'], options: inputData['options'], indexOptionsThatApply: [0], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify single correct option
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['index_options_that_apply'], equals([0]));
      });
      test('Test 5: Should create select all that apply question with all options correct', () async {
        final inputData = generateQuestionInputData(questionType: 'select_all_that_apply', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 4)[0];
        
        final String questionId = await addQuestionSelectAllThatApply(moduleName: inputData['moduleName'], questionElements: inputData['questionElements'], answerElements: inputData['answerElements'], options: inputData['options'], indexOptionsThatApply: [0, 1, 2, 3], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify all options are correct
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['index_options_that_apply'], equals([0, 1, 2, 3]));
      });
      test('Test 6: Should create select all that apply question with minimal content', () async {
        final String questionId = await addQuestionSelectAllThatApply(moduleName: minimalInputData['moduleName'], questionElements: minimalInputData['questionElements'], answerElements: minimalInputData['answerElements'], options: minimalInputData['options'], indexOptionsThatApply: minimalInputData['indexOptionsThatApply'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify minimal question works
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['question_id'], isNotEmpty, reason: 'Should have a valid question ID');
      });
      test('Test 7: Should throw error for invalid option indices', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'invalid_option_index', questionType: 'select_all_that_apply', numberOfQuestions: 1)[0];
        
        expect(() => addQuestionSelectAllThatApply(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], options: malformedData['options'], indexOptionsThatApply: malformedData['indexOptionsThatApply'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for invalid option indices');
      });
      test('Test 8: Should throw error for empty question elements (completion check fails)', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'empty_question_elements', questionType: 'select_all_that_apply', numberOfQuestions: 1)[0];
        
        expect(() => addQuestionSelectAllThatApply(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], options: malformedData['options'], indexOptionsThatApply: malformedData['indexOptionsThatApply'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for incomplete question with empty question elements');
      });
      test('Test 9: Should throw error for empty answer elements (completion check fails)', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'empty_answer_elements', questionType: 'select_all_that_apply', numberOfQuestions: 1)[0];
        
        expect(() => addQuestionSelectAllThatApply(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], options: malformedData['options'], indexOptionsThatApply: malformedData['indexOptionsThatApply'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for incomplete question with empty answer elements');
      });
      test('Test 10: Should throw error for empty options list', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'empty_options', questionType: 'select_all_that_apply', numberOfQuestions: 1)[0];
        
        expect(() => addQuestionSelectAllThatApply(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], options: malformedData['options'], indexOptionsThatApply: malformedData['indexOptionsThatApply'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for empty options list');
      });
      test('Test 11: Should throw error for negative option indices', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'negative_option_index', questionType: 'select_all_that_apply', numberOfQuestions: 1)[0];
        
        expect(() => addQuestionSelectAllThatApply(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], options: malformedData['options'], indexOptionsThatApply: malformedData['indexOptionsThatApply'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for negative option indices');
      });
      test('Test 12: Should throw error for empty module name', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'empty_module', questionType: 'select_all_that_apply', numberOfQuestions: 1)[0];
        
        expect(() => addQuestionSelectAllThatApply(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], options: malformedData['options'], indexOptionsThatApply: malformedData['indexOptionsThatApply'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for empty module name');
      });
      test('Test 13: Should succeed and trim module name whitespace', () async {
        final inputData = generateQuestionInputData(questionType: 'select_all_that_apply', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 2)[0];
        
        final String questionId = await addQuestionSelectAllThatApply(moduleName: '  ${inputData['moduleName']}  ', questionElements: inputData['questionElements'], answerElements: inputData['answerElements'], options: inputData['options'], indexOptionsThatApply: inputData['indexOptionsThatApply'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should succeed and trim module name whitespace');
        
        // Verify the trimmed module name was stored correctly
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['module_name'], equals(inputData['moduleName'].toLowerCase()), reason: 'Module name should be trimmed and normalized');
      });
      test('Test 14: Cleanup - Truncate question_answer_pairs table', () async {
        QuizzerLogger.logMessage('Cleaning up question_answer_pairs table after addQuestionSelectAllThatApply Tests');
        await deleteAllRecordsFromTable('question_answer_pairs');
        QuizzerLogger.logSuccess('Successfully cleaned up question_answer_pairs table after addQuestionSelectAllThatApply Tests');
      });
    });
    
    group('addQuestionTrueFalse Tests', () {
      // Test data variables declared at the top of the group
      late Map<String, dynamic> validInputData;
      late Map<String, dynamic> mediaInputData;
      late Map<String, dynamic> falseInputData;
      late Map<String, dynamic> minimalInputData;
      
      setUp(() {
        // Initialize test data using helper functions
        validInputData = generateQuestionInputData(questionType: 'true_false', numberOfQuestions: 1, numberOfModules: 1)[0];
        mediaInputData = generateQuestionInputData(questionType: 'true_false', numberOfQuestions: 1, numberOfModules: 1, includeMedia: true)[0];
        falseInputData = generateQuestionInputData(questionType: 'true_false', numberOfQuestions: 1, numberOfModules: 1)[0];
        minimalInputData = generateQuestionInputData(questionType: 'true_false', numberOfQuestions: 1, numberOfModules: 1)[0];
      });
      
      test('Test 1: Should create basic true/false question with all required fields', () async {
        final String questionId = await addQuestionTrueFalse(moduleName: validInputData['moduleName'], questionElements: validInputData['questionElements'], answerElements: validInputData['answerElements'], correctOptionIndex: validInputData['correctOptionIndex'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify the question was created correctly
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['module_name'], equals(validInputData['moduleName'].toLowerCase()));
        expect(question['question_type'], equals('true_false'));
        expect(question['correct_option_index'], equals(validInputData['correctOptionIndex']));
        expect(question['qst_contrib'], isNotEmpty, reason: 'Should have a contributor ID from session manager');
        expect(question['has_been_synced'], equals(0), reason: 'Should be marked as needing sync');
        expect(question['edits_are_synced'], equals(0), reason: 'Should be marked as needing sync');
        
        // Verify question and answer elements (already decoded by table functions)
        final List<dynamic> questionElements = question['question_elements'] as List<dynamic>;
        final List<dynamic> answerElements = question['answer_elements'] as List<dynamic>;
        expect(questionElements.length, equals(validInputData['questionElements'].length));
        expect(answerElements.length, equals(validInputData['answerElements'].length));
      });
      
      test('Test 2: Should create true/false question with correct option as False', () async {
        final String questionId = await addQuestionTrueFalse(moduleName: falseInputData['moduleName'], questionElements: falseInputData['questionElements'], answerElements: falseInputData['answerElements'], correctOptionIndex: 1, debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify correct option is False
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['correct_option_index'], equals(1));
      });
      
      test('Test 3: Should create true/false question with media elements', () async {
        final String questionId = await addQuestionTrueFalse(moduleName: mediaInputData['moduleName'], questionElements: mediaInputData['questionElements'], answerElements: mediaInputData['answerElements'], correctOptionIndex: mediaInputData['correctOptionIndex'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify media detection
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['has_media'], equals(1), reason: 'Should detect media presence');
      });
      
      test('Test 4: Should create true/false question with minimal content', () async {
        final String questionId = await addQuestionTrueFalse(moduleName: minimalInputData['moduleName'], questionElements: minimalInputData['questionElements'], answerElements: minimalInputData['answerElements'], correctOptionIndex: minimalInputData['correctOptionIndex'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify minimal question works
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['question_id'], isNotEmpty, reason: 'Should have a valid question ID');
      });
      
      test('Test 5: Should throw error for invalid correct option index (negative)', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'negative_option_index', questionType: 'true_false', numberOfQuestions: 1)[0];
        
        expect(() => addQuestionTrueFalse(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], correctOptionIndex: malformedData['correctOptionIndex'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for negative correct option index');
      });
      
      test('Test 6: Should throw error for invalid correct option index (greater than 1)', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'invalid_option_index', questionType: 'true_false', numberOfQuestions: 1)[0];
        
        expect(() => addQuestionTrueFalse(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], correctOptionIndex: malformedData['correctOptionIndex'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for correct option index greater than 1');
      });
      
      test('Test 7: Should throw error for empty question elements (completion check fails)', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'empty_question_elements', questionType: 'true_false', numberOfQuestions: 1)[0];
        
        expect(() => addQuestionTrueFalse(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], correctOptionIndex: malformedData['correctOptionIndex'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for incomplete question with empty question elements');
      });
      
      test('Test 8: Should throw error for empty answer elements (completion check fails)', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'empty_answer_elements', questionType: 'true_false', numberOfQuestions: 1)[0];
        
        expect(() => addQuestionTrueFalse(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], correctOptionIndex: malformedData['correctOptionIndex'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for incomplete question with empty answer elements');
      });
      
      test('Test 9: Should throw error for empty module name', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'empty_module', questionType: 'true_false', numberOfQuestions: 1)[0];
        
        expect(() => addQuestionTrueFalse(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], correctOptionIndex: malformedData['correctOptionIndex'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for empty module name');
      });
      
      test('Test 10: Should succeed and trim module name whitespace', () async {
        final inputData = generateQuestionInputData(questionType: 'true_false', numberOfQuestions: 1, numberOfModules: 1)[0];
        
        final String questionId = await addQuestionTrueFalse(moduleName: '  ${inputData['moduleName']}  ', questionElements: inputData['questionElements'], answerElements: inputData['answerElements'], correctOptionIndex: inputData['correctOptionIndex'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should succeed and trim module name whitespace');
        
        // Verify the trimmed module name was stored correctly
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['module_name'], equals(inputData['moduleName'].toLowerCase()), reason: 'Module name should be trimmed and normalized');
      });
      
      test('Test 11: Cleanup - Truncate question_answer_pairs table', () async {
        QuizzerLogger.logMessage('Cleaning up question_answer_pairs table after addQuestionTrueFalse Tests');
        await deleteAllRecordsFromTable('question_answer_pairs');
        QuizzerLogger.logSuccess('Successfully cleaned up question_answer_pairs table after addQuestionTrueFalse Tests');
      });
    });

    group('addSortOrderQuestion Tests', () {
      // Test data variables declared at the top of the group
      late Map<String, dynamic> validInputData;
      late Map<String, dynamic> mediaInputData;
      late Map<String, dynamic> minimalInputData;
      late Map<String, dynamic> complexInputData;
      
      setUp(() {
        // Initialize test data using helper functions
        validInputData = generateQuestionInputData(questionType: 'sort_order', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 4)[0];
        mediaInputData = generateQuestionInputData(questionType: 'sort_order', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 3, includeMedia: true)[0];
        minimalInputData = generateQuestionInputData(questionType: 'sort_order', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 2)[0];
        complexInputData = generateQuestionInputData(questionType: 'sort_order', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 6, includeMedia: true)[0];
      });
      
      test('Test 1: Should create basic sort order question with all required fields', () async {
        final String questionId = await addSortOrderQuestion(moduleName: validInputData['moduleName'], questionElements: validInputData['questionElements'], answerElements: validInputData['answerElements'], options: validInputData['options'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify the question was created correctly
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['module_name'], equals(validInputData['moduleName'].toLowerCase()));
        expect(question['question_type'], equals('sort_order'));
        expect(question['qst_contrib'], isNotEmpty, reason: 'Should have a contributor ID from session manager');
        expect(question['has_been_synced'], equals(0), reason: 'Should be marked as needing sync');
        expect(question['edits_are_synced'], equals(0), reason: 'Should be marked as needing sync');
        
        // Verify question and answer elements (already decoded by table functions)
        final List<dynamic> questionElements = question['question_elements'] as List<dynamic>;
        final List<dynamic> answerElements = question['answer_elements'] as List<dynamic>;
        expect(questionElements.length, equals(validInputData['questionElements'].length));
        expect(answerElements.length, equals(validInputData['answerElements'].length));
        
        // Verify options (already decoded by table functions)
        final List<dynamic> options = question['options'] as List<dynamic>;
        expect(options.length, equals(validInputData['options'].length));
      });
      
      test('Test 2: Should create sort order question with media elements', () async {
        final String questionId = await addSortOrderQuestion(moduleName: mediaInputData['moduleName'], questionElements: mediaInputData['questionElements'], answerElements: mediaInputData['answerElements'], options: mediaInputData['options'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify media detection
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['has_media'], equals(1), reason: 'Should detect media presence');
      });
      
      test('Test 3: Should create sort order question with minimal options (2 items)', () async {
        final String questionId = await addSortOrderQuestion(moduleName: minimalInputData['moduleName'], questionElements: minimalInputData['questionElements'], answerElements: minimalInputData['answerElements'], options: minimalInputData['options'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify options
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        final List<dynamic> options = question['options'] as List<dynamic>;
        expect(options.length, equals(2));
      });
      
      test('Test 4: Should create sort order question with complex options including media', () async {
        final String questionId = await addSortOrderQuestion(moduleName: complexInputData['moduleName'], questionElements: complexInputData['questionElements'], answerElements: complexInputData['answerElements'], options: complexInputData['options'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify options with media
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['has_media'], equals(1), reason: 'Should detect media in options');
        final List<dynamic> options = question['options'] as List<dynamic>;
        expect(options.length, equals(6));
      });
      
      test('Test 5: Should create sort order question with minimal content', () async {
        final inputData = generateQuestionInputData(questionType: 'sort_order', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 2)[0];
        
        final String questionId = await addSortOrderQuestion(moduleName: inputData['moduleName'], questionElements: inputData['questionElements'], answerElements: inputData['answerElements'], options: inputData['options'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify minimal question works
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['question_id'], isNotEmpty, reason: 'Should have a valid question ID');
      });
      
      test('Test 6: Should throw error for empty options list', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'empty_options', questionType: 'sort_order', numberOfQuestions: 1)[0];
        
        expect(() => addSortOrderQuestion(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], options: malformedData['options'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for empty options list');
      });
      
      test('Test 7: Should throw error for empty question elements (completion check fails)', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'empty_question_elements', questionType: 'sort_order', numberOfQuestions: 1)[0];
        
        expect(() => addSortOrderQuestion(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], options: malformedData['options'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for incomplete question with empty question elements');
      });
      
      test('Test 8: Should throw error for empty answer elements (completion check fails)', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'empty_answer_elements', questionType: 'sort_order', numberOfQuestions: 1)[0];
        
        expect(() => addSortOrderQuestion(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], options: malformedData['options'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for incomplete question with empty answer elements');
      });
      
      test('Test 9: Should throw error for empty module name', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'empty_module', questionType: 'sort_order', numberOfQuestions: 1)[0];
        
        expect(() => addSortOrderQuestion(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], options: malformedData['options'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for empty module name');
      });
      
      test('Test 10: Should succeed and trim module name whitespace', () async {
        final inputData = generateQuestionInputData(questionType: 'sort_order', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 3)[0];
        
        final String questionId = await addSortOrderQuestion(moduleName: '  ${inputData['moduleName']}  ', questionElements: inputData['questionElements'], answerElements: inputData['answerElements'], options: inputData['options'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should succeed and trim module name whitespace');
        
        // Verify the trimmed module name was stored correctly
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['module_name'], equals(inputData['moduleName'].toLowerCase()), reason: 'Module name should be trimmed and normalized');
      });
      
      test('Test 11: Cleanup - Truncate question_answer_pairs table', () async {
        QuizzerLogger.logMessage('Cleaning up question_answer_pairs table after addSortOrderQuestion Tests');
        await deleteAllRecordsFromTable('question_answer_pairs');
        QuizzerLogger.logSuccess('Successfully cleaned up question_answer_pairs table after addSortOrderQuestion Tests');
      });
    });

    group('addFillInTheBlankQuestion Tests', () {
      // Test data variables declared at the top of the group
      late Map<String, dynamic> validInputData;
      late Map<String, dynamic> mediaInputData;
      late Map<String, dynamic> multipleBlanksInputData;
      late Map<String, dynamic> minimalInputData;
      
      setUp(() {
        // Initialize test data using helper functions
        validInputData = generateQuestionInputData(questionType: 'fill_in_the_blank', numberOfQuestions: 1, numberOfModules: 1, numberOfBlanks: 1, numberOfSynonymsPerBlank: 2)[0];
        mediaInputData = generateQuestionInputData(questionType: 'fill_in_the_blank', numberOfQuestions: 1, numberOfModules: 1, numberOfBlanks: 1, numberOfSynonymsPerBlank: 2, includeMedia: true)[0];
        multipleBlanksInputData = generateQuestionInputData(questionType: 'fill_in_the_blank', numberOfQuestions: 1, numberOfModules: 1, numberOfBlanks: 3, numberOfSynonymsPerBlank: 3)[0];
        minimalInputData = generateQuestionInputData(questionType: 'fill_in_the_blank', numberOfQuestions: 1, numberOfModules: 1, numberOfBlanks: 1, numberOfSynonymsPerBlank: 1)[0];
      });
      
      test('Test 1: Should create basic fill in the blank question with all required fields', () async {
        final String questionId = await addFillInTheBlankQuestion(moduleName: validInputData['moduleName'], questionElements: validInputData['questionElements'], answerElements: validInputData['answerElements'], answersToBlanks: validInputData['answersToBlanks'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify the question was created correctly
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['module_name'], equals(validInputData['moduleName'].toLowerCase()));
        expect(question['question_type'], equals('fill_in_the_blank'));
        expect(question['qst_contrib'], isNotEmpty, reason: 'Should have a contributor ID from session manager');
        expect(question['has_been_synced'], equals(0), reason: 'Should be marked as needing sync');
        expect(question['edits_are_synced'], equals(0), reason: 'Should be marked as needing sync');
                // Verify question and answer elements (already decoded by table functions)
        final List<dynamic> questionElements = question['question_elements'] as List<dynamic>;
        final List<dynamic> answerElements = question['answer_elements'] as List<dynamic>;
        expect(questionElements.length, equals(validInputData['questionElements'].length));
        expect(answerElements.length, equals(validInputData['answerElements'].length));
        
        // Verify answers to blanks (already decoded by table functions)
        final List<dynamic> answersToBlanks = question['answers_to_blanks'] as List<dynamic>;
        expect(answersToBlanks.length, equals(validInputData['answersToBlanks'].length));
      });
      
      test('Test 2: Should create fill in the blank question with media elements', () async {
        final String questionId = await addFillInTheBlankQuestion(moduleName: mediaInputData['moduleName'], questionElements: mediaInputData['questionElements'], answerElements: mediaInputData['answerElements'], answersToBlanks: mediaInputData['answersToBlanks'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify media detection
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['has_media'], equals(1), reason: 'Should detect media presence');
      });
      
      test('Test 3: Should create fill in the blank question with multiple blanks and synonyms', () async {
        final String questionId = await addFillInTheBlankQuestion(moduleName: multipleBlanksInputData['moduleName'], questionElements: multipleBlanksInputData['questionElements'], answerElements: multipleBlanksInputData['answerElements'], answersToBlanks: multipleBlanksInputData['answersToBlanks'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify multiple blanks
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        final List<dynamic> answersToBlanks = question['answers_to_blanks'] as List<dynamic>;
        expect(answersToBlanks.length, equals(3), reason: 'Should have 3 answer groups');
      });
      
      test('Test 4: Should create fill in the blank question with minimal content', () async {
        final String questionId = await addFillInTheBlankQuestion(moduleName: minimalInputData['moduleName'], questionElements: minimalInputData['questionElements'], answerElements: minimalInputData['answerElements'], answersToBlanks: minimalInputData['answersToBlanks'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should return a valid question ID');
        
        // Verify minimal question works
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['question_id'], isNotEmpty, reason: 'Should have a valid question ID');
      });
      
      test('Test 5: Should throw error for empty answers to blanks list', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'empty_answers_to_blanks', questionType: 'fill_in_the_blank', numberOfQuestions: 1)[0];
        
        expect(() => addFillInTheBlankQuestion(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], answersToBlanks: malformedData['answersToBlanks'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for empty answers to blanks list');
      });
      
      test('Test 6: Should throw error for missing blank elements in question', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'missing_blank_elements', questionType: 'fill_in_the_blank', numberOfQuestions: 1)[0];
        
        expect(() => addFillInTheBlankQuestion(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], answersToBlanks: malformedData['answersToBlanks'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for missing blank elements in question');
      });
      
      test('Test 7: Should throw error for mismatched number of blanks and answers', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'mismatched_blanks', questionType: 'fill_in_the_blank', numberOfQuestions: 1)[0];
        
        expect(() => addFillInTheBlankQuestion(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], answersToBlanks: malformedData['answersToBlanks'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for mismatched number of blanks and answers');
      });
      
      test('Test 8: Should throw error for empty question elements (completion check fails)', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'empty_question_elements', questionType: 'fill_in_the_blank', numberOfQuestions: 1)[0];
        
        expect(() => addFillInTheBlankQuestion(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], answersToBlanks: malformedData['answersToBlanks'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for incomplete question with empty question elements');
      });
      
      test('Test 9: Should throw error for empty answer elements (completion check fails)', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'empty_answer_elements', questionType: 'fill_in_the_blank', numberOfQuestions: 1)[0];
        
        expect(() => addFillInTheBlankQuestion(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], answersToBlanks: malformedData['answersToBlanks'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for incomplete question with empty answer elements');
      });
      
      test('Test 10: Should throw error for empty module name', () async {
        final malformedData = generateMalformedQuestionData(malformationType: 'empty_module', questionType: 'fill_in_the_blank', numberOfQuestions: 1)[0];
        
        expect(() => addFillInTheBlankQuestion(moduleName: malformedData['moduleName'], questionElements: malformedData['questionElements'], answerElements: malformedData['answerElements'], answersToBlanks: malformedData['answersToBlanks'], debugDisableOutboundSyncCall: true), throwsA(isA<Exception>()), reason: 'Should throw error for empty module name');
      });
      
      test('Test 11: Should succeed and trim module name whitespace', () async {
        final inputData = generateQuestionInputData(questionType: 'fill_in_the_blank', numberOfQuestions: 1, numberOfModules: 1, numberOfBlanks: 1, numberOfSynonymsPerBlank: 2)[0];
        
        final String questionId = await addFillInTheBlankQuestion(moduleName: '  ${inputData['moduleName']}  ', questionElements: inputData['questionElements'], answerElements: inputData['answerElements'], answersToBlanks: inputData['answersToBlanks'], debugDisableOutboundSyncCall: true);
        
        expect(questionId, isNotEmpty, reason: 'Should succeed and trim module name whitespace');
        
        // Verify the trimmed module name was stored correctly
        final Map<String, dynamic> question = await getQuestionAnswerPairById(questionId);
        expect(question['module_name'], equals(inputData['moduleName'].toLowerCase()), reason: 'Module name should be trimmed and normalized');
      });
      
      test('Test 12: Cleanup - Truncate question_answer_pairs table', () async {
        QuizzerLogger.logMessage('Cleaning up question_answer_pairs table after addFillInTheBlankQuestion Tests');
        await deleteAllRecordsFromTable('question_answer_pairs');
        QuizzerLogger.logSuccess('Successfully cleaned up question_answer_pairs table after addFillInTheBlankQuestion Tests');
      });
    });
    
    // ==================================================
    // Read and Update:
    // ==================================================

    group('getQuestionAnswerPairById Tests', () {
      // Test data variables declared at the top of the group
      late String multipleChoiceQuestionId;
      late String selectAllQuestionId;
      late String trueFalseQuestionId;
      late String sortOrderQuestionId;
      late String fillInBlankQuestionId;
      
      setUp(() async {
        // Create questions of each type for testing retrieval
        final multipleChoiceData = generateQuestionInputData(questionType: 'multiple_choice', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 4, includeMedia: true)[0];
        trackTestModule(multipleChoiceData['moduleName']);
        multipleChoiceQuestionId = await addQuestionMultipleChoice(moduleName: multipleChoiceData['moduleName'], questionElements: multipleChoiceData['questionElements'], answerElements: multipleChoiceData['answerElements'], options: multipleChoiceData['options'], correctOptionIndex: multipleChoiceData['correctOptionIndex'], debugDisableOutboundSyncCall: true);
        
        final selectAllData = generateQuestionInputData(questionType: 'select_all_that_apply', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 4)[0];
        trackTestModule(selectAllData['moduleName']);
        selectAllQuestionId = await addQuestionSelectAllThatApply(moduleName: selectAllData['moduleName'], questionElements: selectAllData['questionElements'], answerElements: selectAllData['answerElements'], options: selectAllData['options'], indexOptionsThatApply: selectAllData['indexOptionsThatApply'], debugDisableOutboundSyncCall: true);
        
        final trueFalseData = generateQuestionInputData(questionType: 'true_false', numberOfQuestions: 1, numberOfModules: 1)[0];
        trackTestModule(trueFalseData['moduleName']);
        trueFalseQuestionId = await addQuestionTrueFalse(moduleName: trueFalseData['moduleName'], questionElements: trueFalseData['questionElements'], answerElements: trueFalseData['answerElements'], correctOptionIndex: trueFalseData['correctOptionIndex'], debugDisableOutboundSyncCall: true);
        
        final sortOrderData = generateQuestionInputData(questionType: 'sort_order', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 4)[0];
        trackTestModule(sortOrderData['moduleName']);
        sortOrderQuestionId = await addSortOrderQuestion(moduleName: sortOrderData['moduleName'], questionElements: sortOrderData['questionElements'], answerElements: sortOrderData['answerElements'], options: sortOrderData['options'], debugDisableOutboundSyncCall: true);
        
        final fillInBlankData = generateQuestionInputData(questionType: 'fill_in_the_blank', numberOfQuestions: 1, numberOfModules: 1, numberOfBlanks: 1, numberOfSynonymsPerBlank: 2)[0];
        trackTestModule(fillInBlankData['moduleName']);
        fillInBlankQuestionId = await addFillInTheBlankQuestion(moduleName: fillInBlankData['moduleName'], questionElements: fillInBlankData['questionElements'], answerElements: fillInBlankData['answerElements'], answersToBlanks: fillInBlankData['answersToBlanks'], debugDisableOutboundSyncCall: true);
      });
      
      test('Test 1: Should retrieve multiple choice question by ID', () async {
        final Map<String, dynamic> retrievedQuestion = await getQuestionAnswerPairById(multipleChoiceQuestionId);
        
        // Verify all fields match what was created
        expect(retrievedQuestion['question_id'], equals(multipleChoiceQuestionId));
        expect(retrievedQuestion['module_name'], equals('testmodule0'));
        expect(retrievedQuestion['question_type'], equals('multiple_choice'));
        expect(retrievedQuestion['correct_option_index'], equals(0));
        expect(retrievedQuestion['has_been_synced'], equals(0));
        expect(retrievedQuestion['edits_are_synced'], equals(0));
        expect(retrievedQuestion['has_media'], equals(1));
        
        // Verify question and answer elements are properly decoded
        final List<dynamic> questionElements = retrievedQuestion['question_elements'] as List<dynamic>;
        final List<dynamic> answerElements = retrievedQuestion['answer_elements'] as List<dynamic>;
        final List<dynamic> options = retrievedQuestion['options'] as List<dynamic>;
        
        expect(questionElements, isNotEmpty);
        expect(answerElements, isNotEmpty);
        expect(options.length, greaterThan(0));
      });
      
      test('Test 2: Should retrieve select all that apply question by ID', () async {
        final Map<String, dynamic> retrievedQuestion = await getQuestionAnswerPairById(selectAllQuestionId);
        
        // Verify all fields match what was created
        expect(retrievedQuestion['question_id'], equals(selectAllQuestionId));
        expect(retrievedQuestion['module_name'], equals('testmodule0'));
        expect(retrievedQuestion['question_type'], equals('select_all_that_apply'));
        expect(retrievedQuestion['has_been_synced'], equals(0));
        expect(retrievedQuestion['edits_are_synced'], equals(0));
        expect(retrievedQuestion['has_media'], equals(0));
        
        // Verify question and answer elements are properly decoded
        final List<dynamic> questionElements = retrievedQuestion['question_elements'] as List<dynamic>;
        final List<dynamic> answerElements = retrievedQuestion['answer_elements'] as List<dynamic>;
        final List<dynamic> options = retrievedQuestion['options'] as List<dynamic>;
        final List<dynamic> indexOptionsThatApply = retrievedQuestion['index_options_that_apply'] as List<dynamic>;
        
        expect(questionElements, isNotEmpty);
        expect(answerElements, isNotEmpty);
        expect(options.length, greaterThan(0));
        expect(indexOptionsThatApply, isNotEmpty);
      });
      
      test('Test 3: Should retrieve true/false question by ID', () async {
        final Map<String, dynamic> retrievedQuestion = await getQuestionAnswerPairById(trueFalseQuestionId);
        
        // Verify all fields match what was created
        expect(retrievedQuestion['question_id'], equals(trueFalseQuestionId));
        expect(retrievedQuestion['module_name'], equals('testmodule0'));
        expect(retrievedQuestion['question_type'], equals('true_false'));
        expect(retrievedQuestion['correct_option_index'], equals(0));
        expect(retrievedQuestion['has_been_synced'], equals(0));
        expect(retrievedQuestion['edits_are_synced'], equals(0));
        expect(retrievedQuestion['has_media'], equals(0));
        
        // Verify question and answer elements are properly decoded
        final List<dynamic> questionElements = retrievedQuestion['question_elements'] as List<dynamic>;
        final List<dynamic> answerElements = retrievedQuestion['answer_elements'] as List<dynamic>;
        
        expect(questionElements, isNotEmpty);
        expect(answerElements, isNotEmpty);
        expect(retrievedQuestion['options'], isNull); // True/false questions don't have options
      });
      
      test('Test 4: Should retrieve sort order question by ID', () async {
        final Map<String, dynamic> retrievedQuestion = await getQuestionAnswerPairById(sortOrderQuestionId);
        
        // Verify all fields match what was created
        expect(retrievedQuestion['question_id'], equals(sortOrderQuestionId));
        expect(retrievedQuestion['module_name'], equals('testmodule0'));
        expect(retrievedQuestion['question_type'], equals('sort_order'));
        expect(retrievedQuestion['has_been_synced'], equals(0));
        expect(retrievedQuestion['edits_are_synced'], equals(0));
        expect(retrievedQuestion['has_media'], equals(0));
        
        // Verify question and answer elements are properly decoded
        final List<dynamic> questionElements = retrievedQuestion['question_elements'] as List<dynamic>;
        final List<dynamic> answerElements = retrievedQuestion['answer_elements'] as List<dynamic>;
        final List<dynamic> options = retrievedQuestion['options'] as List<dynamic>;
        
        expect(questionElements, isNotEmpty);
        expect(answerElements, isNotEmpty);
        expect(options.length, greaterThan(0));
        expect(retrievedQuestion['correct_order'], isNull); // Sort order questions don't use correct_order field
      });
      
      test('Test 5: Should retrieve fill in the blank question by ID', () async {
        final Map<String, dynamic> retrievedQuestion = await getQuestionAnswerPairById(fillInBlankQuestionId);
        
        // Verify all fields match what was created
        expect(retrievedQuestion['question_id'], equals(fillInBlankQuestionId));
        expect(retrievedQuestion['module_name'], equals('testmodule0'));
        expect(retrievedQuestion['question_type'], equals('fill_in_the_blank'));
        expect(retrievedQuestion['has_been_synced'], equals(0));
        expect(retrievedQuestion['edits_are_synced'], equals(0));
        expect(retrievedQuestion['has_media'], equals(0));
        
        // Verify question and answer elements are properly decoded
        final List<dynamic> questionElements = retrievedQuestion['question_elements'] as List<dynamic>;
        final List<dynamic> answerElements = retrievedQuestion['answer_elements'] as List<dynamic>;
        final List<dynamic> answersToBlanks = retrievedQuestion['answers_to_blanks'] as List<dynamic>;
        
        expect(questionElements, isNotEmpty);
        expect(answerElements, isNotEmpty);
        expect(answersToBlanks.length, equals(1));
      });
      
      test('Test 6: Should throw error for non-existent question ID', () async {
        expect(() => getQuestionAnswerPairById('non_existent_id_12345'), throwsA(isA<StateError>()), reason: 'Should throw error for non-existent question ID');
      });
      
      test('Test 7: Should throw error for empty question ID', () async {
        expect(() => getQuestionAnswerPairById(''), throwsA(isA<StateError>()), reason: 'Should throw error for empty question ID');
      });
      
      test('Test 8: Cleanup - Truncate question_answer_pairs table', () async {
        QuizzerLogger.logMessage('Cleaning up question_answer_pairs table after getQuestionAnswerPairById Tests');
        await deleteAllRecordsFromTable('question_answer_pairs');
        QuizzerLogger.logSuccess('Successfully cleaned up question_answer_pairs table after getQuestionAnswerPairById Tests');
      });
    });

    group('editQuestionAnswerPair Tests', () {
      // Test data variables declared at the top of the group
      late String multipleChoiceQuestionId;
      late String selectAllQuestionId;
      late String trueFalseQuestionId;
      late String sortOrderQuestionId;
      late String fillInBlankQuestionId;
      
      setUp(() async {
        // Create questions of each type for testing editing
        final multipleChoiceData = generateQuestionInputData(questionType: 'multiple_choice', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 4)[0];
        multipleChoiceQuestionId = await addQuestionMultipleChoice(moduleName: multipleChoiceData['moduleName'], questionElements: multipleChoiceData['questionElements'], answerElements: multipleChoiceData['answerElements'], options: multipleChoiceData['options'], correctOptionIndex: multipleChoiceData['correctOptionIndex'], debugDisableOutboundSyncCall: true);
        
        final selectAllData = generateQuestionInputData(questionType: 'select_all_that_apply', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 4)[0];
        selectAllQuestionId = await addQuestionSelectAllThatApply(moduleName: selectAllData['moduleName'], questionElements: selectAllData['questionElements'], answerElements: selectAllData['answerElements'], options: selectAllData['options'], indexOptionsThatApply: selectAllData['indexOptionsThatApply'], debugDisableOutboundSyncCall: true);
        
        final trueFalseData = generateQuestionInputData(questionType: 'true_false', numberOfQuestions: 1, numberOfModules: 1)[0];
        trueFalseQuestionId = await addQuestionTrueFalse(moduleName: trueFalseData['moduleName'], questionElements: trueFalseData['questionElements'], answerElements: trueFalseData['answerElements'], correctOptionIndex: trueFalseData['correctOptionIndex'], debugDisableOutboundSyncCall: true);
        
        final sortOrderData = generateQuestionInputData(questionType: 'sort_order', numberOfQuestions: 1, numberOfModules: 1, numberOfOptions: 4)[0];
        sortOrderQuestionId = await addSortOrderQuestion(moduleName: sortOrderData['moduleName'], questionElements: sortOrderData['questionElements'], answerElements: sortOrderData['answerElements'], options: sortOrderData['options'], debugDisableOutboundSyncCall: true);
        
        final fillInBlankData = generateQuestionInputData(questionType: 'fill_in_the_blank', numberOfQuestions: 1, numberOfModules: 1, numberOfBlanks: 1, numberOfSynonymsPerBlank: 2)[0];
        fillInBlankQuestionId = await addFillInTheBlankQuestion(moduleName: fillInBlankData['moduleName'], questionElements: fillInBlankData['questionElements'], answerElements: fillInBlankData['answerElements'], answersToBlanks: fillInBlankData['answersToBlanks'], debugDisableOutboundSyncCall: true);
      });
      
      test('Test 1: Should edit question elements for multiple choice question', () async {
        final int result = await editQuestionAnswerPair(questionId: multipleChoiceQuestionId, questionElements: [{'type': 'text', 'content': 'Updated question text'}], debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(multipleChoiceQuestionId);
        final List<dynamic> questionElements = question['question_elements'] as List<dynamic>;
        expect(questionElements[0]['content'], equals('Updated question text'));
      });
      
      test('Test 2: Should edit answer elements for multiple choice question', () async {
        final int result = await editQuestionAnswerPair(questionId: multipleChoiceQuestionId, answerElements: [{'type': 'text', 'content': 'Updated answer text'}], debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(multipleChoiceQuestionId);
        final List<dynamic> answerElements = question['answer_elements'] as List<dynamic>;
        expect(answerElements[0]['content'], equals('Updated answer text'));
      });
      
      test('Test 3: Should edit options for multiple choice question', () async {
        final int result = await editQuestionAnswerPair(questionId: multipleChoiceQuestionId, options: [{'type': 'text', 'content': 'Updated Option A'}, {'type': 'text', 'content': 'Updated Option B'}, {'type': 'text', 'content': 'Updated Option C'}, {'type': 'text', 'content': 'Updated Option D'}], correctOptionIndex: 2, debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(multipleChoiceQuestionId);
        final List<dynamic> options = question['options'] as List<dynamic>;
        expect(options[0]['content'], equals('Updated Option A'));
        expect(options[2]['content'], equals('Updated Option C'));
        expect(question['correct_option_index'], equals(2));
      });
      
      test('Test 4: Should edit module name and normalize it', () async {
        final int result = await editQuestionAnswerPair(questionId: multipleChoiceQuestionId, moduleName: 'NEW_MODULE_NAME', debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(multipleChoiceQuestionId);
        expect(question['module_name'], equals('new module name'));
      });
      
      test('Test 5: Should edit question elements for select all that apply question', () async {
        final int result = await editQuestionAnswerPair(questionId: selectAllQuestionId, questionElements: [{'type': 'text', 'content': 'Updated select all question'}], debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(selectAllQuestionId);
        final List<dynamic> questionElements = question['question_elements'] as List<dynamic>;
        expect(questionElements[0]['content'], equals('Updated select all question'));
      });
      
      test('Test 6: Should edit options and index options that apply for select all question', () async {
        final int result = await editQuestionAnswerPair(questionId: selectAllQuestionId, options: [{'type': 'text', 'content': 'New Option 1'}, {'type': 'text', 'content': 'New Option 2'}, {'type': 'text', 'content': 'New Option 3'}], indexOptionsThatApply: [0, 2], debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(selectAllQuestionId);
        final List<dynamic> options = question['options'] as List<dynamic>;
        final List<dynamic> indexOptionsThatApply = question['index_options_that_apply'] as List<dynamic>;
        expect(options[0]['content'], equals('New Option 1'));
        expect(indexOptionsThatApply, contains(0));
        expect(indexOptionsThatApply, contains(2));
      });
      
      test('Test 7: Should edit question elements for true/false question', () async {
        final int result = await editQuestionAnswerPair(questionId: trueFalseQuestionId, questionElements: [{'type': 'text', 'content': 'Updated true/false question'}], debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(trueFalseQuestionId);
        final List<dynamic> questionElements = question['question_elements'] as List<dynamic>;
        expect(questionElements[0]['content'], equals('Updated true/false question'));
      });
      
      test('Test 8: Should edit correct option index for true/false question', () async {
        final int result = await editQuestionAnswerPair(questionId: trueFalseQuestionId, correctOptionIndex: 1, debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(trueFalseQuestionId);
        expect(question['correct_option_index'], equals(1));
      });
      
      test('Test 9: Should edit question elements for sort order question', () async {
        final int result = await editQuestionAnswerPair(questionId: sortOrderQuestionId, questionElements: [{'type': 'text', 'content': 'Updated sort order question'}], debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(sortOrderQuestionId);
        final List<dynamic> questionElements = question['question_elements'] as List<dynamic>;
        expect(questionElements[0]['content'], equals('Updated sort order question'));
      });
      
      test('Test 10: Should edit options for sort order question', () async {
        final int result = await editQuestionAnswerPair(questionId: sortOrderQuestionId, options: [{'type': 'text', 'content': 'First'}, {'type': 'text', 'content': 'Second'}, {'type': 'text', 'content': 'Third'}], debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(sortOrderQuestionId);
        final List<dynamic> options = question['options'] as List<dynamic>;
        expect(options[0]['content'], equals('First'));
        expect(options[1]['content'], equals('Second'));
        expect(options[2]['content'], equals('Third'));
      });
      
      test('Test 11: Should edit question elements for fill in the blank question', () async {
        final int result = await editQuestionAnswerPair(questionId: fillInBlankQuestionId, questionElements: [{'type': 'text', 'content': 'Updated fill in the blank question'}, {'type': 'blank', 'content': '10'}, {'type': 'text', 'content': 'end'}], debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(fillInBlankQuestionId);
        final List<dynamic> questionElements = question['question_elements'] as List<dynamic>;
        expect(questionElements[0]['content'], equals('Updated fill in the blank question'));
        expect(questionElements[1]['type'], equals('blank'));
        expect(questionElements[1]['content'], equals('10'));
      });
      
      test('Test 12: Should edit answers to blanks for fill in the blank question', () async {
        final int result = await editQuestionAnswerPair(questionId: fillInBlankQuestionId, answersToBlanks: [{'Updated Answer': ['updated', 'answer', 'synonyms']}], debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(fillInBlankQuestionId);
        final List<dynamic> answersToBlanks = question['answers_to_blanks'] as List<dynamic>;
        final List<dynamic> synonyms = answersToBlanks[0]['Updated Answer'] as List<dynamic>;
        expect(synonyms, contains('updated'));
        expect(synonyms, contains('answer'));
        expect(synonyms, contains('synonyms'));
      });
      
      test('Test 13: Should update sync flags when editing', () async {
        final int result = await editQuestionAnswerPair(questionId: multipleChoiceQuestionId, questionElements: [{'type': 'text', 'content': 'Sync test question'}], debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(multipleChoiceQuestionId);
        expect(question['edits_are_synced'], equals(0), reason: 'Edits should be marked as unsynced after editing');
      });
      
      test('Test 14: Should update last modified timestamp when editing', () async {
        final String originalTimestamp = (await getQuestionAnswerPairById(multipleChoiceQuestionId))['last_modified_timestamp'] as String;
        
        // Wait a moment to ensure timestamp difference
        await Future.delayed(const Duration(milliseconds: 100));
        
        final int result = await editQuestionAnswerPair(questionId: multipleChoiceQuestionId, questionElements: [{'type': 'text', 'content': 'Timestamp test question'}], debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(multipleChoiceQuestionId);
        final String newTimestamp = question['last_modified_timestamp'] as String;
        expect(newTimestamp, isNot(equals(originalTimestamp)), reason: 'Last modified timestamp should be updated');
      });
      
      test('Test 15: Should handle media status updates correctly', () async {
        final int result = await editQuestionAnswerPair(questionId: multipleChoiceQuestionId, questionElements: [{'type': 'text', 'content': 'Text question'}, {'type': 'image', 'content': 'test_image.jpg'}], debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(multipleChoiceQuestionId);
        expect(question['has_media'], equals(1), reason: 'Question with image should have has_media = 1');
      });
      
      test('Test 16: Should throw exception for non-existent question ID', () async {
        expect(() => editQuestionAnswerPair(questionId: 'non_existent_id_12345', questionElements: [{'type': 'text', 'content': 'This should not work'}], debugDisableOutboundSyncCall: true), throwsA(isA<StateError>()), reason: 'Should throw StateError for non-existent question ID');
      });
      
      test('Test 17: Should handle empty question elements gracefully', () async {
        final int result = await editQuestionAnswerPair(questionId: multipleChoiceQuestionId, questionElements: [], debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row even with empty question elements');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(multipleChoiceQuestionId);
        final List<dynamic> questionElements = question['question_elements'] as List<dynamic>;
        expect(questionElements, isEmpty);
      });
      
      test('Test 18: Should handle empty answer elements gracefully', () async {
        final int result = await editQuestionAnswerPair(questionId: multipleChoiceQuestionId, answerElements: [], debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row even with empty answer elements');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(multipleChoiceQuestionId);
        final List<dynamic> answerElements = question['answer_elements'] as List<dynamic>;
        expect(answerElements, isEmpty);
      });
      
      test('Test 19: Should handle empty options gracefully for multiple choice', () async {
        final int result = await editQuestionAnswerPair(questionId: multipleChoiceQuestionId, options: [], correctOptionIndex: 0, debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row even with empty options');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(multipleChoiceQuestionId);
        final List<dynamic> options = question['options'] as List<dynamic>;
        expect(options, isEmpty);
      });
      
      test('Test 20: Should handle empty index options that apply gracefully', () async {
        final int result = await editQuestionAnswerPair(questionId: selectAllQuestionId, indexOptionsThatApply: [], debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row even with empty index options that apply');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(selectAllQuestionId);
        final List<dynamic> indexOptionsThatApply = question['index_options_that_apply'] as List<dynamic>;
        expect(indexOptionsThatApply, isEmpty);
      });
      
      test('Test 21: Should handle empty answers to blanks gracefully', () async {
        final int result = await editQuestionAnswerPair(questionId: fillInBlankQuestionId, answersToBlanks: [], debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row even with empty answers to blanks');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(fillInBlankQuestionId);
        final List<dynamic> answersToBlanks = question['answers_to_blanks'] as List<dynamic>;
        expect(answersToBlanks, isEmpty);
      });
      
      test('Test 22: Should handle whitespace-only module names', () async {
        final int result = await editQuestionAnswerPair(questionId: multipleChoiceQuestionId, moduleName: '   ', debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row even with whitespace-only module name');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(multipleChoiceQuestionId);
        expect(question['module_name'], equals(''), reason: 'Whitespace-only module name should be normalized to empty string');
      });
      
      test('Test 23: Should handle special characters in module names', () async {
        final int result = await editQuestionAnswerPair(questionId: multipleChoiceQuestionId, moduleName: 'Test_Module_With_Underscores', debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(multipleChoiceQuestionId);
        expect(question['module_name'], equals('test module with underscores'), reason: 'Module name should be normalized correctly');
      });
      
      test('Test 24: Should handle multiple field updates simultaneously', () async {
        final int result = await editQuestionAnswerPair(
          questionId: multipleChoiceQuestionId,
          questionElements: [{'type': 'text', 'content': 'Multi-field update question'}],
          answerElements: [{'type': 'text', 'content': 'Multi-field update answer'}],
          moduleName: 'Multi Field Test',
          debugDisableOutboundSyncCall: true,
        );
        
        expect(result, equals(1), reason: 'Should update 1 row');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(multipleChoiceQuestionId);
        final List<dynamic> questionElements = question['question_elements'] as List<dynamic>;
        final List<dynamic> answerElements = question['answer_elements'] as List<dynamic>;
        expect(questionElements[0]['content'], equals('Multi-field update question'));
        expect(answerElements[0]['content'], equals('Multi-field update answer'));
        expect(question['module_name'], equals('multi field test'));
      });
      
      test('Test 25: Should handle invalid correct option index gracefully', () async {
        // The editQuestionAnswerPair function doesn't validate correctOptionIndex, so this should succeed
        final int result = await editQuestionAnswerPair(questionId: multipleChoiceQuestionId, correctOptionIndex: -1, debugDisableOutboundSyncCall: true);
        
        expect(result, equals(1), reason: 'Should update 1 row even with invalid correct option index');
        
        final Map<String, dynamic> question = await getQuestionAnswerPairById(multipleChoiceQuestionId);
        expect(question['correct_option_index'], equals(-1), reason: 'Invalid correct option index should be stored as-is');
      });
      
      test('Test 26: Cleanup - Truncate question_answer_pairs table', () async {
        QuizzerLogger.logMessage('Cleaning up question_answer_pairs table after editQuestionAnswerPair Tests');
        await deleteAllRecordsFromTable('question_answer_pairs');
        QuizzerLogger.logSuccess('Successfully cleaned up question_answer_pairs table after editQuestionAnswerPair Tests');
      });
    });

    group('getAllQuestionAnswerPairs Tests', () {
      // Test data variables declared at the top of the group
      late List<String> generatedQuestionIds;
      
      setUp(() async {
        // Clear the table first
        await deleteAllRecordsFromTable('question_answer_pairs');
        
        // Generate 50 questions using the helper function (10 of each type)
        generatedQuestionIds = [];
        
        // Generate 10 multiple choice questions
        final multipleChoiceData = generateQuestionInputData(questionType: 'multiple_choice', numberOfQuestions: 10, numberOfModules: 5, numberOfOptions: 4);
        for (final data in multipleChoiceData) {
          final questionId = await addQuestionMultipleChoice(moduleName: data['moduleName'], questionElements: data['questionElements'], answerElements: data['answerElements'], options: data['options'], correctOptionIndex: data['correctOptionIndex'], debugDisableOutboundSyncCall: true);
          generatedQuestionIds.add(questionId);
        }
        
        // Generate 10 select all that apply questions
        final selectAllData = generateQuestionInputData(questionType: 'select_all_that_apply', numberOfQuestions: 10, numberOfModules: 5, numberOfOptions: 4);
        for (final data in selectAllData) {
          final questionId = await addQuestionSelectAllThatApply(moduleName: data['moduleName'], questionElements: data['questionElements'], answerElements: data['answerElements'], options: data['options'], indexOptionsThatApply: data['indexOptionsThatApply'], debugDisableOutboundSyncCall: true);
          generatedQuestionIds.add(questionId);
        }
        
        // Generate 10 true/false questions
        final trueFalseData = generateQuestionInputData(questionType: 'true_false', numberOfQuestions: 10, numberOfModules: 5);
        for (final data in trueFalseData) {
          final questionId = await addQuestionTrueFalse(moduleName: data['moduleName'], questionElements: data['questionElements'], answerElements: data['answerElements'], correctOptionIndex: data['correctOptionIndex'], debugDisableOutboundSyncCall: true);
          generatedQuestionIds.add(questionId);
        }
        
        // Generate 10 sort order questions
        final sortOrderData = generateQuestionInputData(questionType: 'sort_order', numberOfQuestions: 10, numberOfModules: 5, numberOfOptions: 4);
        for (final data in sortOrderData) {
          final questionId = await addSortOrderQuestion(moduleName: data['moduleName'], questionElements: data['questionElements'], answerElements: data['answerElements'], options: data['options'], debugDisableOutboundSyncCall: true);
          generatedQuestionIds.add(questionId);
        }
        
        // Generate 10 fill in the blank questions
        final fillInBlankData = generateQuestionInputData(questionType: 'fill_in_the_blank', numberOfQuestions: 10, numberOfModules: 5, numberOfBlanks: 1, numberOfSynonymsPerBlank: 2);
        for (final data in fillInBlankData) {
          final questionId = await addFillInTheBlankQuestion(moduleName: data['moduleName'], questionElements: data['questionElements'], answerElements: data['answerElements'], answersToBlanks: data['answersToBlanks'], debugDisableOutboundSyncCall: true);
          generatedQuestionIds.add(questionId);
        }
      });
      
      test('Test 1: Should return all 50 questions', () async {
        final List<Map<String, dynamic>> allQuestions = await getAllQuestionAnswerPairs();
        
        expect(allQuestions.length, equals(50), reason: 'Should return exactly 50 questions');
        expect(allQuestions.length, equals(generatedQuestionIds.length), reason: 'Should return same number of questions as were created');
      });
      
      test('Test 2: Should return questions with correct structure', () async {
        final List<Map<String, dynamic>> allQuestions = await getAllQuestionAnswerPairs();
        
        for (final question in allQuestions) {
          // Verify required fields are present
          expect(question['question_id'], isNotNull);
          expect(question['time_stamp'], isNotNull);
          expect(question['qst_contrib'], isNotNull);
          expect(question['module_name'], isNotNull);
          expect(question['question_type'], isNotNull);
          expect(question['question_elements'], isNotNull);
          expect(question['answer_elements'], isNotNull);
          expect(question['has_been_synced'], isNotNull);
          expect(question['edits_are_synced'], isNotNull);
          expect(question['last_modified_timestamp'], isNotNull);
          expect(question['has_media'], isNotNull);
          
          // Verify question elements and answer elements are properly decoded
          final List<dynamic> questionElements = question['question_elements'] as List<dynamic>;
          final List<dynamic> answerElements = question['answer_elements'] as List<dynamic>;
          expect(questionElements, isNotEmpty);
          expect(answerElements, isNotEmpty);
        }
      });
      
      test('Test 3: Should return all generated question IDs', () async {
        final List<Map<String, dynamic>> allQuestions = await getAllQuestionAnswerPairs();
        final List<String> returnedQuestionIds = allQuestions.map((q) => q['question_id'] as String).toList();
        
        for (final expectedId in generatedQuestionIds) {
          expect(returnedQuestionIds, contains(expectedId), reason: 'Should contain generated question ID: $expectedId');
        }
      });
      
      test('Test 4: Should return correct distribution of question types', () async {
        final List<Map<String, dynamic>> allQuestions = await getAllQuestionAnswerPairs();
        
        final Map<String, int> typeCounts = {};
        for (final question in allQuestions) {
          final String questionType = question['question_type'] as String;
          typeCounts[questionType] = (typeCounts[questionType] ?? 0) + 1;
        }
        
        expect(typeCounts['multiple_choice'], equals(10), reason: 'Should have 10 multiple choice questions');
        expect(typeCounts['select_all_that_apply'], equals(10), reason: 'Should have 10 select all that apply questions');
        expect(typeCounts['true_false'], equals(10), reason: 'Should have 10 true/false questions');
        expect(typeCounts['sort_order'], equals(10), reason: 'Should have 10 sort order questions');
        expect(typeCounts['fill_in_the_blank'], equals(10), reason: 'Should have 10 fill in the blank questions');
      });
      
      test('Test 5: Should return questions with normalized module names', () async {
        final List<Map<String, dynamic>> allQuestions = await getAllQuestionAnswerPairs();
        
        for (final question in allQuestions) {
          final String moduleName = question['module_name'] as String;
          expect(moduleName, matches(RegExp(r'^[a-z0-9\s]+$')), reason: 'Module name should be normalized to lowercase: $moduleName');
        }
      });
      
      test('Test 6: Cleanup - Truncate question_answer_pairs table', () async {
        QuizzerLogger.logMessage('Cleaning up question_answer_pairs table after getAllQuestionAnswerPairs Tests');
        await deleteAllRecordsFromTable('question_answer_pairs');
        QuizzerLogger.logSuccess('Successfully cleaned up question_answer_pairs table after getAllQuestionAnswerPairs Tests');
      });
    });

    group('removeQuestionAnswerPair Tests', () {
      // Test data variables declared at the top of the group
      late List<String> questionIdsToRemove;
      
      setUp(() async {
        // Clear the table first
        await deleteAllRecordsFromTable('question_answer_pairs');
        
        // Generate 3 questions using the helper function
        questionIdsToRemove = [];
        
        // Generate 3 multiple choice questions
        final testData = generateQuestionInputData(questionType: 'multiple_choice', numberOfQuestions: 3, numberOfModules: 1, numberOfOptions: 2);
        for (final data in testData) {
          final questionId = await addQuestionMultipleChoice(moduleName: data['moduleName'], questionElements: data['questionElements'], answerElements: data['answerElements'], options: data['options'], correctOptionIndex: data['correctOptionIndex'], debugDisableOutboundSyncCall: true);
          questionIdsToRemove.add(questionId);
        }
      });
      
      test('Test 1: Should remove questions and verify they no longer exist', () async {
        // Verify questions exist before removal
        for (final questionId in questionIdsToRemove) {
          final question = await getQuestionAnswerPairById(questionId);
          expect(question, isNotNull, reason: 'Question should exist before removal: $questionId');
        }
        
        // Remove each question
        for (final questionId in questionIdsToRemove) {
          // Extract timestamp and contributor from questionId
          final parts = questionId.split('_');
          final timeStamp = parts[0];
          final qstContrib = parts[1];
          
          final result = await removeQuestionAnswerPair(timeStamp, qstContrib);
          expect(result, equals(1), reason: 'Should remove exactly 1 row for question: $questionId');
        }
        
        // Verify questions no longer exist
        for (final questionId in questionIdsToRemove) {
          expect(() => getQuestionAnswerPairById(questionId), throwsA(isA<StateError>()), reason: 'Question should no longer exist after removal: $questionId');
        }
      });
      
      test('Test 2: Should return 0 when trying to remove non-existent question', () async {
        final result = await removeQuestionAnswerPair('fake_timestamp', 'fake_contributor');
        expect(result, equals(0), reason: 'Should return 0 when removing non-existent question');
      });
      
      test('Test 3: Should verify database is empty after all removals', () async {
        // Remove all questions
        for (final questionId in questionIdsToRemove) {
          final parts = questionId.split('_');
          final timeStamp = parts[0];
          final qstContrib = parts[1];
          await removeQuestionAnswerPair(timeStamp, qstContrib);
        }
        
        // Verify database is empty
        final allQuestions = await getAllQuestionAnswerPairs();
        expect(allQuestions, isEmpty, reason: 'Database should be empty after all removals');
      });
      
      test('Test 4: Cleanup - Truncate question_answer_pairs table', () async {
        QuizzerLogger.logMessage('Cleaning up question_answer_pairs table after removeQuestionAnswerPair Tests');
        await deleteAllRecordsFromTable('question_answer_pairs');
        QuizzerLogger.logSuccess('Successfully cleaned up question_answer_pairs table after removeQuestionAnswerPair Tests');
      });
    });

    group('getModuleNameForQuestionId Tests', () {
      // Test data variables declared at the top of the group
      late List<String> questionIdsToTest;
      
      setUp(() async {
        // Clear the table first
        await deleteAllRecordsFromTable('question_answer_pairs');
        
        // Generate 3 questions with different module names using the helper function
        questionIdsToTest = [];
        
        // Generate 3 multiple choice questions with different module names
        final testData = generateQuestionInputData(questionType: 'multiple_choice', numberOfQuestions: 3, numberOfModules: 3, numberOfOptions: 3);
        for (int i = 0; i < testData.length; i++) {
          final data = testData[i];
          // Override module names to be more descriptive
          final moduleNames = ['Science', 'Math', 'History'];
          final questionId = await addQuestionMultipleChoice(moduleName: moduleNames[i], questionElements: data['questionElements'], answerElements: data['answerElements'], options: data['options'], correctOptionIndex: data['correctOptionIndex'], debugDisableOutboundSyncCall: true);
          questionIdsToTest.add(questionId);
        }
      });
      
      test('Test 1: Should return correct normalized module name for each question', () async {
        // Test each question
        final moduleName1 = await getModuleNameForQuestionId(questionIdsToTest[0]);
        expect(moduleName1, equals('science'), reason: 'Should return normalized module name for Science');
        
        final moduleName2 = await getModuleNameForQuestionId(questionIdsToTest[1]);
        expect(moduleName2, equals('math'), reason: 'Should return normalized module name for Math');
        
        final moduleName3 = await getModuleNameForQuestionId(questionIdsToTest[2]);
        expect(moduleName3, equals('history'), reason: 'Should return normalized module name for History');
      });
      
      test('Test 2: Should throw StateError for non-existent question ID', () async {
        expect(() => getModuleNameForQuestionId('non_existent_id'), throwsA(isA<StateError>()), reason: 'Should throw StateError for non-existent question ID');
      });
      
      test('Test 3: Cleanup - Truncate question_answer_pairs table', () async {
        QuizzerLogger.logMessage('Cleaning up question_answer_pairs table after getModuleNameForQuestionId Tests');
        await deleteAllRecordsFromTable('question_answer_pairs');
        QuizzerLogger.logSuccess('Successfully cleaned up question_answer_pairs table after getModuleNameForQuestionId Tests');
      });
    });

    group('getQuestionRecordsForModule Tests', () {
    List<String> scienceQuestionIds = [];
    List<String> mathQuestionIds = [];
    List<String> historyQuestionIds = [];

    setUp(() async {
      // Clear the table first
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db != null) {
        await verifyQuestionAnswerPairTable(db);
        await db.delete('question_answer_pairs');
      }
      getDatabaseMonitor().releaseDatabaseAccess();

      // Clear the lists to start fresh
      scienceQuestionIds.clear();
      mathQuestionIds.clear();
      historyQuestionIds.clear();

      // Add 5 questions for Science module
      for (int i = 1; i <= 5; i++) {
        final questionId = await addQuestionMultipleChoice(
          moduleName: 'Science',
          questionElements: [
            {'type': 'text', 'content': 'Science question $i?'}
          ],
          answerElements: [
            {'type': 'text', 'content': 'Science answer $i'}
          ],
          options: [
            {'type': 'text', 'content': 'Option A'},
            {'type': 'text', 'content': 'Option B'},
            {'type': 'text', 'content': 'Option C'},
          ],
          correctOptionIndex: 0,
          debugDisableOutboundSyncCall: true,
        );
        scienceQuestionIds.add(questionId);
      }

      // Add 5 questions for Math module
      for (int i = 1; i <= 5; i++) {
        final questionId = await addQuestionMultipleChoice(
          moduleName: 'Math',
          questionElements: [
            {'type': 'text', 'content': 'Math question $i?'}
          ],
          answerElements: [
            {'type': 'text', 'content': 'Math answer $i'}
          ],
          options: [
            {'type': 'text', 'content': 'Option A'},
            {'type': 'text', 'content': 'Option B'},
            {'type': 'text', 'content': 'Option C'},
          ],
          correctOptionIndex: 0,
          debugDisableOutboundSyncCall: true,
        );
        mathQuestionIds.add(questionId);
      }

      // Add 5 questions for History module
      for (int i = 1; i <= 5; i++) {
        final questionId = await addQuestionMultipleChoice(
          moduleName: 'History',
          questionElements: [
            {'type': 'text', 'content': 'History question $i?'}
          ],
          answerElements: [
            {'type': 'text', 'content': 'History answer $i'}
          ],
          options: [
            {'type': 'text', 'content': 'Option A'},
            {'type': 'text', 'content': 'Option B'},
            {'type': 'text', 'content': 'Option C'},
          ],
          correctOptionIndex: 0,
          debugDisableOutboundSyncCall: true,
        );
        historyQuestionIds.add(questionId);
      }

      QuizzerLogger.logMessage('Added 15 questions total: ${scienceQuestionIds.length} Science, ${mathQuestionIds.length} Math, ${historyQuestionIds.length} History');
    });

    test('Test 1: Should return exactly 5 Science questions', () async {
      QuizzerLogger.logMessage('Test 1: Testing getQuestionRecordsForModule returns correct Science questions');

      final scienceQuestions = await getQuestionRecordsForModule('Science');
      
      expect(scienceQuestions.length, equals(5), reason: 'Should return exactly 5 Science questions');
      
      // Verify all returned questions are from Science module
      for (final question in scienceQuestions) {
        expect(question['module_name'], equals('science'), reason: 'All returned questions should have normalized Science module name');
      }

      // Verify all expected question IDs are present
      for (final expectedId in scienceQuestionIds) {
        final foundQuestion = scienceQuestions.firstWhere(
          (q) => q['question_id'] == expectedId,
          orElse: () => throw StateError('Expected question ID $expectedId not found in results')
        );
        expect(foundQuestion, isNotNull, reason: 'Expected Science question ID $expectedId should be present');
      }

      QuizzerLogger.logSuccess('Test 1 passed: All 5 Science questions returned correctly');
    });

    test('Test 2: Should return exactly 5 Math questions', () async {
      QuizzerLogger.logMessage('Test 2: Testing getQuestionRecordsForModule returns correct Math questions');

      final mathQuestions = await getQuestionRecordsForModule('Math');
      
      expect(mathQuestions.length, equals(5), reason: 'Should return exactly 5 Math questions');
      
      // Verify all returned questions are from Math module
      for (final question in mathQuestions) {
        expect(question['module_name'], equals('math'), reason: 'All returned questions should have normalized Math module name');
      }

      // Verify all expected question IDs are present
      for (final expectedId in mathQuestionIds) {
        final foundQuestion = mathQuestions.firstWhere(
          (q) => q['question_id'] == expectedId,
          orElse: () => throw StateError('Expected question ID $expectedId not found in results')
        );
        expect(foundQuestion, isNotNull, reason: 'Expected Math question ID $expectedId should be present');
      }

      QuizzerLogger.logSuccess('Test 2 passed: All 5 Math questions returned correctly');
    });

    test('Test 3: Should return exactly 5 History questions', () async {
      QuizzerLogger.logMessage('Test 3: Testing getQuestionRecordsForModule returns correct History questions');

      final historyQuestions = await getQuestionRecordsForModule('History');
      
      expect(historyQuestions.length, equals(5), reason: 'Should return exactly 5 History questions');
      
      // Verify all returned questions are from History module
      for (final question in historyQuestions) {
        expect(question['module_name'], equals('history'), reason: 'All returned questions should have normalized History module name');
      }

      // Verify all expected question IDs are present
      for (final expectedId in historyQuestionIds) {
        final foundQuestion = historyQuestions.firstWhere(
          (q) => q['question_id'] == expectedId,
          orElse: () => throw StateError('Expected question ID $expectedId not found in results')
        );
        expect(foundQuestion, isNotNull, reason: 'Expected History question ID $expectedId should be present');
      }

      QuizzerLogger.logSuccess('Test 3 passed: All 5 History questions returned correctly');
    });

    test('Test 4: Should return empty list for non-existent module', () async {
      QuizzerLogger.logMessage('Test 4: Testing getQuestionRecordsForModule with non-existent module');

      final nonExistentQuestions = await getQuestionRecordsForModule('NonExistentModule');
      
      expect(nonExistentQuestions, isEmpty, reason: 'Should return empty list for non-existent module');

      QuizzerLogger.logSuccess('Test 4 passed: Non-existent module returns empty list');
    });

    tearDown(() async {
      // Clean up: delete all records from table
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db != null) {
        await verifyQuestionAnswerPairTable(db);
        await db.delete('question_answer_pairs');
        QuizzerLogger.logMessage('Cleaned up question_answer_pairs table after getQuestionRecordsForModule tests');
      }
      getDatabaseMonitor().releaseDatabaseAccess();
    });
  });

    group('getQuestionIdsForModule Tests', () {
      // Test data variables declared at the top of the group
      late List<Map<String, dynamic>> testData;
      
      setUp(() {
        // Initialize test data using helper functions
        testData = generateQuestionInputData(questionType: 'multiple_choice', numberOfQuestions: 15, numberOfModules: 3, numberOfOptions: 3);
      });
      
      test('Test 1: Should return exactly 5 question IDs for Science module', () async {
        // Clear the table first
        await deleteAllRecordsFromTable('question_answer_pairs');
        
        // Add 5 questions for Science module
        final List<String> scienceQuestionIds = [];
        for (int i = 0; i < 5; i++) {
          final questionId = await addQuestionMultipleChoice(
            moduleName: 'Science',
            questionElements: testData[i]['questionElements'],
            answerElements: testData[i]['answerElements'],
            options: testData[i]['options'],
            correctOptionIndex: testData[i]['correctOptionIndex'],
            debugDisableOutboundSyncCall: true,
          );
          scienceQuestionIds.add(questionId);
        }

        // Add 5 questions for Math module
        for (int i = 5; i < 10; i++) {
          await addQuestionMultipleChoice(
            moduleName: 'Math',
            questionElements: testData[i]['questionElements'],
            answerElements: testData[i]['answerElements'],
            options: testData[i]['options'],
            correctOptionIndex: testData[i]['correctOptionIndex'],
            debugDisableOutboundSyncCall: true,
          );
        }

        // Add 5 questions for History module
        for (int i = 10; i < 15; i++) {
          await addQuestionMultipleChoice(
            moduleName: 'History',
            questionElements: testData[i]['questionElements'],
            answerElements: testData[i]['answerElements'],
            options: testData[i]['options'],
            correctOptionIndex: testData[i]['correctOptionIndex'],
            debugDisableOutboundSyncCall: true,
          );
        }

        final returnedScienceQuestionIds = await getQuestionIdsForModule('Science');
        
        expect(returnedScienceQuestionIds.length, equals(5), reason: 'Should return exactly 5 question IDs for Science module');
        
        // Verify that all expected question IDs are present
        for (final expectedId in scienceQuestionIds) {
          expect(returnedScienceQuestionIds, contains(expectedId), reason: 'Expected question ID $expectedId should be present in returned list');
        }
      });

      test('Test 2: Should return exactly 5 question IDs for Math module', () async {
        // Clear the table first
        await deleteAllRecordsFromTable('question_answer_pairs');
        
        // Add 5 questions for Science module
        for (int i = 0; i < 5; i++) {
          await addQuestionMultipleChoice(
            moduleName: 'Science',
            questionElements: testData[i]['questionElements'],
            answerElements: testData[i]['answerElements'],
            options: testData[i]['options'],
            correctOptionIndex: testData[i]['correctOptionIndex'],
            debugDisableOutboundSyncCall: true,
          );
        }

        // Add 5 questions for Math module
        final List<String> mathQuestionIds = [];
        for (int i = 5; i < 10; i++) {
          final questionId = await addQuestionMultipleChoice(
            moduleName: 'Math',
            questionElements: testData[i]['questionElements'],
            answerElements: testData[i]['answerElements'],
            options: testData[i]['options'],
            correctOptionIndex: testData[i]['correctOptionIndex'],
            debugDisableOutboundSyncCall: true,
          );
          mathQuestionIds.add(questionId);
        }

        // Add 5 questions for History module
        for (int i = 10; i < 15; i++) {
          await addQuestionMultipleChoice(
            moduleName: 'History',
            questionElements: testData[i]['questionElements'],
            answerElements: testData[i]['answerElements'],
            options: testData[i]['options'],
            correctOptionIndex: testData[i]['correctOptionIndex'],
            debugDisableOutboundSyncCall: true,
          );
        }

        final returnedMathQuestionIds = await getQuestionIdsForModule('Math');
        
        expect(returnedMathQuestionIds.length, equals(5), reason: 'Should return exactly 5 question IDs for Math module');
        
        // Verify that all expected question IDs are present
        for (final expectedId in mathQuestionIds) {
          expect(returnedMathQuestionIds, contains(expectedId), reason: 'Expected question ID $expectedId should be present in returned list');
        }
      });

      test('Test 3: Should return exactly 5 question IDs for History module', () async {
        // Clear the table first
        await deleteAllRecordsFromTable('question_answer_pairs');
        
        // Add 5 questions for Science module
        for (int i = 0; i < 5; i++) {
          await addQuestionMultipleChoice(
            moduleName: 'Science',
            questionElements: testData[i]['questionElements'],
            answerElements: testData[i]['answerElements'],
            options: testData[i]['options'],
            correctOptionIndex: testData[i]['correctOptionIndex'],
            debugDisableOutboundSyncCall: true,
          );
        }

        // Add 5 questions for Math module
        for (int i = 5; i < 10; i++) {
          await addQuestionMultipleChoice(
            moduleName: 'Math',
            questionElements: testData[i]['questionElements'],
            answerElements: testData[i]['answerElements'],
            options: testData[i]['options'],
            correctOptionIndex: testData[i]['correctOptionIndex'],
            debugDisableOutboundSyncCall: true,
          );
        }

        // Add 5 questions for History module
        final List<String> historyQuestionIds = [];
        for (int i = 10; i < 15; i++) {
          final questionId = await addQuestionMultipleChoice(
            moduleName: 'History',
            questionElements: testData[i]['questionElements'],
            answerElements: testData[i]['answerElements'],
            options: testData[i]['options'],
            correctOptionIndex: testData[i]['correctOptionIndex'],
            debugDisableOutboundSyncCall: true,
          );
          historyQuestionIds.add(questionId);
        }

        final returnedHistoryQuestionIds = await getQuestionIdsForModule('History');
        
        expect(returnedHistoryQuestionIds.length, equals(5), reason: 'Should return exactly 5 question IDs for History module');
        
        // Verify that all expected question IDs are present
        for (final expectedId in historyQuestionIds) {
          expect(returnedHistoryQuestionIds, contains(expectedId), reason: 'Expected question ID $expectedId should be present in returned list');
        }
      });

      test('Test 4: Should return empty list for non-existent module', () async {
        // Clear the table first
        await deleteAllRecordsFromTable('question_answer_pairs');
        
        final nonExistentModuleQuestionIds = await getQuestionIdsForModule('NonExistentModule');
        
        expect(nonExistentModuleQuestionIds, isEmpty, reason: 'Should return empty list for non-existent module');
      });

      test('Test 5: Should return only question IDs, not full records', () async {
        // Clear the table first
        await deleteAllRecordsFromTable('question_answer_pairs');
        
        // Add a few questions first
        trackTestModule('TestModule');
        for (int i = 0; i < 3; i++) {
          await addQuestionMultipleChoice(
            moduleName: 'TestModule',
            questionElements: testData[i]['questionElements'],
            answerElements: testData[i]['answerElements'],
            options: testData[i]['options'],
            correctOptionIndex: testData[i]['correctOptionIndex'],
            debugDisableOutboundSyncCall: true,
          );
        }

        final returnedQuestionIds = await getQuestionIdsForModule('TestModule');
        
        // Verify that we got a list of strings (question IDs)
        expect(returnedQuestionIds, isA<List<String>>(), reason: 'Should return List<String>');
        
        // Verify that each item is a non-empty string
        for (final questionId in returnedQuestionIds) {
          expect(questionId, isA<String>(), reason: 'Each item should be a String');
          expect(questionId, isNotEmpty, reason: 'Each question ID should not be empty');
        }
      });

      test('Test 6: Cleanup - Truncate question_answer_pairs table', () async {
        QuizzerLogger.logMessage('Cleaning up question_answer_pairs table after getQuestionIdsForModule Tests');
        await deleteAllRecordsFromTable('question_answer_pairs');
        QuizzerLogger.logSuccess('Successfully cleaned up question_answer_pairs table after getQuestionIdsForModule Tests');
      });
    });

    group('updateQuestionSyncFlags Tests', () {
      // Test data variables declared at the top of the group
      late List<Map<String, dynamic>> testData;
      late String testQuestionId;
      
      setUp(() {
        // Initialize test data using helper functions
        testData = generateQuestionInputData(questionType: 'multiple_choice', numberOfQuestions: 1, numberOfOptions: 3);
      });
      
      test('Test 1: Should update has_been_synced flag to true', () async {
        // Clear the table first
        await deleteAllRecordsFromTable('question_answer_pairs');
        
        // Add a test question
        trackTestModule('Test Module');
        testQuestionId = await addQuestionMultipleChoice(
          moduleName: 'Test Module',
          questionElements: testData[0]['questionElements'],
          answerElements: testData[0]['answerElements'],
          options: testData[0]['options'],
          correctOptionIndex: testData[0]['correctOptionIndex'],
          debugDisableOutboundSyncCall: true,
        );

        await updateQuestionSyncFlags(
          questionId: testQuestionId,
          hasBeenSynced: true,
          editsAreSynced: false,
        );

        // Verify the update by fetching the question
        final question = await getQuestionAnswerPairById(testQuestionId);
        expect(question, isNotNull, reason: 'Question should exist');
        expect(question['has_been_synced'], equals(1), reason: 'has_been_synced should be 1 (true)');
        expect(question['edits_are_synced'], equals(0), reason: 'edits_are_synced should remain 0 (false)');
      });

      test('Test 2: Should update edits_are_synced flag to true', () async {
        // Clear the table first
        await deleteAllRecordsFromTable('question_answer_pairs');
        
        // Add a test question
        testQuestionId = await addQuestionMultipleChoice(
          moduleName: 'Test Module',
          questionElements: testData[0]['questionElements'],
          answerElements: testData[0]['answerElements'],
          options: testData[0]['options'],
          correctOptionIndex: testData[0]['correctOptionIndex'],
          debugDisableOutboundSyncCall: true,
        );

        await updateQuestionSyncFlags(
          questionId: testQuestionId,
          hasBeenSynced: false,
          editsAreSynced: true,
        );

        // Verify the update by fetching the question
        final question = await getQuestionAnswerPairById(testQuestionId);
        expect(question, isNotNull, reason: 'Question should exist');
        expect(question['has_been_synced'], equals(0), reason: 'has_been_synced should remain 0 (false)');
        expect(question['edits_are_synced'], equals(1), reason: 'edits_are_synced should be 1 (true)');
      });

      test('Test 3: Should update both sync flags to true', () async {
        // Clear the table first
        await deleteAllRecordsFromTable('question_answer_pairs');
        
        // Add a test question
        testQuestionId = await addQuestionMultipleChoice(
          moduleName: 'Test Module',
          questionElements: testData[0]['questionElements'],
          answerElements: testData[0]['answerElements'],
          options: testData[0]['options'],
          correctOptionIndex: testData[0]['correctOptionIndex'],
          debugDisableOutboundSyncCall: true,
        );

        await updateQuestionSyncFlags(
          questionId: testQuestionId,
          hasBeenSynced: true,
          editsAreSynced: true,
        );

        // Verify the update by fetching the question
        final question = await getQuestionAnswerPairById(testQuestionId);
        expect(question, isNotNull, reason: 'Question should exist');
        expect(question['has_been_synced'], equals(1), reason: 'has_been_synced should be 1 (true)');
        expect(question['edits_are_synced'], equals(1), reason: 'edits_are_synced should be 1 (true)');
      });

      test('Test 4: Should update both sync flags to false', () async {
        // Clear the table first
        await deleteAllRecordsFromTable('question_answer_pairs');
        
        // Add a test question
        testQuestionId = await addQuestionMultipleChoice(
          moduleName: 'Test Module',
          questionElements: testData[0]['questionElements'],
          answerElements: testData[0]['answerElements'],
          options: testData[0]['options'],
          correctOptionIndex: testData[0]['correctOptionIndex'],
          debugDisableOutboundSyncCall: true,
        );

        await updateQuestionSyncFlags(
          questionId: testQuestionId,
          hasBeenSynced: false,
          editsAreSynced: false,
        );

        // Verify the update by fetching the question
        final question = await getQuestionAnswerPairById(testQuestionId);
        expect(question, isNotNull, reason: 'Question should exist');
        expect(question['has_been_synced'], equals(0), reason: 'has_been_synced should be 0 (false)');
        expect(question['edits_are_synced'], equals(0), reason: 'edits_are_synced should be 0 (false)');
      });

      test('Test 5: Should update last_modified_timestamp when sync flags change', () async {
        // Clear the table first
        await deleteAllRecordsFromTable('question_answer_pairs');
        
        // Add a test question
        testQuestionId = await addQuestionMultipleChoice(
          moduleName: 'Test Module',
          questionElements: testData[0]['questionElements'],
          answerElements: testData[0]['answerElements'],
          options: testData[0]['options'],
          correctOptionIndex: testData[0]['correctOptionIndex'],
          debugDisableOutboundSyncCall: true,
        );

        // Get the original timestamp
        final originalQuestion = await getQuestionAnswerPairById(testQuestionId);
        final originalTimestamp = originalQuestion['last_modified_timestamp'] as String;

        // Wait a moment to ensure timestamp difference
        await Future.delayed(const Duration(milliseconds: 100));

        await updateQuestionSyncFlags(
          questionId: testQuestionId,
          hasBeenSynced: true,
          editsAreSynced: true,
        );

        // Verify the timestamp was updated
        final updatedQuestion = await getQuestionAnswerPairById(testQuestionId);
        final updatedTimestamp = updatedQuestion['last_modified_timestamp'] as String;

        expect(updatedTimestamp, isNot(equals(originalTimestamp)), reason: 'last_modified_timestamp should be updated');
      });

      test('Test 6: Should handle non-existent question ID gracefully', () async {
        // Clear the table first
        await deleteAllRecordsFromTable('question_answer_pairs');
        
        // This should not throw an exception but should log a warning
        await updateQuestionSyncFlags(
          questionId: 'non_existent_question_id',
          hasBeenSynced: true,
          editsAreSynced: true,
        );

        // The function should complete without throwing an exception
      });

      test('Test 7: Cleanup - Truncate question_answer_pairs table', () async {
        QuizzerLogger.logMessage('Cleaning up question_answer_pairs table after updateQuestionSyncFlags Tests');
        await deleteAllRecordsFromTable('question_answer_pairs');
        QuizzerLogger.logSuccess('Successfully cleaned up question_answer_pairs table after updateQuestionSyncFlags Tests');
      });
    });

    group('getUnsyncedQuestionAnswerPairs Tests', () {
      // Test data variables declared at the top of the group
      late List<Map<String, dynamic>> multipleChoiceData;
      late List<Map<String, dynamic>> trueFalseData;
      late List<Map<String, dynamic>> fillInTheBlankData;
      late List<String> testQuestionIds;
      
      setUp(() {
        // Initialize test data using helper functions for each question type
        multipleChoiceData = generateQuestionInputData(questionType: 'multiple_choice', numberOfQuestions: 3, numberOfOptions: 3);
        trueFalseData = generateQuestionInputData(questionType: 'true_false', numberOfQuestions: 3, numberOfOptions: 2);
        fillInTheBlankData = generateQuestionInputData(questionType: 'fill_in_the_blank', numberOfQuestions: 4, numberOfBlanks: 1, numberOfSynonymsPerBlank: 2);
        testQuestionIds = [];
      });
      
      test('Test 1: Should return all questions as unsynced when sync is disabled', () async {
        // Clear the table first
        await deleteAllRecordsFromTable('question_answer_pairs');
        
        // Add 10 questions of various types (all will be unsynced by default)
        for (int i = 0; i < 10; i++) {
          String questionId;
          
          if (i < 3) {
            // Add 3 multiple choice questions
            questionId = await addQuestionMultipleChoice(
              moduleName: 'Test Module ${i + 1}',
              questionElements: multipleChoiceData[i]['questionElements'],
              answerElements: multipleChoiceData[i]['answerElements'],
              options: multipleChoiceData[i]['options'],
              correctOptionIndex: multipleChoiceData[i]['correctOptionIndex'],
              debugDisableOutboundSyncCall: true,
            );
          } else if (i < 6) {
            // Add 3 true/false questions
            questionId = await addQuestionTrueFalse(
              moduleName: 'Test Module ${i + 1}',
              questionElements: trueFalseData[i - 3]['questionElements'],
              answerElements: trueFalseData[i - 3]['answerElements'],
              correctOptionIndex: trueFalseData[i - 3]['correctOptionIndex'],
              debugDisableOutboundSyncCall: true,
            );
          } else {
            // Add 4 fill-in-the-blank questions
            questionId = await addFillInTheBlankQuestion(
              moduleName: 'Test Module ${i + 1}',
              questionElements: fillInTheBlankData[i - 6]['questionElements'],
              answerElements: fillInTheBlankData[i - 6]['answerElements'],
              answersToBlanks: fillInTheBlankData[i - 6]['answersToBlanks'],
              debugDisableOutboundSyncCall: true,
            );
          }
          
          testQuestionIds.add(questionId);
        }

        final unsyncedQuestions = await getUnsyncedQuestionAnswerPairs();
        
        expect(unsyncedQuestions.length, equals(10), reason: 'Should return all 10 questions as unsynced');
        
        // Verify all expected question IDs are present
        for (final expectedId in testQuestionIds) {
          final foundQuestion = unsyncedQuestions.firstWhere(
            (q) => q['question_id'] == expectedId,
            orElse: () => throw StateError('Expected question ID $expectedId not found in unsynced results')
          );
          expect(foundQuestion, isNotNull, reason: 'Expected question ID $expectedId should be present in unsynced results');
        }
      });

      test('Test 2: Should return questions with correct sync flag values', () async {
        // Clear the table first
        await deleteAllRecordsFromTable('question_answer_pairs');
        
        // Add 10 questions of various types (all will be unsynced by default)
        for (int i = 0; i < 10; i++) {
          String questionId;
          
          if (i < 3) {
            // Add 3 multiple choice questions
            questionId = await addQuestionMultipleChoice(
              moduleName: 'Test Module ${i + 1}',
              questionElements: multipleChoiceData[i]['questionElements'],
              answerElements: multipleChoiceData[i]['answerElements'],
              options: multipleChoiceData[i]['options'],
              correctOptionIndex: multipleChoiceData[i]['correctOptionIndex'],
              debugDisableOutboundSyncCall: true,
            );
          } else if (i < 6) {
            // Add 3 true/false questions
            questionId = await addQuestionTrueFalse(
              moduleName: 'Test Module ${i + 1}',
              questionElements: trueFalseData[i - 3]['questionElements'],
              answerElements: trueFalseData[i - 3]['answerElements'],
              correctOptionIndex: trueFalseData[i - 3]['correctOptionIndex'],
              debugDisableOutboundSyncCall: true,
            );
          } else {
            // Add 4 fill-in-the-blank questions
            questionId = await addFillInTheBlankQuestion(
              moduleName: 'Test Module ${i + 1}',
              questionElements: fillInTheBlankData[i - 6]['questionElements'],
              answerElements: fillInTheBlankData[i - 6]['answerElements'],
              answersToBlanks: fillInTheBlankData[i - 6]['answersToBlanks'],
              debugDisableOutboundSyncCall: true,
            );
          }
          
          testQuestionIds.add(questionId);
        }

        final unsyncedQuestions = await getUnsyncedQuestionAnswerPairs();
        
        // Verify that all returned questions have sync flags indicating they are unsynced
        for (final question in unsyncedQuestions) {
          final hasBeenSynced = question['has_been_synced'] as int;
          final editsAreSynced = question['edits_are_synced'] as int;
          
          // Questions should be unsynced (has_been_synced = 0 OR edits_are_synced = 0)
          expect(
            hasBeenSynced == 0 || editsAreSynced == 0, 
            isTrue, 
            reason: 'Question ${question['question_id']} should have at least one sync flag set to 0'
          );
        }
      });

      test('Test 3: Should return questions with all required fields', () async {
        // Clear the table first
        await deleteAllRecordsFromTable('question_answer_pairs');
        
        // Add 10 questions of various types (all will be unsynced by default)
        for (int i = 0; i < 10; i++) {
          String questionId;
          
          if (i < 3) {
            // Add 3 multiple choice questions
            questionId = await addQuestionMultipleChoice(
              moduleName: 'Test Module ${i + 1}',
              questionElements: multipleChoiceData[i]['questionElements'],
              answerElements: multipleChoiceData[i]['answerElements'],
              options: multipleChoiceData[i]['options'],
              correctOptionIndex: multipleChoiceData[i]['correctOptionIndex'],
              debugDisableOutboundSyncCall: true,
            );
          } else if (i < 6) {
            // Add 3 true/false questions
            questionId = await addQuestionTrueFalse(
              moduleName: 'Test Module ${i + 1}',
              questionElements: trueFalseData[i - 3]['questionElements'],
              answerElements: trueFalseData[i - 3]['answerElements'],
              correctOptionIndex: trueFalseData[i - 3]['correctOptionIndex'],
              debugDisableOutboundSyncCall: true,
            );
          } else {
            // Add 4 fill-in-the-blank questions
            questionId = await addFillInTheBlankQuestion(
              moduleName: 'Test Module ${i + 1}',
              questionElements: fillInTheBlankData[i - 6]['questionElements'],
              answerElements: fillInTheBlankData[i - 6]['answerElements'],
              answersToBlanks: fillInTheBlankData[i - 6]['answersToBlanks'],
              debugDisableOutboundSyncCall: true,
            );
          }
          
          testQuestionIds.add(questionId);
        }

        final unsyncedQuestions = await getUnsyncedQuestionAnswerPairs();
        
        // Verify that all returned questions have the required fields
        for (final question in unsyncedQuestions) {
          expect(question, contains('question_id'), reason: 'Question should have question_id field');
          expect(question, contains('time_stamp'), reason: 'Question should have time_stamp field');
          expect(question, contains('question_elements'), reason: 'Question should have question_elements field');
          expect(question, contains('answer_elements'), reason: 'Question should have answer_elements field');
          expect(question, contains('module_name'), reason: 'Question should have module_name field');
          expect(question, contains('question_type'), reason: 'Question should have question_type field');
          expect(question, contains('has_been_synced'), reason: 'Question should have has_been_synced field');
          expect(question, contains('edits_are_synced'), reason: 'Question should have edits_are_synced field');
        }
      });

      test('Test 4: Should return empty list when no questions exist', () async {
        // Clear the table first
        await deleteAllRecordsFromTable('question_answer_pairs');

        final unsyncedQuestions = await getUnsyncedQuestionAnswerPairs();
        
        expect(unsyncedQuestions, isEmpty, reason: 'Should return empty list when no questions exist');
      });

      test('Test 5: Should return questions in correct format (not decoded)', () async {
        // Clear the table first
        await deleteAllRecordsFromTable('question_answer_pairs');
        
        // Add 10 questions of various types (all will be unsynced by default)
        for (int i = 0; i < 10; i++) {
          String questionId;
          
          if (i < 3) {
            // Add 3 multiple choice questions
            questionId = await addQuestionMultipleChoice(
              moduleName: 'Test Module ${i + 1}',
              questionElements: multipleChoiceData[i]['questionElements'],
              answerElements: multipleChoiceData[i]['answerElements'],
              options: multipleChoiceData[i]['options'],
              correctOptionIndex: multipleChoiceData[i]['correctOptionIndex'],
              debugDisableOutboundSyncCall: true,
            );
          } else if (i < 6) {
            // Add 3 true/false questions
            questionId = await addQuestionTrueFalse(
              moduleName: 'Test Module ${i + 1}',
              questionElements: trueFalseData[i - 3]['questionElements'],
              answerElements: trueFalseData[i - 3]['answerElements'],
              correctOptionIndex: trueFalseData[i - 3]['correctOptionIndex'],
              debugDisableOutboundSyncCall: true,
            );
          } else {
            // Add 4 fill-in-the-blank questions
            questionId = await addFillInTheBlankQuestion(
              moduleName: 'Test Module ${i + 1}',
              questionElements: fillInTheBlankData[i - 6]['questionElements'],
              answerElements: fillInTheBlankData[i - 6]['answerElements'],
              answersToBlanks: fillInTheBlankData[i - 6]['answersToBlanks'],
              debugDisableOutboundSyncCall: true,
            );
          }
          
          testQuestionIds.add(questionId);
        }

        final unsyncedQuestions = await getUnsyncedQuestionAnswerPairs();
        
        // Verify that the function returns raw database records (not decoded)
        for (final question in unsyncedQuestions) {
          // question_elements and answer_elements should be JSON strings, not decoded lists
          final questionElements = question['question_elements'] as String;
          final answerElements = question['answer_elements'] as String;
          
          expect(questionElements, isA<String>(), reason: 'question_elements should be a JSON string');
          expect(answerElements, isA<String>(), reason: 'answer_elements should be a JSON string');
          
          // Verify they are valid JSON strings
          expect(questionElements, startsWith('['), reason: 'question_elements should be a JSON array string');
          expect(answerElements, startsWith('['), reason: 'answer_elements should be a JSON array string');
        }
      });

      test('Test 6: Cleanup - Truncate question_answer_pairs table', () async {
        QuizzerLogger.logMessage('Cleaning up question_answer_pairs table after getUnsyncedQuestionAnswerPairs Tests');
        await deleteAllRecordsFromTable('question_answer_pairs');
        QuizzerLogger.logSuccess('Successfully cleaned up question_answer_pairs table after getUnsyncedQuestionAnswerPairs Tests');
      });
    });

    group('insertOrUpdateQuestionAnswerPair Tests', () {
      test('Test 1: Should insert new question from sync data', () async {
        await deleteAllRecordsFromTable('question_answer_pairs');

        final List<Map<String, dynamic>> syncData = generateCompleteQuestionAnswerPairRecord(
          numberOfQuestions: 1,
          questionType: 'multiple_choice',
        );

        final result = await insertOrUpdateQuestionAnswerPair(syncData[0]);
        expect(result, isTrue);

        // Verify the question was inserted
        final insertedQuestion = await getQuestionAnswerPairById(syncData[0]['question_id']);
        expect(insertedQuestion, isNotNull);
        expect(insertedQuestion['question_id'], equals(syncData[0]['question_id']));
        expect(insertedQuestion['module_name'], equals('testmodule0'));
        expect(insertedQuestion['question_type'], equals('multiple_choice'));
        expect(insertedQuestion['has_been_synced'], equals(1));
        expect(insertedQuestion['edits_are_synced'], equals(1));
      });

      test('Test 2: Should update existing question from sync data', () async {
        await deleteAllRecordsFromTable('question_answer_pairs');

        final List<Map<String, dynamic>> initialData = generateCompleteQuestionAnswerPairRecord(
          numberOfQuestions: 1,
          questionType: 'multiple_choice',
        );

        // First insert
        await insertOrUpdateQuestionAnswerPair(initialData[0]);

        // Create updated data with different content
        final List<Map<String, dynamic>> updatedData = generateCompleteQuestionAnswerPairRecord(
          numberOfQuestions: 1,
          questionType: 'multiple_choice',
        );
        updatedData[0]['question_id'] = initialData[0]['question_id']; // Same ID for update
        updatedData[0]['time_stamp'] = initialData[0]['time_stamp']; // Same timestamp
        updatedData[0]['module_name'] = 'UPDATED_MODULE_NAME'; // Different module name
        updatedData[0]['has_been_reviewed'] = 1; // Changed from 0 to 1

        // Update
        final result = await insertOrUpdateQuestionAnswerPair(updatedData[0]);
        expect(result, isTrue);

        // Verify the question was updated
        final updatedQuestion = await getQuestionAnswerPairById(initialData[0]['question_id']);
        expect(updatedQuestion, isNotNull);
        expect(updatedQuestion['question_id'], equals(initialData[0]['question_id']));
        expect(updatedQuestion['module_name'], equals('updated module name')); // Normalized
        expect(updatedQuestion['has_been_reviewed'], equals(1));
        expect(updatedQuestion['has_been_synced'], equals(1));
        expect(updatedQuestion['edits_are_synced'], equals(1));
      });

      test('Test 3: Should handle different question types correctly', () async {
        await deleteAllRecordsFromTable('question_answer_pairs');

        final List<Map<String, dynamic>> fillInTheBlankData = generateCompleteQuestionAnswerPairRecord(
          numberOfQuestions: 1,
          questionType: 'fill_in_the_blank',
        );

        final result = await insertOrUpdateQuestionAnswerPair(fillInTheBlankData[0]);
        expect(result, isTrue);

        // Verify the question was inserted correctly
        final insertedQuestion = await getQuestionAnswerPairById(fillInTheBlankData[0]['question_id']);
        expect(insertedQuestion, isNotNull);
        expect(insertedQuestion['question_type'], equals('fill_in_the_blank'));
        expect(insertedQuestion['has_been_synced'], equals(1));
        expect(insertedQuestion['edits_are_synced'], equals(1));
      });

      test('Test 4: Should handle missing optional fields gracefully', () async {
        await deleteAllRecordsFromTable('question_answer_pairs');

        final List<Map<String, dynamic>> minimalData = generateCompleteQuestionAnswerPairRecord(
          numberOfQuestions: 1,
          questionType: 'multiple_choice',
        );
        // Remove optional fields
        minimalData[0].remove('options');
        minimalData[0].remove('correct_option_index');
        minimalData[0].remove('has_media');

        final result = await insertOrUpdateQuestionAnswerPair(minimalData[0]);
        expect(result, isTrue);

        // Verify the question was inserted
        final insertedQuestion = await getQuestionAnswerPairById(minimalData[0]['question_id']);
        expect(insertedQuestion, isNotNull);
        expect(insertedQuestion['question_id'], equals(minimalData[0]['question_id']));
        expect(insertedQuestion['has_been_synced'], equals(1));
        expect(insertedQuestion['edits_are_synced'], equals(1));
      });

      test('Test 5: Should return false for validation failures', () async {
        await deleteAllRecordsFromTable('question_answer_pairs');

        final List<Map<String, dynamic>> invalidData = generateCompleteQuestionAnswerPairRecord(
          numberOfQuestions: 1,
          questionType: 'multiple_choice',
        );
        invalidData[0]['module_name'] = ''; // Invalid: empty module name

        final result = await insertOrUpdateQuestionAnswerPair(invalidData[0]);
        expect(result, isFalse);

        // Verify no question was inserted
        expect(
          () => getQuestionAnswerPairById(invalidData[0]['question_id']),
          throwsA(isA<StateError>()),
        );
      });

      test('Test 6: Should strip legacy fields and normalize module name', () async {
        await deleteAllRecordsFromTable('question_answer_pairs');

        final List<Map<String, dynamic>> legacyData = generateCompleteQuestionAnswerPairRecord(
          numberOfQuestions: 1,
          questionType: 'multiple_choice',
        );
        // Add legacy fields and non-normalized module name
        legacyData[0]['citation'] = 'Some citation';
        legacyData[0]['concepts'] = '["concept1", "concept2"]';
        legacyData[0]['subjects'] = '["subject1", "subject2"]';
        legacyData[0]['completed'] = 1;
        legacyData[0]['module_name'] = 'GEOGRAPHY_MODULE'; // Non-normalized

        final result = await insertOrUpdateQuestionAnswerPair(legacyData[0]);
        expect(result, isTrue);

        // Verify the question was inserted with normalized module name
        final insertedQuestion = await getQuestionAnswerPairById(legacyData[0]['question_id']);
        expect(insertedQuestion, isNotNull);
        expect(insertedQuestion['module_name'], equals('geography module')); // Should be normalized
      });

      test('Test 7: Should return false for malformed JSON in complex fields', () async {
        await deleteAllRecordsFromTable('question_answer_pairs');

        final List<Map<String, dynamic>> malformedData = generateCompleteQuestionAnswerPairRecord(
          numberOfQuestions: 1,
          questionType: 'multiple_choice',
        );
        malformedData[0]['question_elements'] = '[{"type":"text","content":"What is the capital of France?"'; // Malformed JSON

        final result = await insertOrUpdateQuestionAnswerPair(malformedData[0]);
        expect(result, isFalse);
      });

      test('Test 8: Should return true for successful operations', () async {
        await deleteAllRecordsFromTable('question_answer_pairs');

        final List<Map<String, dynamic>> validData = generateCompleteQuestionAnswerPairRecord(
          numberOfQuestions: 1,
          questionType: 'multiple_choice',
        );

        final result = await insertOrUpdateQuestionAnswerPair(validData[0]);
        expect(result, isTrue);
      });

      test('Test 9: Cleanup - Truncate question_answer_pairs table', () async {
        QuizzerLogger.logMessage('Cleaning up question_answer_pairs table after insertOrUpdateQuestionAnswerPair Tests');
        await deleteAllRecordsFromTable('question_answer_pairs');
        QuizzerLogger.logSuccess('Successfully cleaned up question_answer_pairs table after insertOrUpdateQuestionAnswerPair Tests');
      });
    });

    group('batchUpsertQuestionAnswerPairs Tests', () {
      test('Test 1: Should successfully insert multiple valid records', () async {
        await deleteAllRecordsFromTable('question_answer_pairs');

        final List<Map<String, dynamic>> records = generateCompleteQuestionAnswerPairRecord(
          numberOfQuestions: 3,
          questionType: 'multiple_choice',
        );

        await batchUpsertQuestionAnswerPairs(records: records);

        // Verify all records were inserted
        final allQuestions = await getAllQuestionAnswerPairs();
        expect(allQuestions.length, equals(3));

        // Verify each record has correct sync flags and normalized module name
        for (final question in allQuestions) {
          expect(question['has_been_synced'], equals(1));
          expect(question['edits_are_synced'], equals(1));
          expect(question['module_name'], startsWith('testmodule')); // Normalized
        }
      });

      test('Test 2: Should handle records with legacy fields by stripping them', () async {
        await deleteAllRecordsFromTable('question_answer_pairs');

        final List<Map<String, dynamic>> records = generateCompleteQuestionAnswerPairRecord(
          numberOfQuestions: 1,
          questionType: 'multiple_choice',
        );
        
        // Add legacy fields that should be stripped
        records[0]['citation'] = 'some citation';
        records[0]['concepts'] = 'some concepts';
        records[0]['subjects'] = 'some subjects';
        records[0]['completed'] = 1;

        await batchUpsertQuestionAnswerPairs(records: records);

        // Verify the record was inserted without legacy fields
        final insertedQuestion = await getQuestionAnswerPairById(records[0]['question_id']);
        expect(insertedQuestion, isNotNull);
        expect(insertedQuestion.containsKey('citation'), isFalse);
        expect(insertedQuestion.containsKey('concepts'), isFalse);
        expect(insertedQuestion.containsKey('subjects'), isFalse);
        expect(insertedQuestion.containsKey('completed'), isFalse);
      });

      test('Test 3: Should skip records with validation failures', () async {
        await deleteAllRecordsFromTable('question_answer_pairs');

        final List<Map<String, dynamic>> records = generateCompleteQuestionAnswerPairRecord(
          numberOfQuestions: 2,
          questionType: 'multiple_choice',
        );
        
        // Make the second record invalid (empty module name)
        records[1]['module_name'] = '';

        await batchUpsertQuestionAnswerPairs(records: records);

        // Verify only the valid record was inserted
        final allQuestions = await getAllQuestionAnswerPairs();
        expect(allQuestions.length, equals(1));
        expect(allQuestions.first['question_id'], equals(records[0]['question_id']));

        // Verify the invalid record was not inserted
        expect(() => getQuestionAnswerPairById(records[1]['question_id']), throwsA(isA<StateError>()));
      });

      test('Test 4: Should handle different question types correctly', () async {
        await deleteAllRecordsFromTable('question_answer_pairs');

        final List<Map<String, dynamic>> multipleChoiceRecords = generateCompleteQuestionAnswerPairRecord(
          numberOfQuestions: 1,
          questionType: 'multiple_choice',
        );
        
        final List<Map<String, dynamic>> fillInTheBlankRecords = generateCompleteQuestionAnswerPairRecord(
          numberOfQuestions: 1,
          questionType: 'fill_in_the_blank',
        );

        final List<Map<String, dynamic>> records = [...multipleChoiceRecords, ...fillInTheBlankRecords];

        await batchUpsertQuestionAnswerPairs(records: records);

        // Verify both records were inserted
        final allQuestions = await getAllQuestionAnswerPairs();
        expect(allQuestions.length, equals(2));

        // Verify question types
        final mcQuestion = allQuestions.firstWhere((q) => q['question_id'] == multipleChoiceRecords[0]['question_id']);
        final fibQuestion = allQuestions.firstWhere((q) => q['question_id'] == fillInTheBlankRecords[0]['question_id']);
        
        expect(mcQuestion['question_type'], equals('multiple_choice'));
        expect(fibQuestion['question_type'], equals('fill_in_the_blank'));
      });

      test('Test 5: Should handle empty records list gracefully', () async {
        await deleteAllRecordsFromTable('question_answer_pairs');

        await batchUpsertQuestionAnswerPairs(records: []);

        // Verify no records were inserted
        final allQuestions = await getAllQuestionAnswerPairs();
        expect(allQuestions.length, equals(0));
      });

      test('Test 6: Cleanup - Truncate question_answer_pairs table', () async {
        QuizzerLogger.logMessage('Cleaning up question_answer_pairs table after batchUpsertQuestionAnswerPairs Tests');
        await deleteAllRecordsFromTable('question_answer_pairs');
        QuizzerLogger.logSuccess('Successfully cleaned up question_answer_pairs table after batchUpsertQuestionAnswerPairs Tests');
      });
    });

  // DONT WRITE ANYTHING PAST HERE, AND DONT DELETE MY FUCKING COMMENTS
  // THIS IS YOUR FUCKING BOUNDARY DON'T YOU DARE FUCKING DO IT, DON'T YOU DARE WRITE ANY LINE OF FUCKING TEST PAST THIS FUCKING LINE YOU FUCKING DIMWITTED SON OF A BITCH
  });

  // NEXT GROUP HERE
  group('User Settings Table Tests', () {
    group('verifyUserSettingsTable Tests', () {
      test('Test 1: Should create table and populate default settings when table does not exist', () async {
        QuizzerLogger.logMessage('Testing verifyUserSettingsTable - table creation and default settings');
        
        // Get the user ID from SessionManager (established pattern)
        final userId = sessionManager.userId!;
        QuizzerLogger.logMessage('Using user ID: $userId for user settings operations');
        
        // Setup: Ensure clean state by dropping table if it exists
        await dropTable('user_settings');
        QuizzerLogger.logMessage('Cleaned up existing user_settings table');
        
        // Execute: Call getAllUserSettings which internally calls the verification function
        final allSettings = await getAllUserSettings(userId);
        
        // Verify: Check that table was created
        final db2 = await getDatabaseMonitor().requestDatabaseAccess();
        if (db2 != null) {
          try {
            final List<Map<String, dynamic>> tables = await db2.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='user_settings'"
            );
            expect(tables.length, equals(1), reason: 'user_settings table should exist');
            
            // Check table structure
            final List<Map<String, dynamic>> columns = await db2.rawQuery(
              "PRAGMA table_info(user_settings)"
            );
            
            // Verify all required columns exist
            final List<String> columnNames = columns.map((col) => col['name'] as String).toList();
            
            expect(columnNames, contains('user_id'), reason: 'user_id column should exist');
            expect(columnNames, contains('setting_name'), reason: 'setting_name column should exist');
            expect(columnNames, contains('setting_value'), reason: 'setting_value column should exist');
            expect(columnNames, contains('has_been_synced'), reason: 'has_been_synced column should exist');
            expect(columnNames, contains('edits_are_synced'), reason: 'edits_are_synced column should exist');
            expect(columnNames, contains('last_modified_timestamp'), reason: 'last_modified_timestamp column should exist');
            expect(columnNames, contains('is_admin_setting'), reason: 'is_admin_setting column should exist');
            
            // Verify that all default settings are populated (11 settings from _applicationSettings)
            expect(allSettings.length, equals(11), reason: 'Should have 11 default settings populated');
            
            // Verify specific settings exist with correct default values
            // Check admin setting
            expect(allSettings.containsKey('geminiApiKey'), isTrue, reason: 'geminiApiKey setting should exist');
            expect(allSettings['geminiApiKey']!['value'], isNull, reason: 'geminiApiKey should have null default value');
            expect(allSettings['geminiApiKey']!['is_admin_setting'], equals(1), reason: 'geminiApiKey should be admin setting');
            
            // Check some user settings
            expect(allSettings.containsKey('home_display_eligible_questions'), isTrue, reason: 'home_display_eligible_questions setting should exist');
            expect(allSettings['home_display_eligible_questions']!['value'], equals('0'), reason: 'home_display_eligible_questions should have "0" default value');
            expect(allSettings['home_display_eligible_questions']!['is_admin_setting'], equals(0), reason: 'home_display_eligible_questions should not be admin setting');
            
            expect(allSettings.containsKey('home_display_in_circulation_questions'), isTrue, reason: 'home_display_in_circulation_questions setting should exist');
            expect(allSettings['home_display_in_circulation_questions']!['value'], equals('0'), reason: 'home_display_in_circulation_questions should have "0" default value');
            
            expect(allSettings.containsKey('home_display_non_circulating_questions'), isTrue, reason: 'home_display_non_circulating_questions setting should exist');
            expect(allSettings['home_display_non_circulating_questions']!['value'], equals('0'), reason: 'home_display_non_circulating_questions should have "0" default value');
            
            expect(allSettings.containsKey('home_display_lifetime_total_questions_answered'), isTrue, reason: 'home_display_lifetime_total_questions_answered setting should exist');
            expect(allSettings['home_display_lifetime_total_questions_answered']!['value'], equals('0'), reason: 'home_display_lifetime_total_questions_answered should have "0" default value');
            
            expect(allSettings.containsKey('home_display_daily_questions_answered'), isTrue, reason: 'home_display_daily_questions_answered setting should exist');
            expect(allSettings['home_display_daily_questions_answered']!['value'], equals('0'), reason: 'home_display_daily_questions_answered should have "0" default value');
            
            expect(allSettings.containsKey('home_display_average_daily_questions_learned'), isTrue, reason: 'home_display_average_daily_questions_learned setting should exist');
            expect(allSettings['home_display_average_daily_questions_learned']!['value'], equals('0'), reason: 'home_display_average_daily_questions_learned should have "0" default value');
            
            expect(allSettings.containsKey('home_display_average_questions_shown_per_day'), isTrue, reason: 'home_display_average_questions_shown_per_day setting should exist');
            expect(allSettings['home_display_average_questions_shown_per_day']!['value'], equals('0'), reason: 'home_display_average_questions_shown_per_day should have "0" default value');
            
            expect(allSettings.containsKey('home_display_days_left_until_questions_exhaust'), isTrue, reason: 'home_display_days_left_until_questions_exhaust setting should exist');
            expect(allSettings['home_display_days_left_until_questions_exhaust']!['value'], equals('0'), reason: 'home_display_days_left_until_questions_exhaust should have "0" default value');
            
            expect(allSettings.containsKey('home_display_revision_streak_score'), isTrue, reason: 'home_display_revision_streak_score setting should exist');
            expect(allSettings['home_display_revision_streak_score']!['value'], equals('0'), reason: 'home_display_revision_streak_score should have "0" default value');
            
            expect(allSettings.containsKey('home_display_last_reviewed'), isTrue, reason: 'home_display_last_reviewed setting should exist');
            expect(allSettings['home_display_last_reviewed']!['value'], equals('0'), reason: 'home_display_last_reviewed should have "0" default value');
            
            QuizzerLogger.logSuccess('✅ verifyUserSettingsTable table creation and default settings test passed');
            
          } finally {
            getDatabaseMonitor().releaseDatabaseAccess();
          }
        }
      });
      
      test('Test 2: Should repopulate default settings when table exists but is empty', () async {
        QuizzerLogger.logMessage('Testing verifyUserSettingsTable - repopulate default settings');
        
        // Get the user ID from SessionManager (established pattern)
        final userId = sessionManager.userId!;
        QuizzerLogger.logMessage('Using user ID: $userId for user settings operations');
        
        // Setup: Delete all records from the table
        await deleteAllRecordsFromTable('user_settings');
        QuizzerLogger.logMessage('Deleted all records from user_settings table');
        
        // Verify: Check that the table is actually empty by querying the database directly
        final db1 = await getDatabaseMonitor().requestDatabaseAccess();
        if (db1 != null) {
          try {
            final List<Map<String, dynamic>> emptyResults = await db1.rawQuery(
              'SELECT COUNT(*) as count FROM user_settings WHERE user_id = ?',
              [userId]
            );
            final int count = emptyResults.first['count'] as int;
            expect(count, equals(0), reason: 'Table should be empty after deleting all records');
            QuizzerLogger.logMessage('Verified table is empty: $count records found');
          } finally {
            getDatabaseMonitor().releaseDatabaseAccess();
          }
        }
        
        // Execute: Call getSettingValue which internally calls the verification function
        // This will trigger the verification and repopulation of default settings
        await getSettingValue(userId, 'geminiApiKey');
        
        // Verify: Check that settings were repopulated by querying the database directly
        final db2 = await getDatabaseMonitor().requestDatabaseAccess();
        if (db2 != null) {
          try {
            final List<Map<String, dynamic>> populatedResults = await db2.rawQuery(
              'SELECT COUNT(*) as count FROM user_settings WHERE user_id = ?',
              [userId]
            );
            final int count = populatedResults.first['count'] as int;
            expect(count, equals(11), reason: 'Table should have 11 default settings after verification');
            QuizzerLogger.logMessage('Verified table was repopulated: $count records found');
          } finally {
            getDatabaseMonitor().releaseDatabaseAccess();
          }
        }
        
        // Now get all settings to verify they were repopulated correctly
        final allSettings = await getAllUserSettings(userId);
        
        // Verify: Check that all default settings are repopulated
        expect(allSettings.length, equals(11), reason: 'Should have 11 default settings repopulated');
        
        // Verify specific settings exist with correct default values
        // Check admin setting
        expect(allSettings.containsKey('geminiApiKey'), isTrue, reason: 'geminiApiKey setting should exist');
        expect(allSettings['geminiApiKey']!['value'], isNull, reason: 'geminiApiKey should have null default value');
        expect(allSettings['geminiApiKey']!['is_admin_setting'], equals(1), reason: 'geminiApiKey should be admin setting');
        
        // Check some user settings
        expect(allSettings.containsKey('home_display_eligible_questions'), isTrue, reason: 'home_display_eligible_questions setting should exist');
        expect(allSettings['home_display_eligible_questions']!['value'], equals('0'), reason: 'home_display_eligible_questions should have "0" default value');
        expect(allSettings['home_display_eligible_questions']!['is_admin_setting'], equals(0), reason: 'home_display_eligible_questions should not be admin setting');
        
        expect(allSettings.containsKey('home_display_in_circulation_questions'), isTrue, reason: 'home_display_in_circulation_questions setting should exist');
        expect(allSettings['home_display_in_circulation_questions']!['value'], equals('0'), reason: 'home_display_in_circulation_questions should have "0" default value');
        
        expect(allSettings.containsKey('home_display_non_circulating_questions'), isTrue, reason: 'home_display_non_circulating_questions setting should exist');
        expect(allSettings['home_display_non_circulating_questions']!['value'], equals('0'), reason: 'home_display_non_circulating_questions should have "0" default value');
        
        expect(allSettings.containsKey('home_display_lifetime_total_questions_answered'), isTrue, reason: 'home_display_lifetime_total_questions_answered setting should exist');
        expect(allSettings['home_display_lifetime_total_questions_answered']!['value'], equals('0'), reason: 'home_display_lifetime_total_questions_answered should have "0" default value');
        
        expect(allSettings.containsKey('home_display_daily_questions_answered'), isTrue, reason: 'home_display_daily_questions_answered setting should exist');
        expect(allSettings['home_display_daily_questions_answered']!['value'], equals('0'), reason: 'home_display_daily_questions_answered should have "0" default value');
        
        expect(allSettings.containsKey('home_display_average_daily_questions_learned'), isTrue, reason: 'home_display_average_daily_questions_learned setting should exist');
        expect(allSettings['home_display_average_daily_questions_learned']!['value'], equals('0'), reason: 'home_display_average_daily_questions_learned should have "0" default value');
        
        expect(allSettings.containsKey('home_display_average_questions_shown_per_day'), isTrue, reason: 'home_display_average_questions_shown_per_day setting should exist');
        expect(allSettings['home_display_average_questions_shown_per_day']!['value'], equals('0'), reason: 'home_display_average_questions_shown_per_day should have "0" default value');
        
        expect(allSettings.containsKey('home_display_days_left_until_questions_exhaust'), isTrue, reason: 'home_display_days_left_until_questions_exhaust setting should exist');
        expect(allSettings['home_display_days_left_until_questions_exhaust']!['value'], equals('0'), reason: 'home_display_days_left_until_questions_exhaust should have "0" default value');
        
        expect(allSettings.containsKey('home_display_revision_streak_score'), isTrue, reason: 'home_display_revision_streak_score setting should exist');
        expect(allSettings['home_display_revision_streak_score']!['value'], equals('0'), reason: 'home_display_revision_streak_score should have "0" default value');
        
        expect(allSettings.containsKey('home_display_last_reviewed'), isTrue, reason: 'home_display_last_reviewed setting should exist');
        expect(allSettings['home_display_last_reviewed']!['value'], equals('0'), reason: 'home_display_last_reviewed should have "0" default value');
        
        QuizzerLogger.logSuccess('✅ verifyUserSettingsTable repopulate default settings test passed');
      });
     });
   
    group('batchUpsertUserSettingsFromSupabase Tests', () {
      setUp(() async {
        // Clear the user_settings table to ensure clean state for each test
        await deleteAllRecordsFromTable('user_settings');
      });

      test('Test 1: Should handle batch upsert and repeated ensure function calls', () async {
        QuizzerLogger.logMessage('Testing batchUpsertUserSettingsFromSupabase with repeated ensure function calls');
        
        // Get the user ID from SessionManager (established pattern)
        final userId = sessionManager.userId!;
        QuizzerLogger.logMessage('Using user ID: $userId for batch upsert tests');
        
        // Setup: Create mock records for each setting
        final List<Map<String, dynamic>> mockSettingsData = [
          {
            'user_id': userId,
            'setting_name': 'geminiApiKey',
            'setting_value': 'test-api-key-12345',
            'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
            'is_admin_setting': true,
          },
          {
            'user_id': userId,
            'setting_name': 'home_display_eligible_questions',
            'setting_value': '1',
            'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
            'is_admin_setting': false,
          },
          {
            'user_id': userId,
            'setting_name': 'home_display_in_circulation_questions',
            'setting_value': '1',
            'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
            'is_admin_setting': false,
          },
          {
            'user_id': userId,
            'setting_name': 'home_display_non_circulating_questions',
            'setting_value': '1',
            'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
            'is_admin_setting': false,
          },
          {
            'user_id': userId,
            'setting_name': 'home_display_lifetime_total_questions_answered',
            'setting_value': '1',
            'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
            'is_admin_setting': false,
          },
          {
            'user_id': userId,
            'setting_name': 'home_display_daily_questions_answered',
            'setting_value': '1',
            'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
            'is_admin_setting': false,
          },
          {
            'user_id': userId,
            'setting_name': 'home_display_average_daily_questions_learned',
            'setting_value': '1',
            'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
            'is_admin_setting': false,
          },
          {
            'user_id': userId,
            'setting_name': 'home_display_average_questions_shown_per_day',
            'setting_value': '1',
            'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
            'is_admin_setting': false,
          },
          {
            'user_id': userId,
            'setting_name': 'home_display_days_left_until_questions_exhaust',
            'setting_value': '1',
            'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
            'is_admin_setting': false,
          },
          {
            'user_id': userId,
            'setting_name': 'home_display_revision_streak_score',
            'setting_value': '1',
            'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
            'is_admin_setting': false,
          },
          {
            'user_id': userId,
            'setting_name': 'home_display_last_reviewed',
            'setting_value': '1',
            'last_modified_timestamp': '2025-01-15T10:30:00.000Z',
            'is_admin_setting': false,
          },
        ];
        
        QuizzerLogger.logMessage('Created ${mockSettingsData.length} mock settings records for testing');
        
        // Step 1: Delete all records
        await deleteAllRecordsFromTable('user_settings');
        QuizzerLogger.logMessage('Deleted all records from user_settings table');
        
        // Step 2: Call the batch upsert
        await batchUpsertUserSettingsFromSupabase(mockSettingsData, userId);
        QuizzerLogger.logMessage('Called batchUpsertUserSettingsFromSupabase');
        
         // Step 3: Immediately call verify table again (through getAllUserSettings)
         await getAllUserSettings(userId);
         QuizzerLogger.logMessage('Called getAllUserSettings after batch upsert (triggers _verifyUserSettingsTable)');
         
         // Step 4: Call ensureAllRecords function by itself (first time) - through getSettingValue
         final step4Result = await getSettingValue(userId, 'geminiApiKey');
         expect(step4Result!['value'], equals('test-api-key-12345'), reason: 'Step 4: geminiApiKey should return the batch upsert value');
         QuizzerLogger.logMessage('Called getSettingValue (first time) - triggers _ensureUserSettingsRowsExist');
         
         // Step 5: Call it again (second time) - through getSettingValue
         final step5Result = await getSettingValue(userId, 'home_display_eligible_questions');
         expect(step5Result!['value'], equals('1'), reason: 'Step 5: home_display_eligible_questions should return the batch upsert value');
         QuizzerLogger.logMessage('Called getSettingValue (second time) - triggers _ensureUserSettingsRowsExist');
         
         // Step 6: Call it a third time - through getSettingValue
         final step6Result = await getSettingValue(userId, 'home_display_in_circulation_questions');
         expect(step6Result!['value'], equals('1'), reason: 'Step 6: home_display_in_circulation_questions should return the batch upsert value');
         QuizzerLogger.logMessage('Called getSettingValue (third time) - triggers _ensureUserSettingsRowsExist');
        
        // Step 7: Test expectations - ensure the settings were updated correctly and match what we fed into the batch upsert
        final allSettings = await getAllUserSettings(userId);
        
        // Verify we have all 11 settings
        expect(allSettings.length, equals(11), reason: 'Should have 11 settings after batch upsert and repeated ensure calls');
        
        // Verify specific settings match our mock data
        expect(allSettings['geminiApiKey']!['value'], equals('test-api-key-12345'), reason: 'geminiApiKey should match mock data');
        expect(allSettings['geminiApiKey']!['is_admin_setting'], equals(1), reason: 'geminiApiKey should be admin setting');
        
        expect(allSettings['home_display_eligible_questions']!['value'], equals('1'), reason: 'home_display_eligible_questions should match mock data');
        expect(allSettings['home_display_eligible_questions']!['is_admin_setting'], equals(0), reason: 'home_display_eligible_questions should not be admin setting');
        
        expect(allSettings['home_display_in_circulation_questions']!['value'], equals('1'), reason: 'home_display_in_circulation_questions should match mock data');
        expect(allSettings['home_display_non_circulating_questions']!['value'], equals('1'), reason: 'home_display_non_circulating_questions should match mock data');
        expect(allSettings['home_display_lifetime_total_questions_answered']!['value'], equals('1'), reason: 'home_display_lifetime_total_questions_answered should match mock data');
        expect(allSettings['home_display_daily_questions_answered']!['value'], equals('1'), reason: 'home_display_daily_questions_answered should match mock data');
        expect(allSettings['home_display_average_daily_questions_learned']!['value'], equals('1'), reason: 'home_display_average_daily_questions_learned should match mock data');
        expect(allSettings['home_display_average_questions_shown_per_day']!['value'], equals('1'), reason: 'home_display_average_questions_shown_per_day should match mock data');
        expect(allSettings['home_display_days_left_until_questions_exhaust']!['value'], equals('1'), reason: 'home_display_days_left_until_questions_exhaust should match mock data');
        expect(allSettings['home_display_revision_streak_score']!['value'], equals('1'), reason: 'home_display_revision_streak_score should match mock data');
        expect(allSettings['home_display_last_reviewed']!['value'], equals('1'), reason: 'home_display_last_reviewed should match mock data');
        
        QuizzerLogger.logSuccess('✅ batchUpsertUserSettingsFromSupabase with repeated ensure function calls test passed');
      });

      test('Test 2: Should handle empty settings list gracefully', () async {
        final userId = sessionManager.userId!;
        
        // Get initial state
        final initialSettings = await getAllUserSettings(userId);
        
        // Store some initial values to verify they don't change
        final initialGeminiValue = initialSettings['geminiApiKey']!['value'];
        final initialEligibleValue = initialSettings['home_display_eligible_questions']!['value'];
        
        final List<Map<String, dynamic>> emptySettingsData = [];
        
        // Should not throw an error
        await batchUpsertUserSettingsFromSupabase(emptySettingsData, userId);
        
        // Verify settings remain unchanged
        final finalSettings = await getAllUserSettings(userId);
        expect(finalSettings['geminiApiKey']!['value'], equals(initialGeminiValue), reason: 'geminiApiKey should remain unchanged');
        expect(finalSettings['home_display_eligible_questions']!['value'], equals(initialEligibleValue), reason: 'home_display_eligible_questions should remain unchanged');
        
        QuizzerLogger.logSuccess('✅ batchUpsertUserSettingsFromSupabase empty list test passed');
      });

      test('Test 3: Should handle partial settings update (subset of settings)', () async {
        final userId = sessionManager.userId!;
        
        // Clear records to ensure clean state
        await deleteAllRecordsFromTable('user_settings');
        
        // Get initial state after clearing
        final initialSettings = await getAllUserSettings(userId);
        
        // Store initial values to verify they change
        final initialGeminiValue = initialSettings['geminiApiKey']!['value'];
        final initialEligibleValue = initialSettings['home_display_eligible_questions']!['value'];
        final initialCirculationValue = initialSettings['home_display_in_circulation_questions']!['value'];
        
        // Create settings with only a subset of settings
        final List<Map<String, dynamic>> partialSettingsData = [
          {
            'user_id': userId,
            'setting_name': 'geminiApiKey',
            'setting_value': 'partial-update-api-key',
            'last_modified_timestamp': '2025-01-15T11:00:00.000Z',
            'is_admin_setting': true,
          },
          {
            'user_id': userId,
            'setting_name': 'home_display_eligible_questions',
            'setting_value': '1',
            'last_modified_timestamp': '2025-01-15T11:00:00.000Z',
            'is_admin_setting': false,
          },
        ];
        
        await batchUpsertUserSettingsFromSupabase(partialSettingsData, userId);
        
        // Verify updated settings changed from initial values
        final finalSettings = await getAllUserSettings(userId);
        expect(finalSettings['geminiApiKey']!['value'], equals('partial-update-api-key'), reason: 'geminiApiKey should be updated to new value');
        expect(finalSettings['geminiApiKey']!['value'], isNot(equals(initialGeminiValue)), reason: 'geminiApiKey should be different from initial value');
        expect(finalSettings['home_display_eligible_questions']!['value'], equals('1'), reason: 'home_display_eligible_questions should be updated to new value');
        expect(finalSettings['home_display_eligible_questions']!['value'], isNot(equals(initialEligibleValue)), reason: 'home_display_eligible_questions should be different from initial value');
        
        // Verify untouched settings remain unchanged
        expect(finalSettings['home_display_in_circulation_questions']!['value'], equals(initialCirculationValue), reason: 'Untouched setting should remain unchanged');
        
        QuizzerLogger.logSuccess('✅ batchUpsertUserSettingsFromSupabase partial update test passed');
      });

      test('Test 4: Should handle mixed data types in batch update', () async {
        final userId = sessionManager.userId!;
        
        // Clear records to ensure clean state
        await deleteAllRecordsFromTable('user_settings');
        
        // Get initial state after clearing
        final initialSettings = await getAllUserSettings(userId);
        
        // Store initial values to verify they change
        final initialGeminiValue = initialSettings['geminiApiKey']!['value'];
        final initialEligibleValue = initialSettings['home_display_eligible_questions']!['value'];
        final initialCirculationValue = initialSettings['home_display_in_circulation_questions']!['value'];
        final initialDailyValue = initialSettings['home_display_daily_questions_answered']!['value'];
        final initialAverageValue = initialSettings['home_display_average_daily_questions_learned']!['value'];
        
        final List<Map<String, dynamic>> mixedDataTypesSettings = [
          {
            'user_id': userId,
            'setting_name': 'geminiApiKey',
            'setting_value': 'test-api-key-value', // change from null to string
            'last_modified_timestamp': '2025-01-15T12:00:00.000Z',
            'is_admin_setting': true,
          },
          {
            'user_id': userId,
            'setting_name': 'home_display_eligible_questions',
            'setting_value': true, // boolean true
            'last_modified_timestamp': '2025-01-15T12:00:00.000Z',
            'is_admin_setting': false,
          },
          {
            'user_id': userId,
            'setting_name': 'home_display_in_circulation_questions',
            'setting_value': true, // boolean true - change from '0' to '1'
            'last_modified_timestamp': '2025-01-15T12:00:00.000Z',
            'is_admin_setting': false,
          },
          {
            'user_id': userId,
            'setting_name': 'home_display_daily_questions_answered',
            'setting_value': true, // boolean true
            'last_modified_timestamp': '2025-01-15T12:00:00.000Z',
            'is_admin_setting': false,
          },
          {
            'user_id': userId,
            'setting_name': 'home_display_average_daily_questions_learned',
            'setting_value': true, // boolean true - change from '0' to '1'
            'last_modified_timestamp': '2025-01-15T12:00:00.000Z',
            'is_admin_setting': false,
          },
        ];
        
        await batchUpsertUserSettingsFromSupabase(mixedDataTypesSettings, userId);
        
        // Verify each data type is handled correctly and changed from initial values
        final finalSettings = await getAllUserSettings(userId);
        expect(finalSettings['geminiApiKey']!['value'], equals('test-api-key-value'), reason: 'String value should be stored correctly');
        expect(finalSettings['geminiApiKey']!['value'], isNot(equals(initialGeminiValue)), reason: 'geminiApiKey should be different from initial value');
        expect(finalSettings['home_display_eligible_questions']!['value'], equals('1'), reason: 'Boolean true should be stored as "1"');
        expect(finalSettings['home_display_eligible_questions']!['value'], isNot(equals(initialEligibleValue)), reason: 'home_display_eligible_questions should be different from initial value');
        expect(finalSettings['home_display_in_circulation_questions']!['value'], equals('1'), reason: 'Boolean true should be stored as "1"');
        expect(finalSettings['home_display_in_circulation_questions']!['value'], isNot(equals(initialCirculationValue)), reason: 'home_display_in_circulation_questions should be different from initial value');
        expect(finalSettings['home_display_daily_questions_answered']!['value'], equals('1'), reason: 'Boolean true should be stored as "1"');
        expect(finalSettings['home_display_daily_questions_answered']!['value'], isNot(equals(initialDailyValue)), reason: 'home_display_daily_questions_answered should be different from initial value');
        expect(finalSettings['home_display_average_daily_questions_learned']!['value'], equals('1'), reason: 'Boolean true should be stored as "1"');
        expect(finalSettings['home_display_average_daily_questions_learned']!['value'], isNot(equals(initialAverageValue)), reason: 'home_display_average_daily_questions_learned should be different from initial value');
        
        QuizzerLogger.logSuccess('✅ batchUpsertUserSettingsFromSupabase mixed data types test passed');
      });

      test('Test 5: Should handle empty string values', () async {
        final userId = sessionManager.userId!;
        
        final List<Map<String, dynamic>> emptyStringSettings = [
          {
            'user_id': userId,
            'setting_name': 'geminiApiKey',
            'setting_value': '', // Empty string
            'last_modified_timestamp': '2025-01-15T16:00:00.000Z',
            'is_admin_setting': true,
          },
        ];
        
        await batchUpsertUserSettingsFromSupabase(emptyStringSettings, userId);
        
        // Verify empty string is stored correctly
        final result = await getSettingValue(userId, 'geminiApiKey');
        expect(result!['value'], equals(''), reason: 'Empty string should be stored correctly');
        
        QuizzerLogger.logSuccess('✅ batchUpsertUserSettingsFromSupabase empty string test passed');
      });

      test('Test 6: Should handle invalid setting names gracefully', () async {
        final userId = sessionManager.userId!;
        
        // Get initial state
        final initialSettings = await getAllUserSettings(userId);
        final initialGeminiValue = initialSettings['geminiApiKey']!['value'];
        
        final List<Map<String, dynamic>> invalidSettingData = [
          {
            'user_id': userId,
            'setting_name': 'invalid_setting_name', // Not in _applicationSettings
            'setting_value': 'some-value',
            'last_modified_timestamp': '2025-01-15T17:00:00.000Z',
            'is_admin_setting': false,
          },
        ];
        
        // Should handle gracefully without crashing
        await batchUpsertUserSettingsFromSupabase(invalidSettingData, userId);
        
        // Verify existing settings remain unchanged
        final finalSettings = await getAllUserSettings(userId);
        expect(finalSettings['geminiApiKey']!['value'], equals(initialGeminiValue), reason: 'Existing settings should remain unchanged');
        
        QuizzerLogger.logSuccess('✅ batchUpsertUserSettingsFromSupabase invalid setting name test passed');
      });

      test('Test 7: Should handle missing timestamp gracefully', () async {
        final userId = sessionManager.userId!;
        
        // Get initial state
        final initialSettings = await getAllUserSettings(userId);
        final initialGeminiValue = initialSettings['geminiApiKey']!['value'];
        
        final List<Map<String, dynamic>> missingTimestampData = [
          {
            'user_id': userId,
            'setting_name': 'geminiApiKey',
            'setting_value': 'api-key-without-timestamp',
            // Missing last_modified_timestamp
            'is_admin_setting': true,
          },
        ];
        
        // Should handle gracefully without crashing
        await batchUpsertUserSettingsFromSupabase(missingTimestampData, userId);
        
        // Verify existing settings remain unchanged
        final finalSettings = await getAllUserSettings(userId);
        expect(finalSettings['geminiApiKey']!['value'], equals(initialGeminiValue), reason: 'Existing settings should remain unchanged');
        
        QuizzerLogger.logSuccess('✅ batchUpsertUserSettingsFromSupabase missing timestamp test passed');
      });

      test('Test 8: Should handle sync flags correctly after batch update', () async {
        final userId = sessionManager.userId!;
        
        final List<Map<String, dynamic>> syncTestSettings = [
          {
            'user_id': userId,
            'setting_name': 'geminiApiKey',
            'setting_value': 'sync-test-api-key',
            'last_modified_timestamp': '2025-01-15T18:00:00.000Z',
            'is_admin_setting': true,
          },
        ];
        
        await batchUpsertUserSettingsFromSupabase(syncTestSettings, userId);
        
        // Verify sync flags are set correctly (should be 1 for cloud data)
        final db = await getDatabaseMonitor().requestDatabaseAccess();
        final syncResult = await db!.query(
          'user_settings',
          where: 'user_id = ? AND setting_name = ?',
          whereArgs: [userId, 'geminiApiKey'],
        );
        getDatabaseMonitor().releaseDatabaseAccess();
        
        expect(syncResult.first['has_been_synced'], equals(1), reason: 'has_been_synced should be 1 after batch upsert');
        expect(syncResult.first['edits_are_synced'], equals(1), reason: 'edits_are_synced should be 1 after batch upsert');
        expect(syncResult.first['last_modified_timestamp'], equals('2025-01-15T18:00:00.000Z'), reason: 'timestamp should match cloud timestamp');
        
        QuizzerLogger.logSuccess('✅ batchUpsertUserSettingsFromSupabase sync flags test passed');
      });

      test('Test 9: Should handle multiple batch updates in sequence', () async {
        final userId = sessionManager.userId!;
        
        // First batch update
        final List<Map<String, dynamic>> firstBatch = [
          {
            'user_id': userId,
            'setting_name': 'geminiApiKey',
            'setting_value': 'first-batch-api-key',
            'last_modified_timestamp': '2025-01-15T19:00:00.000Z',
            'is_admin_setting': true,
          },
        ];
        
        await batchUpsertUserSettingsFromSupabase(firstBatch, userId);
        
        // Second batch update
        final List<Map<String, dynamic>> secondBatch = [
          {
            'user_id': userId,
            'setting_name': 'geminiApiKey',
            'setting_value': 'second-batch-api-key',
            'last_modified_timestamp': '2025-01-15T19:30:00.000Z',
            'is_admin_setting': true,
          },
          {
            'user_id': userId,
            'setting_name': 'home_display_eligible_questions',
            'setting_value': '1',
            'last_modified_timestamp': '2025-01-15T19:30:00.000Z',
            'is_admin_setting': false,
          },
        ];
        
        await batchUpsertUserSettingsFromSupabase(secondBatch, userId);
        
        // Verify final state
        final geminiResult = await getSettingValue(userId, 'geminiApiKey');
        final eligibleResult = await getSettingValue(userId, 'home_display_eligible_questions');
        
        expect(geminiResult!['value'], equals('second-batch-api-key'), reason: 'Second batch should overwrite first');
        expect(eligibleResult!['value'], equals('1'), reason: 'Second batch should add new setting');
        
        QuizzerLogger.logSuccess('✅ batchUpsertUserSettingsFromSupabase multiple batch updates test passed');
      });
     });
   
    group('updateUserSetting Tests', () {
      setUp(() async {
        // Clear the user_settings table to ensure clean state for each test
        await deleteAllRecordsFromTable('user_settings');
      });

      test('Test 1: Should update existing setting with new string value', () async {
        // Setup: Get user ID and ensure settings exist
        final userId = sessionManager.userId!;
        
        // Update with new value
        const newValue = 'updated-api-key-98765';
        final rowsAffected = await updateUserSetting(userId, 'geminiApiKey', newValue);
        
        // Verify rows affected
        expect(rowsAffected, equals(1), reason: 'Should affect 1 row when updating existing setting');
        
        // Verify the value was actually updated
        final updatedResult = await getSettingValue(userId, 'geminiApiKey');
        expect(updatedResult!['value'], equals(newValue), reason: 'Setting value should be updated');
        
        QuizzerLogger.logSuccess('✅ updateUserSetting with string value test passed');
      });
         
      test('Test 2: Should update boolean setting correctly', () async {
        final userId = sessionManager.userId!;
        
        // Update boolean setting
        const newValue = true;
        final rowsAffected = await updateUserSetting(userId, 'home_display_eligible_questions', newValue);
        
        expect(rowsAffected, equals(1), reason: 'Should affect 1 row when updating boolean setting');
        
        // Verify the value was updated (should be stored as '1' in DB)
        final updatedResult = await getSettingValue(userId, 'home_display_eligible_questions');
        expect(updatedResult!['value'], equals('1'), reason: 'Boolean true should be stored as "1"');
        
        QuizzerLogger.logSuccess('✅ updateUserSetting with boolean value test passed');
      });
         
      test('Test 3: Should update setting with null value', () async {
        final userId = sessionManager.userId!;
        
        // Update with null value
        final rowsAffected = await updateUserSetting(userId, 'geminiApiKey', null);
        
        expect(rowsAffected, equals(1), reason: 'Should affect 1 row when updating with null');
        
        // Verify null value is stored
        final updatedResult = await getSettingValue(userId, 'geminiApiKey');
        expect(updatedResult!['value'], isNull, reason: 'Null value should be stored as null');
        
        QuizzerLogger.logSuccess('✅ updateUserSetting with null value test passed');
      });
       
      test('Test 4: Should set sync flags correctly in normal mode', () async {
        final userId = sessionManager.userId!;
        
        // Update in normal mode
        await updateUserSetting(userId, 'home_display_in_circulation_questions', true);
        
        // Verify the setting was updated
        final updatedResult = await getSettingValue(userId, 'home_display_in_circulation_questions');
        expect(updatedResult!['value'], equals('1'), reason: 'Setting should be updated in normal mode');
        
        // Verify sync flags are set correctly for normal mode
        final db = await getDatabaseMonitor().requestDatabaseAccess();
        final syncResult = await db!.query(
          'user_settings',
          where: 'user_id = ? AND setting_name = ?',
          whereArgs: [userId, 'home_display_in_circulation_questions'],
        );
        getDatabaseMonitor().releaseDatabaseAccess();
        
        expect(syncResult.first['edits_are_synced'], equals(0), reason: 'edits_are_synced should be 0 in normal mode');
        expect(syncResult.first['has_been_synced'], equals(0), reason: 'has_been_synced should remain 0 in normal mode');
        
        QuizzerLogger.logSuccess('✅ updateUserSetting sync flags in normal mode test passed');
      });
         
      test('Test 5: Should set sync flags correctly in skip sync mode', () async {
        final userId = sessionManager.userId!;
        const cloudTimestamp = '2025-01-15T12:00:00.000Z';
        
        // Update in skip sync mode
        await updateUserSetting(
          userId, 
          'home_display_non_circulating_questions', 
          true, 
          skipSyncFlags: true, 
          cloudTimestamp: cloudTimestamp
        );
        
        // Verify the setting was updated
        final updatedResult = await getSettingValue(userId, 'home_display_non_circulating_questions');
        expect(updatedResult!['value'], equals('1'), reason: 'Setting should be updated in skip sync mode');
        
        // Verify sync flags are set correctly for skip sync mode
        final db = await getDatabaseMonitor().requestDatabaseAccess();
        final syncResult = await db!.query(
          'user_settings',
          where: 'user_id = ? AND setting_name = ?',
          whereArgs: [userId, 'home_display_non_circulating_questions'],
        );
        getDatabaseMonitor().releaseDatabaseAccess();
        
        expect(syncResult.first['edits_are_synced'], equals(1), reason: 'edits_are_synced should be 1 in skip sync mode');
        expect(syncResult.first['has_been_synced'], equals(1), reason: 'has_been_synced should be 1 in skip sync mode');
        expect(syncResult.first['last_modified_timestamp'], equals(cloudTimestamp), reason: 'should use cloud timestamp in skip sync mode');
        
        QuizzerLogger.logSuccess('✅ updateUserSetting sync flags in skip sync mode test passed');
      });
         
      test('Test 6: Should use cloud timestamp when skipSyncFlags is true', () async {
        final userId = sessionManager.userId!;
        const cloudTimestamp = '2025-01-15T12:30:00.000Z';
        
        // Update with skip sync flags and cloud timestamp
        await updateUserSetting(
          userId, 
          'home_display_lifetime_total_questions_answered', 
          true, 
          skipSyncFlags: true, 
          cloudTimestamp: cloudTimestamp
        );
        
        // Verify the update succeeded
        final updatedResult = await getSettingValue(userId, 'home_display_lifetime_total_questions_answered');
        expect(updatedResult!['value'], equals('1'), reason: 'Setting should be updated');
        
        // Verify cloud timestamp is used
        final db = await getDatabaseMonitor().requestDatabaseAccess();
        final syncResult = await db!.query(
          'user_settings',
          where: 'user_id = ? AND setting_name = ?',
          whereArgs: [userId, 'home_display_lifetime_total_questions_answered'],
        );
        getDatabaseMonitor().releaseDatabaseAccess();
        
        expect(syncResult.first['last_modified_timestamp'], equals(cloudTimestamp), reason: 'should use provided cloud timestamp');
        expect(syncResult.first['edits_are_synced'], equals(1), reason: 'edits_are_synced should be 1 when using cloud timestamp');
        expect(syncResult.first['has_been_synced'], equals(1), reason: 'has_been_synced should be 1 when using cloud timestamp');
        
        QuizzerLogger.logSuccess('✅ updateUserSetting with cloud timestamp test passed');
      });
       
      test('Test 7: Should return 0 rows affected when updating non-existent setting', () async {
        final userId = sessionManager.userId!;
        
        // Try to update a setting that doesn't exist
        final rowsAffected = await updateUserSetting(userId, 'non_existent_setting', 'some_value');
        
        expect(rowsAffected, equals(0), reason: 'Should return 0 rows affected for non-existent setting');
        
        QuizzerLogger.logSuccess('✅ updateUserSetting non-existent setting test passed');
      });
         
      test('Test 8: Should return 1 row affected when updating with same value (SQLite behavior)', () async {
        final userId = sessionManager.userId!;
        
        // Get current value and update with the same value
        final currentResult = await getSettingValue(userId, 'home_display_daily_questions_answered');
        final rowsAffected = await updateUserSetting(userId, 'home_display_daily_questions_answered', currentResult!['value']);
        
        // SQLite UPDATE returns rows that match WHERE clause, not rows that actually changed
        expect(rowsAffected, equals(1), reason: 'Should return 1 row affected when updating with same value (SQLite behavior)');
        
        QuizzerLogger.logSuccess('✅ updateUserSetting same value test passed');
      });
         
      test('Test 9: Should handle empty string values', () async {
        final userId = sessionManager.userId!;
        
        // Update with empty string
        final rowsAffected = await updateUserSetting(userId, 'geminiApiKey', '');
        
        expect(rowsAffected, equals(1), reason: 'Should affect 1 row when updating with empty string');
        
        // Verify empty string is stored
        final updatedResult = await getSettingValue(userId, 'geminiApiKey');
        expect(updatedResult!['value'], equals(''), reason: 'Empty string should be stored correctly');
        
        QuizzerLogger.logSuccess('✅ updateUserSetting empty string test passed');
      });
      test('Test 10: Should handle integer values', () async {
        final userId = sessionManager.userId!;
        
        // Update with integer
        final rowsAffected = await updateUserSetting(userId, 'geminiApiKey', 12345);
        
        expect(rowsAffected, equals(1), reason: 'Should affect 1 row when updating with integer');
        
        // Verify integer is stored as string
        final updatedResult = await getSettingValue(userId, 'geminiApiKey');
        expect(updatedResult!['value'], equals('12345'), reason: 'Integer should be stored as string');
        
        QuizzerLogger.logSuccess('✅ updateUserSetting integer value test passed');
      });
       
       test('Test 11: Should handle double values', () async {
         final userId = sessionManager.userId!;
         
         // Update with double
         final rowsAffected = await updateUserSetting(userId, 'geminiApiKey', 3.14159);
         
         expect(rowsAffected, equals(1), reason: 'Should affect 1 row when updating with double');
         
         // Verify double is stored as string
         final updatedResult = await getSettingValue(userId, 'geminiApiKey');
         expect(updatedResult!['value'], equals('3.14159'), reason: 'Double should be stored as string');
         
         QuizzerLogger.logSuccess('✅ updateUserSetting double value test passed');
       });
       
       test('Test 12: Should handle boolean false values', () async {
         final userId = sessionManager.userId!;
         
         // Update with boolean false
         final rowsAffected = await updateUserSetting(userId, 'home_display_average_daily_questions_learned', false);
         
         expect(rowsAffected, equals(1), reason: 'Should affect 1 row when updating with boolean false');
         
         // Verify boolean false is stored as '0'
         final updatedResult = await getSettingValue(userId, 'home_display_average_daily_questions_learned');
         expect(updatedResult!['value'], equals('0'), reason: 'Boolean false should be stored as "0"');
         
         QuizzerLogger.logSuccess('✅ updateUserSetting boolean false test passed');
       });
       
       test('Test 13: Should handle multiple consecutive updates', () async {
         final userId = sessionManager.userId!;
         
         // First update
         final rowsAffected1 = await updateUserSetting(userId, 'home_display_average_questions_shown_per_day', true);
         expect(rowsAffected1, equals(1), reason: 'First update should affect 1 row');
         
         // Second update
         final rowsAffected2 = await updateUserSetting(userId, 'home_display_days_left_until_questions_exhaust', false);
         expect(rowsAffected2, equals(1), reason: 'Second update should affect 1 row');
         
         // Third update
         final rowsAffected3 = await updateUserSetting(userId, 'home_display_revision_streak_score', true);
         expect(rowsAffected3, equals(1), reason: 'Third update should affect 1 row');
         
         // Verify all updates were successful
         final result1 = await getSettingValue(userId, 'home_display_average_questions_shown_per_day');
         final result2 = await getSettingValue(userId, 'home_display_days_left_until_questions_exhaust');
         final result3 = await getSettingValue(userId, 'home_display_revision_streak_score');
         
         expect(result1!['value'], equals('1'), reason: 'First setting should be updated');
         expect(result2!['value'], equals('0'), reason: 'Second setting should be updated');
         expect(result3!['value'], equals('1'), reason: 'Third setting should be updated');
         
         QuizzerLogger.logSuccess('✅ updateUserSetting multiple consecutive updates test passed');
       });
       
       test('Test 14: Should handle mixed sync modes in sequence', () async {
         final userId = sessionManager.userId!;
         const cloudTimestamp = '2025-01-15T13:00:00.000Z';
         
         // Normal mode update
         final rowsAffected1 = await updateUserSetting(userId, 'home_display_last_reviewed', true);
         expect(rowsAffected1, equals(1), reason: 'Normal mode update should affect 1 row');
         
         // Skip sync mode update
         final rowsAffected2 = await updateUserSetting(
           userId, 
           'home_display_last_reviewed', 
           false, 
           skipSyncFlags: true, 
           cloudTimestamp: cloudTimestamp
         );
         expect(rowsAffected2, equals(1), reason: 'Skip sync mode update should affect 1 row');
         
         // Verify final state
         final updatedResult = await getSettingValue(userId, 'home_display_last_reviewed');
         expect(updatedResult!['value'], equals('0'), reason: 'Final value should be from skip sync update');
         
         QuizzerLogger.logSuccess('✅ updateUserSetting mixed sync modes test passed');
       });
     });
   
   });

  group('Modules Table Tests', () {
    group('Integration with addQuestion Function, should publish module record if not exists', (){ 
      test('Test 1: Should publish module record when questions are added through question_answer_pairs table', () async {
        // Setup: Clear all relevant tables to ensure clean state
        deleteAllRecordsFromTable("question_answer_pairs");
        deleteAllRecordsFromTable("modules");
        deleteAllRecordsFromTable("user_module_activation_status");
        expectTableIsEmpty("question_answer_pairs");
        expectTableIsEmpty("modules");
        expectTableIsEmpty("user_module_activation_status");

        // Once state is set we will add 10 multiple choice questions using our helper and the question answer pair table function for doing so
        const String testModule = "testmodule";
        await addTestQuestionsToLocalDatabase(
          questionType: 'multiple_choice',
          numberOfQuestions: 10,
          customModuleName: testModule,
        );
        // Should now have 10 records in the question answer pairs table
        await expectNRecords("question_answer_pairs", 10);
        // Should have 1 module in the modules table
        await expectNRecords("modules", 1);
        // Should have 1 activation record in user_module_activation_status
        await expectNRecords("user_module_activation_status", 1);

        List<Map<String, dynamic>> moduleRecords = await getAllRecordsFromLocalTable("modules");
        Map<String,dynamic> singleRecord = moduleRecords[0];
        // module in table should match the one we inputted
        expect(singleRecord["module_name"], testModule);
      });
      
    });

    group('Module Categorization Feature should integrate properly', () {
      // Define our top level variables for use throughout this grouping:

      String testModule = 'testmodule';
      test('Test 1: Specifying no value for categories should default to [other]', () async {
        // Setup by clearing tables
        deleteAllRecordsFromTable("question_answer_pairs");
        deleteAllRecordsFromTable("modules");
        expectTableIsEmpty("question_answer_pairs");
        expectTableIsEmpty('modules');
        
        // add ten questions with a custom module, we will be updating the category on this module
        
        await addTestQuestionsToLocalDatabase(
          questionType: 'multiple_choice',
          numberOfQuestions: 10,
          customModuleName: testModule);

        // Test 1 confirmed this works so we will now check the value of categories, should be ["other"] by default
        List<Map<String, dynamic>> moduleRecords = await getAllRecordsFromLocalTable('modules');
        Map<String, dynamic> singleRecord = moduleRecords[0];
        expect(singleRecord['categories'], '["other"]');

        updateModule(name: testModule, categories: ["non-existent", "invalid"]);
        // Now refetch our singleRecord
        moduleRecords = await getAllRecordsFromLocalTable('modules');
        singleRecord = moduleRecords[0];
        // Only value should be other, since we passed in invalid enums
        expect(singleRecord['categories'], '["other"]'); 
    }); 
      test('Test 2: Setting a single valid category should remove the "other" label', () async {
        // Test 2 continues from Test 1
        List<Map<String, dynamic>> moduleRecords = await getAllRecordsFromLocalTable('modules');
        Map<String, dynamic> singleRecord = moduleRecords[0];
        // The old record should still read as other:
        expect(singleRecord['categories'], '["other"]');


        // Now updating the module to a valid name, using 'mcat' for our test
        List<String> updatedCategories = ['mcat'];
        updateModule(name: testModule, categories: updatedCategories);

        moduleRecords = await getAllRecordsFromLocalTable('modules');
        singleRecord = moduleRecords[0];
        // Should now be exactly what we updated with (stored as JSON string)
        expect(singleRecord['categories'], '["mcat"]');
      });
      test('Test 3: updating with category should be not be case sensitive', () async{
        // test record should now have the ["mcat"] label on it:
        List<Map<String, dynamic>> moduleRecords = await getAllRecordsFromLocalTable('modules');
        Map<String, dynamic> singleRecord = moduleRecords[0];
        expect(singleRecord['categories'], '["mcat"]');

        // other valid option is clep, to test we will enter Clep, it should work
        String expectedValue = '["clep"]';
        updateModule(name: testModule, categories: ['Clep']);

        moduleRecords = await getAllRecordsFromLocalTable('modules');
        singleRecord = moduleRecords[0];
        expect(singleRecord['categories'], expectedValue);
      });
      test('Test 4: get by Category call in modules_table.dart should work properly', () async{
        //Setup clear tables and get a variety of questions for each category
        await deleteAllRecordsFromTable("question_answer_pairs");
        await deleteAllRecordsFromTable("modules");
        await expectTableIsEmpty("question_answer_pairs");
        await expectTableIsEmpty('modules');       

        List<String> testModules = ["one", "two", "three", "four"];
        for (String bullshitModuleName in testModules) {
          await addTestQuestionsToLocalDatabase(
            questionType: 'multiple_choice',
            numberOfQuestions: 10,
            customModuleName: bullshitModuleName
            );
        }
        // There are four modules we cycles over, thus we should have 40 questions
        await expectNRecords('question_answer_pairs', 40);
        await expectNRecords('modules', 4);

        //update each module to a different category
        List<String> allCategories = ['clep', 'mcat', 'mathematics'];
        await updateModule(name: "one", categories: [allCategories[0]]);
        await updateModule(name: "two", categories: [allCategories[1]]);
        await updateModule(name: "three", categories: [allCategories[2]]);

        // we should expect all four now havve different category values:
        List<Map<String, dynamic>> moduleRecords = await getAllRecordsFromLocalTable('modules');
        Set<String> uniqueValues = <String>{};
        for (Map<String, dynamic> moduleRecord in moduleRecords) {
          uniqueValues.add(decodeValueFromDB(moduleRecord['categories'])[0]);
        }
        // should get back 4 values
        expect(uniqueValues.length, 4);
        List<dynamic> testLength = [];
        testLength = await getModulesByCategory("clep");
        expect(testLength.length, 1);
        testLength = await getModulesByCategory("mcat");
        expect(testLength.length, 1);
        testLength = await getModulesByCategory("mathematics");
        expect(testLength.length, 1);
        testLength = await getModulesByCategory("other");
        expect(testLength.length, 1);


      });

    });


  });

}


