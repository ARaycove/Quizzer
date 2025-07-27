import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_eligible_questions_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_non_circulating_questions_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_in_circulation_questions_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_revision_streak_sum_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_total_user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_average_questions_shown_per_day_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_total_questions_answered_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_daily_questions_answered_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_days_left_until_questions_exhaust_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_average_daily_questions_learned_table.dart';



/// Updates all relevant daily user statistics for the given user.
Future<void> updateAllUserDailyStats(String userId, {bool? isCorrect}) async {
  QuizzerLogger.logMessage('StatUpdateAggregator: Beginning daily stat updates for user: $userId');

  // Update eligible questions stat
  QuizzerLogger.logMessage('StatUpdateAggregator: Updating eligible questions stat for user: $userId');
  await updateEligibleQuestionsStat(userId);
  QuizzerLogger.logSuccess('StatUpdateAggregator: Successfully triggered eligible questions stat update for user: $userId');

  // Update non-circulating questions stat
  QuizzerLogger.logMessage('StatUpdateAggregator: Updating non-circulating questions stat for user: $userId');
  await updateNonCirculatingQuestionsStat(userId);
  QuizzerLogger.logSuccess('StatUpdateAggregator: Successfully triggered non-circulating questions stat update for user: $userId');

  // Update in-circulation questions stat
  QuizzerLogger.logMessage('StatUpdateAggregator: Updating in-circulation questions stat for user: $userId');
  await updateInCirculationQuestionsStat(userId);
  QuizzerLogger.logSuccess('StatUpdateAggregator: Successfully triggered in-circulation questions stat update for user: $userId');

  // Update revision streak sum stat
  QuizzerLogger.logMessage('StatUpdateAggregator: Updating revision streak sum stat for user: $userId');
  await updateRevisionStreakSumStat(userId);
  QuizzerLogger.logSuccess('StatUpdateAggregator: Successfully triggered revision streak sum stat update for user: $userId');

  // Update total user question answer pairs stat
  QuizzerLogger.logMessage('StatUpdateAggregator: Updating total user question answer pairs stat for user: $userId');
  await updateTotalUserQuestionAnswerPairsStat(userId);
  QuizzerLogger.logSuccess('StatUpdateAggregator: Successfully triggered total user question answer pairs stat update for user: $userId');

  // Update average questions shown per day stat
  QuizzerLogger.logMessage('StatUpdateAggregator: Updating average questions shown per day stat for user: $userId');
  await updateAverageQuestionsShownPerDayStat(userId);
  QuizzerLogger.logSuccess('StatUpdateAggregator: Successfully triggered average questions shown per day stat update for user: $userId');

  // Update total questions answered stat (only if isCorrect is provided)
  if (isCorrect != null) {
    QuizzerLogger.logMessage('StatUpdateAggregator: Incrementing total questions answered stat for user: $userId with isCorrect: $isCorrect');
    await incrementTotalQuestionsAnsweredStat(userId, isCorrect);
    QuizzerLogger.logSuccess('StatUpdateAggregator: Successfully incremented total questions answered stat for user: $userId');

    // Update daily questions answered stat
    QuizzerLogger.logMessage('StatUpdateAggregator: Incrementing daily questions answered stat for user: $userId with isCorrect: $isCorrect');
    await incrementDailyQuestionsAnsweredStat(userId, isCorrect);
    QuizzerLogger.logSuccess('StatUpdateAggregator: Successfully incremented daily questions answered stat for user: $userId');
  }
  // Update average daily questions learned stat
  QuizzerLogger.logMessage('StatUpdateAggregator: Updating average daily questions learned stat for user: $userId');
  await updateAverageDailyQuestionsLearnedStat(userId);
  QuizzerLogger.logSuccess('StatUpdateAggregator: Successfully triggered average daily questions learned stat update for user: $userId');

  // Update days left until questions exhaust stat
  QuizzerLogger.logMessage('StatUpdateAggregator: Updating days left until questions exhaust stat for user: $userId');
  await updateDaysLeftUntilQuestionsExhaustStat(userId);
  QuizzerLogger.logSuccess('StatUpdateAggregator: Successfully triggered days left until questions exhaust stat update for user: $userId');


  // Add calls to other daily stat update functions here as they are created.
  // For example:
  // await user_streak_stats.updateDailyStreakStat(userId, db);
  // getDatabaseMonitor().releaseDatabaseAccess();

  QuizzerLogger.logSuccess('StatUpdateAggregator: All daily stat updates completed for user: $userId');
}
