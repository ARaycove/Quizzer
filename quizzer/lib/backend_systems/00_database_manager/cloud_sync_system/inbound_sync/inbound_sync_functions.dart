import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_settings_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_eligible_questions_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_non_circulating_questions_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_in_circulation_questions_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_revision_streak_sum_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_total_user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_average_questions_shown_per_day_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_total_questions_answered_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_daily_questions_answered_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_days_left_until_questions_exhaust_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_stats/user_stats_average_daily_questions_learned_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_module_activation_status_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/academic_archive.dart/subject_details_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/inbound_sync/inbound_sync_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'dart:io'; // For SocketException
import 'dart:async'; // For Future.delayed

Future<T> executeSupabaseCallWithRetry<T>(
  Future<T> Function() supabaseCall, {
  int maxRetries = 3,
  Duration initialDelay = const Duration(seconds: 2), // Increased initial delay
  String? logContext,
}) async {
  try {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt < maxRetries) {
      try {
        return await supabaseCall();
      } on SocketException catch (e, s) {
        attempt++;
        String context = logContext ?? 'Supabase call';
        QuizzerLogger.logWarning('$context: SocketException (Attempt $attempt/$maxRetries). Retrying in ${delay.inSeconds}s... Error: $e');
        if (attempt >= maxRetries) {
          QuizzerLogger.logError('$context: SocketException after $maxRetries attempts. Error: $e, Stack: $s');
          rethrow;
        }
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      } on PostgrestException catch (e, s) {
        attempt++;
        String context = logContext ?? 'Supabase call';
        // Only retry on network-related or server-side issues (e.g., 5xx errors or connection errors)
        // Do not retry on 4xx client errors like RLS violations, not found, bad request etc.
        bool isRetriable = e.code == null || // Some connection errors might not have a code
                           (e.code != null && e.code!.startsWith('5')) || // Server errors
                           e.message.toLowerCase().contains('failed host lookup') ||
                           e.message.toLowerCase().contains('connection timed out') ||
                           e.message.toLowerCase().contains('connection closed') ||
                           e.message.toLowerCase().contains('network is unreachable');

        if (isRetriable) {
          QuizzerLogger.logWarning('$context: Retriable PostgrestException (Attempt $attempt/$maxRetries). Code: ${e.code}, Message: ${e.message}. Retrying in ${delay.inSeconds}s...');
          if (attempt >= maxRetries) {
            QuizzerLogger.logError('$context: PostgrestException after $maxRetries attempts. Error: ${e.message}, Code: ${e.code}, Stack: $s');
            rethrow;
          }
          await Future.delayed(delay);
          delay *= 2;
        } else {
          QuizzerLogger.logError('$context: Non-retriable PostgrestException. Code: ${e.code}, Message: ${e.message}, Stack: $s');
          rethrow; // Do not retry for non-retriable errors
        }
      } catch (e, s) {
        // For other unexpected errors, log and rethrow immediately without retrying.
        String context = logContext ?? 'Supabase call';
        QuizzerLogger.logError('$context: Unexpected error during Supabase call. Error: $e, Stack: $s');
        rethrow;
      }
    }
    // This should be unreachable if maxRetries > 0
    throw StateError('${logContext ?? "executeSupabaseCallWithRetry"}: Max retries reached, but no error was rethrown.');
  } catch (e) {
    QuizzerLogger.logError('executeSupabaseCallWithRetry: Error - $e');
    rethrow;
  }
}

Future<void> runInboundSync(SessionManager sessionManager) async {
  QuizzerLogger.logMessage('Starting inbound sync aggregator...');
  final String? userId = sessionManager.userId;

  if (userId == null) {
    QuizzerLogger.logError('Cannot run inbound sync: userId is null');
    throw StateError('Cannot run inbound sync: userId is null');
  }

  try {
    QuizzerLogger.logMessage('Starting inbound sync for user $userId...');
    List<List<Map<String,dynamic>>> tableDataForSync = await fetchDataForAllTables(sessionManager.supabase, userId);

    // Now batch upsert all records as a single database transaction
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    db!.transaction((txn) async {
    await batchUpsertQuestionAnswerPairs(records: tableDataForSync[0], db: txn);
    await batchUpsertUserQuestionAnswerPairs(records: tableDataForSync[1], db: txn);
    await upsertUserProfileFromInboundSync(profileDataList: tableDataForSync[2], db: txn); // user should have only one profile record, so index the first in the list (should be only in the list)
    await batchUpsertUserSettingsFromSupabase(settingsData: tableDataForSync[3], userId: userId, db: txn);
    await batchUpsertModuleFromInboundSync(moduleRecords: tableDataForSync[4], db: txn);
    await batchUpsertUserStatsEligibleQuestionsFromInboundSync(userStatsEligibleQuestionsRecords: tableDataForSync[5], db: txn);
    await batchUpsertUserStatsNonCirculatingQuestionsFromInboundSync(userStatsNonCirculatingQuestionsRecords: tableDataForSync[6], db: txn);
    await batchUpsertUserStatsInCirculationQuestionsFromInboundSync(userStatsInCirculationQuestionsRecords: tableDataForSync[7], db: txn);
    await batchUpsertUserStatsRevisionStreakSumFromInboundSync(userStatsRevisionStreakSumRecords: tableDataForSync[8], db: txn);
    await batchUpsertUserStatsTotalUserQuestionAnswerPairsFromInboundSync(userStatsTotalUserQuestionAnswerPairsRecords: tableDataForSync[9], db: txn);
    await batchUpsertUserStatsAverageQuestionsShownPerDayFromInboundSync(userStatsAverageQuestionsShownPerDayRecords: tableDataForSync[10], db: txn);
    await batchUpsertUserStatsTotalQuestionsAnsweredFromInboundSync(userStatsTotalQuestionsAnsweredRecords: tableDataForSync[11], db: txn);
    await batchUpsertUserStatsDailyQuestionsAnsweredFromInboundSync(userStatsDailyQuestionsAnsweredRecords: tableDataForSync[12], db: txn);
    await batchUpsertUserStatsDaysLeftUntilQuestionsExhaustFromInboundSync(userStatsDaysLeftUntilQuestionsExhaustRecords: tableDataForSync[13], db: txn);
    await batchUpsertUserStatsAverageDailyQuestionsLearnedFromInboundSync(userStatsAverageDailyQuestionsLearnedRecords: tableDataForSync[14], db: txn);
    await batchUpsertUserModuleActivationStatusFromInboundSync(userModuleActivationStatusRecords: tableDataForSync[15], db: txn);
    await batchUpsertSubjectDetails(subjectDetailRecords: tableDataForSync[16], db: txn);
    });
    getDatabaseMonitor().releaseDatabaseAccess();
    QuizzerLogger.logSuccess('Inbound sync completed successfully.');
  } catch (e) {
    QuizzerLogger.logError('Error during inbound sync: $e');
    rethrow;
  }
}


