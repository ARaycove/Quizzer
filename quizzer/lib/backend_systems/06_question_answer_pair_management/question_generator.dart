import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_helper_utils/utils.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';

/// QuestionGenerator encapsulates all functionality related to the creation of new questions
/// For exclusive use with the AddQuestionPage, holds all individual question generation methods for each question type.
class QuestionGenerator {
  static final QuestionGenerator _instance = QuestionGenerator._internal();
  factory QuestionGenerator() => _instance;
  QuestionGenerator._internal();

  // ----- One Function for Each Question Type ----
  // Each Question Type will vary in how exactly it gets validated
  // Any question type specific validation will be called within the add call for that question type

  /// Adds a new multiple choice question to the database.
  /// 
  /// Args:
  ///   questionElements: A list of maps representing the question content.
  ///   answerElements: A list of maps representing the explanation/answer rationale.
  ///   options: A list of maps representing the multiple choice options.
  ///   correctOptionIndex: The index of the correct option (0-based).
  ///   debugDisableOutboundSyncCall: When true, prevents signaling the outbound sync system.
  ///     This is useful for testing to avoid triggering sync operations during test execution.
  ///     Defaults to false (sync is signaled normally).
  ///
  /// Returns:
  ///   The unique question_id generated for this question (format: timestamp_userId).
  Future<int> addQuestionMultipleChoice({
    required List<Map<String, dynamic>> questionElements,
    required List<Map<String, dynamic>> answerElements,
    required List<Map<String, dynamic>> options,
    required int correctOptionIndex,
    bool debugDisableOutboundSyncCall = false,
  }) async {
    try {
      final String timeStamp = DateTime.now().toUtc().toIso8601String();
      final String questionId = '${timeStamp}_${SessionManager().userId}';

      // Trim content fields in place
      questionElements = trimContentFields(questionElements);
      answerElements = trimContentFields(answerElements);
      options = trimContentFields(options);

      // Use the table's upsertRecord method for insertion
      return await QuestionAnswerPairsTable().upsertRecord({
        'question_id': questionId,
        'time_stamp': timeStamp,
        'question_elements': questionElements,
        'answer_elements': answerElements,
        'ans_flagged': 0,
        'ans_contrib': '',
        'qst_contrib': SessionManager().userId,
        'qst_reviewer': '',
        'has_been_reviewed': 0,
        'flag_for_removal': 0,
        'question_type': 'multiple_choice',
        'options': options,
        'correct_option_index': correctOptionIndex,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': timeStamp,
      });
    } catch (e) {
      QuizzerLogger.logError('Error adding multiple choice question - $e');
      rethrow;
    }
  }

  /// Adds a new select all that apply question to the database.
  /// 
  /// Args:
  ///   questionElements: A list of maps representing the question content.
  ///   answerElements: A list of maps representing the explanation/answer rationale.
  ///   options: A list of maps representing the options to choose from.
  ///   indexOptionsThatApply: A list of indices (0-based) indicating which options are correct.
  ///
  /// Returns:
  ///   The number of rows affected by the insert operation.
  Future<int> addQuestionSelectAllThatApply({
    required List<Map<String, dynamic>> questionElements,
    required List<Map<String, dynamic>> answerElements,
    required List<Map<String, dynamic>> options,
    required List<int> indexOptionsThatApply,
  }) async {
    try {   
      final String timeStamp = DateTime.now().toUtc().toIso8601String();
      final String questionId = '${timeStamp}_${SessionManager().userId}';

      // Trim content fields in place
      questionElements = trimContentFields(questionElements);
      answerElements = trimContentFields(answerElements);
      options = trimContentFields(options);

      // Use the table's upsertRecord method for insertion
      return await QuestionAnswerPairsTable().upsertRecord({
        'question_id': questionId,
        'time_stamp': timeStamp,
        'question_elements': questionElements,
        'answer_elements': answerElements,
        'ans_flagged': 0,
        'ans_contrib': '',
        'qst_contrib': SessionManager().userId,
        'qst_reviewer': '',
        'has_been_reviewed': 0,
        'flag_for_removal': 0,
        'question_type': 'select_all_that_apply',
        'options': options,
        'index_options_that_apply': indexOptionsThatApply,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': timeStamp,
      });
    } catch (e) {
      QuizzerLogger.logError('Error adding select all that apply question - $e');
      rethrow;
    }
  }

  /// Adds a new true/false question to the database.
  /// 
  /// Args:
  ///   questionElements: A list of maps representing the question content.
  ///   answerElements: A list of maps representing the explanation/answer rationale.
  ///   correctOptionIndex: The index of the correct option (0 for True, 1 for False).
  ///
  /// Returns:
  ///   The number of rows affected by the insert operation.
  Future<int> addQuestionTrueFalse({
    required List<Map<String, dynamic>> questionElements,
    required List<Map<String, dynamic>> answerElements,
    required int correctOptionIndex, // 0 for True, 1 for False
  }) async {
    try {
      final String timeStamp = DateTime.now().toUtc().toIso8601String();

      // Trim content fields in place
      questionElements = trimContentFields(questionElements);
      answerElements = trimContentFields(answerElements);

      // Use the table's upsertRecord method for insertion
      return await QuestionAnswerPairsTable().upsertRecord({
        'question_id': '${timeStamp}_${SessionManager().userId}',
        'time_stamp': timeStamp,
        'question_elements': questionElements,
        'answer_elements': answerElements,
        'ans_flagged': 0,
        'ans_contrib': '',
        'qst_contrib': SessionManager().userId,
        'qst_reviewer': '',
        'has_been_reviewed': 0,
        'flag_for_removal': 0,
        'question_type': 'true_false',
        'correct_option_index': correctOptionIndex,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': timeStamp,
      });
    } catch (e) {
      QuizzerLogger.logError('Error adding true/false question - $e');
      rethrow;
    }
  }

  /// Adds a new sort_order question to the database.
  ///
  /// Args:
  ///   questionElements: A list of maps representing the question content.
  ///   answerElements: A list of maps representing the explanation/answer rationale.
  ///   options: A list of maps representing the items to be sorted, **in the correct final order**.
  ///
  /// Returns:
  ///   The number of rows affected by the insert operation.
  Future<int> addSortOrderQuestion({
    required List<Map<String, dynamic>> questionElements,
    required List<Map<String, dynamic>> answerElements,
    required List<Map<String, dynamic>> options, // Items in the correct sorted order
  }) async {
    try {
      final String timeStamp = DateTime.now().toUtc().toIso8601String();
      final String questionId = '${timeStamp}_${SessionManager().userId}';

      QuizzerLogger.logMessage('Adding sort_order question with ID: $questionId');

      // Trim content fields in place
      questionElements = trimContentFields(questionElements);
      answerElements = trimContentFields(answerElements);
      options = trimContentFields(options);

      // Use the table's upsertRecord method for insertion
      return await QuestionAnswerPairsTable().upsertRecord({
        'question_id': questionId,
        'time_stamp': timeStamp,
        'question_elements': questionElements,
        'answer_elements': answerElements,
        'ans_flagged': 0,
        'ans_contrib': '',
        'qst_contrib': SessionManager().userId,
        'qst_reviewer': '',
        'has_been_reviewed': 0,
        'flag_for_removal': 0,
        'question_type': 'sort_order',
        'options': options,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': timeStamp,
      });
    } catch (e) {
      QuizzerLogger.logError('Error adding sort order question - $e');
      rethrow;
    }
  }

  /// Adds a new fill_in_the_blank question to the database.
  /// 
  /// Args:
  ///   questionElements: A list of maps representing the question content (can include 'blank' type elements).
  ///   answerElements: A list of maps representing the explanation/answer rationale.
  ///   answersToBlanks: A list of maps where each map contains the correct answer and synonyms for each blank.
  ///   >> [{"cos x":["cos(x)","cos","cosine x","cosine(x)","cosine"]}]
  ///
  /// Returns:
  ///   The number of rows affected by the insert operation.
  Future<int> addFillInTheBlankQuestion({
    required List<Map<String, dynamic>> questionElements,
    required List<Map<String, dynamic>> answerElements,
    required List<Map<String, List<String>>> answersToBlanks,
  }) async {
    try {
      final String timeStamp = DateTime.now().toUtc().toIso8601String();
      final String questionId = '${timeStamp}_${SessionManager().userId}';

      // Trim content fields in place
      questionElements = trimContentFields(questionElements);
      answerElements = trimContentFields(answerElements);

      // Use the table's upsertRecord method for insertion
      return await QuestionAnswerPairsTable().upsertRecord({
        'question_id': questionId,
        'time_stamp': timeStamp,
        'question_elements': questionElements,
        'answer_elements': answerElements,
        'ans_flagged': 0,
        'ans_contrib': '',
        'qst_contrib': SessionManager().userId,
        'qst_reviewer': '',
        'has_been_reviewed': 0,
        'flag_for_removal': 0,
        'question_type': 'fill_in_the_blank',
        'answers_to_blanks': answersToBlanks,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': timeStamp,
      });
    } catch (e) {
      QuizzerLogger.logError('Error adding fill in the blank question - $e');
      rethrow;
    }
  }
}