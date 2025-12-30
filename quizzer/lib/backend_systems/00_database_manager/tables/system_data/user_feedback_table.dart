import 'package:uuid/uuid.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/sql_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';

class UserFeedbackTable extends SqlTable {
  static final UserFeedbackTable _instance = UserFeedbackTable._internal();
  factory UserFeedbackTable() => _instance;
  UserFeedbackTable._internal();

  @override
  bool get isTransient => true;

  @override
  bool requiresInboundSync = false;

  @override
  dynamic get additionalFiltersForInboundSync => null;

  @override
  bool get useLastLoginForInboundSync => false;

  @override
  String get tableName => 'user_feedback';

  @override
  List<String> get primaryKeyConstraints => ['id'];

  @override
  List<Map<String, String>> get expectedColumns => [
    {'name': 'id', 'type': 'TEXT KEY'},
    {'name': 'creation_date', 'type': 'TEXT NOT NULL'},
    {'name': 'user_id', 'type': 'TEXT'},
    {'name': 'feedback_type', 'type': 'TEXT'},
    {'name': 'feedback_content', 'type': 'TEXT'},
    {'name': 'app_version', 'type': 'TEXT'},
    {'name': 'operating_system', 'type': 'TEXT'},
    {'name': 'is_addressed', 'type': 'INTEGER DEFAULT 0'},
    {'name': 'has_been_synced', 'type': 'INTEGER DEFAULT 0'},
    {'name': 'edits_are_synced', 'type': 'INTEGER DEFAULT 0'}, 
    {'name': 'last_modified_timestamp', 'type': 'TEXT'},
  ];

  @override
  Future<bool> validateRecord(Map<String, dynamic> dataToInsert) async {
    final String? id = dataToInsert['id'] as String?;
    final String? creationDate = dataToInsert['creation_date'] as String?;
    final String? content = dataToInsert['feedback_content'] as String?;
    
    if (id == null || id.isEmpty) {
      QuizzerLogger.logError('User feedback validation failed: ID is missing.');
      return false;
    }
    if (creationDate == null || creationDate.isEmpty) {
      QuizzerLogger.logError('User feedback validation failed: creation_date is missing.');
      return false;
    }
    if (content == null || content.isEmpty) {
      QuizzerLogger.logError('User feedback validation failed: feedback_content is missing.');
      return false;
    }
    return true;
  }

  @override
  Future<Map<String, dynamic>> finishRecord(Map<String, dynamic> dataToInsert) async {
    final String now = DateTime.now().toUtc().toIso8601String();
    const Uuid uuid = Uuid();
    
    // Mandatory ID and creation time for new records
    dataToInsert.putIfAbsent('id', () => uuid.v4());
    dataToInsert.putIfAbsent('creation_date', () => now);

    // Only fetch dynamic data (device info, app version) if it's a new submission
    if (!dataToInsert.containsKey('app_version')) {
      dataToInsert['operating_system'] = await getDeviceInfo();
      dataToInsert['app_version'] = await getAppVersionInfo();

      // Mark as needing sync for new records
      dataToInsert['has_been_synced'] = 0;
      dataToInsert['edits_are_synced'] = 0;
    } else {
       // If updating, ensure edits are marked for sync if applicable
       if (dataToInsert['has_been_synced'] != 1) {
         dataToInsert['edits_are_synced'] = 0;
      }
    }
    
    // Update audit field
    dataToInsert['last_modified_timestamp'] = now;

    // Ensure user_id is set to null if not provided, for consistency.
    if (!dataToInsert.containsKey('user_id')) {
      dataToInsert['user_id'] = null;
    }

    // Ensure status fields are integers
    dataToInsert['is_addressed'] = dataToInsert['is_addressed'] == 1 ? 1 : 0;
    
    return dataToInsert;
  }
}