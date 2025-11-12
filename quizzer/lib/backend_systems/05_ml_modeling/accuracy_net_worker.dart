import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/05_ml_modeling/attempt_pre_process.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:ml_dataframe/ml_dataframe.dart';
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';
import 'package:path/path.dart' as path;
import 'dart:typed_data';
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
  
  static const int batchSize = 5;
  static const int updateExclusionMinutes = 60;
  static const int loopIntervalSeconds = 1;
  
  bool get isRunning => _isRunning;
  Interpreter? get predictionModel => _interpreter;

  Future<void> start() async {
    QuizzerLogger.logMessage('Entering AccuracyNetWorker start()...');
    
    if (_isRunning) {
      QuizzerLogger.logWarning('AccuracyNetWorker is already running.');
      return;
    }
    await loadTensorFlowModel();
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

  /// Method to load or reload the prediction net model 
  /// (if new model is fetched during runtime, this can be called again to reload the model)
  Future<void> loadTensorFlowModel() async {
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
        QuizzerLogger.logError("Failed to download accuracy_net.tflite from Supabase: $e");
      }
    }
    
    _interpreter = Interpreter.fromFile(file);
  }


  Future<void> _runLoop() async {
    QuizzerLogger.logMessage('Entering AccuracyNetWorker _runLoop()...');
    
    _timer = Timer.periodic(const Duration(seconds: loopIntervalSeconds), (timer) async {
      if (_isRunning) {
        await _runCycle();
      }
    });
  }


  Future<void> _runCycle() async {
    if (!_isRunning) return;
    
    final userId = getSessionManager().userId;
    if (userId == null) return;
    final fetchResult = await fetchBatchInferenceSamples(
      nRecords: batchSize,
      kMinutes: updateExclusionMinutes,
    );
    
    final primaryKeysFrame = fetchResult['primary_keys']!;
    final rawSamplesFrame = fetchResult['raw_inference_data']!;
    if (rawSamplesFrame.rows.isEmpty) return;
    final decodedFrame = await decodeDataFrameJsonFields(rawSamplesFrame);
    // QuizzerLogger.logMessage('Decoded DataFrame: ${decodedFrame.rows.length} rows, ${decodedFrame.header.toList().length} cols');

    final unpackedFrame = await unpackDataFrameFeatures(decodedFrame);
    // QuizzerLogger.logMessage('Unpacked DataFrame: ${unpackedFrame.rows.length} rows, ${unpackedFrame.header.toList().length} cols');

    final encodedFrame = await oneHotEncodeDataFrame(unpackedFrame);
    // QuizzerLogger.logMessage('Encoded DataFrame: ${encodedFrame.rows.length} rows, ${encodedFrame.header.toList().length} cols');

    final inferenceInputFrame = await transformDataFrameToAccuracyNetInputShape(encodedFrame);
    // TODO, comment out debug print of value order, once resolve
    // await writeDataFrameFeatureMap(inferenceInputFrame, "inference_data.json");
    final resultsFrame = await _runBatchInference(
      primaryKeysFrame: primaryKeysFrame,
      inputFrame: inferenceInputFrame,
    );
    // QuizzerLogger.logValue('Inference Results:\n$resultsFrame');
    await _updateDatabaseWithPredictions(resultsFrame);
  }
  Future<void> _updateDatabaseWithPredictions(DataFrame resultsFrame) async {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    try {
      final headers = resultsFrame.header.toList();
      final userUuidIdx = headers.indexOf('user_uuid');
      final questionIdIdx = headers.indexOf('question_id');
      final probResultIdx = headers.indexOf('prob_result');
      final lastProbCalcIdx = headers.indexOf('last_prob_calc');
      int updateCount = 0;
      for (final row in resultsFrame.rows) {
        final rowList = row.toList();
        final userUuid = rowList[userUuidIdx];
        final questionId = rowList[questionIdIdx];
        final probResult = rowList[probResultIdx];
        final lastProbCalc = rowList[lastProbCalcIdx];
        final result = await db.update(
          'user_question_answer_pairs',
          {
            'accuracy_probability': probResult,
            'last_prob_calc': lastProbCalc,
          },
          where: 'user_uuid = ? AND question_id = ?',
          whereArgs: [userUuid, questionId],
        );
        if (result > 0) {
          updateCount++;
        }
      }
      QuizzerLogger.logSuccess('Updated $updateCount records in database');
    } finally {
      getDatabaseMonitor().releaseDatabaseAccess();
    }
  }

  Future<DataFrame> _runBatchInference({
    required DataFrame primaryKeysFrame,
    required DataFrame inputFrame,
  }) async {
    // QuizzerLogger.logMessage('=== Starting runBatchInference ===');
    final timeStamp = DateTime.now().toUtc().toIso8601String();
    final numRows = inputFrame.rows.length;
    final numFeatures = inputFrame.header.length;
    
    // QuizzerLogger.logMessage('Batch info: $numRows rows, $numFeatures features');
    
    // Validate interpreter state
    // QuizzerLogger.logMessage('Checking interpreter state...');
    final inputTensorDetails = AccuracyNetWorker().predictionModel!.getInputTensor(0);
    // QuizzerLogger.logMessage('Input tensor retrieved successfully');
    // QuizzerLogger.logMessage('  Expected shape: ${inputTensorDetails.shape}');
    
    final expectedInputFeatures = inputTensorDetails.shape[1];
    // QuizzerLogger.logMessage('Model expects $expectedInputFeatures features, got $numFeatures features');
    
    if (expectedInputFeatures != numFeatures) {
      // QuizzerLogger.logError('SHAPE MISMATCH: Model expects $expectedInputFeatures but data has $numFeatures');
      throw Exception(
        'Shape mismatch: Model expects $expectedInputFeatures features but data has $numFeatures. '
        'The model does not match the input_features in the database. '
        'Please ensure the model is downloaded during app initialization and matches the expected feature count.'
      );
    }
    
    // QuizzerLogger.logSuccess('✓ Shape validation passed');
    
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
      
      AccuracyNetWorker().predictionModel!.run(inputTensor, outputTensor);
      // QuizzerLogger.logSuccess('  ✓ Inference completed successfully');
      
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
}