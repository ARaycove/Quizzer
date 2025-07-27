// 5. total_questions_in_database (by date, get the total number of user_question_answer_pairs that have at least one attempt on them)

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';

Future<void> _verifyUserStatsTotalUserQuestionAnswerPairsTable(Database db) async {
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
Future<void> updateTotalUserQuestionAnswerPairsStat(String userId) async {
  try {
    // Get the count of active questions in circulation using the proper function
    final List<Map<String, dynamic>> activeQuestionsInCirculation = await getActiveQuestionsInCirculation(userId);
    final int totalCount = activeQuestionsInCirculation.length;
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    await _verifyUserStatsTotalUserQuestionAnswerPairsTable(db!);
    
    // Overwrite (insert or update) the record for today
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
      await insertRawData('user_stats_total_user_question_answer_pairs', data, db, conflictAlgorithm: ConflictAlgorithm.replace);
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
  } catch (e) {
    QuizzerLogger.logError('Error updating total user question answer pairs stat for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<List<Map<String, dynamic>>> getUserStatsTotalUserQuestionAnswerPairsRecordsByUser(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await _verifyUserStatsTotalUserQuestionAnswerPairsTable(db);
    return await queryAndDecodeDatabase(
      'user_stats_total_user_question_answer_pairs',
      db,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  } catch (e) {
    QuizzerLogger.logError('Error getting total user question answer pairs records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<Map<String, dynamic>> getUserStatsTotalUserQuestionAnswerPairsRecordByDate(String userId, String recordDate) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await _verifyUserStatsTotalUserQuestionAnswerPairsTable(db);
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
  } catch (e) {
    QuizzerLogger.logError('Error getting total user question answer pairs record for user ID: $userId, date: $recordDate - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<Map<String, dynamic>> getTodayUserStatsTotalUserQuestionAnswerPairsRecord(String userId) async {
  final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  return await getUserStatsTotalUserQuestionAnswerPairsRecordByDate(userId, today);
}

Future<List<Map<String, dynamic>>> getUnsyncedUserStatsTotalUserQuestionAnswerPairsRecords(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching unsynced total user question answer pairs records for user: $userId...');
    await _verifyUserStatsTotalUserQuestionAnswerPairsTable(db);
    final List<Map<String, dynamic>> results = await db.query(
      'user_stats_total_user_question_answer_pairs',
      where: '(has_been_synced = 0 OR edits_are_synced = 0) AND user_id = ?',
      whereArgs: [userId],
    );
    QuizzerLogger.logSuccess('Fetched ${results.length} unsynced total user question answer pairs records for user $userId.');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced total user question answer pairs records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<void> updateUserStatsTotalUserQuestionAnswerPairsSyncFlags({
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
    QuizzerLogger.logMessage('Updating sync flags for total user question answer pairs record (User: $userId, Date: $recordDate) -> Synced: $hasBeenSynced, Edits Synced: $editsAreSynced');
    await _verifyUserStatsTotalUserQuestionAnswerPairsTable(db);
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
  } catch (e) {
    QuizzerLogger.logError('Error updating sync flags for total user question answer pairs record (User: $userId, Date: $recordDate) - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<void> upsertUserStatsTotalUserQuestionAnswerPairsFromInboundSync(Map<String, dynamic> record) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    final String? userId = record['user_id'] as String?;
    final String? recordDate = record['record_date'] as String?;
    final int? totalCount = record['total_question_answer_pairs'] as int?;
    final String? lastModifiedTimestamp = record['last_modified_timestamp'] as String?;

    assert(userId != null, 'upsertUserStatsTotalUserQuestionAnswerPairsFromInboundSync: user_id cannot be null. Data: $record');
    assert(recordDate != null, 'upsertUserStatsTotalUserQuestionAnswerPairsFromInboundSync: record_date cannot be null. Data: $record');
    assert(totalCount != null, 'upsertUserStatsTotalUserQuestionAnswerPairsFromInboundSync: total_question_answer_pairs cannot be null. Data: $record');
    assert(lastModifiedTimestamp != null, 'upsertUserStatsTotalUserQuestionAnswerPairsFromInboundSync: last_modified_timestamp cannot be null. Data: $record');

    await _verifyUserStatsTotalUserQuestionAnswerPairsTable(db);

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
  } catch (e) {
    QuizzerLogger.logError('Error upserting user_stats_total_user_question_answer_pairs from inbound sync - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}