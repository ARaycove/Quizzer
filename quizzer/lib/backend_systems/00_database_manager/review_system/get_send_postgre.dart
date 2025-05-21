import 'dart:convert';
import 'dart:math'; // For random selection
import 'package:supabase/supabase.dart'; // Corrected Supabase import again
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
// Added imports for local DB and hasMediaCheck
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart'; 
// ======================================================
// duplicate private helper functions here, the AI is fucking dumb and tried to use them instead of the main function in table_helper
// Like seriously, it doesn't matter how many times you tell this stupid assistant it will consistently try to rewrite existing functionality instead of just using whats already there 

// TODO Need to update the approved questions with the reviewer user_id. When a reviewer clicks approve question the question record will be deleted from the review table(s) and then added to the main question answer pairs table. Currently the qst_reviewer field is not filled at this step. Please update the approve function so that it inserts the currently logged in user_id as the qst_reviewer.

// TODO subscribe to user question functionality

// TODO badge and acheivement system needs to be built out, track question contributors and contribution by subject matter 
// - Question performance badges
// - Contribution badges

/// Encodes a Dart value into a type suitable for SQLite storage (TEXT, INTEGER, REAL, NULL).
/// Handles Strings, ints, doubles, booleans, Lists, and Maps.
/// Lists and Maps are encoded as JSON TEXT. Booleans are stored as INTEGER (1/0).
/// Throws StateError for unsupported types.
encodeValueForDB(dynamic value) {
  if (value == null) {
    return null; // Store nulls directly
  } else if (value is String || value is int || value is double) {
    return value; // Store primitives directly
  } else if (value is bool) {
    return value ? 1 : 0; // Store booleans as integers
  } else if (value is List || value is Map) {
    // Encode Lists and Maps as JSON strings
    // json.encode itself can throw if objects are not encodable, which aligns with Fail Fast.
    return json.encode(value);
  } else {
    // Fail Fast for any other type
    throw StateError('Unsupported type for database encoding: ${value.runtimeType}');
  }
}

/// Decodes a value retrieved from SQLite back into its likely Dart type.
/// Assumes that TEXT fields starting with '[' or '{' are JSON strings representing Lists/Maps.
/// Other TEXT fields are returned as Strings. INTEGER, REAL, and NULL are returned directly.
/// Does NOT automatically convert INTEGER back to boolean; callers must handle this based on context.
decodeValueFromDB(dynamic dbValue) {
  if (dbValue == null || dbValue is int || dbValue is double) {
    return dbValue; // Return nulls, integers, and doubles directly
  } else if (dbValue is String) {
    // Trim whitespace before checking brackets/braces
    final trimmedValue = dbValue.trim();
    if (trimmedValue.startsWith('[') || trimmedValue.startsWith('{')) {
      // Attempt to decode potential JSON strings
      // json.decode will throw FormatException on invalid JSON, aligning with Fail Fast.
      return json.decode(trimmedValue);
    } else {
      // Assume it's a plain string if it doesn't look like JSON
      return dbValue;
    }
  } else {
    // Should not happen with standard SQLite types (TEXT, INTEGER, REAL, NULL, BLOB)
    // BLOBs are not currently handled.
    throw StateError('Unsupported type retrieved from database: ${dbValue.runtimeType}');
  }
}


// ==========================================
// Constants
const String _newReviewTable = 'question_answer_pair_new_review';
const String _editsReviewTable = 'question_answer_pair_edits_review';
const String _mainPairsTable = 'question_answer_pairs';
const double _newReviewWeight = 0.7; // 70% chance to pick from new review table

// --- Helper for Decoding a Full Record ---
Map<String, dynamic> _decodeReviewRecord(Map<String, dynamic> rawRecord) {
  final Map<String, dynamic> decodedRecord = {};

  for (final entry in rawRecord.entries) {
    // Apply decodeValueFromDB to every value
    decodedRecord[entry.key] = decodeValueFromDB(entry.value);
  }
  return decodedRecord;
}

// --- Helper for Encoding a Full Record for Upsert ---
Map<String, dynamic> _encodeRecordForUpsert(Map<String, dynamic> decodedRecord) {
  final Map<String, dynamic> encodedRecord = {};

  for (final entry in decodedRecord.entries) {
      // Remove local flags if they somehow exist (shouldn't for review data)
      if (entry.key == 'has_been_synced' || entry.key == 'edits_are_synced') continue;

      // Apply encodeValueForDB to every value
      encodedRecord[entry.key] = encodeValueForDB(entry.value);

      // Ensure timestamp is present and valid for upsert/comparison
      // This specific check might still be needed depending on DB constraints
      if (entry.key == 'last_modified_timestamp') {
          final encodedValue = encodedRecord[entry.key]; // Get the potentially encoded value
          if (encodedValue == null || encodedValue is! String || encodedValue.isEmpty) {
             QuizzerLogger.logWarning('_encodeRecordForUpsert: Missing or invalid last_modified_timestamp. Setting to now() for upsert.');
             // Ensure it's set as a string for PostgreSQL
             encodedRecord[entry.key] = DateTime.now().toUtc().toIso8601String();
          }
      }
  }
  return encodedRecord;
}


// ==========================================
// Review System Functions
// ==========================================

/// Fetches a random question from one of the review tables with weighted preference.
///
/// Returns a Map containing:
/// - 'data': The decoded question data (Map<String, dynamic>). Null if no questions found or error.
/// - 'source_table': The name of the table the question came from (String). Null if no questions found.
/// - 'primary_key': A Map representing the primary key(s) for deletion {'column_name': value}. Null if no questions found.
/// - 'error': An error message (String) if no questions are available. Null otherwise.
Future<Map<String, dynamic>> getRandomQuestionToBeReviewed() async {
  final supabase = getSessionManager().supabase;
  final random = Random();

  // Get counts for weighting and existence check using the modern .count() method
  // Let potential PostgrestExceptions propagate (Fail Fast)
  final int newCount = await supabase
      .from(_newReviewTable)
      .count(CountOption.exact);

  final int editsCount = await supabase
      .from(_editsReviewTable)
      .count(CountOption.exact);

  final int totalCount = newCount + editsCount;

  if (totalCount == 0) {
    QuizzerLogger.logMessage('No questions available in review tables.');
    return {'data': null, 'source_table': null, 'primary_key': null, 'error': 'No questions available for review.'};
  }

  // Determine which table to pull from based on weight and availability
  String selectedTable;
  int countForSelectedTable;
  if (newCount > 0 && (editsCount == 0 || random.nextDouble() < _newReviewWeight)) {
    selectedTable = _newReviewTable;
    countForSelectedTable = newCount;
  } else if (editsCount > 0) {
    selectedTable = _editsReviewTable;
    countForSelectedTable = editsCount;
  } else {
     // Should be unreachable due to totalCount check, but defensively handle.
     QuizzerLogger.logError('Review table selection logic error. Total > 0 but individual counts are 0? New: $newCount, Edits: $editsCount');
     return {'data': null, 'source_table': null, 'primary_key': null, 'error': 'Internal error selecting review table.'};
  }

  // Fetch a random record using offset
  final int randomOffset = random.nextInt(countForSelectedTable);
  QuizzerLogger.logMessage('Fetching random record from $selectedTable (offset: $randomOffset / $countForSelectedTable)');

  final fetchResponse = await supabase
      .from(selectedTable)
      .select() // Select all columns
      .limit(1)
      .range(randomOffset, randomOffset); // Use range for offset

  // Check if response is valid and contains data
  if (fetchResponse.isEmpty) {
      QuizzerLogger.logError('Failed to fetch random record from $selectedTable at offset $randomOffset. Response was empty.');
      return {'data': null, 'source_table': null, 'primary_key': null, 'error': 'Failed to fetch question data.'};
  }

  final Map<String, dynamic> rawData = fetchResponse[0]; // Get the first (only) record
  final Map<String, dynamic> decodedData = _decodeReviewRecord(rawData);
  final String questionId = decodedData['question_id'] as String;

  // --- Perform local hasMediaCheck to trigger media sync --- 
  QuizzerLogger.logMessage('Performing hasMediaCheck for reviewed Question ID: $questionId');
  Database? db = await getDatabaseMonitor().requestDatabaseAccess();
  // Use db! directly to adhere to Fail Fast if db is unexpectedly null.
  // The hasMediaCheck function from question_answer_pairs_table will determine if media exists,
  // extract filenames, and call registerMediaFiles which in turn calls insertMediaSyncStatus.
  // insertMediaSyncStatus will then trigger the MediaSyncWorker if needed.
  await hasMediaCheck(db!, decodedData);
  getDatabaseMonitor().releaseDatabaseAccess();
  QuizzerLogger.logMessage('hasMediaCheck completed for Question ID: $questionId. DB access released.');
  // --- End hasMediaCheck --- 

  Map<String, dynamic> primaryKey;
  if (selectedTable == _newReviewTable) {
    primaryKey = {'question_id': questionId};
  } else { // Must be _editsReviewTable
    final String lastModifiedTimestamp = decodedData['last_modified_timestamp'] as String; // Assume it exists and is string
    primaryKey = {'question_id': questionId, 'last_modified_timestamp': lastModifiedTimestamp};
  }

  QuizzerLogger.logSuccess('Successfully fetched and decoded question $questionId from $selectedTable');
  return {'data': decodedData, 'source_table': selectedTable, 'primary_key': primaryKey, 'error': null};
}

/// Approves a reviewed question.
///
/// Upserts the (potentially edited) question details into the main
/// `question_answer_pairs` table and deletes the original record from its review source table.
///
/// Args:
///   questionDetails: The decoded question data map (potentially modified by admin).
///   sourceTable: The name of the review table the question came from.
///   primaryKey: The map representing the primary key(s) needed for deletion.
///
/// Returns:
///   `true` if both the upsert and delete operations succeed, `false` otherwise.
Future<bool> approveQuestion(Map<String, dynamic> questionDetails, String sourceTable, Map<String, dynamic> primaryKey) async {
  final supabase = getSessionManager().supabase;
  final String questionId = primaryKey['question_id'] as String; // Assume always present
  QuizzerLogger.logMessage('Approving question $questionId from $sourceTable...');

  // Ensure qst_contrib is populated
  if (questionDetails['qst_contrib'] == null || (questionDetails['qst_contrib'] as String).isEmpty) {
    final String? currentUserId = getSessionManager().userId;
    if (currentUserId != null && currentUserId.isNotEmpty) {
      questionDetails['qst_contrib'] = currentUserId;
      QuizzerLogger.logMessage('Populated missing qst_contrib with current userId: $currentUserId for question $questionId');
    } else {
      QuizzerLogger.logError('Critical: qst_contrib is missing and could not be populated with a valid userId for question $questionId. Aborting approval.');
      throw StateError('Cannot approve question $questionId: qst_contrib is missing and no valid session userId found.');
    }
  }

  // Set qst_reviewer to current user ID
  final String? currentUserId = getSessionManager().userId;
  if (currentUserId != null && currentUserId.isNotEmpty) {
    questionDetails['qst_reviewer'] = currentUserId;
    questionDetails['has_been_reviewed'] = 1; // Set review flag
    QuizzerLogger.logMessage('Set qst_reviewer to current userId: $currentUserId for question $questionId');
  } else {
    QuizzerLogger.logError('Critical: Could not set qst_reviewer - no valid session userId found for question $questionId. Aborting approval.');
    throw StateError('Cannot approve question $questionId: No valid session userId found for reviewer.');
  }

  // 1. Encode the data for upsert into the main table
  final String approvalTimestamp = DateTime.now().toUtc().toIso8601String();
  QuizzerLogger.logValue('Setting last_modified_timestamp to $approvalTimestamp for approval.');
  questionDetails['last_modified_timestamp'] = approvalTimestamp;
  final Map<String, dynamic> encodedPayload = _encodeRecordForUpsert(questionDetails);

  // 2. Upsert into the main question_answer_pairs table
  // Let potential PostgrestExceptions propagate (Fail Fast)
  QuizzerLogger.logValue('Upserting question $questionId into $_mainPairsTable...');
  await supabase.from(_mainPairsTable).upsert(encodedPayload, onConflict: 'question_id');
  QuizzerLogger.logSuccess('Upsert successful for question $questionId into $_mainPairsTable.');

  // 3. Delete from the source review table using the primary key map
  QuizzerLogger.logValue('Deleting approved question $questionId from $sourceTable using key: $primaryKey');
  var deleteQuery = supabase.from(sourceTable).delete();
  for (final entry in primaryKey.entries) {
      deleteQuery = deleteQuery.eq(entry.key, entry.value);
  }
  await deleteQuery; // Let potential errors propagate
  QuizzerLogger.logSuccess('Successfully deleted approved question $questionId from $sourceTable.');

  return true; // Return true indicates completion without throwing errors
}

/// Denies (deletes) a reviewed question from its source review table.
///
/// Args:
///   sourceTable: The name of the review table the question came from.
///   primaryKey: The map representing the primary key(s) needed for deletion.
///
/// Returns:
///   `true` if the delete operation succeeds, `false` otherwise (though errors usually throw).
Future<bool> denyQuestion(String sourceTable, Map<String, dynamic> primaryKey) async {
  final supabase = getSessionManager().supabase;
  final String questionId = primaryKey['question_id'] as String; // Log purposes
  QuizzerLogger.logMessage('Denying question $questionId from $sourceTable...');

  // Delete from the source review table using the primary key map
  QuizzerLogger.logValue('Deleting denied question $questionId from $sourceTable using key: $primaryKey');
  var deleteQuery = supabase.from(sourceTable).delete();
  for (final entry in primaryKey.entries) {
      deleteQuery = deleteQuery.eq(entry.key, entry.value);
  }
  await deleteQuery; // Let potential errors propagate
  QuizzerLogger.logSuccess('Successfully deleted denied question $questionId from $sourceTable.');

  return true; // Return true indicates completion without throwing errors
}
