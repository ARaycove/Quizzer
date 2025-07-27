// 6. average_questions_shown_per_day (by date, average number of questions being shown daily)

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';

Future<void> _verifyUserStatsAverageQuestionsShownPerDayTable(Database db) async {
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='user_stats_average_questions_shown_per_day'"
  );

  if (tables.isEmpty) {
    await db.execute('''
      CREATE TABLE user_stats_average_questions_shown_per_day (
        user_id TEXT NOT NULL,
        record_date TEXT NOT NULL,
        average_questions_shown_per_day REAL NOT NULL,
        has_been_synced INTEGER DEFAULT 0,
        edits_are_synced INTEGER DEFAULT 0,
        last_modified_timestamp TEXT,
        PRIMARY KEY (user_id, record_date)
      )
    ''');
    QuizzerLogger.logSuccess('Created user_stats_average_questions_shown_per_day table.');
  } else {
    final List<Map<String, dynamic>> columns = await db.rawQuery(
      "PRAGMA table_info(user_stats_average_questions_shown_per_day)"
    );
    final Set<String> columnNames = columns.map((col) => col['name'] as String).toSet();
    if (!columnNames.contains('has_been_synced')) {
      QuizzerLogger.logMessage('Adding has_been_synced column to user_stats_average_questions_shown_per_day table.');
      await db.execute('ALTER TABLE user_stats_average_questions_shown_per_day ADD COLUMN has_been_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('edits_are_synced')) {
      QuizzerLogger.logMessage('Adding edits_are_synced column to user_stats_average_questions_shown_per_day table.');
      await db.execute('ALTER TABLE user_stats_average_questions_shown_per_day ADD COLUMN edits_are_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('last_modified_timestamp')) {
      QuizzerLogger.logMessage('Adding last_modified_timestamp column to user_stats_average_questions_shown_per_day table.');
      await db.execute('ALTER TABLE user_stats_average_questions_shown_per_day ADD COLUMN last_modified_timestamp TEXT');
    }
  }
}

/// Updates the average questions shown per day stat for a user for today (YYYY-MM-DD).
Future<void> updateAverageQuestionsShownPerDayStat(String userId) async {
  try {
    // Get active questions in circulation using the proper function
    final List<Map<String, dynamic>> activeQuestionsInCirculation = await getActiveQuestionsInCirculation(userId);
    
    // Calculate the sum with revision score correction
    double totalShown = 0.0;
    for (final question in activeQuestionsInCirculation) {
      double avgShown = (question['average_times_shown_per_day'] as num?)?.toDouble() ?? 0.0;
      final int revisionStreak = question['revision_streak'] as int? ?? 0;
      
      // Apply revision score correction: if revision_streak = 0, add 1 to the average
      if (revisionStreak == 0) {
        avgShown += 1.0;
      }
      
      totalShown += avgShown;
    }
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    await _verifyUserStatsAverageQuestionsShownPerDayTable(db!);
    
    // Overwrite (insert or update) the record for today
    final List<Map<String, dynamic>> existing = await queryAndDecodeDatabase(
      'user_stats_average_questions_shown_per_day',
      db,
      where: 'user_id = ? AND record_date = ?',
      whereArgs: [userId, today],
    );
    if (existing.isEmpty) {
      final Map<String, dynamic> data = {
        'user_id': userId,
        'record_date': today,
        'average_questions_shown_per_day': totalShown,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      await insertRawData('user_stats_average_questions_shown_per_day', data, db, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      final Map<String, dynamic> values = {
        'average_questions_shown_per_day': totalShown,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      await updateRawData(
        'user_stats_average_questions_shown_per_day',
        values,
        'user_id = ? AND record_date = ?',
        [userId, today],
        db,
      );
    }
    QuizzerLogger.logSuccess('Updated average questions shown per day stat for user $userId on $today: $totalShown (from ${activeQuestionsInCirculation.length} active questions)');
  } catch (e) {
    QuizzerLogger.logError('Error updating average questions shown per day stat for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<List<Map<String, dynamic>>> getUserStatsAverageQuestionsShownPerDayRecordsByUser(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await _verifyUserStatsAverageQuestionsShownPerDayTable(db!);
    return await queryAndDecodeDatabase(
      'user_stats_average_questions_shown_per_day',
      db,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  } catch (e) {
    QuizzerLogger.logError('Error getting average questions shown per day records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<Map<String, dynamic>> getUserStatsAverageQuestionsShownPerDayRecordByDate(String userId, String recordDate) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await _verifyUserStatsAverageQuestionsShownPerDayTable(db!);
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'user_stats_average_questions_shown_per_day',
      db,
      where: 'user_id = ? AND record_date = ?',
      whereArgs: [userId, recordDate],
      limit: 2,
    );
    if (results.isEmpty) {
      QuizzerLogger.logMessage('No average questions shown per day record found for userId: $userId and date: $recordDate.');
      throw StateError('No record found for user $userId, date $recordDate');
    } else if (results.length > 1) {
      QuizzerLogger.logError('Multiple records found for userId: $userId and date: $recordDate. PK constraint violation?');
      throw StateError('Multiple records for PK user $userId, date $recordDate');
    }
    QuizzerLogger.logSuccess('Fetched average questions shown per day record for User: $userId, Date: $recordDate');
    return results.first;
  } catch (e) {
    QuizzerLogger.logError('Error getting average questions shown per day record for user ID: $userId, date: $recordDate - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<Map<String, dynamic>> getTodayUserStatsAverageQuestionsShownPerDayRecord(String userId) async {
  final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  return await getUserStatsAverageQuestionsShownPerDayRecordByDate(userId, today);
}

Future<List<Map<String, dynamic>>> getUnsyncedUserStatsAverageQuestionsShownPerDayRecords(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    QuizzerLogger.logMessage('Fetching unsynced average questions shown per day records for user: $userId...');
    await _verifyUserStatsAverageQuestionsShownPerDayTable(db!);
    final List<Map<String, dynamic>> results = await db.query(
      'user_stats_average_questions_shown_per_day',
      where: '(has_been_synced = 0 OR edits_are_synced = 0) AND user_id = ?',
      whereArgs: [userId],
    );
    QuizzerLogger.logSuccess('Fetched ${results.length} unsynced average questions shown per day records for user $userId.');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced average questions shown per day records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<void> updateUserStatsAverageQuestionsShownPerDaySyncFlags({
  required String userId,
  required String recordDate,
  required bool hasBeenSynced,
  required bool editsAreSynced,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    QuizzerLogger.logMessage('Updating sync flags for average questions shown per day record (User: $userId, Date: $recordDate) -> Synced: $hasBeenSynced, Edits Synced: $editsAreSynced');
    await _verifyUserStatsAverageQuestionsShownPerDayTable(db!);
    final Map<String, dynamic> updates = {
      'has_been_synced': hasBeenSynced ? 1 : 0,
      'edits_are_synced': editsAreSynced ? 1 : 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    final int rowsAffected = await updateRawData(
      'user_stats_average_questions_shown_per_day',
      updates,
      'user_id = ? AND record_date = ?',
      [userId, recordDate],
      db,
    );
    if (rowsAffected == 0) {
      QuizzerLogger.logWarning('updateUserStatsAverageQuestionsShownPerDaySyncFlags affected 0 rows for average questions shown per day record (User: $userId, Date: $recordDate). Record might not exist?');
    } else {
      QuizzerLogger.logSuccess('Successfully updated sync flags for average questions shown per day record (User: $userId, Date: $recordDate).');
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating sync flags for average questions shown per day record (User: $userId, Date: $recordDate) - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<void> upsertUserStatsAverageQuestionsShownPerDayFromInboundSync(Map<String, dynamic> record) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    final String? userId = record['user_id'] as String?;
    final String? recordDate = record['record_date'] as String?;
    final double? avgShown = record['average_questions_shown_per_day'] is int
        ? (record['average_questions_shown_per_day'] as int).toDouble()
        : record['average_questions_shown_per_day'] as double?;
    final String? lastModifiedTimestamp = record['last_modified_timestamp'] as String?;

    assert(userId != null, 'upsertUserStatsAverageQuestionsShownPerDayFromInboundSync: user_id cannot be null. Data: $record');
    assert(recordDate != null, 'upsertUserStatsAverageQuestionsShownPerDayFromInboundSync: record_date cannot be null. Data: $record');
    assert(avgShown != null, 'upsertUserStatsAverageQuestionsShownPerDayFromInboundSync: average_questions_shown_per_day cannot be null. Data: $record');
    assert(lastModifiedTimestamp != null, 'upsertUserStatsAverageQuestionsShownPerDayFromInboundSync: last_modified_timestamp cannot be null. Data: $record');

    await _verifyUserStatsAverageQuestionsShownPerDayTable(db!);

    final Map<String, dynamic> dataToInsertOrUpdate = {
      'user_id': userId,
      'record_date': recordDate,
      'average_questions_shown_per_day': avgShown,
      'has_been_synced': 1,
      'edits_are_synced': 1,
      'last_modified_timestamp': lastModifiedTimestamp,
    };

    final int rowId = await insertRawData(
      'user_stats_average_questions_shown_per_day',
      dataToInsertOrUpdate,
      db,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (rowId > 0) {
      QuizzerLogger.logSuccess('Successfully upserted user_stats_average_questions_shown_per_day for user $userId, date $recordDate from inbound sync.');
    } else {
      QuizzerLogger.logWarning('upsertUserStatsAverageQuestionsShownPerDayFromInboundSync: insertRawData with replace returned 0 for user $userId, date $recordDate. Data: $dataToInsertOrUpdate');
    }
  } catch (e) {
    QuizzerLogger.logError('Error upserting average questions shown per day record from inbound sync - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}