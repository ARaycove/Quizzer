import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import '../table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';

Future<void> _verifyUserStatsEligibleQuestionsTable(Database db) async {
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='user_stats_eligible_questions'"
  );

  if (tables.isEmpty) {
    await db.execute('''
      CREATE TABLE user_stats_eligible_questions (
        user_id TEXT NOT NULL,
        record_date TEXT NOT NULL,
        eligible_questions_count INTEGER NOT NULL,
        has_been_synced INTEGER DEFAULT 0,
        edits_are_synced INTEGER DEFAULT 0,
        last_modified_timestamp TEXT,
        PRIMARY KEY (user_id, record_date)
      )
    ''');
    QuizzerLogger.logSuccess('Created user_stats_eligible_questions table.');
  } else {
    final List<Map<String, dynamic>> columns = await db.rawQuery(
      "PRAGMA table_info(user_stats_eligible_questions)"
    );
    final Set<String> columnNames = columns.map((col) => col['name'] as String).toSet();
    if (!columnNames.contains('has_been_synced')) {
      QuizzerLogger.logMessage('Adding has_been_synced column to user_stats_eligible_questions table.');
      await db.execute('ALTER TABLE user_stats_eligible_questions ADD COLUMN has_been_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('edits_are_synced')) {
      QuizzerLogger.logMessage('Adding edits_are_synced column to user_stats_eligible_questions table.');
      await db.execute('ALTER TABLE user_stats_eligible_questions ADD COLUMN edits_are_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('last_modified_timestamp')) {
      QuizzerLogger.logMessage('Adding last_modified_timestamp column to user_stats_eligible_questions table.');
      await db.execute('ALTER TABLE user_stats_eligible_questions ADD COLUMN last_modified_timestamp TEXT');
    }
  }
}

/// Updates the eligible questions stat for a user for today (YYYY-MM-DD).
Future<void> updateEligibleQuestionsStat(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    // Get today's date in YYYY-MM-DD format
    final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);

    // Query the count of eligible questions for this user (read-only, do not verify)
    final List<Map<String, dynamic>> result = await db!.rawQuery(
      'SELECT COUNT(*) as count FROM user_question_answer_pairs WHERE user_uuid = ? AND is_eligible = 1',
      [userId],
    );
    final int eligibleCount = result.isNotEmpty ? (result.first['count'] as int) : 0;

    // Verify only the stats table before writing
    await _verifyUserStatsEligibleQuestionsTable(db);

    // Overwrite (insert or update) the record for today
    final List<Map<String, dynamic>> existing = await queryAndDecodeDatabase(
      'user_stats_eligible_questions',
      db,
      where: 'user_id = ? AND record_date = ?',
      whereArgs: [userId, today],
    );
    if (existing.isEmpty) {
      final Map<String, dynamic> data = {
        'user_id': userId,
        'record_date': today,
        'eligible_questions_count': eligibleCount,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      await insertRawData('user_stats_eligible_questions', data, db);
    } else {
      final Map<String, dynamic> values = {
        'eligible_questions_count': eligibleCount,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      await updateRawData(
        'user_stats_eligible_questions',
        values,
        'user_id = ? AND record_date = ?',
        [userId, today],
        db,
      );
    }
    QuizzerLogger.logSuccess('Updated eligible questions stat for user $userId on $today: $eligibleCount');
  } catch (e) {
    QuizzerLogger.logError('Error updating eligible questions stat for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<List<Map<String, dynamic>>> getUserStatsEligibleQuestionsRecordsByUser(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await _verifyUserStatsEligibleQuestionsTable(db!);
    return await queryAndDecodeDatabase(
      'user_stats_eligible_questions',
      db,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  } catch (e) {
    QuizzerLogger.logError('Error getting eligible questions records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<Map<String, dynamic>> getUserStatsEligibleQuestionsRecordByDate(String userId, String recordDate) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await _verifyUserStatsEligibleQuestionsTable(db!);
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'user_stats_eligible_questions',
      db,
      where: 'user_id = ? AND record_date = ?',
      whereArgs: [userId, recordDate],
      limit: 2,
    );
    if (results.isEmpty) {
      QuizzerLogger.logMessage('No eligible questions record found for userId: $userId and date: $recordDate.');
      throw StateError('No record found for user $userId, date $recordDate');
    } else if (results.length > 1) {
      QuizzerLogger.logError('Multiple records found for userId: $userId and date: $recordDate. PK constraint violation?');
      throw StateError('Multiple records for PK user $userId, date $recordDate');
    }
    QuizzerLogger.logSuccess('Fetched eligible questions record for User: $userId, Date: $recordDate');
    return results.first;
  } catch (e) {
    QuizzerLogger.logError('Error getting eligible questions record for user ID: $userId, date: $recordDate - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<Map<String, dynamic>> getTodayUserStatsEligibleQuestionsRecord(String userId) async {
  final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  return await getUserStatsEligibleQuestionsRecordByDate(userId, today);
}

Future<List<Map<String, dynamic>>> getUnsyncedUserStatsEligibleQuestionsRecords(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    QuizzerLogger.logMessage('Fetching unsynced eligible questions records for user: $userId...');
    await _verifyUserStatsEligibleQuestionsTable(db!);
    final List<Map<String, dynamic>> results = await db.query(
      'user_stats_eligible_questions',
      where: '(has_been_synced = 0 OR edits_are_synced = 0) AND user_id = ?',
      whereArgs: [userId],
    );
    QuizzerLogger.logSuccess('Fetched ${results.length} unsynced eligible questions records for user $userId.');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced eligible questions records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<void> updateUserStatsEligibleQuestionsSyncFlags({
  required String userId,
  required String recordDate,
  required bool hasBeenSynced,
  required bool editsAreSynced,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    QuizzerLogger.logMessage('Updating sync flags for eligible questions record (User: $userId, Date: $recordDate) -> Synced: $hasBeenSynced, Edits Synced: $editsAreSynced');
    await _verifyUserStatsEligibleQuestionsTable(db!);
    final Map<String, dynamic> updates = {
      'has_been_synced': hasBeenSynced ? 1 : 0,
      'edits_are_synced': editsAreSynced ? 1 : 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    final int rowsAffected = await updateRawData(
      'user_stats_eligible_questions',
      updates,
      'user_id = ? AND record_date = ?',
      [userId, recordDate],
      db,
    );
    if (rowsAffected == 0) {
      QuizzerLogger.logWarning('updateUserStatsEligibleQuestionsSyncFlags affected 0 rows for eligible questions record (User: $userId, Date: $recordDate). Record might not exist?');
    } else {
      QuizzerLogger.logSuccess('Successfully updated sync flags for eligible questions record (User: $userId, Date: $recordDate).');
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating sync flags for eligible questions record (User: $userId, Date: $recordDate) - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<void> upsertUserStatsEligibleQuestionsFromInboundSync(Map<String, dynamic> record) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    // Ensure required fields are present
    final String? userId = record['user_id'] as String?;
    final String? recordDate = record['record_date'] as String?;
    final int? eligibleQuestionsCount = record['eligible_questions_count'] as int?;
    final String? lastModifiedTimestamp = record['last_modified_timestamp'] as String?;

    assert(userId != null, 'upsertUserStatsEligibleQuestionsFromInboundSync: user_id cannot be null. Data: $record');
    assert(recordDate != null, 'upsertUserStatsEligibleQuestionsFromInboundSync: record_date cannot be null. Data: $record');
    assert(eligibleQuestionsCount != null, 'upsertUserStatsEligibleQuestionsFromInboundSync: eligible_questions_count cannot be null. Data: $record');
    assert(lastModifiedTimestamp != null, 'upsertUserStatsEligibleQuestionsFromInboundSync: last_modified_timestamp cannot be null. Data: $record');

    await _verifyUserStatsEligibleQuestionsTable(db!);

    final Map<String, dynamic> dataToInsertOrUpdate = {
      'user_id': userId,
      'record_date': recordDate,
      'eligible_questions_count': eligibleQuestionsCount,
      'has_been_synced': 1,
      'edits_are_synced': 1,
      'last_modified_timestamp': lastModifiedTimestamp,
    };

    final int rowId = await insertRawData(
      'user_stats_eligible_questions',
      dataToInsertOrUpdate,
      db,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (rowId > 0) {
      QuizzerLogger.logSuccess('Successfully upserted user_stats_eligible_questions for user $userId, date $recordDate from inbound sync.');
    } else {
      QuizzerLogger.logWarning('upsertUserStatsEligibleQuestionsFromInboundSync: insertRawData with replace returned 0 for user $userId, date $recordDate. Data: $dataToInsertOrUpdate');
    }
  } catch (e) {
    QuizzerLogger.logError('Error upserting eligible questions record from inbound sync - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}
