import 'package:ml_dataframe/ml_dataframe.dart';
// import 'package:ml_algo/ml_algo.dart';
import 'package:ml_preprocessing/ml_preprocessing.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';

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
  try {
    QuizzerLogger.logMessage('Starting feature unpacking...');
    DataFrame returnFrame = dataFrame;

    returnFrame = dataFrame.dropSeries(names: ["time_stamp", "question_id", "participant_id", "last_revised_date", "time_of_presentation"]);

    returnFrame = _unpackVectorFeatures(dataFrame: returnFrame, featureNames: ["question_vector"], prefix: "q_v");
    returnFrame = _unpackModulePerformanceVector(returnFrame);
    returnFrame = _unpackMapFeatures(dataFrame: returnFrame, featureNames: ["user_stats_vector"], prefix: "user_stats");
    returnFrame = _unpackStreakFeatures(dataFrame: returnFrame, featureNames: ["user_stats_revision_streak_sum"], prefix: "rs_sum");
    returnFrame = _unpackMapFeatures(dataFrame: returnFrame, featureNames: ["user_profile_record"], prefix: "user_profile");


    returnFrame = returnFrame.dropSeries(names: ["user_stats_user_id", "user_stats_record_date", "user_stats_last_modified_timestamp", "user_profile_birth_date"]);
    // TODO Birth_Day should be used to dynamically update age, but is cleaned here
    QuizzerLogger.logSuccess('Feature unpacking complete - returning original DataFrame for now');
    return returnFrame;
    
  } catch (e) {
    QuizzerLogger.logError('Error unpacking DataFrame features - $e');
    rethrow;
  }
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


/// Unpacks module_performance_vector feature using module_name as prefix
DataFrame _unpackModulePerformanceVector(DataFrame dataFrame) {
  if (dataFrame.rows.isEmpty) return dataFrame;
  
  final originalHeaders = dataFrame.header.toList();
  final originalRows = dataFrame.rows.map((row) => row.toList()).toList();
  
  final colIndex = originalHeaders.indexOf('module_performance_vector');
  if (colIndex == -1) return dataFrame;
  
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
        if (moduleName != null) {
          allModules.add(moduleName);
          // Collect all keys except module_name
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
  
  // Add unpacked module columns
  for (final moduleName in sortedModules) {
    for (final key in sortedKeys) {
      newHeaders.add('${moduleName}_$key');
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
          if (moduleName != null) {
            moduleMap[moduleName] = module;
          }
        }
      }
    }
    
    // Add values for each module-key combination
    for (final moduleName in sortedModules) {
      for (final key in sortedKeys) {
        final moduleData = moduleMap[moduleName];
        newRows[rowIndex].add(moduleData?[key]);
      }
    }
  }
  
  return DataFrame([newHeaders, ...newRows]);
}

/// One-hot encodes categorical features in a DataFrame with special null value handling.
/// 
/// This function performs a two-step encoding process:
/// 1. Creates binary missing value indicators for columns containing nulls (only for user_profile features)
/// 2. Applies standard one-hot encoding to remaining categorical features only
/// 
/// For null values:
/// - If field_name starts with "user_profile" and == null, creates field_name_missing = 1, otherwise 0
/// - For other features, fills nulls with 0 for numeric columns, 'missing_value' for categorical columns
/// 
/// Args:
///   inputDataFrame: The DataFrame containing features to encode
/// 
/// Returns:
///   A new DataFrame with categorical columns one-hot encoded and null indicators added
/// 
/// Throws:
///   Exception: If encoding fails or DataFrame processing issues occur
Future<DataFrame> oneHotEncodeDataFrame(DataFrame inputDataFrame) async {
  try {
    if (inputDataFrame.rows.isEmpty) {
      return inputDataFrame;
    }
    
    final headers = inputDataFrame.header.toList();
    final rows = inputDataFrame.rows.map((row) => row.toList()).toList();
    
    // Step 1: Handle null values by creating missing indicators (only for user_profile features)
    final List<String> newHeaders = [];
    final List<List<dynamic>> processedRows = [];
    
    for (int colIndex = 0; colIndex < headers.length; colIndex++) {
      final columnName = headers[colIndex];
      bool hasNulls = false;
      
      // Check if column has null values
      for (final row in rows) {
        if (row[colIndex] == null) {
          hasNulls = true;
          break;
        }
      }
      
      // Only create missing indicators for user_profile features
      if (hasNulls && columnName.startsWith('user_profile')) {
        // Add missing indicator column
        newHeaders.add('${columnName}_missing');
        
        // Process rows for missing indicators
        for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
          if (processedRows.length <= rowIndex) {
            processedRows.add([]);
          }
          processedRows[rowIndex].add(rows[rowIndex][colIndex] == null ? 1 : 0);
        }
        
        // Replace nulls with placeholder for categorical encoding
        for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
          if (rows[rowIndex][colIndex] == null) {
            rows[rowIndex][colIndex] = 'missing_value';
          }
        }
        
        QuizzerLogger.logMessage('Created missing indicator for user_profile feature: $columnName');
      } else if (hasNulls) {
        // For non-user_profile features, just replace nulls with 0
        for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
          if (rows[rowIndex][colIndex] == null) {
            rows[rowIndex][colIndex] = 0;
          }
        }
        QuizzerLogger.logMessage('Replaced nulls with 0 for non-user_profile feature: $columnName');
      }
      
      newHeaders.add(columnName);
      for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        if (processedRows.length <= rowIndex) {
          processedRows.add([]);
        }
        processedRows[rowIndex].add(rows[rowIndex][colIndex]);
      }
    }
    
    // Create intermediate DataFrame with missing indicators
    final intermediateData = [newHeaders, ...processedRows];
    final intermediateDataFrame = DataFrame(intermediateData);
    
    // Step 2: Find categorical columns for one-hot encoding (exclude numeric and missing indicator columns)
    final categoricalColumns = <String>[];
    final firstRow = processedRows.isNotEmpty ? processedRows.first : [];
    
    QuizzerLogger.logMessage('One-hot encoding: analyzing columns for categorical features...');
    
    for (int i = 0; i < newHeaders.length && i < firstRow.length; i++) {
      final columnName = newHeaders[i];
      final value = firstRow[i];
      
      // Skip missing indicator columns
      if (columnName.endsWith('_missing')) {
        QuizzerLogger.logMessage('Skipping missing indicator column: $columnName');
        continue;
      }
      
      // Only add to categorical if it's actually a string and not a stringified number
      if (value is String) {
        // Check if it's a numeric string
        final numValue = num.tryParse(value);
        if (numValue == null) {
          // It's a true categorical string
          categoricalColumns.add(columnName);
          QuizzerLogger.logMessage('Found categorical column for encoding: $columnName (sample value: "$value")');
        } else {
          QuizzerLogger.logMessage('Skipping numeric string column: $columnName (sample value: "$value")');
        }
      } else {
        QuizzerLogger.logMessage('Skipping non-string column: $columnName (sample value: $value, type: ${value.runtimeType})');
      }
    }
    
    QuizzerLogger.logMessage('Total categorical columns found for one-hot encoding: ${categoricalColumns.length}');
    if (categoricalColumns.isNotEmpty) {
      QuizzerLogger.logMessage('Categorical columns to encode: ${categoricalColumns.join(", ")}');
    }
    
    if (categoricalColumns.isEmpty) {
      return intermediateDataFrame;
    }
    
    // Step 3: Apply one-hot encoding only to true categorical columns
    if (categoricalColumns.isEmpty) {
      return intermediateDataFrame;
    }
    
    final encoder = Encoder.oneHot(intermediateDataFrame, columnNames: categoricalColumns);
    final encodedDataFrame = encoder.process(intermediateDataFrame);
    
    // Step 4: Remove the generic "missing_value" columns that are meaningless
    final finalHeaders = encodedDataFrame.header.where((header) => header != 'missing_value').toList();
    final headerIndexMap = <String, int>{};
    for (int i = 0; i < encodedDataFrame.header.length; i++) {
      headerIndexMap[encodedDataFrame.header.elementAt(i)] = i;
    }
    
    final finalRows = encodedDataFrame.rows.map((row) {
      final rowList = row.toList();
      return finalHeaders.map((header) => rowList[headerIndexMap[header]!]).toList();
    }).toList();
    
    final finalData = [finalHeaders, ...finalRows];
    return DataFrame(finalData);
  } catch (e) {
    QuizzerLogger.logError('Error in oneHotEncodeDataFrame - $e');
    rethrow;
  }
}


/// Splits a DataFrame into training and testing sets with feature/target separation.
/// 
/// This function replicates the behavior of sklearn's train_test_split by:
/// 1. Separating features (X) from target (y) columns
/// 2. Shuffling the data if specified
/// 3. Splitting into train/test sets based on the specified ratio
/// 4. Returning four DataFrames: X_train, X_test, y_train, y_test
/// 
/// Args:
///   dataFrame: The input DataFrame containing both features and target
///   targetColumn: The name of the target column to predict
///   testSize: The proportion of data to use for testing (0.0 to 1.0), defaults to 0.2
///   shuffle: Whether to shuffle the data before splitting, defaults to true
/// 
/// Returns:
///   Map containing 'X_train', 'X_test', 'y_train', 'y_test' DataFrames
/// 
/// Throws:
///   Exception: If target column doesn't exist or testSize is invalid
Map<String, DataFrame> trainTestSplit({
  required DataFrame dataFrame,
  required String targetColumn,
  double testSize = 0.2,
  bool shuffle = true,
}) {
  if (testSize < 0.0 || testSize > 1.0) {
    throw Exception('testSize must be between 0.0 and 1.0, got: $testSize');
  }
  
  if (!dataFrame.header.contains(targetColumn)) {
    throw Exception('Target column "$targetColumn" not found in DataFrame headers: ${dataFrame.header}');
  }
  
  final headers = dataFrame.header.toList();
  final rows = dataFrame.rows.map((row) => row.toList()).toList();
  final targetIndex = headers.indexOf(targetColumn);
  
  // Generate indices
  final indices = List.generate(rows.length, (i) => i);
  if (shuffle) indices.shuffle();
  
  // Calculate split point
  final trainSize = ((1.0 - testSize) * rows.length).round();
  
  // Split indices
  final trainIndices = indices.sublist(0, trainSize);
  final testIndices = indices.sublist(trainSize);
  
  // Create feature headers (X) and target headers (y)
  final xHeaders = [...headers]..removeAt(targetIndex);
  final yHeaders = [headers[targetIndex]];
  
  // Build train/test sets
  final xTrainRows = trainIndices.map((i) {
    final row = [...rows[i]];
    row.removeAt(targetIndex);
    return row;
  }).toList();
  
  final xTestRows = testIndices.map((i) {
    final row = [...rows[i]];
    row.removeAt(targetIndex);
    return row;
  }).toList();
  
  final yTrainRows = trainIndices.map((i) => [rows[i][targetIndex]]).toList();
  final yTestRows = testIndices.map((i) => [rows[i][targetIndex]]).toList();
  
  return {
    'X_train': DataFrame([xHeaders, ...xTrainRows]),
    'X_test': DataFrame([xHeaders, ...xTestRows]),
    'y_train': DataFrame([yHeaders, ...yTrainRows]),
    'y_test': DataFrame([yHeaders, ...yTestRows]),
  };
}

/// Balances a training dataset by oversampling minority class only.
/// Duplicates minority class exactly once, no undersampling.
/// 
/// Args:
///   xTrain: Feature DataFrame
///   yTrain: Target DataFrame (single column)
/// 
/// Returns:
///   Map with 'X_balanced' and 'y_balanced' DataFrames
Map<String, DataFrame> balanceDataset({
  required DataFrame xTrain,
  required DataFrame yTrain,
}) {
  final yValues = yTrain.toMatrix().getColumn(0);
  
  // Count classes
  final classCount = <num, int>{};
  for (final value in yValues) {
    classCount[value] = (classCount[value] ?? 0) + 1;
  }
  
  QuizzerLogger.logMessage('Original class distribution:');
  for (final entry in classCount.entries) {
    final percentage = (entry.value / yValues.length * 100).toStringAsFixed(1);
    QuizzerLogger.logMessage('Class ${entry.key}: ${entry.value} samples ($percentage%)');
  }
  
  final minorityClass = classCount.entries.reduce((a, b) => a.value < b.value ? a : b).key;
  
  // Get indices for each class
  final minorityIndices = <int>[];
  final majorityIndices = <int>[];
  
  for (int i = 0; i < yValues.length; i++) {
    if (yValues[i] == minorityClass) {
      minorityIndices.add(i);
    } else {
      majorityIndices.add(i);
    }
  }
  
  // Oversample minority (duplicate exactly once) + keep ALL majority
  final balancedIndices = <int>[];
  balancedIndices.addAll(majorityIndices); // Keep ALL majority samples
  balancedIndices.addAll(minorityIndices); // Add minority once
  balancedIndices.addAll(minorityIndices); // Duplicate minority once
  
  // Shuffle final indices
  balancedIndices.shuffle();
  
  // Create balanced datasets
  final xRows = xTrain.rows.toList();
  final yRows = yTrain.rows.toList();
  
  final balancedXRows = balancedIndices.map((i) => xRows[i].toList()).toList();
  final balancedYRows = balancedIndices.map((i) => yRows[i].toList()).toList();
  
  final balancedX = DataFrame([xTrain.header.toList(), ...balancedXRows]);
  final balancedY = DataFrame([yTrain.header.toList(), ...balancedYRows]);
  
  // Count balanced classes
  final balancedYValues = balancedY.toMatrix().getColumn(0);
  final balancedClassCount = <num, int>{};
  for (final value in balancedYValues) {
    balancedClassCount[value] = (balancedClassCount[value] ?? 0) + 1;
  }
  
  QuizzerLogger.logMessage('Balanced class distribution:');
  for (final entry in balancedClassCount.entries) {
    final percentage = (entry.value / balancedYValues.length * 100).toStringAsFixed(1);
    QuizzerLogger.logMessage('Class ${entry.key}: ${entry.value} samples ($percentage%)');
  }
  QuizzerLogger.logSuccess('Dataset balanced: ${balancedYValues.length} total samples');
  
  return {
    'X_balanced': balancedX,
    'y_balanced': balancedY,
  };
}


/// Imputes missing values in a DataFrame by replacing nulls and "missing_value" strings with 0.0.
/// 
/// This function handles the common case where unpacked features have inconsistent 
/// lengths across rows, resulting in null values or "missing_value" placeholders.
/// All such values are replaced with 0.0 to ensure numerical consistency.
/// 
/// Args:
///   inputDataFrame: The DataFrame containing missing values to impute
/// 
/// Returns:
///   A new DataFrame with all missing values replaced with 0.0
/// 
/// Throws:
///   Exception: If DataFrame processing fails
DataFrame imputeMissingValues(DataFrame inputDataFrame) {
  try {
    if (inputDataFrame.rows.isEmpty) {
      return inputDataFrame;
    }
    
    final headers = inputDataFrame.header.toList();
    final imputedRows = <List<dynamic>>[];
    
    QuizzerLogger.logMessage('Imputing missing values: processing ${inputDataFrame.rows.length} rows...');
    
    int nullCount = 0;
    int missingValueCount = 0;
    
    for (final row in inputDataFrame.rows) {
      final rowList = row.toList();
      final imputedRow = <dynamic>[];
      
      for (int i = 0; i < headers.length; i++) {
        final value = i < rowList.length ? rowList[i] : null;
        
        if (value == null) {
          imputedRow.add(0.0);
          nullCount++;
        } else if (value is String && value == 'missing_value') {
          imputedRow.add(0.0);
          missingValueCount++;
        } else {
          imputedRow.add(value);
        }
      }
      
      imputedRows.add(imputedRow);
    }
    
    QuizzerLogger.logMessage('Imputation complete: replaced $nullCount nulls and $missingValueCount "missing_value" strings with 0.0');
    
    return DataFrame([headers, ...imputedRows]);
  } catch (e) {
    QuizzerLogger.logError('Error in imputeMissingValues - $e');
    rethrow;
  }
}