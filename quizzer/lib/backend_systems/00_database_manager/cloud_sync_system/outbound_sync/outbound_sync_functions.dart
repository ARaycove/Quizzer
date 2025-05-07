import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // To get Supabase client
import 'package:sqflite/sqflite.dart'; // Import for Database type
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart'; // Import for table functions
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Import Logger
import 'package:supabase/supabase.dart'; // Import for PostgrestException & SupabaseClient

// ==========================================
// Outbound Sync - Generic Push Function

/// Attempts to push a single record to a specified Supabase table using upsert.
/// Returns true if the upsert operation completes without error, false otherwise.
Future<bool> pushRecordToSupabase(String tableName, Map<String, dynamic> recordData) async {
  // USE SESSION MANAGER FOR ACCESS TO SUPABASE
  final questionId = recordData['question_id'] as String?; 
  if (questionId == null) {
    QuizzerLogger.logError('pushRecordToSupabase: Missing question_id in recordData.');
    return false; // Cannot proceed without an ID
  }

  QuizzerLogger.logMessage('Attempting Supabase upsert for QID $questionId to table $tableName...');

  try {
    // 1. Get Supabase client
    final supabase = getSessionManager().supabase;

    // 2. Prepare payload (remove local-only fields, ensure type compatibility)
    Map<String, dynamic> payload = Map.from(recordData);
    payload.remove('has_been_synced');
    payload.remove('edits_are_synced');

    // 3. Perform Upsert based on the question_id
    // This will insert if question_id doesn't exist, or update if it does.
    // TEMPORARY TEST: Use insert instead of upsert
    await supabase
      .from(tableName)
      .insert(payload); // Ensure 'question_id' is the unique column for conflict resolution

    QuizzerLogger.logSuccess('Supabase upsert presumed successful for QID $questionId to $tableName.');
    return true; // Assume success if no exception is thrown

  } on PostgrestException catch (e) {
     // Catch specific Supabase errors
     QuizzerLogger.logError('Supabase PostgrestException during push for QID $questionId to $tableName: ${e.message} (Code: ${e.code})');
     return false;
  } catch (e) {
    // Catch potential network errors or other client errors
    QuizzerLogger.logError('Supabase upsert FAILED for QID $questionId to $tableName: $e');
    return false; // Indicate failure
  }
}

// ==========================================
// Outbound Sync - Table-Specific Functions
// ==========================================

// FIXME, if synced question answer pair has image elements, these need to be pushed to SupaBase as well without this extra logic a file name with no file will be sent out, need to also send the file that goes with the question answer pair
// TODO Implement a separate service that handles the syncing of images based on the specific questions that a user has locally active (ensuring we only sync images that are relevant for questions currently in circulation)

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

// Add functions for other tables (e.g., syncModules, syncUserProfiles) here...
