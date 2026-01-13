import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/09_switch_board/sb_sync_worker_signals.dart'; 
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path/path.dart' as path;



/// Internal Validator, encapsulates all functionality and definitions relating to what
/// makes a question valid and verifies that all data entered is of the appropriate type
/// and structure. For example, the question_text field must be Map with specific key 
/// names and values for those fields, this contains the methods that can be called to 
/// ensure that before submitting everything is structured as expected
class QuestionValidator {
  static final QuestionValidator _instance = QuestionValidator._internal();
  factory QuestionValidator() => _instance;
  QuestionValidator._internal();

  // ----- Check and Validate Question Content -----
  /// Checks if a question-answer pair is complete and valid based on its elements.
  /// This function validates that both question and answer elements are provided,
  /// non-empty, and contain valid content after trimming whitespace.
  /// 
  /// Args:
  ///   questionElements: JSON string representation of question elements.
  ///   answerElements: JSON string representation of answer elements.
  /// 
  /// Returns:
  ///   int: 1 if the question-answer pair is complete and valid, 0 if incomplete or invalid.
  /// 
  /// The function performs the following validations:
  /// - Checks that both strings are non-empty and not whitespace-only
  /// - Validates JSON parsing of both element lists
  /// - Ensures each element has non-empty content after trimming
  /// - Returns 0 for any parsing errors or validation failures
  /// 
  /// This function is used by add*Question functions to validate input before
  /// attempting to insert records into the database.
  static int checkCompletionStatus(String questionElements, String answerElements) {
    try {
      QuizzerLogger.logMessage("=== DEBUG: checkCompletionStatus function ===");
      QuizzerLogger.logMessage("Received questionElements: '$questionElements'");
      QuizzerLogger.logMessage("Received answerElements: '$answerElements'");
      
      if (questionElements.trim().isEmpty || answerElements.trim().isEmpty) {
        QuizzerLogger.logMessage("Strings are empty or whitespace-only");
        return 0;
      }
      
      final List<dynamic> questionList = decodeValueFromDB(questionElements);
      if (questionList.isEmpty) {
        QuizzerLogger.logMessage("questionList is empty");
        return 0;
      }

      int meaningfulQuestionElements = 0;
      for (final element in questionList) {
        if (element is Map<String, dynamic>) {
          final content = element['content'];
          QuizzerLogger.logMessage("Question element content: '$content' (type: ${content.runtimeType})");
          
          if (element['type'] == 'blank') {
            // CORRECTED LOGIC for blank elements
            // Content must be a non-null number greater than 0
            if (content == null || content is! num || content <= 0) {
              QuizzerLogger.logMessage("Blank element has invalid or empty content");
              return 0;
            }
            meaningfulQuestionElements++;
          } else { // 'text' elements
            if (content == null || content is! String) {
              QuizzerLogger.logMessage("Non-blank element has invalid content type");
              return 0;
            }
            if (content.trim().isNotEmpty) {
              meaningfulQuestionElements++;
            }
          }
        }
      }
      
      if (meaningfulQuestionElements == 0) {
        QuizzerLogger.logMessage("Question has no meaningful elements");
        return 0;
      }

      final List<dynamic> answerList = decodeValueFromDB(answerElements);
      if (answerList.isEmpty) {
        QuizzerLogger.logMessage("answerList is empty");
        return 0;
      }
      
      int meaningfulAnswerElements = 0;
      for (final element in answerList) {
        if (element is Map<String, dynamic>) {
          final content = element['content'] as String?;
          QuizzerLogger.logMessage("Answer element content: '$content'");
          if (content == null || content.trim().isEmpty) {
            QuizzerLogger.logMessage("Answer element has empty content");
            return 0;
          }
          meaningfulAnswerElements++;
        }
      }
      
      if (meaningfulAnswerElements == 0) {
        QuizzerLogger.logMessage("Answer has no meaningful elements");
        return 0;
      }

      QuizzerLogger.logMessage("All validation passed, returning 1");
      return 1;
    } catch (e) {
      QuizzerLogger.logError("JSON parsing failed: $e");
      return 0;
    }
  }

  /// Private helper function to validate question options
  /// This validation applies to question types that use options 
  /// (multiple choice, select all that apply, sort order, etc.)
  /// Function will throw an exception if invalid
  static void validateQuestionOptions(List<Map<String, dynamic>> options) {
    if (options.isEmpty) {
      throw Exception('Options list cannot be empty.');
    }
    
    for (int i = 0; i < options.length; i++) {
      final option = options[i];
      if (!option.containsKey('type')) {
        throw Exception('Option at index $i is missing required "type" field.');
      }
      if (!option.containsKey('content')) {
        throw Exception('Option at index $i is missing required "content" field.');
      }
      if (option['type'] != 'text' && option['type'] != 'image' && option['type'] != 'blank') {
        throw Exception('Option at index $i has invalid type "${option['type']}". Valid types are: text, image, blank.');
      }
      if (option['content'].toString().isEmpty) {
        throw Exception('Option at index $i has empty content.');
      }
    }
  }

  /// Private helper function to validate general question entry requirements
  /// This validation applies to all question types and complements checkCompletionStatus
  static void validateQuestionEntry({
    required List<Map<String, dynamic>> questionElements,
    required List<Map<String, dynamic>> answerElements,
  }) {
    // Validate question elements structure (not done by checkCompletionStatus)
    for (int i = 0; i < questionElements.length; i++) {
      final element = questionElements[i];
      if (!element.containsKey('type')) {
        throw Exception('Question element at index $i is missing required "type" field.');
      }
      if (!element.containsKey('content')) {
        throw Exception('Question element at index $i is missing required "content" field.');
      }
      if (element['type'] != 'text' && element['type'] != 'image' && element['type'] != 'blank') {
        throw Exception('Question element at index $i has invalid type "${element['type']}". Valid types are: text, image, blank.');
      }
    }

    // Validate answer elements structure (not done by checkCompletionStatus)
    for (int i = 0; i < answerElements.length; i++) {
      final element = answerElements[i];
      if (!element.containsKey('type')) {
        throw Exception('Answer element at index $i is missing required "type" field.');
      }
      if (!element.containsKey('content')) {
        throw Exception('Answer element at index $i is missing required "content" field.');
      }
      if (element['type'] != 'text' && element['type'] != 'image' && element['type'] != 'blank') {
        throw Exception('Answer element at index $i has invalid type "${element['type']}". Valid types are: text, image, blank.');
      }
    }
  }


  // ----- Check and Validate Media -----
  /// Processes a given question record to check for media, extract filenames if present,
  /// register those filenames in the media_sync_status table, and returns whether media was found.
  /// 
  /// This function can handle both encoded JSON strings and decoded data structures.
  /// If it receives JSON strings, it will decode them before processing.
  static Future<bool> hasMediaCheck(dynamic questionRecord) async {
    // Handle both Map and String input
    if (questionRecord is! Map<String, dynamic>) {
      QuizzerLogger.logError('hasMediaCheck received invalid input type: ${questionRecord.runtimeType}');
      return false;
    }
    
    final String? recordQuestionId = questionRecord['question_id'] as String?;
    final String loggingContextSuffix = recordQuestionId != null ? '(Question ID: $recordQuestionId)' : '(Question ID: unknown)';
    QuizzerLogger.logMessage('Processing media for question record $loggingContextSuffix');

    // Create a copy of the record for media checking
    final Map<String, dynamic> processedRecord = Map<String, dynamic>.from(questionRecord);
    
    // Decode JSON strings for complex fields only if they are strings
    try {
      if (processedRecord['question_elements'] is String) {
        processedRecord['question_elements'] = decodeValueFromDB(processedRecord['question_elements']);
      }
      if (processedRecord['answer_elements'] is String) {
        processedRecord['answer_elements'] = decodeValueFromDB(processedRecord['answer_elements']);
      }
      if (processedRecord['options'] is String) {
        processedRecord['options'] = decodeValueFromDB(processedRecord['options']);
      }
      if (processedRecord['correct_order'] is String) {
        processedRecord['correct_order'] = decodeValueFromDB(processedRecord['correct_order']);
      }
      if (processedRecord['index_options_that_apply'] is String) {
        processedRecord['index_options_that_apply'] = decodeValueFromDB(processedRecord['index_options_that_apply']);
      }
      if (processedRecord['answers_to_blanks'] is String) {
        processedRecord['answers_to_blanks'] = decodeValueFromDB(processedRecord['answers_to_blanks']);
      }
    } catch (e) {
      QuizzerLogger.logError('Error processing data in question record $loggingContextSuffix: $e');
      return false;
    }

    // Check for media using the existing internal helper with processed data
    final bool mediaFound = _internalHasMediaCheck(processedRecord);

    if (mediaFound) {
      QuizzerLogger.logMessage('Media found in record $loggingContextSuffix. Extracting filenames.');
      final Set<String> filenames = _extractMediaFilenames(processedRecord);

      if (filenames.isNotEmpty) {
        QuizzerLogger.logMessage('Extracted ${filenames.length} filenames for $loggingContextSuffix. Downloading if missing and registering for sync.');
        for (final filename in filenames) {
          await _fetchAndDownloadMediaIfMissing(filename);
        }
        // Signal the MediaSyncWorker to process uploads after downloads
        signalMediaSyncNeeded();
      } else {
        signalMediaSyncNeeded();
        QuizzerLogger.logWarning('Media was indicated as found for $loggingContextSuffix, but no filenames were extracted. This might indicate an issue with _extractMediaFilenames or the data structure.');
      }
    } else {
      QuizzerLogger.logMessage('No media found in record $loggingContextSuffix.');
    }
    return mediaFound;
  }

  static bool         _internalHasMediaCheck(dynamic data) {
    if (data is Map<String, dynamic>) {
      // Check for element style: {'type': 'image', 'content': 'file_name.ext'}
      if (data['type'] == 'image' && data.containsKey('content') && data['content'] is String && (data['content'] as String).isNotEmpty) {
        final String imagePath = data['content'] as String;
        if (_isValidImageFilename(imagePath)) {
          return true;
        }
      }
      // Recursively check values in the map
      for (var value in data.values) {
        if (_internalHasMediaCheck(value)) {
          return true;
        }
      }
    } else if (data is List) {
      // Recursively check items in the list
      for (var item in data) {
        if (_internalHasMediaCheck(item)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Validates that an image filename is a simple filename without path separators or URLs
  static bool         _isValidImageFilename(String filename) {
    if (filename.trim().isEmpty) {
      return false;
    }
    
    // Reject paths with directory separators
    if (filename.contains('/') || filename.contains('\\')) {
      return false;
    }
    
    // Reject URLs (http, https, ftp, etc.)
    if (filename.toLowerCase().startsWith('http://') || 
        filename.toLowerCase().startsWith('https://') ||
        filename.toLowerCase().startsWith('ftp://') ||
        filename.toLowerCase().startsWith('file://')) {
      return false;
    }
    
    // Reject absolute paths (Windows or Unix)
    if (filename.startsWith('/') || 
        (filename.length > 1 && filename[1] == ':') || // Windows drive letter
        filename.startsWith('\\')) {
      return false;
    }
    
    return true;
  }

  static Set<String>  _extractMediaFilenames(dynamic data) {
    final Set<String> filenames = {};
    _recursiveExtractFilenames(data, filenames);
    return filenames;
  }

  static void         _recursiveExtractFilenames(dynamic data, Set<String> filenames) {
    if (data is Map<String, dynamic>) {
      if (data['type'] == 'image' && data.containsKey('content') && data['content'] is String && (data['content'] as String).isNotEmpty) {
        final String imagePath = data['content'] as String;
        if (_isValidImageFilename(imagePath)) {
          filenames.add(imagePath);
        }
      }
      // Recursively check values in the map
      for (var value in data.values) {
        _recursiveExtractFilenames(value, filenames);
      }
    } else if (data is List) {
      // Recursively check items in the list
      for (var item in data) {
        _recursiveExtractFilenames(item, filenames);
      }
    }
  }

  /// Helper to immediately fetch and download a media file from Supabase if not present locally
  static Future<void> _fetchAndDownloadMediaIfMissing(String fileName) async {
    final String localAssetBasePath = await getQuizzerMediaPath();
    final String localPath = path.join(localAssetBasePath, fileName);
    final File file = File(localPath);
    if (await file.exists()) {
      QuizzerLogger.logMessage('Media file already exists locally: $localPath');
      return;
    }
    QuizzerLogger.logMessage('Media file missing locally, attempting to download: $fileName');
    try {
      final Uint8List bytes = await SessionManager().supabase.storage.from('question-answer-pair-assets').download(fileName);
      await Directory(path.dirname(localPath)).create(recursive: true);
      await file.writeAsBytes(bytes);
      QuizzerLogger.logSuccess('Successfully downloaded and saved media file: $fileName');
    } catch (e) {
      QuizzerLogger.logError('Failed to download media file $fileName from Supabase: $e');
    }
  }


}