// TODO Refactor all individual stat record tables into a single unified table with all fields:
// * [x] Handle missing daily records
// * [x] Update login initialization to verify this table on login 

// * [] TODO Update SUPABASE with table
// * [] TODO Update SUPABASE with RLS policies

// * [] TODO Connect to inbound sync 
// * [] TODO Connect to outbound sync

// Consolidated daily user statistics table
// All user performance metrics aggregated by date in a single table

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart';
import 'dart:math';

final List<Map<String, String>> expectedColumns = [
  // Primary key
  {'name': 'user_id',                           'type': 'TEXT NOT NULL'},
  {'name': 'record_date',                       'type': 'TEXT NOT NULL'},
  // ==================================================
  // Learning Rate
  // ==================================================
  {'name': 'avg_daily_questions_learned',       'type': 'REAL DEFAULT 0'},
  {'name': 'total_eligible_questions',          'type': 'INTEGER DEFAULT 0'},
  {'name': 'total_in_circ_questions',           'type': 'INTEGER DEFAULT 0'},
  {'name': 'total_non_circ_questions',          'type': 'INTEGER DEFAULT 0'},
  // ==================================================
  // Global Accuracy and Performance
  // ==================================================
  // accuracy
  {'name': 'total_correct_attempts',            'type': 'INTEGER DEFAULT 0'},
  {'name': 'total_incorrect_attempts',          'type': 'INTEGER DEFAULT 0'},
  {'name': 'total_attempts',                    'type': 'INTEGER DEFAULT 0'},
  {'name': 'global_accuracy',                   'type': 'REAL DEFAULT 1'},
    // -- By Multiple choice question type
  {'name': 'total_mcq_correct_attempts',        'type': 'INTEGER DEFAULT 0'},
  {'name': 'total_mcq_incorrrect_attempts',     'type': 'INTEGER DEFAULT 0'},
  {'name': 'total_mcq_attempts',                'type': 'INTEGER DEFAULT 0'},
  {'name': 'global_mcq_accuracy',               'type': 'REAL DEFAULT 1'},
    // -- By fill in the blank q-type
  {'name': 'total_fitb_correct_attempts',        'type': 'INTEGER DEFAULT 0'},
  {'name': 'total_fitb_incorrrect_attempts',     'type': 'INTEGER DEFAULT 0'},
  {'name': 'total_fitb_attempts',                'type': 'INTEGER DEFAULT 0'},
  {'name': 'global_fitb_accuracy',               'type': 'REAL DEFAULT 1'},
    // -- By select all that apply q-type
  {'name': 'total_sata_correct_attempts',        'type': 'INTEGER DEFAULT 0'},
  {'name': 'total_sata_incorrrect_attempts',     'type': 'INTEGER DEFAULT 0'},
  {'name': 'total_sata_attempts',                'type': 'INTEGER DEFAULT 0'},
  {'name': 'global_sata_accuracy',               'type': 'REAL DEFAULT 1'},
    // -- By true-false q-type
  {'name': 'total_tf_correct_attempts',        'type': 'INTEGER DEFAULT 0'},
  {'name': 'total_tf_incorrrect_attempts',     'type': 'INTEGER DEFAULT 0'},
  {'name': 'total_tf_attempts',                'type': 'INTEGER DEFAULT 0'},
  {'name': 'global_tf_accuracy',               'type': 'REAL DEFAULT 1'},
    // -- By sort order q-type
  {'name': 'total_so_correct_attempts',        'type': 'INTEGER DEFAULT 0'},
  {'name': 'total_so_incorrrect_attempts',     'type': 'INTEGER DEFAULT 0'},
  {'name': 'total_so_attempts',                'type': 'INTEGER DEFAULT 0'},
  {'name': 'global_so_accuracy',               'type': 'REAL DEFAULT 1'},
  // Other
  {'name': 'consecutive_correct_streak',        'type': 'INTEGER DEFAULT 0'},
  {'name': 'consecutive_incorrect_streak',      'type': 'INTEGER DEFAULT 0'},
  {'name': 'max_correct_streak_achieved',       'type': 'INTEGER DEFAULT 0'},
  {'name': 'revision_streak_sum',               'type': 'TEXT DEFAULT "[]"'},
  // ==================================================
  // Today Only Accuracy and Performance
  // ==================================================
  {'name': 'today_correct_attempts',            'type': 'INTEGER DEFAULT 0'},
  {'name': 'today_incorrect_attempts',          'type': 'INTEGER DEFAULT 0'},
  {'name': 'today_total_attempts',              'type': 'INTEGER DEFAULT 0'},
  {'name': 'today_accuracy_rate',               'type': 'REAL DEFAULT 1'},
    // -- By Multiple choice question type
  {'name': 'today_mcq_correct_attempts',        'type': 'INTEGER DEFAULT 0'},
  {'name': 'today_mcq_incorrect_attempts',      'type': 'INTEGER DEFAULT 0'},
  {'name': 'today_mcq_total_attempts',          'type': 'INTEGER DEFAULT 0'},
  {'name': 'today_mcq_accuracy_rate',           'type': 'REAL DEFAULT 1'},
    // -- By fill in the blank q-type
  {'name': 'today_fitb_correct_attempts',       'type': 'INTEGER DEFAULT 0'},
  {'name': 'today_fitb_incorrect_attempts',     'type': 'INTEGER DEFAULT 0'},
  {'name': 'today_fitb_total_attempts',         'type': 'INTEGER DEFAULT 0'},
  {'name': 'today_fitb_accuracy_rate',          'type': 'REAL DEFAULT 1'},
    // -- By select all that apply q-type
  {'name': 'today_sata_correct_attempts',       'type': 'INTEGER DEFAULT 0'},
  {'name': 'today_sata_incorrect_attempts',     'type': 'INTEGER DEFAULT 0'},
  {'name': 'today_sata_total_attempts',         'type': 'INTEGER DEFAULT 0'},
  {'name': 'today_sata_accuracy_rate',          'type': 'REAL DEFAULT 1'},
    // -- By true-false q-type
  {'name': 'today_tf_correct_attempts',         'type': 'INTEGER DEFAULT 0'},
  {'name': 'today_tf_incorrect_attempts',       'type': 'INTEGER DEFAULT 0'},
  {'name': 'today_tf_total_attempts',           'type': 'INTEGER DEFAULT 0'},
  {'name': 'today_tf_accuracy_rate',            'type': 'REAL DEFAULT 1'},
    // -- By sort order q-type
  {'name': 'today_so_correct_attempts',         'type': 'INTEGER DEFAULT 0'},
  {'name': 'today_so_incorrect_attempts',       'type': 'INTEGER DEFAULT 0'},
  {'name': 'today_so_total_attempts',           'type': 'INTEGER DEFAULT 0'},
  {'name': 'today_so_accuracy_rate',            'type': 'REAL DEFAULT 1'},

  // ==================================================
  // Other Averages
  // ==================================================
  {'name': 'avg_reaction_time',                 'type': 'REAL DEFAULT 0'},
  // ==================================================
  // Complex engineered features
  // ==================================================
  {'name': 'days_left_until_questions_exhaust',   'type': 'REAL DEFAULT 0'},
  // ==================================================
  // Sync fields
  // ==================================================
  {'name': 'has_been_synced',                   'type': 'INTEGER DEFAULT 0'},
  {'name': 'edits_are_synced',                  'type': 'INTEGER DEFAULT 0'},
  {'name': 'last_modified_timestamp',           'type': 'TEXT'},
];

Future<void> verifyUserDailyStatsTable(dynamic db) async {
  try {
    QuizzerLogger.logMessage('Verifying user_daily_stats table existence');
    
    // Check if the table exists
    final List<Map<String, dynamic>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      ['user_daily_stats']
    );

    if (tables.isEmpty) {
      // Create the table if it doesn't exist
      QuizzerLogger.logMessage('user_daily_stats table not found, creating...');
      
      String createTableSQL = 'CREATE TABLE user_daily_stats(\n';
      createTableSQL += expectedColumns.map((col) => '  ${col['name']} ${col['type']}').join(',\n');
      createTableSQL += ',\n  PRIMARY KEY (user_id, record_date)\n)';
      
      await db.execute(createTableSQL);
      QuizzerLogger.logSuccess('user_daily_stats table created successfully.');
    } else {
      // Table exists, check for column differences
      QuizzerLogger.logMessage('user_daily_stats table already exists. Checking column structure...');
      
      // Get current table structure
      final List<Map<String, dynamic>> currentColumns = await db.rawQuery(
        "PRAGMA table_info(user_daily_stats)"
      );
      
      final Set<String> currentColumnNames = currentColumns
          .map((column) => column['name'] as String)
          .toSet();
      
      final Set<String> expectedColumnNames = expectedColumns
          .map((column) => column['name']!)
          .toSet();
      
      // Find columns to add (expected but not current)
      final Set<String> columnsToAdd = expectedColumnNames.difference(currentColumnNames);
      
      // Find columns to remove (current but not expected)
      final Set<String> columnsToRemove = currentColumnNames.difference(expectedColumnNames);
      
      // Add missing columns
      for (String columnName in columnsToAdd) {
        final columnDef = expectedColumns.firstWhere((col) => col['name'] == columnName);
        QuizzerLogger.logMessage('Adding missing column: $columnName');
        await db.execute('ALTER TABLE user_daily_stats ADD COLUMN ${columnDef['name']} ${columnDef['type']}');
      }
      
      // Remove unexpected columns (SQLite doesn't support DROP COLUMN directly)
      if (columnsToRemove.isNotEmpty) {
        QuizzerLogger.logMessage('Removing unexpected columns: ${columnsToRemove.join(', ')}');
        
        // Create temporary table with only expected columns
        String tempTableSQL = 'CREATE TABLE user_daily_stats_temp(\n';
        tempTableSQL += expectedColumns.map((col) => '  ${col['name']} ${col['type']}').join(',\n');
        tempTableSQL += ',\n  PRIMARY KEY (user_id, record_date)\n)';
        
        await db.execute(tempTableSQL);
        
        // Copy data from old table to temp table (only expected columns)
        String columnList = expectedColumnNames.join(', ');
        await db.execute('INSERT INTO user_daily_stats_temp ($columnList) SELECT $columnList FROM user_daily_stats');
        
        // Drop old table and rename temp table
        await db.execute('DROP TABLE user_daily_stats');
        await db.execute('ALTER TABLE user_daily_stats_temp RENAME TO user_daily_stats');
        
        QuizzerLogger.logSuccess('Removed unexpected columns and restructured table');
      }
      
      if (columnsToAdd.isEmpty && columnsToRemove.isEmpty) {
        QuizzerLogger.logMessage('Table structure is already up to date');
      } else {
        QuizzerLogger.logSuccess('Table structure updated successfully');
      }
    }
  } catch (e) {
    QuizzerLogger.logError('Error verifying user_daily_stats table - $e');
    rethrow;
  }
}

/// Average stats use historical averages, running totals carry forward, daily metrics default to 0.
Future<void> fillMissingDailyStatRecords(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) throw Exception('Failed to acquire database access');
    
    final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    
    // Get most recent record
    final recentRecords = await queryAndDecodeDatabase('user_daily_stats', db,
      where: 'user_id = ?', whereArgs: [userId], orderBy: 'record_date DESC', limit: 1);
    
    final missingDates = <String>[];
    Map<String, dynamic> carryForwardValues = {};
    
    if (recentRecords.isEmpty) {
      // Fresh account - create today's record with SQL defaults
      missingDates.add(today);
    } else {
      // Existing account - fill gap from last record to today
      final lastDate = DateTime.parse(recentRecords.first['record_date']);
      final endDateTime = DateTime.parse(today);
      carryForwardValues = _extractRunningTotals(recentRecords.first);
      
      DateTime current = lastDate.add(const Duration(days: 1));
      while (current.isBefore(endDateTime.add(const Duration(days: 1)))) {
        missingDates.add(current.toIso8601String().substring(0, 10));
        current = current.add(const Duration(days: 1));
      }
    }
    
    if (missingDates.isEmpty) return;
    
    // Insert missing records
    for (final date in missingDates) {
      final record = _buildMissingRecord(userId, date, carryForwardValues);
      await insertRawData('user_daily_stats', record, db, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    
    QuizzerLogger.logSuccess('Filled ${missingDates.length} missing records for user $userId');
  } catch (e) {
    QuizzerLogger.logError('Error filling missing daily stats for user $userId: $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Map<String, dynamic> _extractRunningTotals(Map<String, dynamic> recent) {
  const carryForwardFields = [
    // Running totals
    'total_correct_attempts', 'total_incorrect_attempts', 'total_attempts',
    'total_in_circ_questions', 'total_non_circ_questions', 'total_eligible_questions',
    // Global cumulative metrics (NOT temporal)
    'global_accuracy_rate', 'avg_reaction_time', 'days_left_until_questions_exhaust',
    // Other non-daily fields that should carry forward
    'consecutive_correct_streak', 'consecutive_incorrect_streak', 'max_correct_streak_achieved',
    'avg_daily_questions_learned', 'revision_streak_sum'
  ];
  
  return Map.fromEntries(carryForwardFields.where((f) => recent.containsKey(f)).map((f) => MapEntry(f, recent[f] ?? 0)));
}

/// Fills missing daily stat records between last recorded date and today.
Map<String, dynamic> _buildMissingRecord(String userId, String date, Map<String, dynamic> carryForward) {
  return {
    'user_id': userId,
    'record_date': date,
    'has_been_synced': 0,
    'edits_are_synced': 0,
    'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    ...carryForward,
  };
}

/// Updates all daily stats for a user for today (YYYY-MM-DD).
/// Consolidates all stat calculations into separate optimized queries.
Future<void> updateAllUserDailyStats(String userId, {bool? isCorrect, double? reactionTime, String? questionId}) async {
  try {
    await fillMissingDailyStatRecords(userId);
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    
    final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final String nowUtc = DateTime.now().toUtc().toIso8601String();
    
    QuizzerLogger.logMessage('Updating all daily stats for user: $userId on $today');
    
    // Query 1: Eligible questions count
    const eligibleQuery = '''
      SELECT COUNT(*) as eligible_count
      FROM user_question_answer_pairs uqap
      INNER JOIN question_answer_pairs qap ON uqap.question_id = qap.question_id
      INNER JOIN user_module_activation_status umas ON uqap.user_uuid = umas.user_id AND qap.module_name = umas.module_name
      WHERE uqap.user_uuid = ? AND uqap.in_circulation = 1 AND uqap.next_revision_due < ? AND uqap.flagged = 0 AND umas.is_active = 1
    ''';
    
    final eligibleResults = await db.rawQuery(eligibleQuery, [userId, nowUtc]);
    final int totalEligibleQuestions = (eligibleResults.first['eligible_count'] as int?) ?? 0;

    // Query 2: Circulation counts
    const circulationQuery = '''
      SELECT 
        SUM(CASE WHEN uqap.in_circulation = 1 AND uqap.flagged = 0 AND umas.is_active = 1 THEN 1 ELSE 0 END) as in_circ_count,
        SUM(CASE WHEN uqap.in_circulation = 0 AND uqap.flagged = 0 AND umas.is_active = 1 THEN 1 ELSE 0 END) as non_circ_count
      FROM user_question_answer_pairs uqap
      INNER JOIN question_answer_pairs qap ON uqap.question_id = qap.question_id
      INNER JOIN user_module_activation_status umas ON uqap.user_uuid = umas.user_id AND qap.module_name = umas.module_name
      WHERE uqap.user_uuid = ?
    ''';
    
    final circulationResults = await db.rawQuery(circulationQuery, [userId]);
    final int totalInCircQuestions = (circulationResults.first['in_circ_count'] as int?) ?? 0;
    final int totalNonCircQuestions = (circulationResults.first['non_circ_count'] as int?) ?? 0;

    // Query 3: Current question type (if provided)
    String? currentQuestionType;
    if (questionId != null && questionId.isNotEmpty) {
      const questionTypeQuery = '''
        SELECT qap.question_type
        FROM question_answer_pairs qap
        WHERE qap.question_id = ?
        LIMIT 1
      ''';
      
      final questionTypeResults = await db.rawQuery(questionTypeQuery, [questionId]);
      currentQuestionType = questionTypeResults.isNotEmpty 
          ? (questionTypeResults.first['question_type'] as String?) 
          : null;
    }

    // Query 4: Accuracy stats
    const accuracyQuery = '''
      SELECT 
        SUM(uqap.total_correct_attempts) as total_correct,
        SUM(uqap.total_incorect_attempts) as total_incorrect,
        SUM(CASE WHEN qap.question_type = 'multiple_choice' THEN uqap.total_correct_attempts ELSE 0 END) as mcq_correct,
        SUM(CASE WHEN qap.question_type = 'multiple_choice' THEN uqap.total_incorect_attempts ELSE 0 END) as mcq_incorrect,
        SUM(CASE WHEN qap.question_type = 'fill_in_the_blank' THEN uqap.total_correct_attempts ELSE 0 END) as fitb_correct,
        SUM(CASE WHEN qap.question_type = 'fill_in_the_blank' THEN uqap.total_incorect_attempts ELSE 0 END) as fitb_incorrect,
        SUM(CASE WHEN qap.question_type = 'select_all_that_apply' THEN uqap.total_correct_attempts ELSE 0 END) as sata_correct,
        SUM(CASE WHEN qap.question_type = 'select_all_that_apply' THEN uqap.total_incorect_attempts ELSE 0 END) as sata_incorrect,
        SUM(CASE WHEN qap.question_type = 'true_false' THEN uqap.total_correct_attempts ELSE 0 END) as tf_correct,
        SUM(CASE WHEN qap.question_type = 'true_false' THEN uqap.total_incorect_attempts ELSE 0 END) as tf_incorrect,
        SUM(CASE WHEN qap.question_type = 'sort_order' THEN uqap.total_correct_attempts ELSE 0 END) as so_correct,
        SUM(CASE WHEN qap.question_type = 'sort_order' THEN uqap.total_incorect_attempts ELSE 0 END) as so_incorrect
      FROM user_question_answer_pairs uqap
      INNER JOIN question_answer_pairs qap ON uqap.question_id = qap.question_id
      WHERE uqap.user_uuid = ?
    ''';
    
    final accuracyResults = await db.rawQuery(accuracyQuery, [userId]);
    final Map<String, dynamic> accuracyData = accuracyResults.isNotEmpty ? accuracyResults.first : {};

    // Query 5: Existing daily stats
    const dailyStatsQuery = '''
      SELECT 
        COALESCE(consecutive_correct_streak, 0) as current_correct_streak,
        COALESCE(consecutive_incorrect_streak, 0) as current_incorrect_streak,
        COALESCE(max_correct_streak_achieved, 0) as max_correct_streak,
        COALESCE(today_correct_attempts, 0) as today_correct,
        COALESCE(today_incorrect_attempts, 0) as today_incorrect,
        COALESCE(today_mcq_correct_attempts, 0) as today_mcq_correct,
        COALESCE(today_mcq_incorrect_attempts, 0) as today_mcq_incorrect,
        COALESCE(today_fitb_correct_attempts, 0) as today_fitb_correct,
        COALESCE(today_fitb_incorrect_attempts, 0) as today_fitb_incorrect,
        COALESCE(today_sata_correct_attempts, 0) as today_sata_correct,
        COALESCE(today_sata_incorrect_attempts, 0) as today_sata_incorrect,
        COALESCE(today_tf_correct_attempts, 0) as today_tf_correct,
        COALESCE(today_tf_incorrect_attempts, 0) as today_tf_incorrect,
        COALESCE(today_so_correct_attempts, 0) as today_so_correct,
        COALESCE(today_so_incorrect_attempts, 0) as today_so_incorrect,
        COALESCE(avg_reaction_time, 0.0) as current_avg_reaction_time,
        COALESCE(avg_daily_questions_learned, 0.0) as current_avg_daily_learned
      FROM user_daily_stats
      WHERE user_id = ? AND record_date = ?
      LIMIT 1
    ''';
    
    final dailyStatsResults = await db.rawQuery(dailyStatsQuery, [userId, today]);
    final Map<String, dynamic> dailyStatsData = dailyStatsResults.isNotEmpty 
        ? dailyStatsResults.first 
        : {
            'current_correct_streak': 0,
            'current_incorrect_streak': 0,
            'max_correct_streak': 0,
            'today_correct': 0,
            'today_incorrect': 0,
            'today_mcq_correct': 0,
            'today_mcq_incorrect': 0,
            'today_fitb_correct': 0,
            'today_fitb_incorrect': 0,
            'today_sata_correct': 0,
            'today_sata_incorrect': 0,
            'today_tf_correct': 0,
            'today_tf_incorrect': 0,
            'today_so_correct': 0,
            'today_so_incorrect': 0,
            'current_avg_reaction_time': 0.0,
            'current_avg_daily_learned': 0.0,
          };

    // Query 6: Revision streak distribution
    const revisionStreakQuery = '''
      SELECT 
        uqap.revision_streak,
        COUNT(*) as count
      FROM user_question_answer_pairs uqap
      INNER JOIN question_answer_pairs qap ON uqap.question_id = qap.question_id
      INNER JOIN user_module_activation_status umas ON uqap.user_uuid = umas.user_id AND qap.module_name = umas.module_name
      WHERE uqap.user_uuid = ? AND uqap.in_circulation = 1 AND uqap.flagged = 0 AND umas.is_active = 1
      GROUP BY uqap.revision_streak
    ''';
    
    final revisionStreakResults = await db.rawQuery(revisionStreakQuery, [userId]);
    final List<String> streakJsonList = revisionStreakResults.map((row) {
      return '{"revision_streak":${row['revision_streak']},"count":${row['count']}}';
    }).toList();
    final String revisionStreakSum = '[${streakJsonList.join(',')}]';
    
    // Helper function for precision formatting
    double formatPrecision(double value, int decimals) => 
        double.parse(value.toStringAsFixed(decimals));
    
    // Extract and validate data with safe defaults
    final double avgDailyQuestionsLearned = (dailyStatsData['current_avg_daily_learned'] as double?) ?? 0.0;
    
    // Extract accuracy stats
    int totalCorrectAttempts = (accuracyData['total_correct'] as int?) ?? 0;
    int totalIncorrectAttempts = (accuracyData['total_incorrect'] as int?) ?? 0;
    int mcqCorrect = (accuracyData['mcq_correct'] as int?) ?? 0;
    int mcqIncorrect = (accuracyData['mcq_incorrect'] as int?) ?? 0;
    int fitbCorrect = (accuracyData['fitb_correct'] as int?) ?? 0;
    int fitbIncorrect = (accuracyData['fitb_incorrect'] as int?) ?? 0;
    int sataCorrect = (accuracyData['sata_correct'] as int?) ?? 0;
    int sataIncorrect = (accuracyData['sata_incorrect'] as int?) ?? 0;
    int tfCorrect = (accuracyData['tf_correct'] as int?) ?? 0;
    int tfIncorrect = (accuracyData['tf_incorrect'] as int?) ?? 0;
    int soCorrect = (accuracyData['so_correct'] as int?) ?? 0;
    int soIncorrect = (accuracyData['so_incorrect'] as int?) ?? 0;
    
    // Extract today's data
    int todayCorrectAttempts = (dailyStatsData['today_correct'] as int?) ?? 0;
    int todayIncorrectAttempts = (dailyStatsData['today_incorrect'] as int?) ?? 0;
    int todayMcqCorrect = (dailyStatsData['today_mcq_correct'] as int?) ?? 0;
    int todayMcqIncorrect = (dailyStatsData['today_mcq_incorrect'] as int?) ?? 0;
    int todayFitbCorrect = (dailyStatsData['today_fitb_correct'] as int?) ?? 0;
    int todayFitbIncorrect = (dailyStatsData['today_fitb_incorrect'] as int?) ?? 0;
    int todaySataCorrect = (dailyStatsData['today_sata_correct'] as int?) ?? 0;
    int todaySataIncorrect = (dailyStatsData['today_sata_incorrect'] as int?) ?? 0;
    int todayTfCorrect = (dailyStatsData['today_tf_correct'] as int?) ?? 0;
    int todayTfIncorrect = (dailyStatsData['today_tf_incorrect'] as int?) ?? 0;
    int todaySoCorrect = (dailyStatsData['today_so_correct'] as int?) ?? 0;
    int todaySoIncorrect = (dailyStatsData['today_so_incorrect'] as int?) ?? 0;
    
    int consecutiveCorrectStreak = (dailyStatsData['current_correct_streak'] as int?) ?? 0;
    int consecutiveIncorrectStreak = (dailyStatsData['current_incorrect_streak'] as int?) ?? 0;
    int maxCorrectStreakAchieved = (dailyStatsData['max_correct_streak'] as int?) ?? 0;
    double currentAvgReactionTime = (dailyStatsData['current_avg_reaction_time'] as double?) ?? 0.0;
    
    // Update today's attempts if this is a new answer
    if (isCorrect != null) {
      todayCorrectAttempts += isCorrect ? 1 : 0;
      todayIncorrectAttempts += isCorrect ? 0 : 1;
      totalCorrectAttempts += isCorrect ? 1 : 0;
      totalIncorrectAttempts += isCorrect ? 0 : 1;
      
      // Update streaks
      if (isCorrect) {
        consecutiveCorrectStreak += 1;
        consecutiveIncorrectStreak = 0;
        maxCorrectStreakAchieved = max(maxCorrectStreakAchieved, consecutiveCorrectStreak);
      } else {
        consecutiveIncorrectStreak += 1;
        consecutiveCorrectStreak = 0;
      }
      
      // Update question-type specific stats for today
      if (currentQuestionType != null) {
        switch (currentQuestionType) {
          case 'multiple_choice':
            todayMcqCorrect += isCorrect ? 1 : 0;
            todayMcqIncorrect += isCorrect ? 0 : 1;
            mcqCorrect += isCorrect ? 1 : 0;
            mcqIncorrect += isCorrect ? 0 : 1;
            break;
          case 'fill_in_the_blank':
            todayFitbCorrect += isCorrect ? 1 : 0;
            todayFitbIncorrect += isCorrect ? 0 : 1;
            fitbCorrect += isCorrect ? 1 : 0;
            fitbIncorrect += isCorrect ? 0 : 1;
            break;
          case 'select_all_that_apply':
            todaySataCorrect += isCorrect ? 1 : 0;
            todaySataIncorrect += isCorrect ? 0 : 1;
            sataCorrect += isCorrect ? 1 : 0;
            sataIncorrect += isCorrect ? 0 : 1;
            break;
          case 'true_false':
            todayTfCorrect += isCorrect ? 1 : 0;
            todayTfIncorrect += isCorrect ? 0 : 1;
            tfCorrect += isCorrect ? 1 : 0;
            tfIncorrect += isCorrect ? 0 : 1;
            break;
          case 'sort_order':
            todaySoCorrect += isCorrect ? 1 : 0;
            todaySoIncorrect += isCorrect ? 0 : 1;
            soCorrect += isCorrect ? 1 : 0;
            soIncorrect += isCorrect ? 0 : 1;
            break;
        }
      }
      
      // Update reaction time if provided
      if (reactionTime != null) {
        final int totalAttempts = totalCorrectAttempts + totalIncorrectAttempts;
        if (totalAttempts > 1) {
          // Calculate new average reaction time
          currentAvgReactionTime = ((currentAvgReactionTime * (totalAttempts - 1)) + reactionTime) / totalAttempts;
        } else {
          currentAvgReactionTime = reactionTime;
        }
      }
    }
    
    // Calculate totals and accuracy rates
    final int totalAttempts = totalCorrectAttempts + totalIncorrectAttempts;
    final double globalAccuracy = totalAttempts > 0 ? totalCorrectAttempts / totalAttempts : 0.0;
    
    final int mcqTotal = mcqCorrect + mcqIncorrect;
    final double mcqAccuracy = mcqTotal > 0 ? mcqCorrect / mcqTotal : 0.0;
    
    final int fitbTotal = fitbCorrect + fitbIncorrect;
    final double fitbAccuracy = fitbTotal > 0 ? fitbCorrect / fitbTotal : 0.0;
    
    final int sataTotal = sataCorrect + sataIncorrect;
    final double sataAccuracy = sataTotal > 0 ? sataCorrect / sataTotal : 0.0;
    
    final int tfTotal = tfCorrect + tfIncorrect;
    final double tfAccuracy = tfTotal > 0 ? tfCorrect / tfTotal : 0.0;
    
    final int soTotal = soCorrect + soIncorrect;
    final double soAccuracy = soTotal > 0 ? soCorrect / soTotal : 0.0;
    
    // Today's stats
    final int todayTotalAttempts = todayCorrectAttempts + todayIncorrectAttempts;
    final double todayAccuracyRate = todayTotalAttempts > 0 ? todayCorrectAttempts / todayTotalAttempts : 0.0;
    
    final int todayMcqTotal = todayMcqCorrect + todayMcqIncorrect;
    final double todayMcqAccuracyRate = todayMcqTotal > 0 ? todayMcqCorrect / todayMcqTotal : 0.0;
    
    final int todayFitbTotal = todayFitbCorrect + todayFitbIncorrect;
    final double todayFitbAccuracyRate = todayFitbTotal > 0 ? todayFitbCorrect / todayFitbTotal : 0.0;
    
    final int todaySataTotal = todaySataCorrect + todaySataIncorrect;
    final double todaySataAccuracyRate = todaySataTotal > 0 ? todaySataCorrect / todaySataTotal : 0.0;
    
    final int todayTfTotal = todayTfCorrect + todayTfIncorrect;
    final double todayTfAccuracyRate = todayTfTotal > 0 ? todayTfCorrect / todayTfTotal : 0.0;
    
    final int todaySoTotal = todaySoCorrect + todaySoIncorrect;
    final double todaySoAccuracyRate = todaySoTotal > 0 ? todaySoCorrect / todaySoTotal : 0.0;
    
    // Calculate days left until questions exhaust
    final double daysLeftUntilQuestionsExhaust = avgDailyQuestionsLearned > 0 
        ? totalNonCircQuestions / avgDailyQuestionsLearned 
        : 0.0;
    
    // Prepare consolidated update data
    final Map<String, dynamic> calculatedValues = {
      'user_id': userId,
      'record_date': today,
      'avg_daily_questions_learned': formatPrecision(avgDailyQuestionsLearned, 2),
      'total_eligible_questions': totalEligibleQuestions,
      'total_in_circ_questions': totalInCircQuestions,
      'total_non_circ_questions': totalNonCircQuestions,
      'total_correct_attempts': totalCorrectAttempts,
      'total_incorrect_attempts': totalIncorrectAttempts,
      'total_attempts': totalAttempts,
      'global_accuracy': formatPrecision(globalAccuracy, 6),
      'total_mcq_correct_attempts': mcqCorrect,
      'total_mcq_incorrrect_attempts': mcqIncorrect,
      'total_mcq_attempts': mcqTotal,
      'global_mcq_accuracy': formatPrecision(mcqAccuracy, 6),
      'total_fitb_correct_attempts': fitbCorrect,
      'total_fitb_incorrrect_attempts': fitbIncorrect,
      'total_fitb_attempts': fitbTotal,
      'global_fitb_accuracy': formatPrecision(fitbAccuracy, 6),
      'total_sata_correct_attempts': sataCorrect,
      'total_sata_incorrrect_attempts': sataIncorrect,
      'total_sata_attempts': sataTotal,
      'global_sata_accuracy': formatPrecision(sataAccuracy, 6),
      'total_tf_correct_attempts': tfCorrect,
      'total_tf_incorrrect_attempts': tfIncorrect,
      'total_tf_attempts': tfTotal,
      'global_tf_accuracy': formatPrecision(tfAccuracy, 6),
      'total_so_correct_attempts': soCorrect,
      'total_so_incorrrect_attempts': soIncorrect,
      'total_so_attempts': soTotal,
      'global_so_accuracy': formatPrecision(soAccuracy, 6),
      'consecutive_correct_streak': consecutiveCorrectStreak,
      'consecutive_incorrect_streak': consecutiveIncorrectStreak,
      'max_correct_streak_achieved': maxCorrectStreakAchieved,
      'revision_streak_sum': revisionStreakSum,
      'today_correct_attempts': todayCorrectAttempts,
      'today_incorrect_attempts': todayIncorrectAttempts,
      'today_total_attempts': todayTotalAttempts,
      'today_accuracy_rate': formatPrecision(todayAccuracyRate, 6),
      'today_mcq_correct_attempts': todayMcqCorrect,
      'today_mcq_incorrect_attempts': todayMcqIncorrect,
      'today_mcq_total_attempts': todayMcqTotal,
      'today_mcq_accuracy_rate': formatPrecision(todayMcqAccuracyRate, 6),
      'today_fitb_correct_attempts': todayFitbCorrect,
      'today_fitb_incorrect_attempts': todayFitbIncorrect,
      'today_fitb_total_attempts': todayFitbTotal,
      'today_fitb_accuracy_rate': formatPrecision(todayFitbAccuracyRate, 6),
      'today_sata_correct_attempts': todaySataCorrect,
      'today_sata_incorrect_attempts': todaySataIncorrect,
      'today_sata_total_attempts': todaySataTotal,
      'today_sata_accuracy_rate': formatPrecision(todaySataAccuracyRate, 6),
      'today_tf_correct_attempts': todayTfCorrect,
      'today_tf_incorrect_attempts': todayTfIncorrect,
      'today_tf_total_attempts': todayTfTotal,
      'today_tf_accuracy_rate': formatPrecision(todayTfAccuracyRate, 6),
      'today_so_correct_attempts': todaySoCorrect,
      'today_so_incorrect_attempts': todaySoIncorrect,
      'today_so_total_attempts': todaySoTotal,
      'today_so_accuracy_rate': formatPrecision(todaySoAccuracyRate, 6),
      'avg_reaction_time': formatPrecision(currentAvgReactionTime, 3),
      'days_left_until_questions_exhaust': formatPrecision(daysLeftUntilQuestionsExhaust, 2),
      'has_been_synced': 0,
      'edits_are_synced': 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    
    // Filter to only include fields that exist in expectedColumns
    final Map<String, dynamic> dataToUpsert = {};
    for (final col in expectedColumns) {
      final String fieldName = col['name']!;
      if (calculatedValues.containsKey(fieldName)) {
        dataToUpsert[fieldName] = calculatedValues[fieldName];
      }
    }

    // QuizzerLogger.logMessage("Stats have been updated, feed is:");
    // dataToUpsert.forEach((key, value) {
    //   QuizzerLogger.logMessage("${key.padRight(20)}, $value");
    // });
    
    // Insert or replace the record for today
    await insertRawData(
      'user_daily_stats',
      dataToUpsert,
      db,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    signalOutboundSyncNeeded(); // Trigger outbound sync to run, since this is the last update in the submitAnswer cahin
    
    QuizzerLogger.logSuccess('Updated all daily stats for user $userId on $today - Stats: eligible=$totalEligibleQuestions, accuracy=${formatPrecision(globalAccuracy, 3)}, today_attempts=$todayTotalAttempts');
  } catch (e) {
    QuizzerLogger.logError('Error updating all daily stats for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<List<Map<String, dynamic>>> getUserDailyStatsRecordsByUser(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    
    return await queryAndDecodeDatabase(
      'user_daily_stats',
      db,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'record_date DESC',
    );
  } catch (e) {
    QuizzerLogger.logError('Error getting daily stats records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<Map<String, dynamic>> getUserDailyStatsRecordByDate(String userId, String recordDate) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'user_daily_stats',
      db,
      where: 'user_id = ? AND record_date = ?',
      whereArgs: [userId, recordDate],
      limit: 2,
    );
    
    if (results.isEmpty) {
      QuizzerLogger.logMessage('No daily stats record found for userId: $userId and date: $recordDate.');
      throw StateError('No record found for user $userId, date $recordDate');
    } else if (results.length > 1) {
      QuizzerLogger.logError('Multiple records found for userId: $userId and date: $recordDate. PK constraint violation?');
      throw StateError('Multiple records for PK user $userId, date $recordDate');
    }
    
    QuizzerLogger.logSuccess('Fetched daily stats record for User: $userId, Date: $recordDate');
    return results.first;
  } catch (e) {
    QuizzerLogger.logError('Error getting daily stats record for user ID: $userId, date: $recordDate - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<Map<String, dynamic>> getTodayUserDailyStatsRecord(String userId) async {
  try {
    final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    return await getUserDailyStatsRecordByDate(userId, today);
  } catch (e) {
    QuizzerLogger.logError('Error getting today\'s daily stats record for user ID: $userId - $e');
    rethrow;
  }
}

Future<List<Map<String, dynamic>>> getUnsyncedUserDailyStatsRecords(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    
    QuizzerLogger.logMessage('Fetching unsynced daily stats records for user: $userId...');
    
    final List<Map<String, dynamic>> results = await db.query(
      'user_daily_stats',
      where: '(has_been_synced = 0 OR edits_are_synced = 0) AND user_id = ?',
      whereArgs: [userId],
    );
    
    QuizzerLogger.logSuccess('Fetched ${results.length} unsynced daily stats records for user $userId.');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced daily stats records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<void> updateUserDailyStatsSyncFlags({
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
    
    QuizzerLogger.logMessage('Updating sync flags for daily stats record (User: $userId, Date: $recordDate) -> Synced: $hasBeenSynced, Edits Synced: $editsAreSynced');
    
    final Map<String, dynamic> calculatedValues = {
      'has_been_synced': hasBeenSynced ? 1 : 0,
      'edits_are_synced': editsAreSynced ? 1 : 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    
    // Only include fields that exist in expectedColumns
    final Map<String, dynamic> updates = {};
    for (final col in expectedColumns) {
      final String fieldName = col['name']!;
      if (calculatedValues.containsKey(fieldName)) {
        updates[fieldName] = calculatedValues[fieldName];
      }
    }
    
    final int rowsAffected = await updateRawData(
      'user_daily_stats',
      updates,
      'user_id = ? AND record_date = ?',
      [userId, recordDate],
      db,
    );
    
    if (rowsAffected == 0) {
      QuizzerLogger.logWarning('updateUserDailyStatsSyncFlags affected 0 rows for daily stats record (User: $userId, Date: $recordDate). Record might not exist?');
    } else {
      QuizzerLogger.logSuccess('Successfully updated sync flags for daily stats record (User: $userId, Date: $recordDate).');
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating sync flags for daily stats record (User: $userId, Date: $recordDate) - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<void> batchUpsertUserDailyStatsFromInboundSync({
  required List<Map<String, dynamic>> userDailyStatsRecords,
  required dynamic db,
}) async {
  try {
    for (Map<String, dynamic> statRecord in userDailyStatsRecords) {
      // Create processed record with only columns that exist in expectedColumns schema
      final Map<String, dynamic> data = <String, dynamic>{};
      
      // Only include columns that are defined in expectedColumns
      for (final col in expectedColumns) {
        final name = col['name'] as String;
        if (statRecord.containsKey(name)) {
          data[name] = statRecord[name];
        }
      }
      
      // Set sync flags to indicate synced status
      data['has_been_synced'] = 1;
      data['edits_are_synced'] = 1;
      
      // Insert the processed record
      await insertRawData(
        'user_daily_stats',
        data,
        db,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  } catch (e) {
    QuizzerLogger.logError('Error upserting daily stats record from inbound sync - $e');
    rethrow;
  }
}