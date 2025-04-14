// All documentation for Quizzer is under the quizzer_documentation/ folder, under varying subfolders depending on the type of documentation. This means you will have to do a search for additional information instead of relying completely on valid file paths to be provided
// The documentation for the modules table is in quizzer_documentation/Core Documentation/Chapter 08 - Database/08_04_Modules_Table.md
// TODO: Implement the modules table:
// Follow the same design pattern as the question_answer_pairs table.
// You will not use classes for this table.
// You will follow the same design pattern as the question_answer_pairs table. and other database tables.

import 'package:sqflite/sqflite.dart';
import 'package:quizzer/database/quizzer_database.dart';

Future<void> verifyModulesTable() async {
  final Database db = await getDatabase();
  
  // Check if the table exists
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='modules'"
  );
  
  if (tables.isEmpty) {
    await db.execute('''
      CREATE TABLE modules (
        module_name TEXT PRIMARY KEY,
        description TEXT,
        primary_subject TEXT,
        subjects TEXT,  -- CSV of subjects
        related_concepts TEXT,  -- CSV of concepts
        question_ids TEXT,  -- CSV of question IDs
        creation_date TEXT,
        creator_id TEXT,
        last_modified TEXT,
        total_questions INTEGER,
        FOREIGN KEY (creator_id) REFERENCES user_profile(uuid)
      )
    ''');
  }
}

Future<int> addModule({
  required String moduleName,
  required String description,
  required String primarySubject,
  required List<String> subjects,
  required List<String> relatedConcepts,
  required List<String> questionIds,
  required String creatorId,
}) async {
  // First verify that the table exists
  await verifyModulesTable();

  final Database db = await getDatabase();
  final String creationDate = DateTime.now().toIso8601String();
  final String lastModified = creationDate;

  return await db.insert('modules', {
    'module_name': moduleName,
    'description': description,
    'primary_subject': primarySubject,
    'subjects': subjects.join(','),
    'related_concepts': relatedConcepts.join(','),
    'question_ids': questionIds.join(','),
    'creation_date': creationDate,
    'creator_id': creatorId,
    'last_modified': lastModified,
    'total_questions': questionIds.length,
  });
}

Future<int> editModule({
  required String moduleName,
  String? description,
  String? primarySubject,
  List<String>? subjects,
  List<String>? relatedConcepts,
  List<String>? questionIds,
}) async {
  // First verify that the table exists
  await verifyModulesTable();

  final Database db = await getDatabase();
  Map<String, dynamic> values = {
    'last_modified': DateTime.now().toIso8601String(),
  };
  
  if (description != null) values['description'] = description;
  if (primarySubject != null) values['primary_subject'] = primarySubject;
  if (subjects != null) values['subjects'] = subjects.join(',');
  if (relatedConcepts != null) values['related_concepts'] = relatedConcepts.join(',');
  if (questionIds != null) {
    values['question_ids'] = questionIds.join(',');
    values['total_questions'] = questionIds.length;
  }

  return await db.update(
    'modules',
    values,
    where: 'module_name = ?',
    whereArgs: [moduleName],
  );
}

Future<Map<String, dynamic>?> getModuleByName(String moduleName) async {
  // First verify that the table exists
  await verifyModulesTable();

  final Database db = await getDatabase();
  final List<Map<String, dynamic>> maps = await db.query(
    'modules',
    where: 'module_name = ?',
    whereArgs: [moduleName],
  );

  if (maps.isEmpty) return null;

  final module = maps.first;
  
  // Parse the CSV strings into arrays
  module['subjects'] = module['subjects'].split(',');
  module['related_concepts'] = module['related_concepts'].split(',');
  module['question_ids'] = module['question_ids'].split(',');

  return module;
}

Future<List<Map<String, dynamic>>> getModulesBySubject(String subject) async {
  // First verify that the table exists
  await verifyModulesTable();

  final Database db = await getDatabase();
  return await db.query(
    'modules',
    where: 'subjects LIKE ?',
    whereArgs: ['%$subject%'],
  );
}

Future<List<Map<String, dynamic>>> getModulesByConcept(String concept) async {
  // First verify that the table exists
  await verifyModulesTable();

  final Database db = await getDatabase();
  return await db.query(
    'modules',
    where: 'related_concepts LIKE ?',
    whereArgs: ['%$concept%'],
  );
}

Future<List<Map<String, dynamic>>> getAllModules() async {
  // First verify that the table exists
  await verifyModulesTable();

  final Database db = await getDatabase();
  return await db.query('modules');
}

Future<int> removeModule(String moduleName) async {
  // First verify that the table exists
  await verifyModulesTable();

  final Database db = await getDatabase();
  return await db.delete(
    'modules',
    where: 'module_name = ?',
    whereArgs: [moduleName],
  );
}