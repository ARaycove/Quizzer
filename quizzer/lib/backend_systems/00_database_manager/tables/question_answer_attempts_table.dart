import 'package:quizzer/backend_systems/00_database_manager/tables/sql_table.dart';
import 'dart:async';

class QuestionAnswerAttemptsTable extends SqlTable{
  static final QuestionAnswerAttemptsTable _instance = QuestionAnswerAttemptsTable._internal();
  factory QuestionAnswerAttemptsTable() => _instance;
  QuestionAnswerAttemptsTable._internal();
  // ==================================================
  // ----- Constants -----
  // ==================================================
  @override
  bool isTransient = true;

  @override
  bool requiresInboundSync = false;

  @override
  dynamic get additionalFiltersForInboundSync => null;

  @override
  bool get useLastLoginForInboundSync => false;

  // ==================================================
  // ----- Schema Definition Validation -----
  // ==================================================
  @override
  String get tableName => 'question_answer_attempts';

  @override
  List<String> get primaryKeyConstraints => ['time_stamp', 'question_id', 'participant_id'];

  @override
  List<Map<String, String>> get expectedColumns => [
    // ===================================
    // Meta Data
    // ===================================
    // When was this entered?
    {'name': 'time_stamp',                'type': 'TEXT NOT NULL'},
    // What question was answered
    {'name': 'question_id',               'type': 'TEXT NOT NULL'},
    // The uuid of the user in question
    {'name': 'participant_id',            'type': 'TEXT NOT NULL'},
    // ===================================
    // Question_Metrics (not performance related, what is the question?)
    // ===================================
    {'name': "question_vector",           'type': 'TEXT NOT NULL'}, // What does the transformer say?
    {'name': "question_type",             'type': 'TEXT NOT NULL'}, // What is the question type?
    {'name': "num_mcq_options",           'type': 'INTEGER NULL DEFAULT 0'}, // How many mcq options does this have (should be 0 if the type is not mcq)
    {'name': "num_so_options",            'type': 'INTEGER NULL DEFAULT 0'},
    {'name': "num_sata_options",          'type': 'INTEGER NULL DEFAULT 0'},
    {'name': "num_blanks",                'type': 'INTEGER NULL DEFAULT 0'},
    // ===================================
    // Individual Question Performance
    // ===================================
    {'name': 'avg_react_time',             'type': 'REAL NOT NULL'},   
    {'name': 'response_result',           'type': 'INTEGER NOT NULL'}, // Did the user get this question correct after presentation 0 or 1
    {'name': 'was_first_attempt',         'type': 'INTEGER NOT NULL'}, // At time of presentation, had user attempted this before? 0 or 1
    {'name': 'total_correct_attempts',    'type': 'INTEGER NOT NULL'},
    {'name': 'total_incorrect_attempts',  'type': 'INTEGER NOT NULL'},
    {'name': 'total_attempts',            'type': 'INTEGER NOT NULL'},
    {'name': 'accuracy_rate',             'type': 'REAL NOT NULL'},
    {'name': 'revision_streak',           'type': 'INTEGER NOT NULL'},

    // Temporal metrics
    {'name': 'time_of_presentation',      'type': 'TEXT NULL'},
    {'name': 'last_revised_date',         'type': 'TEXT NULL'},
    {'name': 'days_since_last_revision',  'type': 'REAL NULL'},
    {'name': 'days_since_first_introduced','type':'REAL NULL'},
    {'name': 'attempt_day_ratio',         'type': 'REAL NULL'}, // total_attempts/days_since_introduced
    
    // User Stats metrics Vector
    // The current state of global statistics at time of answer, array of maps
    {'name': 'user_stats_vector',         'type': 'TEXT'},
    // K nearest performance (from closest to further ordered)
    {'name': 'knn_performance_vector',           'type': 'TEXT NULL'},
    // User Profile at time of presentation -> Vector (Fixed)
    {'name': 'user_profile_record',              'type': 'TEXT NULL'},
    // Sync tracking metrics
    {'name': 'has_been_synced',           'type': 'INTEGER DEFAULT 0'},
    {'name': 'edits_are_synced',          'type': 'INTEGER DEFAULT 0'},
    // Does not get a last_modified, since samples get generated once then do not get edited
  ];
  
  @override
  Future<bool> validateRecord(Map<String, dynamic> dataToInsert) async {
    // Get all required field names (NOT NULL columns)
    final requiredFields = expectedColumns
        .where((col) => col['type']?.contains('NOT NULL') == true)
        .map((col) => col['name']!)
        .toList();
    // Check each required field exists and is not null
    for (final field in requiredFields) {
      if (!dataToInsert.containsKey(field) || dataToInsert[field] == null) {
        throw ArgumentError('Required field "$field" is missing or null');
      }
    }
    return true;
  }
}





