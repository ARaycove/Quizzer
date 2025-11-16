import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_daily_stats_table.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // To get Supabase client
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart'; // Import for table functions
import 'package:quizzer/backend_systems/00_database_manager/tables/system_data/login_attempts_table.dart'; // Import for login attempts table functions
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_attempts_table.dart'; // Import for attempt table functions
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart'; // Import for user profile table functions
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart'; // Import for UserQuestionAnswerPairs table functions
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pair_flags_table.dart'; // Import for flags table functions
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Import Logger
import 'package:supabase/supabase.dart'; // Import for PostgrestException & SupabaseClient
import 'package:quizzer/backend_systems/00_database_manager/tables/system_data/error_logs_table.dart'; // Added for syncErrorLogs
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_settings_table.dart'; // Added for user settings table
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/system_data/user_feedback_table.dart'; // Added for user feedback
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_module_activation_status_table.dart';
import 'package:quizzer/backend_systems/12_answer_validator/answer_validation/text_analysis_tools.dart';
import 'dart:io'; // For SocketException

// ==========================================
// Outbound Sync - Generic Push Function

/// Attempts to push a batch of records to a specified Supabase table using upsert.
/// Automatically splits large lists into batches of 500 records.
/// Returns true if all batches complete successfully, false if any batch fails.
Future<bool> pushBatchToSupabase(String tableName, List<Map<String, dynamic>> records, {List<String>? conflictKeys}) async {
  try {
    if (records.isEmpty) {
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
    final supabase = getSessionManager().supabase;
    Map<String, dynamic> payload = Map.from(recordData);
    payload.remove('has_been_synced');
    payload.remove('edits_are_synced');
    payload.forEach((key, value) {
      if (value is double && value.isInfinite) {
        payload[key] = 1.0;
      }
    });
    await supabase.from(tableName).upsert(payload);
    return true;
  } on PostgrestException catch (e) {
    // Handle Supabase-specific errors (network, policy violations, etc.)
    QuizzerLogger.logWarning('Supabase upsert FAILED for record to $tableName: ${e.message} (Code: ${e.code})');
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
      await supabase.from(tableName).insert(payload);
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
    return true; // Assume success if no exception is thrown

  } on PostgrestException catch (e) {
     // Handle Supabase-specific errors (network, policy violations, etc.)
     QuizzerLogger.logError('Supabase PostgrestException during update for ID $primaryKeyValue in $tableName: ${e.message} (Code: ${e.code})');
     QuizzerLogger.logMessage("Payload that failed to push: $recordData");
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
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedQuestionAnswerPairs();
    if (unsyncedRecords.isEmpty) {
      return;
    }
    final List<Map<String, dynamic>> processedRecords = [];
    final SessionManager sessionManager = getSessionManager();
    final String? currentUserId = sessionManager.userId;
    final String currentUserRole = sessionManager.userRole;
    final bool isPrivilegedUser = currentUserRole == 'admin' || currentUserRole == 'contributor';
    
    for (final record in unsyncedRecords) {
      Map<String, dynamic> mutableRecord = Map<String, dynamic>.from(record);
      
      if (record['last_modified_timestamp'] == null || (record['last_modified_timestamp'] is String && (record['last_modified_timestamp'] as String).isEmpty)) {
        mutableRecord['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();
      }
      
      if (record['time_stamp'] == null || (record['time_stamp'] is String && (record['time_stamp'] as String).isEmpty)) {
        mutableRecord['time_stamp'] = DateTime.now().toUtc().toIso8601String();
      }
      
      if (record['ans_contrib'] == null || (record['ans_contrib'] is String && (record['ans_contrib'] as String).isEmpty)) {
        if (currentUserId != null) {
          mutableRecord['ans_contrib'] = currentUserId;
        } else {
          mutableRecord['ans_contrib'] = '';
        }
      }
      
      if (record['completed'] == null) {
        final int completionStatus = checkCompletionStatus(
          record['question_elements'] as String? ?? '',
          record['answer_elements'] as String? ?? ''
        );
        mutableRecord['completed'] = completionStatus;
      }
      
      processedRecords.add(mutableRecord);
    }
    
    for (final record in processedRecords) {
      int hasBeenSynced = record['has_been_synced'] as int? ?? -1;
      int editsAreSynced = record['edits_are_synced'] as int? ?? -1;
      
      if (hasBeenSynced == -1) {
        hasBeenSynced = 1;
      }
      if (editsAreSynced == -1) {
        editsAreSynced = 1;
      }
      
      String? reviewTable;
      if (hasBeenSynced == 0 && editsAreSynced == 0) {
        reviewTable = 'question_answer_pair_new_review';
      } else if (hasBeenSynced == 1 && editsAreSynced == 0) {
        reviewTable = 'question_answer_pair_edits_review';
      } else {
        continue;
      }
      
      if (record['module_name'] != null && record['module_name'] is String) {
        final String normalizedModuleName = await normalizeString(record['module_name'] as String);
        record['module_name'] = normalizedModuleName;
      }
      
      bool pushSuccess = await pushRecordToSupabase(reviewTable, record);
      
      if (pushSuccess && isPrivilegedUser) {
        final bool mainTablePushSuccess = await pushRecordToSupabase('question_answer_pairs', record);
        if (!mainTablePushSuccess) {
          pushSuccess = false;
        }
      }
      
      if (pushSuccess) {
        await updateQuestionSyncFlags(
          questionId: record['question_id'],
          hasBeenSynced: true,
          editsAreSynced: true,
        );
      }
    }
  } catch (e) {
    QuizzerLogger.logError('syncQuestionAnswerPairs: Error - $e');
    rethrow;
  }
}

/// Fetches unsynced login attempts, pushes them to Supabase, and deletes locally on success.
Future<void> syncLoginAttempts() async {
  try {

    // Fetch records needing sync - Remove try-catch, let DB errors propagate
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedLoginAttempts();

    if (unsyncedRecords.isEmpty) {
      return;
    }

    final supabase = getSessionManager().supabase; // Get Supabase client instance
    const String tableName = 'login_attempts'; // Target Supabase table

    for (final record in unsyncedRecords) {
      final loginAttemptId = record['login_attempt_id'] as String;

      // Prepare payload for Supabase (remove local-only flags)
      Map<String, dynamic> payload = Map.from(record);
      payload.remove('has_been_synced');
      payload.remove('edits_are_synced');

      // Keep try-catch ONLY around the Supabase network call
      try {
        // Attempt to insert the record into Supabase
        await supabase.from(tableName).insert(payload);

        // If Supabase insert succeeds, delete the local record directly.
        // Remove nested try-catch. If delete fails, the error propagates (Fail Fast).
        await deleteLoginAttemptRecord(loginAttemptId);

      } on PostgrestException catch (e) {
        QuizzerLogger.logError("Postgrest Exception was: $e");
        // Handle potential Supabase errors (e.g., network, policy violation, duplicate PK if attempted)
        // Do not delete local record if push failed
      } catch (e) {
        // Handle other potential network/client errors during Supabase call
        QuizzerLogger.logError('Supabase insert FAILED for LoginAttempt $loginAttemptId: $e');
        // Do not delete local record if push failed
      }
      // Removed nested try-catch for local delete
    }

  } catch (e) {
    rethrow;
  }
}

/// Fetches unsynced question answer attempts, pushes them to Supabase, and updates local flags on success.
Future<void> syncQuestionAnswerAttempts() async {
  try {
    // Fetch records needing sync
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedQuestionAnswerAttempts();
    if (unsyncedRecords.isEmpty) {
      return;
    }

    // Process records dynamically - no hardcoded field validation
    final List<Map<String, dynamic>> validRecords = [];
    for (final record in unsyncedRecords) {
      // Only validate primary key components for deletion tracking
      final String? participantId = record['participant_id'] as String?;
      final String? questionId = record['question_id'] as String?;
      final String? timeStamp = record['time_stamp'] as String?;
      
      if (participantId == null || questionId == null || timeStamp == null || 
          participantId.isEmpty || questionId.isEmpty || timeStamp.isEmpty) {
        QuizzerLogger.logError('Skipping unsynced attempt record due to missing primary key components: $record');
        continue;
      }

      // Clean the record dynamically - remove null values and sync flags
      final Map<String, dynamic> cleanRecord = {};
      for (final entry in record.entries) {
        final String fieldName = entry.key;
        final dynamic fieldValue = entry.value;
        
        // Skip sync tracking fields - these are local only
        if (['has_been_synced', 'edits_are_synced', 'last_modified_timestamp'].contains(fieldName)) {
          continue;
        }
        
        // Only include non-null values
        if (fieldValue != null) {
          cleanRecord[fieldName] = fieldValue;
        }
      }
      
      validRecords.add(cleanRecord);
    }

    if (validRecords.isEmpty) {
      return;
    }

    // Push records individually
    const String tableName = 'question_answer_attempts';
    for (int i = 0; i < validRecords.length; i++) {
      final record = validRecords[i];
      final originalRecord = unsyncedRecords[i];
      
      try {
        final bool pushSuccess = await pushRecordToSupabase(tableName, record);
        if (pushSuccess) {
          // Delete the successfully synced record locally using original record for PK
          await deleteQuestionAnswerAttemptRecord(
            originalRecord['participant_id'] as String,
            originalRecord['question_id'] as String,
            originalRecord['time_stamp'] as String,
          );
          // QuizzerLogger.logSuccess('Successfully synced and deleted local attempt record: ${record['question_id']}');
        }
      } catch (e) {
        QuizzerLogger.logError('Failed to sync individual attempt record ${record['question_id']}: $e');
        // Continue with other records instead of failing entire batch
      }
    }
  } catch (e) {
    QuizzerLogger.logError('syncQuestionAnswerAttempts: Error - $e');
    rethrow;
  }
}

/// Fetches unsynced user profiles, pushes new ones or updates existing ones, and updates local flags on success.
Future<void> syncUserProfiles() async {
  try {
    // Get the current user's ID from SessionManager
    final SessionManager sessionManager = getSessionManager();
    final String? currentUserId = sessionManager.userId;

    if (currentUserId == null) {
      QuizzerLogger.logWarning('syncUserProfiles: No current user logged in. Cannot proceed.');
      return; // Cannot sync if no user is logged in
    }

    // Fetch records needing sync for the current user
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserProfiles(currentUserId);

    if (unsyncedRecords.isEmpty) {
      return;
    }

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
        pushOrUpdateSuccess = await pushRecordToSupabase(tableName, record);
      } else {
        // This is an existing record with edits, use update (via updateRecordInSupabase)
        pushOrUpdateSuccess = await updateRecordInSupabase(
          tableName,
          record,
          primaryKeyColumn: primaryKey,
          primaryKeyValue: userId,
        );
      }

      // If push or update was successful, update local flags
      if (pushOrUpdateSuccess) {
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
    final SessionManager sessionManager = getSessionManager();
    if (sessionManager.userId == null) {return;}
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserQuestionAnswerPairs(sessionManager.userId!);
    if (unsyncedRecords.isEmpty) {
      return;
    }
    
    // Create mutable copies and process them
    final List<Map<String, dynamic>> mutableRecords = [];
    for (final record in unsyncedRecords) {
      final Map<String, dynamic> mutableRecord = Map<String, dynamic>.from(record);
      
      if (mutableRecord['last_modified_timestamp'] == null || (mutableRecord['last_modified_timestamp'] is String && (mutableRecord['last_modified_timestamp'] as String).isEmpty)) {
        mutableRecord['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();
      }
      // Sanitize Infinity values
      mutableRecord.forEach((key, value) {
        if (value is double && value.isInfinite) {
          mutableRecord[key] = 1.0;
        }
      });
      
      // Remove local-only fields that should not be synced to server
      mutableRecord.remove('accuracy_probability');
      mutableRecord.remove('last_prob_calc');
      
      mutableRecords.add(mutableRecord);
    }
    
    // Push records individually
    const String tableName = 'user_question_answer_pairs';
    for (final record in mutableRecords) {
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);
      if (pushSuccess) {
        await updateUserQuestionAnswerPairSyncFlags(
          userUuid: record['user_uuid'] as String,
          questionId: record['question_id'] as String,
          hasBeenSynced: true,
          editsAreSynced: true,
        );
      }
    }
  } catch (e) {
    QuizzerLogger.logError('syncUserQuestionAnswerPairs: Error - $e');
    rethrow;
  }
}

/// Fetches unsynced modules, pushes them to Supabase, and updates local flags on success.
Future<void> syncModules() async {
  try {
    // Fetch records needing sync
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedModules();

    if (unsyncedRecords.isEmpty) {
      return;
    }

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

    for (final record in unsyncedRecords) {
      // Normalize the module name before sending to server
      if (record['module_name'] != null && record['module_name'] is String) {
        final String normalizedModuleName = await normalizeString(record['module_name'] as String);
        record['module_name'] = normalizedModuleName;
      }
      
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);
      if (pushSuccess) {
        await updateModuleSyncFlags(
          moduleName: record['module_name'] as String,
          hasBeenSynced: true,
          editsAreSynced: true,
        );
      }
    }
  } catch (e) {
    QuizzerLogger.logError('syncModules: Error - $e');
    rethrow;
  }
}

/// Fetches unsynced error logs, pushes them to Supabase, and deletes them locally on success.
Future<void> syncErrorLogs() async {
  try {

    // Fetch records needing sync (already filters for older than 1 hour)
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedErrorLogs();

    if (unsyncedRecords.isEmpty) {
      return;
    }

    const String tableName = 'error_logs';

    for (final record in unsyncedRecords) {
      final String? recordId = record['id'] as String?;

      if (recordId == null) {
        QuizzerLogger.logError('Skipping unsynced error log record due to missing ID: $record');
        continue;
      }

      // Attempt to push the record to Supabase.
      // The pushRecordToSupabase function already removes local-only fields like has_been_synced and edits_are_synced if they were present.
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);

      if (pushSuccess) {
        // If Supabase push succeeds, delete the local record.
        await deleteLocalErrorLog(recordId);
      } else {
        QuizzerLogger.logWarning('Push FAILED for ErrorLog $recordId. Local record will remain for next sync attempt.');
      }
    }
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
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserSettings(currentUserId, skipEnsureRows: true); // from user_settings_table.dart

    if (unsyncedRecords.isEmpty) {
      return;
    }
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

      // Skip push if timestamp is the default timestamp
      if (mutableRecord['last_modified_timestamp'] == '1970-01-01T00:00:00.000Z') {
        await updateUserSettingSyncFlags(
          userId: userId,
          settingName: settingName!,
          hasBeenSynced: true, 
          editsAreSynced: true, 
        );
        continue;
      }

      bool operationSuccess = false;

      if (hasBeenSynced == 0) {
        operationSuccess = await pushRecordToSupabase(tableName, mutableRecord);
      } else {
        // This is an existing record with edits, use update
        operationSuccess = await updateRecordWithCompositeKeyInSupabase(
          tableName,
          mutableRecord,
          compositeKeyFilters: {'user_id': userId, 'setting_name': settingName!},
        );
      }

      if (operationSuccess) {
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
    // Fetch records needing sync
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserFeedback();

    if (unsyncedRecords.isEmpty) {
      return;
    }

    const String tableName = 'user_feedback'; // Supabase table name
    List<String> successfullySyncedIds = [];

    for (final record in unsyncedRecords) {
      final String? recordId = record['id'] as String?;

      if (recordId == null) {
        QuizzerLogger.logError('Skipping unsynced user feedback record due to missing ID: $record');
        continue;
      }

      // Attempt to push the record to Supabase.
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);

      if (pushSuccess) {
        successfullySyncedIds.add(recordId);
      } else {
        QuizzerLogger.logWarning('Push FAILED for UserFeedback $recordId. Record will remain for next sync attempt.');
      }
    }

    // Delete all successfully synced records locally in a batch
    if (successfullySyncedIds.isNotEmpty) {
      await deleteLocalUserFeedback(successfullySyncedIds);
    }
  } catch (e) {
    QuizzerLogger.logError('syncUserFeedback: Error - $e');
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
    final SessionManager sessionManager = getSessionManager();
    final String? currentUserId = sessionManager.userId;

    if (currentUserId == null) {
      QuizzerLogger.logWarning('syncUserModuleActivationStatus: No current user logged in. Cannot proceed.');
      return;
    }

    // Fetch records needing sync for the current user
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedModuleActivationStatusRecords(currentUserId);

    if (unsyncedRecords.isEmpty) {
      return;
    }
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
        // QuizzerLogger.logValue('Preparing to insert UserModuleActivationStatus (User: $userId, Module: $moduleName) into $tableName');
        operationSuccess = await pushRecordToSupabase(tableName, mutableRecord);
      } else {
        // This is an existing record with edits, use update
        // QuizzerLogger.logValue('Preparing to update UserModuleActivationStatus (User: $userId, Module: $moduleName) in $tableName');
        operationSuccess = await updateRecordWithCompositeKeyInSupabase(
          tableName,
          mutableRecord,
          compositeKeyFilters: {'user_id': userId, 'module_name': moduleName},
        );
      }

      if (operationSuccess) {
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
  } catch (e) {
    QuizzerLogger.logError('syncUserModuleActivationStatus: Error - $e');
    rethrow;
  }
}

Future<void> syncUserDailyStats() async {
  try {
    final SessionManager sessionManager = getSessionManager();
    final String? currentUserId = sessionManager.userId;
    if (currentUserId == null) {
      QuizzerLogger.logWarning('syncUserDailyStats: No current user logged in. Cannot proceed.');
      return;
    }

    // Fetch records needing sync for the current user
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserDailyStatsRecords(currentUserId);
    if (unsyncedRecords.isEmpty) {
      return;
    }
    const String tableName = 'user_daily_stats';

    for (final record in unsyncedRecords) {
      final String? userId = record['user_id'] as String?;
      final String? recordDate = record['record_date'] as String?; // CORRECTED FIELD NAME
      final int hasBeenSynced = record['has_been_synced'] as int? ?? 0;

      // Primary Key check for user_daily_stats is (user_id, record_date)
      if (userId == null || recordDate == null) {
        QuizzerLogger.logWarning('Skipping unsynced user daily stats record due to missing PK (user_id or record_date): $record');
        continue;
      }

      // Ensure the record belongs to the current user
      if (userId != currentUserId) {
        QuizzerLogger.logWarning('syncUserDailyStats: Skipping record not belonging to current user. User in record: $userId, Current User: $currentUserId');
        continue;
      }

      // Ensure last_modified_timestamp is present before push/update
      Map<String, dynamic> mutableRecord = Map<String, dynamic>.from(record);
      if (mutableRecord['last_modified_timestamp'] == null || 
          (mutableRecord['last_modified_timestamp'] is String && (mutableRecord['last_modified_timestamp'] as String).isEmpty)) {
        QuizzerLogger.logWarning('syncUserDailyStats: Record (User: $userId, Date: $recordDate) missing last_modified_timestamp. Assigning current time.');
        mutableRecord['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();
      }

      bool operationSuccess = false;

      // The composite key for user_daily_stats is (user_id, record_date)
      final Map<String, dynamic> compositeKeyFilters = {'user_id': userId, 'record_date': recordDate}; // CORRECTED FIELD NAME

      if (hasBeenSynced == 0) {
        // This is a new record, use insert
        QuizzerLogger.logValue('Preparing to insert UserDailyStats (User: $userId, Date: $recordDate) into $tableName');
        operationSuccess = await pushRecordToSupabase(tableName, mutableRecord);
      } else {
        // This is an existing record with edits, use update
        QuizzerLogger.logValue('Preparing to update UserDailyStats (User: $userId, Date: $recordDate) in $tableName');
        operationSuccess = await updateRecordWithCompositeKeyInSupabase(
          tableName,
          mutableRecord,
          compositeKeyFilters: compositeKeyFilters,
        );
      }

      if (operationSuccess) {
        // Update local sync flags
        // Assumed a helper function updateUserDailyStatsSyncFlags exists that takes the correct PK
        await updateUserDailyStatsSyncFlags(
          userId: userId,
          recordDate: recordDate,
          hasBeenSynced: true, 
          editsAreSynced: true, 
        );
      } else {
        final operation = (hasBeenSynced == 0) ? 'Insert' : 'Update';
        QuizzerLogger.logWarning('$operation FAILED for UserDailyStats (User: $userId, Date: $recordDate). Local flags remain unchanged.');
      }
    }
  } catch(e) {
    QuizzerLogger.logError('syncUserDailyStats: Error - $e');
    rethrow;
  }
}

// ==========================================
// Outbound Sync - Question Answer Pair Flags
// ==========================================

/// Fetches unsynced question answer pair flags, pushes them to Supabase, and deletes them locally on success.
Future<void> syncQuestionAnswerPairFlags() async {
  try {
    // Fetch records needing sync
    final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedQuestionAnswerPairFlags();

    if (unsyncedRecords.isEmpty) {return;}

    const String tableName = 'question_answer_pair_flags';

    for (final record in unsyncedRecords) {
      final String? questionId = record['question_id'] as String?;
      final String? flagType = record['flag_type'] as String?;

      if (questionId == null || flagType == null) {
        QuizzerLogger.logError('Skipping unsynced question answer pair flag record due to missing primary key components: $record');
        continue;
      }

      // Attempt to push the record to Supabase
      final bool pushSuccess = await pushRecordToSupabase(tableName, record);

      if (pushSuccess) {
        // If Supabase push succeeds, delete the local record (sync-and-delete workflow)
        await deleteQuestionAnswerPairFlag(questionId, flagType);
      } else {
        QuizzerLogger.logWarning('Push FAILED for QuestionAnswerPairFlag (Question: $questionId, Type: $flagType). Record will remain for next sync attempt.');
      }
    }
  } catch (e) {
    QuizzerLogger.logError('syncQuestionAnswerPairFlags: Error - $e');
    rethrow;
  }
}
