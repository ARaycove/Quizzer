// 10. average_num_questions_entering_circulation_daily
// - Need to analyze the historical record of total_in_circulation_questions and look at average increase over a one year cycle

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_in_circulation_questions_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

/// Verifies the user_stats_average_daily_questions_learned table exists, creates if not.
Future<void> _verifyUserStatsAverageDailyQuestionsLearnedTable(Database db) async {
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='user_stats_average_daily_questions_learned'"
  );

  if (tables.isEmpty) {
    await db.execute('''
      CREATE TABLE user_stats_average_daily_questions_learned (
        user_id TEXT NOT NULL,
        record_date TEXT NOT NULL,
        average_daily_questions_learned REAL NOT NULL,
        has_been_synced INTEGER DEFAULT 0,
        edits_are_synced INTEGER DEFAULT 0,
        last_modified_timestamp TEXT,
        PRIMARY KEY (user_id, record_date)
      )
    ''');
    QuizzerLogger.logSuccess('Created user_stats_average_daily_questions_learned table.');
  } else {
    final List<Map<String, dynamic>> columns = await db.rawQuery(
      "PRAGMA table_info(user_stats_average_daily_questions_learned)"
    );
    final Set<String> columnNames = columns.map((col) => col['name'] as String).toSet();
    if (!columnNames.contains('has_been_synced')) {
      QuizzerLogger.logMessage('Adding has_been_synced column to user_stats_average_daily_questions_learned table.');
      await db.execute('ALTER TABLE user_stats_average_daily_questions_learned ADD COLUMN has_been_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('edits_are_synced')) {
      QuizzerLogger.logMessage('Adding edits_are_synced column to user_stats_average_daily_questions_learned table.');
      await db.execute('ALTER TABLE user_stats_average_daily_questions_learned ADD COLUMN edits_are_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('last_modified_timestamp')) {
      QuizzerLogger.logMessage('Adding last_modified_timestamp column to user_stats_average_daily_questions_learned table.');
      await db.execute('ALTER TABLE user_stats_average_daily_questions_learned ADD COLUMN last_modified_timestamp TEXT');
    }
  }
}

/// Updates the average_daily_questions_learned stat for a user for today (YYYY-MM-DD).
/// This is calculated as:
///   (increase in active in_circulation questions over time period) / (number of days in that period)
Future<void> updateAverageDailyQuestionsLearnedStat(String userId) async {
  try {
    // Get historical data BEFORE requesting database access
    final List<Map<String, dynamic>> inCircHistory = await getUserStatsInCirculationQuestionsRecordsByUser(userId);
    
    if (inCircHistory.length < 2) {
      // Not enough data to calculate increase
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      await _verifyUserStatsAverageDailyQuestionsLearnedTable(db!);
      
      final Map<String, dynamic> data = {
        'user_id': userId,
        'record_date': today,
        'average_daily_questions_learned': 0.0,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      await insertRawData('user_stats_average_daily_questions_learned', data, db, conflictAlgorithm: ConflictAlgorithm.replace);
      QuizzerLogger.logSuccess('Updated average_daily_questions_learned stat for user $userId on $today: 0.0 (not enough data)');
      return;
    }
    
    // Sort by date to get oldest and newest records
    inCircHistory.sort((a, b) => (a['record_date'] as String).compareTo(b['record_date'] as String));
    final String firstDate = inCircHistory.first['record_date'] as String;
    final String lastDate = inCircHistory.last['record_date'] as String;
    final int days = DateTime.parse(lastDate).difference(DateTime.parse(firstDate)).inDays + 1;
    
    // Determine starting count based on time period
    int firstCount;
    if (days < 365) {
      // Less than a year: assume starting from 0
      firstCount = 0;
    } else {
      // Full year or more: use actual first count
      firstCount = inCircHistory.first['in_circulation_questions_count'] as int? ?? 0;
    }
    
    final int lastCount = inCircHistory.last['in_circulation_questions_count'] as int? ?? 0;
    
    // Calculate the increase and time period
    final int increase = lastCount - firstCount;
    
    // Calculate average learning rate: increase / days
    final double avgLearned = days > 0 ? (increase / days) : 0.0;
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    await _verifyUserStatsAverageDailyQuestionsLearnedTable(db!);

    // Overwrite (insert or update) the record for today
    final Map<String, dynamic> data = {
      'user_id': userId,
      'record_date': today,
      'average_daily_questions_learned': avgLearned,
      'has_been_synced': 0,
      'edits_are_synced': 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    await insertRawData('user_stats_average_daily_questions_learned', data, db, conflictAlgorithm: ConflictAlgorithm.replace);
    
    // Update SessionManager cache with the current value
    final SessionManager sessionManager = SessionManager();
    sessionManager.setCachedAverageDailyQuestionsLearned(double.parse(avgLearned.toStringAsFixed(2)));
    
    QuizzerLogger.logSuccess('Updated average_daily_questions_learned stat for user $userId on $today: $avgLearned (increase: $increase, days: $days, first: $firstCount, last: $lastCount)');
  } catch (e) {
    QuizzerLogger.logError('Error updating average daily questions learned stat for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<List<Map<String, dynamic>>> getUserStatsAverageDailyQuestionsLearnedRecordsByUser(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await _verifyUserStatsAverageDailyQuestionsLearnedTable(db!);
    return await queryAndDecodeDatabase(
      'user_stats_average_daily_questions_learned',
      db,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  } catch (e) {
    QuizzerLogger.logError('Error getting average daily questions learned records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<Map<String, dynamic>> getUserStatsAverageDailyQuestionsLearnedRecordByDate(String userId, String recordDate) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await _verifyUserStatsAverageDailyQuestionsLearnedTable(db!);
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'user_stats_average_daily_questions_learned',
      db,
      where: 'user_id = ? AND record_date = ?',
      whereArgs: [userId, recordDate],
      limit: 2,
    );
    if (results.isEmpty) {
      QuizzerLogger.logMessage('No average_daily_questions_learned record found for userId: $userId and date: $recordDate.');
      throw StateError('No record found for user $userId, date $recordDate');
    } else if (results.length > 1) {
      QuizzerLogger.logError('Multiple records found for userId: $userId and date: $recordDate. PK constraint violation?');
      throw StateError('Multiple records for PK user $userId, date $recordDate');
    }
    QuizzerLogger.logSuccess('Fetched average_daily_questions_learned record for User: $userId, Date: $recordDate');
    return results.first;
  } catch (e) {
    QuizzerLogger.logError('Error getting average daily questions learned record for user ID: $userId, date: $recordDate - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<Map<String, dynamic>> getTodayUserStatsAverageDailyQuestionsLearnedRecord(String userId) async {
  try {
    final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    return await getUserStatsAverageDailyQuestionsLearnedRecordByDate(userId, today);
  } catch (e) {
    QuizzerLogger.logError('Error getting today\'s average daily questions learned record for user ID: $userId - $e');
    rethrow;
  }
}

Future<List<Map<String, dynamic>>> getUnsyncedUserStatsAverageDailyQuestionsLearnedRecords(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    QuizzerLogger.logMessage('Fetching unsynced average_daily_questions_learned records for user: $userId...');
    await _verifyUserStatsAverageDailyQuestionsLearnedTable(db!);
    final List<Map<String, dynamic>> results = await db.query(
      'user_stats_average_daily_questions_learned',
      where: '(has_been_synced = 0 OR edits_are_synced = 0) AND user_id = ?',
      whereArgs: [userId],
    );
    QuizzerLogger.logSuccess('Fetched [38;5;10m${results.length}[0m unsynced average_daily_questions_learned records for user $userId.');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced average daily questions learned records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<void> updateUserStatsAverageDailyQuestionsLearnedSyncFlags({
  required String userId,
  required String recordDate,
  required bool hasBeenSynced,
  required bool editsAreSynced,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    QuizzerLogger.logMessage('Updating sync flags for average_daily_questions_learned record (User: $userId, Date: $recordDate) -> Synced: $hasBeenSynced, Edits Synced: $editsAreSynced');
    await _verifyUserStatsAverageDailyQuestionsLearnedTable(db!);
    final Map<String, dynamic> updates = {
      'has_been_synced': hasBeenSynced ? 1 : 0,
      'edits_are_synced': editsAreSynced ? 1 : 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    final int rowsAffected = await updateRawData(
      'user_stats_average_daily_questions_learned',
      updates,
      'user_id = ? AND record_date = ?',
      [userId, recordDate],
      db,
    );
    if (rowsAffected == 0) {
      QuizzerLogger.logWarning('updateUserStatsAverageDailyQuestionsLearnedSyncFlags affected 0 rows for average_daily_questions_learned record (User: $userId, Date: $recordDate). Record might not exist?');
    } else {
      QuizzerLogger.logSuccess('Successfully updated sync flags for average_daily_questions_learned record (User: $userId, Date: $recordDate).');
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating sync flags for average daily questions learned record (User: $userId, Date: $recordDate) - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<void> upsertUserStatsAverageDailyQuestionsLearnedFromInboundSync(Map<String, dynamic> record) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    final String? userId = record['user_id'] as String?;
    final String? recordDate = record['record_date'] as String?;
    final double? avgLearned = record['average_daily_questions_learned'] is int
        ? (record['average_daily_questions_learned'] as int).toDouble()
        : record['average_daily_questions_learned'] as double?;
    final String? lastModifiedTimestamp = record['last_modified_timestamp'] as String?;

    assert(userId != null, 'upsertUserStatsAverageDailyQuestionsLearnedFromInboundSync: user_id cannot be null. Data: $record');
    assert(recordDate != null, 'upsertUserStatsAverageDailyQuestionsLearnedFromInboundSync: record_date cannot be null. Data: $record');
    assert(avgLearned != null, 'upsertUserStatsAverageDailyQuestionsLearnedFromInboundSync: average_daily_questions_learned cannot be null. Data: $record');
    assert(lastModifiedTimestamp != null, 'upsertUserStatsAverageDailyQuestionsLearnedFromInboundSync: last_modified_timestamp cannot be null. Data: $record');

    await _verifyUserStatsAverageDailyQuestionsLearnedTable(db!);

    final Map<String, dynamic> dataToInsertOrUpdate = {
      'user_id': userId,
      'record_date': recordDate,
      'average_daily_questions_learned': avgLearned,
      'has_been_synced': 1,
      'edits_are_synced': 1,
      'last_modified_timestamp': lastModifiedTimestamp,
    };

    final int rowId = await insertRawData(
      'user_stats_average_daily_questions_learned',
      dataToInsertOrUpdate,
      db,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (rowId > 0) {
      QuizzerLogger.logSuccess('Successfully upserted user_stats_average_daily_questions_learned for user $userId, date $recordDate from inbound sync.');
    } else {
      QuizzerLogger.logWarning('upsertUserStatsAverageDailyQuestionsLearnedFromInboundSync: insertRawData with replace returned 0 for user $userId, date $recordDate. Data: $dataToInsertOrUpdate');
    }
  } catch (e) {
    QuizzerLogger.logError('Error upserting average daily questions learned record from inbound sync - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}


