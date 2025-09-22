import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'dart:convert';
import '../table_helper.dart'; // Import the new helper file
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart'; // Import sync signals
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/media_sync_status_table.dart'; // Added import
import 'package:path/path.dart' as path; // Changed alias to path
import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // For Supabase client
import 'dart:typed_data';
import 'dart:io';
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/session_manager/answer_validation/text_analysis_tools.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_helper_utils/utils.dart';

// ALL question_type:
// - multiple_choice:       ✅ IMPLEMENTED
// - select_all_that_apply: ✅ IMPLEMENTED
// - true_false:            ✅ IMPLEMENTED
// - sort_order:            ✅ IMPLEMENTED
// - fill_in_the_blank:     ✅ IMPLEMENTED
// - short_answer:          NOT IMPLEMENTED
// - matching:              NOT IMPLEMENTED
// - hot_spot:              NOT IMPLEMENTED
// - label_diagram:         NOT IMPLEMENTED
// - math:                  NOT IMPLEMENTED
// - speech:                NOT IMPLEMENTED

// question/answer element format:
// List<Map<String, dynamic>> where each element is:
// {'type': 'text', 'content': 'text content'} OR
// {'type': 'image', 'content': 'filename.ext'} OR
// {'type': 'blank', content: '$lengthOfBlank'}
// 
// Supported element types:
// - 'text': Displays text content (content field contains the text)
// - 'image': Displays image (content field contains filename from media directory)
// 
// Element rendering:
// - Elements are rendered in order using ElementRenderer widget
// - Text elements render synchronously
// - Image elements load asynchronously from staging or media paths
// - Images are stored as filenames, not full paths
// 
// Media handling:
// - Images are staged in input_staging directory during creation
// - Finalized images are moved to question_answer_pair_assets directory
// - hasMediaCheck() function detects image elements and updates has_media flag
// 
// Example question_elements:
// [
//   {'type': 'text', 'content': 'What is the capital of France?'},
//   {'type': 'image', 'content': 'france_map.png'},
//   {'type': 'text', 'content': 'Choose the correct answer:'}
// ]
// 
// Example question_elements with blanks (for fill_in_the_blank):
// [
//   {'type': 'text', 'content': 'The capital of France is'},
//   {'type': 'blank', 'content': '10'},
//   {'type': 'text', 'content': 'and it is known for the Eiffel Tower.'}
// ]
// 
// Example answer_elements:
// [
//   {'type': 'text', 'content': 'Paris is the capital of France.'},
//   {'type': 'image', 'content': 'paris_landmark.jpg'}
// ]

final List<Map<String, String>> expectedColumns = [
  {'name': 'question_id',              'type': 'TEXT PRIMARY KEY'},
  {'name': 'time_stamp',               'type': 'TEXT'},
  {'name': 'question_elements',        'type': 'TEXT'},
  {'name': 'answer_elements',          'type': 'TEXT'},
  {'name': 'ans_flagged',              'type': 'INTEGER'},
  {'name': 'ans_contrib',              'type': 'TEXT'},
  {'name': 'qst_contrib',              'type': 'TEXT'},
  {'name': 'qst_reviewer',             'type': 'TEXT'},
  {'name': 'has_been_reviewed',        'type': 'INTEGER'},
  {'name': 'flag_for_removal',         'type': 'INTEGER'},
  {'name': 'module_name',              'type': 'TEXT'},
  {'name': 'question_type',            'type': 'TEXT'},
  {'name': 'options',                  'type': 'TEXT'},
  {'name': 'correct_option_index',     'type': 'INTEGER'},
  {'name': 'correct_order',            'type': 'TEXT'},
  {'name': 'index_options_that_apply', 'type': 'TEXT'},
  {'name': 'answers_to_blanks',        'type': 'TEXT'},
  {'name': 'has_been_synced',          'type': 'INTEGER DEFAULT 0'},
  {'name': 'edits_are_synced',         'type': 'INTEGER DEFAULT 0'},
  {'name': 'last_modified_timestamp',  'type': 'TEXT'},
  {'name': 'has_media',                'type': 'INTEGER DEFAULT NULL'},
  {'name': 'question_vector',          'type': 'TEXT DEFAULT NULL'},
];

/// Verifies that the question_answer_pairs table exists and creates it if it doesn't.
/// This function handles table creation, column additions, and index creation for the
/// question_answer_pairs table. It also manages database schema migrations for new
/// columns and constraints.
/// 
/// Args:
///   db: The database instance to verify and potentially modify.
/// 
/// The function performs the following operations:
/// - Creates the table if it doesn't exist with all required columns
/// - Adds missing columns for new features (question_id, correct_order, etc.)
/// - Creates indexes for performance optimization
/// - Handles unique constraint management
/// - Manages sync-related columns and flags
/// 
/// This function is called by all other functions in this file to ensure
/// the table structure is up-to-date before performing operations.
Future<void> verifyQuestionAnswerPairTable(dynamic db) async {
  try {
    QuizzerLogger.logMessage('Verifying question_answer_pairs table existence');
    
    // Check if the table exists
    final List<Map<String, dynamic>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      ['question_answer_pairs']
    );

    bool tableExists = tables.isNotEmpty;
    List<Map<String, dynamic>>? recordsToMigrate;

    if (tableExists) {
      // Check if the primary key is question_id
      final List<Map<String, dynamic>> tableInfo = await db.rawQuery(
        "PRAGMA table_info(question_answer_pairs)"
      );
      final hasCorrectPrimaryKey = tableInfo.any((col) => col['name'] == 'question_id' && col['pk'] == 1);
      
      if (!hasCorrectPrimaryKey) {
        QuizzerLogger.logWarning('question_answer_pairs table has incorrect primary key. Migrating data and recreating table.');
        
        // Backup all data before dropping the table
        try {
          recordsToMigrate = await db.query('question_answer_pairs');
          QuizzerLogger.logMessage('Successfully backed up ${recordsToMigrate!.length} records.');
        } catch (e) {
          QuizzerLogger.logError('Failed to backup data before migration: $e');
          recordsToMigrate = null;
        }
        
        await db.execute('DROP TABLE IF EXISTS question_answer_pairs');
        tableExists = false;
      }
    }

    if (!tableExists) {
      // Create the table if it doesn't exist
      QuizzerLogger.logMessage('question_answer_pairs table does not exist, creating it');
      
      String createTableSQL = 'CREATE TABLE question_answer_pairs(\n';
      createTableSQL += expectedColumns.map((col) => '  ${col['name']} ${col['type']}').join(',\n');
      createTableSQL += '\n)';
      
      await db.execute(createTableSQL);
      
      // Create indexes
      await db.execute('CREATE INDEX idx_question_answer_pairs_module_name ON question_answer_pairs(module_name)');
      
      QuizzerLogger.logSuccess('question_answer_pairs table created successfully');
    } else {
      // Table exists, check for column differences
      QuizzerLogger.logMessage('question_answer_pairs table exists, checking column structure');
      
      // Get current table structure
      final List<Map<String, dynamic>> currentColumns = await db.rawQuery(
        "PRAGMA table_info(question_answer_pairs)"
      );
      
      final Set<String> currentColumnNames = currentColumns
          .map((column) => column['name'] as String)
          .toSet();
      
      final Set<String> expectedColumnNames = expectedColumns
          .map((column) => column['name']!)
          .toSet();
      
      // Find columns to add (expected but not current)
      final Set<String> columnsToAdd = expectedColumnNames.difference(currentColumnNames);
      
      // Find columns to remove (current but not expected)
      final Set<String> columnsToRemove = currentColumnNames.difference(expectedColumnNames);
      
      // Add missing columns
      for (String columnName in columnsToAdd) {
        final columnDef = expectedColumns.firstWhere((col) => col['name'] == columnName);
        QuizzerLogger.logMessage('Adding missing column: $columnName');
        await db.execute('ALTER TABLE question_answer_pairs ADD COLUMN ${columnDef['name']} ${columnDef['type']}');
      }
      
      // Remove unexpected columns (SQLite doesn't support DROP COLUMN directly)
      if (columnsToRemove.isNotEmpty) {
        QuizzerLogger.logMessage('Removing unexpected columns: ${columnsToRemove.join(', ')}');
        
        // Create temporary table with only expected columns
        String tempTableSQL = 'CREATE TABLE question_answer_pairs_temp(\n';
        tempTableSQL += expectedColumns.map((col) => '  ${col['name']} ${col['type']}').join(',\n');
        tempTableSQL += '\n)';
        
        await db.execute(tempTableSQL);
        
        // Copy data from old table to temp table (only expected columns)
        String columnList = expectedColumnNames.join(', ');
        await db.execute('INSERT INTO question_answer_pairs_temp ($columnList) SELECT $columnList FROM question_answer_pairs');
        
        // Drop old table and rename temp table
        await db.execute('DROP TABLE question_answer_pairs');
        await db.execute('ALTER TABLE question_answer_pairs_temp RENAME TO question_answer_pairs');
        
        QuizzerLogger.logSuccess('Removed unexpected columns and restructured table');
      }
      
      // Check and create indexes if they don't exist
      final List<Map<String, dynamic>> indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='question_answer_pairs'"
      );
      final existingIndexes = indexes.map((index) => index['name'] as String).toSet();
      
      if (!existingIndexes.contains('idx_question_answer_pairs_module_name')) {
        await db.execute('CREATE INDEX idx_question_answer_pairs_module_name ON question_answer_pairs(module_name)');
        QuizzerLogger.logMessage('Created index on module_name');
      }
      
      if (columnsToAdd.isEmpty && columnsToRemove.isEmpty) {
        QuizzerLogger.logMessage('Table structure is already up to date');
      } else {
        QuizzerLogger.logSuccess('Table structure updated successfully');
      }
    }

    // Re-insert backed-up data if migration occurred
    if (recordsToMigrate != null && recordsToMigrate.isNotEmpty) {
      QuizzerLogger.logMessage('Migrating ${recordsToMigrate.length} records back into the table.');
      await db.transaction((txn) async {
        for (final record in recordsToMigrate!) {
          final Map<String, dynamic> newRecord = Map<String, dynamic>.from(record);
          if (newRecord['question_id'] == null) {
            // Recreate the question_id if it was null
            final String timeStamp = newRecord['time_stamp'] as String? ?? '';
            final String qstContrib = newRecord['qst_contrib'] as String? ?? '';
            newRecord['question_id'] = '${timeStamp}_$qstContrib';
          }
          await txn.insert('question_answer_pairs', newRecord);
        }
      });
      QuizzerLogger.logSuccess('Data migration completed successfully.');
    }
  } catch (e) {
    QuizzerLogger.logError('Error verifying question_answer_pairs table - $e');
    rethrow;
  }
}

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
int checkCompletionStatus(String questionElements, String answerElements) {
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
// =============================================================
// Media Sync Helper functionality

/// Helper to immediately fetch and download a media file from Supabase if not present locally
Future<void> _fetchAndDownloadMediaIfMissing(String fileName) async {
  final String localAssetBasePath = await getQuizzerMediaPath();
  final String localPath = path.join(localAssetBasePath, fileName);
  final File file = File(localPath);
  if (await file.exists()) {
    QuizzerLogger.logMessage('Media file already exists locally: $localPath');
    return;
  }
  QuizzerLogger.logMessage('Media file missing locally, attempting to download: $fileName');
  final supabase = getSessionManager().supabase;
  const String bucketName = 'question-answer-pair-assets';
  try {
    final Uint8List bytes = await supabase.storage.from(bucketName).download(fileName);
    await Directory(path.dirname(localPath)).create(recursive: true);
    await file.writeAsBytes(bytes);
    QuizzerLogger.logSuccess('Successfully downloaded and saved media file: $fileName');
  } catch (e) {
    QuizzerLogger.logError('Failed to download media file $fileName from Supabase: $e');
  }
}

/// Processes a given question record to check for media, extract filenames if present,
/// register those filenames in the media_sync_status table, and returns whether media was found.
/// 
/// This function can handle both encoded JSON strings and decoded data structures.
/// If it receives JSON strings, it will decode them before processing.
Future<bool> hasMediaCheck(dynamic questionRecord) async {
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


bool _internalHasMediaCheck(dynamic data) {
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
bool _isValidImageFilename(String filename) {
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

Set<String> _extractMediaFilenames(dynamic data) {
  final Set<String> filenames = {};
  _recursiveExtractFilenames(data, filenames);
  return filenames;
}

void _recursiveExtractFilenames(dynamic data, Set<String> filenames) {
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

/// Takes a set of filenames and attempts to register each in the media_sync_status table.
/// Includes specific error handling for unique constraint violations.
Future<void> registerMediaFiles(Set<String> filenames, {String? qidForLogging}) async {
  final String logCtx = qidForLogging != null ? '(Associated QID: $qidForLogging)' : '';
  QuizzerLogger.logMessage('Attempting to register ${filenames.length} media files $logCtx');

  if (filenames.isEmpty) {
    QuizzerLogger.logMessage('No filenames provided to register $logCtx.');
    return;
  }

  for (final filename in filenames) {
    if (filename.trim().isEmpty) {
      QuizzerLogger.logWarning('Skipping empty media filename during registration $logCtx.');
      continue;
    }
    
    String fileExtension = path.extension(filename);
    if (fileExtension.startsWith('.')) {
      fileExtension = fileExtension.substring(1);
    }

    QuizzerLogger.logMessage('Attempting to ensure media sync status for: $filename $logCtx');
    try {
      // Make sure insertMediaSyncStatus is available in this file's scope
      // It is imported from 'package:quizzer/backend_systems/00_database_manager/tables/media_sync_status_table.dart'
      await insertMediaSyncStatus(
        fileName: filename, 
        fileExtension: fileExtension,
      );
      QuizzerLogger.logSuccess('Successfully ensured media sync status for: $filename $logCtx.');
    } on DatabaseException catch (e) {
      // Check for unique constraint violation codes or messages
      if (e.isUniqueConstraintError() || 
          (e.toString().toLowerCase().contains('unique constraint failed')) ||
          (e.toString().contains('code 1555')) || // Common SQLite code for unique constraint
          (e.toString().contains('code 2067'))) { // Another potential SQLite code for unique constraint
        QuizzerLogger.logMessage('Media sync status for $filename $logCtx already exists or was concurrently inserted. Skipping.');
      } else {
        QuizzerLogger.logError('DatabaseException while ensuring media sync status for $filename $logCtx: $e');
        rethrow; // Fail Fast for other database exceptions
      }
    } catch (e) {
      QuizzerLogger.logError('Unexpected error while ensuring media sync status for $filename $logCtx: $e');
      rethrow; // Fail Fast for non-database exceptions
    }
  }
  QuizzerLogger.logMessage('Finished attempting to register media files $logCtx.');
}

/// Edits an existing question-answer pair by updating specified fields.
/// This function allows partial updates of question records, automatically
/// handling encoding, validation, and sync flag management.
/// 
/// Args:
///   questionId: The unique identifier of the question to edit.
///   questionElements: Optional updated question elements.
///   answerElements: Optional updated answer elements.
///   indexOptionsThatApply: Optional updated indices for select-all-that-apply questions.
///   ansFlagged: Optional flag indicating if the answer has been flagged.
///   ansContrib: Optional contributor of the answer.
///   qstReviewer: Optional reviewer of the question.
///   hasBeenReviewed: Optional flag indicating if the question has been reviewed.
///   flagForRemoval: Optional flag indicating if the question should be removed.
///   moduleName: Optional updated module name (will be normalized).
///   questionType: Optional updated question type.
///   options: Optional updated options for multiple choice/select questions.
///   correctOptionIndex: Optional updated correct option index.
///   correctOrderElements: Optional updated correct order for sort questions.
///   answersToBlanks: Optional updated answers for fill-in-the-blank questions.
///   debugDisableOutboundSyncCall: When true, prevents signaling the outbound sync system.
///     This is useful for testing to avoid triggering sync operations during test execution.
///     Defaults to false (sync is signaled normally).
/// 
/// Returns:
///   int: Number of rows affected by the update operation.
/// 
/// The function performs the following operations:
/// - Fetches the existing record to validate it exists
/// - Normalizes and validates all provided fields
/// - Updates media status based on new content
/// - Marks the record as needing sync
/// - Updates the last modified timestamp
/// - Handles all encoding/decoding automatically
/// 
/// Throws:
///   Exception: If the question ID is not found or validation fails.
Future<int> editQuestionAnswerPair({
  required String questionId,
  List<Map<String, dynamic>>? questionElements,
  List<Map<String, dynamic>>? answerElements,
  // Specific field for Select All That Apply - expecting List<int>
  List<int>? indexOptionsThatApply,
  bool? ansFlagged,
  String? ansContrib,
  String? qstReviewer,
  bool? hasBeenReviewed,
  bool? flagForRemoval,
  String? moduleName,
  String? questionType,
  // Specific field for Multiple Choice/Select All - expecting List<Map<String, dynamic>>
  List<Map<String, dynamic>>? options, 
  // Specific field for Multiple Choice/True False - expecting int
  int? correctOptionIndex,
  // Specific field for Sort Order - expecting List<Map<String, dynamic>>
  List<Map<String, dynamic>>? correctOrderElements,
  // Specific field for Fill in the Blank - expecting List<Map<String, List<String>>>
  List<Map<String, List<String>>>? answersToBlanks,
  bool debugDisableOutboundSyncCall = false,
}) async {
  try {
    // Fetch the existing record first
    final Map<String, dynamic> existingRecord = await getQuestionAnswerPairById(questionId);
    // Get the database access
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // Prepare map for raw values to update 
    Map<String, dynamic> valuesToUpdate = {};
    
    // Add non-null fields to the map without encoding here
    if (questionElements != null) valuesToUpdate['question_elements'] = questionElements;
    if (answerElements != null) valuesToUpdate['answer_elements'] = answerElements;
    if (indexOptionsThatApply != null) valuesToUpdate['index_options_that_apply'] = indexOptionsThatApply;
    if (ansFlagged != null) valuesToUpdate['ans_flagged'] = ansFlagged ? 1 : 0;
    if (ansContrib != null) valuesToUpdate['ans_contrib'] = ansContrib;
    if (qstReviewer != null) valuesToUpdate['qst_reviewer'] = qstReviewer;
    if (hasBeenReviewed != null) valuesToUpdate['has_been_reviewed'] = hasBeenReviewed ? 1 : 0;
    if (flagForRemoval != null) valuesToUpdate['flag_for_removal'] = flagForRemoval ? 1 : 0;
    if (moduleName != null) {
      // Normalize the module name before updating
      final String normalizedModuleName = await normalizeString(moduleName);
      valuesToUpdate['module_name'] = normalizedModuleName;
    }
    if (questionType != null) valuesToUpdate['question_type'] = questionType;
    if (options != null) valuesToUpdate['options'] = options;
    if (correctOptionIndex != null) valuesToUpdate['correct_option_index'] = correctOptionIndex;
    if (correctOrderElements != null) valuesToUpdate['correct_order'] = correctOrderElements;
    if (answersToBlanks != null) valuesToUpdate['answers_to_blanks'] = answersToBlanks;

    // If no values were provided to update, log and return 0 rows affected.
    if (valuesToUpdate.isEmpty) {
      QuizzerLogger.logWarning('editQuestionAnswerPair called for question $questionId with no fields to update.');
      return 0;
    }

    // *** Always mark edits as needing sync ***
    valuesToUpdate['edits_are_synced'] = 0;
    // Update the last_modified_timestamp to current time
    valuesToUpdate['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();

    // Construct the potential new state of the record to check for media
    
    // Create a mutable copy and apply updates to it
    final Map<String, dynamic> potentialNewState = Map<String, dynamic>.from(existingRecord);
    valuesToUpdate.forEach((key, value) {
      potentialNewState[key] = value; // This will reflect the raw values before encoding
    });

    final bool recordHasMedia = await hasMediaCheck(potentialNewState);
    valuesToUpdate['has_media'] = recordHasMedia ? 1 : 0;

    QuizzerLogger.logMessage('Updating question $questionId with fields: ${valuesToUpdate.keys.join(', ')}');

    // Use the universal update helper (encoding happens inside)
    final result = await updateRawData(
      'question_answer_pairs',
      valuesToUpdate, // Pass the map with raw values
      'question_id = ?', // where clause
      [questionId],      // whereArgs
      db,
    );
    
    if (!debugDisableOutboundSyncCall) {
      signalOutboundSyncNeeded(); // Signal after successful update
    }
    
    return result;
  } catch (e) {
    QuizzerLogger.logError('Error editing question answer pair - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
    
    // Validate modules table after editing a question (after db access is released)
    await ensureAllQuestionModuleNamesHaveCorrespondingModuleRecords();
  }
}

/// Fetches a single question-answer pair by its composite ID.
/// The questionId format is expected to be 'timestamp_qstContrib'.
Future<Map<String, dynamic>> getQuestionAnswerPairById(String questionId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // Use the single helper function
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'question_answer_pairs',
      db,
      where: 'question_id = ?',
      whereArgs: [questionId],
      limit: 2, // Limit to 2 to check if more than one exists
    );

    // Perform checks previously done in queryDecodedSingle
    if (results.isEmpty) {
      QuizzerLogger.logError('Query for single row (getQuestionAnswerPairById) returned no results for ID: $questionId');
      throw StateError('Expected exactly one row for question ID $questionId, but found none.');
    } else if (results.length > 1) {
      QuizzerLogger.logError('Query for single row (getQuestionAnswerPairById) returned ${results.length} results for ID: $questionId - removing duplicates');
      
      // Keep the first record and delete the duplicates
      final List<Map<String, dynamic>> duplicates = results.skip(1).toList();
      
      for (final duplicate in duplicates) {
        final String timeStamp = duplicate['time_stamp'] as String;
        final String qstContrib = duplicate['qst_contrib'] as String;
        
        QuizzerLogger.logMessage('Deleting duplicate question record: time_stamp=$timeStamp, qst_contrib=$qstContrib');
        await db.delete(
          'question_answer_pairs',
          where: 'time_stamp = ? AND qst_contrib = ?',
          whereArgs: [timeStamp, qstContrib],
        );
      }
      
      QuizzerLogger.logSuccess('Removed ${duplicates.length} duplicate records for question ID: $questionId');
    }

    // Return the single decoded row
    return results.first;
  } catch (e) {
    QuizzerLogger.logError('Error getting question answer pair by ID - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Retrieves all question-answer pairs from the database.
/// This function returns every question record in the database,
/// automatically decoded and ready for use.
/// 
/// Returns:
///   List<Map<String, dynamic>>: A list of all question-answer pair records
///   from the database. Returns an empty list if no questions exist.
/// 
/// The function performs the following operations:
/// - Queries all records from the question_answer_pairs table
/// - Automatically decodes all complex fields (JSON, etc.)
/// - Returns an empty list if the database is empty
/// - Handles all database access and cleanup automatically
/// 
/// Each record in the returned list includes all fields from the
/// question_answer_pairs table with proper decoding of JSON fields
/// like question_elements, answer_elements, options, etc.
/// 
/// Note: This function should be used carefully with large datasets
/// as it loads all records into memory at once.
/// 
/// Throws:
///   Exception: If database access fails or other database errors occur.
Future<List<Map<String, dynamic>>>  getAllQuestionAnswerPairs() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // Use the helper function to query and decode all rows
    return await queryAndDecodeDatabase('question_answer_pairs', db);
  } catch (e) {
    QuizzerLogger.logError('Error getting all question answer pairs - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Removes a question-answer pair from the database using composite key.
/// This function deletes a specific question record based on its timestamp
/// and contributor ID (the composite primary key).
/// 
/// Args:
///   timeStamp: The timestamp when the question was created (part of composite key).
///   qstContrib: The contributor ID who created the question (part of composite key).
/// 
/// Returns:
///   int: Number of rows deleted (should be 1 if successful, 0 if not found).
/// 
/// The function performs the following operations:
/// - Uses the composite primary key (time_stamp, qst_contrib) to identify the record
/// - Deletes the record if found
/// - Returns the number of affected rows
/// - Handles all database access and cleanup automatically
/// 
/// Note: This function uses the legacy composite key approach. For new code,
/// consider using question_id-based deletion if available.
/// 
/// Throws:
///   Exception: If database access fails or other database errors occur.
Future<int> removeQuestionAnswerPair(String timeStamp, String qstContrib) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    return await db.delete(
      'question_answer_pairs',
      where: 'time_stamp = ? AND qst_contrib = ?',
      whereArgs: [timeStamp, qstContrib],
    );
  } catch (e) {
    QuizzerLogger.logError('Error removing question answer pair - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Fetches the module name for a specific question ID.
/// Throws an error if the question ID is not found (Fail Fast).
Future<String> getModuleNameForQuestionId(String questionId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'question_answer_pairs',
      db,
      columns: ['module_name'],
      where: 'question_id = ?',
      whereArgs: [questionId],
    );
    
    if (results.isEmpty) {
      QuizzerLogger.logError('No question found with ID: $questionId');
      throw StateError('Question ID $questionId not found in database');
    }
    
    final String? moduleName = results.first['module_name'] as String?;
    if (moduleName == null || moduleName.isEmpty) {
      QuizzerLogger.logWarning('Question $questionId has no module name assigned');
      return 'Unknown Module';
    }
    
    return moduleName;
  } catch (e) {
    QuizzerLogger.logError('Error getting module name for question ID - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Fetches all question records for a specific module name.
/// Returns an empty list if no questions are found for the module.
/// The module name is automatically normalized (lowercase, underscores to spaces) for matching.
Future<List<Map<String, dynamic>>> getQuestionRecordsForModule(String moduleName) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // Normalize the module name for consistent matching
    final String normalizedModuleName = await normalizeString(moduleName);
    
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'question_answer_pairs',
      db,
      where: 'module_name = ?',
      whereArgs: [normalizedModuleName],
    );
    
    QuizzerLogger.logMessage('Found ${results.length} questions for module: $moduleName (normalized: $normalizedModuleName)');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting question records for module - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Fetches module names for multiple question IDs in a single database query.
/// This is more efficient than calling getModuleNameForQuestionId multiple times.
/// Returns a map of question ID to module name.
Future<Map<String, String>> getModuleNamesForQuestionIds(List<String> questionIds) async {
  try {
    if (questionIds.isEmpty) {
      return {};
    }
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // Create placeholders for the IN clause
    final placeholders = List.filled(questionIds.length, '?').join(',');
    
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'question_answer_pairs',
      db,
      columns: ['question_id', 'module_name'],
      where: 'question_id IN ($placeholders)',
      whereArgs: questionIds,
    );
    
    final Map<String, String> questionIdToModuleName = {};
    for (final row in results) {
      final String questionId = row['question_id'] as String;
      final String? moduleName = row['module_name'] as String?;
      
      if (moduleName != null && moduleName.isNotEmpty) {
        questionIdToModuleName[questionId] = moduleName;
      } else {
        questionIdToModuleName[questionId] = 'Unknown Module';
      }
    }
    return questionIdToModuleName;
  } catch (e) {
    QuizzerLogger.logError('Error getting module names for question IDs - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Fetches all question IDs for a specific module name.
/// Returns an empty list if no questions are found for the module.
/// The module name is automatically normalized (lowercase, underscores to spaces) for matching.
Future<List<String>> getQuestionIdsForModule(String moduleName) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // Normalize the module name for consistent matching
    final String normalizedModuleName = await normalizeString(moduleName);
    
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'question_answer_pairs',
      db,
      columns: ['question_id'],
      where: 'module_name = ?',
      whereArgs: [normalizedModuleName],
    );
    
    final List<String> questionIds = results
        .map((row) => row['question_id'] as String)
        .where((id) => id.isNotEmpty)
        .toList();
    
    QuizzerLogger.logMessage('Found ${questionIds.length} question IDs for module: $moduleName (normalized: $normalizedModuleName)');
    return questionIds;
  } catch (e) {
    QuizzerLogger.logError('Error getting question IDs for module - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Updates the synchronization flags for a specific question-answer pair.
/// 
/// This function is used by the cloud synchronization system to track the sync status
/// of questions between local and remote databases. It updates two critical sync flags:
/// 
/// - `has_been_synced`: Indicates whether the question has ever been successfully
///   synchronized to the remote database. Set to true (1) when the question is first
///   uploaded to the cloud, false (0) when it exists only locally.
/// 
/// - `edits_are_synced`: Indicates whether any local modifications to the question
///   have been synchronized to the remote database. Set to true (1) when all local
///   changes have been uploaded, false (0) when there are pending local edits that
///   need to be synced.
/// 
/// The function also automatically updates the `last_modified_timestamp` to the current
/// UTC time whenever sync flags are changed, ensuring proper change tracking.
/// 
/// Parameters:
/// - `questionId`: The unique identifier of the question to update
/// - `hasBeenSynced`: Whether the question has been synchronized to the remote database
/// - `editsAreSynced`: Whether all local edits have been synchronized
/// 
/// The function handles non-existent question IDs gracefully by logging a warning
/// rather than throwing an exception, as this is expected behavior during sync operations.
Future<void> updateQuestionSyncFlags({
  required String questionId,
  required bool hasBeenSynced,
  required bool editsAreSynced,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // Ensure sync flags are only 1 or 0, never -1 or other values
    final Map<String, dynamic> updates = {
      'has_been_synced': hasBeenSynced ? 1 : 0,
      'edits_are_synced': editsAreSynced ? 1 : 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    
    // Validate that we're only setting valid sync flag values
    assert(updates['has_been_synced'] == 1 || updates['has_been_synced'] == 0, 
           'has_been_synced must be 1 or 0, got: ${updates['has_been_synced']}');
    assert(updates['edits_are_synced'] == 1 || updates['edits_are_synced'] == 0, 
           'edits_are_synced must be 1 or 0, got: ${updates['edits_are_synced']}');

    final int rowsAffected = await updateRawData(
      'question_answer_pairs',
      updates,
      'question_id = ?',
      [questionId],
      db,
    );

    if (rowsAffected == 0) {
      QuizzerLogger.logWarning('updateQuestionSyncFlags affected 0 rows for question ID: $questionId. Question might not exist?');
    } else {
      QuizzerLogger.logSuccess('Successfully updated sync flags for question ID: $questionId.');
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating question sync flags - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Fetches all question-answer pairs that need outbound synchronization.
/// This includes records that have never been synced (`has_been_synced = 0`)
/// or records that have local edits pending sync (`edits_are_synced = 0`).
/// Does NOT decode the records.
Future<List<Map<String, dynamic>>> getUnsyncedQuestionAnswerPairs() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching unsynced question-answer pairs...');
    final List<Map<String, dynamic>> results = await db.query(
      'question_answer_pairs',
      where: 'has_been_synced = 0 OR edits_are_synced = 0',
    );
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced question answer pairs - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}


/// Inserts a new question-answer pair or updates an existing one from inbound sync.
/// Sets sync flags to indicate the record is synced and edits are synced.
/// 
/// Returns:
///   bool: true if the operation was successful, false if validation failed.
Future<bool> insertOrUpdateQuestionAnswerPair(Map<String, dynamic> questionData) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // Ensure all required fields are present in the incoming data
    final String? questionId = questionData['question_id'] as String?;
    final String? timeStamp = questionData['time_stamp'] as String?;
    final String? qstContrib = questionData['qst_contrib'] as String?;
    final String? lastModifiedTimestamp = questionData['last_modified_timestamp'] as String?;
    final String? moduleName = questionData['module_name'] as String?;
    final String? questionType = questionData['question_type'] as String?;
    final String? questionElementsJson = questionData['question_elements'] as String?;
    final String? answerElementsJson = questionData['answer_elements'] as String?;

    assert(questionId != null, 'insertOrUpdateQuestionAnswerPair: question_id cannot be null. Data: $questionData');
    assert(timeStamp != null, 'insertOrUpdateQuestionAnswerPair: time_stamp cannot be null. Data: $questionData');
    assert(qstContrib != null, 'insertOrUpdateQuestionAnswerPair: qst_contrib cannot be null. Data: $questionData');
    assert(lastModifiedTimestamp != null, 'insertOrUpdateQuestionAnswerPair: last_modified_timestamp cannot be null. Data: $questionData');
    assert(moduleName != null, 'insertOrUpdateQuestionAnswerPair: module_name cannot be null. Data: $questionData');
    assert(questionType != null, 'insertOrUpdateQuestionAnswerPair: question_type cannot be null. Data: $questionData');
    assert(questionElementsJson != null, 'insertOrUpdateQuestionAnswerPair: question_elements cannot be null. Data: $questionData');
    assert(answerElementsJson != null, 'insertOrUpdateQuestionAnswerPair: answer_elements cannot be null. Data: $questionData');

    // Validate the data using the same validation as addQuestion functions
    try {
      _validateQuestionEntry(
        moduleName: moduleName!,
        questionElements: List<Map<String, dynamic>>.from(decodeValueFromDB(questionElementsJson!)),
        answerElements: List<Map<String, dynamic>>.from(decodeValueFromDB(answerElementsJson!)),
      );

      // Validate options if present (for question types that use them)
      if (questionType == 'multiple_choice' || questionType == 'select_all_that_apply' || questionType == 'sort_order') {
        final optionsJson = questionData['options'] as String?;
        if (optionsJson != null) {
          final options = List<Map<String, dynamic>>.from(decodeValueFromDB(optionsJson));
          _validateQuestionOptions(options);
        }
      }
    } catch (e) {
      QuizzerLogger.logError('Validation failed for question $questionId: $e');
      return false; // Return early if validation fails
    }

    // Prepare the data map, stripping out legacy fields that don't exist in local table
    final Map<String, dynamic> dataToInsertOrUpdate = Map<String, dynamic>.from(questionData);
    
    // Remove legacy fields that don't exist in local table schema
    dataToInsertOrUpdate.remove('citation');
    dataToInsertOrUpdate.remove('concepts');
    dataToInsertOrUpdate.remove('subjects');
    dataToInsertOrUpdate.remove('completed');
    
    // Normalize the module name
    dataToInsertOrUpdate['module_name'] = await normalizeString(moduleName);
    
    // Set sync flags to indicate synced status
    dataToInsertOrUpdate['has_been_synced'] = 1;
    dataToInsertOrUpdate['edits_are_synced'] = 1;

    // Use ConflictAlgorithm.replace to handle both insert and update scenarios
    final int rowId = await insertRawData(
      'question_answer_pairs',
      dataToInsertOrUpdate,
      db,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (rowId > 0) {
      QuizzerLogger.logSuccess('Successfully inserted/updated question-answer pair with ID: $questionId from inbound sync.');
      return true;
    } else {
      QuizzerLogger.logWarning('insertOrUpdateQuestionAnswerPair: insertRawData with replace returned 0 for question ID: $questionId. Data: $dataToInsertOrUpdate');
      return false;
    }
  } catch (e) {
    QuizzerLogger.logError('Error inserting or updating question answer pair - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// ===============================================================================
// --- Add Question Functions ---
// ===============================================================================

/// Private helper function to validate general question entry requirements
/// This validation applies to all question types and complements checkCompletionStatus
void _validateQuestionEntry({
  required String moduleName,
  required List<Map<String, dynamic>> questionElements,
  required List<Map<String, dynamic>> answerElements,
}) {
  // Validate module name (not done by checkCompletionStatus)
  if (moduleName.isEmpty) {
    throw Exception('Module name cannot be empty or whitespace-only.');
  }

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

/// Private helper function to validate question options
/// This validation applies to question types that use options (multiple choice, select all that apply, sort order, etc.)
void _validateQuestionOptions(List<Map<String, dynamic>> options) {
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

/// Adds a new multiple choice question to the database.
/// 
/// Args:
///   moduleName: The name of the module this question belongs to.
///   questionElements: A list of maps representing the question content.
///   answerElements: A list of maps representing the explanation/answer rationale.
///   options: A list of maps representing the multiple choice options.
///   correctOptionIndex: The index of the correct option (0-based).
///   debugDisableOutboundSyncCall: When true, prevents signaling the outbound sync system.
///     This is useful for testing to avoid triggering sync operations during test execution.
///     Defaults to false (sync is signaled normally).
///
/// Returns:
///   The unique question_id generated for this question (format: timestamp_userId).
Future<String> addQuestionMultipleChoice({
  required String moduleName,
  required List<Map<String, dynamic>> questionElements,
  required List<Map<String, dynamic>> answerElements,
  required List<Map<String, dynamic>> options,
  required int correctOptionIndex,
  bool debugDisableOutboundSyncCall = false,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // Get current user ID from session manager
    final String? userId = getSessionManager().userId;
    if (userId == null) {
      throw Exception('User must be logged in to add a question');
    }
    
    final String timeStamp = DateTime.now().toUtc().toIso8601String();

    // Normalize the module name and trim content fields in place
    moduleName = await normalizeString(moduleName);
    questionElements = trimContentFields(questionElements);
    answerElements = trimContentFields(answerElements);
    options = trimContentFields(options);

    // Check completion status before proceeding
    final int completionStatus = checkCompletionStatus(
        questionElements.isNotEmpty ? json.encode(questionElements) : '',
        answerElements.isNotEmpty ? json.encode(answerElements) : ''
    );
    
    if (completionStatus == 0) {
      throw Exception('Question is incomplete. Both question and answer elements must be provided and valid.');
    }

    // Additional Validation here:
    
    // Validate general question entry requirements
    _validateQuestionEntry(
      moduleName: moduleName,
      questionElements: questionElements,
      answerElements: answerElements,
    );

    // Validate options using helper function
    _validateQuestionOptions(options);

    // Multiple choice specific validation
    if (correctOptionIndex < 0) {
      throw Exception('Correct option index cannot be negative.');
    }
    if (correctOptionIndex >= options.length) {
      throw Exception('Correct option index $correctOptionIndex is out of range. Options list has ${options.length} elements.');
    }
    

    // Use the universal insert helper
    await insertRawData('question_answer_pairs', {
      'time_stamp': timeStamp,
      'question_elements': encodeValueForDB(questionElements),
      'answer_elements': encodeValueForDB(answerElements),
      'ans_flagged': 0, // Changed from false to 0
      'ans_contrib': '', // Default empty
      'qst_contrib': userId,
      'qst_reviewer': '', // Default empty
      'has_been_reviewed': 0, // Changed from false to 0
      'flag_for_removal': 0, // Changed from false to 0
      'module_name': moduleName,
      'question_type': 'multiple_choice',
      'options': encodeValueForDB(options),
      'correct_option_index': correctOptionIndex,
      'question_id': '${timeStamp}_$userId',
      'has_been_synced': 0, // Initialize sync flags
      'edits_are_synced': 0,
      'last_modified_timestamp': timeStamp, // Use creation timestamp
      'has_media': await hasMediaCheck({
        'time_stamp': timeStamp,
        'question_elements': encodeValueForDB(questionElements),
        'answer_elements': encodeValueForDB(answerElements),
        'ans_flagged': 0,
        'ans_contrib': '',
        'qst_contrib': userId,
        'qst_reviewer': '',
        'has_been_reviewed': 0,
        'flag_for_removal': 0,
        'module_name': moduleName,
        'question_type': 'multiple_choice',
        'options': encodeValueForDB(options),
        'correct_option_index': correctOptionIndex,
        'question_id': '${timeStamp}_$userId',
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': timeStamp,
      }),
    }, db);
    
    if (!debugDisableOutboundSyncCall) {
      signalOutboundSyncNeeded(); // Signal after successful insert
    }

    return '${timeStamp}_$userId'; // Return the generated question ID regardless of insert result (consistent with previous logic)
  } catch (e) {
    QuizzerLogger.logError('Error adding multiple choice question - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
    
    // Validate modules table after adding a question (after db access is released)
    await ensureAllQuestionModuleNamesHaveCorrespondingModuleRecords();
  }
}

/// Adds a new select all that apply question to the database.
/// 
/// Args:
///   moduleName: The name of the module this question belongs to.
///   questionElements: A list of maps representing the question content.
///   answerElements: A list of maps representing the explanation/answer rationale.
///   options: A list of maps representing the options to choose from.
///   indexOptionsThatApply: A list of indices (0-based) indicating which options are correct.
///   debugDisableOutboundSyncCall: When true, prevents signaling the outbound sync system.
///     This is useful for testing to avoid triggering sync operations during test execution.
///     Defaults to false (sync is signaled normally).
///
/// Returns:
///   The unique question_id generated for this question (format: timestamp_userId).
Future<String> addQuestionSelectAllThatApply({
  required String moduleName,
  required List<Map<String, dynamic>> questionElements,
  required List<Map<String, dynamic>> answerElements,
  required List<Map<String, dynamic>> options,
  required List<int> indexOptionsThatApply, // Use List<int>
  bool debugDisableOutboundSyncCall = false,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // Get current user ID from session manager
    final String? userId = getSessionManager().userId;
    if (userId == null) {
      throw Exception('User must be logged in to add a question');
    }
    
    final String timeStamp = DateTime.now().toUtc().toIso8601String();

    // Check completion status before proceeding
    final int completionStatus = checkCompletionStatus(
        questionElements.isNotEmpty ? json.encode(questionElements) : '',
        answerElements.isNotEmpty ? json.encode(answerElements) : ''
    );
    
    if (completionStatus == 0) {
      throw Exception('Question is incomplete. Both question and answer elements must be provided and valid.');
    }
    
    // Normalize the module name and trim content fields in place
    moduleName = await normalizeString(moduleName);
    questionElements = trimContentFields(questionElements);
    answerElements = trimContentFields(answerElements);
    options = trimContentFields(options);

    // Additional Validation here:
    
    // Validate general question entry requirements
    _validateQuestionEntry(
      moduleName: moduleName,
      questionElements: questionElements,
      answerElements: answerElements,
    );

    // Validate options using helper function
    _validateQuestionOptions(options);

    // Select all that apply specific validation
    if (indexOptionsThatApply.isEmpty) {
      throw Exception('At least one option must be selected for select all that apply questions.');
    }
    
    for (int i = 0; i < indexOptionsThatApply.length; i++) {
      final index = indexOptionsThatApply[i];
      if (index < 0) {
        throw Exception('Option index at position $i cannot be negative.');
      }
      if (index >= options.length) {
        throw Exception('Option index $index at position $i is out of range. Options list has ${options.length} elements.');
      }
    }

    // Use the universal insert helper
    await insertRawData('question_answer_pairs', {
      'time_stamp': timeStamp,
      'question_elements': encodeValueForDB(questionElements),
      'answer_elements': encodeValueForDB(answerElements),
      'ans_flagged': 0, // Changed from false to 0
      'ans_contrib': '', // Default empty
      'qst_contrib': userId,
      'qst_reviewer': '', // Default empty
      'has_been_reviewed': 0, // Changed from false to 0
      'flag_for_removal': 0, // Changed from false to 0
      'module_name': moduleName,
      'question_type': 'select_all_that_apply',
      'options': encodeValueForDB(options),
      'index_options_that_apply': encodeValueForDB(indexOptionsThatApply),
      'question_id': '${timeStamp}_$userId',
      'has_been_synced': 0, // Initialize sync flags
      'edits_are_synced': 0,
      'last_modified_timestamp': timeStamp, // Use creation timestamp
      'has_media': await hasMediaCheck({
        'time_stamp': timeStamp,
        'question_elements': encodeValueForDB(questionElements),
        'answer_elements': encodeValueForDB(answerElements),
        'ans_flagged': 0,
        'ans_contrib': '',
        'qst_contrib': userId,
        'qst_reviewer': '',
        'has_been_reviewed': 0,
        'flag_for_removal': 0,
        'module_name': moduleName,
        'question_type': 'select_all_that_apply',
        'options': encodeValueForDB(options),
        'index_options_that_apply': encodeValueForDB(indexOptionsThatApply),
        'question_id': '${timeStamp}_$userId',
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': timeStamp,
      }),
    }, db);
    
    if (!debugDisableOutboundSyncCall) {
      signalOutboundSyncNeeded(); // Signal after successful insert
    }

    return '${timeStamp}_$userId';
  } catch (e) {
    QuizzerLogger.logError('Error adding select all that apply question - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
    
    // Validate modules table after adding a question (after db access is released)
    await ensureAllQuestionModuleNamesHaveCorrespondingModuleRecords();
  }
}

/// Adds a new true/false question to the database.
/// 
/// Args:
///   moduleName: The name of the module this question belongs to.
///   questionElements: A list of maps representing the question content.
///   answerElements: A list of maps representing the explanation/answer rationale.
///   correctOptionIndex: The index of the correct option (0 for True, 1 for False).
///   debugDisableOutboundSyncCall: When true, prevents signaling the outbound sync system.
///     This is useful for testing to avoid triggering sync operations during test execution.
///     Defaults to false (sync is signaled normally).
///
/// Returns:
///   The unique question_id generated for this question (format: timestamp_userId).
Future<String> addQuestionTrueFalse({
  required String moduleName,
  required List<Map<String, dynamic>> questionElements,
  required List<Map<String, dynamic>> answerElements,
  required int correctOptionIndex, // 0 for True, 1 for False
  bool debugDisableOutboundSyncCall = false,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // Get current user ID from session manager
    final String? userId = getSessionManager().userId;
    if (userId == null) {
      throw Exception('User must be logged in to add a question');
    }
    
    final String timeStamp = DateTime.now().toUtc().toIso8601String();

    // Check completion status before proceeding
    final int completionStatus = checkCompletionStatus(
        questionElements.isNotEmpty ? json.encode(questionElements) : '',
        answerElements.isNotEmpty ? json.encode(answerElements) : ''
    );
    
    if (completionStatus == 0) {
      throw Exception('Question is incomplete. Both question and answer elements must be provided and valid.');
    }
    
    // Normalize the module name and trim content fields in place
    moduleName = await normalizeString(moduleName);
    questionElements = trimContentFields(questionElements);
    answerElements = trimContentFields(answerElements);

    // Additional Validation here:
    
    // Validate general question entry requirements
    _validateQuestionEntry(
      moduleName: moduleName,
      questionElements: questionElements,
      answerElements: answerElements,
    );

    // True/false specific validation
    if (correctOptionIndex < 0 || correctOptionIndex > 1) {
      throw Exception('Correct option index must be 0 (True) or 1 (False), got: $correctOptionIndex');
    }

    // Use the universal insert helper
    await insertRawData('question_answer_pairs', {
      'time_stamp': timeStamp,
      'question_elements': encodeValueForDB(questionElements),
      'answer_elements': encodeValueForDB(answerElements),
      'ans_flagged': 0, // Changed from false to 0
      'ans_contrib': '', // Default empty
      'qst_contrib': userId,
      'qst_reviewer': '', // Default empty
      'has_been_reviewed': 0, // Changed from false to 0
      'flag_for_removal': 0, // Changed from false to 0
      'module_name': moduleName,
      'question_type': 'true_false',
      'correct_option_index': correctOptionIndex,
      'question_id': '${timeStamp}_$userId',
      'has_been_synced': 0, // Initialize sync flags
      'edits_are_synced': 0,
      'last_modified_timestamp': timeStamp, // Use creation timestamp
      // 'options' column is intentionally left NULL/unspecified for true_false type
      'has_media': await hasMediaCheck({
        'time_stamp': timeStamp,
        'question_elements': encodeValueForDB(questionElements),
        'answer_elements': encodeValueForDB(answerElements),
        'ans_flagged': 0,
        'ans_contrib': '',
        'qst_contrib': userId,
        'qst_reviewer': '',
        'has_been_reviewed': 0,
        'flag_for_removal': 0,
        'module_name': moduleName,
        'question_type': 'true_false',
        'correct_option_index': correctOptionIndex,
        'question_id': '${timeStamp}_$userId',
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': timeStamp,
      }),
    }, db);
    if (!debugDisableOutboundSyncCall) {
      signalOutboundSyncNeeded(); // Signal after successful insert
    }

    return '${timeStamp}_$userId';
  } catch (e) {
    QuizzerLogger.logError('Error adding true/false question - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
    
    // Validate modules table after adding a question (after db access is released)
    await ensureAllQuestionModuleNamesHaveCorrespondingModuleRecords();
  }
}

/// Adds a new sort_order question to the database, following existing patterns.
///
/// Args:
///   moduleName: The name of the module this question belongs to.
///   questionElements: A list of maps representing the question content.
///   answerElements: A list of maps representing the explanation/answer rationale.
///   options: A list of strings representing the items to be sorted, **in the correct final order**.
///   debugDisableOutboundSyncCall: When true, prevents signaling the outbound sync system.
///     This is useful for testing to avoid triggering sync operations during test execution.
///     Defaults to false (sync is signaled normally).
///
/// Returns:
///   The unique question_id generated for this question (format: timestamp_userId).
Future<String> addSortOrderQuestion({
  required String moduleName,
  required List<Map<String, dynamic>> questionElements,
  required List<Map<String, dynamic>> answerElements,
  required List<Map<String, dynamic>> options, // Items in the correct sorted order
  bool debugDisableOutboundSyncCall = false,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // Get current user ID from session manager
    final String? userId = getSessionManager().userId;
    if (userId == null) {
      throw Exception('User must be logged in to add a question');
    }
    
    // Generate ID components using the established pattern
    final String timeStamp = DateTime.now().toUtc().toIso8601String();

    // Check completion status before proceeding
    final int completionStatus = checkCompletionStatus(
        questionElements.isNotEmpty ? json.encode(questionElements) : '',
        answerElements.isNotEmpty ? json.encode(answerElements) : ''
    );
    
    if (completionStatus == 0) {
      throw Exception('Question is incomplete. Both question and answer elements must be provided and valid.');
    }
    
    // Normalize the module name and trim content fields in place
    moduleName = await normalizeString(moduleName);
    questionElements = trimContentFields(questionElements);
    answerElements = trimContentFields(answerElements);
    options = trimContentFields(options);

    // Additional Validation here:
    
    // Validate general question entry requirements
    _validateQuestionEntry(
      moduleName: moduleName,
      questionElements: questionElements,
      answerElements: answerElements,
    );

    // Validate options using helper function
    _validateQuestionOptions(options);

    // Sort order specific validation
    if (options.length < 2) {
      throw Exception('Sort order questions must have at least 2 options to sort.');
    }

    QuizzerLogger.logMessage('Adding sort_order question with ID: ${timeStamp}_$userId for module $moduleName');

    // Use the universal insert helper (encoding happens inside)
    await insertRawData(
      'question_answer_pairs',
      {
        'time_stamp': timeStamp, // Part of legacy primary key and used for ID
        'question_elements': encodeValueForDB(questionElements), // Will be JSON encoded by helper
        'answer_elements': encodeValueForDB(answerElements),     // Will be JSON encoded by helper
        'ans_flagged': 0, // Default
        'ans_contrib': '', // Default
        'qst_contrib': userId, // Store contributor ID from session manager
        'qst_reviewer': '', // Default
        'has_been_reviewed': 0, // Default
        'flag_for_removal': 0, // Default
        'module_name': moduleName,
        'question_type': 'sort_order', // Use string literal
        'options': encodeValueForDB(options), // Store correctly ordered list, will be JSON encoded by helper
        'question_id': '${timeStamp}_$userId', // Store the generated ID
        'has_been_synced': 0, // Initialize sync flags
        'edits_are_synced': 0,
        'last_modified_timestamp': timeStamp, // Use creation timestamp
        // Fields specific to other types are omitted (correct_option_index, index_options_that_apply, correct_order)
        'has_media': await hasMediaCheck({
          'time_stamp': timeStamp,
          'question_elements': encodeValueForDB(questionElements),
          'answer_elements': encodeValueForDB(answerElements),
          'ans_flagged': 0,
          'ans_contrib': '',
          'qst_contrib': userId,
          'qst_reviewer': '',
          'has_been_reviewed': 0,
          'flag_for_removal': 0,
          'module_name': moduleName,
          'question_type': 'sort_order',
          'options': encodeValueForDB(options),
          'question_id': '${timeStamp}_$userId',
          'has_been_synced': 0,
          'edits_are_synced': 0,
          'last_modified_timestamp': timeStamp,
        }),
      },
      db,
    );
    if (!debugDisableOutboundSyncCall) {
      signalOutboundSyncNeeded(); // Signal after successful insert
    }

    return '${timeStamp}_$userId'; // Return the generated ID
  } catch (e) {
    QuizzerLogger.logError('Error adding sort order question - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
    
    // Validate modules table after adding a question (after db access is released)
    await ensureAllQuestionModuleNamesHaveCorrespondingModuleRecords();
  }
}


/// Adds a new fill_in_the_blank question to the database.
/// 
/// Args:
///   moduleName: The name of the module this question belongs to.
///   questionElements: A list of maps representing the question content (can include 'blank' type elements).
///   answerElements: A list of maps representing the explanation/answer rationale.
///   answersToBlanks: A list of maps where each map contains the correct answer and synonyms for each blank.
///   >> [{"cos x":["cos(x)","cos","cosine x","cosine(x)","cosine"]}]
///   debugDisableOutboundSyncCall: When true, prevents signaling the outbound sync system.
///     This is useful for testing to avoid triggering sync operations during test execution.
///     Defaults to false (sync is signaled normally).
///
/// Returns:
///   The unique question_id generated for this question (format: timestamp_userId).
Future<String> addFillInTheBlankQuestion({
  required String moduleName,
  required List<Map<String, dynamic>> questionElements,
  required List<Map<String, dynamic>> answerElements,
  required List<Map<String, List<String>>> answersToBlanks,
  bool debugDisableOutboundSyncCall = false,
}) async {
// [x] design data structure and answer validation for question type

// [x] update pair table with new fields

// [x] finish designing and writing answer validation function under session_manager directory

// [x] unit tests for answer validation function(s)

// [x] write add*Question function for type

// [x] update SessionManager to utilize new add*Question Type

// [x] update unit tests for addQuestionAPI

// [x] update SessionManager submitAnswer to support new validation function

// [x] update unit tests for submitAnswer API
//
// [x] update element renderer
//
// [x] create new question widget
// 
// [x] Update home page to utilize new question widget
// [x] Update live Preview widget to utilize widget
// [x] Update add_question widget to support new question type
//
// [x] update edit quesiton dialogue to support new question type
// ----------------------------------------------------------------------------
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // Get current user ID from session manager
    final String? userId = getSessionManager().userId;
    if (userId == null) {
      throw Exception('User must be logged in to add a question');
    }
    
    final String timeStamp = DateTime.now().toUtc().toIso8601String();

    // Normalize the module name and trim content fields in place
    moduleName = await normalizeString(moduleName);
    questionElements = trimContentFields(questionElements);
    answerElements = trimContentFields(answerElements);

    // Additional Validation here:
    
    // Validate general question entry requirements
    _validateQuestionEntry(
      moduleName: moduleName,
      questionElements: questionElements,
      answerElements: answerElements,
    );

    // Fill in the blank specific validation
    if (answersToBlanks.isEmpty) {
      throw Exception('Fill in the blank questions must have at least one answer group.');
    }

    // Ensure question_elements has n blank elements where n is the length of answers_to_blanks
    final int blankCount = questionElements.where((element) => element['type'] == 'blank').length;
    if (blankCount != answersToBlanks.length) {
      throw Exception('Number of blank elements ($blankCount) does not match number of answer groups (${answersToBlanks.length})');
    }

    // Validate each answer group has at least one answer
    for (int i = 0; i < answersToBlanks.length; i++) {
      final answerGroup = answersToBlanks[i];
      if (answerGroup.isEmpty) {
        throw Exception('Answer group at index $i cannot be empty.');
      }
    }

    // Check completion status before proceeding
    final String questionElementsJson = questionElements.isNotEmpty ? encodeValueForDB(questionElements) : '';
    final String answerElementsJson = answerElements.isNotEmpty ? encodeValueForDB(answerElements) : '';
    
    QuizzerLogger.logMessage("=== DEBUG: checkCompletionStatus input ===");
    QuizzerLogger.logValue("questionElementsJson: $questionElementsJson");
    QuizzerLogger.logValue("answerElementsJson: $answerElementsJson");
    QuizzerLogger.logMessage("=== END DEBUG ===");
    
    final int completionStatus = checkCompletionStatus(questionElementsJson, answerElementsJson);
    
    QuizzerLogger.logMessage("checkCompletionStatus returned: $completionStatus");
    
    if (completionStatus == 0) {
      throw Exception('Question is incomplete. Both question and answer elements must be provided and valid.');
    }

    // Use the universal insert helper
    await insertRawData('question_answer_pairs', {
      'time_stamp': timeStamp,
      'question_elements': encodeValueForDB(questionElements),
      'answer_elements': encodeValueForDB(answerElements),
      'ans_flagged': 0,
      'ans_contrib': '',
      'qst_contrib': userId,
      'qst_reviewer': '',
      'has_been_reviewed': 0,
      'flag_for_removal': 0,
      'module_name': moduleName,
      'question_type': 'fill_in_the_blank',
      'answers_to_blanks': encodeValueForDB(answersToBlanks),
      'question_id': '${timeStamp}_$userId',
      'has_been_synced': 0,
      'edits_are_synced': 0,
      'last_modified_timestamp': timeStamp,
      'has_media': await hasMediaCheck({
        'time_stamp': timeStamp,
        'question_elements': encodeValueForDB(questionElements),
        'answer_elements': encodeValueForDB(answerElements),
        'ans_flagged': 0,
        'ans_contrib': '',
        'qst_contrib': userId,
        'qst_reviewer': '',
        'has_been_reviewed': 0,
        'flag_for_removal': 0,
        'module_name': moduleName,
        'question_type': 'fill_in_the_blank',
        'answers_to_blanks': encodeValueForDB(answersToBlanks),
        'question_id': '${timeStamp}_$userId',
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': timeStamp,
      }),
    }, db);
    
    if (!debugDisableOutboundSyncCall) {
      signalOutboundSyncNeeded();
    }

    return '${timeStamp}_$userId';
  } catch (e) {
    QuizzerLogger.logError('Error adding fill in the blank question - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
    
    // Validate modules table after adding a question (after db access is released)
    await ensureAllQuestionModuleNamesHaveCorrespondingModuleRecords();
  }
}

// short_answer              isValidationDone [ ]

// matching                  isValidationDone [ ]

// hot_spot (clicks image)   isValidationDone [ ]

// label_diagram             isValidationDone [ ]

// math                      isValidationDone [ ]

// speech                    isValidationDone [ ]

// =====================================================================================
// Media Status Housekeeping Functions

/// Fetches all question-answer pairs where the 'has_media' status is NULL.
Future<List<Map<String, dynamic>>> getPairsWithNullMediaStatus() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching question-answer pairs with NULL has_media status...');
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'question_answer_pairs',
      db,
      where: 'has_media IS NULL',
    );
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting pairs with null media status - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Processes question-answer pairs with NULL 'has_media' status.
/// Fetches these records, runs a media check, and updates the 'has_media' flag directly in the database.
/// This method does NOT signal for outbound sync.
Future<void> processNullMediaStatusPairs() async {
  try {
    final List<Map<String, dynamic>> pairsToProcess = await getPairsWithNullMediaStatus();
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Starting to process pairs with NULL has_media status for direct update.');
    
    // 1. Get records with NULL has_media status
    

    if (pairsToProcess.isEmpty) {
      QuizzerLogger.logMessage('No pairs found with NULL has_media status to process.');
      return;
    }

    QuizzerLogger.logValue('Found ${pairsToProcess.length} pairs to process for has_media flag.');

    for (final record in pairsToProcess) {
      final String? questionId = record['question_id'] as String?;
      if (questionId == null || questionId.isEmpty) {
        QuizzerLogger.logWarning('Skipping record with NULL or empty question_id during NULL media status processing: $record');
        continue;
      }

      // 2. Run hasMediaCheck (this also handles registering files in media_sync_status table)
      // The entire record is passed to hasMediaCheck as it contains all potential media fields.
      final bool mediaFound = await hasMediaCheck(record);
      QuizzerLogger.logValue('Processing QID $questionId for has_media flag update. Media found by hasMediaCheck: $mediaFound');

      // 3. Directly update the has_media flag in the local DB using updateRawData
      final int rowsAffected = await updateRawData(
        'question_answer_pairs',
        {'has_media': mediaFound ? 1 : 0},
        'question_id = ?',
        [questionId],
        db,
      );

    if (rowsAffected > 0) {
      QuizzerLogger.logMessage('Successfully updated has_media flag for QID $questionId to ${mediaFound ? 1 : 0}.');
    } else {
      QuizzerLogger.logWarning('Failed to update has_media flag for QID $questionId. Record might have been deleted or question_id changed.');
    }
  }
  QuizzerLogger.logMessage('Finished processing pairs with NULL has_media status.');
  } catch (e) {
    QuizzerLogger.logError('Error processing null media status pairs - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// True batch upsert for question_answer_pairs using a single SQL statement
/// Automatically handles schema mismatches by only processing columns defined in expectedColumns
Future<void> batchUpsertQuestionAnswerPairs({
  required List<Map<String, dynamic>> records,
  required dynamic db,
  int chunkSize = 500,
}) async {
  try {
    if (records.isEmpty) {
      return;
    }
    
    // Process all records before batch processing
    final List<Map<String, dynamic>> processedRecords = [];
    for (final record in records) {
      final String? questionId = record['question_id'] as String?;
      if (questionId == null) {
        QuizzerLogger.logWarning('Skipping record with missing question_id. This record cannot be upserted.');
        continue;
      }
      
      // Create processed record with only columns that exist in expectedColumns schema
      final Map<String, dynamic> processedRecord = <String, dynamic>{};
      
      // Only include columns that are defined in expectedColumns
      for (final col in expectedColumns) {
        final name = col['name'] as String;
        if (record.containsKey(name)) {
          processedRecord[name] = record[name];
        }
      }
      
      // Normalize the module name if it exists
      if (processedRecord['module_name'] != null) {
        processedRecord['module_name'] = await normalizeString(processedRecord['module_name']);
      }
      
      // Set sync flags to indicate synced status
      processedRecord['has_been_synced'] = 1;
      processedRecord['edits_are_synced'] = 1;
      
      processedRecords.add(processedRecord);
    }
    
    if (processedRecords.isEmpty) {
      return;
    }
    
    for (int i = 0; i < processedRecords.length; i += chunkSize) {
      final batch = processedRecords.sublist(i, i + chunkSize > processedRecords.length ? processedRecords.length : i + chunkSize);
      
      // Dynamically get columns from the first record in the batch
      if (batch.isEmpty) continue;
      final columns = batch.first.keys.toList();
      
      final values = <dynamic>[];
      final valuePlaceholders = batch.map((r) {
        for (final col in columns) {
          values.add(r[col]);
        }
        return '(${List.filled(columns.length, '?').join(',')})';
      }).join(', ');
      
      // Use question_id as the upsert key since it has a UNIQUE constraint
      final updateSet = columns.where((c) => c != 'question_id').map((c) => '$c=excluded.$c').join(', ');
      final sql = 'INSERT INTO question_answer_pairs (${columns.join(',')}) VALUES $valuePlaceholders ON CONFLICT(question_id) DO UPDATE SET $updateSet;';
      
      try {
        await db.rawInsert(sql, values);
      } catch (e) {
        if (e.toString().contains('UNIQUE constraint failed') || e.toString().contains('2067')) {
          QuizzerLogger.logWarning('Unique constraint violation in batch upsert. Falling back to individual inserts.');
          // Fall back to individual inserts for this batch
          for (final record in batch) {
            try {
              await insertRawData('question_answer_pairs', record, db, conflictAlgorithm: ConflictAlgorithm.replace);
            } catch (individualError) {
              QuizzerLogger.logError('Failed to insert individual record: $individualError');
              // Continue with other records instead of failing the entire batch
            }
          }
        } else {
          rethrow;
        }
      }
    }
  } catch (e) {
    QuizzerLogger.logError('Error batch upserting question answer pairs - $e');
    rethrow;
  }
}
