import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/sql_table.dart';

class SubjectDetailsTable extends SqlTable {
  static final SubjectDetailsTable _instance = SubjectDetailsTable._internal();
  factory SubjectDetailsTable() => _instance;
  SubjectDetailsTable._internal();

  @override
  bool get isTransient => true;

  @override
  bool get requiresInboundSync => false;

  @override
  dynamic get additionalFiltersForInboundSync => null;

  @override
  bool get useLastLoginForInboundSync => false;

  @override
  String get tableName => 'subject_details';

  @override
  List<String> get primaryKeyConstraints => ['subject'];

  @override
  List<Map<String, String>> get expectedColumns => [
    // --- Core Identity ---
    {'name': 'subject', 'type': 'TEXT NOT NULL'},

    // --- Subject Structure and Metadata ---
    {'name': 'immediate_parent', 'type': 'TEXT'},
    {'name': 'subject_description', 'type': 'TEXT'},
    
    // --- Sync and Audit Fields ---
    {'name': 'has_been_synced', 'type': 'INTEGER DEFAULT 0'},
    {'name': 'edits_are_synced', 'type': 'INTEGER DEFAULT 0'},
    {'name': 'last_modified_timestamp', 'type': 'TEXT'},
  ];

  @override
  Future<bool> validateRecord(Map<String, dynamic> dataToInsert) async {
    final value = dataToInsert['subject'];
    if (value == null || (value is String && value.isEmpty)) {
      QuizzerLogger.logError('Validation failed for subject detail: Missing required field: "subject".');
      return false;
    }
    return true;
  }
}