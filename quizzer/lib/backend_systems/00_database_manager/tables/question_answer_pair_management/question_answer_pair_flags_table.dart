import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/09_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';

// Fields
// question_id | flag_type | flag_description |
// question_id is a foreign key pointing to the question_id in the question_answer_pair_table
// flag_type is TEXT, but will be defined as a list of types some starting types ["unclear explanation", "non-sensical", "inappropriate reason*", "nudity", "gore", "etc'"]
// flag_description is the text content of the report

// This records in this table will be synced outbound to the supabase server, then removed, this data is only stored locally as temporary storage until it's synced, so no upsertFromSupabase function is necessary
// [x] Define Supabase Table
// [x] add permissions enums
// [x] update permissions table
// [x] Define Supabase RLS
// [x] Connect to outbound sync worker
// [x] Do not connect to inbound sync worker
// [x] Update SessionManager API to add
// [x] Ensure that table calls outbound sync needed signal
// [x] Flagging a question should mark the local question as flagged
// [x] flagged questions should not be eligible to be shown until they are resynced with a non-zero flag

// [x] flagged questions should be unflagged after they have been reviewed by an admin (Wait how do we address that?) Probably write an edge function that edits the user_quesiton_answer_pair on the server, then it'll be updated when they next login and sync

// [x] A review call to get a flagged record

// [x] An review call that sends an update (this is the edge function, this call will use the edge function)

// [x] Review call that handles both edit and delete scenarios

// ==========================================
// Question Answer Pair Flags Table
// ==========================================

// Valid flag types - enum-like list
const List<String> validFlagTypes = [
  'factually_incorrect',
  'misleading_information',
  'outdated_content',
  'biased_perspective',
  'confusing_answer_explanation',
  'incorrect_answer',
  'confusing_question',
  'grammar_spelling_errors',
  'violent_content',
  'sexual_content',
  'hate_speech',
  'duplicate_question',
  'poor_quality_image',
  'broken_media',
  'copyright_violation',
  'other'
];

// Table name and field constants
const String questionAnswerPairFlagsTableName = 'question_answer_pair_flags';
const String questionIdField = 'question_id';
const String flagTypeField = 'flag_type';
const String flagDescriptionField = 'flag_description';

// Create table SQL
const String createQuestionAnswerPairFlagsTableSQL = '''
  CREATE TABLE IF NOT EXISTS $questionAnswerPairFlagsTableName (
    $questionIdField TEXT NOT NULL,
    $flagTypeField TEXT NOT NULL,
    $flagDescriptionField TEXT,
    -- Sync Fields --
    has_been_synced INTEGER DEFAULT 0,
    edits_are_synced INTEGER DEFAULT 0,
    last_modified_timestamp TEXT,
    -- ------------- --
    PRIMARY KEY ($questionIdField, $flagTypeField)
  )
''';

// Verify table exists and create if needed
Future<void> verifyQuestionAnswerPairFlagsTable(dynamic db) async {
  QuizzerLogger.logMessage('Verifying $questionAnswerPairFlagsTableName table existence');
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='$questionAnswerPairFlagsTableName'"
  );
  
  if (tables.isEmpty) {
    QuizzerLogger.logMessage('$questionAnswerPairFlagsTableName table does not exist, creating it');
    await db.execute(createQuestionAnswerPairFlagsTableSQL);
    QuizzerLogger.logSuccess('$questionAnswerPairFlagsTableName table created successfully');
  } else {
    QuizzerLogger.logMessage('$questionAnswerPairFlagsTableName table exists');
  }
}

// ==========================================
// Validation Functions
// ==========================================

/// Validates flag data before insertion
Future<void> _validateFlagData({
  required String questionId,
  required String flagType,
  required String flagDescription,
}) async {
  // Validate flag type
  if (!validFlagTypes.contains(flagType)) {
    QuizzerLogger.logError('Invalid flag type: $flagType. Valid types are: ${validFlagTypes.join(', ')}');
    throw StateError('Invalid flag type: $flagType. Valid types are: ${validFlagTypes.join(', ')}');
  }
  
  // Validate flag description is not empty
  if (flagDescription.trim().isEmpty) {
    QuizzerLogger.logError('Flag description cannot be empty');
    throw StateError('Flag description cannot be empty');
  }
  
  // Validate question exists in question_answer_pairs table
  final db = await getDatabaseMonitor().requestDatabaseAccess();
  if (db == null) {
    throw Exception('Failed to acquire database access');
  }
  
  try {
    await verifyQuestionAnswerPairTable(db);
    final List<Map<String, dynamic>> results = await db.query(
      'question_answer_pairs',
      where: 'question_id = ?',
      whereArgs: [questionId],
    );
    
    if (results.isEmpty) {
      QuizzerLogger.logError('Question ID does not exist: $questionId');
      throw StateError('Question ID does not exist: $questionId');
    }
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// ==========================================
// CRUD Operations
// ==========================================

/// Adds a new flag for a question answer pair
Future<int> addQuestionAnswerPairFlag({
  required String questionId,
  required String flagType,
  required String flagDescription,
}) async {
  // [x] Write unit test for this function:
  try {
    // Validate all input data first
    await _validateFlagData(
      questionId: questionId,
      flagType: flagType,
      flagDescription: flagDescription,
    );
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Adding flag for question: $questionId, type: $flagType');
    // Prepare raw data map
    final Map<String, dynamic> data = {
      'question_id': questionId,
      'flag_type': flagType,
      'flag_description': flagDescription,
      // Sync Fields
      'has_been_synced': 0,
      'edits_are_synced': 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    // Use universal insert helper
    final int result = await insertRawData(
      questionAnswerPairFlagsTableName,
      data,
      db,
    );

    // Log success/failure based on result
    if (result > 0) {
      QuizzerLogger.logSuccess('Added flag for question: $questionId, type: $flagType');
      // Signal SwitchBoard
      signalOutboundSyncNeeded();
    } else {
      QuizzerLogger.logError('Insert operation for flag (question: $questionId, type: $flagType) returned $result.');
      throw StateError('Failed to insert flag for question: $questionId, type: $flagType');
    }
    return result;
  } catch (e) {
    QuizzerLogger.logError('Error adding question answer pair flag - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Note: This table does not include edit or individual fetch operations because:
// 1. Flags are temporary local records that get synced to server and then removed
// 2. Once a flag is created, it should not be modified locally
// 3. Individual flag retrieval is not needed for the sync workflow
// 4. The only operations needed are: add, bulk fetch for sync, and delete after sync



/// Gets all flags that haven't been synced yet
Future<List<Map<String, dynamic>>> getUnsyncedQuestionAnswerPairFlags() async {
  // [x] Write unit tests for this function
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    } 
    // Use universal query helper
    return await queryAndDecodeDatabase(
      questionAnswerPairFlagsTableName,
      db,
      where: 'has_been_synced = 0',
    );
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced question answer pair flags - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Deletes a specific flag
Future<int> deleteQuestionAnswerPairFlag(String questionId, String flagType) async {
  // Set Up:
  // Clear Table

  // Test 1:
  // - use invalid questionId
  // expect failure
  
  // Test 2:
  // - use invalid flagType
  // expect failure

  // Test 3:
  // - get 5 random question_ids from question_answer_pair table
  // - add records for each
  // - call delete with valid id but invalid flag
  // - expect failure

  // test 4:
  // - call delete with invalidId but valid flag
  // - expect failures

  // Test 5:
  // - call delete for each record with valid arguments
  // - expect empty table

  // Clean Up:
  // clean up was performed by Test 3 if successful
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Deleting flag for question: $questionId, type: $flagType');
    final int result = await db.delete(
      questionAnswerPairFlagsTableName,
      where: 'question_id = ? AND flag_type = ?',
      whereArgs: [questionId, flagType],
    );

    if (result > 0) {
      QuizzerLogger.logSuccess('Deleted flag for question: $questionId, type: $flagType ($result row affected).');
      signalOutboundSyncNeeded();
    } else {
      QuizzerLogger.logWarning('Delete operation for flag (question: $questionId, type: $flagType) affected 0 rows. Record might not exist.');
    }
    return result;
  } catch (e) {
    QuizzerLogger.logError('Error deleting question answer pair flag - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}



