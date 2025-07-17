import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'get_send_postgre.dart' show encodeValueForDB, decodeValueFromDB;

// ==========================================
// Constants
const String _subjectDetailsTable = 'subject_details';

// ==========================================
// Subject Review Functions
// ==========================================

/// Fetches a single subject_details record for review.
///
/// Criteria for review:
/// - subject_description is null, OR
/// - last_modified_timestamp is older than 3 months
///
/// Returns a Map containing:
/// - 'data': The decoded subject data (Map<String, dynamic>). Null if no subjects found or error.
/// - 'primary_key': A Map representing the primary key {'subject': value}. Null if no subjects found.
/// - 'error': An error message (String) if no subjects are available. Null otherwise.
Future<Map<String, dynamic>> getSubjectForReview() async {
  final supabase = getSessionManager().supabase;
  
  // Calculate the cutoff date (3 months ago)
  final DateTime threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
  final String cutoffTimestamp = threeMonthsAgo.toUtc().toIso8601String();
  
  QuizzerLogger.logMessage('Fetching subject for review. Cutoff timestamp: $cutoffTimestamp');

  try {
    // Query for subjects that need review
    final response = await supabase
        .from(_subjectDetailsTable)
        .select()
        .or('subject_description.is.null,last_modified_timestamp.lt.$cutoffTimestamp')
        .limit(1);

    if (response.isEmpty) {
      QuizzerLogger.logMessage('No subjects available for review.');
      return {
        'data': null, 
        'primary_key': null, 
        'error': 'No subjects available for review.'
      };
    }

    final Map<String, dynamic> rawData = response[0];
    final Map<String, dynamic> decodedData = _decodeSubjectRecord(rawData);
    final String subject = decodedData['subject'] as String;

    final Map<String, dynamic> primaryKey = {'subject': subject};

    QuizzerLogger.logSuccess('Successfully fetched subject "$subject" for review');
    return {
      'data': decodedData, 
      'primary_key': primaryKey, 
      'error': null
    };

  } catch (e) {
    QuizzerLogger.logError('Error fetching subject for review: $e');
    return {
      'data': null, 
      'primary_key': null, 
      'error': 'Failed to fetch subject data: $e'
    };
  }
}

/// Updates a reviewed subject_details record.
///
/// Args:
///   subjectDetails: The decoded subject data map (potentially modified by admin).
///   primaryKey: The map representing the primary key {'subject': value}.
///
/// Returns:
///   `true` if the update operation succeeds, `false` otherwise.
Future<bool> updateReviewedSubject(Map<String, dynamic> subjectDetails, Map<String, dynamic> primaryKey) async {
  final supabase = getSessionManager().supabase;
  final String subject = primaryKey['subject'] as String;
  
  QuizzerLogger.logMessage('Updating reviewed subject "$subject"...');

  try {
    // Set the current timestamp
    final String updateTimestamp = DateTime.now().toUtc().toIso8601String();
    subjectDetails['last_modified_timestamp'] = updateTimestamp;

    // Encode the data for update
    final Map<String, dynamic> encodedPayload = {};
    for (final entry in subjectDetails.entries) {
      encodedPayload[entry.key] = encodeValueForDB(entry.value);
    }

    // Update the subject_details table
    await supabase
        .from(_subjectDetailsTable)
        .update(encodedPayload)
        .eq('subject', subject);

    QuizzerLogger.logSuccess('Successfully updated subject "$subject"');
    return true;

  } catch (e) {
    QuizzerLogger.logError('Error updating subject "$subject": $e');
    return false;
  }
}

// --- Helper for Decoding a Full Record ---
Map<String, dynamic> _decodeSubjectRecord(Map<String, dynamic> rawRecord) {
  final Map<String, dynamic> decodedRecord = {};

  for (final entry in rawRecord.entries) {
    // Apply decodeValueFromDB to every value
    decodedRecord[entry.key] = decodeValueFromDB(entry.value);
  }
  return decodedRecord;
}
