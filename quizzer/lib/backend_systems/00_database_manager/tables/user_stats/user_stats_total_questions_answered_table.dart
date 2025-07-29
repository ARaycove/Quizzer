// 7. total_questions_answered (by date, the running the total of questions the users has answered)


import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

Future<void> _verifyUserStatsTotalQuestionsAnsweredTable(Database db) async {
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='user_stats_total_questions_answered'"
  );

  if (tables.isEmpty) {
    await db.execute('''
      CREATE TABLE user_stats_total_questions_answered (
        user_id TEXT NOT NULL,
        record_date TEXT NOT NULL,
        total_questions_answered INTEGER NOT NULL,
        correct_questions_answered INTEGER NOT NULL DEFAULT 0,
        incorrect_questions_answered INTEGER NOT NULL DEFAULT 0,
        has_been_synced INTEGER DEFAULT 0,
        edits_are_synced INTEGER DEFAULT 0,
        last_modified_timestamp TEXT,
        PRIMARY KEY (user_id, record_date)
      )
    ''');
    QuizzerLogger.logSuccess('Created user_stats_total_questions_answered table.');
  } else {
    final List<Map<String, dynamic>> columns = await db.rawQuery(
      "PRAGMA table_info(user_stats_total_questions_answered)"
    );
    final Set<String> columnNames = columns.map((col) => col['name'] as String).toSet();
    if (!columnNames.contains('correct_questions_answered')) {
      QuizzerLogger.logMessage('Adding correct_questions_answered column to user_stats_total_questions_answered table.');
      await db.execute('ALTER TABLE user_stats_total_questions_answered ADD COLUMN correct_questions_answered INTEGER NOT NULL DEFAULT 0');
    }
    if (!columnNames.contains('incorrect_questions_answered')) {
      QuizzerLogger.logMessage('Adding incorrect_questions_answered column to user_stats_total_questions_answered table.');
      await db.execute('ALTER TABLE user_stats_total_questions_answered ADD COLUMN incorrect_questions_answered INTEGER NOT NULL DEFAULT 0');
    }
    if (!columnNames.contains('has_been_synced')) {
      QuizzerLogger.logMessage('Adding has_been_synced column to user_stats_total_questions_answered table.');
      await db.execute('ALTER TABLE user_stats_total_questions_answered ADD COLUMN has_been_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('edits_are_synced')) {
      QuizzerLogger.logMessage('Adding edits_are_synced column to user_stats_total_questions_answered table.');
      await db.execute('ALTER TABLE user_stats_total_questions_answered ADD COLUMN edits_are_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('last_modified_timestamp')) {
      QuizzerLogger.logMessage('Adding last_modified_timestamp column to user_stats_total_questions_answered table.');
      await db.execute('ALTER TABLE user_stats_total_questions_answered ADD COLUMN last_modified_timestamp TEXT');
    }
  }
}

/// Increments the total questions answered stat for a user for today (YYYY-MM-DD) by 1, maintaining a running total and filling in skipped days.
Future<void> incrementTotalQuestionsAnsweredStat(String userId, bool isCorrect) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    await _verifyUserStatsTotalQuestionsAnsweredTable(db);

    // Fetch the most recent record for the user (by date desc)
    final List<Map<String, dynamic>> recentRecords = await db.query(
      'user_stats_total_questions_answered',
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
      lastTotal = recentRecords.first['total_questions_answered'] as int? ?? 0;
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
        'total_questions_answered': 1,
        'correct_questions_answered': correctInc,
        'incorrect_questions_answered': incorrectInc,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      await insertRawData('user_stats_total_questions_answered', data, db);
      QuizzerLogger.logSuccess('First total questions answered stat for user $userId on $today');
      return;
    }

    if (lastDate == today) {
      // Already a record for today, increment it
      final int current = lastTotal;
      final int currentCorrect = lastCorrect;
      final int currentIncorrect = lastIncorrect;
      final Map<String, dynamic> values = {
        'total_questions_answered': current + 1,
        'correct_questions_answered': currentCorrect + correctInc,
        'incorrect_questions_answered': currentIncorrect + incorrectInc,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      await updateRawData(
        'user_stats_total_questions_answered',
        values,
        'user_id = ? AND record_date = ?',
        [userId, today],
        db,
      );
      
      // Update SessionManager cache with the new total
      final SessionManager sessionManager = SessionManager();
      sessionManager.setCachedLifetimeTotalQuestionsAnswered(lastTotal + 1);
      
      QuizzerLogger.logSuccess('Incremented total questions answered stat for user $userId on $today');
      return;
    }

    // If today is after the last record, fill in missing days
    int daysGap = daysBetween(lastDate, today);
    if (daysGap > 0) {
      DateTime last = DateTime.parse(lastDate);
      for (int i = 1; i < daysGap; i++) {
        final fillDate = last.add(Duration(days: i)).toIso8601String().substring(0, 10);
        final Map<String, dynamic> fillData = {
          'user_id': userId,
          'record_date': fillDate,
          'total_questions_answered': lastTotal,
          'correct_questions_answered': lastCorrect,
          'incorrect_questions_answered': lastIncorrect,
          'has_been_synced': 0,
          'edits_are_synced': 0,
          'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
        };
        await insertRawData('user_stats_total_questions_answered', fillData, db);
        QuizzerLogger.logMessage('Filled skipped day $fillDate for user $userId with value $lastTotal');
      }
      // Now insert today's record as lastTotal + 1
      final Map<String, dynamic> todayData = {
        'user_id': userId,
        'record_date': today,
        'total_questions_answered': lastTotal + 1,
        'correct_questions_answered': lastCorrect + correctInc,
        'incorrect_questions_answered': lastIncorrect + incorrectInc,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      await insertRawData('user_stats_total_questions_answered', todayData, db);
      
      // Update SessionManager cache with the new total
      final SessionManager sessionManager = SessionManager();
      sessionManager.setCachedLifetimeTotalQuestionsAnswered(lastTotal + 1);
      
      QuizzerLogger.logSuccess('Incremented total questions answered stat for user $userId on $today (filled $daysGap skipped days)');
      return;
    }

    // If for some reason today < lastDate (should not happen), throw
    throw StateError('Attempted to increment total questions answered for a date ($today) before the last recorded date ($lastDate)');
  } catch (e) {
    QuizzerLogger.logError('Error incrementing total questions answered stat for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<List<Map<String, dynamic>>> getUserStatsTotalQuestionsAnsweredRecordsByUser(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await _verifyUserStatsTotalQuestionsAnsweredTable(db);
    return await queryAndDecodeDatabase(
      'user_stats_total_questions_answered',
      db,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  } catch (e) {
    QuizzerLogger.logError('Error getting total questions answered records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<Map<String, dynamic>> getUserStatsTotalQuestionsAnsweredRecordByDate(String userId, String recordDate) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await _verifyUserStatsTotalQuestionsAnsweredTable(db);
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'user_stats_total_questions_answered',
      db,
      where: 'user_id = ? AND record_date = ?',
      whereArgs: [userId, recordDate],
      limit: 2,
    );
    if (results.isEmpty) {
      QuizzerLogger.logMessage('No total questions answered record found for userId: $userId and date: $recordDate. Looking for most recent record...');
      // Find the most recent record for this user
      final List<Map<String, dynamic>> recentResults = await queryAndDecodeDatabase(
        'user_stats_total_questions_answered',
        db,
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'record_date DESC',
        limit: 1,
      );
      if (recentResults.isEmpty) {
        QuizzerLogger.logMessage('No total questions answered records found for userId: $userId at all. Returning default values.');
        // Return default values only if user has never answered any questions
        return {
          'user_id': userId,
          'record_date': recordDate,
          'total_questions_answered': 0,
          'correct_questions_answered': 0,
          'incorrect_questions_answered': 0,
          'has_been_synced': 0,
          'edits_are_synced': 0,
          'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
        };
      } else {
        final mostRecentRecord = recentResults.first;
        final String lastDate = mostRecentRecord['record_date'] as String;
        final int lastTotal = mostRecentRecord['total_questions_answered'] as int? ?? 0;
        final int lastCorrect = mostRecentRecord['correct_questions_answered'] as int? ?? 0;
        final int lastIncorrect = mostRecentRecord['incorrect_questions_answered'] as int? ?? 0;
        
        QuizzerLogger.logMessage('Found most recent total questions answered record for userId: $userId from date: $lastDate. Checking if we need to fill missing days...');
        
        // Calculate days between last record and requested date
        int daysBetween(String start, String end) {
          final startDate = DateTime.parse(start);
          final endDate = DateTime.parse(end);
          return endDate.difference(startDate).inDays;
        }
        
        int daysGap = daysBetween(lastDate, recordDate);
        if (daysGap > 0) {
          QuizzerLogger.logMessage('Filling $daysGap missing days for user $userId from $lastDate to $recordDate with value $lastTotal');
          // Fill in all missing days with the most recent value
          DateTime last = DateTime.parse(lastDate);
          for (int i = 1; i <= daysGap; i++) {
            final fillDate = last.add(Duration(days: i)).toIso8601String().substring(0, 10);
            final Map<String, dynamic> fillData = {
              'user_id': userId,
              'record_date': fillDate,
              'total_questions_answered': lastTotal,
              'correct_questions_answered': lastCorrect,
              'incorrect_questions_answered': lastIncorrect,
              'has_been_synced': 0,
              'edits_are_synced': 0,
              'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
            };
            await insertRawData('user_stats_total_questions_answered', fillData, db);
            QuizzerLogger.logMessage('Filled missing day $fillDate for user $userId with value $lastTotal');
          }
          QuizzerLogger.logSuccess('Successfully filled $daysGap missing days for user $userId');
        }
        
        // Return the most recent record but update the record_date to the requested date
        final mostRecent = Map<String, dynamic>.from(mostRecentRecord);
        mostRecent['record_date'] = recordDate;
        return mostRecent;
      }
    } else if (results.length > 1) {
      QuizzerLogger.logError('Multiple records found for userId: $userId and date: $recordDate. PK constraint violation?');
      throw StateError('Multiple records for PK user $userId, date $recordDate');
    }
    QuizzerLogger.logSuccess('Fetched total questions answered record for User: $userId, Date: $recordDate');
    return results.first;
  } catch (e) {
    QuizzerLogger.logError('Error getting total questions answered record for user ID: $userId, date: $recordDate - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<Map<String, dynamic>> getTodayUserStatsTotalQuestionsAnsweredRecord(String userId) async {
  final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  return await getUserStatsTotalQuestionsAnsweredRecordByDate(userId, today);
}

Future<List<Map<String, dynamic>>> getUnsyncedUserStatsTotalQuestionsAnsweredRecords(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching unsynced total questions answered records for user: $userId...');
    await _verifyUserStatsTotalQuestionsAnsweredTable(db);
    final List<Map<String, dynamic>> results = await db.query(
      'user_stats_total_questions_answered',
      where: '(has_been_synced = 0 OR edits_are_synced = 0) AND user_id = ?',
      whereArgs: [userId],
    );
    QuizzerLogger.logSuccess('Fetched ${results.length} unsynced total questions answered records for user $userId.');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced total questions answered records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<void> updateUserStatsTotalQuestionsAnsweredSyncFlags({
  required String userId,
  required String recordDate,
  required bool hasBeenSynced,
  required bool editsAreSynced,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Updating sync flags for total questions answered record (User: $userId, Date: $recordDate) -> Synced: $hasBeenSynced, Edits Synced: $editsAreSynced');
    await _verifyUserStatsTotalQuestionsAnsweredTable(db);
    final Map<String, dynamic> updates = {
      'has_been_synced': hasBeenSynced ? 1 : 0,
      'edits_are_synced': editsAreSynced ? 1 : 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    final int rowsAffected = await updateRawData(
      'user_stats_total_questions_answered',
      updates,
      'user_id = ? AND record_date = ?',
      [userId, recordDate],
      db,
    );
    if (rowsAffected == 0) {
      QuizzerLogger.logWarning('updateUserStatsTotalQuestionsAnsweredSyncFlags affected 0 rows for total questions answered record (User: $userId, Date: $recordDate). Record might not exist?');
    } else {
      QuizzerLogger.logSuccess('Successfully updated sync flags for total questions answered record (User: $userId, Date: $recordDate).');
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating sync flags for total questions answered record (User: $userId, Date: $recordDate) - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<void> upsertUserStatsTotalQuestionsAnsweredFromInboundSync(Map<String, dynamic> record) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    final String? userId = record['user_id'] as String?;
    final String? recordDate = record['record_date'] as String?;
    final int? totalCount = record['total_questions_answered'] as int?;
    final String? lastModifiedTimestamp = record['last_modified_timestamp'] as String?;
    final int correctCount = record['correct_questions_answered'] as int? ?? 0;
    final int incorrectCount = record['incorrect_questions_answered'] as int? ?? 0;

    assert(userId != null, 'upsertUserStatsTotalQuestionsAnsweredFromInboundSync: user_id cannot be null. Data: $record');
    assert(recordDate != null, 'upsertUserStatsTotalQuestionsAnsweredFromInboundSync: record_date cannot be null. Data: $record');
    assert(totalCount != null, 'upsertUserStatsTotalQuestionsAnsweredFromInboundSync: total_questions_answered cannot be null. Data: $record');
    assert(lastModifiedTimestamp != null, 'upsertUserStatsTotalQuestionsAnsweredFromInboundSync: last_modified_timestamp cannot be null. Data: $record');

    await _verifyUserStatsTotalQuestionsAnsweredTable(db);

    final Map<String, dynamic> dataToInsertOrUpdate = {
      'user_id': userId,
      'record_date': recordDate,
      'total_questions_answered': totalCount,
      'correct_questions_answered': correctCount,
      'incorrect_questions_answered': incorrectCount,
      'has_been_synced': 1,
      'edits_are_synced': 1,
      'last_modified_timestamp': lastModifiedTimestamp,
    };

    final int rowId = await insertRawData(
      'user_stats_total_questions_answered',
      dataToInsertOrUpdate,
      db,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (rowId > 0) {
      QuizzerLogger.logSuccess('Successfully upserted user_stats_total_questions_answered for user $userId, date $recordDate from inbound sync.');
    } else {
      QuizzerLogger.logWarning('upsertUserStatsTotalQuestionsAnsweredFromInboundSync: insertRawData with replace returned 0 for user $userId, date $recordDate. Data: $dataToInsertOrUpdate');
    }
  } catch (e) {
    QuizzerLogger.logError('Error upserting user_stats_total_questions_answered from inbound sync - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}