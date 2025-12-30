import 'dart:math';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/06_question_answer_pair_management/question_validator.dart';
import 'package:supabase/supabase.dart'; // Corrected Supabase import again
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart' show encodeValueForDB, decodeValueFromDB;
/// Should be available to admin and contributor accounts only, all methods in this object will immediately return if the user does not have the correct permissions
/// Encapsulates all functionality related to the Review Panel, this coordinates which question out of the backlog will get presented to the reviewer for active review
class QuestionReviewManager {
  static final QuestionReviewManager _instance = QuestionReviewManager._internal();
  factory QuestionReviewManager() => _instance;
  QuestionReviewManager._internal();
  // ==========================================
  // Constants
  static const String _newReviewTable = 'question_answer_pair_new_review';
  static const String _editsReviewTable = 'question_answer_pair_edits_review';
  static const String _mainPairsTable = 'question_answer_pairs';
  static const String _subjectDetailsTable = 'subject_details';
  // ==================================================
  // ----- Review Question Answer Pairs -----
  // ==================================================
  /// Fetches a random question from one of the review tables with weighted preference.
  ///
  /// Returns a Map containing:
  /// - 'data': The decoded question data (Map<String, dynamic>). Null if no questions found or error.
  /// - 'source_table': The name of the table the question came from (String). Null if no questions found.
  /// - 'primary_key': A Map representing the primary key(s) for deletion {'column_name': value}. Null if no questions found.
  /// - 'error': An error message (String) if no questions are available. Null otherwise.
  Future<Map<String, dynamic>> getRandomQuestionToBeReviewed() async {
    final random = Random();

    // Get counts for weighting and existence check using the modern .count() method
    // Let potential PostgrestExceptions propagate (Fail Fast)
    final int newCount = await SessionManager().supabase
        .from(_newReviewTable)
        .count(CountOption.exact);

    final int editsCount = await SessionManager().supabase
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
    if (newCount > 0) {
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

    final fetchResponse = await SessionManager().supabase
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
    // Use db! directly to adhere to Fail Fast if db is unexpectedly null.
    // The hasMediaCheck function from question_answer_pairs_table will determine if media exists,
    // extract filenames, and call registerMediaFiles which in turn calls insertMediaSyncStatus.
    // insertMediaSyncStatus will then trigger the MediaSyncWorker if needed.
    await QuestionValidator.hasMediaCheck(decodedData);
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
    final String questionId = primaryKey['question_id'] as String; // Assume always present
    QuizzerLogger.logMessage('Approving question $questionId from $sourceTable...');

    // Ensure qst_contrib is populated
    if (questionDetails['qst_contrib'] == null || (questionDetails['qst_contrib'] as String).isEmpty) {
      if (SessionManager().userId != null) {
        questionDetails['qst_contrib'] = SessionManager().userId;
        QuizzerLogger.logMessage('Populated missing qst_contrib with current userId: ${SessionManager().userId} for question $questionId');
      } else {
        QuizzerLogger.logError('Critical: qst_contrib is missing and could not be populated with a valid userId for question $questionId. Aborting approval.');
        throw StateError('Cannot approve question $questionId: qst_contrib is missing and no valid session userId found.');
      }
    }

    // Set qst_reviewer to current user ID
    if (SessionManager().userId != null) {
      questionDetails['qst_reviewer'] = SessionManager().userId;
      questionDetails['has_been_reviewed'] = 1; // Set review flag
      QuizzerLogger.logMessage('Set qst_reviewer to current userId: ${SessionManager().userId} for question $questionId');
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
    await SessionManager().supabase.from(_mainPairsTable).upsert(encodedPayload, onConflict: 'question_id');
    QuizzerLogger.logSuccess('Upsert successful for question $questionId into $_mainPairsTable.');

    // 3. Delete from the source review table using the primary key map
    QuizzerLogger.logValue('Deleting approved question $questionId from $sourceTable using key: $primaryKey');
    var deleteQuery = SessionManager().supabase.from(sourceTable).delete();
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
    final String questionId = primaryKey['question_id'] as String;
    QuizzerLogger.logMessage('Denying question $questionId from all tables...');
    
    // Use the SAME table names as your constants
    final tables = [
      _mainPairsTable,      // 'question_answer_pairs'
      _newReviewTable,      // 'question_answer_pair_new_review'
      _editsReviewTable,    // 'question_answer_pair_edits_review'
      'question_answer_pair_flags'
    ];
    
    for (final table in tables) {
      try {
        QuizzerLogger.logValue('Deleting question $questionId from $table');
        await SessionManager().supabase.from(table).delete().eq('question_id', questionId);
        QuizzerLogger.logSuccess('Deleted from $table');
      } catch (e) {
        QuizzerLogger.logError('Failed to delete from $table: $e');
        // Don't rethrow - continue trying other tables
      }
    }
    
    QuizzerLogger.logSuccess('Successfully processed denial for question $questionId');
    return true;
  }

  // ==================================================
  // ----- Review Subject Articles and Definitions -----
  // ==================================================
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
    // Calculate the cutoff date (3 months ago)
    final DateTime threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
    final String cutoffTimestamp = threeMonthsAgo.toUtc().toIso8601String();
    
    QuizzerLogger.logMessage('Fetching subject for review. Cutoff timestamp: $cutoffTimestamp');

    try {
      // First get up to 100 subject names that need review
      final subjectNamesResponse = await SessionManager().supabase
          .from(_subjectDetailsTable)
          .select('subject')
          .or('subject_description.is.null,last_modified_timestamp.lt.$cutoffTimestamp')
          .limit(100);
      
      if (subjectNamesResponse.isEmpty) {
        QuizzerLogger.logMessage('No subjects available for review.');
        return {
          'data': null, 
          'primary_key': null, 
          'error': 'No subjects available for review.'
        };
      }
      
      // Randomly select one subject name
      final random = Random();
      final int randomIndex = random.nextInt(subjectNamesResponse.length);
      final String selectedSubject = subjectNamesResponse[randomIndex]['subject'] as String;
      
      // Now fetch the full record for the selected subject
      final response = await SessionManager().supabase
          .from(_subjectDetailsTable)
          .select()
          .eq('subject', selectedSubject)
          .limit(1);
      
      if (response.isEmpty) {
        QuizzerLogger.logError('Selected subject "$selectedSubject" not found in full query.');
        return {
          'data': null, 
          'primary_key': null, 
          'error': 'Failed to fetch full subject data.'
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
      await SessionManager().supabase
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

  // ==================================================
  // ----- Review Flagged Questions -----
  // ==================================================
  /// Fetches a flagged question record for review from Supabase.
  /// Returns a map containing both the question data and the flag record.
  /// Returns null if no flagged questions are available for review.
  /// 
  /// Args:
  ///   primaryKey: Optional map containing flag_id, question_id, and flag_type for specific record lookup
  Future<Map<String, dynamic>?> getFlaggedQuestionForReview({
    Map<String, String>? primaryKey,
  }) async {
    // [x] Write unit test for this function

    try {
      QuizzerLogger.logMessage('Fetching flagged question for review from Supabase...');
      List<Map<String, dynamic>> response;
      
      if (primaryKey != null) {
        // Query specific record by primary key
        response = await SessionManager().supabase
            .from('question_answer_pair_flags')
            .select('*')
            .eq('flag_id', primaryKey['flag_id']!)
            .eq('question_id', primaryKey['question_id']!)
            .eq('flag_type', primaryKey['flag_type']!)
            .or('is_reviewed.is.null,is_reviewed.eq.0');
      } else {
        // Query random unreviewed flag - only get records with flag_id = 0 (unreviewed)
        response = await SessionManager().supabase
            .from('question_answer_pair_flags')
            .select('*')
            .eq('flag_id', '0')
            .or('is_reviewed.is.null,is_reviewed.eq.0');
      }
      // Run check if that question_id exists in the question-answer_pair table


      if (response.isEmpty) {
        QuizzerLogger.logMessage('No unreviewed flagged questions available for review.');
        return null;
      }
      
      // If specific record was requested, use the first result
      // Otherwise, select a random flag from the results
      final selectedFlag = primaryKey != null ? response.first : response[Random().nextInt(response.length)];
      
      String questionId = selectedFlag['question_id'] as String;
      String flagType = selectedFlag['flag_type'] as String;
      String? flagDescription = selectedFlag['flag_description'] as String?;
      
      QuizzerLogger.logMessage('Found flag for question: $questionId, type: $flagType');
      
      // Run check if that question_id exists in the question-answer_pair table
      // Validate that the flagged question still exists in the database
      // If not, delete the flag and try to get another one
      bool questionExists = false;
      
      while (!questionExists && response.isNotEmpty) {
        // Check if the question exists
        QuizzerLogger.logMessage('Validating question exists for question_id: $questionId');
        final questionCheck = await SessionManager().supabase
            .from('question_answer_pairs')
            .select('*')
            .eq('question_id', questionId);
        
        if (questionCheck.isNotEmpty) {
          questionExists = true;
          QuizzerLogger.logMessage('Successfully validated question exists for question_id: $questionId');
        } else {
          // Question doesn't exist, delete the flag and try another one
          QuizzerLogger.logMessage('Question $questionId no longer exists, deleting flag and trying another...');
          
          // Delete the invalid flag
          await SessionManager().supabase
              .from('question_answer_pair_flags')
              .delete()
              .eq('question_id', questionId)
              .eq('flag_type', flagType);
          
          // Remove this flag from our response list
          response.removeWhere((flag) => 
              flag['question_id'] == questionId && flag['flag_type'] == flagType);
          
          if (response.isEmpty) {
            QuizzerLogger.logMessage('No more valid flagged questions available for review.');
            return null;
          }
          
          // Try the next flag
          final nextFlag = response[Random().nextInt(response.length)];
          final String nextQuestionId = nextFlag['question_id'] as String;
          final String nextFlagType = nextFlag['flag_type'] as String;
          final String? nextFlagDescription = nextFlag['flag_description'] as String?;
          
          QuizzerLogger.logMessage('Trying next flag for question: $nextQuestionId, type: $nextFlagType');
          
          questionId = nextQuestionId;
          flagType = nextFlagType;
          flagDescription = nextFlagDescription;
        }
      }
      
      // Now fetch the corresponding question data
      QuizzerLogger.logMessage('Fetching question data for question_id: $questionId');
      final questionResponse = await SessionManager().supabase
          .from('question_answer_pairs')
          .select('*')
          .eq('question_id', questionId)
          .single();
      QuizzerLogger.logMessage('Successfully fetched question data for question_id: $questionId');

      // Properly decode the question data using the same pattern as get_send_postgre.dart
      final Map<String, dynamic> decodedQuestionData = {};
      for (final entry in questionResponse.entries) {
        decodedQuestionData[entry.key] = decodeValueFromDB(entry.value);
      }

      // Prepare the response structure
      QuizzerLogger.logMessage('Preparing response structure for question_id: $questionId');
      final Map<String, dynamic> reviewData = {
        'question_data': decodedQuestionData,
        'report': {
          'question_id': questionId,
          'flag_type': flagType,
          'flag_description': flagDescription,
        }
      };
      
      QuizzerLogger.logSuccess('Successfully fetched flagged question for review: $questionId');
      return reviewData;
      
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        // No rows returned (single() throws when no rows found)
        QuizzerLogger.logMessage('No flagged questions available for review.');
        return null;
      }
      QuizzerLogger.logError('Supabase error fetching flagged question for review: ${e.message} (Code: ${e.code})');
      rethrow;
    } catch (e) {
      QuizzerLogger.logError('Error fetching flagged question for review: $e');
      rethrow;
    }
  }

  /// Submits a review decision for a flagged question directly to Supabase.
  /// 
  /// Args:
  ///   questionId: The ID of the question being reviewed
  ///   action: Either 'edit' or 'delete'
  ///   updatedQuestionData: Required for both edit and delete actions. For edit actions, contains the updated question data. For delete actions, contains the original question data to be stored in the old_data_record field.
  /// 
  /// Returns:
  ///   true if the review was successfully submitted, false otherwise
  Future<bool> submitQuestionReview({
    required String questionId,
    required String action, // 'edit' or 'delete'
    Map<String, dynamic>? updatedQuestionData,
  }) async {
    // [x] Write unit tests for this function

    try {
      QuizzerLogger.logMessage('Submitting review for question: $questionId, action: $action');
      
      // Validate action
      if (action != 'edit' && action != 'delete') {
        QuizzerLogger.logError('Invalid action: $action. Must be "edit" or "delete"');
        throw ArgumentError('Action must be "edit" or "delete"');
      }
      // Generate incremental flag_id for the reviewed flag
      final String flagId = await _generateIncrementalFlagId(SessionManager().supabase, questionId);
      
      if (action == 'edit') {        
        // Edit the question record in question_answer_pairs table
        await SessionManager().supabase
          .from('question_answer_pairs')
          .update(updatedQuestionData!)
          .eq('question_id', questionId);
        
        // Query all user records with that id and set flagged to 0
        await SessionManager().supabase
          .from('user_question_answer_pairs')
          .update({'flagged': 0})
          .eq('question_id', questionId)
          .eq('flagged', 1);
        
        // Update the flag record with review info and set flag_id
        await SessionManager().supabase
          .from('question_answer_pair_flags')
          .update({
            'flag_id': flagId,
            'is_reviewed': 1,
            'decision': 'edit',
          })
          .eq('question_id', questionId);
        
      } else if (action == 'delete') {
        // First get the old data record before deleting
        final oldDataResponse = await SessionManager().supabase
          .from('question_answer_pairs')
          .select('*')
          .eq('question_id', questionId)
          .single();
        
        // Actually delete the record from the question_answer_pairs table
        await SessionManager().supabase
          .from('question_answer_pairs')
          .delete()
          .eq('question_id', questionId);
        
        // Update the flag record with review info and set flag_id
        await SessionManager().supabase
          .from('question_answer_pair_flags')
          .update({
            'flag_id': flagId,
            'is_reviewed': 1,
            'decision': 'delete',
            'old_data_record': oldDataResponse,
          })
          .eq('question_id', questionId);
      }
      
      QuizzerLogger.logSuccess('Successfully processed review for question: $questionId');
      return true;
      
    } on PostgrestException catch (e) {
      QuizzerLogger.logError('Supabase error submitting review: ${e.message} (Code: ${e.code})');
      return false;
    } catch (e) {
      QuizzerLogger.logError('Error submitting question review: $e');
      return false;
    }
  }

  // ==================================================
  // ----- Utilities -----
  // ==================================================
  // --- Helper for Decoding a Full QuestionAnswerPairRecord ---
  Map<String, dynamic> _decodeReviewRecord(Map<String, dynamic> rawRecord) {
    final Map<String, dynamic> decodedRecord = {};

    for (final entry in rawRecord.entries) {
      // Apply decodeValueFromDB to every value
      decodedRecord[entry.key] = decodeValueFromDB(entry.value);
    }
    return decodedRecord;
  }

  // --- Helper for Encoding a Full QuestionAnswerPairRecord for Upsert ---
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

  // --- Helper for Decoding a Full Subject Record ---
  Map<String, dynamic> _decodeSubjectRecord(Map<String, dynamic> rawRecord) {
    final Map<String, dynamic> decodedRecord = {};

    for (final entry in rawRecord.entries) {
      // Apply decodeValueFromDB to every value
      decodedRecord[entry.key] = decodeValueFromDB(entry.value);
    }
    return decodedRecord;
  }

  /// Helper function for incremental flag_id generation
  Future<String> _generateIncrementalFlagId(SupabaseClient supabase, String questionId) async {
    try {
      // Get the highest flag_id for this question_id
      final response = await supabase
        .from('question_answer_pair_flags')
        .select('flag_id')
        .eq('question_id', questionId)
        .not('flag_id', 'is', null)
        .order('flag_id', ascending: false)
        .limit(1);
      
      if (response.isEmpty) {
        return '1'; // First flag for this question
      }
      
      // Parse the highest ID and increment
      final String highestId = response.first['flag_id'] as String;
      final int nextId = int.parse(highestId) + 1;
      return nextId.toString();
      
    } catch (e) {
      QuizzerLogger.logError('Error generating incremental flag_id: $e');
      // Fallback to timestamp-based ID
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }
}