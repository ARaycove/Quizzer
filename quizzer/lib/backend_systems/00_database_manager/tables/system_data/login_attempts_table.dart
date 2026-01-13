import 'package:quizzer/backend_systems/00_database_manager/tables/sql_table.dart';
import 'package:quizzer/backend_systems/01_account_creation_and_management/account_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

class LoginAttemptsTable extends SqlTable {
  static final LoginAttemptsTable _instance = LoginAttemptsTable._internal();
  factory LoginAttemptsTable() => _instance;
  LoginAttemptsTable._internal();

  @override
  bool get isTransient => true;

  @override
  bool requiresInboundSync = false;

  @override
  dynamic get additionalFiltersForInboundSync => null;

  @override
  bool get useLastLoginForInboundSync => false;

  @override
  String get tableName => 'login_attempts';

  @override
  List<String> get primaryKeyConstraints => ['login_attempt_id'];
  
  @override
  List<Map<String, String>> get expectedColumns => [
    {'name': 'login_attempt_id', 'type': 'TEXT'},
    {'name': 'user_id', 'type': 'TEXT'},
    {'name': 'email', 'type': 'TEXT NOT NULL'},
    {'name': 'timestamp', 'type': 'TEXT NOT NULL'},
    {'name': 'status_code', 'type': 'TEXT NOT NULL'},
    {'name': 'ip_address', 'type': 'TEXT'},
    {'name': 'device_info', 'type': 'TEXT'},
    {'name': 'has_been_synced', 'type': 'INTEGER DEFAULT 0'},
    {'name': 'edits_are_synced', 'type': 'INTEGER DEFAULT 0'},
    {'name': 'last_modified_timestamp', 'type': 'TEXT'},
  ];

  @override
  Future<bool> validateRecord(Map<String, dynamic> dataToInsert) async {
    final String? email = dataToInsert['email'] as String?;
    final String? statusCode = dataToInsert['status_code'] as String?;

    if (email == null || email.isEmpty) {
      QuizzerLogger.logError('Login attempt validation failed: email is missing.');
      return false;
    }

    if (statusCode == null || statusCode.isEmpty) {
      QuizzerLogger.logError('Login attempt validation failed: status_code is missing.');
      return false;
    }
    return true;
  }

  @override
  Future<Map<String, dynamic>> finishRecord(Map<String, dynamic> dataToInsert) async {
    final String email = dataToInsert['email'] as String? ?? '';
    final String statusCode = dataToInsert['status_code'] as String? ?? '';
    
    if (email.isEmpty || statusCode.isEmpty) {
      QuizzerLogger.logError('Cannot finish login attempt record: missing email or status code.');
      return dataToInsert;
    }
    
    final String now = DateTime.now().toUtc().toIso8601String();
    
    // ALWAYS ensure login_attempt_id exists
    if (!dataToInsert.containsKey('login_attempt_id') || 
        dataToInsert['login_attempt_id'] == null || 
        (dataToInsert['login_attempt_id'] is String && (dataToInsert['login_attempt_id'] as String).isEmpty)) {
      // Generate a unique ID
      String? userId;
      try {
        userId = await AccountManager().getUserIdByEmail(email);
      } catch (e) {
        QuizzerLogger.logMessage("No user logged in, logging attempt anyway. . .\n $e");
      }
      
      final String idSuffix = userId ?? "FailedLoginAttempt"; 
      dataToInsert['login_attempt_id'] = now + idSuffix;
    }
    
    // ALWAYS ensure timestamp exists for new records
    if (!dataToInsert.containsKey('timestamp') || 
        dataToInsert['timestamp'] == null || 
        (dataToInsert['timestamp'] is String && (dataToInsert['timestamp'] as String).isEmpty)) {
      dataToInsert['timestamp'] = now;
    }
    
    // Fill in other data if missing
    if (!dataToInsert.containsKey('user_id') || dataToInsert['user_id'] == null) {
      String? userId;
      try {
        userId = await AccountManager().getUserIdByEmail(email);
      } catch (e) {
        // Already logged above
      }
      dataToInsert['user_id'] = userId;
    }
    
    if (!dataToInsert.containsKey('ip_address') || dataToInsert['ip_address'] == null) {
      dataToInsert['ip_address'] = await getUserIpAddress();
    }
    
    if (!dataToInsert.containsKey('device_info') || dataToInsert['device_info'] == null) {
      dataToInsert['device_info'] = await getDeviceInfo();
    }
    
    // For NEW records, set sync flags and timestamps
    // Check if this looks like a new record (no primary key was provided initially)
    final bool isNewRecord = !dataToInsert.containsKey('login_attempt_id') || 
                            dataToInsert['login_attempt_id'] == null ||
                            (dataToInsert['login_attempt_id'] is String && 
                            (dataToInsert['login_attempt_id'] as String).isEmpty);
    
    if (isNewRecord) {
      dataToInsert['last_modified_timestamp'] = now;
      dataToInsert['has_been_synced'] = 0;
      dataToInsert['edits_are_synced'] = 0;
    }
    
    return dataToInsert;
  }
  
}