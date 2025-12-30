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
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/sql_table.dart';

class MlModelsTable extends SqlTable {
  static final MlModelsTable _instance = MlModelsTable._internal();
  factory MlModelsTable() => _instance;
  MlModelsTable._internal();

  @override
  bool isTransient = false;

  @override
  bool requiresInboundSync = true;

  @override
  dynamic get additionalFiltersForInboundSync => null;

  @override
  bool get useLastLoginForInboundSync => true;

  @override
  String get tableName => 'ml_models';

  @override
  List<String> get primaryKeyConstraints => ['model_name'];

  @override
  List<Map<String, String>> get expectedColumns => [
    {'name': 'model_name',                'type': 'TEXT KEY'},
    {'name': 'input_features',            'type': 'TEXT'},
    {'name': 'optimal_threshold',         'type': 'REAL'}, // [x] update supabase with optimal threshold
    {'name': 'model_json',                'type': 'TEXT'},
    {'name': 'last_modified_timestamp',   'type': 'TEXT'},
    {'name': 'time_last_received_file',   'type': 'TEXT'},
  ];

  @override
  Future<bool> validateRecord(Map<String, dynamic> dataToInsert) async {
    const requiredFields = [
      'model_name', 'last_modified_timestamp'
    ];

    for (final field in requiredFields) {
      if (!dataToInsert.containsKey(field) || dataToInsert[field] == null) {
        throw ArgumentError('Required field "$field" is missing or null');
      }
    }

    return true;
  }

  @override
  Future<Map<String, dynamic>> finishRecord(Map<String, dynamic> dataToInsert) async {
    // Set last_modified_timestamp if not provided
    if (!dataToInsert.containsKey('last_modified_timestamp') || dataToInsert['last_modified_timestamp'] == null) {
      dataToInsert['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();
    }
    
    return dataToInsert;
  }

  // ==================================================
  // Business Logic Methods
  // ==================================================

  /// Gets the optimal threshold for the accuracy_net model
  Future<double> getAccuracyNetOptimalThreshold() async {
    try {
      final results = await getRecord(
        'SELECT optimal_threshold FROM $tableName WHERE model_name = "accuracy_net"'
      );
      
      if (results.isEmpty) {
        throw Exception('accuracy_net model not found');
      }
      
      return results.first['optimal_threshold'] as double;
    } catch (e) {
      QuizzerLogger.logError('Error getting accuracy_net optimal threshold - $e');
      rethrow;
    }
  }
}

// ==================================================
// Removed Functions - Now handled by SqlTable abstract class
// ==================================================

// REMOVED: verifyMlModelsTable - Use verifyTable() from SqlTable instead
// REMOVED: getMlModel - Use getRecord() from SqlTable instead  
// REMOVED: getAllMlModels - Use getRecord() from SqlTable instead
// REMOVED: batchUpsertMlModelsFromInboundSync - Use batchUpsertRecords() from SqlTable instead