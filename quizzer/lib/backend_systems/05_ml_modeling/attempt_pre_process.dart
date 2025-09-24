import 'package:ml_dataframe/ml_dataframe.dart';
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
          .limit(5);
      
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

/// Unpacks complex fields in the DataFrame into individual feature columns
/// Converts nested data structures (Maps, Lists) into flat feature columns
/// 
/// Args:
///   decodedDataFrame: The DataFrame with properly decoded JSON fields
/// 
/// Returns:
///   A new DataFrame with all complex fields unpacked into individual columns
/// 
/// Throws:
///   Exception: If unpacking fails or DataFrame processing issues occur
Future<DataFrame> unpackDataFrameFeatures(DataFrame decodedDataFrame) async {
  try {
    QuizzerLogger.logMessage('Starting to unpack DataFrame features...');

    if (decodedDataFrame.rows.isEmpty) {
      QuizzerLogger.logMessage('Empty DataFrame provided, returning as-is');
      return decodedDataFrame;
    }

    final List<String> headers = decodedDataFrame.header.toList();
    final List<Map<String, dynamic>> processedRows = [];

    // Sync fields to skip during unpacking
    final Set<String> skipFields = {
      'has_been_synced',
      'edits_are_synced',
      'last_modified_timestamp'
    };

    // Process each row
    final List<Iterable<dynamic>> rowsList = decodedDataFrame.rows.toList();
    for (int rowIndex = 0; rowIndex < rowsList.length; rowIndex++) {
      final List<dynamic> row = rowsList[rowIndex].toList();
      final Map<String, dynamic> processedRow = {};

      for (int colIndex = 0;
          colIndex < headers.length && colIndex < row.length;
          colIndex++) {
        final String columnName = headers[colIndex];
        final dynamic value = row[colIndex];

        // Skip sync fields
        if (skipFields.contains(columnName)) {
          continue;
        }

        if (value == null) {
          // just skip nulls at this stage
          continue;
        } else if (value is num) {
          processedRow[columnName] = value.toDouble();
        } else if (value is String) {
          processedRow[columnName] = value;
        } else if (value is List) {
          if (columnName == 'question_vector') {
            // Fully unpack question_vector into individual columns with short names
            for (int i = 0; i < value.length; i++) {
              processedRow['q_v_$i'] = (value[i] as num?)?.toDouble() ?? 0.0;
            }
          } else if (columnName == 'module_performance_vector') {
            // Unpack using moduleName as prefix
            for (final item in value) {
              if (item is Map && item.containsKey('module_name')) {
                final rawName = item['module_name'].toString();
                final modulePrefix = rawName
                    .toLowerCase()
                    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                    .replaceAll(RegExp(r'^_|_$'), '');

                for (final entry in item.entries) {
                  final String fieldName = entry.key;
                  if (fieldName == 'module_name') continue; // don’t duplicate name
                  final dynamic fieldValue = entry.value;

                  if (fieldValue is num) {
                    processedRow['${modulePrefix}_$fieldName'] =
                        fieldValue.toDouble();
                  } else if (fieldValue is String &&
                      fieldValue.isNotEmpty &&
                      fieldValue != 'null') {
                    processedRow['${modulePrefix}_$fieldName'] = fieldValue;
                  }
                }
              } else {
                QuizzerLogger.logError(
                    'module_performance_vector item missing module_name: $item');
              }
            }
          } else {
            // For all other lists, dynamically unpack each item
            for (int i = 0; i < value.length; i++) {
              final dynamic item = value[i];
              if (item is Map) {
                for (final entry in item.entries) {
                  final String fieldName = entry.key;
                  final dynamic fieldValue = entry.value;

                  if (fieldValue is num) {
                    processedRow['${columnName}_${i}_$fieldName'] =
                        fieldValue.toDouble();
                  } else if (fieldValue is String &&
                      fieldValue.isNotEmpty &&
                      fieldValue != 'null') {
                    processedRow['${columnName}_${i}_$fieldName'] = fieldValue;
                  }
                }
              } else if (item is num) {
                processedRow['${columnName}_$i'] = item.toDouble();
              } else if (item is String && item.isNotEmpty && item != 'null') {
                processedRow['${columnName}_$i'] = item;
              }
            }
            // Store list length
            processedRow['${columnName}_length'] = value.length.toDouble();
          }
        } else if (value is Map) {
          // Dynamically unpack ALL fields from maps
          for (final entry in value.entries) {
            final String fieldName = entry.key;
            final dynamic fieldValue = entry.value;

            if (skipFields.contains(fieldName)) continue;

            if (fieldValue is num) {
              processedRow['${columnName}_$fieldName'] = fieldValue.toDouble();
            } else if (fieldValue is String &&
                fieldValue.isNotEmpty &&
                fieldValue != 'null') {
              processedRow['${columnName}_$fieldName'] = fieldValue;
            } else if (fieldValue is List) {
              for (int i = 0; i < fieldValue.length; i++) {
                final dynamic listItem = fieldValue[i];
                if (listItem is num) {
                  processedRow['${columnName}_${fieldName}_$i'] =
                      listItem.toDouble();
                } else if (listItem is String &&
                    listItem.isNotEmpty &&
                    listItem != 'null') {
                  processedRow['${columnName}_${fieldName}_$i'] = listItem;
                }
              }
            } else if (fieldValue is Map) {
              for (final nestedEntry in fieldValue.entries) {
                final String nestedFieldName = nestedEntry.key;
                final dynamic nestedFieldValue = nestedEntry.value;

                if (nestedFieldValue is num) {
                  processedRow['${columnName}_${fieldName}_$nestedFieldName'] =
                      nestedFieldValue.toDouble();
                } else if (nestedFieldValue is String &&
                    nestedFieldValue.isNotEmpty &&
                    nestedFieldValue != 'null') {
                  processedRow['${columnName}_${fieldName}_$nestedFieldName'] =
                      nestedFieldValue;
                }
              }
            }
          }
          // store size of map
          processedRow['${columnName}_size'] = value.length.toDouble();
        } else {
          // Convert other types to string
          processedRow[columnName] = value.toString();
        }
      }
      processedRows.add(processedRow);
    }

    // Build consistent feature matrix
    final Set<String> allFeatures = {};
    for (final row in processedRows) {
      allFeatures.addAll(row.keys);
    }
    final List<String> sortedFeatures = allFeatures.toList()..sort();

    final List<List<dynamic>> matrix = [sortedFeatures];
    for (final row in processedRows) {
      final List<dynamic> rowData = [];
      for (final feature in sortedFeatures) {
        rowData.add(row[feature] ?? 0.0);
      }
      matrix.add(rowData);
    }

    final DataFrame unpackedDataFrame = DataFrame(matrix);

    QuizzerLogger.logSuccess(
        'Successfully unpacked DataFrame to ${sortedFeatures.length} features');

    List<String> fieldsToRemove = [
      "user_stats_vector_user_id",
      "participant_id",
      "question_id",
      "time_of_presentation",
      "time_stamp",
      "user_profile_record_size",
      "user_stats_vector_size",
      "user_stats_vector_record_date",
    ];

    // "user_stats_vector_revision_streak_sum" // needs to be unpacked

    DataFrame updatedDataFrame = unpackedDataFrame;

    for (String field in fieldsToRemove) {
      
      updatedDataFrame = updatedDataFrame.dropSeries(names: [field]);
    }
    
    return updatedDataFrame;
  } catch (e) {
    QuizzerLogger.logError('Error unpacking DataFrame features - $e');
    rethrow;
  }
}




/// Applies one-hot encoding to categorical columns in an unpacked DataFrame
/// 
/// Args:
///   unpackedDataFrame: The DataFrame with features already unpacked into individual columns
/// 
/// Returns:
///   A new DataFrame with categorical columns one-hot encoded
/// 
/// Throws:
///   Exception: If encoding fails or DataFrame processing issues occur
Future<DataFrame> oneHotEncodeDataFrame(DataFrame unpackedDataFrame) async {
  try {
    QuizzerLogger.logMessage('Starting one-hot encoding of categorical features...');
    
    if (unpackedDataFrame.rows.isEmpty) {
      QuizzerLogger.logMessage('Empty DataFrame provided, returning as-is');
      return unpackedDataFrame;
    }
    
    // Find categorical columns by examining first row for string values
    final List<String> categoricalColumns = [];
    final List<dynamic> firstRow = unpackedDataFrame.rows.first.toList();
    final List<String> headers = unpackedDataFrame.header.toList();
    
    for (int i = 0; i < headers.length && i < firstRow.length; i++) {
      if (firstRow[i] is String) {
        categoricalColumns.add(headers[i]);
      }
    }
    
    QuizzerLogger.logMessage('Found ${categoricalColumns.length} categorical columns: ${categoricalColumns.join(', ')}');
    
    if (categoricalColumns.isEmpty) {
      QuizzerLogger.logMessage('No categorical columns found, returning DataFrame as-is');
      return unpackedDataFrame;
    }
    
    // Apply one-hot encoding using ml_preprocessing
    final encoder = Encoder.oneHot(unpackedDataFrame, columnNames: categoricalColumns);
    final encodedDataFrame = encoder.process(unpackedDataFrame);
    
    QuizzerLogger.logSuccess('Successfully applied one-hot encoding. Final DataFrame has ${encodedDataFrame.header.length} total features');
    
    return encodedDataFrame;
  } catch (e) {
    QuizzerLogger.logError('Error applying one-hot encoding - $e');
    rethrow;
  }
}