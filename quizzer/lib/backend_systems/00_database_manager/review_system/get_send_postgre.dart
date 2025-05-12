import 'dart:math'; // For random selection
import 'package:supabase/supabase.dart'; // Corrected Supabase import again
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/00_table_helper.dart'; // For encode/decode

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
