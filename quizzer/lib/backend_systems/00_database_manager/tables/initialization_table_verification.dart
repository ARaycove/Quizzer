import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_settings_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/media_sync_status_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pair_flags_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/system_data/error_logs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/system_data/user_feedback_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_attempts_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/ml_models_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';

//TODO Academic Archive tables
import 'package:quizzer/backend_systems/00_database_manager/tables/academic_archive.dart/subject_details_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_daily_stats_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/system_data/login_attempts_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/sql_table.dart';

/// Table Verification goes in two stages
/// 1. Verify tables required on startup of Quizzer
/// 2. Verify tables required on during and after login
/// Contains allTables for easy reference to the full db
class InitializationTableVerification {
  static final InitializationTableVerification _instance = InitializationTableVerification._internal();
  factory InitializationTableVerification() => _instance;
  InitializationTableVerification._internal();
  /// Concrete table implementations of all the tables
  /// Just a list of references for each table in the database
  static List<SqlTable> get allTables => [
      UserProfileTable(),
      ErrorLogsTable(),
      LoginAttemptsTable(),
      UserDailyStatsTable(),
      UserQuestionAnswerPairsTable(),
      QuestionAnswerPairsTable(),
      QuestionAnswerAttemptsTable(),
      QuestionAnswerPairFlagsTable(),
      UserSettingsTable(),
      MediaSyncStatusTable(),
      UserFeedbackTable(),
      SubjectDetailsTable(),
      MlModelsTable(),
  ];

  /// These tables are initialized on app startup
  Future<void> verifyOnStartup() async {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    db!.transaction((txn) async {
      await UserProfileTable().verifyTable(txn);
      await ErrorLogsTable()  .verifyTable(txn);
      await LoginAttemptsTable().verifyTable(txn);
    });
    getDatabaseMonitor().releaseDatabaseAccess();
  }

  /// These tables are initialized during the login authentication process
  Future<void> verifyOnLogin() async {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    db!.transaction((txn) async {
      // User Profile not included, because it is verified separately in the performLogin
      await UserDailyStatsTable()           .verifyTable(txn);
      await UserQuestionAnswerPairsTable()  .verifyTable(txn);
      await QuestionAnswerPairsTable()      .verifyTable(txn);
      await QuestionAnswerAttemptsTable()   .verifyTable(txn);
      await QuestionAnswerPairFlagsTable()  .verifyTable(txn);
      await UserSettingsTable()             .verifyTable(txn);
      await MediaSyncStatusTable()          .verifyTable(txn);
      await UserFeedbackTable()             .verifyTable(txn);
      await SubjectDetailsTable()           .verifyTable(txn);
      await MlModelsTable()                 .verifyTable(txn);
    });
    getDatabaseMonitor().releaseDatabaseAccess();
  }

  Future<void> verifyAfterSync() async {
    await UserDailyStatsTable().fillMissingDailyStatRecords(); // handles its own db access

    // final db = await getDatabaseMonitor().requestDatabaseAccess();
    // db!.transaction((txn) async {
    //   
    // });
    // getDatabaseMonitor().releaseDatabaseAccess();
  }

}

Future<void> verifyAllTablesExist() async {

}