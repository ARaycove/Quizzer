// 8. questions_answered_by_date (by date, the number of questions the user answered on a given day)


import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

Future<void> verifyUserStatsDailyQuestionsAnsweredTable(dynamic db) async {
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='user_stats_daily_questions_answered'"
  );

  if (tables.isEmpty) {
    await db.execute('''
      CREATE TABLE user_stats_daily_questions_answered (
        user_id TEXT NOT NULL,
        record_date TEXT NOT NULL,
        daily_questions_answered INTEGER NOT NULL,
        correct_questions_answered INTEGER NOT NULL DEFAULT 0,
        incorrect_questions_answered INTEGER NOT NULL DEFAULT 0,
        has_been_synced INTEGER DEFAULT 0,
        edits_are_synced INTEGER DEFAULT 0,
        last_modified_timestamp TEXT,
        PRIMARY KEY (user_id, record_date)
      )
    ''');
    QuizzerLogger.logSuccess('Created user_stats_daily_questions_answered table.');
  } else {
    final List<Map<String, dynamic>> columns = await db.rawQuery(
      "PRAGMA table_info(user_stats_daily_questions_answered)"
    );
    final Set<String> columnNames = columns.map((col) => col['name'] as String).toSet();
    if (!columnNames.contains('correct_questions_answered')) {
      QuizzerLogger.logMessage('Adding correct_questions_answered column to user_stats_daily_questions_answered table.');
      await db.execute('ALTER TABLE user_stats_daily_questions_answered ADD COLUMN correct_questions_answered INTEGER NOT NULL DEFAULT 0');
    }
    if (!columnNames.contains('incorrect_questions_answered')) {
      QuizzerLogger.logMessage('Adding incorrect_questions_answered column to user_stats_daily_questions_answered table.');
      await db.execute('ALTER TABLE user_stats_daily_questions_answered ADD COLUMN incorrect_questions_answered INTEGER NOT NULL DEFAULT 0');
    }
    if (!columnNames.contains('has_been_synced')) {
      QuizzerLogger.logMessage('Adding has_been_synced column to user_stats_daily_questions_answered table.');
      await db.execute('ALTER TABLE user_stats_daily_questions_answered ADD COLUMN has_been_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('edits_are_synced')) {
      QuizzerLogger.logMessage('Adding edits_are_synced column to user_stats_daily_questions_answered table.');
      await db.execute('ALTER TABLE user_stats_daily_questions_answered ADD COLUMN edits_are_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('last_modified_timestamp')) {
      QuizzerLogger.logMessage('Adding last_modified_timestamp column to user_stats_daily_questions_answered table.');
      await db.execute('ALTER TABLE user_stats_daily_questions_answered ADD COLUMN last_modified_timestamp TEXT');
    }
  }
}

/// Increments the daily questions answered stat for a user for today (YYYY-MM-DD) by 1, filling in skipped days with 0.
Future<void> incrementDailyQuestionsAnsweredStat(String userId, bool isCorrect) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);

    // Fetch the most recent record for the user (by date desc)
    final List<Map<String, dynamic>> recentRecords = await db!.query(
      'user_stats_daily_questions_answered',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'record_date DESC',
      limit: 1,
    );

    int lastTotal = 0;
    int lastCorrect = 0;
    int lastIncorrect = 0;
    String? lastDate;
    if (recentRecords.isNotEmpty) {
      lastTotal = recentRecords.first['daily_questions_answered'] as int? ?? 0;
      lastCorrect = recentRecords.first['correct_questions_answered'] as int? ?? 0;
      lastIncorrect = recentRecords.first['incorrect_questions_answered'] as int? ?? 0;
      lastDate = recentRecords.first['record_date'] as String?;
    }

    int daysBetween(String start, String end) {
      final startDate = DateTime.parse(start);
      final endDate = DateTime.parse(end);
      return endDate.difference(startDate).inDays;
    }

    int correctInc = isCorrect ? 1 : 0;
    int incorrectInc = isCorrect ? 0 : 1;

    if (lastDate == null) {
      // No previous record, insert today as 1
      final Map<String, dynamic> data = {
        'user_id': userId,
        'record_date': today,
        'daily_questions_answered': 1,
        'correct_questions_answered': correctInc,
        'incorrect_questions_answered': incorrectInc,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      await insertRawData('user_stats_daily_questions_answered', data, db);
      QuizzerLogger.logSuccess('First daily questions answered stat for user $userId on $today');
      return;
    }

    if (lastDate == today) {
      // Already a record for today, increment it
      final int current = lastTotal;
      final int currentCorrect = lastCorrect;
      final int currentIncorrect = lastIncorrect;
      final Map<String, dynamic> values = {
        'daily_questions_answered': current + 1,
        'correct_questions_answered': currentCorrect + correctInc,
        'incorrect_questions_answered': currentIncorrect + incorrectInc,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      await updateRawData(
        'user_stats_daily_questions_answered',
        values,
        'user_id = ? AND record_date = ?',
        [userId, today],
        db,
      );
      
      // Update SessionManager cache with the new daily total
      final SessionManager sessionManager = SessionManager();
      sessionManager.setCachedDailyQuestionsAnswered(current + 1);
      
      QuizzerLogger.logSuccess('Incremented daily questions answered stat for user $userId on $today');
      return;
    }

    // If today is after the last record, fill in missing days with 0
    int daysGap = daysBetween(lastDate, today);
    if (daysGap > 0) {
      DateTime last = DateTime.parse(lastDate);
      for (int i = 1; i < daysGap; i++) {
        final fillDate = last.add(Duration(days: i)).toIso8601String().substring(0, 10);
        final Map<String, dynamic> fillData = {
          'user_id': userId,
          'record_date': fillDate,
          'daily_questions_answered': 0,
          'correct_questions_answered': 0,
          'incorrect_questions_answered': 0,
          'has_been_synced': 0,
          'edits_are_synced': 0,
          'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
        };
        await insertRawData('user_stats_daily_questions_answered', fillData, db);
        QuizzerLogger.logMessage('Filled skipped day $fillDate for user $userId with value 0');
      }
      // Now insert today's record as 1
      final Map<String, dynamic> todayData = {
        'user_id': userId,
        'record_date': today,
        'daily_questions_answered': 1,
        'correct_questions_answered': correctInc,
        'incorrect_questions_answered': incorrectInc,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      await insertRawData('user_stats_daily_questions_answered', todayData, db);
      
      // Update SessionManager cache with the new daily total
      final SessionManager sessionManager = SessionManager();
      sessionManager.setCachedDailyQuestionsAnswered(1);
      
      QuizzerLogger.logSuccess('Incremented daily questions answered stat for user $userId on $today (filled $daysGap skipped days)');
      return;
    }

    // If for some reason today < lastDate (should not happen), throw
    throw StateError('Attempted to increment daily questions answered for a date ($today) before the last recorded date ($lastDate)');
  } catch (e) {
    QuizzerLogger.logError('Error incrementing daily questions answered stat for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<List<Map<String, dynamic>>> getUserStatsDailyQuestionsAnsweredRecordsByUser(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    return await queryAndDecodeDatabase(
      'user_stats_daily_questions_answered',
      db,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  } catch (e) {
    QuizzerLogger.logError('Error getting daily questions answered records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<Map<String, dynamic>> getUserStatsDailyQuestionsAnsweredRecordByDate(String userId, String recordDate) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'user_stats_daily_questions_answered',
      db,
      where: 'user_id = ? AND record_date = ?',
      whereArgs: [userId, recordDate],
      limit: 2,
    );
    if (results.isEmpty) {
      QuizzerLogger.logMessage('No daily questions answered record found for userId: $userId and date: $recordDate.');
      throw StateError('No record found for user $userId, date $recordDate');
    } else if (results.length > 1) {
      QuizzerLogger.logError('Multiple records found for userId: $userId and date: $recordDate. PK constraint violation?');
      throw StateError('Multiple records for PK user $userId, date $recordDate');
    }
    QuizzerLogger.logSuccess('Fetched daily questions answered record for User: $userId, Date: $recordDate');
    return results.first;
  } catch (e) {
    QuizzerLogger.logError('Error getting daily questions answered record for user ID: $userId, date: $recordDate - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<Map<String, dynamic>> getTodayUserStatsDailyQuestionsAnsweredRecord(String userId) async {
  final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  return await getUserStatsDailyQuestionsAnsweredRecordByDate(userId, today);
}

Future<List<Map<String, dynamic>>> getUnsyncedUserStatsDailyQuestionsAnsweredRecords(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    QuizzerLogger.logMessage('Fetching unsynced daily questions answered records for user: $userId...');
    final List<Map<String, dynamic>> results = await db!.query(
      'user_stats_daily_questions_answered',
      where: '(has_been_synced = 0 OR edits_are_synced = 0) AND user_id = ?',
      whereArgs: [userId],
    );
    QuizzerLogger.logSuccess('Fetched ${results.length} unsynced daily questions answered records for user $userId.');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced daily questions answered records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<void> updateUserStatsDailyQuestionsAnsweredSyncFlags({
  required String userId,
  required String recordDate,
  required bool hasBeenSynced,
  required bool editsAreSynced,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    QuizzerLogger.logMessage('Updating sync flags for daily questions answered record (User: $userId, Date: $recordDate) -> Synced: $hasBeenSynced, Edits Synced: $editsAreSynced');
    final Map<String, dynamic> updates = {
      'has_been_synced': hasBeenSynced ? 1 : 0,
      'edits_are_synced': editsAreSynced ? 1 : 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    final int rowsAffected = await updateRawData(
      'user_stats_daily_questions_answered',
      updates,
      'user_id = ? AND record_date = ?',
      [userId, recordDate],
      db,
    );
    if (rowsAffected == 0) {
      QuizzerLogger.logWarning('updateUserStatsDailyQuestionsAnsweredSyncFlags affected 0 rows for daily questions answered record (User: $userId, Date: $recordDate). Record might not exist?');
    } else {
      QuizzerLogger.logSuccess('Successfully updated sync flags for daily questions answered record (User: $userId, Date: $recordDate).');
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating sync flags for daily questions answered record (User: $userId, Date: $recordDate) - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<void> batchUpsertUserStatsDailyQuestionsAnsweredFromInboundSync({
  required List<Map<String, dynamic>> userStatsDailyQuestionsAnsweredRecords,
  required dynamic db
}) async {
  try {
    for (Map<String, dynamic> statRecord in userStatsDailyQuestionsAnsweredRecords) {
      // Define the data map 
      final Map<String, dynamic> dataToInsertOrUpdate = {
        'user_id': statRecord['user_id'],
        'record_date': statRecord['record_date'],
        'daily_questions_answered': statRecord['daily_questions_answered'],
        'correct_questions_answered': statRecord['correct_questions_answered'],
        'incorrect_questions_answered': statRecord['incorrect_questions_answered'],
        'has_been_synced': 1,
        'edits_are_synced': 1,
        'last_modified_timestamp': statRecord['last_modified_timestamp'],
      };
      // Insert the data map
      await insertRawData(
        'user_stats_daily_questions_answered',
        dataToInsertOrUpdate,
        db,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  } catch (e) {
    QuizzerLogger.logError('Error upserting daily questions answered record from inbound sync - $e');
    rethrow;
  }
}