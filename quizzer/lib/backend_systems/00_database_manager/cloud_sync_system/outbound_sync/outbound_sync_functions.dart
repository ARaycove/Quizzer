import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // To get Supabase client
import 'package:sqflite/sqflite.dart'; // Import for Database type
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart'; // Import for table functions
import 'package:quizzer/backend_systems/00_database_manager/tables/login_attempts_table.dart'; // Import for login attempts table functions
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_attempts_table.dart'; // Import for attempt table functions
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart'; // Import for user profile table functions
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart'; // Import for UserQuestionAnswerPairs table functions
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Import Logger
import 'package:supabase/supabase.dart'; // Import for PostgrestException & SupabaseClient
import 'package:quizzer/backend_systems/00_database_manager/tables/error_logs_table.dart'; // Added for syncErrorLogs
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_settings_table.dart'; // Added for user settings table
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';

// ==========================================
// Outbound Sync - Generic Push Function

/// Attempts to push a single record to a specified Supabase table using upsert.
/// Returns true if the upsert operation completes without error, false otherwise.
Future<bool> pushRecordToSupabase(String tableName, Map<String, dynamic> recordData) async {
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

  if (recordData.containsKey('question_id')) {
    recordIdForLog = recordData['question_id'] as String? ?? recordIdForLog;
  } else if (recordData.containsKey('uuid')) { // Often a primary user or record ID
    recordIdForLog = recordData['uuid'] as String? ?? recordIdForLog;
  } else if (recordData.containsKey('login_attempt_id')) {
    recordIdForLog = recordData['login_attempt_id'] as String? ?? recordIdForLog;
  } else if (recordData.containsKey('participant_id')) { // For question_answer_attempts, this is part of a composite key
    recordIdForLog = recordData['participant_id'] as String? ?? recordIdForLog;
    if (recordData.containsKey('question_id') && recordData.containsKey('time_stamp')) {
        recordIdForLog += "-${recordData['question_id']}-${recordData['time_stamp']}";
    }
  }

  QuizzerLogger.logMessage('Attempting Supabase insert for record $recordIdForLog to table $tableName...');

  try {
    // 1. Get Supabase client
    final supabase = getSessionManager().supabase;

    // 2. Prepare payload (remove local-only fields, ensure type compatibility)
    Map<String, dynamic> payload = Map.from(recordData);
    payload.remove('has_been_synced');
    payload.remove('edits_are_synced');

    // Check for Infinity values and replace with 1
    payload.forEach((key, value) {
      if (value is double && value.isInfinite) {
        payload[key] = 1.0;
      }
    });

    // --- BEGIN NEW LOGGING FOR USER_SETTINGS PAYLOAD ---
    if (tableName == 'user_settings') {
      QuizzerLogger.logValue('Pushing to user_settings. Payload: $payload');
    }
    // --- END NEW LOGGING FOR USER_SETTINGS PAYLOAD ---

    // 3. Perform Insert
    await supabase
      .from(tableName)
      .insert(payload);

    QuizzerLogger.logSuccess('Supabase insert successful for record $recordIdForLog to $tableName.');
    return true; // Assume success if no exception is thrown

  } on PostgrestException catch (e) {
     // Catch specific Supabase errors
     QuizzerLogger.logError('Supabase PostgrestException during push for record $recordIdForLog to $tableName: ${e.message} (Code: ${e.code})');
     // --- BEGIN NEW LOGGING ON FAILURE ---
     final SessionManager sessionManager = getSessionManager();
     QuizzerLogger.logValue('Failed Push Context: SessionManager User ID: ${sessionManager.userId}');
     QuizzerLogger.logValue('Failed Push Context: Session Token: ${sessionManager.supabase.auth.currentSession?.accessToken}');
     // --- END NEW LOGGING ON FAILURE ---
     return false;
  } catch (e) {
    // Catch potential network errors or other client errors
    QuizzerLogger.logError('Supabase insert FAILED for record $recordIdForLog to $tableName: $e');
    // --- BEGIN NEW LOGGING ON FAILURE ---
    final SessionManager sessionManager = getSessionManager();
    QuizzerLogger.logValue('Failed Push Context: SessionManager User ID: ${sessionManager.userId}');
    QuizzerLogger.logValue('Failed Push Context: Session Token: ${sessionManager.supabase.auth.currentSession?.accessToken}');
    // --- END NEW LOGGING ON FAILURE ---
    return false; // Indicate failure
  }
}

// ==========================================
// Outbound Sync - Generic Update Function

/// Attempts to update a single existing record in a specified Supabase table.
/// Matches the record based on the provided primary key column and value.
/// Returns true if the update operation completes without error, false otherwise.
Future<bool> updateRecordInSupabase(String tableName, Map<String, dynamic> recordData, {required String primaryKeyColumn, required dynamic primaryKeyValue}) async {
  // USE SESSION MANAGER FOR ACCESS TO SUPABASE
  QuizzerLogger.logMessage('Attempting Supabase update for ID $primaryKeyValue in table $tableName...');

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

    QuizzerLogger.logSuccess('Supabase update presumed successful for ID $primaryKeyValue in $tableName.');
    return true; // Assume success if no exception is thrown

  } on PostgrestException catch (e) {
     // Catch specific Supabase errors
     QuizzerLogger.logError('Supabase PostgrestException during update for ID $primaryKeyValue in $tableName: ${e.message} (Code: ${e.code})');
     return false;
  } catch (e) {
    // Catch potential network errors or other client errors
    QuizzerLogger.logError('Supabase update FAILED for ID $primaryKeyValue in $tableName: $e');
    return false; // Indicate failure
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
  final String filterLog = compositeKeyFilters.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  QuizzerLogger.logMessage('Attempting Supabase update with composite key for record matching ($filterLog) in table $tableName...');

  try {
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
    QuizzerLogger.logError('Supabase PostgrestException during composite key update for ($filterLog) in $tableName: ${e.message} (Code: ${e.code})');
    return false;
  } catch (e) {
    QuizzerLogger.logError('Supabase update with composite key FAILED for ($filterLog) in $tableName: $e');
    return false;
  }
}

// ==========================================
// Outbound Sync - Table-Specific Functions
// ==========================================

/// Fetches unsynced question-answer pairs and attempts to push them.
Future<void> syncQuestionAnswerPairs(Database db) async {
  QuizzerLogger.logMessage('Starting sync for QuestionAnswerPairs...');

  // Fetch records needing sync
  final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedQuestionAnswerPairs(db);

  if (unsyncedRecords.isEmpty) {
    QuizzerLogger.logMessage('No unsynced QuestionAnswerPairs found.');
    return;
  }

  QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced QuestionAnswerPairs.');

  // Process each record
  for (final record in unsyncedRecords) {
    final questionId = record['question_id'] as String; // Assume non-null
    final hasBeenSynced = record['has_been_synced'] as int;

    // Ensure last_modified_timestamp is populated (UTC ISO8601)
    if (record['last_modified_timestamp'] == null || (record['last_modified_timestamp'] is String && (record['last_modified_timestamp'] as String).isEmpty)) {
      QuizzerLogger.logMessage('QID $questionId is missing last_modified_timestamp. Setting to current UTC time.');
      record['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();
    }

    String targetTable;
    bool newHasBeenSynced = false;
    bool newEditsAreSynced = false;

    // Determine target table and target flag states
    if (hasBeenSynced == 0) {
      targetTable = 'question_answer_pair_new_review';
      // If push succeeds, both flags will become true (1)
      newHasBeenSynced = true;
      newEditsAreSynced = true;
    } else {
      targetTable = 'question_answer_pair_edits_review';
      // If push succeeds, has_been_synced stays true (1), only edits_are_synced becomes true (1)
      newHasBeenSynced = true; // Stays true
      newEditsAreSynced = true;
    }

    QuizzerLogger.logValue('Preparing to push QID $questionId to $targetTable');

    // Attempt to push the record
    final bool pushSuccess = await pushRecordToSupabase(targetTable, record);

    // If push was successful, update local flags
    if (pushSuccess) {
      QuizzerLogger.logMessage('Push successful for QID $questionId. Updating local flags...');
      await updateQuestionSyncFlags(
        questionId: questionId,
        hasBeenSynced: newHasBeenSynced,
        editsAreSynced: newEditsAreSynced,
        db: db,
      );
    } else {
      QuizzerLogger.logWarning('Push FAILED for QID $questionId. Local flags remain unchanged.');
    }
  }

  QuizzerLogger.logMessage('Finished sync attempt for QuestionAnswerPairs.');
}

/// Fetches unsynced login attempts, pushes them to Supabase, and deletes locally on success.
Future<void> syncLoginAttempts(Database db) async {
  QuizzerLogger.logMessage('Starting sync for LoginAttempts...');

  // Fetch records needing sync - Remove try-catch, let DB errors propagate
  final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedLoginAttempts(db);

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
      await deleteLoginAttemptRecord(loginAttemptId, db);

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
}

/// Fetches unsynced question answer attempts, pushes them to Supabase, and updates local flags on success.
Future<void> syncQuestionAnswerAttempts(Database database) async {
  QuizzerLogger.logMessage('Starting sync for QuestionAnswerAttempts...');

  // Fetch records needing sync
  final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedQuestionAnswerAttempts(database);

  if (unsyncedRecords.isEmpty) {
    QuizzerLogger.logMessage('No unsynced QuestionAnswerAttempts found.');
    return;
  }

  QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced QuestionAnswerAttempts.');

  final supabaseClient = getSessionManager().supabase;
  const String tableName = 'question_answer_attempts';

  for (final record in unsyncedRecords) {
    // Extract primary key components
    final String participantId = record['participant_id'] as String;
    final String questionId = record['question_id'] as String;
    final String timeStamp = record['time_stamp'] as String;

    // Basic validation of primary key components
    if (participantId.isEmpty || questionId.isEmpty || timeStamp.isEmpty) {
      QuizzerLogger.logError('Skipping unsynced attempt record due to missing primary key components: $record');
      continue;
    }

    // Prepare payload (remove local-only flags)
    Map<String, dynamic> payload = Map.from(record);
    payload.remove('has_been_synced');
    payload.remove('edits_are_synced');

    QuizzerLogger.logValue('Preparing to push Attempt (participant_id: $participantId, question_id: $questionId, time_stamp: $timeStamp) to $tableName');

    // Use try-catch ONLY for the Supabase call
    try {
      // Attempt to insert the record into Supabase
      await supabaseClient.from(tableName).insert(payload);

      QuizzerLogger.logSuccess('Supabase insert successful for Attempt (participant_id: $participantId, question_id: $questionId, time_stamp: $timeStamp).');

      // If Supabase insert succeeds, delete the local record
      await deleteQuestionAnswerAttemptRecord(participantId, questionId, timeStamp, database);

    } on PostgrestException catch (exception) {
      QuizzerLogger.logError('Supabase PostgrestException during insert for Attempt (participant_id: $participantId, question_id: $questionId, time_stamp: $timeStamp): ${exception.message} (Code: ${exception.code})');
      // Do not delete local record if push failed
    } catch (exception) {
      QuizzerLogger.logError('Supabase insert FAILED for Attempt (participant_id: $participantId, question_id: $questionId, time_stamp: $timeStamp): $exception');
      // Do not delete local record if push failed
    }
  }

  QuizzerLogger.logMessage('Finished sync attempt for QuestionAnswerAttempts.');
}

/// Fetches unsynced user profiles, pushes new ones or updates existing ones, and updates local flags on success.
Future<void> syncUserProfiles(Database db) async {
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
  final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserProfiles(db, currentUserId);

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
        db: db,
      );
    } else {
      final operation = (hasBeenSynced == 0) ? 'Insert' : 'Update';
      QuizzerLogger.logWarning('$operation FAILED for UserProfile $userId. Local flags remain unchanged.');
    }
  }

  QuizzerLogger.logMessage('Finished sync attempt for UserProfiles.');
}

// Add functions for other tables (e.g., syncModules) here...
// --- Sync UserQuestionAnswerPairs ---

/// Fetches unsynced user_question_answer_pairs for the current user,
/// pushes new ones or updates existing ones (with server version check),
/// and updates local sync flags.
Future<void> syncUserQuestionAnswerPairs(Database db) async {
  QuizzerLogger.logMessage('Starting sync for UserQuestionAnswerPairs...');

  final SessionManager sessionManager = getSessionManager();
  if (sessionManager.userId == null) {return;}
  final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserQuestionAnswerPairs(db, sessionManager.userId!);

  if (unsyncedRecords.isEmpty) {
    QuizzerLogger.logMessage('No unsynced UserQuestionAnswerPairs found for user $sessionManager.userId!.');
    return;
  }

  QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced UserQuestionAnswerPairs for user $sessionManager.userId!.');

  const String tableName = 'user_question_answer_pairs';
  // Define composite key fields for this table
  const String pkUserUuid = 'user_uuid';
  const String pkQuestionId = 'question_id';

  // --- Utility: Sanitize Infinity values in a record ---
  void sanitizeInfinityValues(Map<String, dynamic> record) {
    record.forEach((key, value) {
      if (value is double && value.isInfinite) {
        record[key] = 1.0;
      }
    });
  }

  for (final localRecordImmutable in unsyncedRecords) { // Renamed to indicate it's immutable initially
    // Create a mutable copy
    final Map<String, dynamic> localRecord = Map<String, dynamic>.from(localRecordImmutable);

    // Sanitize Infinity values before any push/update
    sanitizeInfinityValues(localRecord);

    // Now use 'localRecord' for all subsequent operations in the loop
    final String userUuidFromRecord = localRecord[pkUserUuid] as String;
    final String questionIdFromRecord = localRecord[pkQuestionId] as String;
    
    // Ensure the record actually belongs to the current user (should be guaranteed by getUnsynced... but double check)
    if (userUuidFromRecord != sessionManager.userId!) {
        QuizzerLogger.logWarning('syncUserQuestionAnswerPairs: Skipping record not belonging to current user. User in record: $userUuidFromRecord, Current User: ${sessionManager.userId}');
        continue;
    }

    // Ensure last_modified_timestamp exists in the record map before push
    if (localRecord['last_modified_timestamp'] == null || (localRecord['last_modified_timestamp'] is String && (localRecord['last_modified_timestamp'] as String).isEmpty)) {
      QuizzerLogger.logWarning('syncUserQuestionAnswerPairs: Local record (User: $userUuidFromRecord, QID: $questionIdFromRecord) missing last_modified_timestamp. Assigning current time for push.');
      localRecord['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String(); // Update in-memory mutable map for the push
    }
    // Re-parse localLastModified for comparison logic if it was potentially updated, or ensure it was parsed initially
    final DateTime localLastModified = DateTime.parse(localRecord['last_modified_timestamp'] as String);

    bool operationSuccess = false;
    Map<String, dynamic> compositeKey = {pkUserUuid: userUuidFromRecord, pkQuestionId: questionIdFromRecord};

    if (localRecord['has_been_synced'] == 0) {
      // New record, attempt to insert
      QuizzerLogger.logMessage('syncUserQuestionAnswerPairs: Preparing to insert (User: $userUuidFromRecord, QID: $questionIdFromRecord)');
      operationSuccess = await pushRecordToSupabase(tableName, localRecord);
    } else {
      // Existing record with local edits, check server version before updating
      QuizzerLogger.logMessage('syncUserQuestionAnswerPairs: Checking server version for (User: $userUuidFromRecord, QID: $questionIdFromRecord) before updating...');
      try {
        final serverResponse = await sessionManager.supabase
            .from(tableName)
            .select('last_modified_timestamp') // Only need this field for comparison
            .eq(pkUserUuid, userUuidFromRecord)      // Filter by user_uuid
            .eq(pkQuestionId, questionIdFromRecord) // Filter by question_id
            .maybeSingle();

        if (serverResponse == null) {
          QuizzerLogger.logWarning('syncUserQuestionAnswerPairs: Record (User: $userUuidFromRecord, QID: $questionIdFromRecord) not found on server (maybe deleted). Re-inserting.');
          operationSuccess = await pushRecordToSupabase(tableName, localRecord);
        } else {
          final serverRecordMap = serverResponse;
          final String? serverLastModifiedStr = serverRecordMap['last_modified_timestamp'] as String?;

          if (serverLastModifiedStr == null) {
            QuizzerLogger.logWarning('syncUserQuestionAnswerPairs: Server record (User: $userUuidFromRecord, QID: $questionIdFromRecord) missing last_modified_timestamp. Overwriting.');
            operationSuccess = await updateRecordWithCompositeKeyInSupabase(tableName, localRecord, compositeKeyFilters: compositeKey);
          } else {
            final DateTime serverLastModified = DateTime.parse(serverLastModifiedStr);
            if (localLastModified.isAfter(serverLastModified)) {
              QuizzerLogger.logMessage('syncUserQuestionAnswerPairs: Local (User: $userUuidFromRecord, QID: $questionIdFromRecord) is newer. Proceeding with update.');
              operationSuccess = await updateRecordWithCompositeKeyInSupabase(tableName, localRecord, compositeKeyFilters: compositeKey);
            } else {
              QuizzerLogger.logMessage('syncUserQuestionAnswerPairs: Server version of (User: $userUuidFromRecord, QID: $questionIdFromRecord) is newer or same. Local changes will be overwritten by next inbound sync. Skipping push.');
              operationSuccess = true; // Mark as success for this item's sync cycle (intentionally skipped)
            }
          }
        }
      } catch (e) {
        QuizzerLogger.logError('syncUserQuestionAnswerPairs: Error fetching/comparing server record (User: $userUuidFromRecord, QID: $questionIdFromRecord): $e');
        operationSuccess = false;
      }
    }

    if (operationSuccess) {
      QuizzerLogger.logMessage('syncUserQuestionAnswerPairs: Operation successful for (User: $userUuidFromRecord, QID: $questionIdFromRecord). Updating local flags...');
      await updateUserQuestionAnswerPairSyncFlags(
        userUuid:   userUuidFromRecord,
        questionId: questionIdFromRecord,
        hasBeenSynced: true,
        editsAreSynced: true, // Both true after a successful push/update or intentional skip
        db: db,
      );
    } else {
      QuizzerLogger.logWarning('syncUserQuestionAnswerPairs: Operation FAILED for (User: $userUuidFromRecord, QID: $questionIdFromRecord). Local flags remain unchanged.');
    }
  }
  QuizzerLogger.logMessage('Finished sync attempt for UserQuestionAnswerPairs.');
}

/// Fetches unsynced modules, pushes them to Supabase, and updates local flags on success.
Future<void> syncModules(Database db) async {
  QuizzerLogger.logMessage('Starting sync for Modules...');

  // Fetch records needing sync
  final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedModules(db);

  if (unsyncedRecords.isEmpty) {
    QuizzerLogger.logMessage('No unsynced Modules found.');
    return;
  }

  QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced Modules.');

  const String tableName = 'modules';
  const String primaryKey = 'module_name';

  for (final record in unsyncedRecords) {
    final String? moduleName = record[primaryKey] as String?;
    final int hasBeenSynced = record['has_been_synced'] as int? ?? 0;

    if (moduleName == null) {
      QuizzerLogger.logError('Skipping unsynced module record due to missing module_name: $record');
      continue;
    }

    // Ensure creation_date is a UTC ISO8601 string
    dynamic creationDate = record['creation_date'];
    if (creationDate is int) {
      creationDate = DateTime.fromMillisecondsSinceEpoch(creationDate).toUtc().toIso8601String();
    }
    final Map<String, dynamic> syncPayload = {
      'module_name': record['module_name'],
      'description': record['description'],
      'creation_date': creationDate,
      'creator_id': record['creator_id'],
      'last_modified_timestamp': record['last_modified_timestamp'] ?? DateTime.now().toUtc().toIso8601String()
    };

    bool operationSuccess = false;

    if (hasBeenSynced == 0) {
      // New record, use insert
      QuizzerLogger.logValue('Preparing to insert Module $moduleName into $tableName');
      operationSuccess = await pushRecordToSupabase(tableName, syncPayload);
    } else {
      // Existing record with edits, use update
      QuizzerLogger.logValue('Preparing to update Module $moduleName in $tableName');
      operationSuccess = await updateRecordInSupabase(
        tableName,
        syncPayload,
        primaryKeyColumn: primaryKey,
        primaryKeyValue: moduleName,
      );
    }

    if (operationSuccess) {
      final operation = (hasBeenSynced == 0) ? 'Insert' : 'Update';
      QuizzerLogger.logMessage('$operation successful for Module $moduleName. Updating local flags...');
      await updateModuleSyncFlags(
        moduleName: moduleName,
        hasBeenSynced: true,
        editsAreSynced: true,
        db: db,
      );
    } else {
      final operation = (hasBeenSynced == 0) ? 'Insert' : 'Update';
      QuizzerLogger.logWarning('$operation FAILED for Module $moduleName. Local flags remain unchanged.');
    }
  }

  QuizzerLogger.logMessage('Finished sync attempt for Modules.');
}

/// Fetches unsynced error logs, pushes them to Supabase, and deletes them locally on success.
Future<void> syncErrorLogs(Database db) async {
  QuizzerLogger.logMessage('Starting sync for ErrorLogs...');

  // Fetch records needing sync (already filters for older than 1 hour)
  final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedErrorLogs(db);

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
      await deleteLocalErrorLog(recordId, db);
    } else {
      QuizzerLogger.logWarning('Push FAILED for ErrorLog $recordId. Local record will remain for next sync attempt.');
    }
  }
  QuizzerLogger.logMessage('Finished sync attempt for ErrorLogs.');
}

// ==========================================
// Outbound Sync - User Settings
// ==========================================

/// Fetches unsynced user settings for the current user, pushes new ones or updates existing ones,
/// and updates local sync flags on success.
Future<void> syncUserSettings(Database db) async {
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
  final List<Map<String, dynamic>> unsyncedRecords = await getUnsyncedUserSettings(currentUserId, db); // from user_settings_table.dart

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
        db: db,
      );
    } else {
      final operation = (hasBeenSynced == 0) ? 'Insert' : 'Update';
      QuizzerLogger.logWarning('$operation FAILED for UserSetting (User: $userId, Setting: $settingName). Local flags remain unchanged.');
    }
  }

  QuizzerLogger.logMessage('Finished sync attempt for UserSettings.');
}
