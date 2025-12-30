import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/04_ml_modeling/attempt_pre_process.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/04_ml_modeling/ml_model_manager.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:ml_dataframe/ml_dataframe.dart';
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';
import 'package:path/path.dart' as path;

import 'dart:convert';
import 'dart:io';

Future<void> writeDataFrameFeatureMap(DataFrame df, String filename) async {
  final headers = df.header.toList();
  final firstRow = df.rows.isEmpty ? [] : df.rows.first.toList();
  
  final Map<String, Map<String, dynamic>> featureMap = {};
  
  for (int i = 0; i < headers.length; i++) {
    featureMap[headers[i]] = {
      'value': i < firstRow.length ? firstRow[i] : null,
      'pos': i,
    };
  }
  
  // QuizzerLogger.logMessage('DataFrame: ${df.rows.length} rows, ${headers.length} cols');
  final jsonString = const JsonEncoder.withIndent('  ').convert(featureMap);
  final logsPath = await getQuizzerLogsPath();
  final filepath = path.join(logsPath, filename);
  final file = File(filepath);
  await file.writeAsString(jsonString);
  
  QuizzerLogger.logSuccess('Feature map written to: ${file.absolute.path}');
}

class AccuracyNetWorker {
  static final AccuracyNetWorker _instance = AccuracyNetWorker._internal();
  factory AccuracyNetWorker() => _instance;
  AccuracyNetWorker._internal();
  bool _isRunning = false;
  Completer<void>? _stopCompleter;
  Interpreter? _interpreter;
  Timer? _timer;
  
  static const int batchSize = 25;
  static const int updateExclusionMinutes = 60;
  static const int loopIntervalSeconds = 1;
  bool _cycleIsRunning = false;
  bool _lastCycleHadData = false;
  
  bool get isRunning => _isRunning;
  Interpreter? get predictionModel => _interpreter;

  Future<void> start() async {
    QuizzerLogger.logMessage('Entering AccuracyNetWorker start()...');
    
    if (_isRunning) {
      QuizzerLogger.logWarning('AccuracyNetWorker is already running.');
      return;
    }
    _isRunning = true;
    _stopCompleter = Completer<void>();
    QuizzerLogger.logMessage('AccuracyNetWorker started.');
    _runLoop();
  }

  Future<void> stop() async {
    QuizzerLogger.logMessage('Entering AccuracyNetWorker stop()...');
    
    if (!_isRunning) {
      QuizzerLogger.logWarning('AccuracyNetWorker is not running.');
      return;
    }
    
    QuizzerLogger.logMessage('AccuracyNetWorker stopping...');
    _isRunning = false;
    
    _timer?.cancel();
    _timer = null;
    
    if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
      _stopCompleter!.complete();
    }
    
    if (_interpreter != null) {
      _interpreter!.close();
      _interpreter = null;
    }
    
    QuizzerLogger.logMessage('AccuracyNetWorker stopped.');
  }

  Future<void> _runLoop() async {
    QuizzerLogger.logMessage('Entering AccuracyNetWorker _runLoop()...');
    
    _timer = Timer.periodic(const Duration(seconds: loopIntervalSeconds), (timer) async {
      if (!_isRunning) {
        timer.cancel();
        return;
      } 
      // If last cycle had data and the cycle is not currently running, initiate a new cycle
      else if (_lastCycleHadData && !_cycleIsRunning) {
        await _runCycle();
      }
      // If no data was processed in the last cycle and no cycle is running, wait before checking again
      else if (!_lastCycleHadData && !_cycleIsRunning) {
        _cycleIsRunning = true; // prevent re-entrance
        await Future.delayed(const Duration(seconds: 60));
        _lastCycleHadData = true; // reset boolean
        _cycleIsRunning = false; // reset boolean
      }
    });
  }


  Future<void> _runCycle() async {
    if (!_isRunning) return;
    _cycleIsRunning = true;
    
    if (SessionManager().userId == null) return;
    
    try {
      final fetchResult = await fetchBatchInferenceSamples(
        nRecords: batchSize,
        kMinutes: updateExclusionMinutes,
      );
      QuizzerLogger.logMessage("Fetched ${fetchResult.length} samples for inference");
      
      final primaryKeysFrame = fetchResult['primary_keys']!;
      final rawSamplesFrame = fetchResult['raw_inference_data']!;
      
      if (rawSamplesFrame.rows.isEmpty) {
        QuizzerLogger.logMessage("No samples to process in this cycle.");
        _cycleIsRunning = false;
        _lastCycleHadData = false;
        // both are set to false so the runLoop knows to wait before next check
        return;
      } else { // there is data to process set the flag to true to indicate
        _lastCycleHadData = true;
      }

      // Get model info from MlModelManager (includes pre-loaded interpreter)
      final modelInfo = await MlModelManager().getAccuracyNetModel();
      final interpreter = modelInfo['interpreter'] as Interpreter;
      final optimalThreshold = modelInfo['optimal_threshold'] as double;
      
      // Process data through pipeline
      QuizzerLogger.logMessage("Processing ${rawSamplesFrame.rows.length} samples through preprocessing pipeline");
      final decodedFrame = await decodeDataFrameJsonFields(rawSamplesFrame);
      final unpackedFrame = await unpackDataFrameFeatures(decodedFrame);
      final encodedFrame = await oneHotEncodeDataFrame(unpackedFrame);
      final inferenceInputFrame = await reshapeDataFrameToAccuracyNetInputShape(encodedFrame);
      QuizzerLogger.logMessage("Preprocessing complete. Inference input frame has ${inferenceInputFrame.rows.length} rows and ${inferenceInputFrame.header.length} columns.");
      
      // Run inference using the interpreter from MlModelManager
      final resultsFrame = await _runBatchInference(
        primaryKeysFrame: primaryKeysFrame,
        inputFrame: inferenceInputFrame,
        interpreter: interpreter,
        optimalThreshold: optimalThreshold,
      );
      
      QuizzerLogger.logMessage("Inference complete. Updating database with predictions.");
      await _updateDatabaseWithPredictions(resultsFrame);
      _cycleIsRunning = false;
    } catch (e) {
      QuizzerLogger.logError('AccuracyNetWorker cycle error: $e');
      rethrow; // DO NOT FUCKING SWALLOW THE ERRORS
    }
  }

  Future<void> _updateDatabaseWithPredictions(DataFrame resultsFrame) async {
    try {
      final headers = resultsFrame.header.toList();
      final userUuidIdx = headers.indexOf('user_uuid');
      final questionIdIdx = headers.indexOf('question_id');
      final probResultIdx = headers.indexOf('prob_result');
      final lastProbCalcIdx = headers.indexOf('last_prob_calc');
      
      int updateCount = 0;
      
      for (final row in resultsFrame.rows) {
        final rowList = row.toList();
        final userUuid = rowList[userUuidIdx] as String;
        final questionId = rowList[questionIdIdx] as String;
        final probResult = rowList[probResultIdx] as double;
        final lastProbCalc = rowList[lastProbCalcIdx] as String;
        
        // Use UserQuestionAnswerPairsTable to update the record
        await UserQuestionAnswerPairsTable().upsertRecord({
          'user_uuid': userUuid,
          'question_id': questionId,
          'accuracy_probability': probResult,
          'last_prob_calc': lastProbCalc,
        });
        
        updateCount++;
      }
      
      if (updateCount > 0) {
        QuizzerLogger.logSuccess('Updated $updateCount records with new predictions using UserQuestionAnswerPairsTable');
      }
    } catch (e) {
      QuizzerLogger.logError('Error in _updateDatabaseWithPredictions: $e');
      rethrow;
    }
  }

  Future<DataFrame> _runBatchInference({
    required DataFrame primaryKeysFrame,
    required DataFrame inputFrame,
    required Interpreter interpreter,
    required double optimalThreshold,
  }) async {
    final timeStamp = DateTime.now().toUtc().toIso8601String();
    final numRows = inputFrame.rows.length;
    final numFeatures = inputFrame.header.length;
    
    // Validate input shape matches model expectations
    final inputTensorDetails = interpreter.getInputTensor(0);
    final expectedInputFeatures = inputTensorDetails.shape[1];
    
    if (expectedInputFeatures != numFeatures) {
      throw Exception(
        'Shape mismatch: Model expects $expectedInputFeatures features but data has $numFeatures. '
        'Please ensure the model matches the expected feature count.'
      );
    }
    
    final List<List<dynamic>> updatedPrimaryKeyRows = [];
    final inputRows = inputFrame.rows.toList();
    
    for (int i = 0; i < numRows; i++) {
      final inputRow = inputRows[i].toList();
      final input = List<double>.filled(numFeatures, 0.0);
      
      // Convert input to double array
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
      
      // Run inference
      final inputTensor = [input];
      final outputTensor = [List<double>.filled(1, 0.0)];
      interpreter.run(inputTensor, outputTensor);
      
      final probability = outputTensor[0][0];
      
      // Log if probability is near optimal threshold for monitoring
      if ((probability - optimalThreshold).abs() < 0.1) {
        QuizzerLogger.logMessage('Prediction near optimal threshold ($optimalThreshold): $probability');
      }
      
      final pkRow = primaryKeysFrame.rows.toList()[i].toList();
      updatedPrimaryKeyRows.add([...pkRow.sublist(0, 2), probability, timeStamp]);
    }
    
    QuizzerLogger.logSuccess('Processed $numRows inference samples');
    
    final headers = ['user_uuid', 'question_id', 'prob_result', 'last_prob_calc'];
    final allData = [headers, ...updatedPrimaryKeyRows];
    
    return DataFrame(allData);
  }
}