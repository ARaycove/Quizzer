import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_eligible_questions_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_non_circulating_questions_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_in_circulation_questions_table.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

/// Aggregates calls to update various user statistics.

/// Updates all relevant daily user statistics for the given user.
Future<void> updateAllUserDailyStats(String userId, Database db) async {
  QuizzerLogger.logMessage('StatUpdateAggregator: Beginning daily stat updates for user: $userId');

  // Update eligible questions stat
  QuizzerLogger.logMessage('StatUpdateAggregator: Updating eligible questions stat for user: $userId');
  await updateEligibleQuestionsStat(userId, db);
  QuizzerLogger.logSuccess('StatUpdateAggregator: Successfully triggered eligible questions stat update for user: $userId');

  // Update non-circulating questions stat
  QuizzerLogger.logMessage('StatUpdateAggregator: Updating non-circulating questions stat for user: $userId');
  await updateNonCirculatingQuestionsStat(userId, db);
  QuizzerLogger.logSuccess('StatUpdateAggregator: Successfully triggered non-circulating questions stat update for user: $userId');

  // Update in-circulation questions stat
  QuizzerLogger.logMessage('StatUpdateAggregator: Updating in-circulation questions stat for user: $userId');
  await updateInCirculationQuestionsStat(userId, db);
  QuizzerLogger.logSuccess('StatUpdateAggregator: Successfully triggered in-circulation questions stat update for user: $userId');

  // TODO: Add calls to other daily stat update functions here as they are created.
  // For example:
  // await user_streak_stats.updateDailyStreakStat(userId, db);
  // await user_activity_stats.updateDailyActivityStat(userId, db);

  QuizzerLogger.logSuccess('StatUpdateAggregator: All daily stat updates completed for user: $userId');
}
