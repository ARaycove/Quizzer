/*
* [x] Write up table and CRUD operations
  * [x] Need a save_feature_set function that saves the given models expected input fields along with default values. Should be a Map<String, dynamic> where String is the feature_name and dynamic is expected default value
* [x] Create supabase table for this (matching the table schema locally)
* [x] Create RLS policies for table
* [x] Verify integrated into login flow
* [x] update inbound sync mechanism 
* [x] only admin should be updating this table, so therefore there is no need to add to outbound sync.
* [] Update prediction_model.dart to save the first model feature set and trigger sync directly.
*/
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';

final List<Map<String, String>> expectedColumns = [
  {'name': 'model_name',      'type': 'TEXT PRIMARY KEY'},
  {'name': 'input_features',  'type': 'TEXT'},
  {'name': 'model_json',      'type': 'TEXT'},
  {'name': 'last_modified_timestamp',   'type': 'TEXT'},
];

Future<void> verifyMlModelsTable(dynamic db) async {
  try {
    QuizzerLogger.logMessage('Verifying ml_models table existence');
    
    final List<Map<String, dynamic>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      ['ml_models']
    );

    if (tables.isEmpty) {
      QuizzerLogger.logMessage('ml_models table does not exist, creating it');
      
      String createTableSQL = 'CREATE TABLE ml_models(\n';
      createTableSQL += expectedColumns.map((col) => '  ${col['name']} ${col['type']}').join(',\n');
      createTableSQL += '\n)';
      
      await db.execute(createTableSQL);
      QuizzerLogger.logSuccess('ml_models table created successfully');
    } else {
      QuizzerLogger.logMessage('ml_models table exists, checking column structure');
      
      final List<Map<String, dynamic>> currentColumns = await db.rawQuery(
        "PRAGMA table_info(ml_models)"
      );
      
      final Set<String> currentColumnNames = currentColumns
          .map((column) => column['name'] as String)
          .toSet();
      
      final Set<String> expectedColumnNames = expectedColumns
          .map((column) => column['name']!)
          .toSet();
      
      final Set<String> columnsToAdd = expectedColumnNames.difference(currentColumnNames);
      final Set<String> columnsToRemove = currentColumnNames.difference(expectedColumnNames);
      
      for (String columnName in columnsToAdd) {
        final columnDef = expectedColumns.firstWhere((col) => col['name'] == columnName);
        QuizzerLogger.logMessage('Adding missing column: $columnName');
        await db.execute('ALTER TABLE ml_models ADD COLUMN ${columnDef['name']} ${columnDef['type']}');
      }
      
      if (columnsToRemove.isNotEmpty) {
        QuizzerLogger.logMessage('Removing unexpected columns: ${columnsToRemove.join(', ')}');
        
        String tempTableSQL = 'CREATE TABLE ml_models_temp(\n';
        tempTableSQL += expectedColumns.map((col) => '  ${col['name']} ${col['type']}').join(',\n');
        tempTableSQL += '\n)';
        
        await db.execute(tempTableSQL);
        
        String columnList = expectedColumnNames.join(', ');
        await db.execute('INSERT INTO ml_models_temp ($columnList) SELECT $columnList FROM ml_models');
        
        await db.execute('DROP TABLE ml_models');
        await db.execute('ALTER TABLE ml_models_temp RENAME TO ml_models');
        
        QuizzerLogger.logSuccess('Removed unexpected columns and restructured table');
      }
      
      if (columnsToAdd.isEmpty && columnsToRemove.isEmpty) {
        QuizzerLogger.logMessage('Table structure is already up to date');
      } else {
        QuizzerLogger.logSuccess('Table structure updated successfully');
      }
    }
  } catch (e) {
    QuizzerLogger.logError('Error verifying ml_models table - $e');
    rethrow;
  }
}

Future<Map<String, dynamic>?> getMlModel(String modelName) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'ml_models',
      db,
      where: 'model_name = ?',
      whereArgs: [modelName],
      limit: 1,
    );

    if (results.isEmpty) {
      QuizzerLogger.logMessage('ML model $modelName not found');
      return null;
    }

    return results.first;
  } catch (e) {
    QuizzerLogger.logError('Error getting ML model - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<List<Map<String, dynamic>>> getAllMlModels() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    
    return await queryAndDecodeDatabase('ml_models', db);
  } catch (e) {
    QuizzerLogger.logError('Error getting all ML models - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<void> batchUpsertMlModelsFromInboundSync({
  required List<Map<String, dynamic>> modelRecords,
  required dynamic db,
}) async {
  try {
    for (Map<String, dynamic> modelRecord in modelRecords) {
      final Map<String, dynamic> data = <String, dynamic>{};
      
      for (final col in expectedColumns) {
        final name = col['name'] as String;
        if (modelRecord.containsKey(name)) {
          data[name] = modelRecord[name];
        }
      }
      
      await insertRawData(
        'ml_models',
        data,
        db,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  } catch (e) {
    QuizzerLogger.logError('Error upserting ML models from inbound sync - $e');
    rethrow;
  }
}