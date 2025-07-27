import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';

Future<void> _verifyUserStatsRevisionStreakSumTable(Database db) async {
  QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: Starting table verification...');
  QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: About to query sqlite_master for table existence...');
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='user_stats_revision_streak_sum'"
  );
  QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: Table check completed, found ${tables.length} tables');

  if (tables.isEmpty) {
    QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: Table does not exist, creating it...');
    QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: About to execute CREATE TABLE...');
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
    QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: Table exists, checking columns...');
    QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: About to query PRAGMA table_info...');
    final List<Map<String, dynamic>> columns = await db.rawQuery(
      "PRAGMA table_info(user_stats_revision_streak_sum)"
    );
    QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: Column check completed, found ${columns.length} columns');
    final Set<String> columnNames = columns.map((col) => col['name'] as String).toSet();
    QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: Column names: ${columnNames.join(', ')}');
    
    if (!columnNames.contains('has_been_synced')) {
      QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: Adding has_been_synced column...');
      await db.execute('ALTER TABLE user_stats_revision_streak_sum ADD COLUMN has_been_synced INTEGER DEFAULT 0');
      QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: has_been_synced column added successfully');
    }
    if (!columnNames.contains('edits_are_synced')) {
      QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: Adding edits_are_synced column...');
      await db.execute('ALTER TABLE user_stats_revision_streak_sum ADD COLUMN edits_are_synced INTEGER DEFAULT 0');
      QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: edits_are_synced column added successfully');
    }
    if (!columnNames.contains('last_modified_timestamp')) {
      QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: Adding last_modified_timestamp column...');
      await db.execute('ALTER TABLE user_stats_revision_streak_sum ADD COLUMN last_modified_timestamp TEXT');
      QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: last_modified_timestamp column added successfully');
    }
  }
  QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: Table verification completed successfully.');
}

/// Updates the revision streak sum stat for a user for today (YYYY-MM-DD).
Future<void> updateRevisionStreakSumStat(String userId) async {
  try {
    // Get active questions in circulation using the proper function
    final List<Map<String, dynamic>> activeQuestionsInCirculation = await getActiveQuestionsInCirculation(userId);
    
    // Group by revision_streak and count
    final Map<int, int> revisionStreakCounts = {};
    for (final question in activeQuestionsInCirculation) {
      final int revisionStreak = question['revision_streak'] as int? ?? 0;
      revisionStreakCounts[revisionStreak] = (revisionStreakCounts[revisionStreak] ?? 0) + 1;
    }
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    await _verifyUserStatsRevisionStreakSumTable(db!);
    
    // Delete existing records for today
    await db.delete(
      'user_stats_revision_streak_sum',
      where: 'user_id = ? AND record_date = ?',
      whereArgs: [userId, today],
    );
    
    // Insert new records for each revision streak
    for (final entry in revisionStreakCounts.entries) {
      final int revisionStreak = entry.key;
      final int count = entry.value;
      final Map<String, dynamic> data = {
        'user_id': userId,
        'record_date': today,
        'revision_streak_score': revisionStreak,
        'question_count': count,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      await insertRawData('user_stats_revision_streak_sum', data, db, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    QuizzerLogger.logSuccess('Updated revision streak sum stat for user $userId on $today with ${revisionStreakCounts.length} streak levels');
  } catch (e) {
    QuizzerLogger.logError('Error updating revision streak sum stat for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<List<Map<String, dynamic>>> getUserStatsRevisionStreakSumRecordsByUser(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: Starting getUserStatsRevisionStreakSumRecordsByUser for user $userId');
    QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: About to call verifyUserStatsRevisionStreakSumTable...');
    await _verifyUserStatsRevisionStreakSumTable(db);
    QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: Table verification completed, calling queryAndDecodeDatabase...');
    final result = await queryAndDecodeDatabase(
      'user_stats_revision_streak_sum',
      db,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: queryAndDecodeDatabase completed, returning ${result.length} records');
    return result;
  } catch (e) {
    QuizzerLogger.logError('Error getting revision streak sum records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<List<Map<String, dynamic>>> getUserStatsRevisionStreakSumRecordsByDate(String userId, String recordDate) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: Starting getUserStatsRevisionStreakSumRecordsByDate for user $userId, date $recordDate');
    QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: About to call verifyUserStatsRevisionStreakSumTable...');
    await _verifyUserStatsRevisionStreakSumTable(db);
    QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: Table verification completed, calling queryAndDecodeDatabase...');
    final result = await queryAndDecodeDatabase(
      'user_stats_revision_streak_sum',
      db,
      where: 'user_id = ? AND record_date = ?',
      whereArgs: [userId, recordDate],
    );
    QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: queryAndDecodeDatabase completed, returning ${result.length} records');
    return result;
  } catch (e) {
    QuizzerLogger.logError('Error getting revision streak sum records for user ID: $userId, date: $recordDate - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<List<Map<String, dynamic>>> getTodayUserStatsRevisionStreakSumRecords(String userId) async {
  QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: Starting getTodayUserStatsRevisionStreakSumRecords for user $userId');
  final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: Today date is $today');
  final result = await getUserStatsRevisionStreakSumRecordsByDate(userId, today);
  QuizzerLogger.logMessage('user_stats_revision_streak_sum_table: getTodayUserStatsRevisionStreakSumRecords completed, returning ${result.length} records');
  return result;
}

Future<List<Map<String, dynamic>>> getUnsyncedUserStatsRevisionStreakSumRecords(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching unsynced revision streak sum records for user: $userId...');
    await _verifyUserStatsRevisionStreakSumTable(db);
    final List<Map<String, dynamic>> results = await db.query(
      'user_stats_revision_streak_sum',
      where: '(has_been_synced = 0 OR edits_are_synced = 0) AND user_id = ?',
      whereArgs: [userId],
    );
    QuizzerLogger.logSuccess('Fetched ${results.length} unsynced revision streak sum records for user $userId.');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced revision streak sum records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<void> updateUserStatsRevisionStreakSumSyncFlags({
  required String userId,
  required String recordDate,
  required int revisionStreakScore,
  required bool hasBeenSynced,
  required bool editsAreSynced,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Updating sync flags for revision streak sum record (User: $userId, Date: $recordDate, Streak: $revisionStreakScore) -> Synced: $hasBeenSynced, Edits Synced: $editsAreSynced');
    await _verifyUserStatsRevisionStreakSumTable(db);
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
  } catch (e) {
    QuizzerLogger.logError('Error updating sync flags for revision streak sum record (User: $userId, Date: $recordDate, Streak: $revisionStreakScore) - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<void> upsertUserStatsRevisionStreakSumFromInboundSync(Map<String, dynamic> record) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    
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

    await _verifyUserStatsRevisionStreakSumTable(db);

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
  } catch (e) {
    QuizzerLogger.logError('Error upserting user_stats_revision_streak_sum from inbound sync - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}
