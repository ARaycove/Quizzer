import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import '../../table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

Future<void> verifyUserStatsEligibleQuestionsTable(dynamic db) async {
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
    // Get the count of eligible questions using the proper function
    final List<Map<String, dynamic>> eligibleQuestions = await getEligibleUserQuestionAnswerPairs(userId);
    final int eligibleCount = eligibleQuestions.length;
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    // Get today's date in YYYY-MM-DD format
    final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);

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
      await insertRawData('user_stats_eligible_questions', data, db, conflictAlgorithm: ConflictAlgorithm.replace);
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
    
    // Update SessionManager cache with the current value
    final SessionManager sessionManager = SessionManager();
    sessionManager.setCachedEligibleQuestionsCount(eligibleCount);
    
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
    final List<Map<String, dynamic>> results = await db!.query(
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


Future<void> batchUpsertUserStatsEligibleQuestionsFromInboundSync({
  required List<Map<String, dynamic>> userStatsEligibleQuestionsRecords,
  required dynamic db
  }) async {
  try {
    // Ensure required fields are present
    for (Map<String, dynamic> statRecord in userStatsEligibleQuestionsRecords) {
      // Define the data mpa we are entering explicitly
      final Map<String, dynamic> dataToInsertOrUpdate = {
        'user_id': statRecord['user_id'],
        'record_date': statRecord['record_date'],
        'eligible_questions_count': statRecord['eligible_questions_count'],
        'has_been_synced': 1,
        'edits_are_synced': 1,
        'last_modified_timestamp': statRecord['last_modified_timestamp'],
      };

      await insertRawData(
        'user_stats_eligible_questions',
        dataToInsertOrUpdate,
        db,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  } catch (e) {
    QuizzerLogger.logError('Error upserting eligible questions record from inbound sync - $e');
    rethrow;
  }
}
