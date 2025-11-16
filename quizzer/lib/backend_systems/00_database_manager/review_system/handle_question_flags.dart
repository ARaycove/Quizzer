import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:supabase/supabase.dart';
import 'dart:math'; // Added for Random
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart' show decodeValueFromDB;
import 'package:quizzer/backend_systems/12_answer_validator/answer_validation/text_analysis_tools.dart';

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
    
    final supabase = getSessionManager().supabase;
    
    List<Map<String, dynamic>> response;
    
    if (primaryKey != null) {
      // Query specific record by primary key
      response = await supabase
          .from('question_answer_pair_flags')
          .select('*')
          .eq('flag_id', primaryKey['flag_id']!)
          .eq('question_id', primaryKey['question_id']!)
          .eq('flag_type', primaryKey['flag_type']!)
          .or('is_reviewed.is.null,is_reviewed.eq.0');
    } else {
      // Query random unreviewed flag - only get records with flag_id = 0 (unreviewed)
      response = await supabase
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
      final questionCheck = await supabase
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
        await supabase
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
    final questionResponse = await supabase
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
  required Map<String, dynamic> updatedQuestionData,
}) async {
  // [x] Write unit tests for this function

  try {
    QuizzerLogger.logMessage('Submitting review for question: $questionId, action: $action');
    
    // Validate action
    if (action != 'edit' && action != 'delete') {
      QuizzerLogger.logError('Invalid action: $action. Must be "edit" or "delete"');
      throw ArgumentError('Action must be "edit" or "delete"');
    }
    
    final supabase = getSessionManager().supabase;
    
    // Generate incremental flag_id for the reviewed flag
    final String flagId = await _generateIncrementalFlagId(supabase, questionId);
    
    if (action == 'edit') {
      // Normalize module name if present before updating
      if (updatedQuestionData['module_name'] != null && updatedQuestionData['module_name'] is String) {
        final String normalizedModuleName = await normalizeString(updatedQuestionData['module_name'] as String);
        updatedQuestionData['module_name'] = normalizedModuleName;
        QuizzerLogger.logMessage('Normalized module name for question $questionId: $normalizedModuleName');
      }
      
      // Edit the question record in question_answer_pairs table
      await supabase
        .from('question_answer_pairs')
        .update(updatedQuestionData)
        .eq('question_id', questionId);
      
      // Query all user records with that id and set flagged to 0
      await supabase
        .from('user_question_answer_pairs')
        .update({'flagged': 0})
        .eq('question_id', questionId)
        .eq('flagged', 1);
      
      // Update the flag record with review info and set flag_id
      await supabase
        .from('question_answer_pair_flags')
        .update({
          'flag_id': flagId,
          'is_reviewed': 1,
          'decision': 'edit',
        })
        .eq('question_id', questionId);
      
    } else if (action == 'delete') {
      // First get the old data record before deleting
      final oldDataResponse = await supabase
        .from('question_answer_pairs')
        .select('*')
        .eq('question_id', questionId)
        .single();
      
      // Actually delete the record from the question_answer_pairs table
      await supabase
        .from('question_answer_pairs')
        .delete()
        .eq('question_id', questionId);
      
      // Update the flag record with review info and set flag_id
      await supabase
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
