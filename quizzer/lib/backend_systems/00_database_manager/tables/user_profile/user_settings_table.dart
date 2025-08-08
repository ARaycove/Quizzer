import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart'; // Universal DB helpers

// --- Application-Defined Settings ---
// Defines the settings that must exist for every user and their initial values.
const List<Map<String, dynamic>> _applicationSettings = [
  // Group admin seetings first
  // ADMIN SETTINGS:
  // =====================================
  {
    'name': 'geminiApiKey',
    'default_value': null, // Initial value is null, user needs to input their key
    'is_admin_setting': true,
  },
  // GENERAL USER SETTINGS:
  // =====================================
  // Home page display settings for stats
  // Show eligible questions count on home page
  {
    'name': 'home_display_eligible_questions',
    'default_value': false,
    'is_admin_setting': false,
  },
  // Show in circulation questions count on home page
  {
    'name': 'home_display_in_circulation_questions',
    'default_value': false,
    'is_admin_setting': false,
  },
  // Show non-circulating questions count on home page
  {
    'name': 'home_display_non_circulating_questions',
    'default_value': false,
    'is_admin_setting': false,
  },
  // Show lifetime total questions answered on home page
  {
    'name': 'home_display_lifetime_total_questions_answered',
    'default_value': false,
    'is_admin_setting': false,
  },
  // Show daily questions answered on home page
  {
    'name': 'home_display_daily_questions_answered',
    'default_value': false,
    'is_admin_setting': false,
  },
  // Show average daily questions learned on home page
  {
    'name': 'home_display_average_daily_questions_learned',
    'default_value': false,
    'is_admin_setting': false,
  },
  // Show average questions shown per day on home page
  {
    'name': 'home_display_average_questions_shown_per_day',
    'default_value': false,
    'is_admin_setting': false,
  },
  // Show days left until questions exhaust on home page
  {
    'name': 'home_display_days_left_until_questions_exhaust',
    'default_value': false,
    'is_admin_setting': false,
  },
  // Show current revision streak score on home page
  {
    'name': 'home_display_revision_streak_score',
    'default_value': false,
    'is_admin_setting': false,
  },
  // Show last reviewed date on home page
  {
    'name': 'home_display_last_reviewed',
    'default_value': false,
    'is_admin_setting': false,
  },
];
// TODO Designing a stat/info display for home page
// Add the following settings 
// [x] one for each stat
// [x] Update settings page to allow toggling of these boolean settings added
// settings page should not use the field names directly and should be user readable. BECAUSE THERES A FUCKING DIFFERENCE BETWEEN REGULAR HUMAN READABLE TEXT AND CAMEL CASE AND SNAKE CASE non-technical users don't want to see that bullshit

// [x] update SessionManager to store current stats in memory
// [x] For each display setting, create a private variable and getter for that variable in the SessionManager, should be clean and organized in it's own section to make the now very Large SessionManager object more readable. 
// [x] setup how the SessionManager will get that information
// - update after any stat update call
// - closer to the source, have each individual update stat function do the update in the sessionmanager itself rather than additional queries. Thus while that function has the current value in memory, it will store it in the session manager in addition to writing it to the DB through the sql update

// TODO Design a stat_block widget for each display setting (use a template, that handles different data types and displays accordingly)

// TODO Design a stat_display widget to place in the home_page

const String _tableName = 'user_settings';

// --- Internal Helper: Ensure Setting Rows Exist ---

/// Ensures that all application-defined settings rows exist for a given user.
/// If a setting from `_applicationSettings` is not present for the user,
/// it's inserted with its predefined initial value. This does NOT overwrite existing settings.
Future<void> _ensureUserSettingsRowsExist(String userId, Database db) async {
  for (final settingMap in _applicationSettings) {
    final String settingName = settingMap['name'] as String;
    final dynamic initialValue = settingMap['default_value'];
    final bool isAdminSetting = settingMap['is_admin_setting'] as bool? ?? false;

    // Get ALL records from the table and check if this setting exists
    final List<Map<String, dynamic>> allRecords = await queryAndDecodeDatabase(
      _tableName,
      db,
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    final bool settingExists = allRecords.any((record) => record['setting_name'] == settingName);

    if (settingExists) {
      continue;
    }

    // Convert boolean values to integers for database storage
    dynamic dbValue = initialValue;
    if (initialValue is bool) {
      dbValue = initialValue ? 1 : 0;
    }
    
    final int result = await insertRawData(
      _tableName,
      {
        'user_id': userId,
        'setting_name': settingName,
        'setting_value': dbValue,
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': DateTime(1970, 1, 1).toUtc().toIso8601String(),
        'is_admin_setting': isAdminSetting ? 1 : 0,
      },
      db
    );
    
    if (result > 0) {
      QuizzerLogger.logSuccess('_ensureUserSettingsRowsExist: Successfully inserted setting "$settingName" for user $userId');
    }
  }
}

// --- Table Verification & Initialization ---

/// Verifies that the user_settings table exists and creates it if not.
/// Also ensures that all application-defined setting rows exist for the given user.
/// [skipEnsureRows] - When true, skips calling _ensureUserSettingsRowsExist (used during inbound sync)
Future<void> _verifyUserSettingsTable(String userId, Database db, {bool skipEnsureRows = false}) async {
  await db.execute('PRAGMA foreign_keys = ON;');
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
    [_tableName]
  );

  if (tables.isEmpty) {
    QuizzerLogger.logMessage('User settings table does not exist, creating it.');
    await db.execute('''
      CREATE TABLE $_tableName (
        user_id TEXT NOT NULL,
        setting_name TEXT NOT NULL,
        setting_value TEXT,
        has_been_synced INTEGER DEFAULT 0,
        edits_are_synced INTEGER DEFAULT 0,
        last_modified_timestamp TEXT NOT NULL,
        is_admin_setting INTEGER DEFAULT 0 NOT NULL,
        PRIMARY KEY (user_id, setting_name),
        FOREIGN KEY (user_id) REFERENCES user_profile (uuid) ON DELETE CASCADE
      )
    ''');
    QuizzerLogger.logSuccess('User settings table created successfully.');
  } else {
    // Check if is_admin_setting column exists, add if not (for existing databases)
    final List<Map<String, dynamic>> columns = await db.rawQuery(
      "PRAGMA table_info($_tableName)"
    );
    final Set<String> columnNames = columns.map((column) => column['name'] as String).toSet();
    if (!columnNames.contains('is_admin_setting')) {
      QuizzerLogger.logMessage('Adding is_admin_setting column to $_tableName table.');
      await db.execute('ALTER TABLE $_tableName ADD COLUMN is_admin_setting INTEGER DEFAULT 0 NOT NULL');
      QuizzerLogger.logSuccess('Added is_admin_setting column to $_tableName table.');
    }
  }
  
  // Always ensure all setting rows exist for the user (handles new settings being added)
  // Skip this during inbound sync to prevent overwriting cloud data
  if (!skipEnsureRows) {
    await _ensureUserSettingsRowsExist(userId, db);
  }
}

// --- CRUD Operations & Reset Logic ---

/// Retrieves the value of a specific setting for a user.
/// Returns a map containing 'value' and 'is_admin_setting' (as int 0 or 1), or null if not found.
Future<Map<String, dynamic>?> getSettingValue(String userId, String settingName) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await _verifyUserSettingsTable(userId, db!); // Ensures table and all rows are initialized
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      _tableName,
      db,
      columns: ['setting_value', 'is_admin_setting'],
      where: 'user_id = ? AND setting_name = ?',
      whereArgs: [userId, settingName],
      limit: 1,
    );

    if (results.isNotEmpty) {
      // Return a map with the value and the admin flag
      return {
        'value': results.first['setting_value'],
        'is_admin_setting': results.first['is_admin_setting'] as int? ?? 0, // Default to 0 if null
      };
    }
    // This case should be rare if verifyUserSettingsTable works correctly with _ensureUserSettingsRowsExist
    QuizzerLogger.logWarning('Setting "$settingName" not found for user $userId after verification.');
    return null;
  } catch (e) {
    QuizzerLogger.logError('Error getting setting value for user ID: $userId, setting: $settingName - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Retrieves all settings for a user.
/// Returns a map where keys are setting_names and values are maps containing
/// 'value' (the setting's value) and 'is_admin_setting' (int 0 or 1).
Future<Map<String, Map<String, dynamic>>> getAllUserSettings(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await _verifyUserSettingsTable(userId, db!); // Ensures table and all rows are initialized
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      _tableName,
      db,
      columns: ['setting_name', 'setting_value', 'is_admin_setting'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    final Map<String, Map<String, dynamic>> userSettings = {};
    for (final row in results) {
      final String settingName = row['setting_name'] as String;
      userSettings[settingName] = {
        'value': row['setting_value'],
        'is_admin_setting': row['is_admin_setting'] as int? ?? 0, // Default to 0 if null
      };
    }
    return userSettings;
  } catch (e) {
    QuizzerLogger.logError('Error getting all user settings for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}
// ======================================================================================
// Update function
/// Updates a specific setting for a user.
/// The new value will be encoded by the table_helper.
/// Sets edits_are_synced to 0 and updates last_modified_timestamp.
/// [skipSyncFlags] - When true, skips updating sync flags and timestamp (used during inbound sync)
/// [cloudTimestamp] - When skipSyncFlags is true, use this timestamp instead of current time
Future<int> updateUserSetting(String userId, String settingName, dynamic newValue, {bool skipSyncFlags = false, String? cloudTimestamp}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await _verifyUserSettingsTable(userId, db!); // Ensures table and row exist before update attempt

    final Map<String, dynamic> dataToUpdate = {
      'setting_value': newValue,
    };
    
    // Only update sync flags and timestamp if not skipping
    if (!skipSyncFlags) {
      final String nowTimestamp = DateTime.now().toUtc().toIso8601String();
      dataToUpdate['edits_are_synced'] = 0;
      dataToUpdate['last_modified_timestamp'] = nowTimestamp;
    } else {
      // When skipping sync flags, set them to 1 (synced) and use cloud timestamp
      dataToUpdate['has_been_synced'] = 1;
      dataToUpdate['edits_are_synced'] = 1;
      if (cloudTimestamp != null) {
        dataToUpdate['last_modified_timestamp'] = cloudTimestamp;
      }
    }

    final int rowsAffected = await updateRawData(
      _tableName,
      dataToUpdate,
      'user_id = ? AND setting_name = ?',
      [userId, settingName],
      db,
    );

    if (rowsAffected > 0) {
      QuizzerLogger.logSuccess('Setting "$settingName" updated for user $userId.');
      if (!skipSyncFlags) {
        signalOutboundSyncNeeded();
      }
    } else {
      QuizzerLogger.logWarning('Failed to update setting "$settingName" for user $userId. Setting or user may not exist, or value was the same.');
    }
    return rowsAffected;
  } catch (e) {
    QuizzerLogger.logError('Error updating user setting for user ID: $userId, setting: $settingName - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Resets a specific user setting to its application-defined initial value.
Future<void> resetUserSettingToInitialValue(String userId, String settingName) async {
  final settingDefinition = _applicationSettings.firstWhere(
    (s) => s['name'] == settingName,
    orElse: () => {},
  );

  if (settingDefinition.isNotEmpty) {
    final dynamic initialValue = settingDefinition['default_value'];
    QuizzerLogger.logMessage('Resetting setting "$settingName" to initial value: $initialValue for user $userId.');
    await updateUserSetting(userId, settingName, initialValue);
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

// --- Sync-related Functions ---
Future<List<Map<String, dynamic>>> getUnsyncedUserSettings(String userId, {bool skipEnsureRows = false}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await _verifyUserSettingsTable(userId, db!, skipEnsureRows: skipEnsureRows); // Ensures table and rows exist
    final List<Map<String, dynamic>> results = await db.query(
      _tableName,
      where: 'user_id = ? AND (has_been_synced = 0 OR edits_are_synced = 0)',
      whereArgs: [userId],
    );
    QuizzerLogger.logSuccess('Fetched ${results.length} unsynced settings for user $userId.');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced user settings for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Updates the synchronization flags for a specific user setting.
/// updateSyncFlags functions are used by the outbound sync worker to updat sync status
/// Does NOT trigger a new sync signal, as this is usually called after a sync operation.
Future<void> updateUserSettingSyncFlags({
  required String userId,
  required String settingName,
  required bool hasBeenSynced,
  required bool editsAreSynced,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await _verifyUserSettingsTable(userId, db!); // Ensure table/columns exist

    final Map<String, dynamic> updates = {
      'has_been_synced': hasBeenSynced ? 1 : 0,
      'edits_are_synced': editsAreSynced ? 1 : 0,
      // We typically DO NOT update last_modified_timestamp when only changing sync flags.
    };

    final int rowsAffected = await updateRawData(
      _tableName,
      updates,
      'user_id = ? AND setting_name = ?',
      [userId, settingName],
      db,
    );

    if (rowsAffected == 0) {
      QuizzerLogger.logWarning('updateUserSettingSyncFlags affected 0 rows for User: $userId, Setting: $settingName. Record might not exist?');
    } else {
      QuizzerLogger.logSuccess('Successfully updated sync flags for User: $userId, Setting: $settingName.');
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating sync flags for User: $userId, Setting: $settingName - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// --- Function to Insert or Update from Cloud ---
/// Takes cloud data and overwrites local data. No timestamp checking, no conditionals.
/// Cloud is the source of truth during inbound sync.
Future<void> upsertUserSettingsFromSupabase(Map<String, dynamic> settingData) async {
  try {
    QuizzerLogger.logMessage('upsertUserSettingsFromSupabase: Starting with data: $settingData');
    
    final String? userId = settingData['user_id'] as String?;
    final String? settingName = settingData['setting_name'] as String?;
    final dynamic settingValue = settingData['setting_value'];
    final String? cloudLastModifiedTimestamp = settingData['last_modified_timestamp'] as String?;
    
    QuizzerLogger.logMessage('upsertUserSettingsFromSupabase: Parsed values - userId: $userId, settingName: $settingName, settingValue: $settingValue, timestamp: $cloudLastModifiedTimestamp');
    
    // Parse is_admin_setting
    int isAdminSettingValue = 0;
    if (settingData.containsKey('is_admin_setting')) {
      final dynamic cloudAdminFlag = settingData['is_admin_setting'];
      if (cloudAdminFlag is bool) {
        isAdminSettingValue = cloudAdminFlag ? 1 : 0;
      } else if (cloudAdminFlag is int) {
        isAdminSettingValue = (cloudAdminFlag == 1) ? 1 : 0;
      }
    } else if (settingName != null) {
      final appSettingDef = _applicationSettings.firstWhere(
        (s) => s['name'] == settingName,
        orElse: () => {},
      );
      if (appSettingDef.isNotEmpty && appSettingDef.containsKey('is_admin_setting')) {
        isAdminSettingValue = (appSettingDef['is_admin_setting'] as bool? ?? false) ? 1 : 0;
      }
    }

    assert(userId != null, 'upsertUserSettingsFromSupabase: userId cannot be null');
    assert(settingName != null, 'upsertUserSettingsFromSupabase: settingName cannot be null');
    assert(cloudLastModifiedTimestamp != null, 'upsertUserSettingsFromSupabase: lastModifiedTimestamp cannot be null');

    QuizzerLogger.logMessage('upsertUserSettingsFromSupabase: Assertions passed, getting database access...');
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    QuizzerLogger.logMessage('upsertUserSettingsFromSupabase: Got database access, verifying table...');
    await _verifyUserSettingsTable(userId!, db!, skipEnsureRows: true);
    QuizzerLogger.logMessage('upsertUserSettingsFromSupabase: Table verified');

    final Map<String, dynamic> dataToInsertOrUpdate = {
      'user_id': userId,
      'setting_name': settingName,
      'setting_value': settingValue,
      'has_been_synced': 1,
      'edits_are_synced': 1,
      'last_modified_timestamp': cloudLastModifiedTimestamp,
      'is_admin_setting': isAdminSettingValue,
    };

    QuizzerLogger.logMessage('upsertUserSettingsFromSupabase: About to insert/update with data: $dataToInsertOrUpdate');
    QuizzerLogger.logMessage('upsertUserSettingsFromSupabase: Using ConflictAlgorithm.replace');

    final int result = await insertRawData(
      _tableName,
      dataToInsertOrUpdate,
      db,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    QuizzerLogger.logMessage('upsertUserSettingsFromSupabase: insertRawData returned: $result');
    QuizzerLogger.logSuccess('Overwrote setting "$settingName" with $settingValue for user $userId with cloud data');
  } catch (e) {
    QuizzerLogger.logError('Error upserting from Supabase - $e');
    QuizzerLogger.logError('upsertUserSettingsFromSupabase: Stack trace: ${StackTrace.current}');
    rethrow;
  } finally {
    QuizzerLogger.logMessage('upsertUserSettingsFromSupabase: Releasing database access');
    getDatabaseMonitor().releaseDatabaseAccess();
    QuizzerLogger.logMessage('upsertUserSettingsFromSupabase: Completed');
  }
}

// --- Batch Function to Insert or Update Multiple Settings from Cloud ---
/// Takes a list of cloud data and overwrites local data in a single transaction.
/// Cloud is the source of truth during inbound sync.
Future<void> batchUpsertUserSettingsFromSupabase(List<Map<String, dynamic>> settingsData, String userId) async {
  if (settingsData.isEmpty) {
    QuizzerLogger.logMessage('batchUpsertUserSettingsFromSupabase: No settings to upsert');
    return;
  }

  try {
    QuizzerLogger.logMessage('Received Data, settingsData: $settingsData');
    QuizzerLogger.logMessage('batchUpsertUserSettingsFromSupabase: Starting batch upsert of ${settingsData.length} settings');
    
    assert(userId.isNotEmpty, 'batchUpsertUserSettingsFromSupabase: userId cannot be empty');

    final db = await getDatabaseMonitor().requestDatabaseAccess();
    QuizzerLogger.logMessage('batchUpsertUserSettingsFromSupabase: Got database access, verifying table...');
    await _verifyUserSettingsTable(userId, db!, skipEnsureRows: false); // Don't skip ensure - create default settings first
    QuizzerLogger.logMessage('batchUpsertUserSettingsFromSupabase: Table verified and default settings ensured');

    // Loop through each setting and update it using direct database operations
    for (final settingData in settingsData) {
      final String? settingName = settingData['setting_name'] as String?;
      final dynamic settingValue = settingData['setting_value'];
      final String? cloudLastModifiedTimestamp = settingData['last_modified_timestamp'] as String?;

      if (!_applicationSettings.any((setting) => setting['name'] == settingName)) {
        QuizzerLogger.logWarning('batchUpsertUserSettingsFromSupabase: Skipping invalid setting "$settingName" - not a valid application setting');
        continue;
      }
      if (cloudLastModifiedTimestamp == null) {
        QuizzerLogger.logWarning('batchUpsertUserSettingsFromSupabase: Skipping setting "$settingName" - missing lastModifiedTimestamp');
        continue;
      }

      QuizzerLogger.logMessage('batchUpsertUserSettingsFromSupabase: Updating setting "$settingName" with value $settingValue');
      
      // Use direct database update - settings already exist from _ensureUserSettingsRowsExist
      final Map<String, dynamic> dataToUpdate = {
        'setting_value': settingValue,
        'has_been_synced': 1,
        'edits_are_synced': 1,
        'last_modified_timestamp': cloudLastModifiedTimestamp,
      };

      final int result = await updateRawData(
        _tableName,
        dataToUpdate,
        'user_id = ? AND setting_name = ?',
        [userId, settingName],
        db,
      );
      
      QuizzerLogger.logMessage('batchUpsertUserSettingsFromSupabase: Setting "$settingName" update result: $result');
    }

    QuizzerLogger.logSuccess('batchUpsertUserSettingsFromSupabase: Successfully batch upserted ${settingsData.length} settings for user $userId');
  } catch (e) {
    QuizzerLogger.logError('batchUpsertUserSettingsFromSupabase: Error - $e');
    QuizzerLogger.logError('batchUpsertUserSettingsFromSupabase: Stack trace: ${StackTrace.current}');
    rethrow;
  } finally {
    QuizzerLogger.logMessage('batchUpsertUserSettingsFromSupabase: Releasing database access');
    getDatabaseMonitor().releaseDatabaseAccess();
    QuizzerLogger.logMessage('batchUpsertUserSettingsFromSupabase: Completed');
  }
}
