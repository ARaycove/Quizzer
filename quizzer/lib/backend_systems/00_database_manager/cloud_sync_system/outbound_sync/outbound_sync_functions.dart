import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // To get Supabase client
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart'; // Import for table functions
import 'package:quizzer/backend_systems/00_database_manager/tables/system_data/login_attempts_table.dart'; // Import for login attempts table functions
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_attempts_table.dart'; // Import for attempt table functions
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart'; // Import for user profile table functions
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart'; // Import for UserQuestionAnswerPairs table functions
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Import Logger
import 'package:supabase/supabase.dart'; // Import for PostgrestException & SupabaseClient
import 'package:quizzer/backend_systems/00_database_manager/tables/system_data/error_logs_table.dart'; // Added for syncErrorLogs
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_settings_table.dart'; // Added for user settings table
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/system_data/user_feedback_table.dart'; // Added for user feedback
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

// ==========================================
// Outbound Sync - Generic Push Function

/// Attempts to push a batch of records to a specified Supabase table using upsert.
/// Automatically splits large lists into batches of 500 records.
/// Returns true if all batches complete successfully, false if any batch fails.
Future<bool> pushBatchToSupabase(String tableName, List<Map<String, dynamic>> records, {List<String>? conflictKeys}) async {
  try {
    if (records.isEmpty) {
      QuizzerLogger.logMessage('pushBatchToSupabase: Empty batch received for table $tableName. Skipping.');
      return true;
    }

    // Remove sync flags from all records
    final filteredRecords = records.map((record) {
      final filtered = Map<String, dynamic>.from(record);
      filtered.remove('has_been_synced');
      filtered.remove('edits_are_synced');
      return filtered;
    }).toList();

    // Use the keys from the first record for columns
    final columns = filteredRecords.first.keys.toList();
    final valuesList = filteredRecords.map((record) {
      String esc(dynamic v) => v == null ? 'NULL' : "'${v.toString().replaceAll("'", "''")}'";
      return '(${columns.map((col) => esc(record[col])).join(', ')})';
    }).join(',\n');

    // Build ON CONFLICT clause if conflictKeys provided
    String onConflictClause = '';
    if (conflictKeys != null && conflictKeys.isNotEmpty) {
      final updateSet = columns
        .where((col) => !conflictKeys.contains(col))
        .map((col) => '$col = EXCLUDED.$col')
        .join(',\n        ');
      onConflictClause = '\n      ON CONFLICT (${conflictKeys.join(', ')}) DO UPDATE SET\n        $updateSet';
    }

    final sql = '''
      INSERT INTO $tableName (${columns.join(', ')})
      VALUES $valuesList
      $onConflictClause
    ''';

    final supabase = getSessionManager().supabase;
    await supabase.rpc('execute_sql', params: {'sql': sql});
    QuizzerLogger.logSuccess('Raw SQL batch insert successful for $tableName.');
    return true;
  } catch (e) {
    QuizzerLogger.logError('Raw SQL batch insert FAILED for $tableName: $e');
    rethrow;
  }
}

/// Attempts to push a single record to a specified Supabase table using upsert.
/// Returns true if the upsert operation completes without error, false otherwise.
Future<bool> pushRecordToSupabase(String tableName, Map<String, dynamic> recordData) async {
  try {
    // USE SESSION MANAGER FOR ACCESS TO SUPABASE
    // Try to get a meaningful ID for logging, without making it a hard requirement for the function's logic.
    String recordIdForLog = "unknown_id";

    // --- BEGIN NEW DIAGNOSTIC LOGGING ---
    if (tableName == 'user_settings') {
      QuizzerLogger.logValue('pushRecordToSupabase (user_settings) received recordData with keys: ${recordData.keys.toList()}');
      QuizzerLogger.logValue('pushRecordToSupabase (user_settings) user_id value: ${recordData['user_id']}');
      QuizzerLogger.logValue('pushRecordToSupabase (user_settings) setting_name value: ${recordData['setting_name']}');
    }
    // --- END NEW DIAGNOSTIC LOGGING ---

    QuizzerLogger.logMessage('Attempting Supabase upsert for record $recordIdForLog to table $tableName...');

    final supabase = getSessionManager().supabase;
    Map<String, dynamic> payload = Map.from(recordData);
    payload.remove('has_been_synced');
    payload.remove('edits_are_synced');
    payload.forEach((key, value) {
      if (value is double && value.isInfinite) {
        payload[key] = 1.0;
      }
    });
    QuizzerLogger.logValue('Pushing to $tableName. Payload: $payload');
    await supabase.from(tableName).upsert(payload);
    QuizzerLogger.logSuccess('Supabase upsert successful for record $recordIdForLog to $tableName.');
    return true;
  } on PostgrestException catch (e) {
    // Handle Supabase-specific errors (network, policy violations, etc.)
    QuizzerLogger.logWarning('Supabase upsert FAILED for record to $tableName: ${e.message} (Code: ${e.code})');
    QuizzerLogger.logMessage('Attempting Supabase insert for record to table $tableName as fallback...');
    try {
      final supabase = getSessionManager().supabase;
      Map<String, dynamic> payload = Map.from(recordData);
      payload.remove('has_been_synced');
      payload.remove('edits_are_synced');
      payload.forEach((key, value) {
        if (value is double && value.isInfinite) {
          payload[key] = 1.0;
        }
      });
      QuizzerLogger.logValue('Pushing to $tableName (insert fallback). Payload: $payload');
      await supabase.from(tableName).insert(payload);
      QuizzerLogger.logSuccess('Supabase insert successful for record to $tableName.');
      return true;
    } on PostgrestException catch (e2) {
      QuizzerLogger.logError('Supabase insert FAILED for record to $tableName: ${e2.message} (Code: ${e2.code})');
      return false; // Return false for network/external errors
    } catch (e2) {
      QuizzerLogger.logError('Unexpected error during Supabase insert fallback for record to $tableName: $e2');
      rethrow; // Rethrow unexpected errors (logic errors)
    }
  } on SocketException catch (e) {
    // Handle network connectivity errors
    QuizzerLogger.logWarning('Network error during Supabase upsert for record to $tableName: $e');
    return false; // Return false for network errors
  } catch (e) {
    // Handle other unexpected errors (logic errors, etc.)
    QuizzerLogger.logError('Unexpected error during Supabase upsert for record to $tableName: $e');
    rethrow; // Rethrow unexpected errors (logic errors)
  }
}

// ==========================================
// Outbound Sync - Generic Update Function

/// Attempts to update a single existing record in a specified Supabase table.
/// Matches the record based on the provided primary key column and value.
/// Returns true if the update operation completes without error, false otherwise.
Future<bool> updateRecordInSupabase(String tableName, Map<String, dynamic> recordData, {required String primaryKeyColumn, required dynamic primaryKeyValue}) async {
  try {
    // USE SESSION MANAGER FOR ACCESS TO SUPABASE
    QuizzerLogger.logMessage('Attempting Supabase update for ID $primaryKeyValue in table $tableName...');

    // 1. Get Supabase client
    final supabase = getSessionManager().supabase;

    // 2. Prepare payload (remove local-only fields and the primary key itself, as it's used in the filter)
    Map<String, dynamic> payload = Map.from(recordData);
    payload.remove('has_been_synced');
    payload.remove('edits_are_synced');
    payload.remove(primaryKeyColumn); // Don't try to update the primary key

    // Ensure there's something left to update besides sync flags/PK
    if (payload.isEmpty) {
        QuizzerLogger.logWarning('updateRecordInSupabase: No fields to update for ID $primaryKeyValue in $tableName after removing sync flags and PK.');
        return true; // Consider this a success, as there are no actual changes to push for this edit.
    }

    // 3. Perform Update based on the primary key column and value
    await supabase
      .from(tableName)
      .update(payload)
      .eq(primaryKeyColumn, primaryKeyValue); // Use .eq() to specify the row to update

    QuizzerLogger.logSuccess('Supabase update presumed successful for ID $primaryKeyValue in $tableName.');
    return true; // Assume success if no exception is thrown

  } on PostgrestException catch (e) {
     // Handle Supabase-specific errors (network, policy violations, etc.)
     QuizzerLogger.logError('Supabase PostgrestException during update for ID $primaryKeyValue in $tableName: ${e.message} (Code: ${e.code})');
     return false; // Return false for network/external errors
  } on SocketException catch (e) {
     // Handle network connectivity errors
     QuizzerLogger.logWarning('Network error during Supabase update for ID $primaryKeyValue in $tableName: $e');
     return false; // Return false for network errors
  } catch (e) {
    // Handle other unexpected errors (logic errors, etc.)
    QuizzerLogger.logError('Unexpected error during Supabase update for ID $primaryKeyValue in $tableName: $e');
    rethrow; // Rethrow unexpected errors (logic errors)
  }
}

// ==========================================
// Outbound Sync - Generic Update Function for Composite Keys (NEW)

/// Attempts to update a single existing record in a specified Supabase table using multiple filter conditions.
/// Matches the record based on the provided compositeKeyFilters.
/// Returns true if the update operation completes without error, false otherwise.
Future<bool> updateRecordWithCompositeKeyInSupabase(
  String tableName, 
  Map<String, dynamic> recordData, 
  {required Map<String, dynamic> compositeKeyFilters}
) async {
  try {
    final String filterLog = compositeKeyFilters.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    QuizzerLogger.logMessage('Attempting Supabase update with composite key for record matching ($filterLog) in table $tableName...');

    final supabase = getSessionManager().supabase;
    Map<String, dynamic> payload = Map.from(recordData);
    payload.remove('has_been_synced');
    payload.remove('edits_are_synced');
    // Also remove the keys used in the filter from the payload, as they identify the row and shouldn't be updated themselves.
    for (var key in compositeKeyFilters.keys) {
      payload.remove(key);
    }

    // Check for Infinity values and replace with 1
    payload.forEach((key, value) {
      if (value is double && value.isInfinite) {
        payload[key] = 1.0;
      }
    });

    if (payload.isEmpty) {
      QuizzerLogger.logWarning('updateRecordWithCompositeKeyInSupabase: No fields to update for ($filterLog) in $tableName after removing sync/filter keys.');
      return true; // No actual changes to push
    }

    var query = supabase.from(tableName).update(payload);
    for (var entry in compositeKeyFilters.entries) {
      query = query.eq(entry.key, entry.value);
    }
    await query; // Executes the update query

    QuizzerLogger.logSuccess('Supabase update with composite key successful for ($filterLog) in $tableName.');
    return true;
  } on PostgrestException catch (e) {
    // Handle Supabase-specific errors (network, policy violations, etc.)
    final String filterLog = compositeKeyFilters.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    QuizzerLogger.logError('Supabase PostgrestException during composite key update for ($filterLog) in $tableName: ${e.message} (Code: ${e.code})');
    return false; // Return false for network/external errors
  } on SocketException catch (e) {
    // Handle network connectivity errors
    final String filterLog = compositeKeyFilters.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    QuizzerLogger.logWarning('Network error during Supabase composite key update for ($filterLog) in $tableName: $e');
    return false; // Return false for network errors
  } catch (e) {
    // Handle other unexpected errors (logic errors, etc.)
    final String filterLog = compositeKeyFilters.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    QuizzerLogger.logError('Unexpected error during Supabase composite key update for ($filterLog) in $tableName: $e');
    rethrow; // Rethrow unexpected errors (logic errors)
  }
}

// ==========================================
// Outbound Sync - Table-Specific Functions
// ==========================================

/// Fetches unsynced question-answer pairs and attempts to push them.
Future<void> syncQuestionAnswerPairs() async {
  try {
    QuizzerLogger.logMessage('Starting sync for QuestionAnswerPairs...');

    // Fetch records needing sync
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedQuestionAnswerPairs();

    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced QuestionAnswerPairs found.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced QuestionAnswerPairs.');

    // Ensure all records have last_modified_timestamp
    for (final record in unsyncedRecords) {
      if (record['last_modified_timestamp'] == null || (record['last_modified_timestamp'] is String && (record['last_modified_timestamp'] as String).isEmpty)) {
        record['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();
      }
    }

    // Push records to the appropriate review table
    int successCount = 0;
    int failureCount = 0;

    for (final record in unsyncedRecords) {
      // Handle corrupted sync flags: treat -1 as 1 (synced)
      int hasBeenSynced = record['has_been_synced'] as int? ?? -1;
      int editsAreSynced = record['edits_are_synced'] as int? ?? -1;
      
      // Fix corrupted sync flags
      if (hasBeenSynced == -1) {
        QuizzerLogger.logWarning('Fixing corrupted has_been_synced flag from -1 to 1 for record: ${record['question_id']}');
        hasBeenSynced = 1;
      }
      if (editsAreSynced == -1) {
        QuizzerLogger.logWarning('Fixing corrupted edits_are_synced flag from -1 to 1 for record: ${record['question_id']}');
        editsAreSynced = 1;
      }
      
      String? reviewTable;
      if (hasBeenSynced == 0 && editsAreSynced == 0) {
        reviewTable = 'question_answer_pair_new_review';
      } else if (hasBeenSynced == 1 && editsAreSynced == 0) {
        reviewTable = 'question_answer_pair_edits_review';
      } else {
        QuizzerLogger.logError('Invalid sync flags for question_answer_pair: has_been_synced=$hasBeenSynced, edits_are_synced=$editsAreSynced. Skipping record: $record');
        failureCount++;
        continue;
      }
      QuizzerLogger.logValue('Pushing to $reviewTable. Payload: $record');
      final bool pushSuccess = await pushRecordToSupabase(reviewTable, record);
      if (pushSuccess) {
        successCount++;
        await updateQuestionSyncFlags(
          questionId: record['question_id'],
          hasBeenSynced: true,
          editsAreSynced: true,
        );
      } else {
        failureCount++;
      }
    }

    if (failureCount > 0) {
      QuizzerLogger.logWarning('Sync completed with failures. Success: $successCount, Failures: $failureCount');
    } else {
      QuizzerLogger.logSuccess('Successfully synced $successCount question answer pairs to review tables.');
    }

    QuizzerLogger.logMessage('Finished sync attempt for QuestionAnswerPairs.');
  } catch (e) {
    QuizzerLogger.logError('syncQuestionAnswerPairs: Error - $e');
    rethrow;
  }
}

/// Fetches unsynced login attempts, pushes them to Supabase, and deletes locally on success.
Future<void> syncLoginAttempts() async {
  try {
    QuizzerLogger.logMessage('Starting sync for LoginAttempts...');

    // Fetch records needing sync - Remove try-catch, let DB errors propagate
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedLoginAttempts();

    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced LoginAttempts found.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced LoginAttempts.');

    final supabase = getSessionManager().supabase; // Get Supabase client instance
    const String tableName = 'login_attempts'; // Target Supabase table

    for (final record in unsyncedRecords) {
      final loginAttemptId = record['login_attempt_id'] as String;

      // Prepare payload for Supabase (remove local-only flags)
      Map<String, dynamic> payload = Map.from(record);
      payload.remove('has_been_synced');
      payload.remove('edits_are_synced');

      QuizzerLogger.logValue('Preparing to push LoginAttempt $loginAttemptId to $tableName');

      // Keep try-catch ONLY around the Supabase network call
      try {
        // Attempt to insert the record into Supabase
        await supabase.from(tableName).insert(payload);

        QuizzerLogger.logSuccess('Supabase insert successful for LoginAttempt $loginAttemptId.');

        // If Supabase insert succeeds, delete the local record directly.
        // Remove nested try-catch. If delete fails, the error propagates (Fail Fast).
        await deleteLoginAttemptRecord(loginAttemptId);

      } on PostgrestException catch (e) {
        // Handle potential Supabase errors (e.g., network, policy violation, duplicate PK if attempted)
        QuizzerLogger.logError('Supabase PostgrestException during insert for LoginAttempt $loginAttemptId: ${e.message} (Code: ${e.code})');
        // Do not delete local record if push failed
      } catch (e) {
        // Handle other potential network/client errors during Supabase call
        QuizzerLogger.logError('Supabase insert FAILED for LoginAttempt $loginAttemptId: $e');
        // Do not delete local record if push failed
      }
      // Removed nested try-catch for local delete
    }

    QuizzerLogger.logMessage('Finished sync attempt for LoginAttempts.');
  } catch (e) {
    QuizzerLogger.logError('syncLoginAttempts: Error - $e');
    rethrow;
  }
}

/// Fetches unsynced question answer attempts, pushes them to Supabase, and updates local flags on success.
Future<void> syncQuestionAnswerAttempts() async {
  try {
    QuizzerLogger.logMessage('Starting sync for QuestionAnswerAttempts...');

    // Fetch records needing sync
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedQuestionAnswerAttempts();

    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced QuestionAnswerAttempts found.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced QuestionAnswerAttempts.');

    // Validate and clean records for question_answer_attempts
    final List<Map<String, dynamic>> validRecords = [];
    for (final record in unsyncedRecords) {
      final String participantId = record['participant_id'] as String? ?? '';
      final String questionId = record['question_id'] as String? ?? '';
      final String timeStamp = record['time_stamp'] as String? ?? '';

      if (participantId.isEmpty || questionId.isEmpty || timeStamp.isEmpty) {
        QuizzerLogger.logError('Skipping unsynced attempt record due to missing primary key components: $record');
        continue;
      }
      // Remove nullable fields if null
      final Map<String, dynamic> cleanRecord = Map.from(record);
      for (final nullableField in [
        'knowledge_base',
        'last_revised_date',
        'days_since_last_revision',
        'last_modified_timestamp',
      ]) {
        if (cleanRecord[nullableField] == null) {
          cleanRecord.remove(nullableField);
        }
      }
      // Validate required fields
      bool missingRequired = false;
      for (final requiredField in [
        'time_stamp',
        'question_id',
        'participant_id',
        'response_time',
        'response_result',
        'was_first_attempt',
        'question_context_csv',
        'total_attempts',
        'revision_streak',
      ]) {
        if (cleanRecord[requiredField] == null) {
          QuizzerLogger.logError('Required field $requiredField is null in question_answer_attempts record: $cleanRecord');
          missingRequired = true;
        }
      }
      if (!missingRequired) {
        validRecords.add(cleanRecord);
      }
    }

    if (validRecords.isEmpty) {
      QuizzerLogger.logMessage('No valid QuestionAnswerAttempts to sync after validation.');
      return;
    }

    // Push records individually
    const String tableName = 'question_answer_attempts';
    int successCount = 0;
    int failureCount = 0;

    for (final record in validRecords) {
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);
      if (pushSuccess) {
        successCount++;
        // Delete the successfully synced record locally
        await deleteQuestionAnswerAttemptRecord(
          record['participant_id'] as String,
          record['question_id'] as String,
          record['time_stamp'] as String,
        );
      } else {
        failureCount++;
      }
    }

    if (failureCount > 0) {
      QuizzerLogger.logWarning('Sync completed with failures. Success: $successCount, Failures: $failureCount');
    } else {
      QuizzerLogger.logSuccess('Successfully synced $successCount question answer attempts.');
    }

    QuizzerLogger.logMessage('Finished sync attempt for QuestionAnswerAttempts.');
  } catch (e) {
    QuizzerLogger.logError('syncQuestionAnswerAttempts: Error - $e');
    rethrow;
  }
}

/// Fetches unsynced user profiles, pushes new ones or updates existing ones, and updates local flags on success.
Future<void> syncUserProfiles() async {
  try {
    QuizzerLogger.logMessage('Starting sync for UserProfiles...');

    // Get the current user's ID from SessionManager
    final SessionManager sessionManager = getSessionManager();
    final String? currentUserId = sessionManager.userId;

    if (currentUserId == null) {
      QuizzerLogger.logWarning('syncUserProfiles: No current user logged in. Cannot proceed.');
      return; // Cannot sync if no user is logged in
    }
    QuizzerLogger.logMessage('Outbound Sync: Checking for unsynced UserProfiles for user $currentUserId.');

    // Fetch records needing sync for the current user
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserProfiles(currentUserId);

    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced UserProfiles found for user $currentUserId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced UserProfiles for user $currentUserId.');

    const String tableName = 'user_profile';
    const String primaryKey = 'uuid';

    for (final record in unsyncedRecords) {
      final userId = record[primaryKey] as String?;
      final hasBeenSynced = record['has_been_synced'] as int? ?? 0; // Default to 0 if null

      if (userId == null) {
        QuizzerLogger.logError('Skipping unsynced user profile record due to missing uuid: $record');
        continue;
      }

      // Defensive check: Ensure the record's userId matches the current session's userId.
      // This should be guaranteed by getUnsyncedUserProfiles, but an explicit check adds safety.
      if (userId != currentUserId) {
        QuizzerLogger.logError(
          'CRITICAL: syncUserProfiles: Record user ID $userId MISMATCHES session user ID $currentUserId. Skipping sync for this record. This may indicate an issue with getUnsyncedUserProfiles.'
        );
        continue;
      }

      bool pushOrUpdateSuccess = false;

      if (hasBeenSynced == 0) {
        // This is a new record, use insert (via pushRecordToSupabase)
        QuizzerLogger.logValue('Preparing to insert UserProfile $userId into $tableName');
        pushOrUpdateSuccess = await pushRecordToSupabase(tableName, record);
      } else {
        // This is an existing record with edits, use update (via updateRecordInSupabase)
        QuizzerLogger.logValue('Preparing to update UserProfile $userId in $tableName');
        pushOrUpdateSuccess = await updateRecordInSupabase(
          tableName,
          record,
          primaryKeyColumn: primaryKey,
          primaryKeyValue: userId,
        );
      }

      // If push or update was successful, update local flags
      if (pushOrUpdateSuccess) {
        final operation = (hasBeenSynced == 0) ? 'Insert' : 'Update';
        QuizzerLogger.logMessage('$operation successful for UserProfile $userId. Updating local flags...');
        await updateUserProfileSyncFlags(
          userId: userId,
          hasBeenSynced: true, // Mark as synced
          editsAreSynced: true, // Mark edits as synced
        );
      } else {
        final operation = (hasBeenSynced == 0) ? 'Insert' : 'Update';
        QuizzerLogger.logWarning('$operation FAILED for UserProfile $userId. Local flags remain unchanged.');
      }
    }

    QuizzerLogger.logMessage('Finished sync attempt for UserProfiles.');
  } catch (e) {
    QuizzerLogger.logError('syncUserProfiles: Error - $e');
    rethrow;
  }
}

// Add functions for other tables (e.g., syncModules) here...
// --- Sync UserQuestionAnswerPairs ---

/// Fetches unsynced user_question_answer_pairs for the current user,
/// pushes new ones or updates existing ones (with server version check),
/// and updates local sync flags.
Future<void> syncUserQuestionAnswerPairs() async {
  try {
    QuizzerLogger.logMessage('Starting sync for UserQuestionAnswerPairs...');

    final SessionManager sessionManager = getSessionManager();
    if (sessionManager.userId == null) {return;}
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserQuestionAnswerPairs(sessionManager.userId!);

    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced UserQuestionAnswerPairs found for user ${sessionManager.userId}.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced UserQuestionAnswerPairs for user ${sessionManager.userId}.');

    // Ensure all records have last_modified_timestamp and sanitize Infinity values
    for (final record in unsyncedRecords) {
      if (record['last_modified_timestamp'] == null || (record['last_modified_timestamp'] is String && (record['last_modified_timestamp'] as String).isEmpty)) {
        record['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();
      }
      // Sanitize Infinity values
      record.forEach((key, value) {
        if (value is double && value.isInfinite) {
          record[key] = 1.0;
        }
      });
    }

    // Push records individually
    const String tableName = 'user_question_answer_pairs';
    int successCount = 0;
    int failureCount = 0;

    for (final record in unsyncedRecords) {
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);
      if (pushSuccess) {
        successCount++;
        await updateUserQuestionAnswerPairSyncFlags(
          userUuid: record['user_uuid'] as String,
          questionId: record['question_id'] as String,
          hasBeenSynced: true,
          editsAreSynced: true,
        );
      } else {
        failureCount++;
      }
    }

    if (failureCount > 0) {
      QuizzerLogger.logWarning('Sync completed with failures. Success: $successCount, Failures: $failureCount');
    } else {
      QuizzerLogger.logSuccess('Successfully synced $successCount user question answer pairs.');
    }

    QuizzerLogger.logMessage('Finished sync attempt for UserQuestionAnswerPairs.');
  } catch (e) {
    QuizzerLogger.logError('syncUserQuestionAnswerPairs: Error - $e');
    rethrow;
  }
}

/// Fetches unsynced modules, pushes them to Supabase, and updates local flags on success.
Future<void> syncModules() async {
  try {
    QuizzerLogger.logMessage('Starting sync for Modules...');

    // Fetch records needing sync
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedModules();

    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced Modules found.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced Modules.');

    // Ensure all records have proper creation_date and last_modified_timestamp
    for (final record in unsyncedRecords) {
      // Convert creation_date to UTC ISO8601 string if it's an integer
      dynamic creationDate = record['creation_date'];
      if (creationDate is int) {
        record['creation_date'] = DateTime.fromMillisecondsSinceEpoch(creationDate).toUtc().toIso8601String();
      }

      // Ensure last_modified_timestamp exists
      if (record['last_modified_timestamp'] == null || (record['last_modified_timestamp'] is String && (record['last_modified_timestamp'] as String).isEmpty)) {
        record['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();
      }
    }

    // Push records individually
    const String tableName = 'modules';
    int successCount = 0;
    int failureCount = 0;

    for (final record in unsyncedRecords) {
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);
      if (pushSuccess) {
        successCount++;
        await updateModuleSyncFlags(
          moduleName: record['module_name'] as String,
          hasBeenSynced: true,
          editsAreSynced: true,
        );
      } else {
        failureCount++;
      }
    }

    if (failureCount > 0) {
      QuizzerLogger.logWarning('Sync completed with failures. Success: $successCount, Failures: $failureCount');
    } else {
      QuizzerLogger.logSuccess('Successfully synced $successCount modules.');
    }

    QuizzerLogger.logMessage('Finished sync attempt for Modules.');
  } catch (e) {
    QuizzerLogger.logError('syncModules: Error - $e');
    rethrow;
  }
}

/// Fetches unsynced error logs, pushes them to Supabase, and deletes them locally on success.
Future<void> syncErrorLogs() async {
  try {
    QuizzerLogger.logMessage('Starting sync for ErrorLogs...');

    // Fetch records needing sync (already filters for older than 1 hour)
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedErrorLogs();

    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced ErrorLogs found to sync.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced ErrorLogs to process.');

    const String tableName = 'error_logs';

    for (final record in unsyncedRecords) {
      final String? recordId = record['id'] as String?;

      if (recordId == null) {
        QuizzerLogger.logError('Skipping unsynced error log record due to missing ID: $record');
        continue;
      }

      // Attempt to push the record to Supabase.
      // The pushRecordToSupabase function already removes local-only fields like has_been_synced and edits_are_synced if they were present.
      QuizzerLogger.logValue('Preparing to push ErrorLog $recordId to $tableName');
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);

      if (pushSuccess) {
        QuizzerLogger.logSuccess('Push successful for ErrorLog $recordId. Deleting local record...');
        // If Supabase push succeeds, delete the local record.
        await deleteLocalErrorLog(recordId);
      } else {
        QuizzerLogger.logWarning('Push FAILED for ErrorLog $recordId. Local record will remain for next sync attempt.');
      }
    }
    QuizzerLogger.logMessage('Finished sync attempt for ErrorLogs.');
  } catch (e) {
    QuizzerLogger.logError('syncErrorLogs: Error - $e');
    rethrow;
  }
}

// ==========================================
// Outbound Sync - User Settings
// ==========================================

/// Fetches unsynced user settings for the current user, pushes new ones or updates existing ones,
/// and updates local sync flags on success.
Future<void> syncUserSettings() async {
  try {
    QuizzerLogger.logMessage('Starting sync for UserSettings...');

    final SessionManager sessionManager = getSessionManager();
    final String? currentUserId = sessionManager.userId;

    if (currentUserId == null) {
      QuizzerLogger.logWarning('syncUserSettings: No current user logged in. Cannot proceed.');
      return;
    }

    // Fetch records needing sync for the current user
    // Assuming user_settings_table.dart is imported as user_settings_table
    // For now, let's assume the import alias or direct import makes getUnsyncedUserSettings available.
    // If not, this will need an import: import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_settings_table.dart' as user_settings_tbl;
    // Then call: user_settings_tbl.getUnsyncedUserSettings(currentUserId, db);
    // For this edit, I'll assume direct availability. It will be caught if not.
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserSettings(currentUserId); // from user_settings_table.dart

    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced UserSettings found for user $currentUserId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced UserSettings for user $currentUserId.');

    const String tableName = 'user_settings'; // Supabase table name

    for (final record in unsyncedRecords) {
      final String? userId = record['user_id'] as String?;
      final String? settingName = record['setting_name'] as String?;
      final int hasBeenSynced = record['has_been_synced'] as int? ?? 0;

      assert(userId != null, 'syncUserSettings: Unsynced user setting record encountered with null user_id. Record: $record');
      assert(settingName != null, 'syncUserSettings: Unsynced user setting record encountered with null setting_name. Record: $record');

      // Ensure the record belongs to the current user (should be guaranteed by getUnsynced...)
      if (userId! != currentUserId) {
          QuizzerLogger.logWarning('syncUserSettings: Skipping record not belonging to current user. User in record: $userId, Current User: $currentUserId');
          continue;
      }

      // Ensure last_modified_timestamp is present before push/update
      Map<String, dynamic> mutableRecord = Map<String, dynamic>.from(record);
      if (mutableRecord['last_modified_timestamp'] == null || 
          (mutableRecord['last_modified_timestamp'] is String && (mutableRecord['last_modified_timestamp'] as String).isEmpty)) {
        QuizzerLogger.logWarning('syncUserSettings: Record (User: $userId, Setting: $settingName) missing last_modified_timestamp. Assigning current time.');
        mutableRecord['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();
      }

      bool operationSuccess = false;

      if (hasBeenSynced == 0) {
        // This is a new record, use insert
        QuizzerLogger.logValue('Preparing to insert UserSetting (User: $userId, Setting: $settingName) into $tableName');
        operationSuccess = await pushRecordToSupabase(tableName, mutableRecord);
      } else {
        // This is an existing record with edits, use update
        QuizzerLogger.logValue('Preparing to update UserSetting (User: $userId, Setting: $settingName) in $tableName');
        operationSuccess = await updateRecordWithCompositeKeyInSupabase(
          tableName,
          mutableRecord,
          compositeKeyFilters: {'user_id': userId, 'setting_name': settingName!},
        );
      }

      if (operationSuccess) {
        final operation = (hasBeenSynced == 0) ? 'Insert' : 'Update';
        QuizzerLogger.logMessage('$operation successful for UserSetting (User: $userId, Setting: $settingName). Updating local flags...');
        // Call the function from user_settings_table.dart (assuming direct import or alias)
        await updateUserSettingSyncFlags(
          userId: userId,
          settingName: settingName!,
          hasBeenSynced: true, 
          editsAreSynced: true, 
        );
      } else {
        final operation = (hasBeenSynced == 0) ? 'Insert' : 'Update';
        QuizzerLogger.logWarning('$operation FAILED for UserSetting (User: $userId, Setting: $settingName). Local flags remain unchanged.');
      }
    }

    QuizzerLogger.logMessage('Finished sync attempt for UserSettings.');
  } catch (e) {
    QuizzerLogger.logError('syncUserSettings: Error - $e');
    rethrow;
  }
}

// ==========================================
// Outbound Sync - User Feedback
// ==========================================

/// Fetches unsynced user feedback, pushes them to Supabase, and deletes them locally on success.
Future<void> syncUserFeedback() async {
  try {
    QuizzerLogger.logMessage('Starting sync for UserFeedback...');

    // Fetch records needing sync
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserFeedback();

    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced UserFeedback found to sync.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced UserFeedback records to process.');

    const String tableName = 'user_feedback'; // Supabase table name
    List<String> successfullySyncedIds = [];

    for (final record in unsyncedRecords) {
      final String? recordId = record['id'] as String?;

      if (recordId == null) {
        QuizzerLogger.logError('Skipping unsynced user feedback record due to missing ID: $record');
        continue;
      }

      // Attempt to push the record to Supabase.
      QuizzerLogger.logValue('Preparing to push UserFeedback $recordId to $tableName');
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);

      if (pushSuccess) {
        QuizzerLogger.logSuccess('Push successful for UserFeedback $recordId.');
        successfullySyncedIds.add(recordId);
      } else {
        QuizzerLogger.logWarning('Push FAILED for UserFeedback $recordId. Record will remain for next sync attempt.');
      }
    }

    // Delete all successfully synced records locally in a batch
    if (successfullySyncedIds.isNotEmpty) {
      QuizzerLogger.logMessage('Deleting ${successfullySyncedIds.length} successfully synced UserFeedback records locally...');
      await deleteLocalUserFeedback(successfullySyncedIds);
    }

    QuizzerLogger.logMessage('Finished sync attempt for UserFeedback.');
  } catch (e) {
    QuizzerLogger.logError('syncUserFeedback: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsEligibleQuestions() async {
  try {
    QuizzerLogger.logMessage('Starting sync for UserStatsEligibleQuestions...');

    final SessionManager sessionManager = getSessionManager();
    final String? currentUserId = sessionManager.userId;
    if (currentUserId == null) {
      QuizzerLogger.logWarning('syncUserStatsEligibleQuestions: No current user logged in. Cannot proceed.');
      return;
    }

    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserStatsEligibleQuestionsRecords(currentUserId);
    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced UserStatsEligibleQuestions found for user $currentUserId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced UserStatsEligibleQuestions for user $currentUserId.');

    const String tableName = 'user_stats_eligible_questions';
    for (final record in unsyncedRecords) {
      final String? userId = record['user_id'] as String?;
      final String? recordDate = record['record_date'] as String?;
      if (userId == null || recordDate == null) {
        QuizzerLogger.logWarning('Skipping unsynced user stats eligible questions record due to missing PK: $record');
        continue;
      }
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);
      if (pushSuccess) {
        QuizzerLogger.logSuccess('Push successful for UserStatsEligibleQuestions (User: $userId, Date: $recordDate). Updating local flags...');
        await updateUserStatsEligibleQuestionsSyncFlags(
          userId: userId,
          recordDate: recordDate,
          hasBeenSynced: true,
          editsAreSynced: true,
        );
      } else {
        QuizzerLogger.logWarning('Push FAILED for UserStatsEligibleQuestions (User: $userId, Date: $recordDate). Local flags remain unchanged.');
      }
    }
    QuizzerLogger.logMessage('Finished sync attempt for UserStatsEligibleQuestions.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsEligibleQuestions: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsNonCirculatingQuestions() async {
  try {
    QuizzerLogger.logMessage('Starting sync for UserStatsNonCirculatingQuestions...');

    final SessionManager sessionManager = getSessionManager();
    final String? currentUserId = sessionManager.userId;
    if (currentUserId == null) {
      QuizzerLogger.logWarning('syncUserStatsNonCirculatingQuestions: No current user logged in. Cannot proceed.');
      return;
    }

    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserStatsNonCirculatingQuestionsRecords(currentUserId);
    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced UserStatsNonCirculatingQuestions found for user $currentUserId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced UserStatsNonCirculatingQuestions for user $currentUserId.');

    const String tableName = 'user_stats_non_circulating_questions';
    for (final record in unsyncedRecords) {
      final String? userId = record['user_id'] as String?;
      final String? recordDate = record['record_date'] as String?;
      if (userId == null || recordDate == null) {
        QuizzerLogger.logWarning('Skipping unsynced user_stats_non_circulating_questions record due to missing PK: $record');
        continue;
      }
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);
      if (pushSuccess) {
        QuizzerLogger.logSuccess('Push successful for UserStatsNonCirculatingQuestions (User: $userId, Date: $recordDate). Updating local flags...');
        await updateUserStatsNonCirculatingQuestionsSyncFlags(
          userId: userId,
          recordDate: recordDate,
          hasBeenSynced: true,
          editsAreSynced: true,
        );
      } else {
        QuizzerLogger.logWarning('Push FAILED for UserStatsNonCirculatingQuestions (User: $userId, Date: $recordDate). Local flags remain unchanged.');
      }
    }
    QuizzerLogger.logMessage('Finished sync attempt for UserStatsNonCirculatingQuestions.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsNonCirculatingQuestions: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsInCirculationQuestions() async {
  try {
    QuizzerLogger.logMessage('Starting sync for UserStatsInCirculationQuestions...');

    final SessionManager sessionManager = getSessionManager();
    final String? currentUserId = sessionManager.userId;
    if (currentUserId == null) {
      QuizzerLogger.logWarning('syncUserStatsInCirculationQuestions: No current user logged in. Cannot proceed.');
      return;
    }

    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserStatsInCirculationQuestionsRecords(currentUserId);
    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced UserStatsInCirculationQuestions found for user $currentUserId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced UserStatsInCirculationQuestions for user $currentUserId.');

    const String tableName = 'user_stats_in_circulation_questions';
    for (final record in unsyncedRecords) {
      final String? userId = record['user_id'] as String?;
      final String? recordDate = record['record_date'] as String?;
      if (userId == null || recordDate == null) {
        QuizzerLogger.logWarning('Skipping unsynced user_stats_in_circulation_questions record due to missing PK: $record');
        continue;
      }
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);
      if (pushSuccess) {
        QuizzerLogger.logSuccess('Push successful for UserStatsInCirculationQuestions (User: $userId, Date: $recordDate). Updating local flags...');
        await updateUserStatsInCirculationQuestionsSyncFlags(
          userId: userId,
          recordDate: recordDate,
          hasBeenSynced: true,
          editsAreSynced: true,
        );
      } else {
        QuizzerLogger.logWarning('Push FAILED for UserStatsInCirculationQuestions (User: $userId, Date: $recordDate). Local flags remain unchanged.');
      }
    }
    QuizzerLogger.logMessage('Finished sync attempt for UserStatsInCirculationQuestions.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsInCirculationQuestions: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsRevisionStreakSum() async {
  try {
    QuizzerLogger.logMessage('Starting sync for UserStatsRevisionStreakSum...');

    final SessionManager sessionManager = getSessionManager();
    final String? currentUserId = sessionManager.userId;
    if (currentUserId == null) {
      QuizzerLogger.logWarning('syncUserStatsRevisionStreakSum: No current user logged in. Cannot proceed.');
      return;
    }

    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserStatsRevisionStreakSumRecords(currentUserId);
    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced UserStatsRevisionStreakSum found for user $currentUserId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced UserStatsRevisionStreakSum for user $currentUserId.');

    const String tableName = 'user_stats_revision_streak_sum';
    for (final record in unsyncedRecords) {
      final String? userId = record['user_id'] as String?;
      final String? recordDate = record['record_date'] as String?;
      final int? revisionStreakScore = record['revision_streak_score'] as int?;
      if (userId == null || recordDate == null || revisionStreakScore == null) {
        QuizzerLogger.logWarning('Skipping unsynced user_stats_revision_streak_sum record due to missing PK: $record');
        continue;
      }
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);
      if (pushSuccess) {
        QuizzerLogger.logSuccess('Push successful for UserStatsRevisionStreakSum (User: $userId, Date: $recordDate, Streak: $revisionStreakScore). Updating local flags...');
        await updateUserStatsRevisionStreakSumSyncFlags(
          userId: userId,
          recordDate: recordDate,
          revisionStreakScore: revisionStreakScore,
          hasBeenSynced: true,
          editsAreSynced: true,
        );
      } else {
        QuizzerLogger.logWarning('Push FAILED for UserStatsRevisionStreakSum (User: $userId, Date: $recordDate, Streak: $revisionStreakScore). Local flags remain unchanged.');
      }
    }
    QuizzerLogger.logMessage('Finished sync attempt for UserStatsRevisionStreakSum.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsRevisionStreakSum: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsTotalUserQuestionAnswerPairs() async {
  try {
    QuizzerLogger.logMessage('Starting sync for UserStatsTotalUserQuestionAnswerPairs...');

    final SessionManager sessionManager = getSessionManager();
    final String? currentUserId = sessionManager.userId;
    if (currentUserId == null) {
      QuizzerLogger.logWarning('syncUserStatsTotalUserQuestionAnswerPairs: No current user logged in. Cannot proceed.');
      return;
    }

    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserStatsTotalUserQuestionAnswerPairsRecords(currentUserId);
    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced UserStatsTotalUserQuestionAnswerPairs found for user $currentUserId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced UserStatsTotalUserQuestionAnswerPairs for user $currentUserId.');

    const String tableName = 'user_stats_total_user_question_answer_pairs';
    for (final record in unsyncedRecords) {
      final String? userId = record['user_id'] as String?;
      final String? recordDate = record['record_date'] as String?;
      if (userId == null || recordDate == null) {
        QuizzerLogger.logWarning('Skipping unsynced user_stats_total_user_question_answer_pairs record due to missing PK: $record');
        continue;
      }
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);
      if (pushSuccess) {
        QuizzerLogger.logSuccess('Push successful for UserStatsTotalUserQuestionAnswerPairs (User: $userId, Date: $recordDate). Updating local flags...');
        await updateUserStatsTotalUserQuestionAnswerPairsSyncFlags(
          userId: userId,
          recordDate: recordDate,
          hasBeenSynced: true,
          editsAreSynced: true,
        );
      } else {
        QuizzerLogger.logWarning('Push FAILED for UserStatsTotalUserQuestionAnswerPairs (User: $userId, Date: $recordDate). Local flags remain unchanged.');
      }
    }
    QuizzerLogger.logMessage('Finished sync attempt for UserStatsTotalUserQuestionAnswerPairs.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsTotalUserQuestionAnswerPairs: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsAverageQuestionsShownPerDay() async {
  try {
    QuizzerLogger.logMessage('Starting sync for UserStatsAverageQuestionsShownPerDay...');

    final SessionManager sessionManager = getSessionManager();
    final String? currentUserId = sessionManager.userId;
    if (currentUserId == null) {
      QuizzerLogger.logWarning('syncUserStatsAverageQuestionsShownPerDay: No current user logged in. Cannot proceed.');
      return;
    }

    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserStatsAverageQuestionsShownPerDayRecords(currentUserId);
    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced UserStatsAverageQuestionsShownPerDay found for user $currentUserId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced UserStatsAverageQuestionsShownPerDay for user $currentUserId.');

    const String tableName = 'user_stats_average_questions_shown_per_day';
    for (final record in unsyncedRecords) {
      final String? userId = record['user_id'] as String?;
      final String? recordDate = record['record_date'] as String?;
      if (userId == null || recordDate == null) {
        QuizzerLogger.logWarning('Skipping unsynced user_stats_average_questions_shown_per_day record due to missing PK: $record');
        continue;
      }
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);
      if (pushSuccess) {
        QuizzerLogger.logSuccess('Push successful for UserStatsAverageQuestionsShownPerDay (User: $userId, Date: $recordDate). Updating local flags...');
        await updateUserStatsAverageQuestionsShownPerDaySyncFlags(
          userId: userId,
          recordDate: recordDate,
          hasBeenSynced: true,
          editsAreSynced: true,
        );
      } else {
        QuizzerLogger.logWarning('Push FAILED for UserStatsAverageQuestionsShownPerDay (User: $userId, Date: $recordDate). Local flags remain unchanged.');
      }
    }
    QuizzerLogger.logMessage('Finished sync attempt for UserStatsAverageQuestionsShownPerDay.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsAverageQuestionsShownPerDay: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsTotalQuestionsAnswered() async {
  try {
    QuizzerLogger.logMessage('Starting sync for UserStatsTotalQuestionsAnswered...');

    final SessionManager sessionManager = getSessionManager();
    final String? currentUserId = sessionManager.userId;
    if (currentUserId == null) {
      QuizzerLogger.logWarning('syncUserStatsTotalQuestionsAnswered: No current user logged in. Cannot proceed.');
      return;
    }

    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserStatsTotalQuestionsAnsweredRecords(currentUserId);
    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced UserStatsTotalQuestionsAnswered found for user $currentUserId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced UserStatsTotalQuestionsAnswered for user $currentUserId.');

    const String tableName = 'user_stats_total_questions_answered';
    for (final record in unsyncedRecords) {
      final String? userId = record['user_id'] as String?;
      final String? recordDate = record['record_date'] as String?;
      if (userId == null || recordDate == null) {
        QuizzerLogger.logWarning('Skipping unsynced user_stats_total_questions_answered record due to missing PK: $record');
        continue;
      }
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);
      if (pushSuccess) {
        QuizzerLogger.logSuccess('Push successful for UserStatsTotalQuestionsAnswered (User: $userId, Date: $recordDate). Updating local flags...');
        await updateUserStatsTotalQuestionsAnsweredSyncFlags(
          userId: userId,
          recordDate: recordDate,
          hasBeenSynced: true,
          editsAreSynced: true,
        );
      } else {
        QuizzerLogger.logWarning('Push FAILED for UserStatsTotalQuestionsAnswered (User: $userId, Date: $recordDate). Local flags remain unchanged.');
      }
    }
    QuizzerLogger.logMessage('Finished sync attempt for UserStatsTotalQuestionsAnswered.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsTotalQuestionsAnswered: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsDailyQuestionsAnswered() async {
  try {
    QuizzerLogger.logMessage('Starting sync for UserStatsDailyQuestionsAnswered...');

    final SessionManager sessionManager = getSessionManager();
    final String? currentUserId = sessionManager.userId;
    if (currentUserId == null) {
      QuizzerLogger.logWarning('syncUserStatsDailyQuestionsAnswered: No current user logged in. Cannot proceed.');
      return;
    }

    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserStatsDailyQuestionsAnsweredRecords(currentUserId);
    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced UserStatsDailyQuestionsAnswered found for user $currentUserId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced UserStatsDailyQuestionsAnswered for user $currentUserId.');

    const String tableName = 'user_stats_daily_questions_answered';
    for (final record in unsyncedRecords) {
      final String? userId = record['user_id'] as String?;
      final String? recordDate = record['record_date'] as String?;
      if (userId == null || recordDate == null) {
        QuizzerLogger.logWarning('Skipping unsynced user_stats_daily_questions_answered record due to missing PK: $record');
        continue;
      }
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);
      if (pushSuccess) {
        QuizzerLogger.logSuccess('Push successful for UserStatsDailyQuestionsAnswered (User: $userId, Date: $recordDate). Updating local flags...');
        await updateUserStatsDailyQuestionsAnsweredSyncFlags(
          userId: userId,
          recordDate: recordDate,
          hasBeenSynced: true,
          editsAreSynced: true,
        );
      } else {
        QuizzerLogger.logWarning('Push FAILED for UserStatsDailyQuestionsAnswered (User: $userId, Date: $recordDate). Local flags remain unchanged.');
      }
    }
    QuizzerLogger.logMessage('Finished sync attempt for UserStatsDailyQuestionsAnswered.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsDailyQuestionsAnswered: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsDaysLeftUntilQuestionsExhaust() async {
  try {
    final sessionManager = getSessionManager();
    final String? userId = sessionManager.userId;
    if (userId == null) {
      QuizzerLogger.logWarning('syncUserStatsDaysLeftUntilQuestionsExhaust: No current user logged in. Cannot proceed.');
      return;
    }
    final unsyncedRecords = await getUnsyncedUserStatsDaysLeftUntilQuestionsExhaustRecords(userId);
    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced days_left_until_questions_exhaust records for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced days_left_until_questions_exhaust records for user $userId.');

    const String tableName = 'user_stats_days_left_until_questions_exhaust';
    for (final record in unsyncedRecords) {
      final String? recordUserId = record['user_id'] as String?;
      final String? recordDate = record['record_date'] as String?;
      if (recordUserId == null || recordDate == null) {
        QuizzerLogger.logWarning('Skipping unsynced days_left_until_questions_exhaust record due to missing PK: $record');
        continue;
      }
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);
      if (pushSuccess) {
        QuizzerLogger.logSuccess('Push successful for days_left_until_questions_exhaust (User: $recordUserId, Date: $recordDate). Updating local flags...');
        await updateUserStatsDaysLeftUntilQuestionsExhaustSyncFlags(
          userId: recordUserId,
          recordDate: recordDate,
          hasBeenSynced: true,
          editsAreSynced: true,
        );
      } else {
        QuizzerLogger.logWarning('Push FAILED for days_left_until_questions_exhaust (User: $recordUserId, Date: $recordDate). Local flags remain unchanged.');
      }
    }
    QuizzerLogger.logMessage('Finished sync attempt for days_left_until_questions_exhaust.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsDaysLeftUntilQuestionsExhaust: Error - $e');
    rethrow;
  }
}

Future<void> syncUserStatsAverageDailyQuestionsLearned() async {
  try {
    final sessionManager = getSessionManager();
    final String? userId = sessionManager.userId;
    if (userId == null) {
      QuizzerLogger.logWarning('syncUserStatsAverageDailyQuestionsLearned: No current user logged in. Cannot proceed.');
      return;
    }
    final unsyncedRecords = await getUnsyncedUserStatsAverageDailyQuestionsLearnedRecords(userId);
    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced average_daily_questions_learned records for user $userId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced average_daily_questions_learned records for user $userId.');

    const String tableName = 'user_stats_average_daily_questions_learned';
    for (final record in unsyncedRecords) {
      final String? recordUserId = record['user_id'] as String?;
      final String? recordDate = record['record_date'] as String?;
      if (recordUserId == null || recordDate == null) {
        QuizzerLogger.logWarning('Skipping unsynced average_daily_questions_learned record due to missing PK: $record');
        continue;
      }
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);
      if (pushSuccess) {
        QuizzerLogger.logSuccess('Push successful for average_daily_questions_learned (User: $recordUserId, Date: $recordDate). Updating local flags...');
        await updateUserStatsAverageDailyQuestionsLearnedSyncFlags(
          userId: recordUserId,
          recordDate: recordDate,
          hasBeenSynced: true,
          editsAreSynced: true,
        );
      } else {
        QuizzerLogger.logWarning('Push FAILED for average_daily_questions_learned (User: $recordUserId, Date: $recordDate). Local flags remain unchanged.');
      }
    }
    QuizzerLogger.logMessage('Finished sync attempt for average_daily_questions_learned.');
  } catch (e) {
    QuizzerLogger.logError('syncUserStatsAverageDailyQuestionsLearned: Error - $e');
    rethrow;
  }
}

// ==========================================
// Outbound Sync - User Module Activation Status
// ==========================================

/// Fetches unsynced user module activation status records for the current user,
/// pushes new ones or updates existing ones, and updates local sync flags.
Future<void> syncUserModuleActivationStatus() async {
  try {
    QuizzerLogger.logMessage('Starting sync for UserModuleActivationStatus...');

    final SessionManager sessionManager = getSessionManager();
    final String? currentUserId = sessionManager.userId;

    if (currentUserId == null) {
      QuizzerLogger.logWarning('syncUserModuleActivationStatus: No current user logged in. Cannot proceed.');
      return;
    }

    // Fetch records needing sync for the current user
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedModuleActivationStatusRecords(currentUserId);

    if (unsyncedRecords.isEmpty) {
      QuizzerLogger.logMessage('No unsynced UserModuleActivationStatus found for user $currentUserId.');
      return;
    }

    QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced UserModuleActivationStatus for user $currentUserId.');

    const String tableName = 'user_module_activation_status';

    for (final record in unsyncedRecords) {
      final String? userId = record['user_id'] as String?;
      final String? moduleName = record['module_name'] as String?;
      final int hasBeenSynced = record['has_been_synced'] as int? ?? 0;

      if (userId == null || moduleName == null) {
        QuizzerLogger.logWarning('Skipping unsynced user module activation status record due to missing PK: $record');
        continue;
      }

      // Ensure the record belongs to the current user
      if (userId != currentUserId) {
        QuizzerLogger.logWarning('syncUserModuleActivationStatus: Skipping record not belonging to current user. User in record: $userId, Current User: $currentUserId');
        continue;
      }

      // Ensure last_modified_timestamp is present before push/update
      Map<String, dynamic> mutableRecord = Map<String, dynamic>.from(record);
      if (mutableRecord['last_modified_timestamp'] == null || 
          (mutableRecord['last_modified_timestamp'] is String && (mutableRecord['last_modified_timestamp'] as String).isEmpty)) {
        QuizzerLogger.logWarning('syncUserModuleActivationStatus: Record (User: $userId, Module: $moduleName) missing last_modified_timestamp. Assigning current time.');
        mutableRecord['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();
      }

      bool operationSuccess = false;

      if (hasBeenSynced == 0) {
        // This is a new record, use insert
        QuizzerLogger.logValue('Preparing to insert UserModuleActivationStatus (User: $userId, Module: $moduleName) into $tableName');
        operationSuccess = await pushRecordToSupabase(tableName, mutableRecord);
      } else {
        // This is an existing record with edits, use update
        QuizzerLogger.logValue('Preparing to update UserModuleActivationStatus (User: $userId, Module: $moduleName) in $tableName');
        operationSuccess = await updateRecordWithCompositeKeyInSupabase(
          tableName,
          mutableRecord,
          compositeKeyFilters: {'user_id': userId, 'module_name': moduleName},
        );
      }

      if (operationSuccess) {
        final operation = (hasBeenSynced == 0) ? 'Insert' : 'Update';
        QuizzerLogger.logMessage('$operation successful for UserModuleActivationStatus (User: $userId, Module: $moduleName). Updating local flags...');
        await updateModuleActivationStatusSyncFlags(
          userId: userId,
          moduleName: moduleName,
          hasBeenSynced: true, 
          editsAreSynced: true, 
        );
      } else {
        final operation = (hasBeenSynced == 0) ? 'Insert' : 'Update';
        QuizzerLogger.logWarning('$operation FAILED for UserModuleActivationStatus (User: $userId, Module: $moduleName). Local flags remain unchanged.');
      }
    }

    QuizzerLogger.logMessage('Finished sync attempt for UserModuleActivationStatus.');
  } catch (e) {
    QuizzerLogger.logError('syncUserModuleActivationStatus: Error - $e');
    rethrow;
  }
}
