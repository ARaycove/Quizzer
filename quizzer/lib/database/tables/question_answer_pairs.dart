import 'package:sqflite/sqflite.dart';
import 'package:quizzer/database/quizzer_database.dart';

Future<void> verifyQuestionAnswerPairTable() async {
  final Database db = await getDatabase();
  
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
        PRIMARY KEY (time_stamp, qst_contrib)
      )
    ''');
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

Future<int> addQuestionAnswerPair({
  required String timeStamp,
  required String citation,
  required List<Map<String, dynamic>> questionElements,
  required List<Map<String, dynamic>> answerElements,
  required bool ansFlagged,
  required String ansContrib,
  String? concepts,
  String? subjects,
  required String qstContrib,
  String? qstReviewer,
  required bool hasBeenReviewed,
  required bool flagForRemoval,
  required String moduleName,
  String? questionType,
  List<String>? options,
  int? correctOptionIndex,
}) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable();

  final Database db = await getDatabase();
  final formattedQuestionElements = _formatElements(questionElements);
  final formattedAnswerElements = _formatElements(answerElements);

  return await db.insert('question_answer_pairs', {
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
    'completed': _checkCompletionStatus(formattedQuestionElements, formattedAnswerElements) ? 1 : 0,
    'module_name': moduleName,
    'question_type': questionType ?? 'text',
    'options': options?.join(',') ?? '',
    'correct_option_index': correctOptionIndex ?? -1,
  });
}

Future<int> editQuestionAnswerPair({
  required String timeStamp,
  required String qstContrib,
  String? citation,
  List<Map<String, dynamic>>? questionElements,
  List<Map<String, dynamic>>? answerElements,
  bool? ansFlagged,
  String? ansContrib,
  String? concepts,
  String? subjects,
  String? qstReviewer,
  bool? hasBeenReviewed,
  bool? flagForRemoval,
  String? moduleName,
  String? questionType,
  List<String>? options,
  int? correctOptionIndex,
}) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable();

  final Database db = await getDatabase();
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
  if (options != null) values['options'] = options.join(',');
  if (correctOptionIndex != null) values['correct_option_index'] = correctOptionIndex;

  // Get current values to check completion status
  final current = await getQuestionAnswerPairById(timeStamp, qstContrib);
  if (current != null) {
    values.addAll(current);
    values['completed'] = _checkCompletionStatus(
      values['question_elements'] ?? '',
      values['answer_elements'] ?? '',
    );
  }

  return await db.update(
    'question_answer_pairs',
    values,
    where: 'time_stamp = ? AND qst_contrib = ?',
    whereArgs: [timeStamp, qstContrib],
  );
}


Future<Map<String, dynamic>?>       getQuestionAnswerPairById(String timeStamp, String qstContrib) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable();

  final Database db = await getDatabase();
  final List<Map<String, dynamic>> maps = await db.query(
    'question_answer_pairs',
    where: 'time_stamp = ? AND qst_contrib = ?',
    whereArgs: [timeStamp, qstContrib],
  );

  if (maps.isEmpty) return null;

  final pair = maps.first;
  
  // Parse the CSV strings into arrays of elements
  pair['question_elements'] = _parseElements(pair['question_elements']);
  pair['answer_elements'] = _parseElements(pair['answer_elements']);

  return pair;
}

Future<List<Map<String, dynamic>>>  getQuestionAnswerPairsBySubject(String subject) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable();

  final Database db = await getDatabase();
  return await db.query(
    'question_answer_pairs',
    where: 'subjects LIKE ?',
    whereArgs: ['%$subject%'],
  );
}

Future<List<Map<String, dynamic>>>  getQuestionAnswerPairsByConcept(String concept) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable();

  final Database db = await getDatabase();
  return await db.query(
    'question_answer_pairs',
    where: 'concepts LIKE ?',
    whereArgs: ['%$concept%'],
  );
}

Future<List<Map<String, dynamic>>>  getQuestionAnswerPairsBySubjectAndConcept(String subject, String concept) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable();

  final Database db = await getDatabase();
  return await db.query(
    'question_answer_pairs',
    where: 'subjects LIKE ? AND concepts LIKE ?',
    whereArgs: ['%$subject%', '%$concept%'],
  );
}
Future<Map<String, dynamic>?>       getRandomQuestionAnswerPair() async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable();

  final Database db = await getDatabase();
  final List<Map<String, dynamic>> maps = await db.rawQuery(
    'SELECT * FROM question_answer_pairs ORDER BY RANDOM() LIMIT 1'
  );
  return maps.isEmpty ? null : maps.first;
}

Future<List<Map<String, dynamic>>>  getAllQuestionAnswerPairs() async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable();

  final Database db = await getDatabase();
  return await db.query('question_answer_pairs');
}

Future<int> removeQuestionAnswerPair(String timeStamp, String qstContrib) async {
  // First verify that the table exists
  await verifyQuestionAnswerPairTable();

  final Database db = await getDatabase();
  return await db.delete(
    'question_answer_pairs',
    where: 'time_stamp = ? AND qst_contrib = ?',
    whereArgs: [timeStamp, qstContrib],
  );
}


