// 5. total_questions_in_database (by date, get the total number of user_question_answer_pairs that have at least one attempt on them)
// TODO Make this table
// TODO update aggregator
// TODO SUPABASE table created
// TODO SUPABASE RLS 
// TODO UPdate outbound sync
// TODO update inbound sync
// TODO connect stat to stats page

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';

Future<void> verifyUserStatsTotalUserQuestionAnswerPairsTable(Database db) async {
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='user_stats_total_user_question_answer_pairs'"
  );

  if (tables.isEmpty) {
    await db.execute('''
      CREATE TABLE user_stats_total_user_question_answer_pairs (
        user_id TEXT NOT NULL,
        record_date TEXT NOT NULL,
        total_question_answer_pairs INTEGER NOT NULL,
        has_been_synced INTEGER DEFAULT 0,
        edits_are_synced INTEGER DEFAULT 0,
        last_modified_timestamp TEXT,
        PRIMARY KEY (user_id, record_date)
      )
    ''');
    QuizzerLogger.logSuccess('Created user_stats_total_user_question_answer_pairs table.');
  } else {
    final List<Map<String, dynamic>> columns = await db.rawQuery(
      "PRAGMA table_info(user_stats_total_user_question_answer_pairs)"
    );
    final Set<String> columnNames = columns.map((col) => col['name'] as String).toSet();
    if (!columnNames.contains('has_been_synced')) {
      QuizzerLogger.logMessage('Adding has_been_synced column to user_stats_total_user_question_answer_pairs table.');
      await db.execute('ALTER TABLE user_stats_total_user_question_answer_pairs ADD COLUMN has_been_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('edits_are_synced')) {
      QuizzerLogger.logMessage('Adding edits_are_synced column to user_stats_total_user_question_answer_pairs table.');
      await db.execute('ALTER TABLE user_stats_total_user_question_answer_pairs ADD COLUMN edits_are_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('last_modified_timestamp')) {
      QuizzerLogger.logMessage('Adding last_modified_timestamp column to user_stats_total_user_question_answer_pairs table.');
      await db.execute('ALTER TABLE user_stats_total_user_question_answer_pairs ADD COLUMN last_modified_timestamp TEXT');
    }
  }
}

/// Updates the total user question answer pairs stat for a user for today (YYYY-MM-DD).
Future<void> updateTotalUserQuestionAnswerPairsStat(String userId, Database db) async {
  final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  final List<Map<String, dynamic>> result = await db.rawQuery(
    'SELECT COUNT(*) as count FROM user_question_answer_pairs WHERE user_uuid = ?',
    [userId],
  );
  final int totalCount = result.isNotEmpty ? (result.first['count'] as int) : 0;
  await verifyUserStatsTotalUserQuestionAnswerPairsTable(db);
  final List<Map<String, dynamic>> existing = await queryAndDecodeDatabase(
    'user_stats_total_user_question_answer_pairs',
    db,
    where: 'user_id = ? AND record_date = ?',
    whereArgs: [userId, today],
  );
  if (existing.isEmpty) {
    final Map<String, dynamic> data = {
      'user_id': userId,
      'record_date': today,
      'total_question_answer_pairs': totalCount,
      'has_been_synced': 0,
      'edits_are_synced': 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    await insertRawData('user_stats_total_user_question_answer_pairs', data, db);
  } else {
    final Map<String, dynamic> values = {
      'total_question_answer_pairs': totalCount,
      'has_been_synced': 0,
      'edits_are_synced': 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    await updateRawData(
      'user_stats_total_user_question_answer_pairs',
      values,
      'user_id = ? AND record_date = ?',
      [userId, today],
      db,
    );
  }
  QuizzerLogger.logSuccess('Updated total user question answer pairs stat for user $userId on $today: $totalCount');
}

Future<List<Map<String, dynamic>>> getUserStatsTotalUserQuestionAnswerPairsRecordsByUser(String userId, Database db) async {
  await verifyUserStatsTotalUserQuestionAnswerPairsTable(db);
  return await queryAndDecodeDatabase(
    'user_stats_total_user_question_answer_pairs',
    db,
    where: 'user_id = ?',
    whereArgs: [userId],
  );
}

Future<Map<String, dynamic>> getUserStatsTotalUserQuestionAnswerPairsRecordByDate(String userId, String recordDate, Database db) async {
  await verifyUserStatsTotalUserQuestionAnswerPairsTable(db);
  final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
    'user_stats_total_user_question_answer_pairs',
    db,
    where: 'user_id = ? AND record_date = ?',
    whereArgs: [userId, recordDate],
    limit: 2,
  );
  if (results.isEmpty) {
    QuizzerLogger.logMessage('No total user question answer pairs record found for userId: $userId and date: $recordDate.');
    throw StateError('No record found for user $userId, date $recordDate');
  } else if (results.length > 1) {
    QuizzerLogger.logError('Multiple records found for userId: $userId and date: $recordDate. PK constraint violation?');
    throw StateError('Multiple records for PK user $userId, date $recordDate');
  }
  QuizzerLogger.logSuccess('Fetched total user question answer pairs record for User: $userId, Date: $recordDate');
  return results.first;
}

Future<Map<String, dynamic>> getTodayUserStatsTotalUserQuestionAnswerPairsRecord(String userId, Database db) async {
  final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  return await getUserStatsTotalUserQuestionAnswerPairsRecordByDate(userId, today, db);
}

Future<List<Map<String, dynamic>>> getUnsyncedUserStatsTotalUserQuestionAnswerPairsRecords(Database db, String userId) async {
  QuizzerLogger.logMessage('Fetching unsynced total user question answer pairs records for user: $userId...');
  await verifyUserStatsTotalUserQuestionAnswerPairsTable(db);
  final List<Map<String, dynamic>> results = await db.query(
    'user_stats_total_user_question_answer_pairs',
    where: '(has_been_synced = 0 OR edits_are_synced = 0) AND user_id = ?',
    whereArgs: [userId],
  );
  QuizzerLogger.logSuccess('Fetched ${results.length} unsynced total user question answer pairs records for user $userId.');
  return results;
}

Future<void> updateUserStatsTotalUserQuestionAnswerPairsSyncFlags({
  required String userId,
  required String recordDate,
  required bool hasBeenSynced,
  required bool editsAreSynced,
  required Database db,
}) async {
  QuizzerLogger.logMessage('Updating sync flags for total user question answer pairs record (User: $userId, Date: $recordDate) -> Synced: $hasBeenSynced, Edits Synced: $editsAreSynced');
  await verifyUserStatsTotalUserQuestionAnswerPairsTable(db);
  final Map<String, dynamic> updates = {
    'has_been_synced': hasBeenSynced ? 1 : 0,
    'edits_are_synced': editsAreSynced ? 1 : 0,
    'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
  };
  final int rowsAffected = await updateRawData(
    'user_stats_total_user_question_answer_pairs',
    updates,
    'user_id = ? AND record_date = ?',
    [userId, recordDate],
    db,
  );
  if (rowsAffected == 0) {
    QuizzerLogger.logWarning('updateUserStatsTotalUserQuestionAnswerPairsSyncFlags affected 0 rows for total user question answer pairs record (User: $userId, Date: $recordDate). Record might not exist?');
  } else {
    QuizzerLogger.logSuccess('Successfully updated sync flags for total user question answer pairs record (User: $userId, Date: $recordDate).');
  }
}

Future<void> upsertUserStatsTotalUserQuestionAnswerPairsFromInboundSync(Map<String, dynamic> record, Database db) async {
  final String? userId = record['user_id'] as String?;
  final String? recordDate = record['record_date'] as String?;
  final int? totalCount = record['total_question_answer_pairs'] as int?;
  final String? lastModifiedTimestamp = record['last_modified_timestamp'] as String?;

  assert(userId != null, 'upsertUserStatsTotalUserQuestionAnswerPairsFromInboundSync: user_id cannot be null. Data: $record');
  assert(recordDate != null, 'upsertUserStatsTotalUserQuestionAnswerPairsFromInboundSync: record_date cannot be null. Data: $record');
  assert(totalCount != null, 'upsertUserStatsTotalUserQuestionAnswerPairsFromInboundSync: total_question_answer_pairs cannot be null. Data: $record');
  assert(lastModifiedTimestamp != null, 'upsertUserStatsTotalUserQuestionAnswerPairsFromInboundSync: last_modified_timestamp cannot be null. Data: $record');

  await verifyUserStatsTotalUserQuestionAnswerPairsTable(db);

  final Map<String, dynamic> dataToInsertOrUpdate = {
    'user_id': userId,
    'record_date': recordDate,
    'total_question_answer_pairs': totalCount,
    'has_been_synced': 1,
    'edits_are_synced': 1,
    'last_modified_timestamp': lastModifiedTimestamp,
  };

  final int rowId = await insertRawData(
    'user_stats_total_user_question_answer_pairs',
    dataToInsertOrUpdate,
    db,
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  if (rowId > 0) {
    QuizzerLogger.logSuccess('Successfully upserted user_stats_total_user_question_answer_pairs for user $userId, date $recordDate from inbound sync.');
  } else {
    QuizzerLogger.logWarning('upsertUserStatsTotalUserQuestionAnswerPairsFromInboundSync: insertRawData with replace returned 0 for user $userId, date $recordDate. Data: $dataToInsertOrUpdate');
  }
}