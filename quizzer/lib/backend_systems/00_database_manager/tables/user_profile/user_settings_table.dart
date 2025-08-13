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
    'default_value': "0",
    'is_admin_setting': false,
  },
  // Show in circulation questions count on home page
  {
    'name': 'home_display_in_circulation_questions',
    'default_value': "0",
    'is_admin_setting': false,
  },
  // Show non-circulating questions count on home page
  {
    'name': 'home_display_non_circulating_questions',
    'default_value': "0",
    'is_admin_setting': false,
  },
  // Show lifetime total questions answered on home page
  {
    'name': 'home_display_lifetime_total_questions_answered',
    'default_value': "0",
    'is_admin_setting': false,
  },
  // Show daily questions answered on home page
  {
    'name': 'home_display_daily_questions_answered',
    'default_value': "0",
    'is_admin_setting': false,
  },
  // Show average daily questions learned on home page
  {
    'name': 'home_display_average_daily_questions_learned',
    'default_value': "0",
    'is_admin_setting': false,
  },
  // Show average questions shown per day on home page
  {
    'name': 'home_display_average_questions_shown_per_day',
    'default_value': "0",
    'is_admin_setting': false,
  },
  // Show days left until questions exhaust on home page
  {
    'name': 'home_display_days_left_until_questions_exhaust',
    'default_value': "0",
    'is_admin_setting': false,
  },
  // Show current revision streak score on home page
  {
    'name': 'home_display_revision_streak_score',
    'default_value': "0",
    'is_admin_setting': false,
  },
  // Show last reviewed date on home page
  {
    'name': 'home_display_last_reviewed',
    'default_value': "0",
    'is_admin_setting': false,
  },
];
const String _tableName = 'user_settings';

/// Exposes the application's hardcoded user settings specification.
/// Returns the const list of setting definitions used to initialize and verify settings.
/// Each entry contains: {'name': String, 'default_value': dynamic, 'is_admin_setting': bool}
List<Map<String, dynamic>> getApplicationUserSettings() {
  return _applicationSettings;
}

// --- Table Verification & Initialization ---

/// Verifies that the user_settings table exists and creates it if not.
/// Also ensures that all application-defined setting rows exist for the given user.
/// This function handles its own database access and transaction management.
/// [skipEnsureRows] - When true, skips calling _ensureUserSettingsRowsExist (used during inbound sync)
Future<void> verifyUserSettingsTable(dynamic db) async {
  await db.execute('PRAGMA foreign_keys = ON;');
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='user_settings'"
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
  }
  else {
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
}

// --- CRUD Operations & Reset Logic ---

/// Retrieves the value of a specific setting for a user.
/// Returns a map containing 'value' and 'is_admin_setting' (as int 0 or 1), or null if not found.
Future<Map<String, dynamic>?> getSettingValue(String userId, String settingName) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    
    // Query for existing setting record
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      _tableName,
      db,
      columns: ['setting_value', 'is_admin_setting'],
      where: 'user_id = ? AND setting_name = ?',
      whereArgs: [userId, settingName],
      limit: 1,
    );

    if (results.isNotEmpty) {
      // Return existing setting from database
      return {
        'value': results.first['setting_value'],
        'is_admin_setting': results.first['is_admin_setting'] as int? ?? 0,
      };
    } else {
      // No database record exists, return default value from _applicationSettings
      final defaultSetting = _applicationSettings.firstWhere(
        (setting) => setting['name'] == settingName,
        orElse: () => {},
      );
      
      if (defaultSetting.isNotEmpty) {
        return {
          'value': defaultSetting['default_value'],
          'is_admin_setting': defaultSetting['is_admin_setting'] ? 1 : 0,
        };
      }
      
      // Setting not found in either database or defaults
      QuizzerLogger.logWarning('Setting "$settingName" not found for user $userId in database or defaults.');
      return null;
    }
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
    QuizzerLogger.logMessage('getAllUserSettings: Starting for user $userId');
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    QuizzerLogger.logMessage('getAllUserSettings: Got database access for user $userId');
    
    // Query for existing settings from database
    QuizzerLogger.logMessage('getAllUserSettings: About to query database for user $userId');
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      _tableName,
      db,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    
    QuizzerLogger.logMessage('getAllUserSettings: Raw database results for user $userId: $results');
    QuizzerLogger.logMessage('getAllUserSettings: Number of results: ${results.length}');

    final Map<String, Map<String, dynamic>> userSettings = {};
    
    // Add existing database settings
    for (final row in results) {
      final String settingName = row['setting_name'] as String;
      QuizzerLogger.logMessage('getAllUserSettings: Processing row for setting: $settingName, value: ${row['setting_value']}');
      userSettings[settingName] = {
        'setting_value': row['setting_value'],
        'is_admin_setting': row['is_admin_setting'] as int? ?? 0,
      };
    }
    
    QuizzerLogger.logMessage('getAllUserSettings: Processed userSettings map: $userSettings');
    
    // Add default values for any missing settings
    for (final defaultSetting in _applicationSettings) {
      final String settingName = defaultSetting['name'] as String;
      if (!userSettings.containsKey(settingName)) {
        QuizzerLogger.logMessage('getAllUserSettings: Adding default for missing setting: $settingName, value: ${defaultSetting['default_value']}');
        userSettings[settingName] = {
          'setting_value': defaultSetting['default_value'],
          'is_admin_setting': defaultSetting['is_admin_setting'] ? 1 : 0,
        };
      }
    }
    
    QuizzerLogger.logMessage('getAllUserSettings: FINAL RESULT for user $userId: $userSettings');
    return userSettings;
  } catch (e) {
    QuizzerLogger.logError('Error getting all user settings for user ID: $userId - $e');
    QuizzerLogger.logError('Stack trace: ${StackTrace.current}');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
    QuizzerLogger.logMessage('getAllUserSettings: Released database access for user $userId');
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
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }

    // Use upsertRawData to handle both insert and update cases
    final settingDefinition = _applicationSettings.firstWhere(
      (s) => s['name'] == settingName,
      orElse: () => {'is_admin_setting': false},
    );
    
    final Map<String, dynamic> dataToUpdate = {
      'user_id': userId,
      'setting_name': settingName,
      'setting_value': newValue,
      'is_admin_setting': settingDefinition['is_admin_setting'] as bool? ?? false,
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

    final int rowsAffected = await upsertRawData(
      _tableName,
      dataToUpdate,
      db,
    );

    if (rowsAffected > 0) {
      QuizzerLogger.logSuccess('Setting "$settingName" upserted for user $userId.');
      if (!skipSyncFlags) {
        signalOutboundSyncNeeded();
      }
    } else {
      QuizzerLogger.logWarning('Failed to upsert setting "$settingName" for user $userId.');
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
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
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
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }

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

// --- Batch Function to Insert or Update Multiple Settings from Cloud ---
/// Takes a list of cloud data and overwrites local data in a single transaction.
/// Cloud is the source of truth during inbound sync.
Future<void> batchUpsertUserSettingsFromSupabase({
  required List<Map<String, dynamic>> settingsData, 
  required String userId,
  required dynamic db
  }) async {
  if (settingsData.isEmpty) {
    QuizzerLogger.logMessage('batchUpsertUserSettingsFromSupabase: No settings to upsert');
    return;
  }

  try {
    QuizzerLogger.logMessage('Received Data, settingsData: $settingsData');
    QuizzerLogger.logMessage('batchUpsertUserSettingsFromSupabase: Starting batch upsert of ${settingsData.length} settings');
    
    assert(userId.isNotEmpty, 'batchUpsertUserSettingsFromSupabase: userId cannot be empty');

    // Process and validate all records before batch processing
    final List<Map<String, dynamic>> processedRecords = [];
    
    for (final record in settingsData) {
      try {
        if (record['setting_name'] == null || record['setting_value'] == null || record['last_modified_timestamp'] == null) {
          QuizzerLogger.logWarning('Skipping record with missing required fields: ${record['setting_name']}');
          continue;
        }

        // Validate that the setting name exists in _applicationSettings
        final bool isValidSetting = _applicationSettings.any((setting) => setting['name'] == record['setting_name']);
        if (!isValidSetting) {
          QuizzerLogger.logWarning('Skipping record with invalid setting name: ${record['setting_name']}');
          continue;
        }

        // Manually construct the record with only the fields we need
        final Map<String, dynamic> processedRecord = {
          'user_id': record['user_id'],
          'setting_name': record['setting_name'],
          'setting_value': record['setting_value'],
          'last_modified_timestamp': record['last_modified_timestamp'],
          'is_admin_setting': record['is_admin_setting'] ?? false,
          'has_been_synced': 1,
          'edits_are_synced': 1,
        };
        
        processedRecords.add(processedRecord);
      } catch (e) {
        QuizzerLogger.logError('Error processing record: $e');
        continue; // Skip this record and continue with others
      }
    }

    if (processedRecords.isEmpty) {
      QuizzerLogger.logMessage('No valid records to process after validation');
      return;
    }

    // Use a transaction to ensure all inserts are committed together
    for (final processedRecord in processedRecords) {
      // Use insertRawData with ConflictAlgorithm.replace to handle both insert and update cases
      // This matches the working pattern from question_answer_pairs_table
      final int result = await insertRawData(
        _tableName,
        processedRecord,
        db,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      QuizzerLogger.logMessage('Upserted setting: $processedRecord, result: $result');
    }


    QuizzerLogger.logSuccess('batchUpsertUserSettingsFromSupabase: Successfully processed ${settingsData.length} settings');

  } catch (e) {
    QuizzerLogger.logError('batchUpsertUserSettingsFromSupabase: Error - $e');
    QuizzerLogger.logError('batchUpsertUserSettingsFromSupabase: Stack trace: ${StackTrace.current}');
    rethrow;
  }
}