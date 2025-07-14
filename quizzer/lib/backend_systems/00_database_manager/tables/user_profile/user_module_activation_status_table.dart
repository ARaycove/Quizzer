import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/07_user_question_management/user_question_processes.dart';

/// Verifies that the user_module_activation_status table exists in the database
/// Creates the table if it doesn't exist
/// Private function that requires a database parameter to avoid race conditions
Future<void> verifyUserModuleActivationStatusTable(dynamic db, String userId) async {
  try {
    QuizzerLogger.logMessage('Verifying user_module_activation_status table existence');
    
    // Check if the table exists
    final List<Map<String, dynamic>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='user_module_activation_status'"
    );
    
    if (tables.isEmpty) {
      QuizzerLogger.logMessage('User module activation status table does not exist, creating it');
      await db.execute('''
        CREATE TABLE user_module_activation_status(
          user_id TEXT NOT NULL,
          module_name TEXT NOT NULL,
          is_active INTEGER DEFAULT 0,
          -- Sync Fields --
          has_been_synced INTEGER DEFAULT 0,
          edits_are_synced INTEGER DEFAULT 0,
          last_modified_timestamp TEXT,
          -- ------------- --
          PRIMARY KEY (user_id, module_name)
        )
      ''');
      
      QuizzerLogger.logSuccess('User module activation status table created successfully');
    } else {
      // Table exists, check for sync columns
      final List<Map<String, dynamic>> columns = await db.rawQuery(
        "PRAGMA table_info(user_module_activation_status)"
      );
      final Set<String> columnNames = columns.map((column) => column['name'] as String).toSet();

      // Add checks for sync columns if they don't exist
      if (!columnNames.contains('has_been_synced')) {
        QuizzerLogger.logMessage('Adding has_been_synced column to user_module_activation_status table.');
        await db.execute('ALTER TABLE user_module_activation_status ADD COLUMN has_been_synced INTEGER DEFAULT 0');
      }
      if (!columnNames.contains('edits_are_synced')) {
        QuizzerLogger.logMessage('Adding edits_are_synced column to user_module_activation_status table.');
        await db.execute('ALTER TABLE user_module_activation_status ADD COLUMN edits_are_synced INTEGER DEFAULT 0');
      }
      if (!columnNames.contains('last_modified_timestamp')) {
        QuizzerLogger.logMessage('Adding last_modified_timestamp column to user_module_activation_status table.');
        await db.execute('ALTER TABLE user_module_activation_status ADD COLUMN last_modified_timestamp TEXT');
      }
      _ensureAllModulesHaveActivationStatusForUser(db, userId);
    }
  } catch (e) {
    QuizzerLogger.logError('Error verifying user module activation status table - $e');
    rethrow;
  }
}

/// Internal function to ensure all modules have activation status records for a user
/// 1. Get all module names from module_table
/// 2. Get all current activation status records for the user
/// 3. Figure out what module names don't have activation status records
/// 4. Add an activation status record for each missing record
Future<void> _ensureAllModulesHaveActivationStatusForUser(dynamic db, String userId) async {
  try {
    // 1. Get all module names from module_table
    final List<Map<String, dynamic>> allModules = await getAllModules();
    final List<String> allModuleNames = allModules.map((module) => module['module_name'] as String).toList();
    
    // 2. Get all current activation status records for the user
    final List<Map<String, dynamic>> existingRecords = await queryAndDecodeDatabase(
      'user_module_activation_status',
      db,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    final Set<String> existingModuleNames = existingRecords.map((record) => record['module_name'] as String).toSet();
    
    // 3. Figure out what module names don't have activation status records
    final List<String> missingModules = allModuleNames.where((moduleName) => !existingModuleNames.contains(moduleName)).toList();
    
    if (missingModules.isEmpty) {
      QuizzerLogger.logMessage('All modules already have activation status records for user: $userId');
      return;
    }
    
    // 4. Add an activation status record for each missing record
    QuizzerLogger.logMessage('Creating activation status records for ${missingModules.length} missing modules for user: $userId');
    for (final moduleName in missingModules) {
      final Map<String, dynamic> data = {
        'user_id': userId,
        'module_name': moduleName,
        'is_active': 0, // Default to inactive
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      
      final int result = await insertRawData(
        'user_module_activation_status',
        data,
        db,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      
      if (result > 0) {
        QuizzerLogger.logMessage('Created activation status record for module: $moduleName, user: $userId');
      }
    }
    
    QuizzerLogger.logSuccess('Successfully ensured all modules have activation status records for user: $userId');
  } catch (e) {
    QuizzerLogger.logError('Error ensuring all modules have activation status for user: $userId - $e');
    rethrow;
  }
}

/// Gets the activation status of modules for a user
/// Returns a Map<String, bool> where keys are module names and values are activation status
Future<Map<String, bool>> getModuleActivationStatus(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await verifyUserModuleActivationStatusTable(db, userId);
    
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'user_module_activation_status',
      db,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    
    final Map<String, bool> activationStatus = {};
    for (final result in results) {
      final String moduleName = result['module_name'] as String;
      final int isActive = result['is_active'] as int;
      activationStatus[moduleName] = isActive == 1;
    }
    
    QuizzerLogger.logMessage('Retrieved activation status for ${activationStatus.length} modules for user: $userId');
    return activationStatus;
  } catch (e) {
    QuizzerLogger.logError('Error getting module activation status for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Updates the activation status of a specific module for a user
/// Takes a module name and boolean value to set its activation status
Future<bool> updateModuleActivationStatus(String userId, String moduleName, bool isActive) async {
  try {
    QuizzerLogger.logMessage('Updating activation status for module: $moduleName, user: $userId, status: $isActive');
    
    // If module is being activated, validate that all questions from this module are in the user's profile
    // This must be done BEFORE requesting database access to avoid race conditions
    if (isActive) {
      QuizzerLogger.logMessage('Module being activated, validating questions for user profile...');
      try {
        await validateModuleQuestionsInUserProfile(moduleName, userId);
        QuizzerLogger.logSuccess('Successfully validated questions for module: $moduleName');
      } catch (e) {
        QuizzerLogger.logError('Error validating questions for module $moduleName: $e');
        rethrow;
      }
    }
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await verifyUserModuleActivationStatusTable(db, userId);
    
    final Map<String, dynamic> data = {
      'user_id': userId,
      'module_name': moduleName,
      'is_active': isActive ? 1 : 0,
      'has_been_synced': 0,
      'edits_are_synced': 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    // Use upsert to handle both insert and update scenarios
    final int result = await insertRawData(
      'user_module_activation_status',
      data,
      db,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    if (result > 0) {
      QuizzerLogger.logSuccess('Successfully updated activation status for module: $moduleName, user: $userId');
      // Signal SwitchBoard
      signalOutboundSyncNeeded();
      return true;
    } else {
      QuizzerLogger.logError('Failed to update activation status for module: $moduleName, user: $userId');
      return false;
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating module activation status for module: $moduleName, user: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Ensures that every module in the modules table has a corresponding record
/// in the user_module_activation_status table for the given user.
/// Creates records with default is_active = 0 for any missing modules.
Future<void> ensureAllModulesHaveActivationStatus(String userId) async {
  try {
    QuizzerLogger.logMessage('Ensuring all modules have activation status for user: $userId');
    final List<Map<String, dynamic>> allModules = await getAllModules();
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await verifyUserModuleActivationStatusTable(db, userId);
    
    // Get all module names from the modules table
    
    final List<String> allModuleNames = allModules.map((module) => module['module_name'] as String).toList();
    
    QuizzerLogger.logMessage('Found ${allModuleNames.length} modules in modules table');
    
    // Get existing activation status records for this user
    final List<Map<String, dynamic>> existingRecords = await queryAndDecodeDatabase(
      'user_module_activation_status',
      db,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    
    final Set<String> existingModuleNames = existingRecords.map((record) => record['module_name'] as String).toSet();
    
    // Find modules that don't have activation status records
    final List<String> missingModules = allModuleNames.where((moduleName) => !existingModuleNames.contains(moduleName)).toList();
    
    if (missingModules.isEmpty) {
      QuizzerLogger.logMessage('All modules already have activation status records for user: $userId');
      return;
    }
    
    QuizzerLogger.logMessage('Creating activation status records for ${missingModules.length} missing modules');
    
    // Create records for missing modules with default is_active = 0
    for (final moduleName in missingModules) {
      final Map<String, dynamic> data = {
        'user_id': userId,
        'module_name': moduleName,
        'is_active': 0, // Default to inactive
        'has_been_synced': 0,
        'edits_are_synced': 0,
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      
      final int result = await insertRawData(
        'user_module_activation_status',
        data,
        db,
        conflictAlgorithm: ConflictAlgorithm.ignore, // Ignore if somehow already exists
      );
      
      if (result > 0) {
        QuizzerLogger.logMessage('Created activation status record for module: $moduleName');
      }
    }
    
    QuizzerLogger.logSuccess('Successfully ensured all modules have activation status records for user: $userId');
    // Signal SwitchBoard for the new records
    signalOutboundSyncNeeded();
  } catch (e) {
    QuizzerLogger.logError('Error ensuring all modules have activation status for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Gets all active module names for a specific user
/// Returns a List<String> containing the names of all active modules
Future<List<String>> getActiveModuleNames(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await verifyUserModuleActivationStatusTable(db, userId);
    
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'user_module_activation_status',
      db,
      columns: ['module_name'],
      where: 'user_id = ? AND is_active = ?',
      whereArgs: [userId, 1],
    );
    
    final List<String> activeModuleNames = results.map((result) => result['module_name'] as String).toList();
    
    QuizzerLogger.logMessage('Retrieved ${activeModuleNames.length} active module names for user: $userId');
    return activeModuleNames;
  } catch (e) {
    QuizzerLogger.logError('Error getting active module names for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Gets all module activation status records for a specific user
/// Returns a list of maps with all activation status records
Future<List<Map<String, dynamic>>> getModuleActivationStatusRecords(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await verifyUserModuleActivationStatusTable(db, userId);
    
    return await queryAndDecodeDatabase(
      'user_module_activation_status',
      db,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  } catch (e) {
    QuizzerLogger.logError('Error getting module activation status records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Gets unsynced module activation status records for a specific user
/// Returns records that need outbound synchronization
Future<List<Map<String, dynamic>>> getUnsyncedModuleActivationStatusRecords(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching unsynced module activation status records for user: $userId...');
    await verifyUserModuleActivationStatusTable(db, userId);

    final List<Map<String, dynamic>> results = await db.query(
      'user_module_activation_status',
      where: '(has_been_synced = 0 OR edits_are_synced = 0) AND user_id = ?',
      whereArgs: [userId],
    );

    QuizzerLogger.logSuccess('Fetched ${results.length} unsynced module activation status records for user $userId.');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced module activation status records for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Updates the synchronization flags for a specific module activation status record
/// Does NOT trigger a new sync signal
Future<void> updateModuleActivationStatusSyncFlags({
  required String userId,
  required String moduleName,
  required bool hasBeenSynced,
  required bool editsAreSynced,
}) async {
  try {
    QuizzerLogger.logMessage('Updating sync flags for module activation status (User: $userId, Module: $moduleName) -> Synced: $hasBeenSynced, Edits Synced: $editsAreSynced');
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    await verifyUserModuleActivationStatusTable(db, userId);
    
    final Map<String, dynamic> updates = {
      'has_been_synced': hasBeenSynced ? 1 : 0,
      'edits_are_synced': editsAreSynced ? 1 : 0,
    };

    final int rowsAffected = await updateRawData(
      'user_module_activation_status',
      updates,
      'user_id = ? AND module_name = ?',
      [userId, moduleName],
      db,
    );

    if (rowsAffected == 0) {
      QuizzerLogger.logWarning('updateModuleActivationStatusSyncFlags affected 0 rows for (User: $userId, Module: $moduleName). Record might not exist?');
    } else {
      QuizzerLogger.logSuccess('Successfully updated sync flags for module activation status (User: $userId, Module: $moduleName).');
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating sync flags for module activation status (User: $userId, Module: $moduleName) - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Inserts or updates module activation status records from inbound sync
/// Sets sync flags to indicate the record is synced and edits are synced
Future<void> upsertModuleActivationStatusFromInboundSync({
  required String userId,
  required String moduleName,
  required bool isActive,
  required String lastModifiedTimestamp,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Upserting module activation status from inbound sync (User: $userId, Module: $moduleName)');
    
    await verifyUserModuleActivationStatusTable(db, userId);

    final Map<String, dynamic> data = {
      'user_id': userId,
      'module_name': moduleName,
      'is_active': isActive ? 1 : 0,
      'has_been_synced': 1, // Mark as synced from cloud
      'edits_are_synced': 1, // Mark edits as synced (as it's from cloud)
      'last_modified_timestamp': lastModifiedTimestamp,
    };

    final int result = await insertRawData(
      'user_module_activation_status',
      data,
      db,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (result > 0) {
      QuizzerLogger.logSuccess('Successfully upserted module activation status from inbound sync (User: $userId, Module: $moduleName)');
    } else {
      QuizzerLogger.logWarning('upsertModuleActivationStatusFromInboundSync: insertRawData with replace returned 0 for (User: $userId, Module: $moduleName)');
    }
  } catch (e) {
    QuizzerLogger.logError('Error upserting module activation status from inbound sync (User: $userId, Module: $moduleName) - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}
