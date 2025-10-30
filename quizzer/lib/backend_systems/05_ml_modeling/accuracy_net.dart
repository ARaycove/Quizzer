// import 'package:quizzer/backend_systems/00_database_manager/tables/ml_models_table.dart';
// import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';
import 'package:ml_dataframe/ml_dataframe.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';

import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:typed_data';

Future<Interpreter> loadAccuracyNetModel() async {
  final localPath = path.join(await getQuizzerMediaPath(), 'accuracy_net.tflite');
  final file = File(localPath);
  
  if (!file.existsSync()) {
    try {
      QuizzerLogger.logMessage('Model file not found locally, fetching from Supabase...');
      
      final Uint8List bytes = await getSessionManager().supabase.storage
          .from('ml_models')
          .download('accuracy_net.tflite');
      
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      
      QuizzerLogger.logSuccess('Model file downloaded and saved to $localPath');
    } catch (e) {
      throw Exception('Failed to download accuracy_net.tflite from Supabase: $e');
    }
  }
  
  final interpreter = await Interpreter.fromFile(file);
  return interpreter;
}

Future<DataFrame> runBatchInference({
  required Interpreter interpreter,
  required DataFrame primaryKeysFrame,
  required DataFrame inputFrame,
  bool isRetry = false,
}) async {
  // QuizzerLogger.logMessage('=== Starting runBatchInference ===');
  
  final timeStamp = DateTime.now().toUtc().toIso8601String();
  final numRows = inputFrame.rows.length;
  final numFeatures = inputFrame.header.length;
  
  // QuizzerLogger.logMessage('Batch info: $numRows rows, $numFeatures features');
  
  // Validate interpreter state
  // QuizzerLogger.logMessage('Checking interpreter state...');
  try {
    final inputTensorDetails = interpreter.getInputTensor(0);
    // QuizzerLogger.logMessage('Input tensor retrieved successfully');
    // QuizzerLogger.logMessage('  Expected shape: ${inputTensorDetails.shape}');
    
    final expectedInputFeatures = inputTensorDetails.shape[1];
    // QuizzerLogger.logMessage('Model expects $expectedInputFeatures features, got $numFeatures features');
    
    if (expectedInputFeatures != numFeatures) {
      // QuizzerLogger.logError('SHAPE MISMATCH: Model expects $expectedInputFeatures but data has $numFeatures');
      
      if (!isRetry) {
        // QuizzerLogger.logWarning('Shape mismatch detected. Attempting to re-download model from Supabase...');
        
        // Close current interpreter
        interpreter.close();
        
        // Force download latest model
        try {
          await forceDownloadLatestModel();
          // QuizzerLogger.logSuccess('Model re-downloaded successfully');
          
          // Reload interpreter
          final newInterpreter = await loadAccuracyNetModel();
          // QuizzerLogger.logSuccess('New interpreter loaded');
          
          // Retry inference with new interpreter
          // QuizzerLogger.logMessage('Retrying inference with updated model...');
          return await runBatchInference(
            interpreter: newInterpreter,
            primaryKeysFrame: primaryKeysFrame,
            inputFrame: inputFrame,
            isRetry: true,
          );
        } catch (e) {
          QuizzerLogger.logError('Failed to re-download and retry: $e');
          throw Exception('Shape mismatch and re-download failed: $e');
        }
      } else {
        // Already retried once, fail permanently
        throw Exception(
          'Shape mismatch persists after re-download: Model expects $expectedInputFeatures features but data has $numFeatures. '
          'The model in Supabase does not match the input_features in the database. '
          'Please retrain and re-upload both the model and feature map.'
        );
      }
    }
    
    // QuizzerLogger.logSuccess('✓ Shape validation passed');
  } catch (e, stackTrace) {
    if (e.toString().contains('Shape mismatch')) {
      rethrow;
    }
    QuizzerLogger.logError('Failed to validate interpreter state: $e');
    QuizzerLogger.logError('Stack trace: $stackTrace');
    rethrow;
  }
  
  final List<List<dynamic>> updatedPrimaryKeyRows = [];
  final inputRows = inputFrame.rows.toList();
  
  // QuizzerLogger.logMessage('Starting inference loop for $numRows samples...');
  
  for (int i = 0; i < numRows; i++) {
    // QuizzerLogger.logMessage('--- Processing sample ${i + 1}/$numRows ---');
    
    final inputRow = inputRows[i].toList();
    final input = List<double>.filled(numFeatures, 0.0);

    for (int j = 0; j < numFeatures; j++) {
      final value = inputRow[j];
      if (value == null) {
        input[j] = 0.0;
      } else if (value is num) {
        input[j] = value.toDouble();
      } else {
        input[j] = 0.0;
      }
    }
    
    final inputTensor = [input];
    final outputTensor = [List<double>.filled(1, 0.0)];
    
    try {
      interpreter.run(inputTensor, outputTensor);
      // QuizzerLogger.logSuccess('  ✓ Inference completed successfully');
    } catch (e, stackTrace) {
      QuizzerLogger.logError('  ✗ Inference FAILED on sample ${i + 1}: $e');
      QuizzerLogger.logError('  Stack trace: $stackTrace');
      rethrow;
    }
    
    final probability = outputTensor[0][0];
    QuizzerLogger.logMessage('  Predicted probability: $probability');
    
    if (probability < 0.0 || probability > 1.0) {
      QuizzerLogger.logWarning('  WARNING: Probability out of range [0,1]: $probability');
    }
    
    final pkRow = primaryKeysFrame.rows.toList()[i].toList();
    updatedPrimaryKeyRows.add([...pkRow.sublist(0, 2), probability, timeStamp]);
  }
  
  QuizzerLogger.logSuccess('✓ All $numRows samples processed successfully');
  
  final headers = ['user_uuid', 'question_id', 'prob_result', 'last_prob_calc'];
  final allData = [headers, ...updatedPrimaryKeyRows];
  
  final resultFrame = DataFrame(allData);
  // QuizzerLogger.logMessage('=== runBatchInference completed ===');
  
  return resultFrame;
}

Future<void> forceDownloadLatestModel() async {
  QuizzerLogger.logMessage('=== Force downloading latest accuracy_net model from Supabase ===');
  
  final supabase = getSessionManager().supabase;
  final mediaPath = await getQuizzerMediaPath();
  
  // Download model file
  QuizzerLogger.logMessage('Downloading accuracy_net.tflite...');
  try {
    final modelBytes = await supabase.storage
        .from('ml_models')
        .download('accuracy_net.tflite');
    
    final modelPath = path.join(mediaPath, 'accuracy_net.tflite');
    final modelFile = File(modelPath);
    await modelFile.create(recursive: true);
    await modelFile.writeAsBytes(modelBytes);
    
    final fileSize = await modelFile.length();
    QuizzerLogger.logSuccess('✓ Model downloaded: $fileSize bytes');
    QuizzerLogger.logMessage('  Saved to: $modelPath');
  } catch (e) {
    QuizzerLogger.logError('Failed to download model file: $e');
    throw Exception('Failed to download accuracy_net.tflite: $e');
  }
  
  // Validate the downloaded model
  QuizzerLogger.logMessage('Validating downloaded model...');
  try {
    final modelPath = path.join(mediaPath, 'accuracy_net.tflite');
    final interpreter = Interpreter.fromFile(File(modelPath));
    interpreter.allocateTensors();
    
    final inputTensor = interpreter.getInputTensor(0);
    final expectedFeatures = inputTensor.shape[1];
    
    QuizzerLogger.logSuccess('✓ Model loaded and validated');
    QuizzerLogger.logMessage('  Model expects $expectedFeatures input features');
    QuizzerLogger.logMessage('  Input shape: ${inputTensor.shape}');
    
    interpreter.close();
    
    // Verify feature count matches database
    final response = await supabase
        .from('ml_models')
        .select('input_features')
        .eq('model_name', 'accuracy_net')
        .single();
    
    Map<String, dynamic> featureMap;
    final inputFeaturesJson = response['input_features'];
    if (inputFeaturesJson is String) {
      featureMap = decodeValueFromDB(inputFeaturesJson) as Map<String, dynamic>;
    } else {
      featureMap = inputFeaturesJson as Map<String, dynamic>;
    }
    
    if (featureMap.length != expectedFeatures) {
      QuizzerLogger.logError('✗ MISMATCH: Model expects $expectedFeatures features but database has ${featureMap.length} features');
      throw Exception(
        'Feature count mismatch: Model expects $expectedFeatures features but '
        'input_features in database has ${featureMap.length} features. '
        'The model and feature map in the database are out of sync.'
      );
    }
    
    QuizzerLogger.logSuccess('✓ Feature count matches: $expectedFeatures features');
    
  } catch (e) {
    QuizzerLogger.logError('Model validation failed: $e');
    rethrow;
  }
  
  QuizzerLogger.logSuccess('=== Model download and validation complete ===');
}

