import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

Future<void> verifyUserQuestionAnswerPairTable(Database db) async {
  
  // Check if the table exists
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='user_question_answer_pairs'"
  );
  
  if (tables.isEmpty) {
    await db.execute('''
      CREATE TABLE user_question_answer_pairs (
        user_uuid TEXT,
        question_id TEXT,
        revision_streak INTEGER,
        last_revised TEXT,
        predicted_revision_due_history TEXT,
        next_revision_due TEXT,
        time_between_revisions REAL,
        average_times_shown_per_day REAL,
        is_eligible INTEGER,
        in_circulation INTEGER,
        last_updated TEXT,
        total_attempts INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (user_uuid, question_id)
      )
    ''');
  } else {
    // Table exists, check columns
    final List<Map<String, dynamic>> columns = await db.rawQuery(
      "PRAGMA table_info(user_question_answer_pairs)"
    );
    final Set<String> columnNames = columns.map((col) => col['name'] as String).toSet();

    // Check for last_updated (existing check)
    if (!columnNames.contains('last_updated')) {
      QuizzerLogger.logWarning('Adding missing column: last_updated');
      await db.execute(
        "ALTER TABLE user_question_answer_pairs ADD COLUMN last_updated TEXT"
      );
    }
    // Check for total_attempts (new check)
    if (!columnNames.contains('total_attempts')) {
       QuizzerLogger.logWarning('Adding missing column: total_attempts');
      // Add with default 0 for existing rows
      await db.execute("ALTER TABLE user_question_answer_pairs ADD COLUMN total_attempts INTEGER NOT NULL DEFAULT 0");
    }
  }
}

Future<int> addUserQuestionAnswerPair({
  required String userUuid,
  required String questionAnswerReference,
  required int revisionStreak,
  required String? lastRevised,
  required String predictedRevisionDueHistory,
  required String nextRevisionDue,
  required double timeBetweenRevisions,
  required double averageTimesShownPerDay,
  required bool inCirculation,
  required Database db,
}) async {
  await verifyUserQuestionAnswerPairTable(db);

  return await db.insert('user_question_answer_pairs', {
    'user_uuid': userUuid,
    'question_id': questionAnswerReference,
    'revision_streak': revisionStreak,
    'last_revised': lastRevised,
    'predicted_revision_due_history': predictedRevisionDueHistory,
    'next_revision_due': nextRevisionDue,
    'time_between_revisions': timeBetweenRevisions,
    'average_times_shown_per_day': averageTimesShownPerDay,
    'in_circulation': inCirculation ? 1 : 0,
  });
}

Future<int> editUserQuestionAnswerPair({
  required String userUuid,
  required String questionId,
  required Database db,
  int? revisionStreak,
  String? lastRevised,
  String? predictedRevisionDueHistory,
  String? nextRevisionDue,
  double? timeBetweenRevisions,
  double? averageTimesShownPerDay,
  bool? isEligible,
  bool? inCirculation,
  String? lastUpdated,
}) async {
  await verifyUserQuestionAnswerPairTable(db);

  Map<String, dynamic> values = {};
  
  if (revisionStreak != null) values['revision_streak'] = revisionStreak;
  if (lastRevised != null) values['last_revised'] = lastRevised;
  if (predictedRevisionDueHistory != null) values['predicted_revision_due_history'] = predictedRevisionDueHistory;
  if (nextRevisionDue != null) values['next_revision_due'] = nextRevisionDue;
  if (timeBetweenRevisions != null) values['time_between_revisions'] = timeBetweenRevisions;
  if (averageTimesShownPerDay != null) values['average_times_shown_per_day'] = averageTimesShownPerDay;
  if (isEligible != null) values['is_eligible'] = isEligible ? 1 : 0;
  if (inCirculation != null) values['in_circulation'] = inCirculation ? 1 : 0;
  if (lastUpdated != null) values['last_updated'] = lastUpdated;

  return await db.update(
    'user_question_answer_pairs',
    values,
    where: 'user_uuid = ? AND question_id = ?',
    whereArgs: [userUuid, questionId],
  );
}

Future<Map<String, dynamic>> getUserQuestionAnswerPairById(String userUuid, String questionId, Database db) async {
  await verifyUserQuestionAnswerPairTable(db);
  
  final List<Map<String, dynamic>> result = await db.query(
    'user_question_answer_pairs',
    where: 'user_uuid = ? AND question_id = ?',
    whereArgs: [userUuid, questionId],
  );
  
  // Check if the result is empty
  if (result.isEmpty) {
    // Throw an exception if no record is found for the given IDs
    throw ArgumentError(
        'No user question answer pair found for userUuid: $userUuid and questionAnswerReference: $questionId. Invalid IDs provided.');
  }
  
  // Return the first record if found
  return result.first;
}

Future<List<Map<String, dynamic>>> getUserQuestionAnswerPairsByUser(String userUuid, Database db) async {
  await verifyUserQuestionAnswerPairTable(db);
  return await db.query(
    'user_question_answer_pairs',
    where: 'user_uuid = ?',
    whereArgs: [userUuid],
  );
}

Future<List<Map<String, dynamic>>> getQuestionsInCirculation(String userUuid, Database db) async {
  await verifyUserQuestionAnswerPairTable(db);

  return await db.query(
    'user_question_answer_pairs',
    where: 'user_uuid = ? AND in_circulation = ?',
    whereArgs: [userUuid, 1],
  );
}

Future<List<Map<String, dynamic>>> getAllUserQuestionAnswerPairs(Database db, String userUuid) async {
  await verifyUserQuestionAnswerPairTable(db);

  return await db.query(
      'user_question_answer_pairs',
      where: 'user_uuid = ?',
      whereArgs: [userUuid]
  );
}

Future<int> removeUserQuestionAnswerPair(String userUuid, String questionAnswerReference, Database db) async {
  await verifyUserQuestionAnswerPairTable(db);

  return await db.delete(
    'user_question_answer_pairs',
    where: 'user_uuid = ? AND question_id = ?',
    whereArgs: [userUuid, questionAnswerReference],
  );
}

// --- Helper Functions ---

/// Increments the total_attempts count for a specific user-question pair.
Future<void> incrementTotalAttempts(String userUuid, String questionId, Database db) async {
  QuizzerLogger.logMessage('Incrementing total attempts for User: $userUuid, Question: $questionId');
  
  // Ensure the table and column exist before attempting update
  await verifyUserQuestionAnswerPairTable(db);

  final int rowsAffected = await db.rawUpdate(
    'UPDATE user_question_answer_pairs SET total_attempts = total_attempts + 1 WHERE user_uuid = ? AND question_id = ?',
    [userUuid, questionId]
  );

  if (rowsAffected == 0) {
    QuizzerLogger.logWarning('Failed to increment total attempts: No matching record found for User: $userUuid, Question: $questionId');
    // Depending on desired behavior, could throw an exception here if the record *should* exist.
  } else {
    QuizzerLogger.logSuccess('Successfully incremented total attempts for User: $userUuid, Question: $questionId');
  }
}