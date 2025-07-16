import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';
import 'test_helpers.dart';
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
  
  group('Review API Tests', () {
    test('Test 1: Get Review Question and Validate Data Structure', () async {
      QuizzerLogger.logMessage('=== Test 1: Get Review Question and Validate Data Structure ===');
      
      try {
        // Call the review API
        QuizzerLogger.logMessage('Step 1: Calling getReviewQuestion() API...');
        final reviewResult = await sessionManager.getReviewQuestion();
        
        // Validate the response structure
        QuizzerLogger.logMessage('Step 2: Validating response structure...');
        expect(reviewResult, isA<Map<String, dynamic>>(), reason: 'Response should be a Map<String, dynamic>');
        
        // Check for required keys
        expect(reviewResult.containsKey('data'), isTrue, reason: 'Response should contain "data" key');
        expect(reviewResult.containsKey('source_table'), isTrue, reason: 'Response should contain "source_table" key');
        expect(reviewResult.containsKey('primary_key'), isTrue, reason: 'Response should contain "primary_key" key');
        expect(reviewResult.containsKey('error'), isTrue, reason: 'Response should contain "error" key');
        
        QuizzerLogger.logSuccess('Response structure validation passed');
        
        // Check if we got an error (no questions available)
        if (reviewResult['error'] != null) {
          QuizzerLogger.logMessage('No questions available for review: ${reviewResult['error']}');
          QuizzerLogger.logSuccess('Test completed - no questions available for review');
          return;
        }
        
        // Validate data is present
        expect(reviewResult['data'], isNotNull, reason: 'Data should not be null when no error');
        expect(reviewResult['source_table'], isNotNull, reason: 'Source table should not be null when no error');
        expect(reviewResult['primary_key'], isNotNull, reason: 'Primary key should not be null when no error');
        
        final Map<String, dynamic> questionData = reviewResult['data'] as Map<String, dynamic>;
        final String sourceTable = reviewResult['source_table'] as String;
        final Map<String, dynamic> primaryKey = reviewResult['primary_key'] as Map<String, dynamic>;
        
        QuizzerLogger.logSuccess('Basic response validation passed');
        
        // Validate question data structure
        QuizzerLogger.logMessage('Step 3: Validating question data structure...');
        _validateQuestionDataStructure(questionData);
        
        // Validate source table
        QuizzerLogger.logMessage('Step 4: Validating source table...');
        expect(sourceTable, anyOf('question_answer_pair_new_review', 'question_answer_pair_edits_review'), 
               reason: 'Source table should be one of the expected review tables');
        
        // Validate primary key structure
        QuizzerLogger.logMessage('Step 5: Validating primary key structure...');
        expect(primaryKey.containsKey('question_id'), isTrue, reason: 'Primary key should contain question_id');
        expect(primaryKey['question_id'], isA<String>(), reason: 'question_id should be a String');
        
        if (sourceTable == 'question_answer_pair_edits_review') {
          expect(primaryKey.containsKey('last_modified_timestamp'), isTrue, 
                 reason: 'Edits review table primary key should contain last_modified_timestamp');
          expect(primaryKey['last_modified_timestamp'], isA<String>(), 
                 reason: 'last_modified_timestamp should be a String');
        }
        
        QuizzerLogger.logSuccess('Primary key validation passed');
        
        // Check for media and verify local download
        QuizzerLogger.logMessage('Step 6: Checking for media and verifying local download...');
        await _checkMediaAndVerifyDownload(questionData);
        
        QuizzerLogger.logSuccess('✅ Review API test completed successfully');
        
      } catch (e) {
        QuizzerLogger.logError('Review API test failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

/// Validates the structure of question data returned from the review API
void _validateQuestionDataStructure(Map<String, dynamic> questionData) {
  QuizzerLogger.logMessage('Validating question data structure...');
  
  // Required fields that should always be present
  final List<String> requiredFields = [
    'question_id',
    'question_type',
    'module_name',
    'question_elements',
    'answer_elements',
    'qst_contrib',
    'has_been_reviewed',
    'flag_for_removal',
    'completed',
    'has_been_synced',
    'edits_are_synced',
    'last_modified_timestamp',
    'has_media',
  ];
  
  for (final field in requiredFields) {
    expect(questionData.containsKey(field), isTrue, 
           reason: 'Question data should contain required field: $field');
  }
  
  // Validate specific field types
  expect(questionData['question_id'], isA<String>(), reason: 'question_id should be a String');
  expect(questionData['question_type'], isA<String>(), reason: 'question_type should be a String');
  expect(questionData['module_name'], isA<String>(), reason: 'module_name should be a String');
  expect(questionData['question_elements'], isA<List>(), reason: 'question_elements should be a List');
  expect(questionData['answer_elements'], isA<List>(), reason: 'answer_elements should be a List');
  expect(questionData['qst_contrib'], isA<String>(), reason: 'qst_contrib should be a String');
  expect(questionData['has_been_reviewed'], isA<int>(), reason: 'has_been_reviewed should be an int');
  expect(questionData['flag_for_removal'], isA<int>(), reason: 'flag_for_removal should be an int');
  expect(questionData['completed'], isA<int>(), reason: 'completed should be an int');
  expect(questionData['has_been_synced'], isA<int>(), reason: 'has_been_synced should be an int');
  expect(questionData['edits_are_synced'], isA<int>(), reason: 'edits_are_synced should be an int');
  expect(questionData['last_modified_timestamp'], isA<String>(), reason: 'last_modified_timestamp should be a String');
  expect(questionData['has_media'], isA<int>(), reason: 'has_media should be an int');
  
  // Validate question type is one of the expected types
  final String questionType = questionData['question_type'] as String;
  expect(questionType, anyOf('multiple_choice', 'select_all_that_apply', 'true_false', 'sort_order'), 
         reason: 'question_type should be one of the expected types');
  
  // Validate question elements structure
  final List<dynamic> questionElements = questionData['question_elements'] as List<dynamic>;
  for (final element in questionElements) {
    expect(element, isA<Map<String, dynamic>>(), reason: 'Each question element should be a Map');
    final Map<String, dynamic> elementMap = element as Map<String, dynamic>;
    expect(elementMap.containsKey('type'), isTrue, reason: 'Question element should have a type field');
    expect(elementMap.containsKey('content'), isTrue, reason: 'Question element should have a content field');
  }
  
  // Validate answer elements structure
  final List<dynamic> answerElements = questionData['answer_elements'] as List<dynamic>;
  for (final element in answerElements) {
    expect(element, isA<Map<String, dynamic>>(), reason: 'Each answer element should be a Map');
    final Map<String, dynamic> elementMap = element as Map<String, dynamic>;
    expect(elementMap.containsKey('type'), isTrue, reason: 'Answer element should have a type field');
    expect(elementMap.containsKey('content'), isTrue, reason: 'Answer element should have a content field');
  }
  
  // Type-specific validations
  switch (questionType) {
    case 'multiple_choice':
      expect(questionData.containsKey('options'), isTrue, reason: 'Multiple choice should have options');
      expect(questionData.containsKey('correct_option_index'), isTrue, reason: 'Multiple choice should have correct_option_index');
      expect(questionData['options'], isA<List>(), reason: 'options should be a List');
      expect(questionData['correct_option_index'], isA<int>(), reason: 'correct_option_index should be an int');
      break;
      
    case 'select_all_that_apply':
      expect(questionData.containsKey('options'), isTrue, reason: 'Select all should have options');
      expect(questionData.containsKey('index_options_that_apply'), isTrue, reason: 'Select all should have index_options_that_apply');
      expect(questionData['options'], isA<List>(), reason: 'options should be a List');
      expect(questionData['index_options_that_apply'], isA<List>(), reason: 'index_options_that_apply should be a List');
      break;
      
    case 'true_false':
      expect(questionData.containsKey('correct_option_index'), isTrue, reason: 'True/false should have correct_option_index');
      expect(questionData['correct_option_index'], isA<int>(), reason: 'correct_option_index should be an int');
      break;
      
    case 'sort_order':
      expect(questionData.containsKey('options'), isTrue, reason: 'Sort order should have options');
      expect(questionData['options'], isA<List>(), reason: 'options should be a List');
      break;
  }
  
  QuizzerLogger.logSuccess('Question data structure validation passed');
}

/// Checks for media in question data and verifies local download
Future<void> _checkMediaAndVerifyDownload(Map<String, dynamic> questionData) async {
  QuizzerLogger.logMessage('Checking for media in question data...');
  
  final int hasMedia = questionData['has_media'] as int;
  final String questionId = questionData['question_id'] as String;
  
  if (hasMedia == 1) {
    QuizzerLogger.logMessage('Question $questionId has media. Checking for local files...');
    
    // Get the media path
    final String mediaPath = await getQuizzerMediaPath();
    QuizzerLogger.logValue('Media path: $mediaPath');
    
    // Check if media directory exists
    final Directory mediaDir = Directory(mediaPath);
    if (!await mediaDir.exists()) {
      QuizzerLogger.logWarning('Media directory does not exist: $mediaPath');
      return;
    }
    
    // Extract potential media filenames from question and answer elements
    final Set<String> potentialMediaFiles = <String>{};
    
    // Check question elements for media
    final List<dynamic> questionElements = questionData['question_elements'] as List<dynamic>;
    for (final element in questionElements) {
      final Map<String, dynamic> elementMap = element as Map<String, dynamic>;
      _extractMediaFilenamesFromElement(elementMap, potentialMediaFiles);
    }
    
    // Check answer elements for media
    final List<dynamic> answerElements = questionData['answer_elements'] as List<dynamic>;
    for (final element in answerElements) {
      final Map<String, dynamic> elementMap = element as Map<String, dynamic>;
      _extractMediaFilenamesFromElement(elementMap, potentialMediaFiles);
    }
    
    if (potentialMediaFiles.isEmpty) {
      QuizzerLogger.logWarning('Question $questionId has has_media=1 but no media filenames found in elements');
      return;
    }
    
    QuizzerLogger.logValue('Found potential media files: ${potentialMediaFiles.join(', ')}');
    
    // Check if any of these files exist locally
    bool foundLocalFile = false;
    for (final filename in potentialMediaFiles) {
      final String localFilePath = '$mediaPath/$filename';
      final File localFile = File(localFilePath);
      
      if (await localFile.exists()) {
        QuizzerLogger.logSuccess('Media file found locally: $filename');
        foundLocalFile = true;
        
        // Verify file is not empty
        final int fileSize = await localFile.length();
        expect(fileSize, greaterThan(0), reason: 'Local media file should not be empty');
        QuizzerLogger.logValue('Local media file size: $fileSize bytes');
      } else {
        QuizzerLogger.logWarning('Media file not found locally: $filename');
      }
    }
    
    if (foundLocalFile) {
      QuizzerLogger.logSuccess('✅ Media download verification passed - at least one media file found locally');
    } else {
      QuizzerLogger.logWarning('No media files found locally for question $questionId');
    }
    
  } else {
    QuizzerLogger.logMessage('Question $questionId has no media (has_media=0)');
  }
}

/// Extracts media filenames from a question/answer element
void _extractMediaFilenamesFromElement(Map<String, dynamic> element, Set<String> filenames) {
  final String type = element['type'] as String? ?? '';
  final dynamic content = element['content'];
  
  if (type == 'image' && content is String && content.isNotEmpty) {
    filenames.add(content);
  } else if (element.containsKey('image') && element['image'] is String && (element['image'] as String).isNotEmpty) {
    filenames.add(element['image'] as String);
  }
}
