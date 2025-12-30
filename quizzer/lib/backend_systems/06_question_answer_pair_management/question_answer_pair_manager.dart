import 'package:quizzer/backend_systems/09_switch_board/sb_sync_worker_signals.dart'; 
import 'package:quizzer/backend_systems/06_question_answer_pair_management/question_validator.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';

/// The QuestionAnswerPairManager encapsulates all functionality related to the physical question records
/// To access individual user relationships with the question records use the UserQuestionManager object
class QuestionAnswerPairManager {
  static final QuestionAnswerPairManager _instance = QuestionAnswerPairManager._internal();
  factory QuestionAnswerPairManager() => _instance;
  QuestionAnswerPairManager._internal();

  // ----- Get Questions based on conditions -----
  /// Fetches a single question-answer pair by its composite ID.
  /// The questionId format is expected to be 'timestamp_qstContrib'.
  Future<Map<String, dynamic>> getQuestionAnswerPairById(String questionId) async {
    try {
      final results = await QuestionAnswerPairsTable().getRecord(
        'SELECT * FROM question_answer_pairs WHERE question_id = "$questionId"'
      );

      // Perform checks for single row results
      if (results.isEmpty) {
        QuizzerLogger.logError('Query for single row (getQuestionAnswerPairById) returned no results for ID: $questionId');
        throw StateError('Expected exactly one row for question ID $questionId, but found none.');
      } else if (results.length > 1) {
        QuizzerLogger.logError('Query for single row (getQuestionAnswerPairById) returned ${results.length} results for ID: $questionId - removing duplicates');
        
        // Keep the first record and delete the duplicates
        final List<Map<String, dynamic>> duplicates = results.skip(1).toList();
        
        for (final duplicate in duplicates) {
          final String duplicateQuestionId = duplicate['question_id'] as String;
          QuizzerLogger.logMessage('Deleting duplicate question record: $duplicateQuestionId');
          
          await QuestionAnswerPairsTable().deleteRecord({
            'question_id': duplicateQuestionId
          });
        }
        
        QuizzerLogger.logSuccess('Removed ${duplicates.length} duplicate records for question ID: $questionId');
      }

      // Return the single decoded row
      return results.first;
    } catch (e) {
      QuizzerLogger.logError('Error getting question answer pair by ID - $e');
      rethrow;
    }
  }

  /// Retrieves all question-answer pairs from the database.
  Future<List<Map<String, dynamic>>> getAllQuestionAnswerPairs() async {
    try {
      return await QuestionAnswerPairsTable().getRecord('SELECT * FROM question_answer_pairs');
    } catch (e) {
      QuizzerLogger.logError('Error getting all question answer pairs - $e');
      rethrow;
    }
  }

  /// Gets all question IDs and their k_nearest_neighbors from the question_answer_pairs table
  Future<List<Map<String, dynamic>>> getAllQuestionIdsWithNeighbors() async {
    try {
      final results = await QuestionAnswerPairsTable().getRecord('''
        SELECT 
          question_id,
          k_nearest_neighbors
        FROM question_answer_pairs
      ''');

      return results;
    } catch (e) {
      QuizzerLogger.logError('Error getting all question IDs with neighbors - $e');
      rethrow;
    }
  }

  // ----- Edit Questions -----
  /// Edits an existing question-answer pair by updating specified fields.
  Future<int> editQuestionAnswerPair({
    required String questionId,
    List<Map<String, dynamic>>? questionElements,
    List<Map<String, dynamic>>? answerElements,
    List<int>? indexOptionsThatApply,
    bool? ansFlagged,
    String? ansContrib,
    String? qstReviewer,
    bool? hasBeenReviewed,
    bool? flagForRemoval,
    String? questionType,
    List<Map<String, dynamic>>? options, 
    int? correctOptionIndex,
    List<Map<String, dynamic>>? correctOrderElements,
    List<Map<String, List<String>>>? answersToBlanks,
    bool debugDisableOutboundSyncCall = false,
  }) async {
    try {
      // Fetch the existing record first
      final Map<String, dynamic> existingRecord = await getQuestionAnswerPairById(questionId);
      
      // Prepare updates
      Map<String, dynamic> updates = {};
      
      // Add non-null fields to the updates
      if (questionElements != null) updates['question_elements'] = questionElements;
      if (answerElements != null) updates['answer_elements'] = answerElements;
      if (indexOptionsThatApply != null) updates['index_options_that_apply'] = indexOptionsThatApply;
      if (ansFlagged != null) updates['ans_flagged'] = ansFlagged ? 1 : 0;
      if (ansContrib != null) updates['ans_contrib'] = ansContrib;
      if (qstReviewer != null) updates['qst_reviewer'] = qstReviewer;
      if (hasBeenReviewed != null) updates['has_been_reviewed'] = hasBeenReviewed ? 1 : 0;
      if (flagForRemoval != null) updates['flag_for_removal'] = flagForRemoval ? 1 : 0;
      if (questionType != null) updates['question_type'] = questionType;
      if (options != null) updates['options'] = options;
      if (correctOptionIndex != null) updates['correct_option_index'] = correctOptionIndex;
      if (correctOrderElements != null) updates['correct_order'] = correctOrderElements;
      if (answersToBlanks != null) updates['answers_to_blanks'] = answersToBlanks;

      // If no values were provided to update, log and return 0 rows affected.
      if (updates.isEmpty) {
        QuizzerLogger.logWarning('editQuestionAnswerPair called for question $questionId with no fields to update.');
        return 0;
      }

      // Create updated record by merging existing record with updates
      final Map<String, dynamic> updatedRecord = Map<String, dynamic>.from(existingRecord);
      updates.forEach((key, value) {
        updatedRecord[key] = value;
      });

      // Update sync flags and timestamp
      updatedRecord['edits_are_synced'] = 0;
      updatedRecord['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();

      // Check for media
      final bool recordHasMedia = await QuestionValidator.hasMediaCheck(updatedRecord);
      updatedRecord['has_media'] = recordHasMedia ? 1 : 0;

      QuizzerLogger.logMessage('Updating question $questionId with fields: ${updates.keys.join(', ')}');

      // Use the table's upsertRecord method
      final result = await QuestionAnswerPairsTable().upsertRecord(updatedRecord);
      
      if (!debugDisableOutboundSyncCall) {
        signalOutboundSyncNeeded();
      }
      
      return result;
    } catch (e) {
      QuizzerLogger.logError('Error editing question answer pair - $e');
      rethrow;
    }
  }
}