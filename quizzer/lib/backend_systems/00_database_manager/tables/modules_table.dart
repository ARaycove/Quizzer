import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'table_helper.dart'; // Import the helper file
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart';

// Table name and field constants
const String modulesTableName = 'modules';
const String moduleNameField = 'module_name';
const String descriptionField = 'description';
const String primarySubjectField = 'primary_subject';
const String subjectsField = 'subjects';
const String relatedConceptsField = 'related_concepts';
const String creationDateField = 'creation_date';
const String creatorIdField = 'creator_id';
const String categoriesField = 'categories';

// Allowed category values
const List<String> allowedCategories = [
  'other', 
  'mathematics', 
  'mcat', 
  'clep'
  ];

// Get all available categories
List<String> getAvailableCategories() {
  return List.from(allowedCategories);
}

// Helper function to validate and normalize categories
List<String> validateAndNormalizeCategories(List<String> categories) {
  final List<String> validatedCategories = [];
  for (final category in categories) {
    final normalizedCategory = category.toLowerCase();
    if (allowedCategories.contains(normalizedCategory)) {
      validatedCategories.add(normalizedCategory);
    }
  }
  // If no valid categories found, default to 'other'
  return validatedCategories.isNotEmpty ? validatedCategories : ['other'];
}

// Create table SQL
String createModulesTableSQL() {
  return '''
    CREATE TABLE IF NOT EXISTS $modulesTableName (
      $moduleNameField TEXT PRIMARY KEY,
      $descriptionField TEXT,
      $primarySubjectField TEXT,
      $subjectsField TEXT,
      $relatedConceptsField TEXT,
      $creationDateField TEXT,
      $creatorIdField TEXT,
      $categoriesField TEXT DEFAULT '["other"]',
      has_been_synced INTEGER DEFAULT 0,
      edits_are_synced INTEGER DEFAULT 0,
      last_modified_timestamp TEXT
    )
  ''';
}

// Verify table exists and create if needed
Future<void> verifyModulesTable(dynamic db) async {
  QuizzerLogger.logMessage('Verifying modules table existence');
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='$modulesTableName'"
  );
  
  if (tables.isEmpty) {
    QuizzerLogger.logMessage('Modules table does not exist, creating it');
    await db.execute(createModulesTableSQL());
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
      'last_modified_timestamp': 'TEXT',
      categoriesField: 'TEXT DEFAULT \'["other"]\''
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
  List<String> categories = const ['other'],
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Inserting new module: $name');
    await verifyModulesTable(db);
    final now = DateTime.now().toUtc().toIso8601String();
    
    // Validate and normalize categories
    categories = validateAndNormalizeCategories(categories);
    
    // Prepare the raw data map - join lists into strings as needed by schema
    final Map<String, dynamic> data = {
      moduleNameField: name,
      descriptionField: description,
      primarySubjectField: primarySubject,
      subjectsField: subjects, // Pass raw list for JSON encoding
      relatedConceptsField: relatedConcepts, // Pass raw list for JSON encoding
      creationDateField: now,
      creatorIdField: creatorId,
      categoriesField: categories,
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
  List<String>? categories,
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
    if (categories != null) {
      updates[categoriesField] = validateAndNormalizeCategories(categories);
      updates['edits_are_synced'] = 0; // Mark as needing sync when categories change
    }
    
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
      
      // Trigger outbound sync for module updates
      signalOutboundSyncNeeded();
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
      categoriesField: decodedModule[categoriesField],
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
          categoriesField: decodedModule[categoriesField],
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

/// Retrieves all modules that belong to a specific category.
/// 
/// This function performs a case-insensitive search for modules containing the specified
/// category in their categories field. If an invalid category is provided, it automatically
/// defaults to searching for modules in the 'other' category.
/// 
/// **Parameters:**
/// - `category`: The category name to search for (case-insensitive)
/// 
/// **Returns:**
/// A `Future<List<Map<String, dynamic>>>` containing all modules that have the specified
/// category in their categories list. Each map contains the complete module data including:
/// - `module_name`: The unique identifier/name of the module
/// - `description`: Module description
/// - `primary_subject`: The primary subject area
/// - `subjects`: List of related subjects (decoded from JSON)
/// - `related_concepts`: List of related concepts (decoded from JSON)
/// - `creation_date`: When the module was created (ISO8601 string)
/// - `creator_id`: ID of the user who created the module
/// - `categories`: List of categories the module belongs to (decoded from JSON)
/// 
/// **Behavior:**
/// - Input is normalized to lowercase for case-insensitive matching
/// - Invalid categories automatically default to 'other'
/// - Uses SQL LIKE operator to match categories within the JSON array
/// - Returns empty list if no modules found for the category
/// - All returned data is properly decoded from database storage format
/// 
/// **Example:**
/// ```dart
/// // Get all mathematics modules
/// List<Map<String, dynamic>> mathModules = await getModulesByCategory('mathematics');
/// 
/// // Case-insensitive - these are equivalent
/// List<Map<String, dynamic>> mcatModules1 = await getModulesByCategory('MCAT');
/// List<Map<String, dynamic>> mcatModules2 = await getModulesByCategory('mcat');
/// 
/// // Invalid category defaults to 'other'
/// List<Map<String, dynamic>> otherModules = await getModulesByCategory('invalid');
/// ```
Future<List<Map<String, dynamic>>> getModulesByCategory(String category) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching modules by category: $category');
    await verifyModulesTable(db);
    
    // Validate and normalize category
    final normalizedCategory = category.toLowerCase();
    final validatedCategory = allowedCategories.contains(normalizedCategory) ? normalizedCategory : 'other';
    
    // Use the universal query helper
    final List<Map<String, dynamic>> decodedModules = await queryAndDecodeDatabase(
      modulesTableName,
      db,
      where: '$categoriesField LIKE ?',
      whereArgs: ['%$validatedCategory%'],
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

      // Perform the same type conversions as in getModule
      final Map<String, dynamic> processedModule = {
        moduleNameField: decodedModule[moduleNameField],
        descriptionField: decodedModule[descriptionField],
        primarySubjectField: decodedModule[primarySubjectField],
        subjectsField: decodedModule[subjectsField],
        relatedConceptsField: decodedModule[relatedConceptsField],
        creationDateField: decodedModule[creationDateField],
        creatorIdField: decodedModule[creatorIdField],
        categoriesField: decodedModule[categoriesField],
      };
      finalResults.add(processedModule);
    }

    QuizzerLogger.logValue('Retrieved and processed ${finalResults.length} modules for category: $validatedCategory');
    return finalResults;
  } catch (e) {
    QuizzerLogger.logError('Error getting modules by category - $e');
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
  required String categories,
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
      'categories': categories,
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

/// Ensures that all unique module names from question_answer_pairs table have corresponding module records
/// Creates missing modules with default values
Future<void> ensureAllQuestionModuleNamesHaveCorrespondingModuleRecords() async {
  List<String> missingModuleNames = [];
  
  try {
    QuizzerLogger.logMessage('Validating modules table - checking for missing modules...');
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    
    await verifyModulesTable(db);
    
    // Get all unique module names from question_answer_pairs table
    final List<Map<String, dynamic>> moduleNamesResult = await db.rawQuery(
      'SELECT DISTINCT module_name FROM question_answer_pairs WHERE module_name IS NOT NULL AND module_name != ""'
    );
    
    if (moduleNamesResult.isEmpty) {
      QuizzerLogger.logMessage('No module names found in question_answer_pairs table');
      return;
    }
    
    final List<String> questionModuleNames = moduleNamesResult
        .map((row) => row['module_name'] as String)
        .where((name) => name.isNotEmpty)
        .toList();
    
    QuizzerLogger.logMessage('Found ${questionModuleNames.length} unique module names in question_answer_pairs table');
    
    // Get all existing module names from modules table
    final List<Map<String, dynamic>> existingModulesResult = await db.rawQuery(
      'SELECT module_name FROM modules'
    );
    
    final Set<String> existingModuleNames = existingModulesResult
        .map((row) => row['module_name'] as String)
        .toSet();
    
    QuizzerLogger.logMessage('Found ${existingModuleNames.length} existing modules in modules table');
    
    // Find missing modules
    missingModuleNames = questionModuleNames
        .where((name) => !existingModuleNames.contains(name))
        .toList();
    
    if (missingModuleNames.isEmpty) {
      QuizzerLogger.logMessage('All module names have corresponding module records');
      return;
    }
    
    QuizzerLogger.logMessage('Found ${missingModuleNames.length} missing modules: ${missingModuleNames.join(', ')}');
    
  } catch (e) {
    QuizzerLogger.logError('Error validating modules table - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
  
  // Create missing modules OUTSIDE the database access wrapper
  for (final moduleName in missingModuleNames) {
    QuizzerLogger.logMessage('Creating missing module: $moduleName');
    
    await insertModule(
      name: moduleName,
      description: 'Auto-generated module for $moduleName',
      primarySubject: 'General',
      subjects: [],
      relatedConcepts: [],
      creatorId: 'system',
      categories: ['other'], // Default category for auto-generated modules
    );
  }
  
  QuizzerLogger.logSuccess('Successfully created ${missingModuleNames.length} missing modules');
}
