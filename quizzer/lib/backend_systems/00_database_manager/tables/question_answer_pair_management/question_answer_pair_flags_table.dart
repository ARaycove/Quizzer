import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/sql_table.dart';

class QuestionAnswerPairFlagsTable extends SqlTable {
  static final QuestionAnswerPairFlagsTable _instance = QuestionAnswerPairFlagsTable._internal();
  factory QuestionAnswerPairFlagsTable() => _instance;
  QuestionAnswerPairFlagsTable._internal();

  @override
  bool get isTransient => true;

  @override
  bool get requiresInboundSync => false;

  @override
  dynamic get additionalFiltersForInboundSync => null;

  @override
  bool get useLastLoginForInboundSync => false;

  @override
  String get tableName => 'question_answer_pair_flags';

  @override
  List<String> get primaryKeyConstraints => ['question_id', 'flag_type', 'flag_description'];

  @override
  List<Map<String, String>> get expectedColumns => [
    // --- Core Identity (Composite Primary Key) ---
    {'name': 'question_id', 'type': 'TEXT NOT NULL'},
    {'name': 'flag_type', 'type': 'TEXT NOT NULL'},
    {'name': 'flag_description', 'type': 'TEXT'},

    // --- Sync and Audit Fields ---
    {'name': 'has_been_synced', 'type': 'INTEGER DEFAULT 0'},
    {'name': 'edits_are_synced', 'type': 'INTEGER DEFAULT 0'},
    {'name': 'last_modified_timestamp', 'type': 'TEXT'},
  ];

  // ==========================================
  // Validation Logic
  // ==========================================

  // Valid flag types
  static const List<String> validFlagTypes = [
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

  @override
  Future<bool> validateRecord(Map<String, dynamic> dataToInsert) async {
    final String? questionId = dataToInsert['question_id'] as String?;
    final String? flagType = dataToInsert['flag_type'] as String?;
    final String? flagDescription = dataToInsert['flag_description'] as String?;

    if (questionId == null || questionId.isEmpty) {
      QuizzerLogger.logError('Validation failed for flag: Missing question_id.');
      return false;
    }
    if (flagType == null || !validFlagTypes.contains(flagType)) {
      QuizzerLogger.logError('Validation failed for flag $questionId: Invalid or missing flag_type: $flagType.');
      return false;
    }
    if (flagDescription == null || flagDescription.trim().isEmpty) {
      QuizzerLogger.logError('Validation failed for flag $questionId: flag_description cannot be empty.');
      return false;
    }

    // Since this table is dependent on 'question_answer_pairs',
    // we perform the existence check here.
    return await _checkQuestionExists(questionId);
  }

  /// Checks for the existence of the question_id in the master table.
  Future<bool> _checkQuestionExists(String questionId) async {
    final db = await DatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      QuizzerLogger.logError('Failed to acquire database access to check question existence.');
      return false;
    }

    try {
      final List<Map<String, dynamic>> results = await db.query(
        'question_answer_pairs',
        columns: ['question_id'],
        where: 'question_id = ?',
        whereArgs: [questionId],
        limit: 1,
      );

      if (results.isEmpty) {
        QuizzerLogger.logError('Question ID does not exist in master table: $questionId');
        return false;
      }
      return true;
    } catch (e) {
      QuizzerLogger.logError('Error checking question existence for flag validation - $e');
      return false;
    } finally {
      DatabaseMonitor().releaseDatabaseAccess();
    }
  }
}