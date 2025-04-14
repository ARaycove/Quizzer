import 'package:sqflite/sqflite.dart';
import 'package:quizzer/database/quizzer_database.dart';

Future<void> verifyUserQuestionAnswerPairTable() async {
  final Database db = await getDatabase();
  
  // Check if the table exists
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='user_question_answer_pairs'"
  );
  
  if (tables.isEmpty) {
    await db.execute('''
      CREATE TABLE user_question_answer_pairs (
        user_uuid TEXT,
        question_answer_reference TEXT,
        revision_streak INTEGER,
        last_revised TEXT,
        predicted_revision_due_history TEXT,
        next_revision_due TEXT,
        time_between_revisions REAL,
        average_times_shown_per_day REAL,
        is_eligible BOOLEAN,
        is_module_active BOOLEAN,
        in_circulation BOOLEAN,
        PRIMARY KEY (user_uuid, question_answer_reference)
      )
    ''');
  }
}

Future<bool> _checkTableExists() async {
  try {
    final Database db = await getDatabase();
    await db.rawQuery('SELECT 1 FROM user_question_answer_pairs LIMIT 1');
    return true;
  } catch (e) {
    await verifyUserQuestionAnswerPairTable();
    return false;
  }
}

Future<int> addUserQuestionAnswerPair({
  required String userUuid,
  required String questionAnswerReference,
  required int revisionStreak,
  required String lastRevised,
  required String predictedRevisionDueHistory,
  required String nextRevisionDue,
  required double timeBetweenRevisions,
  required double averageTimesShownPerDay,
  required bool isEligible,
  required bool isModuleActive,
  required bool inCirculation,
}) async {
  await verifyUserQuestionAnswerPairTable();

  final Database db = await getDatabase();
  return await db.insert('user_question_answer_pairs', {
    'user_uuid': userUuid,
    'question_answer_reference': questionAnswerReference,
    'revision_streak': revisionStreak,
    'last_revised': lastRevised,
    'predicted_revision_due_history': predictedRevisionDueHistory,
    'next_revision_due': nextRevisionDue,
    'time_between_revisions': timeBetweenRevisions,
    'average_times_shown_per_day': averageTimesShownPerDay,
    'is_eligible': isEligible,
    'is_module_active': isModuleActive,
    'in_circulation': inCirculation,
  });
}

Future<int> editUserQuestionAnswerPair({
  required String userUuid,
  required String questionAnswerReference,
  int? revisionStreak,
  String? lastRevised,
  String? predictedRevisionDueHistory,
  String? nextRevisionDue,
  double? timeBetweenRevisions,
  double? averageTimesShownPerDay,
  bool? isEligible,
  bool? isModuleActive,
  bool? inCirculation,
}) async {
  await verifyUserQuestionAnswerPairTable();

  final Database db = await getDatabase();
  Map<String, dynamic> values = {};
  
  if (revisionStreak != null) values['revision_streak'] = revisionStreak;
  if (lastRevised != null) values['last_revised'] = lastRevised;
  if (predictedRevisionDueHistory != null) values['predicted_revision_due_history'] = predictedRevisionDueHistory;
  if (nextRevisionDue != null) values['next_revision_due'] = nextRevisionDue;
  if (timeBetweenRevisions != null) values['time_between_revisions'] = timeBetweenRevisions;
  if (averageTimesShownPerDay != null) values['average_times_shown_per_day'] = averageTimesShownPerDay;
  if (isEligible != null) values['is_eligible'] = isEligible;
  if (isModuleActive != null) values['is_module_active'] = isModuleActive;
  if (inCirculation != null) values['in_circulation'] = inCirculation;

  return await db.update(
    'user_question_answer_pairs',
    values,
    where: 'user_uuid = ? AND question_answer_reference = ?',
    whereArgs: [userUuid, questionAnswerReference],
  );
}

Future<Map<String, dynamic>?> getUserQuestionAnswerPairById(String userUuid, String questionAnswerReference) async {
  await verifyUserQuestionAnswerPairTable();

  final Database db = await getDatabase();
  final List<Map<String, dynamic>> maps = await db.query(
    'user_question_answer_pairs',
    where: 'user_uuid = ? AND question_answer_reference = ?',
    whereArgs: [userUuid, questionAnswerReference],
  );

  return maps.isEmpty ? null : maps.first;
}

Future<List<Map<String, dynamic>>> getUserQuestionAnswerPairsByUser(String userUuid) async {
  await verifyUserQuestionAnswerPairTable();

  final Database db = await getDatabase();
  return await db.query(
    'user_question_answer_pairs',
    where: 'user_uuid = ?',
    whereArgs: [userUuid],
  );
}

Future<List<Map<String, dynamic>>> getEligibleQuestions(String userUuid) async {
  await verifyUserQuestionAnswerPairTable();

  final Database db = await getDatabase();
  return await db.query(
    'user_question_answer_pairs',
    where: 'user_uuid = ? AND is_eligible = ? AND is_module_active = ?',
    whereArgs: [userUuid, true, true],
  );
}

Future<List<Map<String, dynamic>>> getQuestionsInCirculation(String userUuid) async {
  await verifyUserQuestionAnswerPairTable();

  final Database db = await getDatabase();
  return await db.query(
    'user_question_answer_pairs',
    where: 'user_uuid = ? AND in_circulation = ?',
    whereArgs: [userUuid, true],
  );
}

Future<List<Map<String, dynamic>>> getAllUserQuestionAnswerPairs() async {
  await verifyUserQuestionAnswerPairTable();

  final Database db = await getDatabase();
  return await db.query('user_question_answer_pairs');
}

Future<int> removeUserQuestionAnswerPair(String userUuid, String questionAnswerReference) async {
  await verifyUserQuestionAnswerPairTable();

  final Database db = await getDatabase();
  return await db.delete(
    'user_question_answer_pairs',
    where: 'user_uuid = ? AND question_answer_reference = ?',
    whereArgs: [userUuid, questionAnswerReference],
  );
}