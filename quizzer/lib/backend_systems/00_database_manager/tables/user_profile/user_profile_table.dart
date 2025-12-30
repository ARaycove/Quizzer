import 'package:uuid/uuid.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
// import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/sql_table.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

class UserProfileTable extends SqlTable {
  static final UserProfileTable _instance = UserProfileTable._internal();
  factory UserProfileTable() => _instance;
  UserProfileTable._internal();

  @override
  bool get isTransient => true;

  @override
  bool requiresInboundSync = true;

  @override
  dynamic get additionalFiltersForInboundSync => {'uuid': SessionManager().userId};

  @override
  bool get useLastLoginForInboundSync => false;
  
  @override
  String get tableName => 'user_profile';

  @override
  List<String> get primaryKeyConstraints => ['uuid', 'email'];
  
  @override
  List<Map<String, String>> get expectedColumns => [
    {'name': 'uuid',                  'type': 'TEXT'},
    {'name': 'username',              'type': 'TEXT'},
    {'name': 'email',                 'type': 'TEXT NOT NULL'},
    // Specific Account information
    {'name': 'role',                  'type': 'TEXT DEFAULT \'base_user\''},
    {'name': 'account_status',        'type': 'TEXT DEFAULT \'active\''},
    {'name': 'account_creation_date', 'type': 'TEXT NOT NULL'},
    {'name': 'last_login',            'type': 'TEXT'},
    // Education level indicators
    {'name': 'highest_level_edu',     'type': 'TEXT'},
    {'name': 'undergrad_major',       'type': 'TEXT'},
    {'name': 'undergrad_minor',       'type': 'TEXT'},
    {'name': 'grad_major',            'type': 'TEXT'},
    {'name': 'years_since_graduation','type': 'INTEGER'},
    {'name': 'education_background',  'type': 'TEXT'},
    {'name': 'teaching_experience',   'type': 'INTEGER'}, // How many years of teaching experience does the user have.

    // socio-cultural indicators
    {'name': 'profile_picture',       'type': 'TEXT'},
    {'name': 'country_of_origin',     'type': 'TEXT'},
    {'name': 'current_country',       'type': 'TEXT'},
    {'name': 'current_state',         'type': 'TEXT'},
    {'name': 'current_city',          'type': 'TEXT'},
    {'name': 'urban_rural',           'type': 'TEXT'}, // Is the address in a rural, suburban, or urban setting?
    {'name': 'religion',              'type': 'TEXT'},
    {'name': 'political_affilition',  'type': 'TEXT'},
    {'name': 'marital_status',        'type': 'TEXT'},
    {'name': 'num_children',          'type': 'INTEGER'},
    {'name': 'veteran_status',        'type': 'INTEGER'},
    {'name': 'native_language',       'type': 'TEXT'},
    {'name': 'secondary_languages',   'type': 'TEXT'},
    {'name': 'num_languages_spoken',  'type': 'INTEGER'},
    {'name': 'birth_date',            'type': 'TEXT'},
    {'name': 'age',                   'type': 'INTEGER'},
    {'name': 'household_income',      'type': 'REAL'},
    {'name': 'learning_disabilities', 'type': 'TEXT'}, // Array of learning disabilities (ADHD, Autism, Aspergers, etc)
    {'name': 'physical_disabilities', 'type': 'TEXT'}, // Array of physical disabilities (amputee, wheel-chair, crippled)
    {'name': 'housing_situation',     'type': 'TEXT'},
    {'name': 'birth_order',           'type': 'TEXT'},

    // Work experience
    {'name': 'current_occupation',    'type': 'TEXT'},
    {'name': 'years_work_experience', 'type': 'INTEGER'},
    {'name': 'hours_worked_per_week', 'type': 'REAL'},
    {'name': 'total_job_changes',     'type': 'INTEGER'},

    // Other
    {'name': 'notification_preferences', 'type': 'TEXT'},     //TODO should be a setting, leave here for now
    {'name': 'total_study_time', 'type': 'REAL DEFAULT 0.0'}, //TODO move to stat table
    {'name': 'average_session_length', 'type': 'REAL'},       //TODO move to stat table
    {'name': 'has_been_synced', 'type': 'INTEGER DEFAULT 0'},
    {'name': 'edits_are_synced', 'type': 'INTEGER DEFAULT 0'},
    {'name': 'last_modified_timestamp', 'type': 'TEXT'},
  ];
  
  @override
  Future<bool> validateRecord(Map<String, dynamic> dataToInsert) async {
    const requiredFields = [
      'email', 'account_creation_date'
    ];

    for (final field in requiredFields) {
      final value = dataToInsert[field];
      if (value == null || (value is String && value.isEmpty)) {
        QuizzerLogger.logError('Validation failed for user profile: Missing required field: $field.');
        return false;
      }
    }

    // Validate email format if present
    if (dataToInsert.containsKey('email')) {
      final email = dataToInsert['email'] as String;
      if (!_isValidEmail(email)) {
        QuizzerLogger.logError('Validation failed for user profile: Invalid email format: $email');
        return false;
      }
    }

    return true;
  }

  @override
  Future<Map<String, dynamic>> finishRecord(Map<String, dynamic> dataToInsert) async {
    // 1. Validate/Generate UUID
    if (!dataToInsert.containsKey('uuid') || dataToInsert['uuid'] == null) {
      dataToInsert['uuid'] = _generateUserUUID();
    }
    // 2. Set last_modified_timestamp
    dataToInsert['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();
    // 3. Set creation date if it's a new record
    if (!dataToInsert.containsKey('account_creation_date') || dataToInsert['account_creation_date'] == null) {
      dataToInsert['account_creation_date'] = DateTime.now().toUtc().toIso8601String();
    }
    // 4. Set sync flags for new/edited records
    dataToInsert['has_been_synced'] = 0;
    dataToInsert['edits_are_synced'] = 0;
    return dataToInsert;
  }

  /// Generates a unique UUID for a new user
  String _generateUserUUID() {
    const uuid = Uuid();
    final generatedUUID = uuid.v4();
    QuizzerLogger.logMessage('Generated new UUID: $generatedUUID');
    return generatedUUID;
  }

  /// Validates email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  // ==================================================
  // Public API Methods
  // ==================================================

  /// Updates the total_study_time for a user by adding the specified amount of hours.
  Future<void> updateTotalStudyTime(String userUuid, double hoursToAdd) async {
    try {
      QuizzerLogger.logMessage('Updating total_study_time for User: $userUuid, adding: $hoursToAdd hours');
      
      final double daysToAdd = hoursToAdd / 24.0;
      final results = await getRecord('SELECT total_study_time FROM $tableName WHERE uuid = "$userUuid"');
      
      if (results.isEmpty) {
        throw Exception('User not found: $userUuid');
      }

      final currentStudyTime = results.first['total_study_time'] as double? ?? 0.0;
      final newStudyTime = currentStudyTime + daysToAdd;
      
      await upsertRecord({
        'uuid': userUuid,
        'total_study_time': newStudyTime,
      });
      
      QuizzerLogger.logSuccess('Successfully updated total_study_time for User: $userUuid (added $daysToAdd days)');
    } catch (e) {
      QuizzerLogger.logError('Error updating total study time for user: $userUuid - $e');
      rethrow;
    }
  }
}