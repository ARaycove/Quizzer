import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_eligible_questions_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_non_circulating_questions_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_in_circulation_questions_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_revision_streak_sum_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_total_user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_average_questions_shown_per_day_table.dart';

/// Updates all relevant daily user statistics for the given user.
Future<void> updateAllUserDailyStats(String userId) async {
  QuizzerLogger.logMessage('StatUpdateAggregator: Beginning daily stat updates for user: $userId');

  // Update eligible questions stat
  QuizzerLogger.logMessage('StatUpdateAggregator: Updating eligible questions stat for user: $userId');
  Database? db = await getDatabaseMonitor().requestDatabaseAccess();
  await updateEligibleQuestionsStat(userId, db!);
  getDatabaseMonitor().releaseDatabaseAccess();
  QuizzerLogger.logSuccess('StatUpdateAggregator: Successfully triggered eligible questions stat update for user: $userId');

  // Update non-circulating questions stat
  QuizzerLogger.logMessage('StatUpdateAggregator: Updating non-circulating questions stat for user: $userId');
  db = await getDatabaseMonitor().requestDatabaseAccess();
  await updateNonCirculatingQuestionsStat(userId, db!);
  getDatabaseMonitor().releaseDatabaseAccess();
  QuizzerLogger.logSuccess('StatUpdateAggregator: Successfully triggered non-circulating questions stat update for user: $userId');

  // Update in-circulation questions stat
  QuizzerLogger.logMessage('StatUpdateAggregator: Updating in-circulation questions stat for user: $userId');
  db = await getDatabaseMonitor().requestDatabaseAccess();
  await updateInCirculationQuestionsStat(userId, db!);
  getDatabaseMonitor().releaseDatabaseAccess();
  QuizzerLogger.logSuccess('StatUpdateAggregator: Successfully triggered in-circulation questions stat update for user: $userId');

  // Update revision streak sum stat
  QuizzerLogger.logMessage('StatUpdateAggregator: Updating revision streak sum stat for user: $userId');
  db = await getDatabaseMonitor().requestDatabaseAccess();
  await updateRevisionStreakSumStat(userId, db!);
  getDatabaseMonitor().releaseDatabaseAccess();
  QuizzerLogger.logSuccess('StatUpdateAggregator: Successfully triggered revision streak sum stat update for user: $userId');

  // Update total user question answer pairs stat
  QuizzerLogger.logMessage('StatUpdateAggregator: Updating total user question answer pairs stat for user: $userId');
  db = await getDatabaseMonitor().requestDatabaseAccess();
  await updateTotalUserQuestionAnswerPairsStat(userId, db!);
  getDatabaseMonitor().releaseDatabaseAccess();
  QuizzerLogger.logSuccess('StatUpdateAggregator: Successfully triggered total user question answer pairs stat update for user: $userId');

  // Update average questions shown per day stat
  QuizzerLogger.logMessage('StatUpdateAggregator: Updating average questions shown per day stat for user: $userId');
  db = await getDatabaseMonitor().requestDatabaseAccess();
  await updateAverageQuestionsShownPerDayStat(userId, db!);
  getDatabaseMonitor().releaseDatabaseAccess();
  QuizzerLogger.logSuccess('StatUpdateAggregator: Successfully triggered average questions shown per day stat update for user: $userId');

  // TODO: Add calls to other daily stat update functions here as they are created.
  // For example:
  // await user_streak_stats.updateDailyStreakStat(userId, db);
  // getDatabaseMonitor().releaseDatabaseAccess();

  QuizzerLogger.logSuccess('StatUpdateAggregator: All daily stat updates completed for user: $userId');
}
