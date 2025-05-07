import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'dart:convert';
import '00_table_helper.dart'; // Import the new helper file
import 'package:quizzer/backend_systems/12_switch_board/switch_board.dart'; // Import SwitchBoard

// Get SwitchBoard instance for signaling
final SwitchBoard _switchBoard = SwitchBoard();

// TODO flag questions by user's primary language

// --- Universal Encoding/Decoding Helpers --- Removed, moved to 00_table_helper.dart ---

Future<void> verifyQuestionAnswerPairTable(Database db) async {
  
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
        question_id TEXT,        -- Added for unique question identification
        correct_order TEXT,      -- Added for sort_order
        index_options_that_apply TEXT,
        has_been_synced INTEGER DEFAULT 0,  -- Added for outbound sync tracking
        edits_are_synced INTEGER DEFAULT 0, -- Added for outbound edit sync tracking
        last_modified_timestamp TEXT,       -- Store as ISO8601 UTC string
        PRIMARY KEY (time_stamp, qst_contrib)
      )
    ''');
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
      // Optionally, backfill existing rows, e.g., with their time_stamp or current time
      // For simplicity, new rows will get it, old rows will have NULL until next edit or a separate migration script.
      // Or, update existing rows to use the 'time_stamp' as the initial last_modified_timestamp:
      // await db.rawUpdate('UPDATE question_answer_pairs SET last_modified_timestamp = time_stamp WHERE last_modified_timestamp IS NULL');
    }

    // TODO: Add checks for columns needed by other future question types here

  }
}

bool _checkCompletionStatus(String questionElements, String answerElements) {
  return questionElements.isNotEmpty && answerElements.isNotEmpty;
}

Future<int> editQuestionAnswerPair({
  required String questionId,
  required Database db,
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

  QuizzerLogger.logMessage('Updating question $questionId with fields: ${valuesToUpdate.keys.join(', ')}');

  // Use the universal update helper (encoding happens inside)
  final result = await updateRawData(
    'question_answer_pairs',
    valuesToUpdate, // Pass the map with raw values
    'question_id = ?', // where clause
    [questionId],      // whereArgs
    db,
  );
  _switchBoard.signalOutboundSyncNeeded(); // Signal after successful update
  return result;
}

/// Fetches a single question-answer pair by its composite ID.
/// The questionId format is expected to be 'timestamp_qstContrib'.
Future<Map<String, dynamic>> getQuestionAnswerPairById(String questionId, Database db) async {
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
    QuizzerLogger.logError('Query for single row (getQuestionAnswerPairById) returned ${results.length} results for ID: $questionId');
    throw StateError('Expected exactly one row for question ID $questionId, but found ${results.length}.');
  }

  // Return the single decoded row
  return results.first;
}

Future<List<Map<String, dynamic>>>  getQuestionAnswerPairsBySubject(String subject, Database db) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable(db);
  // Use the helper function to query and decode the list of rows
  return await queryAndDecodeDatabase(
    'question_answer_pairs',
    db,
    where: 'subjects LIKE ?',
    whereArgs: ['%$subject%'],
  );
}

Future<List<Map<String, dynamic>>>  getQuestionAnswerPairsByConcept(String concept, Database db) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable(db);
  // Use the helper function to query and decode the list of rows
  return await queryAndDecodeDatabase(
    'question_answer_pairs',
    db,
    where: 'concepts LIKE ?',
    whereArgs: ['%$concept%'],
  );
}

Future<List<Map<String, dynamic>>>  getQuestionAnswerPairsBySubjectAndConcept(String subject, String concept, Database db) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable(db);
  // Use the helper function to query and decode the list of rows
  return await queryAndDecodeDatabase(
    'question_answer_pairs',
    db,
    where: 'subjects LIKE ? AND concepts LIKE ?',
    whereArgs: ['%$subject%', '%$concept%'],
  );
}

Future<Map<String, dynamic>?>       getRandomQuestionAnswerPair(Database db) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable(db);

  // Cannot use standard queryDecodedList due to ORDER BY RANDOM()
  final List<Map<String, dynamic>> maps = await db.rawQuery(
    'SELECT * FROM question_answer_pairs ORDER BY RANDOM() LIMIT 1'
  );
  
  if (maps.isEmpty) {
    return null;
  }

  // Manually decode the single result from rawQuery
  final Map<String, dynamic> rawResult = maps.first;
  final Map<String, dynamic> decodedResult = {};
  for (final entry in rawResult.entries) {
    decodedResult[entry.key] = decodeValueFromDB(entry.value);
  }
  return decodedResult;
}

Future<List<Map<String, dynamic>>>  getAllQuestionAnswerPairs(Database db) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable(db);
  // Use the helper function to query and decode all rows
  return await queryAndDecodeDatabase('question_answer_pairs', db);
}

Future<int> removeQuestionAnswerPair(String timeStamp, String qstContrib, Database db) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable(db);

  return await db.delete(
    'question_answer_pairs',
    where: 'time_stamp = ? AND qst_contrib = ?',
    whereArgs: [timeStamp, qstContrib],
  );
}

/// Fetches the module name for a specific question ID.
/// Throws an error if the question ID is not found (Fail Fast).
Future<String> getModuleNameForQuestionId(String questionId, Database db) async {
  await verifyQuestionAnswerPairTable(db); // Ensure table/columns exist

  QuizzerLogger.logMessage('Fetching module_name for question ID: $questionId');
  
  final List<Map<String, dynamic>> result = await db.query(
    'question_answer_pairs',
    columns: ['module_name'], // Select only the module_name column
    where: 'question_id = ?',
    whereArgs: [questionId],
    limit: 1, // We expect only one result
  );

  // Fail fast if no record is found
  assert(result.isNotEmpty, 'No question found with ID: $questionId');
  // Fail fast if module_name is somehow null in the DB (shouldn't happen if added correctly)
  assert(result.first['module_name'] != null, 'Module name is null for question ID: $questionId');

  final moduleName = result.first['module_name'] as String;
  QuizzerLogger.logValue('Found module_name: $moduleName for question ID: $questionId');
  return moduleName;
}

/// Returns a set of all unique subjects present in the question_answer_pairs table
/// Subjects are expected to be stored as comma-separated strings in the 'subjects' column.
/// This is useful for populating subject filters in the UI
Future<Set<String>> getUniqueSubjects(Database db) async {
  QuizzerLogger.logMessage('Fetching unique subjects from question_answer_pairs table');
  // First verify that the table exists
  await verifyQuestionAnswerPairTable(db);
  
  // Query the database for all non-null, non-empty subjects strings
  final List<Map<String, dynamic>> result = await db.query(
    'question_answer_pairs',
    columns: ['subjects'], // Query the correct 'subjects' column
    where: 'subjects IS NOT NULL AND subjects != ""'
  );
  
  // Process the results to extract unique subjects from CSV strings
  final Set<String> subjects = {}; // Initialize an empty set

  for (final row in result) {
    final String? subjectsCsv = row['subjects'] as String?;
    if (subjectsCsv != null && subjectsCsv.isNotEmpty) {
       // Split the CSV string, trim whitespace, filter empty, and add to set
       subjectsCsv.split(',').forEach((subject) {
         final trimmedSubject = subject.trim();
         if (trimmedSubject.isNotEmpty) {
           subjects.add(trimmedSubject);
         }
       });
    }
  }
  
  QuizzerLogger.logSuccess('Retrieved ${subjects.length} unique subjects from CSV data');
  return subjects;
}

/// Returns a set of all unique concepts present in the question_answer_pairs table
/// This is useful for populating concept filters in the UI
Future<Set<String>> getUniqueConcepts(Database db) async {
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

/// Updates the synchronization flags for a specific question-answer pair.
/// Does NOT trigger a new sync signal.
///
/// Args:
///   questionId: The ID of the question to update.
///   hasBeenSynced: The new boolean state for the has_been_synced flag.
///   editsAreSynced: The new boolean state for the edits_are_synced flag.
///   db: The database instance.
Future<void> updateQuestionSyncFlags({
  required String questionId,
  required bool hasBeenSynced,
  required bool editsAreSynced,
  required Database db,
}) async {
  QuizzerLogger.logMessage('Updating sync flags for QID: $questionId (Synced: $hasBeenSynced, Edits Synced: $editsAreSynced)');
  // Ensure table exists (though likely already verified by caller)
  await verifyQuestionAnswerPairTable(db);

  // Prepare the update map, converting booleans to integers (1/0)
  final Map<String, dynamic> updates = {
    'has_been_synced': hasBeenSynced ? 1 : 0,
    'edits_are_synced': editsAreSynced ? 1 : 0,
  };

  // Use the universal update helper
  final int rowsAffected = await updateRawData(
    'question_answer_pairs',
    updates,
    'question_id = ?', // where clause
    [questionId],      // whereArgs
    db,
  );

  // Log if the expected row wasn't updated
  if (rowsAffected == 0) {
    QuizzerLogger.logWarning('updateQuestionSyncFlags affected 0 rows for QID: $questionId. Record might not exist?');
  } else {
    QuizzerLogger.logSuccess('Successfully updated sync flags for QID: $questionId');
  }
  // No signal is sent here as requested
}

/// Fetches all question-answer pairs that need outbound synchronization.
/// DOES NOT, decode the records
/// This includes records that have never been synced (`has_been_synced = 0`)
/// or records that have local edits pending sync (`edits_are_synced = 0`).
Future<List<Map<String, dynamic>>> getUnsyncedQuestionAnswerPairs(Database db) async {
  QuizzerLogger.logMessage('Fetching unsynced question-answer pairs...');
  // Ensure table and sync columns exist
  await verifyQuestionAnswerPairTable(db);

  // Use the universal query helper
  final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
    'question_answer_pairs',
    db,
    where: 'has_been_synced = 0 OR edits_are_synced = 0',
    // No whereArgs needed
  );

  QuizzerLogger.logSuccess('Fetched ${results.length} unsynced question-answer pairs.');
  return results;
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
  required Database db,
  String? citation,
  String? concepts,
  String? subjects,
}) async {
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

  // Use the universal insert helper
  await insertRawData('question_answer_pairs', data, db);
  _switchBoard.signalOutboundSyncNeeded(); // Signal after successful insert

  return questionId; // Return the generated question ID regardless of insert result (consistent with previous logic)
}

Future<String> addQuestionSelectAllThatApply({
  required String moduleName,
  required List<Map<String, dynamic>> questionElements,
  required List<Map<String, dynamic>> answerElements,
  required List<Map<String, dynamic>> options,
  required List<int> indexOptionsThatApply, // Use List<int>
  required String qstContrib,
  required Database db,
  String? citation,
  String? concepts,
  String? subjects,
}) async {
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

  // Use the universal insert helper
  await insertRawData('question_answer_pairs', data, db);
  _switchBoard.signalOutboundSyncNeeded(); // Signal after successful insert

  return questionId;
}

Future<String> addQuestionTrueFalse({
  required String moduleName,
  required List<Map<String, dynamic>> questionElements,
  required List<Map<String, dynamic>> answerElements,
  required int correctOptionIndex, // 0 for True, 1 for False
  required String qstContrib,
  required Database db,
  String? citation,
  String? concepts,
  String? subjects,
}) async {
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

  // Use the universal insert helper
  await insertRawData('question_answer_pairs', data, db);
  _switchBoard.signalOutboundSyncNeeded(); // Signal after successful insert

  return questionId;
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
  required Database db,
  String? citation,
  String? concepts,
  String? subjects,
}) async {
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

  QuizzerLogger.logMessage('Adding sort_order question with ID: $questionId for module $moduleId');

  // Use the universal insert helper (encoding happens inside)
  await insertRawData(
    'question_answer_pairs',
    rawData,
    db,
  );
  _switchBoard.signalOutboundSyncNeeded(); // Signal after successful insert

  return questionId; // Return the generated ID
}

// TODO matching                  isValidationDone [ ]

// TODO fill_in_the_blank         isValidationDone [ ]

// TODO short_answer              isValidationDone [ ]

// TODO hot_spot (clicks image)   isValidationDone [ ]

// TODO label_diagram             isValidationDone [ ]

// TODO math                      isValidationDone [ ]

