import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/sql_table.dart';

class MediaSyncStatusTable extends SqlTable {
  static final MediaSyncStatusTable _instance = MediaSyncStatusTable._internal();
  factory MediaSyncStatusTable() => _instance;
  MediaSyncStatusTable._internal();

  @override
  bool get isTransient => true;

  @override
  bool get requiresInboundSync => false;

  @override
  dynamic get additionalFiltersForInboundSync => null;

  @override
  bool get useLastLoginForInboundSync => false;
  
  @override
  String get tableName => 'media_sync_status';

  @override
  List<String> get primaryKeyConstraints => ['file_name'];

  @override
  List<Map<String, String>> get expectedColumns => [
    // --- Core Identity (Primary Key) ---
    {'name': 'file_name', 'type': 'TEXT NOT NULL'},
    {'name': 'file_extension', 'type': 'TEXT NOT NULL'},

    // --- Status Flags (NULLABLE by default) ---
    {'name': 'exists_locally', 'type': 'INTEGER DEFAULT NULL'},
    {'name': 'exists_externally', 'type': 'INTEGER DEFAULT NULL'},
  ];

  @override
  Future<bool> validateRecord(Map<String, dynamic> dataToInsert) async {
    const requiredFields = ['file_name', 'file_extension'];

    for (final field in requiredFields) {
      final value = dataToInsert[field];
      if (value == null || (value is String && value.isEmpty)) {
        QuizzerLogger.logError('Validation failed for media sync status: Missing required field: $field.');
        return false;
      }
    }
    return true;
  }
}