import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

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

    // TODO: Add checks for columns needed by other future question types here

  }
}

bool _checkCompletionStatus(String questionElements, String answerElements) {
  return questionElements.isNotEmpty && answerElements.isNotEmpty;
}

String _formatElements(List<Map<String, dynamic>> elements) {
  return elements.map((e) => '${e['type']}:${e['content']}').join(',');
}

List<Map<String, dynamic>> _parseElements(String csvString) {
  if (csvString.isEmpty) return [];
  
  return csvString.split(',').map((element) {
    final parts = element.split(':');
    return {
      'type': parts[0],
      'content': parts[1],
    };
  }).toList();
}

// Helper to format List<int> to CSV string
String _formatIndices(List<int> indices) {
  return indices.map((index) => index.toString()).join(',');
}

// Helper to parse CSV string to List<int>
List<int> _parseIndices(String? csvString) {
  if (csvString == null || csvString.isEmpty) return [];
  
  try {
    return csvString.split(',').map((s) => int.parse(s.trim())).toList();
  } on FormatException catch (e) {
    QuizzerLogger.logError('Failed to parse indices CSV: "$csvString". Error: $e');
    // Fail Fast: Re-throw as StateError for data integrity issues
    throw StateError('Invalid format for index_options_that_apply CSV: "$csvString"'); 
  }
}

Future<int> editQuestionAnswerPair({
  required String questionId,
  required Database db,
  String? citation,
  List<Map<String, dynamic>>? questionElements,
  List<Map<String, dynamic>>? answerElements,
  List<Map<String, dynamic>>? correctOrderElements,
  bool? ansFlagged,
  String? ansContrib,
  String? concepts,
  String? subjects,
  String? qstReviewer,
  bool? hasBeenReviewed,
  bool? flagForRemoval,
  String? moduleName,
  String? questionType,
  List<Map<String, dynamic>>? options,
  int? correctOptionIndex,
  
}) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable(db);

  Map<String, dynamic> values = {};
  
  if (citation != null) values['citation'] = citation;
  if (questionElements != null) values['question_elements'] = _formatElements(questionElements);
  if (answerElements != null) values['answer_elements'] = _formatElements(answerElements);
  if (ansFlagged != null) values['ans_flagged'] = ansFlagged;
  if (ansContrib != null) values['ans_contrib'] = ansContrib;
  if (concepts != null) values['concepts'] = concepts;
  if (subjects != null) values['subjects'] = subjects;
  if (qstReviewer != null) values['qst_reviewer'] = qstReviewer;
  if (hasBeenReviewed != null) values['has_been_reviewed'] = hasBeenReviewed;
  if (flagForRemoval != null) values['flag_for_removal'] = flagForRemoval;
  if (moduleName != null) values['module_name'] = moduleName;
  if (questionType != null) values['question_type'] = questionType;
  if (options != null) values['options'] = _formatElements(options);
  if (correctOptionIndex != null) values['correct_option_index'] = correctOptionIndex;
  if (correctOrderElements != null) {values['correct_order'] = _formatElements(correctOrderElements);}

  // Get current values to check completion status
  final current = await getQuestionAnswerPairById(questionId, db);
  values.addAll(current);
  values['completed'] = _checkCompletionStatus(
    values['question_elements'] ?? '',
    values['answer_elements'] ?? '',
  );

  return await db.update(
    'question_answer_pairs',
    values,
    where: 'question_id = ?',
    whereArgs: [questionId],
  );
}

/// Fetches a single question-answer pair by its composite ID.
/// The questionId format is expected to be 'timestamp_qstContrib'.
Future<Map<String, dynamic>> getQuestionAnswerPairById(String questionId, Database db) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable(db);

  QuizzerLogger.logMessage('Fetching question_answer_pair with ID: $questionId');

  final List<Map<String, dynamic>> maps = await db.query(
    'question_answer_pairs',
    where: 'question_id = ?', // Query by the composite question_id directly
    whereArgs: [questionId],   // Use the provided questionId
  );
  // Create a new map instead of modifying the read-only query result
  final Map<String, dynamic> result = Map<String, dynamic>.from(maps.first);
  
  // Parse the element CSV strings if they exist
  if(result.containsKey('question_elements')){
      result['question_elements'] = _parseElements(result['question_elements']);
  }
  if(result.containsKey('answer_elements')){
      result['answer_elements'] = _parseElements(result['answer_elements']);
  }
  // Parse options string into List<Map<String, dynamic>>
  if (result.containsKey('options')) {
    final optionsCsv = result['options'] as String?;
    if (optionsCsv != null && optionsCsv.isNotEmpty) {
      result['options'] = _parseElements(optionsCsv);
    } else {
      result['options'] = <Map<String, dynamic>>[]; // Empty list if null or empty CSV
    }
  }

  // Parse correct_order CSV string into List<Map<String, dynamic>>
  if (result.containsKey('correct_order')) {
    final correctOrderCsv = result['correct_order'] as String?;
    if (correctOrderCsv != null && correctOrderCsv.isNotEmpty) {
      result['correct_order'] = _parseElements(correctOrderCsv);
    } else {
      result['correct_order'] = <Map<String, dynamic>>[]; // Empty list if null or empty CSV
    }
  }

  // Parse index_options_that_apply CSV string into List<int>
  if (result.containsKey('index_options_that_apply')) {
    result['index_options_that_apply'] = _parseIndices(result['index_options_that_apply'] as String?);
  }
  // Ensure subjects is parsed if needed, although it might already be a string
  // if (result.containsKey('subjects')) { ... parsing logic if needed ... }

  QuizzerLogger.logSuccess('Successfully fetched question $questionId');
  return result;
}

Future<List<Map<String, dynamic>>>  getQuestionAnswerPairsBySubject(String subject, Database db) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable(db);

  return await db.query(
    'question_answer_pairs',
    where: 'subjects LIKE ?',
    whereArgs: ['%$subject%'],
  );
}

Future<List<Map<String, dynamic>>>  getQuestionAnswerPairsByConcept(String concept, Database db) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable(db);

  return await db.query(
    'question_answer_pairs',
    where: 'concepts LIKE ?',
    whereArgs: ['%$concept%'],
  );
}

Future<List<Map<String, dynamic>>>  getQuestionAnswerPairsBySubjectAndConcept(String subject, String concept, Database db) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable(db);

  return await db.query(
    'question_answer_pairs',
    where: 'subjects LIKE ? AND concepts LIKE ?',
    whereArgs: ['%$subject%', '%$concept%'],
  );
}
Future<Map<String, dynamic>?>       getRandomQuestionAnswerPair(Database db) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable(db);

  final List<Map<String, dynamic>> maps = await db.rawQuery(
    'SELECT * FROM question_answer_pairs ORDER BY RANDOM() LIMIT 1'
  );
  return maps.isEmpty ? null : maps.first;
}

Future<List<Map<String, dynamic>>>  getAllQuestionAnswerPairs(Database db) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable(db);
  return await db.query('question_answer_pairs');
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

// We should have a dedicated function to add a question answer pair, for each question type
/// Adds a new multiple-choice question to the database.
/// Requires specific fields relevant to multiple-choice questions.
Future<int> addQuestionMultipleChoice({
  required String timeStamp, // Used for generating question_id
  required String qstContrib, // Used for generating question_id
  required List<Map<String, dynamic>> questionElements,
  required List<Map<String, dynamic>> answerElements,
  // Options format: List<Map<String, dynamic>>, where each map represents one option,
  // typically like {'type': 'text', 'content': 'option_text'}. Each map is one option.
  required List<Map<String, dynamic>> options,
  required int correctOptionIndex, // Specific to multiple choice
  required String moduleName,
  required String ansContrib, // Assuming this is still required
  required bool ansFlagged, // Assuming required
  required bool hasBeenReviewed, // Assuming required
  required bool flagForRemoval, // Assuming required
  String citation = '',
  String? concepts,
  String? subjects,
  String? qstReviewer,
  required Database db,
}) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable(db);

  // Generate question_id
  final questionId = '${timeStamp}_$qstContrib';

  // Format elements and options using the element formatter
  final formattedQuestionElements = _formatElements(questionElements);
  final formattedAnswerElements   = _formatElements(answerElements);
  final formattedOptions          = _formatElements(options); // CHANGED: Use _formatElements

  // Check completion status based on formatted elements
  final bool completed = _checkCompletionStatus(formattedQuestionElements, formattedAnswerElements);

  // Prepare data map
  final Map<String, dynamic> data = {
    'time_stamp': timeStamp,
    'citation': citation,
    'question_elements': formattedQuestionElements,
    'answer_elements': formattedAnswerElements,
    'ans_flagged': ansFlagged ? 1 : 0,
    'ans_contrib': ansContrib,
    'concepts': concepts ?? '', // Use empty string if null
    'subjects': subjects ?? '', // Use empty string if null
    'qst_contrib': qstContrib,
    'qst_reviewer': qstReviewer, // Nullable is okay for DB
    'has_been_reviewed': hasBeenReviewed ? 1 : 0,
    'flag_for_removal': flagForRemoval ? 1 : 0,
    'completed': completed ? 1 : 0,
    'module_name': moduleName,
    'question_type': 'multiple_choice', // Set type explicitly
    'options': formattedOptions, // Use the newly formatted options string
    'correct_option_index': correctOptionIndex,
    'question_id': questionId,
    // 'correct_order': null, // Explicitly null for non-sort_order types (DB allows NULL)
  };

  // Remove null value keys specifically for qst_reviewer before insert
  // Other nulls were handled with ?? '' or are nullable in the schema.
  if (data['qst_reviewer'] == null) {
      data.remove('qst_reviewer');
  }

  QuizzerLogger.logMessage('Adding multiple_choice question with ID: $questionId');
  final result = await db.insert(
    'question_answer_pairs',
    data,
    // Using ignore conflict algorithm, assuming question_id should be unique
    // If timestamp+contrib isn't guaranteed unique, consider ConflictAlgorithm.replace or fail
    conflictAlgorithm: ConflictAlgorithm.ignore,
  );
  if (result == 0) {
     QuizzerLogger.logWarning('Failed to insert multiple_choice question $questionId (maybe duplicate?)');
  } else {
     QuizzerLogger.logSuccess('Successfully added multiple_choice question $questionId with row ID: $result');
  }
  return result;
}

// select_all_that_apply     isValidationDone [X]
/// Adds a new select-all-that-apply question to the database.
Future<int> addQuestionSelectAllThatApply({
  required String timeStamp,
  required String qstContrib,
  required List<Map<String, dynamic>> questionElements,
  required List<Map<String, dynamic>> answerElements,
  required List<Map<String, dynamic>> options,
  required List<int> indexOptionsThatApply, // Specific to this type
  required String moduleName,
  required String ansContrib,
  required bool ansFlagged,
  required bool hasBeenReviewed,
  required bool flagForRemoval,
  String citation = '',
  String? concepts,
  String? subjects,
  String? qstReviewer,
  required Database db,
}) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable(db);

  // Generate question_id
  final questionId = '${timeStamp}_$qstContrib';

  // Format elements, options, and indices
  final formattedQuestionElements = _formatElements(questionElements);
  final formattedAnswerElements   = _formatElements(answerElements);
  final formattedOptions          = _formatElements(options);
  final formattedIndices          = _formatIndices(indexOptionsThatApply);

  // Check completion status
  final bool completed = _checkCompletionStatus(formattedQuestionElements, formattedAnswerElements);

  // Prepare data map
  final Map<String, dynamic> data = {
    'time_stamp': timeStamp,
    'citation': citation,
    'question_elements': formattedQuestionElements,
    'answer_elements': formattedAnswerElements,
    'ans_flagged': ansFlagged ? 1 : 0,
    'ans_contrib': ansContrib,
    'concepts': concepts ?? '',
    'subjects': subjects ?? '',
    'qst_contrib': qstContrib,
    'qst_reviewer': qstReviewer,
    'has_been_reviewed': hasBeenReviewed ? 1 : 0,
    'flag_for_removal': flagForRemoval ? 1 : 0,
    'completed': completed ? 1 : 0,
    'module_name': moduleName,
    'question_type': 'select_all_that_apply', // Set type explicitly
    'options': formattedOptions,
    'index_options_that_apply': formattedIndices, // Use the formatted indices string
    'correct_option_index': null, // Explicitly null for this type
    'question_id': questionId,
  };

  // Remove null value key specifically for qst_reviewer
  if (data['qst_reviewer'] == null) {
      data.remove('qst_reviewer');
  }

  QuizzerLogger.logMessage('Adding select_all_that_apply question with ID: $questionId');
  final result = await db.insert(
    'question_answer_pairs',
    data,
    conflictAlgorithm: ConflictAlgorithm.ignore, // Assume question_id should be unique
  );
  if (result == 0) {
     QuizzerLogger.logWarning('Failed to insert select_all_that_apply question $questionId (maybe duplicate?)');
  } else {
     QuizzerLogger.logSuccess('Successfully added select_all_that_apply question $questionId with row ID: $result');
  }
  return result;
}


// TODO true_false                isValidationDone [ ]


// TODO sort_order                isValidationDone [ ]


// TODO matching                  isValidationDone [ ]


// TODO fill_in_the_blank         isValidationDone [ ]


// TODO short_answer              isValidationDone [ ]


// TODO hot_spot (clicks image)   isValidationDone [ ]


// TODO label_diagram             isValidationDone [ ]


// TODO math                      isValidationDone [ ]