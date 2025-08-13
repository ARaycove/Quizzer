import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_average_daily_questions_learned_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_average_questions_shown_per_day_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_daily_questions_answered_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_days_left_until_questions_exhaust_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_eligible_questions_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_in_circulation_questions_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_non_circulating_questions_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_revision_streak_sum_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_total_questions_answered_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_total_user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_module_activation_status_table.dart';

import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_settings_table.dart';
// import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_subject_interest_table.dart'; //TODO NOT IMPLEMENTED

import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/media_sync_status_table.dart';
// import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pair_concepts.dart'; //TODO NOT IMPLEMENTED
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pair_flags_table.dart';
// import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pair_subjects.dart'; //TODO NOT IMPLEMENTED
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';

import 'package:quizzer/backend_systems/00_database_manager/tables/system_data/error_logs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/system_data/user_feedback_table.dart';

import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_attempts_table.dart';


//TODO Academic Archive tables
import 'package:quizzer/backend_systems/00_database_manager/tables/academic_archive.dart/subject_details_table.dart';




import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';


Future<void> verifyAllTablesExist(userId) async {
  DatabaseMonitor dbMonitor = getDatabaseMonitor();
  final db = await dbMonitor.requestDatabaseAccess();
  // Do all verifications in one transactions
  db!.transaction((txn) async {
    // User Profile not included, because it is verified separately in the performLogin
      await verifyUserStatsAverageDailyQuestionsLearnedTable(txn);
      await verifyUserStatsAverageQuestionsShownPerDayTable(txn);
      await verifyUserStatsDailyQuestionsAnsweredTable(txn);
      await verifyUserStatsDaysLeftUntilQuestionsExhaustTable(txn);
      await verifyUserStatsEligibleQuestionsTable(txn);
      await verifyUserStatsInCirculationQuestionsTable(txn);
      await verifyUserStatsNonCirculatingQuestionsTable(txn);
      await verifyUserStatsRevisionStreakSumTable(txn);
      await verifyUserStatsTotalQuestionsAnsweredTable(txn);
      await verifyUserStatsTotalUserQuestionAnswerPairsTable(txn);
      await verifyUserModuleActivationStatusTable(txn, userId);
      await verifyUserQuestionAnswerPairTable(txn);
      await verifyUserSettingsTable(txn);
      await verifyMediaSyncStatusTable(txn);
      await verifyQuestionAnswerPairFlagsTable(txn);
      await verifyQuestionAnswerPairTable(txn);
      await verifyErrorLogsTable(txn);
      await verifyUserFeedbackTable(txn);
      await verifyModulesTable(txn);
      await verifyQuestionAnswerAttemptTable(txn);
      await verifySubjectDetailsTable(txn);
  });
  dbMonitor.releaseDatabaseAccess();
}