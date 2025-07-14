import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'dart:convert';
import 'table_helper.dart'; // Import the new helper file
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart'; // Import sync signals
import 'package:quizzer/backend_systems/00_database_manager/tables/media_sync_status_table.dart'; // Added import
import 'package:path/path.dart' as path; // Changed alias to path
import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // For Supabase client
import 'dart:typed_data';
import 'dart:io';
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';

// --- Universal Encoding/Decoding Helpers --- Removed, moved to 00_table_helper.dart ---

Future<void> verifyQuestionAnswerPairTable(dynamic db) async {
  
  // Check if the table exists
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='question_answer_pairs'"
  );
  
  if (tables.isEmpty) {
    await db.execute('''
      CREATE TABLE question_answer_pairs (
        time_stamp TEXT,
        citation TEXT,
        question_elements TEXT,  -- CSV of question elements in format: type:content
        answer_elements TEXT,    -- CSV of answer elements in format: type:content
        ans_flagged BOOLEAN,
        ans_contrib TEXT,
        concepts TEXT,
        subjects TEXT,
        qst_contrib TEXT,
        qst_reviewer TEXT,
        has_been_reviewed BOOLEAN,
        flag_for_removal BOOLEAN,
        completed BOOLEAN,
        module_name TEXT,
        question_type TEXT,      -- Added for multiple choice support
        options TEXT,            -- Added for multiple choice options
        correct_option_index INTEGER,  -- Added for multiple choice correct answer
        question_id TEXT UNIQUE, -- Added for unique question identification with UNIQUE constraint
        correct_order TEXT,      -- Added for sort_order
        index_options_that_apply TEXT,
        has_been_synced INTEGER DEFAULT 0,  -- Added for outbound sync tracking
        edits_are_synced INTEGER DEFAULT 0, -- Added for outbound edit sync tracking
        last_modified_timestamp TEXT,       -- Store as ISO8601 UTC string
        has_media INTEGER DEFAULT NULL,     
        PRIMARY KEY (time_stamp, qst_contrib)
      )
    ''');
    
    // Create index on module_name for better query performance
    await db.execute('CREATE INDEX idx_question_answer_pairs_module_name ON question_answer_pairs(module_name)');
    
  } else {
    // Check if question_id column exists
    final List<Map<String, dynamic>> columns = await db.rawQuery(
      "PRAGMA table_info(question_answer_pairs)"
    );
    
    final bool hasQuestionId = columns.any((column) => column['name'] == 'question_id');
    
    if (!hasQuestionId) {
      // Add question_id column to existing table
      await db.execute('ALTER TABLE question_answer_pairs ADD COLUMN question_id TEXT');
      
      // Update existing records with question_id
      final List<Map<String, dynamic>> existingPairs = await db.query('question_answer_pairs');
      for (var pair in existingPairs) {
        final timeStamp = pair['time_stamp'] as String;
        final qstContrib = pair['qst_contrib'] as String;
        final questionId = '${timeStamp}_$qstContrib';
        
        await db.update(
          'question_answer_pairs',
          {'question_id': questionId},
          where: 'time_stamp = ? AND qst_contrib = ?',
          whereArgs: [timeStamp, qstContrib],
        );
      }
    }

    // Check for correct_order (for sort_order type)
    final bool hasCorrectOrder = columns.any((column) => column['name'] == 'correct_order');
    if (!hasCorrectOrder) {
      QuizzerLogger.logMessage('Adding correct_order column to question_answer_pairs table.');
      // Add correct_order column as TEXT to store JSON list
      await db.execute('ALTER TABLE question_answer_pairs ADD COLUMN correct_order TEXT'); 
    }

    // Check for index_options_that_apply (for select_all_that_apply type)
    final bool hasIndexOptions = columns.any((column) => column['name'] == 'index_options_that_apply');
    if (!hasIndexOptions) {
      QuizzerLogger.logMessage('Adding index_options_that_apply column to question_answer_pairs table.');
      // Add index_options_that_apply column as TEXT to store CSV list of integers
      await db.execute('ALTER TABLE question_answer_pairs ADD COLUMN index_options_that_apply TEXT');
    }

    // Check for has_been_synced
    final bool hasBeenSyncedCol = columns.any((column) => column['name'] == 'has_been_synced');
    if (!hasBeenSyncedCol) {
      QuizzerLogger.logMessage('Adding has_been_synced column to question_answer_pairs table.');
      await db.execute('ALTER TABLE question_answer_pairs ADD COLUMN has_been_synced INTEGER DEFAULT 0');
    }

    // Check for edits_are_synced
    final bool hasEditsAreSyncedCol = columns.any((column) => column['name'] == 'edits_are_synced');
    if (!hasEditsAreSyncedCol) {
      QuizzerLogger.logMessage('Adding edits_are_synced column to question_answer_pairs table.');
      await db.execute('ALTER TABLE question_answer_pairs ADD COLUMN edits_are_synced INTEGER DEFAULT 0');
    }

    // Check for last_modified_timestamp
    final bool hasLastModifiedCol = columns.any((column) => column['name'] == 'last_modified_timestamp');
    if (!hasLastModifiedCol) {
      QuizzerLogger.logMessage('Adding last_modified_timestamp column to question_answer_pairs table.');
      await db.execute('ALTER TABLE question_answer_pairs ADD COLUMN last_modified_timestamp TEXT');
    }

    // Check for has_media column and add with DEFAULT NULL if missing
    final bool hasMediaCol = columns.any((column) => column['name'] == 'has_media');
    if (!hasMediaCol) {
      QuizzerLogger.logMessage('Adding has_media column with DEFAULT NULL to question_answer_pairs table.');
      await db.execute('ALTER TABLE question_answer_pairs ADD COLUMN has_media INTEGER DEFAULT NULL');
    }
    
    // Check if question_id has UNIQUE constraint and add it if missing
    final List<Map<String, dynamic>> uniqueIndexes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='question_answer_pairs'"
    );
    
    final List<String> existingUniqueIndexes = uniqueIndexes.map((index) => index['name'] as String).toList();
    
    // Check if unique constraint on question_id exists
    if (!existingUniqueIndexes.contains('idx_question_answer_pairs_question_id_unique')) {
      QuizzerLogger.logMessage('Checking for existing duplicates before adding UNIQUE constraint on question_id...');
      
      // First, find and clean up any existing duplicates
      final List<Map<String, dynamic>> duplicateGroups = await db.rawQuery('''
        SELECT question_id, COUNT(*) as count
        FROM question_answer_pairs 
        WHERE question_id IS NOT NULL 
        GROUP BY question_id 
        HAVING COUNT(*) > 1
      ''');
      
      if (duplicateGroups.isNotEmpty) {
        QuizzerLogger.logMessage('Found ${duplicateGroups.length} question_id groups with duplicates. Cleaning up...');
        
        for (final group in duplicateGroups) {
          final String questionId = group['question_id'] as String;
          final int count = group['count'] as int;
          
          QuizzerLogger.logMessage('Cleaning up $count duplicates for question_id: $questionId');
          
          // Get all records for this question_id
          final List<Map<String, dynamic>> duplicates = await db.query(
            'question_answer_pairs',
            where: 'question_id = ?',
            whereArgs: [questionId],
            orderBy: 'time_stamp ASC', // Keep the oldest record
          );
          
          // Keep the first record, delete the rest
          for (int i = 1; i < duplicates.length; i++) {
            final Map<String, dynamic> duplicate = duplicates[i];
            final String timeStamp = duplicate['time_stamp'] as String;
            final String qstContrib = duplicate['qst_contrib'] as String;
            
            QuizzerLogger.logMessage('Deleting duplicate: time_stamp=$timeStamp, qst_contrib=$qstContrib');
            await db.delete(
              'question_answer_pairs',
              where: 'time_stamp = ? AND qst_contrib = ?',
              whereArgs: [timeStamp, qstContrib],
            );
          }
        }
        
        QuizzerLogger.logSuccess('Finished cleaning up duplicates');
      }
      
      // Now create the unique index
      QuizzerLogger.logMessage('Adding UNIQUE constraint on question_id column to prevent duplicates.');
      await db.execute('CREATE UNIQUE INDEX idx_question_answer_pairs_question_id_unique ON question_answer_pairs(question_id)');
    }
    
    // Check if module_name index exists and create it if it doesn't
    final List<Map<String, dynamic>> indexes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='question_answer_pairs'"
    );
    
    final List<String> existingIndexes = indexes.map((index) => index['name'] as String).toList();
    
    if (!existingIndexes.contains('idx_question_answer_pairs_module_name')) {
      QuizzerLogger.logMessage('Creating index on module_name column for better query performance.');
      await db.execute('CREATE INDEX idx_question_answer_pairs_module_name ON question_answer_pairs(module_name)');
    }
  }
}

bool _checkCompletionStatus(String questionElements, String answerElements) {
  return questionElements.isNotEmpty && answerElements.isNotEmpty;
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
Future<bool> hasMediaCheck(Map<String, dynamic> questionRecord) async {
  final String? recordQuestionId = questionRecord['question_id'] as String?;
  final String loggingContextSuffix = recordQuestionId != null ? '(Question ID: $recordQuestionId)' : '(Question ID: unknown)';
  QuizzerLogger.logMessage('Processing media for question record $loggingContextSuffix');

  // Check for media using the existing internal helper
  final bool mediaFound = _internalHasMediaCheck(questionRecord);

  if (mediaFound) {
    QuizzerLogger.logMessage('Media found in record $loggingContextSuffix. Extracting filenames.');
    final Set<String> filenames = _extractMediaFilenames(questionRecord);

    if (filenames.isNotEmpty) {
      QuizzerLogger.logMessage('Extracted ${filenames.length} filenames for $loggingContextSuffix. Downloading if missing.');
      for (final filename in filenames) {
        await _fetchAndDownloadMediaIfMissing(filename);
      }
      // Signal the MediaSyncWorker after downloads
      signalMediaSyncStatusProcessed();
    } else {
      signalMediaSyncStatusProcessed();
      QuizzerLogger.logWarning('Media was indicated as found for $loggingContextSuffix, but no filenames were extracted. This might indicate an issue with _extractMediaFilenames or the data structure.');
    }
  } else {
    QuizzerLogger.logMessage('No media found in record $loggingContextSuffix.');
  }

  return mediaFound;
}


bool _internalHasMediaCheck(dynamic data) {
  if (data is Map<String, dynamic>) {
    // Check for direct image specification: {'image': 'file_name.ext'}
    if (data.containsKey('image') && data['image'] is String && (data['image'] as String).isNotEmpty) {
      return true;
    }
    // Check for element style: {'type': 'image', 'content': 'file_name.ext'}
    if (data['type'] == 'image' && data.containsKey('content') && data['content'] is String && (data['content'] as String).isNotEmpty) {
      return true;
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

Set<String> _extractMediaFilenames(dynamic data) {
  final Set<String> filenames = {};
  _recursiveExtractFilenames(data, filenames);
  return filenames;
}

void _recursiveExtractFilenames(dynamic data, Set<String> filenames) {
  if (data is Map<String, dynamic>) {
    if (data.containsKey('image') && data['image'] is String && (data['image'] as String).isNotEmpty) {
      filenames.add(data['image'] as String);
    } else if (data['type'] == 'image' && data.containsKey('content') && data['content'] is String && (data['content'] as String).isNotEmpty) {
      filenames.add(data['content'] as String);
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

Future<int> editQuestionAnswerPair({
  required String questionId,
  String? citation,
  List<Map<String, dynamic>>? questionElements,
  List<Map<String, dynamic>>? answerElements,
  // Specific field for Select All That Apply - expecting List<int>
  List<int>? indexOptionsThatApply,
  bool? ansFlagged,
  String? ansContrib,
  String? concepts,
  String? subjects,
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
}) async {
  try {
    // Fetch the existing record first
    final Map<String, dynamic> existingRecord = await getQuestionAnswerPairById(questionId);
    // Get the database access
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // First verify that the table exists
    await verifyQuestionAnswerPairTable(db);

    // Prepare map for raw values to update 
    Map<String, dynamic> valuesToUpdate = {};
    
    // Add non-null fields to the map without encoding here
    if (citation != null) valuesToUpdate['citation'] = citation;
    if (questionElements != null) valuesToUpdate['question_elements'] = questionElements;
    if (answerElements != null) valuesToUpdate['answer_elements'] = answerElements;
    if (indexOptionsThatApply != null) valuesToUpdate['index_options_that_apply'] = indexOptionsThatApply;
    if (ansFlagged != null) valuesToUpdate['ans_flagged'] = ansFlagged;
    if (ansContrib != null) valuesToUpdate['ans_contrib'] = ansContrib;
    if (concepts != null) valuesToUpdate['concepts'] = concepts;
    if (subjects != null) valuesToUpdate['subjects'] = subjects;
    if (qstReviewer != null) valuesToUpdate['qst_reviewer'] = qstReviewer;
    if (hasBeenReviewed != null) valuesToUpdate['has_been_reviewed'] = hasBeenReviewed;
    if (flagForRemoval != null) valuesToUpdate['flag_for_removal'] = flagForRemoval;
    if (moduleName != null) valuesToUpdate['module_name'] = moduleName;
    if (questionType != null) valuesToUpdate['question_type'] = questionType;
    if (options != null) valuesToUpdate['options'] = options;
    if (correctOptionIndex != null) valuesToUpdate['correct_option_index'] = correctOptionIndex;
    if (correctOrderElements != null) valuesToUpdate['correct_order'] = correctOrderElements;

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
    signalOutboundSyncNeeded(); // Signal after successful update
    return result;
  } catch (e) {
    QuizzerLogger.logError('Error editing question answer pair - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
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
    // First verify that the table exists
    await verifyQuestionAnswerPairTable(db);
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

Future<List<Map<String, dynamic>>>  getQuestionAnswerPairsBySubject(String subject) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // First verify that the table exists
    await verifyQuestionAnswerPairTable(db);
    // Use the helper function to query and decode the list of rows
    return await queryAndDecodeDatabase(
      'question_answer_pairs',
      db,
      where: 'subjects LIKE ?',
      whereArgs: ['%$subject%'],
    );
  } catch (e) {
    QuizzerLogger.logError('Error getting question answer pairs by subject - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<List<Map<String, dynamic>>>  getQuestionAnswerPairsByConcept(String concept) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // First verify that the table exists
    await verifyQuestionAnswerPairTable(db);
    // Use the helper function to query and decode the list of rows
    return await queryAndDecodeDatabase(
      'question_answer_pairs',
      db,
      where: 'concepts LIKE ?',
      whereArgs: ['%$concept%'],
    );
  } catch (e) {
    QuizzerLogger.logError('Error getting question answer pairs by concept - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<List<Map<String, dynamic>>>  getQuestionAnswerPairsBySubjectAndConcept(String subject, String concept) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // First verify that the table exists
    await verifyQuestionAnswerPairTable(db);
    // Use the helper function to query and decode the list of rows
    return await queryAndDecodeDatabase(
      'question_answer_pairs',
      db,
      where: 'subjects LIKE ? AND concepts LIKE ?',
      whereArgs: ['%$subject%', '%$concept%'],
    );
  } catch (e) {
    QuizzerLogger.logError('Error getting question answer pairs by subject and concept - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<Map<String, dynamic>?> getRandomQuestionAnswerPair() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // First verify that the table exists
    await verifyQuestionAnswerPairTable(db);

    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'question_answer_pairs', // tableName is still useful for context/logging if helper uses it
      db,
      customQuery: 'SELECT * FROM question_answer_pairs ORDER BY RANDOM() LIMIT 1',
      // whereArgs are not needed for this specific custom query
    );
    
    if (results.isEmpty) {
      return null;
    }
    return results.first; // queryAndDecodeDatabase now handles the decoding
  } catch (e) {
    QuizzerLogger.logError('Error getting random question answer pair - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<List<Map<String, dynamic>>>  getAllQuestionAnswerPairs() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // First verify that the table exists
    await verifyQuestionAnswerPairTable(db);
    // Use the helper function to query and decode all rows
    return await queryAndDecodeDatabase('question_answer_pairs', db);
  } catch (e) {
    QuizzerLogger.logError('Error getting all question answer pairs - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<int> removeQuestionAnswerPair(String timeStamp, String qstContrib) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // First verify that the table exists
    await verifyQuestionAnswerPairTable(db);

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
    await verifyQuestionAnswerPairTable(db);
    
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
Future<List<Map<String, dynamic>>> getQuestionRecordsForModule(String moduleName) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await verifyQuestionAnswerPairTable(db);
    
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'question_answer_pairs',
      db,
      where: 'module_name = ?',
      whereArgs: [moduleName],
    );
    
    QuizzerLogger.logMessage('Found ${results.length} questions for module: $moduleName');
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
    await verifyQuestionAnswerPairTable(db);
    
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
    
    QuizzerLogger.logMessage('Fetched module names for ${questionIdToModuleName.length} question IDs');
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
Future<List<String>> getQuestionIdsForModule(String moduleName) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await verifyQuestionAnswerPairTable(db);
    
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'question_answer_pairs',
      db,
      columns: ['question_id'],
      where: 'module_name = ?',
      whereArgs: [moduleName],
    );
    
    final List<String> questionIds = results
        .map((row) => row['question_id'] as String)
        .where((id) => id.isNotEmpty)
        .toList();
    
    QuizzerLogger.logMessage('Found ${questionIds.length} question IDs for module: $moduleName');
    return questionIds;
  } catch (e) {
    QuizzerLogger.logError('Error getting question IDs for module - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Fetches all unique subjects from the question_answer_pairs table.
/// Returns an empty list if no subjects are found.
Future<List<String>> getUniqueSubjects() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await verifyQuestionAnswerPairTable(db);
    
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'question_answer_pairs',
      db,
      columns: ['subjects'],
    );
    
    final Set<String> uniqueSubjects = <String>{};
    for (final row in results) {
      final String? subjects = row['subjects'] as String?;
      if (subjects != null && subjects.isNotEmpty) {
        // Split subjects by comma and add each one to the set
        final List<String> subjectList = subjects.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        uniqueSubjects.addAll(subjectList);
      }
    }
    
    final List<String> sortedSubjects = uniqueSubjects.toList()..sort();
    QuizzerLogger.logMessage('Found ${sortedSubjects.length} unique subjects');
    return sortedSubjects;
  } catch (e) {
    QuizzerLogger.logError('Error getting unique subjects - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Returns a set of all unique concepts present in the question_answer_pairs table
/// This is useful for populating concept filters in the UI
Future<Set<String>> getUniqueConcepts(dynamic db) async {
  QuizzerLogger.logMessage('Fetching unique concepts from question_answer_pairs table');
  // First verify that the table exists
  await verifyQuestionAnswerPairTable(db);
  
  // Query the database for all distinct concept values
  final List<Map<String, dynamic>> result = await db.rawQuery(
    'SELECT DISTINCT concept FROM question_answer_pairs WHERE concept IS NOT NULL AND concept != ""'
  );
  
  // Convert the result to a set of strings
  final Set<String> concepts = result
      .map((row) => row['concept'] as String)
      .toSet();
  
  QuizzerLogger.logSuccess('Retrieved ${concepts.length} unique concepts');
  return concepts;
}

/// Updates the synchronization flags for a specific question.
/// This function is used by the sync system to mark questions as synced.
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
    await verifyQuestionAnswerPairTable(db);
    
    final Map<String, dynamic> updates = {
      'has_been_synced': hasBeenSynced ? 1 : 0,
      'edits_are_synced': editsAreSynced ? 1 : 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };

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
    await verifyQuestionAnswerPairTable(db); // Ensure table and sync columns exist

    final List<Map<String, dynamic>> results = await db.query(
      'question_answer_pairs',
      where: 'has_been_synced = 0 OR edits_are_synced = 0',
    );

    QuizzerLogger.logSuccess('Fetched ${results.length} unsynced question-answer pairs.');
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
Future<void> insertOrUpdateQuestionAnswerPair(Map<String, dynamic> questionData) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await verifyQuestionAnswerPairTable(db);

    // Ensure all required fields are present in the incoming data
    final String? questionId = questionData['question_id'] as String?;
    final String? timeStamp = questionData['time_stamp'] as String?;
    final String? qstContrib = questionData['qst_contrib'] as String?;
    final String? lastModifiedTimestamp = questionData['last_modified_timestamp'] as String?;

    assert(questionId != null, 'insertOrUpdateQuestionAnswerPair: question_id cannot be null. Data: $questionData');
    assert(timeStamp != null, 'insertOrUpdateQuestionAnswerPair: time_stamp cannot be null. Data: $questionData');
    assert(qstContrib != null, 'insertOrUpdateQuestionAnswerPair: qst_contrib cannot be null. Data: $questionData');
    assert(lastModifiedTimestamp != null, 'insertOrUpdateQuestionAnswerPair: last_modified_timestamp cannot be null. Data: $questionData');

    // Prepare the data map with sync flags set to indicate synced status
    final Map<String, dynamic> dataToInsertOrUpdate = Map<String, dynamic>.from(questionData);
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
    } else {
      QuizzerLogger.logWarning('insertOrUpdateQuestionAnswerPair: insertRawData with replace returned 0 for question ID: $questionId. Data: $dataToInsertOrUpdate');
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

Future<String> addQuestionMultipleChoice({
  required String moduleName,
  required List<Map<String, dynamic>> questionElements,
  required List<Map<String, dynamic>> answerElements,
  required List<Map<String, dynamic>> options,
  required int correctOptionIndex,
  required String qstContrib, // Added contributor ID
  String? citation,
  String? concepts,
  String? subjects,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await verifyQuestionAnswerPairTable(db);
    final String timeStamp = DateTime.now().toUtc().toIso8601String();
    final String questionId = '${timeStamp}_$qstContrib';

    // Prepare the raw data map (values will be encoded by the helper)
    final Map<String, dynamic> data = {
      'time_stamp': timeStamp,
      'citation': citation,
      'question_elements': questionElements,
      'answer_elements': answerElements,
      'ans_flagged': false,
      'ans_contrib': '', // Default empty
      'concepts': concepts,
      'subjects': subjects,
      'qst_contrib': qstContrib,
      'qst_reviewer': '', // Default empty
      'has_been_reviewed': false,
      'flag_for_removal': false,
      // Check completion based on raw lists before encoding
      'completed': _checkCompletionStatus(
          questionElements.isNotEmpty ? json.encode(questionElements) : '', // Check if list is not empty before encoding for check
          answerElements.isNotEmpty ? json.encode(answerElements) : ''
      ),
      'module_name': moduleName,
      'question_type': 'multiple_choice',
      'options': options,
      'correct_option_index': correctOptionIndex,
      'question_id': questionId,
      'has_been_synced': 0, // Initialize sync flags
      'edits_are_synced': 0,
      'last_modified_timestamp': timeStamp, // Use creation timestamp
    };


    data['has_media'] = await hasMediaCheck(data);

    // Use the universal insert helper
    await insertRawData('question_answer_pairs', data, db);
    signalOutboundSyncNeeded(); // Signal after successful insert

    return questionId; // Return the generated question ID regardless of insert result (consistent with previous logic)
  } catch (e) {
    QuizzerLogger.logError('Error adding multiple choice question - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<String> addQuestionSelectAllThatApply({
  required String moduleName,
  required List<Map<String, dynamic>> questionElements,
  required List<Map<String, dynamic>> answerElements,
  required List<Map<String, dynamic>> options,
  required List<int> indexOptionsThatApply, // Use List<int>
  required String qstContrib,
  String? citation,
  String? concepts,
  String? subjects,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await verifyQuestionAnswerPairTable(db);
    final String timeStamp = DateTime.now().toUtc().toIso8601String();
    final String questionId = '${timeStamp}_$qstContrib';

    // Prepare the raw data map
    final Map<String, dynamic> data = {
      'time_stamp': timeStamp,
      'citation': citation,
      'question_elements': questionElements,
      'answer_elements': answerElements,
      'ans_flagged': false,
      'ans_contrib': '',
      'concepts': concepts,
      'subjects': subjects,
      'qst_contrib': qstContrib,
      'qst_reviewer': '',
      'has_been_reviewed': false,
      'flag_for_removal': false,
      'completed': _checkCompletionStatus(
          questionElements.isNotEmpty ? json.encode(questionElements) : '',
          answerElements.isNotEmpty ? json.encode(answerElements) : ''
      ),
      'module_name': moduleName,
      'question_type': 'select_all_that_apply',
      'options': options,
      'index_options_that_apply': indexOptionsThatApply,
      'question_id': questionId,
      'has_been_synced': 0, // Initialize sync flags
      'edits_are_synced': 0,
      'last_modified_timestamp': timeStamp, // Use creation timestamp
    };


    data['has_media'] = await hasMediaCheck(data);

    // Use the universal insert helper
    await insertRawData('question_answer_pairs', data, db);
    signalOutboundSyncNeeded(); // Signal after successful insert

    return questionId;
  } catch (e) {
    QuizzerLogger.logError('Error adding select all that apply question - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<String> addQuestionTrueFalse({
  required String moduleName,
  required List<Map<String, dynamic>> questionElements,
  required List<Map<String, dynamic>> answerElements,
  required int correctOptionIndex, // 0 for True, 1 for False
  required String qstContrib,
  String? citation,
  String? concepts,
  String? subjects,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await verifyQuestionAnswerPairTable(db);
    final String timeStamp = DateTime.now().toUtc().toIso8601String();
    final String questionId = '${timeStamp}_$qstContrib';

    // Prepare the raw data map
    final Map<String, dynamic> data = {
      'time_stamp': timeStamp,
      'citation': citation,
      'question_elements': questionElements,
      'answer_elements': answerElements,
      'ans_flagged': false,
      'ans_contrib': '',
      'concepts': concepts,
      'subjects': subjects,
      'qst_contrib': qstContrib,
      'qst_reviewer': '',
      'has_been_reviewed': false,
      'flag_for_removal': false,
      'completed': _checkCompletionStatus(
          questionElements.isNotEmpty ? json.encode(questionElements) : '',
          answerElements.isNotEmpty ? json.encode(answerElements) : ''
      ),
      'module_name': moduleName,
      'question_type': 'true_false',
      'correct_option_index': correctOptionIndex,
      'question_id': questionId,
      'has_been_synced': 0, // Initialize sync flags
      'edits_are_synced': 0,
      'last_modified_timestamp': timeStamp, // Use creation timestamp
      // 'options' column is intentionally left NULL/unspecified for true_false type
    };


    data['has_media'] = await hasMediaCheck(data);

    // Use the universal insert helper
    await insertRawData('question_answer_pairs', data, db);
    signalOutboundSyncNeeded(); // Signal after successful insert

    return questionId;
  } catch (e) {
    QuizzerLogger.logError('Error adding true/false question - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Adds a new sort_order question to the database, following existing patterns.
///
/// Args:
///   moduleId: The ID of the module this question belongs to.
///   questionElements: A list of maps representing the question content.
///   answerElements: A list of maps representing the explanation/answer rationale.
///   options: A list of strings representing the items to be sorted, **in the correct final order**.
///   qstContrib: The contributor ID for this question.
///   db: The database instance.
///   citation: Optional citation string.
///   concepts: Optional comma-separated concepts string.
///   subjects: Optional comma-separated subjects string.
///
/// Returns:
///   The unique question_id generated for this question (format: timestamp_qstContrib).
Future<String> addSortOrderQuestion({
  required String moduleId,
  required List<Map<String, dynamic>> questionElements,
  required List<Map<String, dynamic>> answerElements,
  required List<Map<String, dynamic>> options, // Items in the correct sorted order
  required String qstContrib, // Added contributor ID to match pattern
  String? citation,
  String? concepts,
  String? subjects,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // First verify that the table exists
    await verifyQuestionAnswerPairTable(db); // Ensure table and columns are ready

    // Generate ID components using the established pattern
    final String timeStamp = DateTime.now().toUtc().toIso8601String();
    final String questionId = '${timeStamp}_$qstContrib';

    // Prepare the raw data map - matching fields and defaults from other add functions
    final Map<String, dynamic> rawData = {
      'time_stamp': timeStamp, // Part of legacy primary key and used for ID
      'citation': citation,
      'question_elements': questionElements, // Will be JSON encoded by helper
      'answer_elements': answerElements,     // Will be JSON encoded by helper
      'ans_flagged': false, // Default
      'ans_contrib': '', // Default
      'concepts': concepts,
      'subjects': subjects,
      'qst_contrib': qstContrib, // Store contributor ID
      'qst_reviewer': '', // Default
      'has_been_reviewed': false, // Default
      'flag_for_removal': false, // Default
      // Use the helper to check completion status, mirroring other add functions
      'completed': _checkCompletionStatus(
          questionElements.isNotEmpty ? json.encode(questionElements) : '',
          answerElements.isNotEmpty ? json.encode(answerElements) : ''
      ),
      'module_name': moduleId,
      'question_type': 'sort_order', // Use string literal
      'options': options, // Store correctly ordered list, will be JSON encoded by helper
      'question_id': questionId, // Store the generated ID
      'has_been_synced': 0, // Initialize sync flags
      'edits_are_synced': 0,
      'last_modified_timestamp': timeStamp, // Use creation timestamp
      // Fields specific to other types are omitted (correct_option_index, index_options_that_apply, correct_order)
    };


    rawData['has_media'] = await hasMediaCheck(rawData);

    QuizzerLogger.logMessage('Adding sort_order question with ID: $questionId for module $moduleId');

    // Use the universal insert helper (encoding happens inside)
    await insertRawData(
      'question_answer_pairs',
      rawData,
      db,
    );
    signalOutboundSyncNeeded(); // Signal after successful insert

    return questionId; // Return the generated ID
  } catch (e) {
    QuizzerLogger.logError('Error adding sort order question - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// TODO matching                  isValidationDone [ ]

// TODO fill_in_the_blank         isValidationDone [ ]

// TODO short_answer              isValidationDone [ ]

// TODO hot_spot (clicks image)   isValidationDone [ ]

// TODO label_diagram             isValidationDone [ ]

// TODO math                      isValidationDone [ ]

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
    await verifyQuestionAnswerPairTable(db); // Ensure table and columns exist

    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'question_answer_pairs',
      db,
      where: 'has_media IS NULL',
    );

    QuizzerLogger.logSuccess('Fetched ${results.length} question-answer pairs with NULL has_media status.');
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
Future<void> batchUpsertQuestionAnswerPairs({
  required List<Map<String, dynamic>> records,
  int chunkSize = 500,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    if (records.isEmpty) return;
    QuizzerLogger.logMessage('Starting TRUE batch upsert for question_answer_pairs: \\${records.length} records');
    await verifyQuestionAnswerPairTable(db);

    // List of all columns in the table
    final columns = [
      'time_stamp',
      'citation',
      'question_elements',
      'answer_elements',
      'ans_flagged',
      'ans_contrib',
      'concepts',
      'subjects',
      'qst_contrib',
      'qst_reviewer',
      'has_been_reviewed',
      'flag_for_removal',
      'completed',
      'module_name',
      'question_type',
      'options',
      'correct_option_index',
      'question_id',
      'correct_order',
      'index_options_that_apply',
      'has_been_synced',
      'edits_are_synced',
      'last_modified_timestamp',
      'has_media',
    ];

    // Helper to get value or null/default
    dynamic getVal(Map<String, dynamic> r, String k, dynamic def) => r[k] ?? def;

    for (int i = 0; i < records.length; i += chunkSize) {
      final batch = records.sublist(i, i + chunkSize > records.length ? records.length : i + chunkSize);
      final values = <dynamic>[];
      final valuePlaceholders = batch.map((r) {
        for (final col in columns) {
          values.add(getVal(r, col, null));
        }
        return '(${List.filled(columns.length, '?').join(',')})';
      }).join(', ');

      // Use question_id as the upsert key if present, else (time_stamp, qst_contrib)
      // We'll use question_id for ON CONFLICT if available in all records, else fallback
      // For now, use question_id if present, else fallback to (time_stamp, qst_contrib)
      // But for compatibility, use question_id as the upsert key
      final updateSet = columns.where((c) => c != 'time_stamp' && c != 'qst_contrib').map((c) => '$c=excluded.$c').join(', ');
      final sql = 'INSERT INTO question_answer_pairs (${columns.join(',')}) VALUES $valuePlaceholders ON CONFLICT(time_stamp, qst_contrib) DO UPDATE SET $updateSet;';
      await db.rawInsert(sql, values);
    }
    QuizzerLogger.logSuccess('TRUE batch upsert for question_answer_pairs complete.');
  } catch (e) {
    QuizzerLogger.logError('Error batch upserting question answer pairs - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Gets the most recent last_modified_timestamp from the question_answer_pairs table
Future<String?> getMostRecentQuestionAnswerPairTimestamp() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    
    await verifyQuestionAnswerPairTable(db);
    
    // Query to get the maximum last_modified_timestamp
    final List<Map<String, dynamic>> results = await db.rawQuery(
      'SELECT MAX(last_modified_timestamp) as max_timestamp FROM question_answer_pairs WHERE last_modified_timestamp IS NOT NULL'
    );
    
    if (results.isNotEmpty && results.first['max_timestamp'] != null) {
      final String? maxTimestamp = results.first['max_timestamp'] as String?;
      QuizzerLogger.logMessage('Most recent question timestamp found: $maxTimestamp');
      return maxTimestamp;
    } else {
      QuizzerLogger.logMessage('No question records found with last_modified_timestamp');
      return null;
    }
  } catch (e) {
    QuizzerLogger.logError('Error getting most recent question timestamp - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}
