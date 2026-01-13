import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/sql_table.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

class UserSettingsTable extends SqlTable {
  static final UserSettingsTable _instance = UserSettingsTable._internal();
  factory UserSettingsTable() => _instance;
  UserSettingsTable._internal();

  @override
  bool isTransient = false;

  @override
  bool requiresInboundSync = true;

  @override
  dynamic get additionalFiltersForInboundSync => {'user_id': SessionManager().userId};

  @override
  bool get useLastLoginForInboundSync => false;

  @override
  String get tableName => 'user_settings';

  @override
  List<String> get primaryKeyConstraints => ['user_id', 'setting_name'];

  @override
  List<Map<String, String>> get expectedColumns => [
    {'name': 'user_id',                   'type': 'TEXT NOT NULL'},
    {'name': 'setting_name',              'type': 'TEXT NOT NULL'},
    {'name': 'setting_value',             'type': 'TEXT'},
    {'name': 'is_admin_setting',          'type': 'INTEGER DEFAULT 0 NOT NULL'},
    {'name': 'has_been_synced',           'type': 'INTEGER DEFAULT 0'},
    {'name': 'edits_are_synced',          'type': 'INTEGER DEFAULT 0'},
    {'name': 'last_modified_timestamp',   'type': 'TEXT NOT NULL'},
  ];

  // --- Application-Defined Settings ---
  static const List<Map<String, dynamic>> _applicationSettings = [
    // ADMIN SETTINGS:
    {
      'name': 'geminiApiKey',
      'default_value': null,
      'is_admin_setting': true,
    },
    // GENERAL USER SETTINGS:
    {
      'name': 'home_display_eligible_questions',
      'default_value': "0",
      'is_admin_setting': false,
    },
    {
      'name': 'home_display_in_circulation_questions',
      'default_value': "0",
      'is_admin_setting': false,
    },
    {
      'name': 'home_display_non_circulating_questions',
      'default_value': "0",
      'is_admin_setting': false,
    },
    {
      'name': 'home_display_lifetime_total_questions_answered',
      'default_value': "0",
      'is_admin_setting': false,
    },
    {
      'name': 'home_display_daily_questions_answered',
      'default_value': "0",
      'is_admin_setting': false,
    },
    {
      'name': 'home_display_average_daily_questions_learned',
      'default_value': "0",
      'is_admin_setting': false,
    },
    {
      'name': 'home_display_average_questions_shown_per_day',
      'default_value': "0",
      'is_admin_setting': false,
    },
    {
      'name': 'home_display_days_left_until_questions_exhaust',
      'default_value': "0",
      'is_admin_setting': false,
    },
    {
      'name': 'home_display_revision_streak_score',
      'default_value': "0",
      'is_admin_setting': false,
    },
    {
      'name': 'home_display_last_reviewed',
      'default_value': "0",
      'is_admin_setting': false,
    },
  ];

  /// Exposes the application's hardcoded user settings specification.
  static List<Map<String, dynamic>> getApplicationUserSettings() {
    return _applicationSettings;
  }

  @override
  Future<bool> validateRecord(Map<String, dynamic> dataToInsert) async {
    const requiredFields = [
      'user_id', 'setting_name', 'last_modified_timestamp'
    ];

    for (final field in requiredFields) {
      if (!dataToInsert.containsKey(field) || dataToInsert[field] == null) {
        throw ArgumentError('Required field "$field" is missing or null');
      }
    }

    // Validate that setting_name is in application settings
    final settingName = dataToInsert['setting_name'];
    final isValidSetting = _applicationSettings.any((setting) => setting['name'] == settingName);
    if (!isValidSetting) {
      throw ArgumentError('Invalid setting name: "$settingName"');
    }

    return true;
  }

  @override
  Future<Map<String, dynamic>> finishRecord(Map<String, dynamic> dataToInsert) async {
    // Set last_modified_timestamp if not provided
    if (!dataToInsert.containsKey('last_modified_timestamp') || dataToInsert['last_modified_timestamp'] == null) {
      dataToInsert['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();
    }
    
    // Set sync flags for new/edited records
    dataToInsert['has_been_synced'] = 0;
    dataToInsert['edits_are_synced'] = 0;

    // Set is_admin_setting based on application settings
    final settingName = dataToInsert['setting_name'];
    final settingDefinition = _applicationSettings.firstWhere(
      (setting) => setting['name'] == settingName,
      orElse: () => {'is_admin_setting': false},
    );
    dataToInsert['is_admin_setting'] = settingDefinition['is_admin_setting'] ? 1 : 0;
    
    return dataToInsert;
  }

  // ==================================================
  // Business Logic Methods
  // ==================================================

  /// Resets a specific user setting to its application-defined initial value.
  Future<void> resetUserSettingToInitialValue(String userId, String settingName) async {
    final settingDefinition = _applicationSettings.firstWhere(
      (s) => s['name'] == settingName,
      orElse: () => {},
    );

    if (settingDefinition.isNotEmpty) {
      final dynamic initialValue = settingDefinition['default_value'];
      QuizzerLogger.logMessage('Resetting setting "$settingName" to initial value: $initialValue for user $userId.');
      
      // Use upsertRecord to reset the setting
      await upsertRecord({
        'user_id': userId,
        'setting_name': settingName,
        'setting_value': initialValue,
      });
    } else {
      QuizzerLogger.logWarning('Attempted to reset setting "$settingName", but it has no defined initial value in _applicationSettings.');
    }
  }

  /// Resets all application-defined user settings to their initial values for a specific user.
  Future<void> resetAllUserSettingsToInitialValues(String userId) async {
    QuizzerLogger.logMessage('Resetting all application-defined settings to their initial values for user $userId.');
    for (final settingMap in _applicationSettings) {
      final String settingName = settingMap['name'] as String;
      await resetUserSettingToInitialValue(userId, settingName);
    }
    QuizzerLogger.logSuccess('Finished resetting all application-defined settings for user $userId.');
  }
}