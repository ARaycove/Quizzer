// 9. reserve_questions_exhaust_in_x_days (single stat)
// - calculated by taking current non_circulating_questions (whose modules are active) and the average_num_questions_entering_circulation_daily
// - divide current non_circulating_questions / average_num_questions_entering_circulation_daily
// TODO update stats page to display this statistic

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_non_circulating_questions_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_in_circulation_questions_table.dart';

Future<void> verifyUserStatsDaysLeftUntilQuestionsExhaustTable(Database db) async {
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='user_stats_days_left_until_questions_exhaust'"
  );

  if (tables.isEmpty) {
    await db.execute('''
      CREATE TABLE user_stats_days_left_until_questions_exhaust (
        user_id TEXT NOT NULL,
        record_date TEXT NOT NULL,
        days_left_until_questions_exhaust REAL NOT NULL,
        has_been_synced INTEGER DEFAULT 0,
        edits_are_synced INTEGER DEFAULT 0,
        last_modified_timestamp TEXT,
        PRIMARY KEY (user_id, record_date)
      )
    ''');
    QuizzerLogger.logSuccess('Created user_stats_days_left_until_questions_exhaust table.');
  } else {
    final List<Map<String, dynamic>> columns = await db.rawQuery(
      "PRAGMA table_info(user_stats_days_left_until_questions_exhaust)"
    );
    final Set<String> columnNames = columns.map((col) => col['name'] as String).toSet();
    if (!columnNames.contains('has_been_synced')) {
      QuizzerLogger.logMessage('Adding has_been_synced column to user_stats_days_left_until_questions_exhaust table.');
      await db.execute('ALTER TABLE user_stats_days_left_until_questions_exhaust ADD COLUMN has_been_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('edits_are_synced')) {
      QuizzerLogger.logMessage('Adding edits_are_synced column to user_stats_days_left_until_questions_exhaust table.');
      await db.execute('ALTER TABLE user_stats_days_left_until_questions_exhaust ADD COLUMN edits_are_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('last_modified_timestamp')) {
      QuizzerLogger.logMessage('Adding last_modified_timestamp column to user_stats_days_left_until_questions_exhaust table.');
      await db.execute('ALTER TABLE user_stats_days_left_until_questions_exhaust ADD COLUMN last_modified_timestamp TEXT');
    }
  }
}

/// Updates the days_left_until_questions_exhaust stat for a user for today (YYYY-MM-DD).
/// This is calculated as:
///   current non_circulating_questions (whose modules are active)
///   divided by the average number of questions entering circulation daily (over a period, e.g., 365 days)
Future<void> updateDaysLeftUntilQuestionsExhaustStat(String userId, Database db, {int periodDays = 365}) async {
  final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);

  // Fetch today's non_circulating_questions_count from the stat table
  int nonCirculatingCount = 0;

  final Map<String, dynamic> nonCircStat = await getUserStatsNonCirculatingQuestionsRecordByDate(userId, today, db);
  nonCirculatingCount = nonCircStat['non_circulating_questions_count'] as int? ?? 0;

  QuizzerLogger.logWarning('No non_circulating stat found for user $userId on $today, defaulting to 0.');
  nonCirculatingCount = 0;

  // Get historical in_circulation questions stat records (sorted by date asc)
  final List<Map<String, dynamic>> inCircHistory = await getUserStatsInCirculationQuestionsRecordsByUser(userId, db);
  if (inCircHistory.isEmpty) {
    QuizzerLogger.logWarning('No in_circulation history found for user $userId, cannot calculate average.');
    return;
  }
  inCircHistory.sort((a, b) => (a['record_date'] as String).compareTo(b['record_date'] as String));

  // Only consider the last [periodDays] days
  final List<Map<String, dynamic>> periodHistory = inCircHistory.length > periodDays
      ? inCircHistory.sublist(inCircHistory.length - periodDays)
      : inCircHistory;

  // Calculate average daily increase in in_circulation questions
  double avgDailyIncrease = 0.0;
  if (periodHistory.length > 1) {
    final int start = periodHistory.first['in_circulation_questions_count'] as int? ?? 0;
    final int end = periodHistory.last['in_circulation_questions_count'] as int? ?? 0;
    final int days = periodHistory.length - 1;
    avgDailyIncrease = days > 0 ? (end - start) / days : 0.0;
  }

  // Avoid division by zero
  double daysLeft = 0.0;
  if (avgDailyIncrease > 0) {
    daysLeft = nonCirculatingCount / avgDailyIncrease;
  }

  await verifyUserStatsDaysLeftUntilQuestionsExhaustTable(db);

  // Overwrite (insert or update) the record for today
  final List<Map<String, dynamic>> existing = await queryAndDecodeDatabase(
    'user_stats_days_left_until_questions_exhaust',
    db,
    where: 'user_id = ? AND record_date = ?',
    whereArgs: [userId, today],
  );
  if (existing.isEmpty) {
    final Map<String, dynamic> data = {
      'user_id': userId,
      'record_date': today,
      'days_left_until_questions_exhaust': daysLeft,
      'has_been_synced': 0,
      'edits_are_synced': 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    await insertRawData('user_stats_days_left_until_questions_exhaust', data, db);
  } else {
    final Map<String, dynamic> values = {
      'days_left_until_questions_exhaust': daysLeft,
      'has_been_synced': 0,
      'edits_are_synced': 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    await updateRawData(
      'user_stats_days_left_until_questions_exhaust',
      values,
      'user_id = ? AND record_date = ?',
      [userId, today],
      db,
    );
  }
  QuizzerLogger.logSuccess('Updated days_left_until_questions_exhaust stat for user $userId on $today: $daysLeft');
}

Future<List<Map<String, dynamic>>> getUserStatsDaysLeftUntilQuestionsExhaustRecordsByUser(String userId, Database db) async {
  await verifyUserStatsDaysLeftUntilQuestionsExhaustTable(db);
  return await queryAndDecodeDatabase(
    'user_stats_days_left_until_questions_exhaust',
    db,
    where: 'user_id = ?',
    whereArgs: [userId],
  );
}

Future<Map<String, dynamic>> getUserStatsDaysLeftUntilQuestionsExhaustRecordByDate(String userId, String recordDate, Database db) async {
  await verifyUserStatsDaysLeftUntilQuestionsExhaustTable(db);
  final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
    'user_stats_days_left_until_questions_exhaust',
    db,
    where: 'user_id = ? AND record_date = ?',
    whereArgs: [userId, recordDate],
    limit: 2,
  );
  if (results.isEmpty) {
    QuizzerLogger.logMessage('No days_left_until_questions_exhaust record found for userId: $userId and date: $recordDate.');
    throw StateError('No record found for user $userId, date $recordDate');
  } else if (results.length > 1) {
    QuizzerLogger.logError('Multiple records found for userId: $userId and date: $recordDate. PK constraint violation?');
    throw StateError('Multiple records for PK user $userId, date $recordDate');
  }
  QuizzerLogger.logSuccess('Fetched days_left_until_questions_exhaust record for User: $userId, Date: $recordDate');
  return results.first;
}

Future<Map<String, dynamic>> getTodayUserStatsDaysLeftUntilQuestionsExhaustRecord(String userId, Database db) async {
  final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  return await getUserStatsDaysLeftUntilQuestionsExhaustRecordByDate(userId, today, db);
}

Future<List<Map<String, dynamic>>> getUnsyncedUserStatsDaysLeftUntilQuestionsExhaustRecords(Database db, String userId) async {
  QuizzerLogger.logMessage('Fetching unsynced days_left_until_questions_exhaust records for user: $userId...');
  await verifyUserStatsDaysLeftUntilQuestionsExhaustTable(db);
  final List<Map<String, dynamic>> results = await db.query(
    'user_stats_days_left_until_questions_exhaust',
    where: '(has_been_synced = 0 OR edits_are_synced = 0) AND user_id = ?',
    whereArgs: [userId],
  );
  QuizzerLogger.logSuccess('Fetched [38;5;10m${results.length}[0m unsynced days_left_until_questions_exhaust records for user $userId.');
  return results;
}

Future<void> updateUserStatsDaysLeftUntilQuestionsExhaustSyncFlags({
  required String userId,
  required String recordDate,
  required bool hasBeenSynced,
  required bool editsAreSynced,
  required Database db,
}) async {
  QuizzerLogger.logMessage('Updating sync flags for days_left_until_questions_exhaust record (User: $userId, Date: $recordDate) -> Synced: $hasBeenSynced, Edits Synced: $editsAreSynced');
  await verifyUserStatsDaysLeftUntilQuestionsExhaustTable(db);
  final Map<String, dynamic> updates = {
    'has_been_synced': hasBeenSynced ? 1 : 0,
    'edits_are_synced': editsAreSynced ? 1 : 0,
    'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
  };
  final int rowsAffected = await updateRawData(
    'user_stats_days_left_until_questions_exhaust',
    updates,
    'user_id = ? AND record_date = ?',
    [userId, recordDate],
    db,
  );
  if (rowsAffected == 0) {
    QuizzerLogger.logWarning('updateUserStatsDaysLeftUntilQuestionsExhaustSyncFlags affected 0 rows for days_left_until_questions_exhaust record (User: $userId, Date: $recordDate). Record might not exist?');
  } else {
    QuizzerLogger.logSuccess('Successfully updated sync flags for days_left_until_questions_exhaust record (User: $userId, Date: $recordDate).');
  }
}

Future<void> upsertUserStatsDaysLeftUntilQuestionsExhaustFromInboundSync(Map<String, dynamic> record, Database db) async {
  final String? userId = record['user_id'] as String?;
  final String? recordDate = record['record_date'] as String?;
  final double? daysLeft = record['days_left_until_questions_exhaust'] is int
      ? (record['days_left_until_questions_exhaust'] as int).toDouble()
      : record['days_left_until_questions_exhaust'] as double?;
  final String? lastModifiedTimestamp = record['last_modified_timestamp'] as String?;

  assert(userId != null, 'upsertUserStatsDaysLeftUntilQuestionsExhaustFromInboundSync: user_id cannot be null. Data: $record');
  assert(recordDate != null, 'upsertUserStatsDaysLeftUntilQuestionsExhaustFromInboundSync: record_date cannot be null. Data: $record');
  assert(daysLeft != null, 'upsertUserStatsDaysLeftUntilQuestionsExhaustFromInboundSync: days_left_until_questions_exhaust cannot be null. Data: $record');
  assert(lastModifiedTimestamp != null, 'upsertUserStatsDaysLeftUntilQuestionsExhaustFromInboundSync: last_modified_timestamp cannot be null. Data: $record');

  await verifyUserStatsDaysLeftUntilQuestionsExhaustTable(db);

  final Map<String, dynamic> dataToInsertOrUpdate = {
    'user_id': userId,
    'record_date': recordDate,
    'days_left_until_questions_exhaust': daysLeft,
    'has_been_synced': 1,
    'edits_are_synced': 1,
    'last_modified_timestamp': lastModifiedTimestamp,
  };

  final int rowId = await insertRawData(
    'user_stats_days_left_until_questions_exhaust',
    dataToInsertOrUpdate,
    db,
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  if (rowId > 0) {
    QuizzerLogger.logSuccess('Successfully upserted user_stats_days_left_until_questions_exhaust for user $userId, date $recordDate from inbound sync.');
  } else {
    QuizzerLogger.logWarning('upsertUserStatsDaysLeftUntilQuestionsExhaustFromInboundSync: insertRawData with replace returned 0 for user $userId, date $recordDate. Data: $dataToInsertOrUpdate');
  }
}