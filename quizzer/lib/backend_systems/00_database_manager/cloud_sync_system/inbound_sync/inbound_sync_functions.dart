import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite/sqflite.dart';
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
import 'dart:io'; // For SocketException
import 'dart:async'; // For Future.delayed

Future<T> executeSupabaseCallWithRetry<T>(
  Future<T> Function() supabaseCall, {
  int maxRetries = 3,
  Duration initialDelay = const Duration(seconds: 2), // Increased initial delay
  String? logContext,
}) async {
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
}

/// Syncs question_answer_pairs from the cloud that are newer than last_login
Future<void> syncQuestionAnswerPairsInbound(
  String userId,
  String lastLogin,
  SupabaseClient supabaseClient,
) async {
  SessionManager sessionManager = getSessionManager();
  QuizzerLogger.logMessage('Syncing inbound question_answer_pairs for user $userId since $lastLogin...');
  List<dynamic> cloudRecords;
  try {
    cloudRecords = await supabaseClient
        .from('question_answer_pairs')
        .select('*')
        .gt('last_modified_timestamp', lastLogin);
  } on PostgrestException catch (e, s) {
    QuizzerLogger.logError('syncQuestionAnswerPairsInbound: PostgrestException for user $userId. Error: ${e.message}, Stack: $s');
    sessionManager.addLoginProgress('Question sync: Error.');
    return;
  } on SocketException catch (e, s) {
    QuizzerLogger.logError('syncQuestionAnswerPairsInbound: SocketException for user $userId. Error: $e, Stack: $s');
    sessionManager.addLoginProgress('Question sync: Network error.');
    return;
  } catch (e, s) {
    QuizzerLogger.logError('syncQuestionAnswerPairsInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
    sessionManager.addLoginProgress('Question sync: Unexpected error.');
    return;
  }

  final int totalToSync = cloudRecords.length;

  if (totalToSync == 0) {
    QuizzerLogger.logMessage('No new question_answer_pairs to sync.');
    sessionManager.addLoginProgress('Question sync: No new questions.');
    return;
  }

  QuizzerLogger.logMessage('Found $totalToSync new/updated question_answer_pairs to sync.');
  sessionManager.addLoginProgress('Question sync: Found $totalToSync questions.');
  final DatabaseMonitor monitor = getDatabaseMonitor();
  Database? db = await monitor.requestDatabaseAccess();
  QuizzerLogger.logMessage('Database Access Granted');
  int syncedCount = 0;
  // Batch size for transaction
  const int batchSize = 500;
  for (int i = 0; i < cloudRecords.length; i += batchSize) {
    final end = (i + batchSize < cloudRecords.length) ? i + batchSize : cloudRecords.length;
    final batch = List<Map<String, dynamic>>.from(cloudRecords.sublist(i, end));
    await db!.transaction((txn) async {
      await batchUpsertQuestionAnswerPairs(records: batch, db: txn);
      syncedCount += batch.length;
      sessionManager.addLoginProgress('Syncing Question $syncedCount/$totalToSync');
    });
  }
  monitor.releaseDatabaseAccess();
  QuizzerLogger.logMessage('Database Released');
  QuizzerLogger.logSuccess('Synced $totalToSync question_answer_pairs from cloud.');
  sessionManager.addLoginProgress('Question sync: Complete.');
}

/// Syncs user_question_answer_pairs from the cloud that are newer than the initial profile timestamp
Future<void> syncUserQuestionAnswerPairsInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  QuizzerLogger.logMessage('Syncing inbound user_question_answer_pairs for user $userId since $initialTimestamp...');
  final SessionManager sessionManager = getSessionManager();
  List<dynamic> cloudRecords;
  try {
    cloudRecords = await supabaseClient
        .from('user_question_answer_pairs')
        .select('*')
        .eq('user_uuid', userId)
        .gt('last_modified_timestamp', initialTimestamp ?? '');
  } on PostgrestException catch (e, s) {
    QuizzerLogger.logError('syncUserQuestionAnswerPairsInbound: PostgrestException for user $userId. Error: ${e.message}, Stack: $s');
    sessionManager.addLoginProgress('User progress sync: Error.');
    return;
  } on SocketException catch (e, s) {
    QuizzerLogger.logError('syncUserQuestionAnswerPairsInbound: SocketException for user $userId. Error: $e, Stack: $s');
    sessionManager.addLoginProgress('User progress sync: Network error.');
    return;
  } catch (e, s) {
    QuizzerLogger.logError('syncUserQuestionAnswerPairsInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
    sessionManager.addLoginProgress('User progress sync: Unexpected error.');
    return;
  }

  if (cloudRecords.isEmpty) {
    QuizzerLogger.logMessage('No new user_question_answer_pairs to sync.');
    sessionManager.addLoginProgress('User progress sync: No new records.');
    return;
  }

  final int totalToSync = cloudRecords.length;
  QuizzerLogger.logMessage('Found $totalToSync new/updated user_question_answer_pairs to sync.');
  sessionManager.addLoginProgress('User progress sync: Found $totalToSync records.');

  final DatabaseMonitor monitor = getDatabaseMonitor();
  Database? db = await monitor.requestDatabaseAccess();
  QuizzerLogger.logMessage('Database Access Granted');

  // Process in batches of 500
  const int batchSize = 500;
  int processedCount = 0;
  for (int i = 0; i < cloudRecords.length; i += batchSize) {
    final end = (i + batchSize < cloudRecords.length) ? i + batchSize : cloudRecords.length;
    final batch = List<Map<String, dynamic>>.from(cloudRecords.sublist(i, end));
    await db!.transaction((txn) async {
      await batchUpsertUserQuestionAnswerPairs(records: batch, db: txn);
      processedCount += batch.length;
      sessionManager.addLoginProgress('Syncing User Progress $processedCount/$totalToSync');
    });
  }

  monitor.releaseDatabaseAccess();
  QuizzerLogger.logMessage('Database Released');
  QuizzerLogger.logSuccess('Synced $processedCount user_question_answer_pairs from cloud.');
  sessionManager.addLoginProgress('User progress sync: Complete.');
}

/// Syncs user profile from the cloud that is newer than the initial profile timestamp
Future<void> syncUserProfileInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  QuizzerLogger.logMessage('Syncing inbound user profile for user $userId since $initialTimestamp...');
  final SessionManager sessionManager = getSessionManager();
  
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

    final DatabaseMonitor monitor = getDatabaseMonitor();
    Database? db = await monitor.requestDatabaseAccess();
    QuizzerLogger.logMessage('Database Access Granted');
    // Update the local profile (no encoding)
    await db!.update(
      'user_profile',
      {
        'email': record['email'],
        'username': record['username'],
        'role': record['role'],
        'account_status': record['account_status'],
        'profile_picture': record['profile_picture'],
        'birth_date': record['birth_date'],
        'address': record['address'],
        'job_title': record['job_title'],
        'education_level': record['education_level'],
        'specialization': record['specialization'],
        'teaching_experience': record['teaching_experience'],
        'primary_language': record['primary_language'],
        'secondary_languages': record['secondary_languages'],
        'study_schedule': record['study_schedule'],
        'social_links': record['social_links'],
        'achievement_sharing': record['achievement_sharing'],
        'interest_data': record['interest_data'],
        'settings': record['settings'],
        'notification_preferences': record['notification_preferences'],
        'learning_streak': record['learning_streak'],
        'total_study_time': record['total_study_time'],
        'total_questions_answered': record['total_questions_answered'],
        'average_session_length': record['average_session_length'],
        'peak_cognitive_hours': record['peak_cognitive_hours'],
        'health_data': record['health_data'],
        'recall_accuracy_trends': record['recall_accuracy_trends'],
        'content_portfolio': record['content_portfolio'],
        'activation_status_of_modules': record['activation_status_of_modules'],
        'completion_status_of_modules': record['completion_status_of_modules'],
        'tutorial_progress': record['tutorial_progress'],
        'has_been_synced': 1,
        'edits_are_synced': 1,
        'last_modified_timestamp': record['last_modified_timestamp'],
      },
      where: 'uuid = ?',
      whereArgs: [userId],
    );
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');

    QuizzerLogger.logSuccess('Synced user profile from cloud.');
  } on PostgrestException catch (e, s) {
    QuizzerLogger.logError('syncUserProfileInbound: PostgrestException while fetching user profile for $userId. Error: ${e.message}, Stack: $s');
  } on SocketException catch (e, s) {
    QuizzerLogger.logError('syncUserProfileInbound: SocketException while fetching user profile for $userId. Error: $e, Stack: $s');
  } catch (e, s) {
    QuizzerLogger.logError('syncUserProfileInbound: Unexpected error while fetching user profile for $userId. Error: $e, Stack: $s');
  }
}

/// Syncs user settings from the cloud that are newer than the initial profile timestamp for the user.
Future<void> syncUserSettingsInbound(
  String userId,
  String? initialTimestamp, // This is the last_modified_timestamp of the user_profile at login
  SupabaseClient supabaseClient,
) async {
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
  
    final DatabaseMonitor monitor = getDatabaseMonitor();
    Database? db = await monitor.requestDatabaseAccess();
    if (db == null) {
      QuizzerLogger.logError('syncUserSettingsInbound: Failed to get database access.');
      return; // Cannot proceed without DB
    }

    for (final record in cloudRecords) {
      if (record is Map<String, dynamic>) {
        // Use the new function from user_settings_table.dart
        await upsertFromSupabase(record, db);
      } else {
        QuizzerLogger.logWarning('syncUserSettingsInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
      }
    }
    monitor.releaseDatabaseAccess(); // Ensure DB access is released after the loop
    QuizzerLogger.logMessage('Database Released');
  
    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_settings from cloud for user $userId.');
  } on PostgrestException catch (e, s) {
    QuizzerLogger.logError('syncUserSettingsInbound: PostgrestException (potentially non-retriable or after retries) for user $userId. Error: ${e.message}, Stack: $s');
  } on SocketException catch (e, s) {
    QuizzerLogger.logError('syncUserSettingsInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
  } catch (e, s) {
    QuizzerLogger.logError('syncUserSettingsInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
  }
}

/// Syncs modules from the cloud that are newer than the initial profile timestamp
Future<void> syncModulesInbound(
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
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

  final DatabaseMonitor monitor = getDatabaseMonitor();
  Database? db = await monitor.requestDatabaseAccess();
  if (db == null) {
    QuizzerLogger.logError('syncModulesInbound: Failed to get database access.');
    return;
  }

  for (final record in cloudRecords) {
    if (record is Map<String, dynamic>) {
      // Only sync the fields we store in Supabase
      await upsertModuleFromInboundSync(
        moduleName: record['module_name'],
        description: record['description'],
        db: db,
      );
    } else {
      QuizzerLogger.logWarning('syncModulesInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
    }
  }
  monitor.releaseDatabaseAccess();
  QuizzerLogger.logMessage('Database Released');

  QuizzerLogger.logSuccess('Synced ${cloudRecords.length} modules from cloud.');
}

Future<void> syncUserStatsEligibleQuestionsInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  QuizzerLogger.logMessage('Syncing inbound user_stats_eligible_questions for user $userId since $initialTimestamp...');

  final DatabaseMonitor monitor = getDatabaseMonitor();
  Database? db = await monitor.requestDatabaseAccess();
  if (db == null) {
    QuizzerLogger.logError('syncUserStatsEligibleQuestionsInbound: Failed to get database access.');
    return;
  }

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
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } on SocketException catch (e, s) {
    QuizzerLogger.logError('syncUserStatsEligibleQuestionsInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } catch (e, s) {
    QuizzerLogger.logError('syncUserStatsEligibleQuestionsInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  if (cloudRecords.isEmpty) {
    QuizzerLogger.logMessage('No new user_stats_eligible_questions to sync for user $userId.');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_eligible_questions to sync for user $userId.');

  for (final record in cloudRecords) {
    if (record is Map<String, dynamic>) {
      await upsertUserStatsEligibleQuestionsFromInboundSync(record, db);
    } else {
      QuizzerLogger.logWarning('syncUserStatsEligibleQuestionsInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
    }
  }

  QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_eligible_questions from cloud for user $userId.');
  monitor.releaseDatabaseAccess();
  QuizzerLogger.logMessage('Database Released');
}

Future<void> syncUserStatsNonCirculatingQuestionsInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  QuizzerLogger.logMessage('Syncing inbound user_stats_non_circulating_questions for user $userId since $initialTimestamp...');

  final DatabaseMonitor monitor = getDatabaseMonitor();
  Database? db = await monitor.requestDatabaseAccess();
  if (db == null) {
    QuizzerLogger.logError('syncUserStatsNonCirculatingQuestionsInbound: Failed to get database access.');
    return;
  }

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
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } on SocketException catch (e, s) {
    QuizzerLogger.logError('syncUserStatsNonCirculatingQuestionsInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } catch (e, s) {
    QuizzerLogger.logError('syncUserStatsNonCirculatingQuestionsInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  if (cloudRecords.isEmpty) {
    QuizzerLogger.logMessage('No new user_stats_non_circulating_questions to sync for user $userId.');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_non_circulating_questions to sync for user $userId.');

  for (final record in cloudRecords) {
    if (record is Map<String, dynamic>) {
      await upsertUserStatsNonCirculatingQuestionsFromInboundSync(record, db);
    } else {
      QuizzerLogger.logWarning('syncUserStatsNonCirculatingQuestionsInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
    }
  }

  QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_non_circulating_questions from cloud for user $userId.');
  monitor.releaseDatabaseAccess();
  QuizzerLogger.logMessage('Database Released');
}

Future<void> syncUserStatsInCirculationQuestionsInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  QuizzerLogger.logMessage('Syncing inbound user_stats_in_circulation_questions for user $userId since $initialTimestamp...');

  final DatabaseMonitor monitor = getDatabaseMonitor();
  Database? db = await monitor.requestDatabaseAccess();
  if (db == null) {
    QuizzerLogger.logError('syncUserStatsInCirculationQuestionsInbound: Failed to get database access.');
    return;
  }

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
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } on SocketException catch (e, s) {
    QuizzerLogger.logError('syncUserStatsInCirculationQuestionsInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } catch (e, s) {
    QuizzerLogger.logError('syncUserStatsInCirculationQuestionsInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  if (cloudRecords.isEmpty) {
    QuizzerLogger.logMessage('No new user_stats_in_circulation_questions to sync for user $userId.');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_in_circulation_questions to sync for user $userId.');

  for (final record in cloudRecords) {
    if (record is Map<String, dynamic>) {
      await upsertUserStatsInCirculationQuestionsFromInboundSync(record, db);
    } else {
      QuizzerLogger.logWarning('syncUserStatsInCirculationQuestionsInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
    }
  }

  QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_in_circulation_questions from cloud for user $userId.');
  monitor.releaseDatabaseAccess();
  QuizzerLogger.logMessage('Database Released');
}

Future<void> syncUserStatsRevisionStreakSumInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  QuizzerLogger.logMessage('Syncing inbound user_stats_revision_streak_sum for user $userId since $initialTimestamp...');

  final DatabaseMonitor monitor = getDatabaseMonitor();
  Database? db = await monitor.requestDatabaseAccess();
  if (db == null) {
    QuizzerLogger.logError('syncUserStatsRevisionStreakSumInbound: Failed to get database access.');
    return;
  }

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
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } on SocketException catch (e, s) {
    QuizzerLogger.logError('syncUserStatsRevisionStreakSumInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } catch (e, s) {
    QuizzerLogger.logError('syncUserStatsRevisionStreakSumInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  if (cloudRecords.isEmpty) {
    QuizzerLogger.logMessage('No new user_stats_revision_streak_sum to sync for user $userId.');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_revision_streak_sum to sync for user $userId.');

  for (final record in cloudRecords) {
    if (record is Map<String, dynamic>) {
      await upsertUserStatsRevisionStreakSumFromInboundSync(record, db);
    } else {
      QuizzerLogger.logWarning('syncUserStatsRevisionStreakSumInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
    }
  }

  QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_revision_streak_sum from cloud for user $userId.');
  monitor.releaseDatabaseAccess();
  QuizzerLogger.logMessage('Database Released');
}

Future<void> syncUserStatsTotalUserQuestionAnswerPairsInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  QuizzerLogger.logMessage('Syncing inbound user_stats_total_user_question_answer_pairs for user $userId since $initialTimestamp...');

  final DatabaseMonitor monitor = getDatabaseMonitor();
  Database? db = await monitor.requestDatabaseAccess();
  if (db == null) {
    QuizzerLogger.logError('syncUserStatsTotalUserQuestionAnswerPairsInbound: Failed to get database access.');
    return;
  }

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
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } on SocketException catch (e, s) {
    QuizzerLogger.logError('syncUserStatsTotalUserQuestionAnswerPairsInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } catch (e, s) {
    QuizzerLogger.logError('syncUserStatsTotalUserQuestionAnswerPairsInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  if (cloudRecords.isEmpty) {
    QuizzerLogger.logMessage('No new user_stats_total_user_question_answer_pairs to sync for user $userId.');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_stats_total_user_question_answer_pairs to sync for user $userId.');

  for (final record in cloudRecords) {
    if (record is Map<String, dynamic>) {
      await upsertUserStatsTotalUserQuestionAnswerPairsFromInboundSync(record, db);
    } else {
      QuizzerLogger.logWarning('syncUserStatsTotalUserQuestionAnswerPairsInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
    }
  }

  QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_total_user_question_answer_pairs from cloud for user $userId.');
  monitor.releaseDatabaseAccess();
  QuizzerLogger.logMessage('Database Released');
}

Future<void> syncUserStatsAverageQuestionsShownPerDayInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  QuizzerLogger.logMessage('Syncing inbound user_stats_average_questions_shown_per_day for user $userId since $initialTimestamp...');

  final DatabaseMonitor monitor = getDatabaseMonitor();
  Database? db = await monitor.requestDatabaseAccess();
  if (db == null) {
    QuizzerLogger.logError('syncUserStatsAverageQuestionsShownPerDayInbound: Failed to get database access.');
    return;
  }

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
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } on SocketException catch (e, s) {
    QuizzerLogger.logError('syncUserStatsAverageQuestionsShownPerDayInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } catch (e, s) {
    QuizzerLogger.logError('syncUserStatsAverageQuestionsShownPerDayInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  if (cloudRecords.isEmpty) {
    QuizzerLogger.logMessage('No new user_stats_average_questions_shown_per_day to sync for user $userId.');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  QuizzerLogger.logMessage('Found \u001b[38;5;10m${cloudRecords.length}[0m new/updated user_stats_average_questions_shown_per_day to sync for user $userId.');

  for (final record in cloudRecords) {
    if (record is Map<String, dynamic>) {
      await upsertUserStatsAverageQuestionsShownPerDayFromInboundSync(record, db);
    } else {
      QuizzerLogger.logWarning('syncUserStatsAverageQuestionsShownPerDayInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
    }
  }

  QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_average_questions_shown_per_day from cloud for user $userId.');
  monitor.releaseDatabaseAccess();
  QuizzerLogger.logMessage('Database Released');
}

Future<void> syncUserStatsTotalQuestionsAnsweredInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  QuizzerLogger.logMessage('Syncing inbound user_stats_total_questions_answered for user $userId since $initialTimestamp...');

  final DatabaseMonitor monitor = getDatabaseMonitor();
  Database? db = await monitor.requestDatabaseAccess();
  if (db == null) {
    QuizzerLogger.logError('syncUserStatsTotalQuestionsAnsweredInbound: Failed to get database access.');
    return;
  }

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
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } on SocketException catch (e, s) {
    QuizzerLogger.logError('syncUserStatsTotalQuestionsAnsweredInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } catch (e, s) {
    QuizzerLogger.logError('syncUserStatsTotalQuestionsAnsweredInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  if (cloudRecords.isEmpty) {
    QuizzerLogger.logMessage('No new user_stats_total_questions_answered to sync for user $userId.');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  QuizzerLogger.logMessage('Found \u001b[38;5;10m${cloudRecords.length}\u001b[0m new/updated user_stats_total_questions_answered to sync for user $userId.');

  for (final record in cloudRecords) {
    if (record is Map<String, dynamic>) {
      await upsertUserStatsTotalQuestionsAnsweredFromInboundSync(record, db);
    } else {
      QuizzerLogger.logWarning('syncUserStatsTotalQuestionsAnsweredInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
    }
  }

  QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_total_questions_answered from cloud for user $userId.');
  monitor.releaseDatabaseAccess();
  QuizzerLogger.logMessage('Database Released');
}

Future<void> syncUserStatsDailyQuestionsAnsweredInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  QuizzerLogger.logMessage('Syncing inbound user_stats_daily_questions_answered for user $userId since $initialTimestamp...');

  final DatabaseMonitor monitor = getDatabaseMonitor();
  Database? db = await monitor.requestDatabaseAccess();
  if (db == null) {
    QuizzerLogger.logError('syncUserStatsDailyQuestionsAnsweredInbound: Failed to get database access.');
    return;
  }

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
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } on SocketException catch (e, s) {
    QuizzerLogger.logError('syncUserStatsDailyQuestionsAnsweredInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } catch (e, s) {
    QuizzerLogger.logError('syncUserStatsDailyQuestionsAnsweredInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  if (cloudRecords.isEmpty) {
    QuizzerLogger.logMessage('No new user_stats_daily_questions_answered to sync for user $userId.');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  QuizzerLogger.logMessage('Found \u001b[38;5;10m${cloudRecords.length}[0m new/updated user_stats_daily_questions_answered to sync for user $userId.');

  for (final record in cloudRecords) {
    if (record is Map<String, dynamic>) {
      await upsertUserStatsDailyQuestionsAnsweredFromInboundSync(record, db);
    } else {
      QuizzerLogger.logWarning('syncUserStatsDailyQuestionsAnsweredInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
    }
  }

  QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_daily_questions_answered from cloud for user $userId.');
  monitor.releaseDatabaseAccess();
  QuizzerLogger.logMessage('Database Released');
}

Future<void> syncUserStatsDaysLeftUntilQuestionsExhaustInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  QuizzerLogger.logMessage('Syncing inbound user_stats_days_left_until_questions_exhaust for user $userId since $initialTimestamp...');

  final DatabaseMonitor monitor = getDatabaseMonitor();
  Database? db = await monitor.requestDatabaseAccess();
  if (db == null) {
    QuizzerLogger.logError('syncUserStatsDaysLeftUntilQuestionsExhaustInbound: Failed to get database access.');
    return;
  }

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
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } on SocketException catch (e, s) {
    QuizzerLogger.logError('syncUserStatsDaysLeftUntilQuestionsExhaustInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } catch (e, s) {
    QuizzerLogger.logError('syncUserStatsDaysLeftUntilQuestionsExhaustInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  if (cloudRecords.isEmpty) {
    QuizzerLogger.logMessage('No new user_stats_days_left_until_questions_exhaust to sync for user $userId.');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  QuizzerLogger.logMessage('Found [38;5;10m${cloudRecords.length}[0m new/updated user_stats_days_left_until_questions_exhaust to sync for user $userId.');

  for (final record in cloudRecords) {
    if (record is Map<String, dynamic>) {
      await upsertUserStatsDaysLeftUntilQuestionsExhaustFromInboundSync(record, db);
    } else {
      QuizzerLogger.logWarning('syncUserStatsDaysLeftUntilQuestionsExhaustInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
    }
  }

  QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_days_left_until_questions_exhaust from cloud for user $userId.');
  monitor.releaseDatabaseAccess();
  QuizzerLogger.logMessage('Database Released');
}

Future<void> syncUserStatsAverageDailyQuestionsLearnedInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  QuizzerLogger.logMessage('Syncing inbound user_stats_average_daily_questions_learned for user $userId since $initialTimestamp...');

  final DatabaseMonitor monitor = getDatabaseMonitor();
  Database? db = await monitor.requestDatabaseAccess();
  if (db == null) {
    QuizzerLogger.logError('syncUserStatsAverageDailyQuestionsLearnedInbound: Failed to get database access.');
    return;
  }

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
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } on SocketException catch (e, s) {
    QuizzerLogger.logError('syncUserStatsAverageDailyQuestionsLearnedInbound: SocketException (after retries) for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  } catch (e, s) {
    QuizzerLogger.logError('syncUserStatsAverageDailyQuestionsLearnedInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  if (cloudRecords.isEmpty) {
    QuizzerLogger.logMessage('No new user_stats_average_daily_questions_learned to sync for user $userId.');
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database Released');
    return;
  }

  QuizzerLogger.logMessage('Found \u001b[38;5;10m${cloudRecords.length}\u001b[0m new/updated user_stats_average_daily_questions_learned to sync for user $userId.');

  for (final record in cloudRecords) {
    if (record is Map<String, dynamic>) {
      await upsertUserStatsAverageDailyQuestionsLearnedFromInboundSync(record, db);
    } else {
      QuizzerLogger.logWarning('syncUserStatsAverageDailyQuestionsLearnedInbound: Encountered a record not of type Map<String, dynamic>. Record: $record');
    }
  }

  QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_stats_average_daily_questions_learned from cloud for user $userId.');
  monitor.releaseDatabaseAccess();
  QuizzerLogger.logMessage('Database Released');
}

Future<void> runInitialInboundSync(SessionManager sessionManager) async {
  QuizzerLogger.logMessage('Starting initial inbound sync aggregator...');
  final String? userId = sessionManager.userId;

  final DatabaseMonitor monitor = getDatabaseMonitor();
  Database? db = await monitor.requestDatabaseAccess();
  QuizzerLogger.logMessage('Database Access Granted');

  // Get last_login timestamp using the imported helper
  final String? lastLogin = await getLastLoginForUser(userId!, db!);
  monitor.releaseDatabaseAccess();
  QuizzerLogger.logMessage('Database Released');
  db = null;
  // If lastLogin is null, set it to 20 years ago to ensure we get all records
  final String effectiveLastLogin = lastLogin ?? DateTime.now().subtract(const Duration(days: 365 * 20)).toUtc().toIso8601String();
  QuizzerLogger.logMessage('Using effective last login timestamp: $effectiveLastLogin');

  // Sync question_answer_pairs
  await syncQuestionAnswerPairsInbound(userId, effectiveLastLogin, sessionManager.supabase);

  // Get initial profile timestamp, if null set to 20 years ago
  final String? initialTimestamp = sessionManager.initialProfileLastModified;
  final String effectiveInitialTimestamp = initialTimestamp ?? DateTime.now().subtract(const Duration(days: 365 * 20)).toUtc().toIso8601String();
  QuizzerLogger.logMessage('Using effective initial timestamp: $effectiveInitialTimestamp');

  // Sync user_question_answer_pairs using the initial profile last_modified_timestamp
  await syncUserQuestionAnswerPairsInbound(
    userId,
    effectiveInitialTimestamp,
    sessionManager.supabase,
  );

  // Sync user profile using the initial profile last_modified_timestamp
  await syncUserProfileInbound(
    userId,
    effectiveInitialTimestamp,
    sessionManager.supabase,
  );

  // Sync user settings using the initial profile last_modified_timestamp
  await syncUserSettingsInbound(
    userId,
    effectiveInitialTimestamp,
    sessionManager.supabase,
  );

  // Sync modules using the initial profile last_modified_timestamp
  await syncModulesInbound(
    effectiveInitialTimestamp,
    sessionManager.supabase,
  );

  // Sync user_stats_eligible_questions using the initial profile last_modified_timestamp
  await syncUserStatsEligibleQuestionsInbound(
    userId,
    effectiveInitialTimestamp,
    sessionManager.supabase,
  );

  // Sync user_stats_non_circulating_questions using the initial profile last_modified_timestamp
  await syncUserStatsNonCirculatingQuestionsInbound(
    userId,
    effectiveInitialTimestamp,
    sessionManager.supabase,
  );

  // Sync user_stats_in_circulation_questions using the initial profile last_modified_timestamp
  await syncUserStatsInCirculationQuestionsInbound(
    userId,
    effectiveInitialTimestamp,
    sessionManager.supabase,
  );

  // Sync user_stats_revision_streak_sum using the initial profile last_modified_timestamp
  await syncUserStatsRevisionStreakSumInbound(
    userId,
    effectiveInitialTimestamp,
    sessionManager.supabase,
  );

  // Sync user_stats_total_user_question_answer_pairs using the initial profile last_modified_timestamp
  await syncUserStatsTotalUserQuestionAnswerPairsInbound(
    userId,
    effectiveInitialTimestamp,
    sessionManager.supabase,
  );

  // Sync user_stats_average_questions_shown_per_day using the initial profile last_modified_timestamp
  await syncUserStatsAverageQuestionsShownPerDayInbound(
    userId,
    effectiveInitialTimestamp,
    sessionManager.supabase,
  );

  // Sync user_stats_total_questions_answered using the initial profile last_modified_timestamp
  await syncUserStatsTotalQuestionsAnsweredInbound(
    userId,
    effectiveInitialTimestamp,
    sessionManager.supabase,
  );

  // Sync user_stats_daily_questions_answered using the initial profile last_modified_timestamp
  await syncUserStatsDailyQuestionsAnsweredInbound(
    userId,
    effectiveInitialTimestamp,
    sessionManager.supabase,
  );

  // Sync user_stats_days_left_until_questions_exhaust using the initial profile last_modified_timestamp
  await syncUserStatsDaysLeftUntilQuestionsExhaustInbound(
    userId,
    effectiveInitialTimestamp,
    sessionManager.supabase
  );

  // Sync user_stats_average_daily_questions_learned using the initial profile last_modified_timestamp
  await syncUserStatsAverageDailyQuestionsLearnedInbound(
    userId,
    effectiveInitialTimestamp,
    sessionManager.supabase
  );

  QuizzerLogger.logSuccess('Initial inbound sync completed successfully.');
}


