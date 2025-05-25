import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';

// TODO Make this table (done)
// TODO update aggregator
// TODO SUPABASE table created [ ]
// TODO SUPABASE RLS 
// TODO UPdate outbound sync
// TODO update inbound sync
// TODO connect stat to stats page

Future<void> verifyUserStatsRevisionStreakSumTable(Database db) async {
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='user_stats_revision_streak_sum'"
  );

  if (tables.isEmpty) {
    await db.execute('''
      CREATE TABLE user_stats_revision_streak_sum (
        user_id TEXT NOT NULL,
        record_date TEXT NOT NULL,
        revision_streak_score INTEGER NOT NULL,
        question_count INTEGER NOT NULL,
        has_been_synced INTEGER DEFAULT 0,
        edits_are_synced INTEGER DEFAULT 0,
        last_modified_timestamp TEXT,
        PRIMARY KEY (user_id, record_date, revision_streak_score)
      )
    ''');
    QuizzerLogger.logSuccess('Created user_stats_revision_streak_sum table.');
  } else {
    final List<Map<String, dynamic>> columns = await db.rawQuery(
      "PRAGMA table_info(user_stats_revision_streak_sum)"
    );
    final Set<String> columnNames = columns.map((col) => col['name'] as String).toSet();
    if (!columnNames.contains('has_been_synced')) {
      QuizzerLogger.logMessage('Adding has_been_synced column to user_stats_revision_streak_sum table.');
      await db.execute('ALTER TABLE user_stats_revision_streak_sum ADD COLUMN has_been_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('edits_are_synced')) {
      QuizzerLogger.logMessage('Adding edits_are_synced column to user_stats_revision_streak_sum table.');
      await db.execute('ALTER TABLE user_stats_revision_streak_sum ADD COLUMN edits_are_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('last_modified_timestamp')) {
      QuizzerLogger.logMessage('Adding last_modified_timestamp column to user_stats_revision_streak_sum table.');
      await db.execute('ALTER TABLE user_stats_revision_streak_sum ADD COLUMN last_modified_timestamp TEXT');
    }
  }
}

/// Updates the revision streak sum stat for a user for today (YYYY-MM-DD).
Future<void> updateRevisionStreakSumStat(String userId, Database db) async {
  final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  final List<Map<String, dynamic>> result = await db.rawQuery(
    'SELECT revision_streak, COUNT(*) as count FROM user_question_answer_pairs WHERE user_uuid = ? GROUP BY revision_streak',
    [userId],
  );
  await verifyUserStatsRevisionStreakSumTable(db);
  await db.delete(
    'user_stats_revision_streak_sum',
    where: 'user_id = ? AND record_date = ?',
    whereArgs: [userId, today],
  );
  for (final row in result) {
    final int revisionStreak = row['revision_streak'] as int;
    final int count = row['count'] as int;
    final Map<String, dynamic> data = {
      'user_id': userId,
      'record_date': today,
      'revision_streak_score': revisionStreak,
      'question_count': count,
      'has_been_synced': 0,
      'edits_are_synced': 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    await insertRawData('user_stats_revision_streak_sum', data, db);
  }
  QuizzerLogger.logSuccess('Updated revision streak sum stat for user $userId on $today');
}

Future<List<Map<String, dynamic>>> getUserStatsRevisionStreakSumRecordsByUser(String userId, Database db) async {
  await verifyUserStatsRevisionStreakSumTable(db);
  return await queryAndDecodeDatabase(
    'user_stats_revision_streak_sum',
    db,
    where: 'user_id = ?',
    whereArgs: [userId],
  );
}

Future<List<Map<String, dynamic>>> getUserStatsRevisionStreakSumRecordsByDate(String userId, String recordDate, Database db) async {
  await verifyUserStatsRevisionStreakSumTable(db);
  return await queryAndDecodeDatabase(
    'user_stats_revision_streak_sum',
    db,
    where: 'user_id = ? AND record_date = ?',
    whereArgs: [userId, recordDate],
  );
}

Future<List<Map<String, dynamic>>> getTodayUserStatsRevisionStreakSumRecords(String userId, Database db) async {
  final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  return await getUserStatsRevisionStreakSumRecordsByDate(userId, today, db);
}

Future<List<Map<String, dynamic>>> getUnsyncedUserStatsRevisionStreakSumRecords(Database db, String userId) async {
  QuizzerLogger.logMessage('Fetching unsynced revision streak sum records for user: $userId...');
  await verifyUserStatsRevisionStreakSumTable(db);
  final List<Map<String, dynamic>> results = await db.query(
    'user_stats_revision_streak_sum',
    where: '(has_been_synced = 0 OR edits_are_synced = 0) AND user_id = ?',
    whereArgs: [userId],
  );
  QuizzerLogger.logSuccess('Fetched ${results.length} unsynced revision streak sum records for user $userId.');
  return results;
}

Future<void> updateUserStatsRevisionStreakSumSyncFlags({
  required String userId,
  required String recordDate,
  required int revisionStreakScore,
  required bool hasBeenSynced,
  required bool editsAreSynced,
  required Database db,
}) async {
  QuizzerLogger.logMessage('Updating sync flags for revision streak sum record (User: $userId, Date: $recordDate, Streak: $revisionStreakScore) -> Synced: $hasBeenSynced, Edits Synced: $editsAreSynced');
  await verifyUserStatsRevisionStreakSumTable(db);
  final Map<String, dynamic> updates = {
    'has_been_synced': hasBeenSynced ? 1 : 0,
    'edits_are_synced': editsAreSynced ? 1 : 0,
    'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
  };
  final int rowsAffected = await updateRawData(
    'user_stats_revision_streak_sum',
    updates,
    'user_id = ? AND record_date = ? AND revision_streak_score = ?',
    [userId, recordDate, revisionStreakScore],
    db,
  );
  if (rowsAffected == 0) {
    QuizzerLogger.logWarning('updateUserStatsRevisionStreakSumSyncFlags affected 0 rows for revision streak sum record (User: $userId, Date: $recordDate, Streak: $revisionStreakScore). Record might not exist?');
  } else {
    QuizzerLogger.logSuccess('Successfully updated sync flags for revision streak sum record (User: $userId, Date: $recordDate, Streak: $revisionStreakScore).');
  }
}

Future<void> upsertUserStatsRevisionStreakSumFromInboundSync(Map<String, dynamic> record, Database db) async {
  final String? userId = record['user_id'] as String?;
  final String? recordDate = record['record_date'] as String?;
  final int? revisionStreakScore = record['revision_streak_score'] as int?;
  final int? questionCount = record['question_count'] as int?;
  final String? lastModifiedTimestamp = record['last_modified_timestamp'] as String?;

  assert(userId != null, 'upsertUserStatsRevisionStreakSumFromInboundSync: user_id cannot be null. Data: $record');
  assert(recordDate != null, 'upsertUserStatsRevisionStreakSumFromInboundSync: record_date cannot be null. Data: $record');
  assert(revisionStreakScore != null, 'upsertUserStatsRevisionStreakSumFromInboundSync: revision_streak_score cannot be null. Data: $record');
  assert(questionCount != null, 'upsertUserStatsRevisionStreakSumFromInboundSync: question_count cannot be null. Data: $record');
  assert(lastModifiedTimestamp != null, 'upsertUserStatsRevisionStreakSumFromInboundSync: last_modified_timestamp cannot be null. Data: $record');

  await verifyUserStatsRevisionStreakSumTable(db);

  final Map<String, dynamic> dataToInsertOrUpdate = {
    'user_id': userId,
    'record_date': recordDate,
    'revision_streak_score': revisionStreakScore,
    'question_count': questionCount,
    'has_been_synced': 1,
    'edits_are_synced': 1,
    'last_modified_timestamp': lastModifiedTimestamp,
  };

  final int rowId = await insertRawData(
    'user_stats_revision_streak_sum',
    dataToInsertOrUpdate,
    db,
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  if (rowId > 0) {
    QuizzerLogger.logSuccess('Successfully upserted user_stats_revision_streak_sum for user $userId, date $recordDate, streak $revisionStreakScore from inbound sync.');
  } else {
    QuizzerLogger.logWarning('upsertUserStatsRevisionStreakSumFromInboundSync: insertRawData with replace returned 0 for user $userId, date $recordDate, streak $revisionStreakScore. Data: $dataToInsertOrUpdate');
  }
}
