// 2. non_circulating_questions (by date, to get current non_circulating_questions get today's stat)

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

Future<void> _verifyUserStatsNonCirculatingQuestionsTable(Database db) async {
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='user_stats_non_circulating_questions'"
  );

  if (tables.isEmpty) {
    await db.execute('''
      CREATE TABLE user_stats_non_circulating_questions (
        user_id TEXT NOT NULL,
        record_date TEXT NOT NULL,
        non_circulating_questions_count INTEGER NOT NULL,
        has_been_synced INTEGER DEFAULT 0,
        edits_are_synced INTEGER DEFAULT 0,
        last_modified_timestamp TEXT,
        PRIMARY KEY (user_id, record_date)
      )
    ''');
    QuizzerLogger.logSuccess('Created user_stats_non_circulating_questions table.');
  } else {
    final List<Map<String, dynamic>> columns = await db.rawQuery(
      "PRAGMA table_info(user_stats_non_circulating_questions)"
    );
    final Set<String> columnNames = columns.map((col) => col['name'] as String).toSet();
    if (!columnNames.contains('has_been_synced')) {
      QuizzerLogger.logMessage('Adding has_been_synced column to user_stats_non_circulating_questions table.');
      await db.execute('ALTER TABLE user_stats_non_circulating_questions ADD COLUMN has_been_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('edits_are_synced')) {
      QuizzerLogger.logMessage('Adding edits_are_synced column to user_stats_non_circulating_questions table.');
      await db.execute('ALTER TABLE user_stats_non_circulating_questions ADD COLUMN edits_are_synced INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('last_modified_timestamp')) {
      QuizzerLogger.logMessage('Adding last_modified_timestamp column to user_stats_non_circulating_questions table.');
      await db.execute('ALTER TABLE user_stats_non_circulating_questions ADD COLUMN last_modified_timestamp TEXT');
    }
  }
}

/// Updates the non-circulating questions stat for a user for today (YYYY-MM-DD).
Future<void> updateNonCirculatingQuestionsStat(String userId) async {
  try {
    // Get the count of non-circulating questions using the proper function
    final List<Map<String, dynamic>> nonCirculatingQuestions = await getNonCirculatingQuestionsWithDetails(userId);
    final int nonCirculatingCount = nonCirculatingQuestions.length;
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    await _verifyUserStatsNonCirculatingQuestionsTable(db!);
    
    // Overwrite (insert or update) the record for today
    final List<Map<String, dynamic>> existing = await queryAndDecodeDatabase(
      'user_stats_non_circulating_questions',
      db,
      where: 'user_id = ? AND record_date = ?',
      whereArgs: [userId, today],
    );
    if (existing.isEmpty) {
      final Map<String, dynamic> data = {
        'user_id': userId,
        'record_date': today,
        'non_circulating_questions_count': nonCirculatingCount,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      await insertRawData('user_stats_non_circulating_questions', data, db, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      final Map<String, dynamic> values = {
        'non_circulating_questions_count': nonCirculatingCount,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      await updateRawData(
        'user_stats_non_circulating_questions',
        values,
        'user_id = ? AND record_date = ?',
        [userId, today],
        db,
      );
    }
    
    // Update SessionManager cache with the current value
    final SessionManager sessionManager = SessionManager();
    sessionManager.setCachedNonCirculatingQuestionsCount(nonCirculatingCount);
    
    QuizzerLogger.logSuccess('Updated non-circulating questions stat for user $userId on $today: $nonCirculatingCount');
  } catch (e) {
    QuizzerLogger.logError('Error updating non-circulating questions stat for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<List<Map<String, dynamic>>> getUserStatsNonCirculatingQuestionsRecordsByUser(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await _verifyUserStatsNonCirculatingQuestionsTable(db);
    return await queryAndDecodeDatabase(
      'user_stats_non_circulating_questions',
      db,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  } catch (e) {
    QuizzerLogger.logError('Error getting non-circulating questions records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<Map<String, dynamic>> getUserStatsNonCirculatingQuestionsRecordByDate(String userId, String recordDate) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await _verifyUserStatsNonCirculatingQuestionsTable(db);
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'user_stats_non_circulating_questions',
      db,
      where: 'user_id = ? AND record_date = ?',
      whereArgs: [userId, recordDate],
      limit: 2,
    );
    if (results.isEmpty) {
      QuizzerLogger.logMessage('No non-circulating questions record found for userId: $userId and date: $recordDate.');
      throw StateError('No record found for user $userId, date $recordDate');
    } else if (results.length > 1) {
      QuizzerLogger.logError('Multiple records found for userId: $userId and date: $recordDate. PK constraint violation?');
      throw StateError('Multiple records for PK user $userId, date $recordDate');
    }
    QuizzerLogger.logSuccess('Fetched non-circulating questions record for User: $userId, Date: $recordDate');
    return results.first;
  } catch (e) {
    QuizzerLogger.logError('Error getting non-circulating questions record for user ID: $userId, date: $recordDate - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<Map<String, dynamic>> getTodayUserStatsNonCirculatingQuestionsRecord(String userId) async {
  final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  return await getUserStatsNonCirculatingQuestionsRecordByDate(userId, today);
}

Future<List<Map<String, dynamic>>> getUnsyncedUserStatsNonCirculatingQuestionsRecords(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching unsynced non-circulating questions records for user: $userId...');
    await _verifyUserStatsNonCirculatingQuestionsTable(db);
    final List<Map<String, dynamic>> results = await db.query(
      'user_stats_non_circulating_questions',
      where: '(has_been_synced = 0 OR edits_are_synced = 0) AND user_id = ?',
      whereArgs: [userId],
    );
    QuizzerLogger.logSuccess('Fetched ${results.length} unsynced non-circulating questions records for user $userId.');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced non-circulating questions records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<void> updateUserStatsNonCirculatingQuestionsSyncFlags({
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
    QuizzerLogger.logMessage('Updating sync flags for non-circulating questions record (User: $userId, Date: $recordDate) -> Synced: $hasBeenSynced, Edits Synced: $editsAreSynced');
    await _verifyUserStatsNonCirculatingQuestionsTable(db);
    final Map<String, dynamic> updates = {
      'has_been_synced': hasBeenSynced ? 1 : 0,
      'edits_are_synced': editsAreSynced ? 1 : 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    final int rowsAffected = await updateRawData(
      'user_stats_non_circulating_questions',
      updates,
      'user_id = ? AND record_date = ?',
      [userId, recordDate],
      db,
    );
    if (rowsAffected == 0) {
      QuizzerLogger.logWarning('updateUserStatsNonCirculatingQuestionsSyncFlags affected 0 rows for non-circulating questions record (User: $userId, Date: $recordDate). Record might not exist?');
    } else {
      QuizzerLogger.logSuccess('Successfully updated sync flags for non-circulating questions record (User: $userId, Date: $recordDate).');
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating sync flags for non-circulating questions record (User: $userId, Date: $recordDate) - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<void> upsertUserStatsNonCirculatingQuestionsFromInboundSync(Map<String, dynamic> record) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    
    // Ensure required fields are present
    final String? userId = record['user_id'] as String?;
    final String? recordDate = record['record_date'] as String?;
    final int? nonCirculatingQuestionsCount = record['non_circulating_questions_count'] as int?;
    final String? lastModifiedTimestamp = record['last_modified_timestamp'] as String?;

    assert(userId != null, 'upsertUserStatsNonCirculatingQuestionsFromInboundSync: user_id cannot be null. Data: $record');
    assert(recordDate != null, 'upsertUserStatsNonCirculatingQuestionsFromInboundSync: record_date cannot be null. Data: $record');
    assert(nonCirculatingQuestionsCount != null, 'upsertUserStatsNonCirculatingQuestionsFromInboundSync: non_circulating_questions_count cannot be null. Data: $record');
    assert(lastModifiedTimestamp != null, 'upsertUserStatsNonCirculatingQuestionsFromInboundSync: last_modified_timestamp cannot be null. Data: $record');

    await _verifyUserStatsNonCirculatingQuestionsTable(db);

    final Map<String, dynamic> dataToInsertOrUpdate = {
      'user_id': userId,
      'record_date': recordDate,
      'non_circulating_questions_count': nonCirculatingQuestionsCount,
      'has_been_synced': 1,
      'edits_are_synced': 1,
      'last_modified_timestamp': lastModifiedTimestamp,
    };

    final int rowId = await insertRawData(
      'user_stats_non_circulating_questions',
      dataToInsertOrUpdate,
      db,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (rowId > 0) {
      QuizzerLogger.logSuccess('Successfully upserted user_stats_non_circulating_questions for user $userId, date $recordDate from inbound sync.');
    } else {
      QuizzerLogger.logWarning('upsertUserStatsNonCirculatingQuestionsFromInboundSync: insertRawData with replace returned 0 for user $userId, date $recordDate. Data: $dataToInsertOrUpdate');
    }
  } catch (e) {
    QuizzerLogger.logError('Error upserting user_stats_non_circulating_questions from inbound sync - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
} 