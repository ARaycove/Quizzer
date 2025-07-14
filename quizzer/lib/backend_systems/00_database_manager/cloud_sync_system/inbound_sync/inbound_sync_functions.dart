import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_other_signals.dart';
import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_settings_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_eligible_questions_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_non_circulating_questions_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_in_circulation_questions_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_revision_streak_sum_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_total_user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_average_questions_shown_per_day_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_total_questions_answered_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_daily_questions_answered_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_days_left_until_questions_exhaust_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_average_daily_questions_learned_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_module_activation_status_table.dart';
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

/// Syncs question_answer_pairs from the cloud that are newer than the most recent local record
Future<void> syncQuestionAnswerPairsInbound(
  String userId,
  SupabaseClient supabaseClient,
) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound question_answer_pairs for user $userId...');
    
    // Get the most recent last_modified_timestamp from local question_answer_pairs table
    String? localLastTimestamp;
    try {
      localLastTimestamp = await getMostRecentQuestionAnswerPairTimestamp();
      QuizzerLogger.logMessage('Most recent local question timestamp: ${localLastTimestamp ?? "No local records found"}');
    } catch (e) {
      QuizzerLogger.logError('Error getting local last timestamp: $e');
      // Fallback to using a very old timestamp if we can't get local timestamp
      localLastTimestamp = DateTime(1996, 8, 20).toUtc().toIso8601String();
    }
    
    // Use local timestamp if available, otherwise use a very old timestamp to get all records
    final String syncStartTimestamp = localLastTimestamp ?? DateTime.now().subtract(const Duration(days: 365 * 20)).toUtc().toIso8601String();
    QuizzerLogger.logMessage('Starting sync from timestamp: $syncStartTimestamp');
    
    int totalSynced = 0;
    int batchNumber = 0;
    bool hasMoreRecords = true;
    String? lastTimestamp = syncStartTimestamp;
    
    while (hasMoreRecords) {
      batchNumber++;
    List<dynamic> cloudRecords;
      
    try {
        // Build query with pagination - use the appropriate timestamp for this batch
        String queryTimestamp = batchNumber == 1 ? syncStartTimestamp : (lastTimestamp ?? syncStartTimestamp);
        
      cloudRecords = await supabaseClient
          .from('question_answer_pairs')
          .select('*')
            .gt('last_modified_timestamp', queryTimestamp)
            .order('last_modified_timestamp', ascending: true)
            .limit(500);
        
    } on PostgrestException catch (e, s) {
        QuizzerLogger.logError('syncQuestionAnswerPairsInbound: PostgrestException for user $userId (batch $batchNumber). Error: ${e.message}, Stack: $s');
      signalLoginProgress('Question sync: Error.');
      return;
    } on SocketException catch (e, s) {
        QuizzerLogger.logError('syncQuestionAnswerPairsInbound: SocketException for user $userId (batch $batchNumber). Error: $e, Stack: $s');
      signalLoginProgress('Question sync: Network error.');
      return;
    } catch (e, s) {
        QuizzerLogger.logError('syncQuestionAnswerPairsInbound: Unexpected error for user $userId (batch $batchNumber). Error: $e, Stack: $s');
      signalLoginProgress('Question sync: Unexpected error.');
      return;
    }

      if (cloudRecords.isEmpty) {
        hasMoreRecords = false;
        break;
      }

      // Update last timestamp for next batch (use the last record's timestamp)
      if (cloudRecords.isNotEmpty) {
        final lastRecord = cloudRecords.last as Map<String, dynamic>;
        lastTimestamp = lastRecord['last_modified_timestamp'] as String;
      }

      final int batchSize = cloudRecords.length;
      totalSynced += batchSize;
      
      QuizzerLogger.logMessage('Processing batch $batchNumber: $batchSize records (Total so far: $totalSynced)');
      
      if (batchNumber == 1) {
        // First batch - show initial count
        signalLoginProgress('Question sync: Found $batchSize questions.');
      } else {
        // Subsequent batches - show progress
        signalLoginProgress('Question sync: Found $totalSynced questions so far.');
      }

      // Process this batch
      final batch = List<Map<String, dynamic>>.from(cloudRecords);
      await batchUpsertQuestionAnswerPairs(records: batch);
      
      signalLoginProgress('Syncing Question $totalSynced (batch $batchNumber complete)');
      
      // If we got less than 500 records, we've reached the end
      if (batchSize < 500) {
        hasMoreRecords = false;
      }
    }

    if (totalSynced == 0) {
      QuizzerLogger.logMessage('No new question_answer_pairs to sync.');
      signalLoginProgress('Question sync: No new questions.');
    } else {
      QuizzerLogger.logSuccess('Synced $totalSynced question_answer_pairs from cloud in $batchNumber batches.');
    signalLoginProgress('Question sync: Complete.');
    }
  } catch (e) {
    QuizzerLogger.logError('syncQuestionAnswerPairsInbound: Error - $e');
    rethrow;
  }
}

/// Syncs user_question_answer_pairs from the cloud that are newer than the initial profile timestamp
Future<void> syncUserQuestionAnswerPairsInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_question_answer_pairs for user $userId since $initialTimestamp...');
    
    // Use initial timestamp if available, otherwise use a very old timestamp to get all records
    final String syncStartTimestamp = initialTimestamp ?? DateTime.now().subtract(const Duration(days: 365 * 20)).toUtc().toIso8601String();
    QuizzerLogger.logMessage('Starting sync from timestamp: $syncStartTimestamp');
    
    int totalSynced = 0;
    int batchNumber = 0;
    bool hasMoreRecords = true;
    String? lastTimestamp = syncStartTimestamp;
    
    while (hasMoreRecords) {
      batchNumber++;
    List<dynamic> cloudRecords;
      
    try {
        // Build query with pagination - use the appropriate timestamp for this batch
        String queryTimestamp = batchNumber == 1 ? syncStartTimestamp : (lastTimestamp ?? syncStartTimestamp);
        
      cloudRecords = await supabaseClient
          .from('user_question_answer_pairs')
          .select('*')
          .eq('user_uuid', userId)
            .gt('last_modified_timestamp', queryTimestamp)
            .order('last_modified_timestamp', ascending: true)
            .limit(500);
        
    } on PostgrestException catch (e, s) {
        QuizzerLogger.logError('syncUserQuestionAnswerPairsInbound: PostgrestException for user $userId (batch $batchNumber). Error: ${e.message}, Stack: $s');
      signalLoginProgress('User progress sync: Error.');
      return;
    } on SocketException catch (e, s) {
        QuizzerLogger.logError('syncUserQuestionAnswerPairsInbound: SocketException for user $userId (batch $batchNumber). Error: $e, Stack: $s');
      signalLoginProgress('User progress sync: Network error.');
      return;
    } catch (e, s) {
        QuizzerLogger.logError('syncUserQuestionAnswerPairsInbound: Unexpected error for user $userId (batch $batchNumber). Error: $e, Stack: $s');
      signalLoginProgress('User progress sync: Unexpected error.');
      return;
    }

    if (cloudRecords.isEmpty) {
        hasMoreRecords = false;
        break;
      }

      // Update last timestamp for next batch (use the last record's timestamp)
      if (cloudRecords.isNotEmpty) {
        final lastRecord = cloudRecords.last as Map<String, dynamic>;
        lastTimestamp = lastRecord['last_modified_timestamp'] as String;
    }

      final int batchSize = cloudRecords.length;
      totalSynced += batchSize;
      
      QuizzerLogger.logMessage('Processing batch $batchNumber: $batchSize records (Total so far: $totalSynced)');
      
      if (batchNumber == 1) {
        // First batch - show initial count
        signalLoginProgress('User progress sync: Found $batchSize records.');
      } else {
        // Subsequent batches - show progress
        signalLoginProgress('User progress sync: Found $totalSynced records so far.');
      }

      // Process this batch
      final batch = List<Map<String, dynamic>>.from(cloudRecords);
      await batchUpsertUserQuestionAnswerPairs(records: batch);
      
      signalLoginProgress('Syncing User Progress $totalSynced (batch $batchNumber complete)');
      
      // If we got less than 500 records, we've reached the end
      if (batchSize < 500) {
        hasMoreRecords = false;
      }
    }

    if (totalSynced == 0) {
      QuizzerLogger.logMessage('No new user_question_answer_pairs to sync.');
      signalLoginProgress('User progress sync: No new records.');
    } else {
      QuizzerLogger.logSuccess('Synced $totalSynced user_question_answer_pairs from cloud in $batchNumber batches.');
    signalLoginProgress('User progress sync: Complete.');
    }
  } catch (e) {
    QuizzerLogger.logError('syncUserQuestionAnswerPairsInbound: Error - $e');
    rethrow;
  }
}

/// Syncs user profile from the cloud that is newer than the initial profile timestamp
Future<void> syncUserProfileInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user profile for user $userId since $initialTimestamp...');
    
    // If no initial timestamp, fetch the profile
    try {
      final List<dynamic> cloudRecords = await supabaseClient
          .from('user_profile')
          .select('*')
          .eq('uuid', userId)
          .gt('last_modified_timestamp', initialTimestamp ?? '');

      if (cloudRecords.isEmpty) {
        QuizzerLogger.logMessage('No new user profile to sync.');
        return;
      }

      QuizzerLogger.logMessage('Found updated user profile to sync.');
      final record = cloudRecords.first; // Should only be one record per user

      // Update the local profile using the refactored function that handles its own database access
      await upsertUserProfileFromInboundSync(record);

      QuizzerLogger.logSuccess('Synced user profile from cloud.');
    } on PostgrestException catch (e, s) {
      QuizzerLogger.logError('syncUserProfileInbound: PostgrestException while fetching user profile for $userId. Error: ${e.message}, Stack: $s');
    } on SocketException catch (e, s) {
      QuizzerLogger.logError('syncUserProfileInbound: SocketException while fetching user profile for $userId. Error: $e, Stack: $s');
    } catch (e, s) {
      QuizzerLogger.logError('syncUserProfileInbound: Unexpected error while fetching user profile for $userId. Error: $e, Stack: $s');
    }
  } catch (e) {
    QuizzerLogger.logError('syncUserProfileInbound: Error - $e');
    rethrow;
  }
}

/// Syncs user settings from the cloud that are newer than the initial profile timestamp for the user.
Future<void> syncUserSettingsInbound(
  String userId,
  String? initialTimestamp, // This is the last_modified_timestamp of the user_profile at login
  SupabaseClient supabaseClient,
) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_settings for user $userId since $initialTimestamp...');

    try {
      final List<dynamic> cloudRecords = await executeSupabaseCallWithRetry(
        () => supabaseClient
            .from('user_settings') // Target table
            .select('*') // Select all columns
            .eq('user_id', userId) // Filter by user_id
            .gt('last_modified_timestamp', initialTimestamp ?? DateTime(1970).toIso8601String()) // Filter by timestamp
            .then((response) => List<dynamic>.from(response as List)),
        logContext: 'syncUserSettingsInbound: Fetching for user $userId',
      );

      if (cloudRecords.isEmpty) {
        QuizzerLogger.logMessage('No new user_settings to sync for user $userId.');
        return;
      }

      QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_settings to sync for user $userId.');

      for (final record in cloudRecords) {
        if (record is Map<String, dynamic>) {
          // Use the refactored function that handles its own database access
          await upsertFromSupabase(record);
        } else {
          QuizzerLogger.logWarning('syncUserSettingsInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
        }
      }

      QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_settings from cloud for user $userId.');
    } on PostgrestException catch (e, s) {
      QuizzerLogger.logError('syncUserSettingsInbound: PostgrestException (potentially non-retriable or after retries) for user $userId. Error: ${e.message}, Stack: $s');
    } on SocketException catch (e, s) {
      QuizzerLogger.logError('syncUserSettingsInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
    } catch (e, s) {
      QuizzerLogger.logError('syncUserSettingsInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
    }
  } catch (e) {
    QuizzerLogger.logError('syncUserSettingsInbound: Error - $e');
    rethrow;
  }
}

/// Syncs modules from the cloud that are newer than the initial profile timestamp
Future<void> syncModulesInbound(
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound modules since $initialTimestamp...');

    List<dynamic> cloudRecords;
    try {
      cloudRecords = await executeSupabaseCallWithRetry(
        () => supabaseClient
            .from('modules')
            .select('*')
            .gt('last_modified_timestamp', initialTimestamp ?? DateTime(1970).toIso8601String())
            .then((response) => List<dynamic>.from(response as List)),
        logContext: 'syncModulesInbound: Fetching modules',
      );
    } on PostgrestException catch (e, s) {
      QuizzerLogger.logError('syncModulesInbound: PostgrestException (potentially non-retriable or after retries). Error: ${e.message}, Stack: $s');
      return;
    } on SocketException catch (e, s) {
      QuizzerLogger.logError('syncModulesInbound: SocketException (after retries). Error: $e, Stack: $s');
      return;
    } catch (e, s) {
      QuizzerLogger.logError('syncModulesInbound: Unexpected error. Error: $e, Stack: $s');
      return;
    }

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new modules to sync.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated modules to sync.');

    for (final record in cloudRecords) {
      if (record is Map<String, dynamic>) {
        // Only sync the fields we store in Supabase
        await upsertModuleFromInboundSync(
          moduleName: record['module_name'],
          description: record['description'],
        );
      } else {
        QuizzerLogger.logWarning('syncModulesInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
      }
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} modules from cloud.');
  } catch (e) {
    QuizzerLogger.logError('syncModulesInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsEligibleQuestionsInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_eligible_questions for user $userId since $initialTimestamp...');

    List<dynamic> cloudRecords;
    try {
      cloudRecords = await executeSupabaseCallWithRetry(
        () => supabaseClient
            .from('user_stats_eligible_questions')
            .select('*')
            .eq('user_id', userId)
            .gt('last_modified_timestamp', initialTimestamp ?? DateTime(1970).toIso8601String())
            .then((response) => List<dynamic>.from(response as List)),
        logContext: 'syncUserStatsEligibleQuestionsInbound: Fetching for user $userId',
      );
    } on PostgrestException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsEligibleQuestionsInbound: PostgrestException (potentially non-retriable or after retries) for user $userId. Error: ${e.message}, Stack: $s');
      return;
    } on SocketException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsEligibleQuestionsInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
      return;
    } catch (e, s) {
      QuizzerLogger.logError('syncUserStatsEligibleQuestionsInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
      return;
    }

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_eligible_questions to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_eligible_questions to sync for user $userId.');

    for (final record in cloudRecords) {
      if (record is Map<String, dynamic>) {
        await upsertUserStatsEligibleQuestionsFromInboundSync(record);
      } else {
        QuizzerLogger.logWarning('syncUserStatsEligibleQuestionsInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
      }
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_eligible_questions from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsEligibleQuestionsInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsNonCirculatingQuestionsInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_non_circulating_questions for user $userId since $initialTimestamp...');

    List<dynamic> cloudRecords;
    try {
      cloudRecords = await executeSupabaseCallWithRetry(
        () => supabaseClient
            .from('user_stats_non_circulating_questions')
            .select('*')
            .eq('user_id', userId)
            .gt('last_modified_timestamp', initialTimestamp ?? DateTime(1970).toIso8601String())
            .then((response) => List<dynamic>.from(response as List)),
        logContext: 'syncUserStatsNonCirculatingQuestionsInbound: Fetching for user $userId',
      );
    } on PostgrestException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsNonCirculatingQuestionsInbound: PostgrestException (potentially non-retriable or after retries) for user $userId. Error: ${e.message}, Stack: $s');
      return;
    } on SocketException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsNonCirculatingQuestionsInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
      return;
    } catch (e, s) {
      QuizzerLogger.logError('syncUserStatsNonCirculatingQuestionsInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
      return;
    }

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_non_circulating_questions to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_non_circulating_questions to sync for user $userId.');

    for (final record in cloudRecords) {
      if (record is Map<String, dynamic>) {
        await upsertUserStatsNonCirculatingQuestionsFromInboundSync(record);
      } else {
        QuizzerLogger.logWarning('syncUserStatsNonCirculatingQuestionsInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
      }
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_non_circulating_questions from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsNonCirculatingQuestionsInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsInCirculationQuestionsInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_in_circulation_questions for user $userId since $initialTimestamp...');

    List<dynamic> cloudRecords;
    try {
      cloudRecords = await executeSupabaseCallWithRetry(
        () => supabaseClient
            .from('user_stats_in_circulation_questions')
            .select('*')
            .eq('user_id', userId)
            .gt('last_modified_timestamp', initialTimestamp ?? DateTime(1970).toIso8601String())
            .then((response) => List<dynamic>.from(response as List)),
        logContext: 'syncUserStatsInCirculationQuestionsInbound: Fetching for user $userId',
      );
    } on PostgrestException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsInCirculationQuestionsInbound: PostgrestException (potentially non-retriable or after retries) for user $userId. Error: ${e.message}, Stack: $s');
      return;
    } on SocketException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsInCirculationQuestionsInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
      return;
    } catch (e, s) {
      QuizzerLogger.logError('syncUserStatsInCirculationQuestionsInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
      return;
    }

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_in_circulation_questions to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_in_circulation_questions to sync for user $userId.');

    for (final record in cloudRecords) {
      if (record is Map<String, dynamic>) {
        await upsertUserStatsInCirculationQuestionsFromInboundSync(record);
      } else {
        QuizzerLogger.logWarning('syncUserStatsInCirculationQuestionsInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
      }
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_in_circulation_questions from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsInCirculationQuestionsInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsRevisionStreakSumInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_revision_streak_sum for user $userId since $initialTimestamp...');

    List<dynamic> cloudRecords;
    try {
      cloudRecords = await executeSupabaseCallWithRetry(
        () => supabaseClient
            .from('user_stats_revision_streak_sum')
            .select('*')
            .eq('user_id', userId)
            .gt('last_modified_timestamp', initialTimestamp ?? DateTime(1970).toIso8601String())
            .then((response) => List<dynamic>.from(response as List)),
        logContext: 'syncUserStatsRevisionStreakSumInbound: Fetching for user $userId',
      );
    } on PostgrestException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsRevisionStreakSumInbound: PostgrestException (potentially non-retriable or after retries) for user $userId. Error: ${e.message}, Stack: $s');
      return;
    } on SocketException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsRevisionStreakSumInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
      return;
    } catch (e, s) {
      QuizzerLogger.logError('syncUserStatsRevisionStreakSumInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
      return;
    }

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_revision_streak_sum to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_revision_streak_sum to sync for user $userId.');

    for (final record in cloudRecords) {
      if (record is Map<String, dynamic>) {
        await upsertUserStatsRevisionStreakSumFromInboundSync(record);
      } else {
        QuizzerLogger.logWarning('syncUserStatsRevisionStreakSumInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
      }
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_revision_streak_sum from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsRevisionStreakSumInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsTotalUserQuestionAnswerPairsInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_total_user_question_answer_pairs for user $userId since $initialTimestamp...');

    List<dynamic> cloudRecords;
    try {
      cloudRecords = await executeSupabaseCallWithRetry(
        () => supabaseClient
            .from('user_stats_total_user_question_answer_pairs')
            .select('*')
            .eq('user_id', userId)
            .gt('last_modified_timestamp', initialTimestamp ?? DateTime(1970).toIso8601String())
            .then((response) => List<dynamic>.from(response as List)),
        logContext: 'syncUserStatsTotalUserQuestionAnswerPairsInbound: Fetching for user $userId',
      );
    } on PostgrestException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsTotalUserQuestionAnswerPairsInbound: PostgrestException (potentially non-retriable or after retries) for user $userId. Error: ${e.message}, Stack: $s');
      return;
    } on SocketException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsTotalUserQuestionAnswerPairsInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
      return;
    } catch (e, s) {
      QuizzerLogger.logError('syncUserStatsTotalUserQuestionAnswerPairsInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
      return;
    }

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_total_user_question_answer_pairs to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_total_user_question_answer_pairs to sync for user $userId.');

    for (final record in cloudRecords) {
      if (record is Map<String, dynamic>) {
        await upsertUserStatsTotalUserQuestionAnswerPairsFromInboundSync(record);
      } else {
        QuizzerLogger.logWarning('syncUserStatsTotalUserQuestionAnswerPairsInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
      }
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_total_user_question_answer_pairs from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsTotalUserQuestionAnswerPairsInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsAverageQuestionsShownPerDayInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_average_questions_shown_per_day for user $userId since $initialTimestamp...');

    List<dynamic> cloudRecords;
    try {
      cloudRecords = await executeSupabaseCallWithRetry(
        () => supabaseClient
            .from('user_stats_average_questions_shown_per_day')
            .select('*')
            .eq('user_id', userId)
            .gt('last_modified_timestamp', initialTimestamp ?? DateTime(1970).toIso8601String())
            .then((response) => List<dynamic>.from(response as List)),
        logContext: 'syncUserStatsAverageQuestionsShownPerDayInbound: Fetching for user $userId',
      );
    } on PostgrestException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsAverageQuestionsShownPerDayInbound: PostgrestException (potentially non-retriable or after retries) for user $userId. Error: \u001b[38;5;9m${e.message}[0m, Stack: $s');
      return;
    } on SocketException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsAverageQuestionsShownPerDayInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
      return;
    } catch (e, s) {
      QuizzerLogger.logError('syncUserStatsAverageQuestionsShownPerDayInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
      return;
    }

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_average_questions_shown_per_day to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found \u001b[38;5;10m${cloudRecords.length}[0m new/updated user_stats_average_questions_shown_per_day to sync for user $userId.');

    for (final record in cloudRecords) {
      if (record is Map<String, dynamic>) {
        await upsertUserStatsAverageQuestionsShownPerDayFromInboundSync(record);
      } else {
        QuizzerLogger.logWarning('syncUserStatsAverageQuestionsShownPerDayInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
      }
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_average_questions_shown_per_day from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsAverageQuestionsShownPerDayInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsTotalQuestionsAnsweredInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_total_questions_answered for user $userId since $initialTimestamp...');

    List<dynamic> cloudRecords;
    try {
      cloudRecords = await executeSupabaseCallWithRetry(
        () => supabaseClient
            .from('user_stats_total_questions_answered')
            .select('*')
            .eq('user_id', userId)
            .gt('last_modified_timestamp', initialTimestamp ?? DateTime(1970).toIso8601String())
            .then((response) => List<dynamic>.from(response as List)),
        logContext: 'syncUserStatsTotalQuestionsAnsweredInbound: Fetching for user $userId',
      );
    } on PostgrestException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsTotalQuestionsAnsweredInbound: PostgrestException (potentially non-retriable or after retries) for user $userId. Error: \u001b[38;5;9m${e.message}[0m, Stack: $s');
      return;
    } on SocketException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsTotalQuestionsAnsweredInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
      return;
    } catch (e, s) {
      QuizzerLogger.logError('syncUserStatsTotalQuestionsAnsweredInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
      return;
    }

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_total_questions_answered to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found \u001b[38;5;10m${cloudRecords.length}\u001b[0m new/updated user_stats_total_questions_answered to sync for user $userId.');

    for (final record in cloudRecords) {
      if (record is Map<String, dynamic>) {
        await upsertUserStatsTotalQuestionsAnsweredFromInboundSync(record);
      } else {
        QuizzerLogger.logWarning('syncUserStatsTotalQuestionsAnsweredInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
      }
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_total_questions_answered from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsTotalQuestionsAnsweredInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsDailyQuestionsAnsweredInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_daily_questions_answered for user $userId since $initialTimestamp...');

    List<dynamic> cloudRecords;
    try {
      cloudRecords = await executeSupabaseCallWithRetry(
        () => supabaseClient
            .from('user_stats_daily_questions_answered')
            .select('*')
            .eq('user_id', userId)
            .gt('last_modified_timestamp', initialTimestamp ?? DateTime(1970).toIso8601String())
            .then((response) => List<dynamic>.from(response as List)),
        logContext: 'syncUserStatsDailyQuestionsAnsweredInbound: Fetching for user $userId',
      );
    } on PostgrestException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsDailyQuestionsAnsweredInbound: PostgrestException (potentially non-retriable or after retries) for user $userId. Error: \u001b[38;5;9m${e.message}[0m, Stack: $s');
      return;
    } on SocketException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsDailyQuestionsAnsweredInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
      return;
    } catch (e, s) {
      QuizzerLogger.logError('syncUserStatsDailyQuestionsAnsweredInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
      return;
    }

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_daily_questions_answered to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found \u001b[38;5;10m${cloudRecords.length}[0m new/updated user_stats_daily_questions_answered to sync for user $userId.');

    for (final record in cloudRecords) {
      if (record is Map<String, dynamic>) {
        await upsertUserStatsDailyQuestionsAnsweredFromInboundSync(record);
      } else {
        QuizzerLogger.logWarning('syncUserStatsDailyQuestionsAnsweredInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
      }
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_daily_questions_answered from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsDailyQuestionsAnsweredInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsDaysLeftUntilQuestionsExhaustInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_days_left_until_questions_exhaust for user $userId since $initialTimestamp...');

    List<dynamic> cloudRecords;
    try {
      cloudRecords = await executeSupabaseCallWithRetry(
        () => supabaseClient
            .from('user_stats_days_left_until_questions_exhaust')
            .select('*')
            .eq('user_id', userId)
            .gt('last_modified_timestamp', initialTimestamp ?? DateTime(1970).toIso8601String())
            .then((response) => List<dynamic>.from(response as List)),
        logContext: 'syncUserStatsDaysLeftUntilQuestionsExhaustInbound: Fetching for user $userId',
      );
    } on PostgrestException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsDaysLeftUntilQuestionsExhaustInbound: PostgrestException (potentially non-retriable or after retries) for user $userId. Error: \u001b[38;5;9m\u001b[0m${e.message}, Stack: $s');
      return;
    } on SocketException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsDaysLeftUntilQuestionsExhaustInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
      return;
    } catch (e, s) {
      QuizzerLogger.logError('syncUserStatsDaysLeftUntilQuestionsExhaustInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
      return;
    }

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_days_left_until_questions_exhaust to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found [38;5;10m${cloudRecords.length}[0m new/updated user_stats_days_left_until_questions_exhaust to sync for user $userId.');

    for (final record in cloudRecords) {
      if (record is Map<String, dynamic>) {
        await upsertUserStatsDaysLeftUntilQuestionsExhaustFromInboundSync(record);
      } else {
        QuizzerLogger.logWarning('syncUserStatsDaysLeftUntilQuestionsExhaustInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
      }
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_days_left_until_questions_exhaust from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsDaysLeftUntilQuestionsExhaustInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsAverageDailyQuestionsLearnedInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_stats_average_daily_questions_learned for user $userId since $initialTimestamp...');

    List<dynamic> cloudRecords;
    try {
      cloudRecords = await executeSupabaseCallWithRetry(
        () => supabaseClient
            .from('user_stats_average_daily_questions_learned')
            .select('*')
            .eq('user_id', userId)
            .gt('last_modified_timestamp', initialTimestamp ?? DateTime(1970).toIso8601String())
            .then((response) => List<dynamic>.from(response as List)),
        logContext: 'syncUserStatsAverageDailyQuestionsLearnedInbound: Fetching for user $userId',
      );
    } on PostgrestException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsAverageDailyQuestionsLearnedInbound: PostgrestException (potentially non-retriable or after retries) for user $userId. Error: \u001b[38;5;9m\u001b[0m${e.message}, Stack: $s');
      return;
    } on SocketException catch (e, s) {
      QuizzerLogger.logError('syncUserStatsAverageDailyQuestionsLearnedInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
      return;
    } catch (e, s) {
      QuizzerLogger.logError('syncUserStatsAverageDailyQuestionsLearnedInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
      return;
    }

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_stats_average_daily_questions_learned to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found \u001b[38;5;10m${cloudRecords.length}\u001b[0m new/updated user_stats_average_daily_questions_learned to sync for user $userId.');

    for (final record in cloudRecords) {
      if (record is Map<String, dynamic>) {
        await upsertUserStatsAverageDailyQuestionsLearnedFromInboundSync(record);
      } else {
        QuizzerLogger.logWarning('syncUserStatsAverageDailyQuestionsLearnedInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
      }
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_average_daily_questions_learned from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsAverageDailyQuestionsLearnedInbound: Error - $e');
    rethrow;
  }
}

Future<void> syncUserModuleActivationStatusInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  try {
    QuizzerLogger.logMessage('Syncing inbound user_module_activation_status for user $userId since $initialTimestamp...');

    List<dynamic> cloudRecords;
    try {
      cloudRecords = await executeSupabaseCallWithRetry(
        () => supabaseClient
            .from('user_module_activation_status')
            .select('*')
            .eq('user_id', userId)
            .gt('last_modified_timestamp', initialTimestamp ?? DateTime(1970).toIso8601String())
            .then((response) => List<dynamic>.from(response as List)),
        logContext: 'syncUserModuleActivationStatusInbound: Fetching for user $userId',
      );
    } on PostgrestException catch (e, s) {
      QuizzerLogger.logError('syncUserModuleActivationStatusInbound: PostgrestException (potentially non-retriable or after retries) for user $userId. Error: ${e.message}, Stack: $s');
      return;
    } on SocketException catch (e, s) {
      QuizzerLogger.logError('syncUserModuleActivationStatusInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
      return;
    } catch (e, s) {
      QuizzerLogger.logError('syncUserModuleActivationStatusInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
      return;
    }

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_module_activation_status to sync for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_module_activation_status to sync for user $userId.');

    for (final record in cloudRecords) {
      if (record is Map<String, dynamic>) {
        await upsertModuleActivationStatusFromInboundSync(
          userId: record['user_id'] as String,
          moduleName: record['module_name'] as String,
          isActive: (record['is_active'] as int) == 1,
          lastModifiedTimestamp: record['last_modified_timestamp'] as String,
        );
      } else {
        QuizzerLogger.logWarning('syncUserModuleActivationStatusInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
      }
    }

    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_module_activation_status from cloud for user $userId.');
  } catch (e) {
    QuizzerLogger.logError('syncUserModuleActivationStatusInbound: Error - $e');
    rethrow;
  }
}

Future<void> runInboundSync(SessionManager sessionManager) async {
  QuizzerLogger.logMessage('Starting inbound sync aggregator...');
  final String? userId = sessionManager.userId;

  // Get last_login timestamp using the imported helper
  final String? lastLogin = await getLastLoginForUser(userId!);
  // If lastLogin is null, set it to 20 years ago to ensure we get all records
  final String effectiveLastLogin = lastLogin ?? DateTime.now().subtract(const Duration(days: 365 * 20)).toUtc().toIso8601String();
  QuizzerLogger.logMessage('Using effective last login timestamp: $effectiveLastLogin');

  // Get initial profile timestamp, if null set to 20 years ago
  final String? initialTimestamp = sessionManager.initialProfileLastModified;
  final String effectiveInitialTimestamp = initialTimestamp ?? DateTime.now().subtract(const Duration(days: 365 * 20)).toUtc().toIso8601String();
  QuizzerLogger.logMessage('Using effective initial timestamp: $effectiveInitialTimestamp');

  // Run all sync operations concurrently using Future.wait()
  await Future.wait([
    // Sync question_answer_pairs
    syncQuestionAnswerPairsInbound(userId, sessionManager.supabase),

  // Sync user_question_answer_pairs using the initial profile last_modified_timestamp
    syncUserQuestionAnswerPairsInbound(userId, effectiveInitialTimestamp, sessionManager.supabase),

  // Sync user profile using the initial profile last_modified_timestamp
    syncUserProfileInbound(userId, effectiveInitialTimestamp, sessionManager.supabase),

  // Sync user settings using the initial profile last_modified_timestamp
    syncUserSettingsInbound(userId, effectiveInitialTimestamp, sessionManager.supabase),

  // Sync modules using the initial profile last_modified_timestamp
    syncModulesInbound(effectiveInitialTimestamp, sessionManager.supabase),

  // Sync user_stats_eligible_questions using the initial profile last_modified_timestamp
    syncUserStatsEligibleQuestionsInbound(userId, effectiveInitialTimestamp, sessionManager.supabase),

  // Sync user_stats_non_circulating_questions using the initial profile last_modified_timestamp
    syncUserStatsNonCirculatingQuestionsInbound(userId, effectiveInitialTimestamp, sessionManager.supabase),

  // Sync user_stats_in_circulation_questions using the initial profile last_modified_timestamp
    syncUserStatsInCirculationQuestionsInbound(userId, effectiveInitialTimestamp, sessionManager.supabase),

  // Sync user_stats_revision_streak_sum using the initial profile last_modified_timestamp
    syncUserStatsRevisionStreakSumInbound(userId, effectiveInitialTimestamp, sessionManager.supabase),

  // Sync user_stats_total_user_question_answer_pairs using the initial profile last_modified_timestamp
    syncUserStatsTotalUserQuestionAnswerPairsInbound(userId, effectiveInitialTimestamp, sessionManager.supabase),

  // Sync user_stats_average_questions_shown_per_day using the initial profile last_modified_timestamp
    syncUserStatsAverageQuestionsShownPerDayInbound(userId, effectiveInitialTimestamp, sessionManager.supabase),

  // Sync user_stats_total_questions_answered using the initial profile last_modified_timestamp
    syncUserStatsTotalQuestionsAnsweredInbound(userId, effectiveInitialTimestamp, sessionManager.supabase),

  // Sync user_stats_daily_questions_answered using the initial profile last_modified_timestamp
    syncUserStatsDailyQuestionsAnsweredInbound(userId, effectiveInitialTimestamp, sessionManager.supabase),

  // Sync user_stats_days_left_until_questions_exhaust using the initial profile last_modified_timestamp
    syncUserStatsDaysLeftUntilQuestionsExhaustInbound(userId, effectiveInitialTimestamp, sessionManager.supabase),

  // Sync user_stats_average_daily_questions_learned using the initial profile last_modified_timestamp
    syncUserStatsAverageDailyQuestionsLearnedInbound(userId, effectiveInitialTimestamp, sessionManager.supabase),
    
    // Sync user_module_activation_status using the initial profile last_modified_timestamp
    syncUserModuleActivationStatusInbound(userId, effectiveInitialTimestamp, sessionManager.supabase),
  ]);

  QuizzerLogger.logSuccess('Inbound sync completed successfully.');
}


