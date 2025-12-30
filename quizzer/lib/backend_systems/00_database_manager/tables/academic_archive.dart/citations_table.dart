import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/sql_table.dart';

class CitationsTable extends SqlTable {
  static final CitationsTable _instance = CitationsTable._internal();
  factory CitationsTable() => _instance;
  CitationsTable._internal();

  @override
  bool isTransient = true;

  @override
  bool get requiresInboundSync => false;

  @override
  dynamic get additionalFiltersForInboundSync => null;

  @override
  bool get useLastLoginForInboundSync => false;

  @override
  String get tableName => 'citations';

  @override
  List<String> get primaryKeyConstraints => ['title', 'publisher', 'publication_date'];
  
  @override
  List<Map<String, String>> get expectedColumns => [
    // --- Core Citation Identity and Type ---
    {'name': 'title', 'type': 'TEXT NOT NULL'},
    {'name': 'subtitle', 'type': 'TEXT'},
    {'name': 'citation_type', 'type': 'TEXT NOT NULL'},

    // --- Author/Contributor Fields ---
    {'name': 'author_first_name', 'type': 'TEXT NOT NULL'},
    {'name': 'author_middle_initial', 'type': 'TEXT'},
    {'name': 'author_last_name', 'type': 'TEXT NOT NULL'},
    {'name': 'author_suffix', 'type': 'TEXT'},
    {'name': 'corporate_author', 'type': 'TEXT'},
    {'name': 'additional_authors', 'type': 'TEXT'},

    // --- Publication Details (Required & Common) ---
    {'name': 'publication_date', 'type': 'TEXT NOT NULL'},
    {'name': 'publisher', 'type': 'TEXT NOT NULL'},
    {'name': 'publisher_location', 'type': 'TEXT'},
    {'name': 'edition', 'type': 'TEXT'},
    {'name': 'volume', 'type': 'TEXT'},
    {'name': 'issue', 'type': 'TEXT'},
    {'name': 'series_title', 'type': 'TEXT'},
    {'name': 'series_number', 'type': 'TEXT'},
    {'name': 'pages', 'type': 'TEXT'},
    
    // --- Chapter/Part Details ---
    {'name': 'chapter_title', 'type': 'TEXT'},
    {'name': 'chapter_number', 'type': 'TEXT'},

    // --- Digital/Access Fields ---
    {'name': 'url', 'type': 'TEXT'},
    {'name': 'doi', 'type': 'TEXT'},

    // --- Specialized Source Fields (Journal, Conference, Thesis) ---
    {'name': 'journal_title', 'type': 'TEXT'},
    {'name': 'journal_abbreviation', 'type': 'TEXT'},
    {'name': 'conference_name', 'type': 'TEXT'},
    {'name': 'conference_location', 'type': 'TEXT'},
    {'name': 'conference_date', 'type': 'TEXT'},
    {'name': 'degree_type', 'type': 'TEXT'},
    {'name': 'university', 'type': 'TEXT'},

    // --- Report/Institution/Patent Fields ---
    {'name': 'report_number', 'type': 'TEXT'},
    {'name': 'institution', 'type': 'TEXT'},
    {'name': 'patent_number', 'type': 'TEXT'},
    {'name': 'patent_office', 'type': 'TEXT'},

    // --- Legal/Court Fields ---
    {'name': 'legal_citation', 'type': 'TEXT'},
    {'name': 'court', 'type': 'TEXT'},

    // --- Content/Metadata Fields ---
    {'name': 'abstract', 'type': 'TEXT'},
    {'name': 'notes', 'type': 'TEXT'},
    {'name': 'full_document', 'type': 'TEXT NOT NULL'},
    {'name': 'media', 'type': 'TEXT'},

    // --- Sync and Metadata Fields ---
    {'name': 'has_been_synced', 'type': 'INTEGER DEFAULT 0'},
    {'name': 'edits_are_synced', 'type': 'INTEGER DEFAULT 0'},
    {'name': 'last_modified_timestamp', 'type': 'TEXT'},
  ];

  @override
  Future<bool> validateRecord(Map<String, dynamic> dataToInsert) async {
    const requiredFields = [
      'citation_type', 'title', 'author_first_name', 'author_last_name',
      'publication_date', 'publisher', 'full_document'
    ];

    for (final field in requiredFields) {
      final value = dataToInsert[field];
      if (value == null || (value is String && value.isEmpty)) {
        QuizzerLogger.logError('Validation failed for citation: Missing required field: $field.');
        return false;
      }
    }
    return true;
  }
}