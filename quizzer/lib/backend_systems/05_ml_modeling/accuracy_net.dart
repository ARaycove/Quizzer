// import 'package:quizzer/backend_systems/00_database_manager/tables/ml_models_table.dart';
// import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';
import 'package:ml_dataframe/ml_dataframe.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
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
}) async {
  final timeStamp = DateTime.now().toUtc().toIso8601String();
  final numRows = inputFrame.rows.length;
  final numFeatures = inputFrame.header.length;
  
  final List<List<dynamic>> updatedPrimaryKeyRows = [];
  
  final inputRows = inputFrame.rows.toList();
  
  for (int i = 0; i < numRows; i++) {
    final inputRow = inputRows[i].toList();
    final input = List<double>.filled(numFeatures, 0.0);
    
    for (int j = 0; j < numFeatures; j++) {
      final value = inputRow[j];
      input[j] = value is num ? value.toDouble() : 0.0;
    }
    
    final inputTensor = [input];
    final outputTensor = [[0.0]];
    
    interpreter.run(inputTensor, outputTensor);
    
    final probability = (outputTensor[0] as List)[0] as double;
    
    final pkRow = primaryKeysFrame.rows.toList()[i].toList();
    updatedPrimaryKeyRows.add([...pkRow.sublist(0, 2), probability, timeStamp]);
  }
  
  final headers = ['user_uuid', 'question_id', 'prob_result', 'last_prob_calc'];
  final allData = [headers, ...updatedPrimaryKeyRows];
  
  return DataFrame(allData);
}
