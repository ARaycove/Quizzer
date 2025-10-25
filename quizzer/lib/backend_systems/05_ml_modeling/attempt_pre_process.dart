import 'package:ml_dataframe/ml_dataframe.dart';
import 'dart:convert'; 
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
// import 'package:ml_algo/ml_algo.dart';
import 'package:ml_preprocessing/ml_preprocessing.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/ml_models_table.dart';

/// Loads all training data from the question_answer_attempts table in Supabase
/// and converts it into an ML DataFrame for model training.
/// 
/// Args:
///   limit: Optional limit on number of records. If null, gets ALL records using pagination.
///          If 5, gets only 5 records for testing.
/// 
/// Returns a DataFrame containing all the attempt records with properly
/// structured columns for machine learning operations.
/// 
/// Throws:
///   Exception: If Supabase query fails or data conversion issues occur
Future<DataFrame> loadQuestionAnswerAttemptsFromSupabase({int? limit}) async {
  try {
    QuizzerLogger.logMessage('Starting to load question answer attempts from Supabase...');
    
    final supabase = getSessionManager().supabase;
    
    List<Map<String, dynamic>> processedData = [];
    
    if (limit != null) {
      // Get only 5 records for testing
      QuizzerLogger.logMessage('Executing limited Supabase query for 5 records...');
      final List<dynamic> rawData = await supabase
          .from('question_answer_attempts')
          .select('*')
          .order('time_stamp', ascending: false)
          .limit(limit);
      
      processedData = rawData.cast<Map<String, dynamic>>();
    } else {
      // Get ALL records using pagination
      QuizzerLogger.logMessage('Executing paginated Supabase query for ALL records...');
      
      const int pageSize = 1000; // Supabase limit
      int offset = 0;
      bool hasMoreData = true;
      
      while (hasMoreData) {
        QuizzerLogger.logMessage('Fetching batch starting at offset $offset...');
        
        final List<dynamic> batchData = await supabase
            .from('question_answer_attempts')
            .select('*')
            .order('time_stamp', ascending: false)
            .range(offset, offset + pageSize - 1);
        
        if (batchData.isEmpty || batchData.length < pageSize) {
          hasMoreData = false;
        }
        
        processedData.addAll(batchData.cast<Map<String, dynamic>>());
        offset += pageSize;
        
        QuizzerLogger.logMessage('Fetched ${batchData.length} records, total so far: ${processedData.length}');
      }
    }
    
    QuizzerLogger.logMessage('Retrieved ${processedData.length} total records from Supabase');
    
    if (processedData.isEmpty) {
      QuizzerLogger.logWarning('No records found in question_answer_attempts table');
      return DataFrame([]);
    }
    
    QuizzerLogger.logMessage('Processing data for DataFrame conversion...');
    
    // Get column headers from the first record
    final List<String> headers = processedData.first.keys.toList();
    
    // Create data rows - each row is a List of values in the same order as headers
    final List<List<dynamic>> rows = processedData.map((record) {
      return headers.map((header) => record[header]).toList();
    }).toList();
    
    // Combine headers and data rows
    final List<List<dynamic>> allData = [headers, ...rows];
    
    // Create DataFrame using the standard constructor
    final DataFrame dataFrame = DataFrame(allData);
    
    QuizzerLogger.logSuccess('Successfully created DataFrame with ${dataFrame.rows.length} rows and ${dataFrame.header.length} columns');
    QuizzerLogger.logValue('DataFrame columns: ${dataFrame.header.join(', ')}');
    
    return dataFrame;
  } catch (e) {
    QuizzerLogger.logError('Error loading question answer attempts from Supabase - $e');
    rethrow;
  }
}


/// Converts embedded JSON strings in the DataFrame to proper Dart types
/// using the existing decodeValueFromDB function from table_helper.dart.
/// 
/// Args:
///   rawDataFrame: The DataFrame with JSON-encoded string fields from Supabase
/// 
/// Returns:
///   A new DataFrame with all JSON fields properly decoded to Dart types
/// 
/// Throws:
///   Exception: If decoding fails or DataFrame processing issues occur
Future<DataFrame> decodeDataFrameJsonFields(DataFrame rawDataFrame) async {
  try {
    QuizzerLogger.logMessage('Starting to decode JSON fields in DataFrame...');
    
    if (rawDataFrame.rows.isEmpty) {
      QuizzerLogger.logMessage('Empty DataFrame provided, returning as-is');
      return rawDataFrame;
    }
    
    // Get headers
    final List<String> headers = rawDataFrame.header.toList();
    
    // Process each row and decode JSON fields using existing table_helper function
    final List<List<dynamic>> decodedRows = [];
    final List<Iterable<dynamic>> rowsList = rawDataFrame.rows.toList();
    
    for (int rowIndex = 0; rowIndex < rowsList.length; rowIndex++) {
      final List<dynamic> originalRow = rowsList[rowIndex].toList();
      final List<dynamic> decodedRow = [];
      
      for (int colIndex = 0; colIndex < originalRow.length; colIndex++) {
        final dynamic originalValue = originalRow[colIndex];
        final dynamic decodedValue = decodeValueFromDB(originalValue);
        decodedRow.add(decodedValue);
      }
      
      decodedRows.add(decodedRow);
    }
    
    // Create new DataFrame with decoded data
    final List<List<dynamic>> allData = [headers, ...decodedRows];
    final DataFrame decodedDataFrame = DataFrame(allData);
    
    QuizzerLogger.logSuccess('Successfully decoded DataFrame with ${decodedDataFrame.rows.length} rows and ${decodedDataFrame.header.length} columns');
    
    return decodedDataFrame;
  } catch (e) {
    QuizzerLogger.logError('Error decoding DataFrame JSON fields - $e');
    rethrow;
  }
}

/// Recursively unpacks all complex data structures (Lists and Maps) in a DataFrame
/// into individual columns for machine learning preprocessing.
/// 
/// Args:
///   dataFrame: The input DataFrame with complex nested structures
/// 
/// Returns:
///   A new DataFrame with all complex structures unpacked into individual columns
/// 
/// Throws:
///   Exception: If unpacking fails or DataFrame processing issues occur
Future<DataFrame> unpackDataFrameFeatures(DataFrame dataFrame) async {
  QuizzerLogger.logMessage('Starting feature unpacking...');
  DataFrame returnFrame = dataFrame;
  
  // Drop unwanted columns first
  returnFrame = returnFrame.dropSeries(names: [
    "time_stamp", "participant_id", "last_revised_date", "time_of_presentation"
  ]);
  
  // Unpack user_stats_vector
  returnFrame = _unpackMapFeatures(dataFrame: returnFrame, featureNames: ["user_stats_vector"], prefix: "user_stats");
  
  // Unpack user_stats_revision_streak_sum
  returnFrame = _unpackStreakFeatures(dataFrame: returnFrame, featureNames: ["user_stats_revision_streak_sum"], prefix: "rs");
  
  // Unpack module_performance_vector
  returnFrame = _unpackModulePerformanceVector(returnFrame, prefix: "mvec");
  
  // Unpack user_profile_record
  returnFrame = _unpackMapFeatures(dataFrame: returnFrame, featureNames: ["user_profile_record"], prefix: "up");
  
  // Unpack question_vector
  returnFrame = _unpackVectorFeatures(dataFrame: returnFrame, featureNames: ["question_vector"], prefix: "qv");
  
  // Drop additional unwanted columns after unpacking
  final additionalDrops = [
    "user_stats_user_id", "user_stats_record_date", 
    "user_stats_last_modified_timestamp", "up_birth_date",
    "user_stats_has_been_synced", "user_stats_edits_are_synced",
    
    // bio 160 - misnamed course title
    "module_name_bio 160",
    "mvec_bio 160_num_fitb", "mvec_bio 160_num_total", "mvec_bio 160_overall_accuracy",
    "mvec_bio 160_num_mcq", "mvec_bio 160_num_tf", "mvec_bio 160_days_since_last_seen",
    "mvec_bio 160_total_attempts", "mvec_bio 160_total_correct_attempts", 
    "mvec_bio 160_total_incorrect_attempts", "mvec_bio 160_total_seen",
    "mvec_bio 160_avg_attempts_per_question", "mvec_bio 160_avg_reaction_time",
    "mvec_bio 160_percentage_seen",
    
    // Typo module name
    "module_name_chemistry and strcutural biology",
    "mvec_chemistry and strcutural biology_days_since_last_seen",
    
    // Generic math module - noisy catch-all
    "module_name_math",
    "mvec_math_num_fitb", "mvec_math_num_mcq", "mvec_math_num_total", 
    "mvec_math_total_attempts", "mvec_math_total_correct_attempts", 
    "mvec_math_total_incorrect_attempts", "mvec_math_total_seen",
    "mvec_math_avg_attempts_per_question", "mvec_math_avg_reaction_time", 
    "mvec_math_days_since_last_seen", "mvec_math_overall_accuracy", 
    "mvec_math_percentage_seen",
    
    // Noisy stats
    "user_stats_total_non_circ_questions", "user_stats_total_in_circ_questions", 
    "user_stats_total_eligible_questions",
  ];
  
  returnFrame = returnFrame.dropSeries(names: additionalDrops);
  
  QuizzerLogger.logSuccess('Feature unpacking complete');
  return returnFrame;
}

/// Unpacks vector features into individual columns with format: prefix_index
DataFrame _unpackVectorFeatures({
  required DataFrame dataFrame,
  required List<String> featureNames,
  required String prefix,
}) {
  if (dataFrame.rows.isEmpty) return dataFrame;
  
  final originalHeaders = dataFrame.header.toList();
  final originalRows = dataFrame.rows.map((row) => row.toList()).toList();
  
  // Build new headers and rows
  final newHeaders = <String>[];
  final newRows = List.generate(originalRows.length, (i) => <dynamic>[]);
  
  // Add non-vector columns first
  for (int colIndex = 0; colIndex < originalHeaders.length; colIndex++) {
    final columnName = originalHeaders[colIndex];
    if (!featureNames.contains(columnName)) {
      newHeaders.add(columnName);
      for (int rowIndex = 0; rowIndex < originalRows.length; rowIndex++) {
        newRows[rowIndex].add(originalRows[rowIndex][colIndex]);
      }
    }
  }
  
  // Unpack vector features
  for (final featureName in featureNames) {
    final colIndex = originalHeaders.indexOf(featureName);
    if (colIndex == -1) continue;
    
    // Get vector size from first non-null row
    int vectorSize = 0;
    for (final row in originalRows) {
      final value = row[colIndex];
      if (value is List && value.isNotEmpty) {
        vectorSize = value.length;
        break;
      }
    }
    
    // Add headers for unpacked columns
    for (int i = 0; i < vectorSize; i++) {
      newHeaders.add('${prefix}_$i');
    }
    
    // Extract vector values
    for (int rowIndex = 0; rowIndex < originalRows.length; rowIndex++) {
      final value = originalRows[rowIndex][colIndex];
      if (value is List) {
        for (int i = 0; i < vectorSize; i++) {
          newRows[rowIndex].add(i < value.length ? value[i] : null);
        }
      } else {
        // Add nulls for non-list values
        for (int i = 0; i < vectorSize; i++) {
          newRows[rowIndex].add(null);
        }
      }
    }
  }
  
  return DataFrame([newHeaders, ...newRows]);
}

/// Unpacks map features into individual columns with format: prefix_key
DataFrame _unpackMapFeatures({
  required DataFrame dataFrame,
  required List<String> featureNames,
  required String prefix,
}) {
  if (dataFrame.rows.isEmpty) return dataFrame;
  
  final originalHeaders = dataFrame.header.toList();
  final originalRows = dataFrame.rows.map((row) => row.toList()).toList();
  
  // Build new headers and rows
  final newHeaders = <String>[];
  final newRows = List.generate(originalRows.length, (i) => <dynamic>[]);
  
  // Add non-map columns first
  for (int colIndex = 0; colIndex < originalHeaders.length; colIndex++) {
    final columnName = originalHeaders[colIndex];
    if (!featureNames.contains(columnName)) {
      newHeaders.add(columnName);
      for (int rowIndex = 0; rowIndex < originalRows.length; rowIndex++) {
        newRows[rowIndex].add(originalRows[rowIndex][colIndex]);
      }
    }
  }
  
  // Unpack map features
  for (final featureName in featureNames) {
    final colIndex = originalHeaders.indexOf(featureName);
    if (colIndex == -1) continue;
    
    // Get all unique keys from all maps
    final allKeys = <String>{};
    for (final row in originalRows) {
      final value = row[colIndex];
      if (value is Map<String, dynamic>) {
        allKeys.addAll(value.keys);
      }
    }
    final sortedKeys = allKeys.toList()..sort();
    
    // Add headers for unpacked columns
    for (final key in sortedKeys) {
      newHeaders.add('${prefix}_$key');
    }
    
    // Extract map values
    for (int rowIndex = 0; rowIndex < originalRows.length; rowIndex++) {
      final value = originalRows[rowIndex][colIndex];
      if (value is Map<String, dynamic>) {
        for (final key in sortedKeys) {
          newRows[rowIndex].add(value[key]);
        }
      } else {
        // Add nulls for non-map values
        for (int i = 0; i < sortedKeys.length; i++) {
          newRows[rowIndex].add(null);
        }
      }
    }
  }
  
  return DataFrame([newHeaders, ...newRows]);
}

/// Unpacks revision_streak_sum features into individual columns with format: prefix_streakValue
DataFrame _unpackStreakFeatures({
  required DataFrame dataFrame,
  required List<String> featureNames,
  required String prefix,
}) {
  if (dataFrame.rows.isEmpty) return dataFrame;
  
  final originalHeaders = dataFrame.header.toList();
  final originalRows = dataFrame.rows.map((row) => row.toList()).toList();
  
  // Build new headers and rows
  final newHeaders = <String>[];
  final newRows = List.generate(originalRows.length, (i) => <dynamic>[]);
  
  // Add non-streak columns first
  for (int colIndex = 0; colIndex < originalHeaders.length; colIndex++) {
    final columnName = originalHeaders[colIndex];
    if (!featureNames.contains(columnName)) {
      newHeaders.add(columnName);
      for (int rowIndex = 0; rowIndex < originalRows.length; rowIndex++) {
        newRows[rowIndex].add(originalRows[rowIndex][colIndex]);
      }
    }
  }
  
  // Unpack streak features
  for (final featureName in featureNames) {
    final colIndex = originalHeaders.indexOf(featureName);
    if (colIndex == -1) continue;
    
    // Get all unique revision_streak values from all rows
    final allStreakValues = <int>{};
    for (final row in originalRows) {
      final value = row[colIndex];
      List<dynamic> streakData;
      
      if (value is String) {
        streakData = decodeValueFromDB(value) as List<dynamic>;
      } else if (value is List) {
        streakData = value;
      } else {
        continue;
      }
      
      for (final item in streakData) {
        if (item is Map<String, dynamic> && item.containsKey('revision_streak')) {
          allStreakValues.add(item['revision_streak'] as int);
        }
      }
    }
    final sortedStreakValues = allStreakValues.toList()..sort();
    
    // Add headers for unpacked columns
    for (final streakValue in sortedStreakValues) {
      newHeaders.add('${prefix}_$streakValue');
    }
    
    // Extract streak counts
    for (int rowIndex = 0; rowIndex < originalRows.length; rowIndex++) {
      final value = originalRows[rowIndex][colIndex];
      final Map<int, int> streakCounts = {};
      
      if (value != null) {
        List<dynamic> streakData;
        
        if (value is String) {
          streakData = decodeValueFromDB(value) as List<dynamic>;
        } else if (value is List) {
          streakData = value;
        } else {
          streakData = [];
        }
        
        for (final item in streakData) {
          if (item is Map<String, dynamic> && 
              item.containsKey('revision_streak') && 
              item.containsKey('count')) {
            final streak = item['revision_streak'] as int;
            final count = item['count'] as int;
            streakCounts[streak] = count;
          }
        }
      }
      
      // Add counts for each streak value (0 if not present)
      for (final streakValue in sortedStreakValues) {
        newRows[rowIndex].add(streakCounts[streakValue] ?? 0);
      }
    }
  }
  
  return DataFrame([newHeaders, ...newRows]);
}


DataFrame _unpackModulePerformanceVector(DataFrame dataFrame, {required String prefix}) {
  if (dataFrame.rows.isEmpty) return dataFrame;
  
  final originalHeaders = dataFrame.header.toList();
  final originalRows = dataFrame.rows.map((row) => row.toList()).toList();
  
  final colIndex = originalHeaders.indexOf('module_performance_vector');
  if (colIndex == -1) return dataFrame;
  
  // Modules to exclude from unpacking
  final excludedModules = {
    "dummy module", "multi field test", "new module name", "test module",
    "test module 1", "test module 10", "test module 2", "test module 3",
    "test module 4", "test module 5", "test module 6", "test module 7",
    "test module 8", "test module 9", "test module with underscores",
    "testmodule", "testmodule0", "testmodule1", "testmodule2", "testmodule3",
    "testmodule4", "algebra 1-3", "algebra & trigonometry", "testmodule0 edited"
  };
  
  // Get all unique module names and performance keys
  final allModules = <String>{};
  final allKeys = <String>{};
  
  for (final row in originalRows) {
    final value = row[colIndex];
    List<dynamic> moduleData;
    
    if (value is String) {
      moduleData = decodeValueFromDB(value) as List<dynamic>;
    } else if (value is List) {
      moduleData = value;
    } else {
      continue;
    }
    
    for (final module in moduleData) {
      if (module is Map<String, dynamic>) {
        final moduleName = module['module_name'] as String?;
        if (moduleName != null && !excludedModules.contains(moduleName)) {
          allModules.add(moduleName);
          for (final key in module.keys) {
            if (key != 'module_name') {
              allKeys.add(key);
            }
          }
        }
      }
    }
  }
  
  final sortedModules = allModules.toList()..sort();
  final sortedKeys = allKeys.toList()..sort();
  
  // Build new headers and rows
  final newHeaders = <String>[];
  final newRows = List.generate(originalRows.length, (i) => <dynamic>[]);
  
  // Add original columns except module_performance_vector
  for (int i = 0; i < originalHeaders.length; i++) {
    if (i != colIndex) {
      newHeaders.add(originalHeaders[i]);
      for (int rowIndex = 0; rowIndex < originalRows.length; rowIndex++) {
        newRows[rowIndex].add(originalRows[rowIndex][i]);
      }
    }
  }
  
  // Add unpacked module columns with prefix
  for (final moduleName in sortedModules) {
    for (final key in sortedKeys) {
      newHeaders.add('${prefix}_${moduleName}_$key');
    }
  }
  
  // Extract module performance values
  for (int rowIndex = 0; rowIndex < originalRows.length; rowIndex++) {
    final value = originalRows[rowIndex][colIndex];
    final Map<String, Map<String, dynamic>> moduleMap = {};
    
    if (value != null) {
      List<dynamic> moduleData;
      
      if (value is String) {
        moduleData = decodeValueFromDB(value) as List<dynamic>;
      } else if (value is List) {
        moduleData = value;
      } else {
        moduleData = [];
      }
      
      for (final module in moduleData) {
        if (module is Map<String, dynamic>) {
          final moduleName = module['module_name'] as String?;
          if (moduleName != null && !excludedModules.contains(moduleName)) {
            moduleMap[moduleName] = module;
          }
        }
      }
    }
    
    // Add values for each module-key combination, filling with 0 for missing data
    for (final moduleName in sortedModules) {
      for (final key in sortedKeys) {
        final moduleData = moduleMap[moduleName];
        newRows[rowIndex].add(moduleData?[key] ?? 0);
      }
    }
  }
  
  return DataFrame([newHeaders, ...newRows]);
}

Future<DataFrame> oneHotEncodeDataFrame(DataFrame inputDataFrame) async {
  if (inputDataFrame.rows.isEmpty) {
    return inputDataFrame;
  }
  
  final headers = inputDataFrame.header.toList();
  final rows = inputDataFrame.rows.map((row) => row.toList()).toList();
  
  // Find categorical columns (dtype == 'object' equivalent in Dart)
  final categoricalColumns = <String>[];
  final firstRow = rows.isNotEmpty ? rows.first : [];
  
  for (int i = 0; i < headers.length && i < firstRow.length; i++) {
    final columnName = headers[i];
    final value = firstRow[i];
    
    if (value is String) {
      final numValue = num.tryParse(value);
      if (numValue == null) {
        categoricalColumns.add(columnName);
      }
    }
  }
  
  QuizzerLogger.logMessage('Found ${categoricalColumns.length} categorical columns to encode: ${categoricalColumns.join(", ")}');
  
  if (categoricalColumns.isEmpty) {
    return inputDataFrame;
  }
  
  // Fill nulls in 'up_' prefixed columns with 'unknown'
  for (int colIndex = 0; colIndex < headers.length; colIndex++) {
    final columnName = headers[colIndex];
    if (categoricalColumns.contains(columnName) && columnName.startsWith('up_')) {
      for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        if (rows[rowIndex][colIndex] == null) {
          rows[rowIndex][colIndex] = 'unknown';
        }
      }
    }
  }
  
  // Create DataFrame with filled nulls
  final filledData = [headers, ...rows];
  final filledDataFrame = DataFrame(filledData);
  
  // One-hot encode
  final encoder = Encoder.oneHot(filledDataFrame, columnNames: categoricalColumns);
  final encodedDataFrame = encoder.process(filledDataFrame);
  
  QuizzerLogger.logMessage('One-hot encoding complete. DataFrame now has ${encodedDataFrame.header.length} columns');
  
  return encodedDataFrame;
}

Future<DataFrame> transformDataFrameToAccuracyNetInputShape(DataFrame processedDataFrame) async {
  final modelRecord = await getMlModel('accuracy_net');
  
  if (modelRecord == null) {
    throw Exception('accuracy_net model not found in ml_models table');
  }
  
  final dynamic inputFeaturesData = modelRecord['input_features'];
  final Map<String, dynamic> featureMap = inputFeaturesData is String 
      ? decodeValueFromDB(inputFeaturesData) as Map<String, dynamic>
      : inputFeaturesData as Map<String, dynamic>;
  
  final currentHeaders = processedDataFrame.header.toList();
  final currentRows = processedDataFrame.rows.map((row) => row.toList()).toList();
  
  final List<String> orderedFeatures = [];
  final List<dynamic> defaultValues = [];
  
  final sortedEntries = featureMap.entries.toList()
    ..sort((a, b) {
      final posA = (a.value as Map<String, dynamic>)['pos'] as int;
      final posB = (b.value as Map<String, dynamic>)['pos'] as int;
      return posA.compareTo(posB);
    });
  
  for (final entry in sortedEntries) {
    orderedFeatures.add(entry.key);
    defaultValues.add((entry.value as Map<String, dynamic>)['default_value']);
  }
  
  final Map<String, int> currentHeaderIndex = {};
  for (int i = 0; i < currentHeaders.length; i++) {
    currentHeaderIndex[currentHeaders[i]] = i;
  }
  
  final List<List<dynamic>> inferenceRows = [];
  
  for (final row in currentRows) {
    final List<dynamic> inferenceRow = [];
    for (int i = 0; i < orderedFeatures.length; i++) {
      final featureName = orderedFeatures[i];
      final defaultValue = defaultValues[i];
      
      if (currentHeaderIndex.containsKey(featureName)) {
        final value = row[currentHeaderIndex[featureName]!];
        inferenceRow.add(value ?? defaultValue);
      } else {
        inferenceRow.add(defaultValue);
      }
    }
    inferenceRows.add(inferenceRow);
  }
  
  final inferenceData = [orderedFeatures, ...inferenceRows];
  
  return DataFrame(inferenceData);
}

Future<Map<String, DataFrame>> fetchBatchInferenceSamples({
  required int nRecords,
  required int kMinutes,
}) async {
  final db = await getDatabaseMonitor().requestDatabaseAccess();
  if (db == null) {
    throw Exception('Failed to acquire database access');
  }
  
  final userId = getSessionManager().userId;
  final cutoffTime = DateTime.now().toUtc().subtract(Duration(minutes: kMinutes)).toIso8601String();
  final timeStamp = DateTime.now().toUtc().toIso8601String();
  final today = timeStamp.substring(0, 10);
  
  const pairsQuery = '''
    SELECT user_uuid, question_id
    FROM user_question_answer_pairs
    WHERE user_uuid = ?
      AND (last_prob_calc IS NULL OR last_prob_calc < ?)
    ORDER BY last_prob_calc ASC
    LIMIT ?
  ''';
  
  final pairs = await db.rawQuery(pairsQuery, [userId, cutoffTime, nRecords]);
  final questionIds = pairs.map((p) => p['question_id'] as String).toList();
  
  if (questionIds.isEmpty) {
    getDatabaseMonitor().releaseDatabaseAccess();
    QuizzerLogger.logMessage('No records found for batch inference');
    return {
      'primary_keys': DataFrame([]),
      'raw_inference_data': DataFrame([]),
    };
  }
  
  QuizzerLogger.logMessage('Fetched ${questionIds.length} user-question pairs for batch inference');
  
  final qidPlaceholders = List.filled(questionIds.length, '?').join(',');
  final questionMetadataQuery = '''
    SELECT question_vector, module_name, question_type, options, question_elements, question_id
    FROM question_answer_pairs
    WHERE question_id IN ($qidPlaceholders)
  ''';
  
  final questionResults = await db.rawQuery(questionMetadataQuery, questionIds);
  final questionDataMap = {for (var q in questionResults) q['question_id'] as String: q};
  
  final userQuestionQuery = '''
    SELECT 
      question_id,
      avg_reaction_time,
      total_correct_attempts,
      total_incorect_attempts,
      total_attempts,
      question_accuracy_rate,
      revision_streak,
      last_revised,
      day_time_introduced
    FROM user_question_answer_pairs
    WHERE user_uuid = ? AND question_id IN ($qidPlaceholders)
  ''';
  
  final userQuestionResults = await db.rawQuery(userQuestionQuery, [userId, ...questionIds]);
  final userQuestionDataMap = {for (var uq in userQuestionResults) uq['question_id'] as String: uq};
  
  const userStatsQuery = '''
    SELECT *
    FROM user_daily_stats
    WHERE user_id = ? AND record_date = ?
    LIMIT 1
  ''';
  
  final userStatsResults = await db.rawQuery(userStatsQuery, [userId, today]);
  final userStatsVector = userStatsResults.isNotEmpty ? jsonEncode(userStatsResults.first) : null;
  
  const modulePerformanceQuery = '''
    SELECT 
      module_name,
      num_mcq,
      num_fitb,
      num_sata,
      num_tf,
      num_so,
      num_total,
      total_seen,
      percentage_seen,
      total_correct_attempts,
      total_incorrect_attempts,
      total_attempts,
      overall_accuracy,
      avg_attempts_per_question,
      avg_reaction_time
    FROM user_module_activation_status
    WHERE user_id = ?
    ORDER BY module_name
  ''';
  
  final modulePerformanceResults = await db.rawQuery(modulePerformanceQuery, [userId]);
  
  String? modulePerformanceVector;
  if (modulePerformanceResults.isNotEmpty) {
    final now = DateTime.parse(timeStamp);
    
    const lastSeenQuery = '''
      SELECT 
        qap.module_name,
        MAX(uqap.last_revised) as last_seen_date
      FROM user_question_answer_pairs uqap
      INNER JOIN question_answer_pairs qap ON uqap.question_id = qap.question_id
      WHERE uqap.user_uuid = ?
      GROUP BY qap.module_name
    ''';
    
    final lastSeenResults = await db.rawQuery(lastSeenQuery, [userId]);
    final moduleLastSeen = {for (var r in lastSeenResults) r['module_name'] as String: r['last_seen_date'] as String?};
    
    final processedModuleRecords = <Map<String, dynamic>>[];
    for (final moduleRecord in modulePerformanceResults) {
      final processedRecord = Map<String, dynamic>.from(moduleRecord);
      final moduleNameKey = moduleRecord['module_name'] as String;
      
      double daysSinceLastSeen = 0.0;
      final lastSeenDateStr = moduleLastSeen[moduleNameKey];
      if (lastSeenDateStr != null) {
        final lastSeenDate = DateTime.parse(lastSeenDateStr);
        daysSinceLastSeen = now.difference(lastSeenDate).inMicroseconds / Duration.microsecondsPerDay;
      }
      
      processedRecord['days_since_last_seen'] = daysSinceLastSeen;
      processedModuleRecords.add(processedRecord);
    }
    
    modulePerformanceVector = jsonEncode(processedModuleRecords);
  }
  
  const userProfileQuery = '''
    SELECT 
      highest_level_edu,
      undergrad_major,
      undergrad_minor,
      grad_major,
      years_since_graduation,
      education_background,
      teaching_experience,
      profile_picture,
      country_of_origin,
      current_country,
      current_state,
      current_city,
      urban_rural,
      religion,
      political_affilition,
      marital_status,
      num_children,
      veteran_status,
      native_language,
      secondary_languages,
      num_languages_spoken,
      birth_date,
      age,
      household_income,
      learning_disabilities,
      physical_disabilities,
      housing_situation,
      birth_order,
      current_occupation,
      years_work_experience,
      hours_worked_per_week,
      total_job_changes
    FROM user_profile
    WHERE uuid = ?
    LIMIT 1
  ''';
  
  final userProfileResults = await db.rawQuery(userProfileQuery, [userId]);
  final userProfileRecord = userProfileResults.isNotEmpty ? jsonEncode(userProfileResults.first) : null;
  
  getDatabaseMonitor().releaseDatabaseAccess();
  
  final List<Map<String, dynamic>> samples = [];
  final List<Map<String, dynamic>> primaryKeys = [];
  
  for (final questionId in questionIds) {
    final questionData = questionDataMap[questionId];
    final userQuestionData = userQuestionDataMap[questionId];
    
    if (questionData == null || userQuestionData == null) continue;
    
    primaryKeys.add({
      'user_uuid': userId,
      'question_id': questionId,
      'prob_result': null,
    });
    
    final questionVector = questionData['question_vector'] as String?;
    final moduleName = questionData['module_name'] as String;
    final questionType = questionData['question_type'] as String;
    
    int numMcqOptions = 0;
    int numSoOptions = 0;
    int numSataOptions = 0;
    int numBlanks = 0;
    
    if (questionType == 'multiple_choice' || questionType == 'select_all_that_apply' || questionType == 'sort_order') {
      final optionsJson = questionData['options'] as String?;
      if (optionsJson != null) {
        final options = decodeValueFromDB(optionsJson);
        final optionCount = options.length;
        
        switch (questionType) {
          case 'multiple_choice':
            numMcqOptions = optionCount;
            break;
          case 'select_all_that_apply':
            numSataOptions = optionCount;
            break;
          case 'sort_order':
            numSoOptions = optionCount;
            break;
        }
      }
    } else if (questionType == 'fill_in_the_blank') {
      final questionElementsJson = questionData['question_elements'] as String?;
      if (questionElementsJson != null) {
        final questionElements = decodeValueFromDB(questionElementsJson);
        numBlanks = questionElements.where((element) => element is Map && element['type'] == 'blank').length;
      }
    }
    
    final avgReactTime = userQuestionData['avg_reaction_time'] as double? ?? 0.0;
    final totalCorrectAttempts = userQuestionData['total_correct_attempts'] as int? ?? 0;
    final totalIncorrectAttempts = userQuestionData['total_incorect_attempts'] as int? ?? 0;
    final totalAttempts = userQuestionData['total_attempts'] as int? ?? 0;
    final accuracyRate = userQuestionData['question_accuracy_rate'] as double? ?? 0.0;
    final revisionStreak = userQuestionData['revision_streak'] as int? ?? 0;
    final lastRevisedDate = userQuestionData['last_revised'] as String?;
    final dayTimeIntroduced = userQuestionData['day_time_introduced'] as String?;
    
    final wasFirstAttempt = totalAttempts == 0;
    
    double daysSinceLastRevision = 0.0;
    if (lastRevisedDate != null) {
      final lastRevised = DateTime.parse(lastRevisedDate);
      final now = DateTime.parse(timeStamp);
      daysSinceLastRevision = now.difference(lastRevised).inMicroseconds / Duration.microsecondsPerDay;
    }
    
    double daysSinceFirstIntroduced = 0.0;
    double attemptDayRatio = 0.0;
    if (dayTimeIntroduced != null) {
      final firstIntroduced = DateTime.parse(dayTimeIntroduced);
      final now = DateTime.parse(timeStamp);
      daysSinceFirstIntroduced = now.difference(firstIntroduced).inMicroseconds / Duration.microsecondsPerDay;
      
      if (daysSinceFirstIntroduced > 0) {
        attemptDayRatio = totalAttempts / daysSinceFirstIntroduced;
      }
    }
    
    final sampleData = {
      'module_name': moduleName,
      'question_type': questionType,
      'num_mcq_options': numMcqOptions,
      'num_so_options': numSoOptions,
      'num_sata_options': numSataOptions,
      'num_blanks': numBlanks,
      'avg_react_time': avgReactTime,
      'was_first_attempt': wasFirstAttempt ? 1 : 0,
      'total_correct_attempts': totalCorrectAttempts,
      'total_incorrect_attempts': totalIncorrectAttempts,
      'total_attempts': totalAttempts,
      'accuracy_rate': accuracyRate,
      'revision_streak': revisionStreak,
      'time_of_presentation': timeStamp,
      'last_revised_date': lastRevisedDate,
      'days_since_last_revision': daysSinceLastRevision,
      'days_since_first_introduced': daysSinceFirstIntroduced,
      'attempt_day_ratio': attemptDayRatio,
    };
    
    if (questionVector != null) {
      sampleData['question_vector'] = questionVector;
    }
    
    if (userStatsVector != null) {
      sampleData['user_stats_vector'] = userStatsVector;
    }
    
    if (modulePerformanceVector != null) {
      sampleData['module_performance_vector'] = modulePerformanceVector;
    }
    
    if (userProfileRecord != null) {
      sampleData['user_profile_record'] = userProfileRecord;
    }
    
    samples.add(sampleData);
  }
  
  QuizzerLogger.logSuccess('Generated ${samples.length} complete inference samples with batched queries');
  
  if (samples.isEmpty) {
    return {
      'primary_keys': DataFrame([]),
      'raw_inference_data': DataFrame([]),
    };
  }
  
  final pkHeaders = primaryKeys.first.keys.toList();
  final pkRows = primaryKeys.map((pk) => pkHeaders.map((header) => pk[header]).toList()).toList();
  final pkData = [pkHeaders, ...pkRows];
  
  final headers = samples.first.keys.toList();
  final rows = samples.map((sample) => headers.map((header) => sample[header]).toList()).toList();
  final allData = [headers, ...rows];
  
  return {
    'primary_keys': DataFrame(pkData),
    'raw_inference_data': DataFrame(allData),
  };
}