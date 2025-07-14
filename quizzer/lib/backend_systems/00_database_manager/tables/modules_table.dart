import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'table_helper.dart'; // Import the helper file
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';

// Table name and field constants
const String modulesTableName = 'modules';
const String moduleNameField = 'module_name';
const String descriptionField = 'description';
const String primarySubjectField = 'primary_subject';
const String subjectsField = 'subjects';
const String relatedConceptsField = 'related_concepts';
const String creationDateField = 'creation_date';
const String creatorIdField = 'creator_id';

// Create table SQL
const String createModulesTableSQL = '''
  CREATE TABLE IF NOT EXISTS $modulesTableName (
    $moduleNameField TEXT PRIMARY KEY,
    $descriptionField TEXT,
    $primarySubjectField TEXT,
    $subjectsField TEXT,
    $relatedConceptsField TEXT,
    $creationDateField TEXT,
    $creatorIdField TEXT,
    has_been_synced INTEGER DEFAULT 0,
    edits_are_synced INTEGER DEFAULT 0,
    last_modified_timestamp TEXT
  )
''';

// Verify table exists and create if needed
Future<void> verifyModulesTable(dynamic db) async {
  QuizzerLogger.logMessage('Verifying modules table existence');
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='$modulesTableName'"
  );
  
  if (tables.isEmpty) {
    QuizzerLogger.logMessage('Modules table does not exist, creating it');
    await db.execute(createModulesTableSQL);
    QuizzerLogger.logSuccess('Modules table created successfully');
    // Build modules from question-answer pairs when table is first created
    QuizzerLogger.logMessage('Building initial modules from question-answer pairs');
    QuizzerLogger.logSuccess('Initial modules built successfully');
  } else {
    QuizzerLogger.logMessage('Modules table exists, checking for old fields');
    
    // Get current table info
    final List<Map<String, dynamic>> columns = await db.rawQuery(
      "PRAGMA table_info($modulesTableName)"
    );
    
    // Check for old fields to remove
    final oldFields = [
      'last_modified',
      'has_been_synced_with_central_db',
      'last_sync_with_central_db',
      'question_ids',
      'total_questions'
    ];
    
    for (final field in oldFields) {
      if (columns.any((col) => col['name'] == field)) {
        QuizzerLogger.logMessage('Removing old field: $field');
        await db.execute('ALTER TABLE $modulesTableName DROP COLUMN $field');
      }
    }

    // Add new sync fields if they don't exist
    final newFields = {
      'has_been_synced': 'INTEGER DEFAULT 0',
      'edits_are_synced': 'INTEGER DEFAULT 0',
      'last_modified_timestamp': 'TEXT'
    };

    for (final entry in newFields.entries) {
      if (!columns.any((col) => col['name'] == entry.key)) {
        QuizzerLogger.logMessage('Adding new field: ${entry.key}');
        await db.execute('ALTER TABLE $modulesTableName ADD COLUMN ${entry.key} ${entry.value}');
      }
    }
    
    QuizzerLogger.logSuccess('Modules table structure verified and cleaned');
  }
}

// Insert a new module
Future<void> insertModule({
  required String name,
  required String description,
  required String primarySubject,
  required List<String> subjects,
  required List<String> relatedConcepts,
  required String creatorId,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Inserting new module: $name');
    await verifyModulesTable(db);
    final now = DateTime.now().toUtc().toIso8601String();
    
    // Prepare the raw data map - join lists into strings as needed by schema
    final Map<String, dynamic> data = {
      moduleNameField: name,
      descriptionField: description,
      primarySubjectField: primarySubject,
      subjectsField: subjects, // Pass raw list for JSON encoding
      relatedConceptsField: relatedConcepts, // Pass raw list for JSON encoding
      creationDateField: now,
      creatorIdField: creatorId,
      'has_been_synced': 0,
      'edits_are_synced': 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String()
    };

    // Use the universal insert helper with ConflictAlgorithm.replace
    final int result = await insertRawData(
      modulesTableName,
      data,
      db,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    // Log based on result (insertRawData returns row ID or 0/-1 on failure/ignore)
    if (result > 0) { // replace returns rowID
      QuizzerLogger.logSuccess('Module $name inserted/replaced successfully');
    } else {
       // This case might indicate an issue if replace was expected to always work
       QuizzerLogger.logWarning('Insert/replace operation for module $name returned $result.');
    }
  } catch (e) {
    QuizzerLogger.logError('Error inserting module - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Update a module
Future<void> updateModule({
  required String name,
  String? newName,
  String? description,
  String? primarySubject,
  List<String>? subjects,
  List<String>? relatedConcepts,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Updating module: $name');
    await verifyModulesTable(db);
    final updates = <String, dynamic>{};
    
    // Handle module name change if provided
    if (newName != null && newName != name) {
      updates[moduleNameField] = newName;
      updates['edits_are_synced'] = 0; // Mark as needing sync when name changes
      QuizzerLogger.logMessage('Module name will be changed from "$name" to "$newName"');
    }
    
    // Prepare map with raw data - lists will be handled by encodeValueForDB in the helper
    if (description != null) {
      updates[descriptionField] = description;
      updates['edits_are_synced'] = 0; // Mark as needing sync when description changes
    }
    if (primarySubject != null) updates[primarySubjectField] = primarySubject;
    if (subjects != null) updates[subjectsField] = subjects; // Pass raw list
    if (relatedConcepts != null) updates[relatedConceptsField] = relatedConcepts; // Pass raw list
    
    // Add fields that are always updated
    updates['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();

    // Use the universal update helper (encoding happens inside)
    final int result = await updateRawData(
      modulesTableName,
      updates,
      '$moduleNameField = ?', // where clause
      [name],                 // whereArgs
      db,
    );
    
    // Log based on result (updateRawData returns number of rows affected)
    if (result > 0) {
      if (newName != null && newName != name) {
        QuizzerLogger.logSuccess('Module renamed from "$name" to "$newName" successfully ($result row affected).');
      } else {
        QuizzerLogger.logSuccess('Module $name updated successfully ($result row affected).');
      }
    } else {
      QuizzerLogger.logWarning('Update operation for module $name affected 0 rows. Module might not exist or data was unchanged.');
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating module - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Get a module by name
Future<Map<String, dynamic>?> getModule(String name) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching module: $name');
    await verifyModulesTable(db);
    
    // Use the universal query helper
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      modulesTableName,
      db,
      where: '$moduleNameField = ?',
      whereArgs: [name],
      limit: 2, // Limit to 2 to detect if PK constraint is violated
    );

    if (results.isEmpty) {
      QuizzerLogger.logMessage('Module $name not found');
      return null;
    } else if (results.length > 1) {
      // This shouldn't happen if moduleNameField is a primary key
      QuizzerLogger.logError('Found multiple modules with the same name: $name. PK constraint violation?');
      throw StateError('Found multiple modules with the same primary key: $name');
    }

    // Get the single, already decoded map
    final decodedModule = results.first;

    // Manually handle type conversions not covered by the generic decoder
    // Specifically: Handle creation_date as string (UTC ISO8601)
    final Map<String, dynamic> finalResult = {
      moduleNameField: decodedModule[moduleNameField],
      descriptionField: decodedModule[descriptionField],
      primarySubjectField: decodedModule[primarySubjectField],
      subjectsField: decodedModule[subjectsField], // Already decoded to List<String> or similar by helper
      relatedConceptsField: decodedModule[relatedConceptsField], // Already decoded
      creationDateField: decodedModule[creationDateField], // Keep as string, no conversion needed
      creatorIdField: decodedModule[creatorIdField],
    };
    
    QuizzerLogger.logValue('Retrieved and processed module: $finalResult');
    return finalResult;
  } catch (e) {
    QuizzerLogger.logError('Error getting module - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Get all modules with complete data
/// Retrieves the entire module list with all data associated with all modules.
/// Returns a full map of all data for each module including name, description, 
/// primary subject, subjects list, related concepts list, creation date, and creator ID.
/// This is not a snapshot but the complete current state of all modules in the database.
Future<List<Map<String, dynamic>>> getAllModules() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching all modules');
    await verifyModulesTable(db);
    
    // Use the universal query helper
    final List<Map<String, dynamic>> decodedModules = await queryAndDecodeDatabase(
      modulesTableName,
      db,
      // No WHERE clause needed to get all
    );

    // Process the decoded results to perform final type conversions
    final List<Map<String, dynamic>> finalResults = [];
    for (final decodedModule in decodedModules) {
        // Check if module_name is missing (essential)
        if (decodedModule[moduleNameField] == null) {
          QuizzerLogger.logError(
            'Skipping module due to missing essential field: $moduleNameField. Module data: $decodedModule'
          );
          continue;
        }

        // Check if creation_date is missing (non-critical for loading, but log it)
        if (decodedModule[creationDateField] == null) {
          QuizzerLogger.logWarning(
            'Module \'${decodedModule[moduleNameField]}\' has a null $creationDateField. Proceeding to load.'
          );
        }
        
        // No other fields are currently checked as critical for skipping in getAllModules.
        // If other fields were previously part of a critical check that caused skipping, 
        // that logic is now removed in favor of only moduleNameField being critical.

        // Perform the same type conversions as in getModule
        final Map<String, dynamic> processedModule = {
          moduleNameField: decodedModule[moduleNameField],
          descriptionField: decodedModule[descriptionField],
          primarySubjectField: decodedModule[primarySubjectField],
          subjectsField: decodedModule[subjectsField],
          relatedConceptsField: decodedModule[relatedConceptsField],
          creationDateField: decodedModule[creationDateField], // Keep as string, no conversion needed
          creatorIdField: decodedModule[creatorIdField],
        };
        finalResults.add(processedModule);
    }

    QuizzerLogger.logValue('Retrieved and processed ${finalResults.length} modules');
    return finalResults;
  } catch (e) {
    QuizzerLogger.logError('Error getting all modules - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Get unsynced modules
Future<List<Map<String, dynamic>>> getUnsyncedModules() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching unsynced modules');
    await verifyModulesTable(db);
    
    // Use the universal query helper to get modules that need syncing
    final List<Map<String, dynamic>> unsyncedModules = await queryAndDecodeDatabase(
      modulesTableName,
      db,
      where: 'edits_are_synced = ?',
      whereArgs: [0],
    );

    QuizzerLogger.logValue('Found ${unsyncedModules.length} unsynced modules');
    return unsyncedModules;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced modules - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Update module sync flags
Future<void> updateModuleSyncFlags({
  required String moduleName,
  required bool hasBeenSynced,
  required bool editsAreSynced,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Updating sync flags for module: $moduleName');
    await verifyModulesTable(db);
    
    final updates = {
      'has_been_synced': hasBeenSynced ? 1 : 0,
      'edits_are_synced': editsAreSynced ? 1 : 0,
    };

    final int result = await updateRawData(
      modulesTableName,
      updates,
      '$moduleNameField = ?',
      [moduleName],
      db,
    );
    
    if (result > 0) {
      QuizzerLogger.logSuccess('Sync flags updated for module $moduleName');
    } else {
      QuizzerLogger.logWarning('No rows affected when updating sync flags for module $moduleName');
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating module sync flags - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Upserts a module from inbound sync and sets sync flags to 1.
/// This function is specifically for handling inbound sync operations.
Future<void> upsertModuleFromInboundSync({
  required String moduleName,
  required String description,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Upserting module $moduleName from inbound sync...');

    await verifyModulesTable(db);

    // Prepare the data map with only the fields we store in Supabase
    final Map<String, dynamic> data = {
      'module_name': moduleName,
      'description': description,
      'has_been_synced': 1,
      'edits_are_synced': 1,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    // Use upsert to handle both insert and update cases
    await db.insert(
      'modules',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    QuizzerLogger.logSuccess('Successfully upserted module $moduleName from inbound sync.');
  } catch (e) {
    QuizzerLogger.logError('Error upserting module from inbound sync - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}
