// Removed individual stats tables
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
import 'package:quizzer/backend_systems/00_database_manager/tables/ml_models_table.dart';


//TODO Academic Archive tables
import 'package:quizzer/backend_systems/00_database_manager/tables/academic_archive.dart/subject_details_table.dart';

import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_daily_stats_table.dart';


import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';


Future<void> verifyAllTablesExist(userId) async {
  DatabaseMonitor dbMonitor = getDatabaseMonitor();
  final db = await dbMonitor.requestDatabaseAccess();
  // Do all verifications in one transactions
  db!.transaction((txn) async {
    // User Profile not included, because it is verified separately in the performLogin
      await verifyUserDailyStatsTable(txn);
      await verifyModulesTable(txn);
      await verifyUserModuleActivationStatusTable(txn, userId);
      await verifyUserQuestionAnswerPairTable(txn);
      await verifyUserSettingsTable(txn);
      await verifyMediaSyncStatusTable(txn);
      await verifyQuestionAnswerPairFlagsTable(txn);
      await verifyQuestionAnswerPairTable(txn);
      await verifyErrorLogsTable(txn);
      await verifyUserFeedbackTable(txn);
      await verifyQuestionAnswerAttemptTable(txn);
      await verifySubjectDetailsTable(txn);
      await verifyMlModelsTable(txn);
  });
  dbMonitor.releaseDatabaseAccess();
}