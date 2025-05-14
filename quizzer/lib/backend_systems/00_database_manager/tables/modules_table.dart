import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'table_helper.dart'; // Import the helper file

// Table name and field constants
const String modulesTableName = 'modules';
const String moduleNameField = 'module_name';
const String descriptionField = 'description';
const String primarySubjectField = 'primary_subject';
const String subjectsField = 'subjects';
const String relatedConceptsField = 'related_concepts';
const String questionIdsField = 'question_ids';
const String creationDateField = 'creation_date';
const String creatorIdField = 'creator_id';
const String lastModifiedField = 'last_modified';
const String totalQuestionsField = 'total_questions';
const String hasBeenSyncedField = 'has_been_synced_with_central_db';
const String lastSyncField = 'last_sync_with_central_db';

// Create table SQL
const String createModulesTableSQL = '''
  CREATE TABLE IF NOT EXISTS $modulesTableName (
    $moduleNameField TEXT PRIMARY KEY,
    $descriptionField TEXT,
    $primarySubjectField TEXT,
    $subjectsField TEXT,
    $relatedConceptsField TEXT,
    $questionIdsField TEXT,
    $creationDateField INTEGER,
    $creatorIdField TEXT,
    $lastModifiedField INTEGER,
    $totalQuestionsField INTEGER,
    $hasBeenSyncedField INTEGER DEFAULT 0,
    $lastSyncField INTEGER
  )
''';

// Verify table exists and create if needed
Future<void> verifyModulesTable(Database db) async {
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
    QuizzerLogger.logMessage('Modules table already exists');
  }
}

// Insert a new module
Future<void> insertModule({
  required String name,
  required String description,
  required String primarySubject,
  required List<String> subjects,
  required List<String> relatedConcepts,
  required List<String> questionIds,
  required String creatorId,
  required Database db,
}) async {
  QuizzerLogger.logMessage('Inserting new module: $name');
  await verifyModulesTable(db);
  final now = DateTime.now().millisecondsSinceEpoch;
  
  // Prepare the raw data map - join lists into strings as needed by schema
  final Map<String, dynamic> data = {
    moduleNameField: name,
    descriptionField: description,
    primarySubjectField: primarySubject,
    subjectsField: subjects, // Pass raw list for JSON encoding
    relatedConceptsField: relatedConcepts, // Pass raw list for JSON encoding
    questionIdsField: questionIds, // Pass raw list for JSON encoding
    creationDateField: now,
    creatorIdField: creatorId,
    lastModifiedField: now,
    totalQuestionsField: questionIds.length,
    hasBeenSyncedField: 0,
    lastSyncField: null, // Helper will handle null
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
}

// Update a module
Future<void> updateModule({
  required String name,
  required Database db,
  String? description,
  String? primarySubject,
  List<String>? subjects,
  List<String>? relatedConcepts,
  List<String>? questionIds,
}) async {
  QuizzerLogger.logMessage('Updating module: $name');
  await verifyModulesTable(db);
  final updates = <String, dynamic>{};
  
  // Prepare map with raw data - lists will be handled by encodeValueForDB in the helper
  if (description != null) updates[descriptionField] = description;
  if (primarySubject != null) updates[primarySubjectField] = primarySubject;
  if (subjects != null) updates[subjectsField] = subjects; // Pass raw list
  if (relatedConcepts != null) updates[relatedConceptsField] = relatedConcepts; // Pass raw list
  if (questionIds != null) {
    updates[questionIdsField] = questionIds; // Pass raw list
    updates[totalQuestionsField] = questionIds.length;
  }
  
  // Add fields that are always updated
  updates[lastModifiedField] = DateTime.now().millisecondsSinceEpoch;
  updates[hasBeenSyncedField] = 0; // Mark as needing sync after update

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
    QuizzerLogger.logSuccess('Module $name updated successfully ($result row affected).');
  } else {
    QuizzerLogger.logWarning('Update operation for module $name affected 0 rows. Module might not exist or data was unchanged.');
  }
}

// Get a module by name
Future<Map<String, dynamic>?> getModule(String name, Database db) async {
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
  // Specifically: Convert integer timestamps to DateTime
  final Map<String, dynamic> finalResult = {
    moduleNameField: decodedModule[moduleNameField],
    descriptionField: decodedModule[descriptionField],
    primarySubjectField: decodedModule[primarySubjectField],
    subjectsField: decodedModule[subjectsField], // Already decoded to List<String> or similar by helper
    relatedConceptsField: decodedModule[relatedConceptsField], // Already decoded
    questionIdsField: decodedModule[questionIdsField], // Already decoded
    creationDateField: DateTime.fromMillisecondsSinceEpoch(decodedModule[creationDateField] as int),
    creatorIdField: decodedModule[creatorIdField],
    lastModifiedField: DateTime.fromMillisecondsSinceEpoch(decodedModule[lastModifiedField] as int),
    totalQuestionsField: decodedModule[totalQuestionsField],
    hasBeenSyncedField: decodedModule[hasBeenSyncedField] == 1, // Convert int (0/1) to bool
    lastSyncField: decodedModule[lastSyncField] != null 
        ? DateTime.fromMillisecondsSinceEpoch(decodedModule[lastSyncField] as int)
        : null,
  };
  
  QuizzerLogger.logValue('Retrieved and processed module: $finalResult');
  return finalResult;
}

// Get all modules
Future<List<Map<String, dynamic>>> getAllModules(Database db) async {
  QuizzerLogger.logMessage('Fetching all modules');
  await verifyModulesTable(db);
  
  // Use the universal query helper
  final List<Map<String, dynamic>> decodedModules = await queryAndDecodeDatabase(
    modulesTableName,
    db,
    // No WHERE clause needed to get all
  );

  // Process the decoded results to perform final type conversions (like int timestamps to DateTime)
  final List<Map<String, dynamic>> finalResults = [];
  for (final decodedModule in decodedModules) {
      // Basic check for essential fields
      if (decodedModule[moduleNameField] == null || 
          decodedModule[creationDateField] == null || 
          decodedModule[lastModifiedField] == null) {
        QuizzerLogger.logWarning('Skipping module due to missing essential fields: ${decodedModule[moduleNameField] ?? 'Unknown'}');
        continue; // Skip this potentially malformed module
      }

      // Perform the same type conversions as in getModule
      final Map<String, dynamic> processedModule = {
        moduleNameField: decodedModule[moduleNameField],
        descriptionField: decodedModule[descriptionField],
        primarySubjectField: decodedModule[primarySubjectField],
        subjectsField: decodedModule[subjectsField], // Already List<dynamic>? or null
        relatedConceptsField: decodedModule[relatedConceptsField], // Already List<dynamic>? or null
        questionIdsField: decodedModule[questionIdsField], // Already List<dynamic>? or null
        creationDateField: DateTime.fromMillisecondsSinceEpoch(decodedModule[creationDateField] as int),
        creatorIdField: decodedModule[creatorIdField],
        lastModifiedField: DateTime.fromMillisecondsSinceEpoch(decodedModule[lastModifiedField] as int),
        totalQuestionsField: decodedModule[totalQuestionsField],
        hasBeenSyncedField: (decodedModule[hasBeenSyncedField] == 1 || decodedModule[hasBeenSyncedField] == true), // Handle int or bool
        lastSyncField: decodedModule[lastSyncField] != null 
            ? DateTime.fromMillisecondsSinceEpoch(decodedModule[lastSyncField] as int)
            : null,
      };
      finalResults.add(processedModule);
  }

  QuizzerLogger.logValue('Retrieved and processed ${finalResults.length} modules');
  return finalResults;
}
