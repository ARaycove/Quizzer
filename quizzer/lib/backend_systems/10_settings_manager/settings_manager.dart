import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_settings_table.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

class SettingsManager {
  static final SettingsManager _instance = SettingsManager._internal();
  factory SettingsManager() => _instance;
  SettingsManager._internal();

  // Cache structure: userId -> {settingName -> {details}}
  final Map<String, dynamic> _settingsCache = {};

  bool _initializedForUser = false;

  // ================================================================================
  // Public API
  // ================================================================================
  /// Unified method to get user settings with three modes: single, list, or all.
  /// 
  /// Args:
  ///   userId: The user ID to get settings for
  ///   settingName: Get a single setting by name (optional)
  ///   settingNames: Get multiple settings by name list (optional)
  ///   getAll: Get all settings for the user (optional)
  ///   includeAdminFlag: If true, returns Map<String, dynamic> with 'setting_value' and 'is_admin_setting'
  ///                     If false, returns just the setting value (String/dynamic)
  /// 
  /// Returns:
  ///   - For getAll: Map<String, dynamic> where key is setting_name and value is either:
  ///                 * Just the setting_value (if includeAdminFlag = false)
  ///                 * Map with 'setting_value' and 'is_admin_setting' (if includeAdminFlag = true)
  ///   - For settingName: Either the setting value or Map with details (based on includeAdminFlag)
  ///   - For settingNames: Map<String, dynamic> with requested settings
  /// 
  /// Throws:
  ///   ArgumentError if more than one mode is specified or no mode is specified
  Future<dynamic> getUserSettings({
    String? settingName,
    List<String>? settingNames,
    bool getAll = false,
    bool includeAdminFlag = false,
  }) async {
    // Validate exactly one mode is specified
    final int modesSpecified = (settingName != null ? 1 : 0) +
                              (settingNames != null ? 1 : 0) +
                              (getAll ? 1 : 0);
    
    if (modesSpecified == 0) {
      throw ArgumentError('No mode specified. Provide settingName, settingNames, or set getAll to true.');
    }
    if (modesSpecified > 1) {
      throw ArgumentError('Multiple modes specified. Only one of settingName, settingNames, or getAll can be used.');
    }

    if (getAll) {
      final settings = await _getAllSettings();
      return settings;
    } 
    else if (settingName != null) {
      final setting = await _getSingleSetting(settingName);
      return setting;
    } 
    else { // settingNames != null
      final result = <String, dynamic>{};
      for (final name in settingNames!) {
        final setting = await _getSingleSetting(name);
        if (setting != null) {
          result[name] = setting;
        }
      }
      return result;
    }
  }

  Future<int> updateUserSetting(String settingName, dynamic newValue) async {
    try {
      QuizzerLogger.logMessage('SettingsManager: Updating setting "$settingName" for user ${SessionManager().userId} to: $newValue');
      
      final result = await UserSettingsTable().upsertRecord({
        'user_id': SessionManager().userId,
        'setting_name': settingName,
        'setting_value': newValue,
      });
      
      _updateCache(settingName, newValue);
      return result;
      
    } catch (e) {
      QuizzerLogger.logError('Error in SettingsManager.updateUserSetting - $e');
      rethrow;
    }
  }

  Future<void> resetSettingToDefault(String settingName) async {
    try {
      QuizzerLogger.logMessage('SettingsManager: Resetting setting "$settingName" to default for user ${SessionManager().userId}');
      
      await UserSettingsTable().resetUserSettingToInitialValue(
        SessionManager().userId!,
        settingName,
      );

      // Update cache with default value
      final appSettings = UserSettingsTable.getApplicationUserSettings();
      final settingDef = appSettings.firstWhere(
        (s) => s['name'] == settingName,
        orElse: () => {},
      );
      
      if (settingDef.isNotEmpty) {
        _updateCache(settingName, settingDef['default_value']);
      }
      
    } catch (e) {
      QuizzerLogger.logError('Error in SettingsManager.resetSettingToDefault - $e');
      rethrow;
    }
  }

  Future<void> resetAllSettingsToDefaults() async {
    try {
      QuizzerLogger.logMessage('SettingsManager: Resetting all settings to defaults for user ${SessionManager().userId}');
      
      await UserSettingsTable().resetAllUserSettingsToInitialValues(
        SessionManager().userId!,
      );

      // Update cache with all default values
      final appSettings = UserSettingsTable.getApplicationUserSettings();
      for (final settingDef in appSettings) {
        _updateCache(settingDef['name'] as String, settingDef['default_value']);
      }
      
    } catch (e) {
      QuizzerLogger.logError('Error in SettingsManager.resetAllSettingsToDefaults - $e');
      rethrow;
    }
  }

  /// Call on logout
  void clearSettingsCache() {_settingsCache.clear();_initializedForUser = false;}

  // ================================================================================
  // Private Helper Functionality
  // ================================================================================
  
  /// Private helper: Gets a single setting with default creation if needed
  Future<Map<String, dynamic>?> _getSingleSetting(String settingName) async {
    if (!_initializedForUser) {
      await _initializeUserSettings();
    }
    
    return _settingsCache[settingName];
  }

  /// Private helper: Gets all settings with default creation for missing ones
  Future<Map<String, dynamic>> _getAllSettings() async {
    if (!_initializedForUser) {
      await _initializeUserSettings();
    }
    
    return Map<String, dynamic>.from(_settingsCache);
  }

  void _updateCache(String settingName, dynamic value) {
    _settingsCache[settingName] = value;
  }

  Future<void> _initializeUserSettings() async {
    try {
      final appSettings = UserSettingsTable.getApplicationUserSettings();
      final userRole = SessionManager().userRole;
      final isAdmin = userRole == 'admin' || userRole == 'contributor';
      
      for (final settingDef in appSettings) {
        final settingName = settingDef['name'] as String;
        final isAdminSetting = settingDef['is_admin_setting'] == true;
        
        // Skip admin settings for non-admin users
        if (isAdminSetting && !isAdmin) {
          continue;
        }
        
        final defaultVal = settingDef['default_value'];
        
        final results = await UserSettingsTable().getRecord(
          'SELECT * FROM user_settings WHERE user_id = "${SessionManager().userId}" AND setting_name = "$settingName"'
        );
        
        if (results.isEmpty) {
          await UserSettingsTable().upsertRecord({
            'user_id': SessionManager().userId,
            'setting_name': settingName,
            'setting_value': defaultVal,
          });
          
          _updateCache(settingName, defaultVal);
        } else {
          _updateCache(settingName, results.first['setting_value']);
        }
      }
      _initializedForUser = true;
    } catch (e) {
      QuizzerLogger.logError('Error initializing user settings - $e');
      rethrow;
    }
  }
}