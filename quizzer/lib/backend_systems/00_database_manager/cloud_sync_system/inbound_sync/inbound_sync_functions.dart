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
import 'dart:io'; // For SocketException

/// Syncs question_answer_pairs from the cloud that are newer than last_login
Future<void> syncQuestionAnswerPairsInbound(
  String userId,
  String lastLogin,
  SupabaseClient supabaseClient,
) async {
  QuizzerLogger.logMessage('Syncing inbound question_answer_pairs for user $userId since $lastLogin...');
  try {
    final List<dynamic> cloudRecords = await supabaseClient
        .from('question_answer_pairs')
        .select('*')
        .gt('last_modified_timestamp', lastLogin);

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new question_answer_pairs to sync.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated question_answer_pairs to sync.');
    final DatabaseMonitor monitor = getDatabaseMonitor();
    Database? db = await monitor.requestDatabaseAccess();
    for (final record in cloudRecords) {
      // Insert or update each record
      await insertOrUpdateQuestionAnswerPair(record, db!);
    }
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} question_answer_pairs from cloud.');
  } on PostgrestException catch (e, s) {
    QuizzerLogger.logError('syncQuestionAnswerPairsInbound: PostgrestException for user $userId. Error: ${e.message}, Stack: $s');
  } on SocketException catch (e, s) {
    QuizzerLogger.logError('syncQuestionAnswerPairsInbound: SocketException for user $userId. Error: $e, Stack: $s');
  } catch (e, s) {
    QuizzerLogger.logError('syncQuestionAnswerPairsInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
  }
}

/// Syncs user_question_answer_pairs from the cloud that are newer than the initial profile timestamp
Future<void> syncUserQuestionAnswerPairsInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
  QuizzerLogger.logMessage('Syncing inbound user_question_answer_pairs for user $userId since $initialTimestamp...');
  
  // If no initial timestamp, fetch all records for this user
  try {
    final List<dynamic> cloudRecords = await supabaseClient
        .from('user_question_answer_pairs')
        .select('*')
        .eq('user_uuid', userId)
        .gt('last_modified_timestamp', initialTimestamp ?? '');

    if (cloudRecords.isEmpty) {
      QuizzerLogger.logMessage('No new user_question_answer_pairs to sync.');
      return;
    }

    QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated user_question_answer_pairs to sync.');
    final DatabaseMonitor monitor = getDatabaseMonitor();
    Database? db = await monitor.requestDatabaseAccess();
    for (final record in cloudRecords) {
      // Insert or update each record, explicitly converting numeric values to doubles
      await insertOrUpdateUserQuestionAnswerPair(
        userUuid: userId,
        questionId: record['question_id'],
        revisionStreak: record['revision_streak'],
        lastRevised: record['last_revised'],
        predictedRevisionDueHistory: record['predicted_revision_due_history'],
        nextRevisionDue: record['next_revision_due'],
        timeBetweenRevisions: (record['time_between_revisions'] as num).toDouble(),
        averageTimesShownPerDay: (record['average_times_shown_per_day'] as num).toDouble(),
        db: db!,
      );
    }
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_question_answer_pairs from cloud.');
  } on PostgrestException catch (e, s) {
    QuizzerLogger.logError('syncUserQuestionAnswerPairsInbound: PostgrestException for user $userId. Error: ${e.message}, Stack: $s');
  } on SocketException catch (e, s) {
    QuizzerLogger.logError('syncUserQuestionAnswerPairsInbound: SocketException for user $userId. Error: $e, Stack: $s');
  } catch (e, s) {
    QuizzerLogger.logError('syncUserQuestionAnswerPairsInbound: Unexpected error for user $userId. Error: $e, Stack: $s');
  }
}

/// Syncs user profile from the cloud that is newer than the initial profile timestamp
Future<void> syncUserProfileInbound(
  String userId,
  String? initialTimestamp,
  SupabaseClient supabaseClient,
) async {
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

    final DatabaseMonitor monitor = getDatabaseMonitor();
    Database? db = await monitor.requestDatabaseAccess();
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

  // Fetch records from 'user_settings' table in Supabase
  // - belonging to the current userId
  // - newer than the initialTimestamp (user_profile's last_modified_timestamp at login)
  try {
    final List<dynamic> cloudRecords = await supabaseClient
        .from('user_settings') // Target table
        .select('*') // Select all columns
        .eq('user_id', userId) // Filter by user_id
        .gt('last_modified_timestamp', initialTimestamp ?? DateTime(1970).toIso8601String()); // Filter by timestamp

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
  
    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} user_settings from cloud for user $userId.');
  } on PostgrestException catch (e, s) {
    QuizzerLogger.logError('syncUserSettingsInbound: PostgrestException for user $userId. Error: ${e.message}, Stack: $s');
  } on SocketException catch (e, s) {
    QuizzerLogger.logError('syncUserSettingsInbound: SocketException for user $userId. Error: $e, Stack: $s');
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
  
  // Fetch records from 'modules' table in Supabase
  // - newer than the initialTimestamp
  try {
    final List<dynamic> cloudRecords = await supabaseClient
        .from('modules')
        .select('*')
        .gt('last_modified_timestamp', initialTimestamp ?? DateTime(1970).toIso8601String());

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
  
    QuizzerLogger.logSuccess('Synced ${cloudRecords.length} modules from cloud.');
  } on PostgrestException catch (e, s) {
    QuizzerLogger.logError('syncModulesInbound: PostgrestException. Error: ${e.message}, Stack: $s');
  } on SocketException catch (e, s) {
    QuizzerLogger.logError('syncModulesInbound: SocketException. Error: $e, Stack: $s');
  } catch (e, s) {
    QuizzerLogger.logError('syncModulesInbound: Unexpected error. Error: $e, Stack: $s');
  }
}

Future<void> runInitialInboundSync(SessionManager sessionManager) async {
  QuizzerLogger.logMessage('Starting initial inbound sync aggregator...');
  final String? userId = sessionManager.userId;

  final DatabaseMonitor monitor = getDatabaseMonitor();
  Database? db = await monitor.requestDatabaseAccess();

  // Get last_login timestamp using the imported helper
  final String? lastLogin = await getLastLoginForUser(userId!, db!);
  monitor.releaseDatabaseAccess();
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

  QuizzerLogger.logSuccess('Initial inbound sync completed successfully.');
}


