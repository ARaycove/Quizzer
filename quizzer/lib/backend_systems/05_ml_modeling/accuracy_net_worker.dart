import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/05_ml_modeling/attempt_pre_process.dart';
import 'package:quizzer/backend_systems/05_ml_modeling/accuracy_net.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
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
  
  final SwitchBoard _switchBoard = SwitchBoard();
  
  static const int batchSize = 10;
  static const int updateExclusionMinutes = 60;
  
  bool get isRunning => _isRunning;

  Future<void> start() async {
    QuizzerLogger.logMessage('Entering AccuracyNetWorker start()...');
    
    if (_isRunning) {
      QuizzerLogger.logWarning('AccuracyNetWorker is already running.');
      return;
    }

    _interpreter = await loadAccuracyNetModel();

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
    
    if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
      await _stopCompleter!.future;
    }
    
    if (_interpreter != null) {
      _interpreter!.close();
      _interpreter = null;
    }
    
    QuizzerLogger.logMessage('AccuracyNetWorker stopped.');
  }

  Future<void> _runLoop() async {
    QuizzerLogger.logMessage('Entering AccuracyNetWorker _runLoop()...');
    
    while (_isRunning) {
      await _runCycle();
      if (_isRunning) {
        await _switchBoard.onQuestionAnsweredCorrectly.first;
      }
    }
    
    if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
      _stopCompleter!.complete();
    }
    QuizzerLogger.logMessage('AccuracyNetWorker loop finished.');
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
    final unpackedFrame = await unpackDataFrameFeatures(decodedFrame);
    final encodedFrame = await oneHotEncodeDataFrame(unpackedFrame);
    final inferenceInputFrame = await transformDataFrameToAccuracyNetInputShape(encodedFrame);

    // TODO, comment out debug print of value order, once resolve
    await writeDataFrameFeatureMap(inferenceInputFrame, "inference_data.json");

    final resultsFrame = await runBatchInference(
      interpreter: _interpreter!,
      primaryKeysFrame: primaryKeysFrame,
      inputFrame: inferenceInputFrame,
    );

    QuizzerLogger.logValue('Inference Results:\n$resultsFrame');

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
}