/*
* [x] Write up table and CRUD operations
  * [x] Need a save_feature_set function that saves the given models expected input fields along with default values. Should be a Map<String, dynamic> where String is the feature_name and dynamic is expected default value
* [x] Create supabase table for this (matching the table schema locally)
* [x] Create RLS policies for table
* [x] Verify integrated into login flow
* [x] update inbound sync mechanism 
* [x] only admin should be updating this table, so therefore there is no need to add to outbound sync.
* [x] Update ml pipeline to resolve memory leak issue (process random params in individual batches)

* [x] Update ml pipeline to construct ordered input array, for feature mapping in production
  * [x] Update pipeline to push feature map to supabase
  * [x] Update ml pipeline to push most recent model to supabase

* [x] Update flutter code base to import most recent model from supabase through tensorflow-lite
  
* [x] Function to collect n records with the oldest last_prob_calc timestamps on them, excluding records that have been calculated in the last k minutes, and return a dataframe with the raw inference data.

* [] Update Test
  - pull n records -> run through pipeline
  - Ensure mapping of inference records to original user question primary key
  - Run inference on each one, Store inference in temporary map {primary_key: {value: prob_calc, update_time: time_UTC}}
  - When inference is done, push and update the user question answer pair table with new values

* [] Build inference engine, match generated prediction record to fit the model.
  * [] Should be able to load and initialize assignment to a variable
  * [] A function that generates a training sample
    * [] Flatten and vectorize the training sample,
  - Map input to expected input
  * [] Run the vector through the model input

* [] Test model is ready for use
  - Feed test training samples, by generating samples for all questions in the user_profile, and feeding in each one into the model to output probabilities. then print to screen the mapping of question_id to probability of correctness

* [] Create accuracy_net worker, that runs the inference

* [] submitAnswer needs to be updated to run inference on any question that's just been answered.
  - If the trigger for the worker is to update oldest records not within k_minutes, then whenever a question is answered if we set the last_prob_calc to time.now - k minutes, it should make it so the inference worker automatically picks it up for recalculation. If we set it to UTC 1970, it'll trigger the worker to pick up as first priority for recalculation
  - Signal the inference worker to loop anytime a question is answered (after updates not before)

* [] Update selection algorithm to use the inference metric:
  Follow the technical document outline for how the selection algorithm will be updated, we can only update it in part since we don't have all the pieces yet.
  *pull all user profile questions and select at random*
  - 75% - closest to threshold (hard cap of 0.8, so if optimal threshold is 0.7, we do not select above 0.8)
  - 20% - lowest probability score on list
  - 5%  - random question between 0.8 and 1 probability (if there is one) otherwise probability goes to closest to threshold
  * [] Bypasses old circulation and eligibility system when making selections (just select based on probability)



* [] Later iterations will manually draw forgetting curves using the model, and plot all questions' curves together over time
  - Using the insights of this plot if everything is done right, we sure see logarithm based curved showing degradation of probability over time (matching the original ebbinghaus study)
  * [] Assuming the above is done, we will update the selection algorithm to utilize this for efficiency
    - For questions that get a probability score of 0.8 or higher, draw the curve until we get an output below 0.8. We draw the curve by starting with some value k(days_since_last_reviewed) = 0, and increment drawing the curve, when the output is < 0.8 collect the k figure and set a timestamp for k days from now. Such user questions will not be recalculated by the model until after that due date (THIS IS NOT A REVIEW SCHEDULE ITS AN OPTIMIZATION SCHEDULE TO REDUCE COMPUTATIONAL LOAD)

*/
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';

final List<Map<String, String>> expectedColumns = [
  {'name': 'model_name',                'type': 'TEXT PRIMARY KEY'},
  {'name': 'input_features',            'type': 'TEXT'},
  {'name': 'optimal_threshold',         'type': 'REAL'}, // [x] update supabase with optimal threshold
  {'name': 'model_json',                'type': 'TEXT'},
  {'name': 'last_modified_timestamp',   'type': 'TEXT'},
  {'name': 'time_last_received_file',   'type': 'TEXT'},
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


// Model Specific:

Future<double> getAccuracyNetOptimalThreshold() async {
  final db = await getDatabaseMonitor().requestDatabaseAccess();
  if (db == null) throw Exception('Failed to acquire database access');
  
  try {
    final result = await db.rawQuery(
      'SELECT optimal_threshold FROM ml_models WHERE model_name = ?',
      ['accuracy_net']
    );
    if (result.isEmpty) throw Exception('accuracy_net model not found');
    return result.first['optimal_threshold'] as double;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}