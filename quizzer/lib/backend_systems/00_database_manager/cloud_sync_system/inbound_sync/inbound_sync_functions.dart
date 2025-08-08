import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_other_signals.dart';
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

/// Syncs question_answer_pairs from the cloud that are newer than the last login date
Future<void> syncQuestionAnswerPairsInbound(
  String userId,
  SupabaseClient supabaseClient, {
  String? effectiveLastLogin,
}) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound question_answer_pairs for user $userId...');
    
    // Use the new helper function to fetch all records newer than last login
    final List<Map<String, dynamic>> cloudRecords = await fetchAllRecordsOlderThanLastLogin(
      supabase: supabaseClient,
      tableName: 'question_answer_pairs',
      userId: userId,
      effectiveLastLogin: effectiveLastLogin,
    );
    
    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new question_answer_pairs to sync.');
      signalLoginProgress('Question sync: No new questions.');
      return;
    }

    final int totalSynced = cloudRecords.length;
    QuizzerLogger.logMessage('Found $totalSynced question_answer_pairs to sync.');
    signalLoginProgress('Question sync: Found $totalSynced questions.');

    // Process all records in a single batch
    await batchUpsertQuestionAnswerPairs(records: cloudRecords);
    
    signalLoginProgress('Question sync: Complete.');
    QuizzerLogger.logSuccess('Synced $totalSynced question_answer_pairs from cloud.');
  } catch (e) {
    QuizzerLogger.logError('syncQuestionAnswerPairsInbound: Error - $e');
    rethrow;
  }
}

/// Syncs user_question_answer_pairs from the cloud that are newer than the last login date
Future<void> syncUserQuestionAnswerPairsInbound(
  String userId,
  SupabaseClient supabaseClient, {
  String? effectiveLastLogin,
}) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_question_answer_pairs for user $userId...');
    
    // Use the new helper function to fetch all records newer than last login
    final List<Map<String, dynamic>> cloudRecords = await fetchAllRecordsOlderThanLastLogin(
      supabase: supabaseClient,
      tableName: 'user_question_answer_pairs',
      userId: userId,
      additionalFilters: {'user_uuid': userId},
      effectiveLastLogin: effectiveLastLogin,
    );
    
    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_question_answer_pairs to sync.');
      signalLoginProgress('User progress sync: No new records.');
      return;
    }

    final int totalSynced = cloudRecords.length;
    QuizzerLogger.logMessage('Found $totalSynced user_question_answer_pairs to sync.');
    signalLoginProgress('User progress sync: Found $totalSynced records.');

    // Process all records in a single batch
    await batchUpsertUserQuestionAnswerPairs(records: cloudRecords);
    
    signalLoginProgress('User progress sync: Complete.');
    QuizzerLogger.logSuccess('Synced $totalSynced user_question_answer_pairs from cloud.');
  } catch (e) {
    QuizzerLogger.logError('syncUserQuestionAnswerPairsInbound: Error - $e');
    rethrow;
  }
}

/// Syncs user profile from the cloud that is newer than the last login date
Future<void> syncUserProfileInbound(
  String userId,
  SupabaseClient supabaseClient, {
  String? effectiveLastLogin,
}) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user profile for user $userId...');
    
    // Use the new helper function to fetch user profile newer than last login
    final List<Map<String, dynamic>> cloudRecords = await fetchAllRecordsOlderThanLastLogin(
      supabase: supabaseClient,
      tableName: 'user_profile',
      userId: userId,
      additionalFilters: {'uuid': userId},
      effectiveLastLogin: effectiveLastLogin,
    );

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user profile to sync.');
      return;
    }

    QuizzerLogger.logMessage('Found updated user profile to sync.');
    final record = cloudRecords.first; // Should only be one record per user

    // Update the local profile using the refactored function that handles its own database access
    await upsertUserProfileFromInboundSync(record);

    QuizzerLogger.logSuccess('Synced user profile from cloud.');
  } catch (e) {
    QuizzerLogger.logError('syncUserProfileInbound: Error - $e');
    rethrow;
  }
}

/// Syncs user settings from the cloud that are newer than the initial profile timestamp for the user.
Future<void> syncUserSettingsInbound(
  String userId,
  SupabaseClient supabaseClient, {
  String? effectiveLastLogin,
}) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_settings for user $userId...');

    // Use the new helper function to fetch all user settings newer than last login
    final List<Map<String, dynamic>> cloudRecords = await fetchAllRecordsOlderThanLastLogin(
      supabase: supabaseClient,
      tableName: 'user_settings',
      userId: userId,
      additionalFilters: {'user_id': userId},
      effectiveLastLogin: effectiveLastLogin,
    );

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_settings to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_settings to sync for user $userId.');

    // Use batch upsert to handle all settings in a single transaction
    await batchUpsertUserSettingsFromSupabase(cloudRecords, userId);

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_settings from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserSettingsInbound: Error - $e');
    rethrow;
  }
}

/// Syncs modules from the cloud that are newer than the last login date
Future<void> syncModulesInbound(
  SupabaseClient supabaseClient,
) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound modules...');

    // Use the new helper function to fetch all modules newer than last login
    // Modules are global, so we don't use last login filtering
    final List<Map<String, dynamic>> cloudRecords = await fetchAllRecordsOlderThanLastLogin(
      supabase: supabaseClient,
      tableName: 'modules',
      userId: null, // No userId for global tables
      useLastLogin: false, // Don't use last login for global tables
    );

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new modules to sync.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated modules to sync.');

    for (final record in cloudRecords) {
      // Only sync the fields we store in Supabase
      await upsertModuleFromInboundSync(
        moduleName: record['module_name'],
        description: record['description'],
        categories: record['categories']
      );
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} modules from cloud.');
  } catch (e) {
    QuizzerLogger.logError('syncModulesInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsEligibleQuestionsInbound(
  String userId,
  SupabaseClient supabaseClient, {
  String? effectiveLastLogin,
}) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_eligible_questions for user $userId...');

    // Use the new helper function to fetch all records newer than last login
    final List<Map<String, dynamic>> cloudRecords = await fetchAllRecordsOlderThanLastLogin(
      supabase: supabaseClient,
      tableName: 'user_stats_eligible_questions',
      userId: userId,
      additionalFilters: {'user_id': userId},
      effectiveLastLogin: effectiveLastLogin,
    );

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_eligible_questions to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_eligible_questions to sync for user $userId.');

    for (final record in cloudRecords) {
      await upsertUserStatsEligibleQuestionsFromInboundSync(record);
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_eligible_questions from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsEligibleQuestionsInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsNonCirculatingQuestionsInbound(
  String userId,
  SupabaseClient supabaseClient, {
  String? effectiveLastLogin,
}) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_non_circulating_questions for user $userId...');

    // Use the new helper function to fetch all records newer than last login
    final List<Map<String, dynamic>> cloudRecords = await fetchAllRecordsOlderThanLastLogin(
      supabase: supabaseClient,
      tableName: 'user_stats_non_circulating_questions',
      userId: userId,
      additionalFilters: {'user_id': userId},
      effectiveLastLogin: effectiveLastLogin,
    );

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_non_circulating_questions to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_non_circulating_questions to sync for user $userId.');

    for (final record in cloudRecords) {
      await upsertUserStatsNonCirculatingQuestionsFromInboundSync(record);
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_non_circulating_questions from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsNonCirculatingQuestionsInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsInCirculationQuestionsInbound(
  String userId,
  SupabaseClient supabaseClient, {
  String? effectiveLastLogin,
}) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_in_circulation_questions for user $userId...');

    // Use the new helper function to fetch all records newer than last login
    final List<Map<String, dynamic>> cloudRecords = await fetchAllRecordsOlderThanLastLogin(
      supabase: supabaseClient,
      tableName: 'user_stats_in_circulation_questions',
      userId: userId,
      additionalFilters: {'user_id': userId},
      effectiveLastLogin: effectiveLastLogin,
    );

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_in_circulation_questions to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_in_circulation_questions to sync for user $userId.');

    for (final record in cloudRecords) {
      await upsertUserStatsInCirculationQuestionsFromInboundSync(record);
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_in_circulation_questions from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsInCirculationQuestionsInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsRevisionStreakSumInbound(
  String userId,
  SupabaseClient supabaseClient, {
  String? effectiveLastLogin,
}) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_revision_streak_sum for user $userId...');

    // Use the new helper function to fetch all records newer than last login
    final List<Map<String, dynamic>> cloudRecords = await fetchAllRecordsOlderThanLastLogin(
      supabase: supabaseClient,
      tableName: 'user_stats_revision_streak_sum',
      userId: userId,
      additionalFilters: {'user_id': userId},
      effectiveLastLogin: effectiveLastLogin,
    );

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_revision_streak_sum to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_revision_streak_sum to sync for user $userId.');

    for (final record in cloudRecords) {
      await upsertUserStatsRevisionStreakSumFromInboundSync(record);
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_revision_streak_sum from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsRevisionStreakSumInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsTotalUserQuestionAnswerPairsInbound(
  String userId,
  SupabaseClient supabaseClient, {
  String? effectiveLastLogin,
}) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_total_user_question_answer_pairs for user $userId...');

    // Use the new helper function to fetch all records newer than last login
    final List<Map<String, dynamic>> cloudRecords = await fetchAllRecordsOlderThanLastLogin(
      supabase: supabaseClient,
      tableName: 'user_stats_total_user_question_answer_pairs',
      userId: userId,
      additionalFilters: {'user_id': userId},
      effectiveLastLogin: effectiveLastLogin,
    );

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_total_user_question_answer_pairs to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_total_user_question_answer_pairs to sync for user $userId.');

    for (final record in cloudRecords) {
      await upsertUserStatsTotalUserQuestionAnswerPairsFromInboundSync(record);
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_total_user_question_answer_pairs from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsTotalUserQuestionAnswerPairsInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsAverageQuestionsShownPerDayInbound(
  String userId,
  SupabaseClient supabaseClient, {
  String? effectiveLastLogin,
}) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_average_questions_shown_per_day for user $userId...');

    // Use the new helper function to fetch all records newer than last login
    final List<Map<String, dynamic>> cloudRecords = await fetchAllRecordsOlderThanLastLogin(
      supabase: supabaseClient,
      tableName: 'user_stats_average_questions_shown_per_day',
      userId: userId,
      additionalFilters: {'user_id': userId},
      effectiveLastLogin: effectiveLastLogin,
    );

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_average_questions_shown_per_day to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_average_questions_shown_per_day to sync for user $userId.');

    for (final record in cloudRecords) {
      await upsertUserStatsAverageQuestionsShownPerDayFromInboundSync(record);
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_average_questions_shown_per_day from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsAverageQuestionsShownPerDayInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsTotalQuestionsAnsweredInbound(
  String userId,
  SupabaseClient supabaseClient, {
  String? effectiveLastLogin,
}) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_total_questions_answered for user $userId...');

    // Use the new helper function to fetch all records newer than last login
    final List<Map<String, dynamic>> cloudRecords = await fetchAllRecordsOlderThanLastLogin(
      supabase: supabaseClient,
      tableName: 'user_stats_total_questions_answered',
      userId: userId,
      additionalFilters: {'user_id': userId},
      effectiveLastLogin: effectiveLastLogin,
    );

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_total_questions_answered to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_total_questions_answered to sync for user $userId.');

    for (final record in cloudRecords) {
      await upsertUserStatsTotalQuestionsAnsweredFromInboundSync(record);
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_total_questions_answered from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsTotalQuestionsAnsweredInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsDailyQuestionsAnsweredInbound(
  String userId,
  SupabaseClient supabaseClient, {
  String? effectiveLastLogin,
}) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_daily_questions_answered for user $userId...');

    // Use the new helper function to fetch all records newer than last login
    final List<Map<String, dynamic>> cloudRecords = await fetchAllRecordsOlderThanLastLogin(
      supabase: supabaseClient,
      tableName: 'user_stats_daily_questions_answered',
      userId: userId,
      additionalFilters: {'user_id': userId},
      effectiveLastLogin: effectiveLastLogin,
    );

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_daily_questions_answered to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_daily_questions_answered to sync for user $userId.');

    for (final record in cloudRecords) {
      await upsertUserStatsDailyQuestionsAnsweredFromInboundSync(record);
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_daily_questions_answered from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsDailyQuestionsAnsweredInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsDaysLeftUntilQuestionsExhaustInbound(
  String userId,
  SupabaseClient supabaseClient, {
  String? effectiveLastLogin,
}) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_days_left_until_questions_exhaust for user $userId...');

    // Use the new helper function to fetch all records newer than last login
    final List<Map<String, dynamic>> cloudRecords = await fetchAllRecordsOlderThanLastLogin(
      supabase: supabaseClient,
      tableName: 'user_stats_days_left_until_questions_exhaust',
      userId: userId,
      additionalFilters: {'user_id': userId},
      effectiveLastLogin: effectiveLastLogin,
    );

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_days_left_until_questions_exhaust to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_days_left_until_questions_exhaust to sync for user $userId.');

    for (final record in cloudRecords) {
      await upsertUserStatsDaysLeftUntilQuestionsExhaustFromInboundSync(record);
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_days_left_until_questions_exhaust from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsDaysLeftUntilQuestionsExhaustInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsAverageDailyQuestionsLearnedInbound(
  String userId,
  SupabaseClient supabaseClient, {
  String? effectiveLastLogin,
}) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_average_daily_questions_learned for user $userId...');

    // Use the new helper function to fetch all records newer than last login
    final List<Map<String, dynamic>> cloudRecords = await fetchAllRecordsOlderThanLastLogin(
      supabase: supabaseClient,
      tableName: 'user_stats_average_daily_questions_learned',
      userId: userId,
      additionalFilters: {'user_id': userId},
      effectiveLastLogin: effectiveLastLogin,
    );

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_average_daily_questions_learned to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_average_daily_questions_learned to sync for user $userId.');

    for (final record in cloudRecords) {
      await upsertUserStatsAverageDailyQuestionsLearnedFromInboundSync(record);
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_average_daily_questions_learned from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsAverageDailyQuestionsLearnedInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserModuleActivationStatusInbound(
  String userId,
  SupabaseClient supabaseClient, {
  String? effectiveLastLogin,
}) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_module_activation_status for user $userId...');

    // Use the new helper function to fetch all records newer than last login
    final List<Map<String, dynamic>> cloudRecords = await fetchAllRecordsOlderThanLastLogin(
      supabase: supabaseClient,
      tableName: 'user_module_activation_status',
      userId: userId,
      additionalFilters: {'user_id': userId},
      effectiveLastLogin: effectiveLastLogin,
    );

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_module_activation_status to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_module_activation_status to sync for user $userId.');

    for (final record in cloudRecords) {
      await upsertModuleActivationStatusFromInboundSync(
        userId: record['user_id'] as String,
        moduleName: record['module_name'] as String,
        isActive: (record['is_active'] as int) == 1,
        lastModifiedTimestamp: record['last_modified_timestamp'] as String,
      );
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_module_activation_status from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserModuleActivationStatusInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncSubjectDetailsInbound(
  SupabaseClient supabaseClient,
) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound subject_details...');

    // Use the new helper function to fetch all records newer than last login
    // Subject details is a global table, so we don't use last login filtering
    final List<Map<String, dynamic>> cloudRecords = await fetchAllRecordsOlderThanLastLogin(
      supabase: supabaseClient,
      tableName: 'subject_details',
      userId: null, // No userId for global tables
      useLastLogin: false, // Don't use last login for global tables
    );

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new subject_details to sync.');
      return;
    }

    final int totalSynced = cloudRecords.length;
    QuizzerLogger.logMessage('Found $totalSynced new/updated subject_details to sync.');

    // Process all records in a single batch
    await batchUpsertSubjectDetails(records: cloudRecords);
    
    QuizzerLogger.logSuccess('Synced $totalSynced subject_details from cloud.');
  } catch (e) {
    QuizzerLogger.logError('syncSubjectDetailsInbound: Error - $e');
    rethrow;
  }
}

Future<void> runInboundSync(SessionManager sessionManager, {bool isDatabaseFresh = false}) async {
  QuizzerLogger.logMessage('Starting inbound sync aggregator...');
  final String? userId = sessionManager.userId;

  if (userId == null) {
    QuizzerLogger.logError('Cannot run inbound sync: userId is null');
    throw StateError('Cannot run inbound sync: userId is null');
  }

  String effectiveLastLogin;
  if (isDatabaseFresh) {
    // Fresh database - use 1970 timestamp to get ALL records
    effectiveLastLogin = DateTime(1970, 1, 1).toUtc().toIso8601String();
    QuizzerLogger.logMessage('Fresh database detected - using 1970 timestamp to sync ALL records: $effectiveLastLogin');
  } else {
    // Existing database - use last_login from profile
    final String? lastLogin = await getLastLoginForUser(userId);
    effectiveLastLogin = lastLogin ?? DateTime(1970, 1, 1).toUtc().toIso8601String();
    QuizzerLogger.logMessage('Existing database - using last login timestamp: $effectiveLastLogin');
  }

  try {
    QuizzerLogger.logMessage('Starting inbound sync for user $userId...');

    // Execute all sync operations sequentially to avoid data loss issues
    // Sync question_answer_pairs
    await syncQuestionAnswerPairsInbound(userId, sessionManager.supabase, effectiveLastLogin: effectiveLastLogin);
    
    // Sync user_question_answer_pairs using the initial profile last_modified_timestamp
    await syncUserQuestionAnswerPairsInbound(userId, sessionManager.supabase, effectiveLastLogin: effectiveLastLogin);
    
    // Sync modules using the initial profile last_modified_timestamp
    await syncModulesInbound(sessionManager.supabase);
    
    // Sync subject_details using the local table's most recent timestamp
    await syncSubjectDetailsInbound(sessionManager.supabase);
    
    // Sync user stats using the initial profile last_modified_timestamp
    await syncUserStatsEligibleQuestionsInbound(userId, sessionManager.supabase, effectiveLastLogin: effectiveLastLogin);
    await syncUserStatsNonCirculatingQuestionsInbound(userId, sessionManager.supabase, effectiveLastLogin: effectiveLastLogin);
    await syncUserStatsInCirculationQuestionsInbound(userId, sessionManager.supabase, effectiveLastLogin: effectiveLastLogin);
    await syncUserStatsRevisionStreakSumInbound(userId, sessionManager.supabase, effectiveLastLogin: effectiveLastLogin);
    await syncUserStatsTotalUserQuestionAnswerPairsInbound(userId, sessionManager.supabase, effectiveLastLogin: effectiveLastLogin);
    await syncUserStatsAverageQuestionsShownPerDayInbound(userId, sessionManager.supabase, effectiveLastLogin: effectiveLastLogin);
    await syncUserStatsTotalQuestionsAnsweredInbound(userId, sessionManager.supabase, effectiveLastLogin: effectiveLastLogin);
    await syncUserStatsDailyQuestionsAnsweredInbound(userId, sessionManager.supabase, effectiveLastLogin: effectiveLastLogin);
    await syncUserStatsDaysLeftUntilQuestionsExhaustInbound(userId, sessionManager.supabase, effectiveLastLogin: effectiveLastLogin);
    await syncUserStatsAverageDailyQuestionsLearnedInbound(userId, sessionManager.supabase, effectiveLastLogin: effectiveLastLogin);
    await syncUserModuleActivationStatusInbound(userId, sessionManager.supabase, effectiveLastLogin: effectiveLastLogin);

    // Sync user settings separately to avoid race conditions
    QuizzerLogger.logMessage('Syncing user settings separately to avoid race conditions...');
    await syncUserSettingsInbound(userId, sessionManager.supabase, effectiveLastLogin: effectiveLastLogin);

    // Now sync the user profile LAST - this will update the last_login timestamp
    QuizzerLogger.logMessage('Syncing user profile last to update last_login timestamp...');
    await syncUserProfileInbound(userId, sessionManager.supabase, effectiveLastLogin: effectiveLastLogin);

    QuizzerLogger.logSuccess('Inbound sync completed successfully.');
  } catch (e) {
    QuizzerLogger.logError('runInboundSync: Error - $e');
    rethrow;
  }
}


