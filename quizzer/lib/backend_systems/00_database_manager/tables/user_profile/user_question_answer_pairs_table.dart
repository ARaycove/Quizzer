import 'dart:async';
import 'package:quizzer/backend_systems/00_database_manager/tables/sql_table.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

class UserQuestionAnswerPairsTable extends SqlTable {
  static final UserQuestionAnswerPairsTable _instance = UserQuestionAnswerPairsTable._internal();
  factory UserQuestionAnswerPairsTable() => _instance;
  UserQuestionAnswerPairsTable._internal();

  @override
  bool isTransient = false;

  @override
  bool requiresInboundSync = true;

  @override
  dynamic get additionalFiltersForInboundSync => {'user_uuid': SessionManager().userId};

  @override
  bool get useLastLoginForInboundSync => false;
  
  @override
  String get tableName => 'user_question_answer_pairs';

  @override
  List<String> get primaryKeyConstraints => ['user_uuid', 'question_id'];

  @override
  List<Map<String, String>> get expectedColumns => [
    {'name': 'user_uuid',                       'type': 'TEXT NOT NULL'},
    {'name': 'question_id',                     'type': 'TEXT NOT NULL'},
    {'name': 'revision_streak',                 'type': 'INTEGER'},
    {'name': 'last_revised',                    'type': 'TEXT'},
    // Days_since_last_revision calculated live
    // Current_time calculated live UTC time
    {'name': 'day_time_introduced',             'type': 'TEXT DEFAULT NULL'},
    // days since first introduced calculated live
    {'name': 'avg_hesitation',                  'type': 'REAL DEFAULT 0'},
    {'name': 'avg_reaction_time',               'type': 'REAL NOT NULL DEFAULT 0'},

    // next_revision_due was removed, this is a relic of the original SRS implementation
    {'name': 'total_incorect_attempts',         'type': 'INTEGER NOT NULL DEFAULT 0'},
    {'name': 'total_correct_attempts',          'type': 'INTEGER NOT NULL DEFAULT 0'},
    {'name': 'total_attempts',                  'type': 'INTEGER NOT NULL DEFAULT 0'},
    {'name': 'question_accuracy_rate',          'type': 'REAL NOT NULL DEFAULT 0'},
    {'name': 'question_inaccuracy_rate',        'type': 'REAL NOT NULL DEFAULT 0'},
    
    // These features will be deprecated
    // time_between_revisions was removed, this is a relic of the original SRS implementation
    {'name': 'average_times_shown_per_day',     'type': 'REAL'},
    {'name': 'in_circulation',                  'type': 'INTEGER'},
    // Tracking features
    {'name': 'flagged',                         'type': 'INTEGER DEFAULT 0'},
    {'name': 'last_modified_timestamp',         'type': 'TEXT'},

    // NOT TO BE TO BE SYNCED TO SUPABASE
    {'name': 'accuracy_probability',            'type': 'REAL DEFAULT 0'},  // What was the prediction models accuracy probability that it estimated?
    {'name': 'last_prob_calc',                  'type': 'TEXT'},            // When was the last time the probability for this question was calculated?
    {'name': 'has_been_synced',                 'type': 'INTEGER DEFAULT 0'},
    {'name': 'edits_are_synced',                'type': 'INTEGER DEFAULT 0'},
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

  @override
  Future<Map<String, dynamic>> finishRecord(Map<String, dynamic> dataToInsert) async {
    // Set last_modified_timestamp
    dataToInsert['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();
    
    // Set sync flags for new/edited records
    dataToInsert['has_been_synced'] = 0;
    dataToInsert['edits_are_synced'] = 0;
    dataToInsert.putIfAbsent('avg_hesitation', () => 0.0);
    dataToInsert.putIfAbsent('avg_reaction_time', () => 0.0);
    
    // Set day_time_introduced if it's a new record and not provided
    if ((!dataToInsert.containsKey('day_time_introduced') || dataToInsert['day_time_introduced'] == null) &&
        dataToInsert.containsKey('user_uuid') && dataToInsert.containsKey('question_id')) {
      dataToInsert['day_time_introduced'] = DateTime.now().toUtc().toIso8601String();
    }
    
    return dataToInsert;
  }
}