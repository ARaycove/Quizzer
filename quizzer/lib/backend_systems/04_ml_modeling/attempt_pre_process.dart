import 'package:ml_dataframe/ml_dataframe.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
// import 'package:ml_algo/ml_algo.dart';
import 'package:ml_preprocessing/ml_preprocessing.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/ml_models_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_attempts_table.dart';
import 'package:quizzer/backend_systems/05_question_queue_server/circulation_worker.dart';

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
    // QuizzerLogger.logMessage('Starting to decode JSON fields in DataFrame...');
    
    if (rawDataFrame.rows.isEmpty) {
      // QuizzerLogger.logMessage('Empty DataFrame provided, returning as-is');
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
    
    // QuizzerLogger.logSuccess('Successfully decoded DataFrame with ${decodedDataFrame.rows.length} rows and ${decodedDataFrame.header.length} columns');
    
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
  // QuizzerLogger.logMessage('Starting feature unpacking...');
  DataFrame returnFrame = dataFrame;
  
  // QuizzerLogger.logMessage('Initial rows: ${returnFrame.rows.length}');
  
  returnFrame = returnFrame.dropSeries(names: [
    "time_stamp", "question_id", "participant_id", 
    "last_revised_date", "time_of_presentation"
  ]);
  // QuizzerLogger.logMessage('After initial drop: ${returnFrame.rows.length}');
  
  returnFrame = _unpackMapFeatures(dataFrame: returnFrame, featureNames: ["user_stats_vector"], prefix: "user_stats");
  // QuizzerLogger.logMessage('After user_stats_vector unpack: ${returnFrame.rows.length}');
  
  returnFrame = _unpackStreakFeatures(dataFrame: returnFrame, featureNames: ["user_stats_revision_streak_sum"], prefix: "rs");
  // QuizzerLogger.logMessage('After streak features unpack: ${returnFrame.rows.length}');
  
  returnFrame = _unpackMapFeatures(dataFrame: returnFrame, featureNames: ["user_profile_record"], prefix: "up");
  // QuizzerLogger.logMessage('After user_profile_record unpack: ${returnFrame.rows.length}');
  
  returnFrame = _unpackVectorFeatures(dataFrame: returnFrame, featureNames: ["question_vector"], prefix: "qv");
  // QuizzerLogger.logMessage('After question_vector unpack: ${returnFrame.rows.length}');
  
  returnFrame = _unpackKnnPerformanceVector(returnFrame, "knn");
  // QuizzerLogger.logMessage('After knn unpack: ${returnFrame.rows.length}');



  // QuizzerLogger.logSuccess('Feature unpacking complete');
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


// DataFrame _unpackModulePerformanceVector(DataFrame dataFrame, {required String prefix}) {
//   if (dataFrame.rows.isEmpty) return dataFrame;
  
//   final originalHeaders = dataFrame.header.toList();
//   final originalRows = dataFrame.rows.map((row) => row.toList()).toList();
  
//   final colIndex = originalHeaders.indexOf('module_performance_vector');
//   if (colIndex == -1) return dataFrame;
  
//   // Modules to exclude from unpacking
//   final excludedModules = {
//     "dummy module", "multi field test", "new module name", "test module",
//     "test module 1", "test module 10", "test module 2", "test module 3",
//     "test module 4", "test module 5", "test module 6", "test module 7",
//     "test module 8", "test module 9", "test module with underscores",
//     "testmodule", "testmodule0", "testmodule1", "testmodule2", "testmodule3",
//     "testmodule4", "algebra 1-3", "algebra & trigonometry", "testmodule0 edited"
//   };
  
//   // Get all unique module names and performance keys
//   final allModules = <String>{};
//   final allKeys = <String>{};
  
//   for (final row in originalRows) {
//     final value = row[colIndex];
//     List<dynamic> moduleData;
    
//     if (value is String) {
//       moduleData = decodeValueFromDB(value) as List<dynamic>;
//     } else if (value is List) {
//       moduleData = value;
//     } else {
//       continue;
//     }
    
//     for (final module in moduleData) {
//       if (module is Map<String, dynamic>) {
//         final moduleName = module['module_name'] as String?;
//         if (moduleName != null && !excludedModules.contains(moduleName)) {
//           allModules.add(moduleName);
//           for (final key in module.keys) {
//             if (key != 'module_name') {
//               allKeys.add(key);
//             }
//           }
//         }
//       }
//     }
//   }
  
//   final sortedModules = allModules.toList()..sort();
//   final sortedKeys = allKeys.toList()..sort();
  
//   // Build new headers and rows
//   final newHeaders = <String>[];
//   final newRows = List.generate(originalRows.length, (i) => <dynamic>[]);
  
//   // Add original columns except module_performance_vector
//   for (int i = 0; i < originalHeaders.length; i++) {
//     if (i != colIndex) {
//       newHeaders.add(originalHeaders[i]);
//       for (int rowIndex = 0; rowIndex < originalRows.length; rowIndex++) {
//         newRows[rowIndex].add(originalRows[rowIndex][i]);
//       }
//     }
//   }
  
//   // Add unpacked module columns with prefix
//   for (final moduleName in sortedModules) {
//     for (final key in sortedKeys) {
//       newHeaders.add('${prefix}_${moduleName}_$key');
//     }
//   }
  
//   // Extract module performance values
//   for (int rowIndex = 0; rowIndex < originalRows.length; rowIndex++) {
//     final value = originalRows[rowIndex][colIndex];
//     final Map<String, Map<String, dynamic>> moduleMap = {};
    
//     if (value != null) {
//       List<dynamic> moduleData;
      
//       if (value is String) {
//         moduleData = decodeValueFromDB(value) as List<dynamic>;
//       } else if (value is List) {
//         moduleData = value;
//       } else {
//         moduleData = [];
//       }
      
//       for (final module in moduleData) {
//         if (module is Map<String, dynamic>) {
//           final moduleName = module['module_name'] as String?;
//           if (moduleName != null && !excludedModules.contains(moduleName)) {
//             moduleMap[moduleName] = module;
//           }
//         }
//       }
//     }
    
//     // Add values for each module-key combination, filling with 0 for missing data
//     for (final moduleName in sortedModules) {
//       for (final key in sortedKeys) {
//         final moduleData = moduleMap[moduleName];
//         newRows[rowIndex].add(moduleData?[key] ?? 0);
//       }
//     }
//   }
  
//   return DataFrame([newHeaders, ...newRows]);
// }

DataFrame _unpackKnnPerformanceVector(DataFrame dataFrame, String prefix) {
  if (!dataFrame.header.contains('knn_performance_vector')) {
    return dataFrame;
  }
  
  final excludedFields = {'time_of_presentation', 'last_revised_date'};
  final knnColumnIndex = dataFrame.header.toList().indexOf('knn_performance_vector');
  final rows = dataFrame.rows.toList();
  
  // First pass: get max neighbors and all fields
  int maxNeighbors = 0;
  final Set<String> allFieldsSet = {};
  
  for (final row in rows) {
    final knnValue = row.toList()[knnColumnIndex];
    if (knnValue == null) continue;
    
    final List<dynamic> knnList = (knnValue is String) 
        ? decodeValueFromDB(knnValue) as List<dynamic>
        : knnValue as List<dynamic>;
    
    if (knnList.length > maxNeighbors) {
      maxNeighbors = knnList.length;
    }
    
    for (final neighbor in knnList) {
      if (neighbor is Map) {
        for (final key in neighbor.keys) {
          allFieldsSet.add(key as String);
        }
      }
    }
  }
  
  // Remove excluded fields
  final allFields = allFieldsSet.difference(excludedFields).toList();
  
  // Build knn data for each row
  final List<Map<String, dynamic>> knnData = [];
  
  for (final row in rows) {
    final knnValue = row.toList()[knnColumnIndex];
    final Map<String, dynamic> rowData = {};
    
    // Add is_missing flag for entire vector
    if (knnValue == null || 
        (knnValue is List && knnValue.isEmpty) ||
        (knnValue is String && (decodeValueFromDB(knnValue) as List).isEmpty)) {
      rowData['${prefix}_vector_is_missing'] = 1;
    } else {
      rowData['${prefix}_vector_is_missing'] = 0;
    }
    
    if (knnValue != null) {
      final List<dynamic> knnList = (knnValue is String)
          ? decodeValueFromDB(knnValue) as List<dynamic>
          : knnValue as List<dynamic>;

      for (int i = 0; i < knnList.length; i++) {
        final neighborNum = (i + 1).toString().padLeft(2, '0');
        final neighbor = knnList[i];
        if (neighbor is Map) {
          for (final field in allFields) {
            final value = neighbor[field];
            // Convert booleans to integers
            final processedValue = (value is bool) ? (value ? 1 : 0) : (value ?? 0);
            rowData['${prefix}_${neighborNum}_$field'] = processedValue;
          }
        }
      }

    }
    
    // Fill missing values with 0
    for (int i = 0; i < maxNeighbors; i++) {
      final neighborNum = (i + 1).toString().padLeft(2, '0');
      for (final field in allFields) {
        final colName = '${prefix}_${neighborNum}_$field';
        if (!rowData.containsKey(colName)) {
          rowData[colName] = 0;
        }
      }
    }
    
    knnData.add(rowData);
  }
  
  // Get all column names from knn data (sorted for consistency)
  final knnColumnNames = knnData.isEmpty ? <String>[] : knnData.first.keys.toList()..sort();
  
  // Build new dataframe by concatenating original (minus knn column) with flattened knn data
  final originalHeaders = dataFrame.header.toList();
  final originalRows = dataFrame.rows.map((row) => row.toList()).toList();
  
  final newHeaders = <String>[];
  final newRows = <List<dynamic>>[];
  
  // Add all original columns except knn_performance_vector
  for (int colIdx = 0; colIdx < originalHeaders.length; colIdx++) {
    if (colIdx != knnColumnIndex) {
      newHeaders.add(originalHeaders[colIdx]);
    }
  }
  
  // Add knn columns
  newHeaders.addAll(knnColumnNames);
  
  // Build rows
  for (int rowIdx = 0; rowIdx < originalRows.length; rowIdx++) {
    final newRow = <dynamic>[];
    
    // Add original row data (except knn column)
    for (int colIdx = 0; colIdx < originalHeaders.length; colIdx++) {
      if (colIdx != knnColumnIndex) {
        newRow.add(originalRows[rowIdx][colIdx]);
      }
    }
    
    // Add knn row data
    for (final colName in knnColumnNames) {
      newRow.add(knnData[rowIdx][colName]);
    }
    
    newRows.add(newRow);
  }
  
  return DataFrame([newHeaders, ...newRows]);
}

Future<DataFrame> oneHotEncodeDataFrame(DataFrame inputDataFrame) async {
  if (inputDataFrame.rows.isEmpty) {
    return inputDataFrame;
  }
  
  final headers = inputDataFrame.header.toList();
  final rows = inputDataFrame.rows.map((row) => row.toList()).toList();
  
  final categoricalColumns = <String>[];
  
  for (int colIndex = 0; colIndex < headers.length; colIndex++) {
    final columnName = headers[colIndex];
    bool isCategorical = false;
    
    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      if (colIndex >= rows[rowIndex].length) continue;
      
      final value = rows[rowIndex][colIndex];
      if (value is String && num.tryParse(value) == null) {
        isCategorical = true;
        break;
      }
    }
    
    if (isCategorical) {
      categoricalColumns.add(columnName);
    }
  }
  
  // QuizzerLogger.logMessage('Found ${categoricalColumns.length} categorical columns to encode: ${categoricalColumns.join(", ")}');
  
  if (categoricalColumns.isEmpty) {
    return inputDataFrame;
  }
  
  for (int colIndex = 0; colIndex < headers.length; colIndex++) {
    final columnName = headers[colIndex];
    if (categoricalColumns.contains(columnName)) {
      for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        if (colIndex >= rows[rowIndex].length) continue;
        
        final value = rows[rowIndex][colIndex];
        if (value is num || (value is String && num.tryParse(value) != null)) {
          rows[rowIndex][colIndex] = null;
        }
        if (rows[rowIndex][colIndex] == null) {
          rows[rowIndex][colIndex] = 'missing';
        }
      }
    }
  }
  
  // Log what values are in each categorical column after preprocessing
  for (final catCol in categoricalColumns) {
    final colIndex = headers.indexOf(catCol);
    final uniqueValues = <String>{};
    for (final row in rows) {
      if (colIndex < row.length && row[colIndex] != null) {
        uniqueValues.add(row[colIndex].toString());
      }
    }
    // QuizzerLogger.logMessage('Column "$catCol" unique values after preprocessing: ${uniqueValues.join(", ")}');
  }
  
  final processedData = [headers, ...rows];
  final processedDataFrame = DataFrame(processedData);
  
  // QuizzerLogger.logMessage('About to encode. ProcessedDataFrame: ${processedDataFrame.rows.length} rows');
  
  final encoder = Encoder.oneHot(processedDataFrame, columnNames: categoricalColumns);
  final encodedDataFrame = encoder.process(processedDataFrame);
  
  // QuizzerLogger.logMessage('Encoding complete. Output: ${encodedDataFrame.rows.length} rows, ${encodedDataFrame.header.length} cols');
  
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
        if (value == null || (value is num && !value.isFinite)) {
          inferenceRow.add(defaultValue);
        } else {
          inferenceRow.add(value);
        }
      } else {
        inferenceRow.add(defaultValue);
      }
    }
    inferenceRows.add(inferenceRow);
  }
  
  final inferenceData = [orderedFeatures, ...inferenceRows];
  
  return DataFrame(inferenceData);
}

/// Fetches batch inference samples for questions in circulation or connected to circulating questions.
/// 
/// Only processes questions that are:
/// - Currently in circulation, OR
/// - Not circulating but connected to a circulating question
/// 
/// This filtering uses the CirculationWorker's cached data structures for efficiency.
/// 
/// Parameters:
/// - [nRecords]: Maximum number of records to fetch
/// - [kMinutes]: Time window in minutes - only fetch records not calculated within this period
/// 
/// Returns a Map containing:
/// - 'primary_keys': DataFrame with user_uuid and question_id columns
/// - 'raw_inference_data': DataFrame with all features needed for inference
Future<Map<String, DataFrame>> fetchBatchInferenceSamples({required int nRecords, required int kMinutes}) async {
  // Validate user session
  final userId = getSessionManager().userId;
  if (userId == null) throw Exception('User ID is null');
  
  // Get eligible questions from CirculationWorker's cached sets
  // Combines circulating questions and non-circulating questions connected to circulation
  final circWorker = CirculationWorker();
  final eligibleQuestions = {...circWorker.circulatingQuestions, ...circWorker.nonCirculatingConnected};
  
  // Early return if no eligible questions
  if (eligibleQuestions.isEmpty) {
    return {
      'primary_keys': DataFrame([]),
      'raw_inference_data': DataFrame([])
    };
  }
  
  // Acquire database access
  final db = await getDatabaseMonitor().requestDatabaseAccess();
  if (db == null) throw Exception('Failed to acquire database access');
  
  // Calculate cutoff time for filtering stale calculations
  final cutoffTime = DateTime.now().subtract(Duration(minutes: kMinutes)).toUtc().toIso8601String();
  
  // Build IN clause placeholders for eligible questions
  final placeholders = List.filled(eligibleQuestions.length, '?').join(',');
  
  // Query pairs that:
  // 1. Belong to the current user
  // 2. Are in the eligible questions set (circulating or connected)
  // 3. Need recalculation (null or stale last_prob_calc)
  // 4. Have required ML features (question_vector and k_nearest_neighbors)
  final pairsQuery = '''
    SELECT user_question_answer_pairs.user_uuid, user_question_answer_pairs.question_id
    FROM user_question_answer_pairs
    INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
    WHERE user_question_answer_pairs.user_uuid = ?
      AND user_question_answer_pairs.question_id IN ($placeholders)
      AND (user_question_answer_pairs.last_prob_calc IS NULL OR user_question_answer_pairs.last_prob_calc < ?)
      AND question_answer_pairs.question_vector IS NOT NULL
      AND question_answer_pairs.k_nearest_neighbors IS NOT NULL
    ORDER BY user_question_answer_pairs.last_prob_calc ASC
    LIMIT ?
  ''';
  
  // Execute query with user_id, all eligible question IDs, cutoff time, and limit
  final pairs = await db.rawQuery(pairsQuery, [userId, ...eligibleQuestions, cutoffTime, nRecords]);
  
  // Early return if no pairs found
  if (pairs.isEmpty) {
    getDatabaseMonitor().releaseDatabaseAccess();
    return {
      'primary_keys': DataFrame([]),
      'raw_inference_data': DataFrame([])
    };
  }
  
  // QuizzerLogger.logMessage('Fetched ${pairs.length} user-question pairs for batch inference');
  
  // Prepare common data needed for all samples
  final timeStamp = DateTime.now().toUtc().toIso8601String();
  final userStatsVector = await fetchUserStatsVector(db: db, userId: userId);
  final userProfileRecord = await fetchUserProfileRecord(db: db, userId: userId);
  
  // Storage for constructed samples and their primary keys
  final List<Map<String, dynamic>> samples = [];
  final List<List<dynamic>> primaryKeys = [];
  
  // Build feature vectors for each question-user pair
  for (final pair in pairs) {
    final questionId = pair['question_id'] as String;
    
    // Fetch question metadata (type, options, etc.)
    final questionMetadata = await fetchQuestionMetadata(db: db, questionId: questionId);
    
    // Fetch user's performance on this specific question
    final userQuestionPerformance = await fetchUserQuestionPerformance(db: db, userId: userId, questionId: questionId, timeStamp: timeStamp);
    
    // Fetch performance on k-nearest neighbor questions
    final knnPerformanceVector = await fetchKNearestPerformanceVector(db: db, userId: userId, kNearestNeighbors: questionMetadata['k_nearest_neighbors'] as String?, timeStamp: timeStamp);
    
    // Store primary key
    primaryKeys.add([userId, questionId]);
    
    // Construct complete feature vector for ML inference
    samples.add({
      'module_name': questionMetadata['module_name'],
      'question_type': questionMetadata['question_type'],
      'num_mcq_options': questionMetadata['num_mcq_options'],
      'num_so_options': questionMetadata['num_so_options'],
      'num_sata_options': questionMetadata['num_sata_options'],
      'num_blanks': questionMetadata['num_blanks'],
      'avg_react_time': userQuestionPerformance['avg_react_time'],
      'was_first_attempt': userQuestionPerformance['was_first_attempt'] ? 1 : 0,
      'total_correct_attempts': userQuestionPerformance['total_correct_attempts'],
      'total_incorrect_attempts': userQuestionPerformance['total_incorrect_attempts'],
      'total_attempts': userQuestionPerformance['total_attempts'],
      'accuracy_rate': userQuestionPerformance['accuracy_rate'],
      'revision_streak': userQuestionPerformance['revision_streak'],
      'time_of_presentation': userQuestionPerformance['time_of_presentation'],
      'last_revised_date': userQuestionPerformance['last_revised_date'],
      'days_since_last_revision': userQuestionPerformance['days_since_last_revision'],
      'days_since_first_introduced': userQuestionPerformance['days_since_first_introduced'],
      'attempt_day_ratio': userQuestionPerformance['attempt_day_ratio'],
      'question_vector': questionMetadata['question_vector'],
      'user_stats_vector': userStatsVector,
      'user_profile_record': userProfileRecord,
      'knn_performance_vector': knnPerformanceVector,
    });
  }
  
  // Release database access
  getDatabaseMonitor().releaseDatabaseAccess();
  
  // Safety check (should not happen given earlier check)
  if (samples.isEmpty) {
    return {
      'primary_keys': DataFrame([]),
      'raw_inference_data': DataFrame([])
    };
  }
  
  // Convert samples to DataFrame format
  final headers = samples.first.keys.toList();
  final rows = samples.map((sample) => headers.map((header) => sample[header]).toList()).toList();
  final primaryKeysHeaders = ['user_uuid', 'question_id'];
  
  // Return both primary keys and feature data as DataFrames
  return {
    'primary_keys': DataFrame([primaryKeysHeaders, ...primaryKeys]),
    'raw_inference_data': DataFrame([headers, ...rows])
  };
}