import 'package:sqflite/sqflite.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';

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
  
  await db.insert(
    modulesTableName,
    {
      moduleNameField: name,
      descriptionField: description,
      primarySubjectField: primarySubject,
      subjectsField: subjects.join(','),
      relatedConceptsField: relatedConcepts.join(','),
      questionIdsField: questionIds.join(','),
      creationDateField: now,
      creatorIdField: creatorId,
      lastModifiedField: now,
      totalQuestionsField: questionIds.length,
      hasBeenSyncedField: 0,
      lastSyncField: null,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  
  QuizzerLogger.logSuccess('Module $name inserted successfully');
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
  
  if (description != null) updates[descriptionField] = description;
  if (primarySubject != null) updates[primarySubjectField] = primarySubject;
  if (subjects != null) updates[subjectsField] = subjects.join(',');
  if (relatedConcepts != null) updates[relatedConceptsField] = relatedConcepts.join(',');
  if (questionIds != null) {
    updates[questionIdsField] = questionIds.join(',');
    updates[totalQuestionsField] = questionIds.length;
  }
  
  updates[lastModifiedField] = DateTime.now().millisecondsSinceEpoch;
  updates[hasBeenSyncedField] = 0;

  await db.update(
    modulesTableName,
    updates,
    where: '$moduleNameField = ?',
    whereArgs: [name],
  );
  
  QuizzerLogger.logSuccess('Module $name updated successfully');
}

// Get a module by name
Future<Map<String, dynamic>?> getModule(String name, Database db) async {
  QuizzerLogger.logMessage('Fetching module: $name');
  await verifyModulesTable(db);
  final List<Map<String, dynamic>> maps = await db.query(
    modulesTableName,
    where: '$moduleNameField = ?',
    whereArgs: [name],
  );

  if (maps.isEmpty) {
    QuizzerLogger.logMessage('Module $name not found');
    return null;
  }

  final module = maps.first;
  final result = {
    'module_name': module[moduleNameField],
    'description': module[descriptionField],
    'primary_subject': module[primarySubjectField],
    'subjects': (module[subjectsField] as String).split(','),
    'related_concepts': (module[relatedConceptsField] as String).split(','),
    'question_ids': (module[questionIdsField] as String).split(','),
    'creation_date': DateTime.fromMillisecondsSinceEpoch(module[creationDateField]),
    'creator_id': module[creatorIdField],
    'last_modified': DateTime.fromMillisecondsSinceEpoch(module[lastModifiedField]),
    'total_questions': module[totalQuestionsField],
    'has_been_synced': module[hasBeenSyncedField] == 1,
    'last_sync': module[lastSyncField] != null 
        ? DateTime.fromMillisecondsSinceEpoch(module[lastSyncField])
        : null,
  };
  
  QuizzerLogger.logValue('Retrieved module: $result');
  
  return result;
}

// Get all modules
Future<List<Map<String, dynamic>>> getAllModules(Database db) async {
  QuizzerLogger.logMessage('Fetching all modules');
  await verifyModulesTable(db);
  final List<Map<String, dynamic>> maps = await db.query(modulesTableName);
  
  final result = maps.map((module) => {
    'module_name': module[moduleNameField],
    'description': module[descriptionField],
    'primary_subject': module[primarySubjectField],
    'subjects': (module[subjectsField] as String).split(','),
    'related_concepts': (module[relatedConceptsField] as String).split(','),
    'question_ids': (module[questionIdsField] as String).split(','),
    'creation_date': DateTime.fromMillisecondsSinceEpoch(module[creationDateField]),
    'creator_id': module[creatorIdField],
    'last_modified': DateTime.fromMillisecondsSinceEpoch(module[lastModifiedField]),
    'total_questions': module[totalQuestionsField],
    'has_been_synced': module[hasBeenSyncedField] == 1,
    'last_sync': module[lastSyncField] != null 
        ? DateTime.fromMillisecondsSinceEpoch(module[lastSyncField])
        : null,
  }).toList();
  
  QuizzerLogger.logValue('Retrieved modules: $result');
  
  return result;
}
