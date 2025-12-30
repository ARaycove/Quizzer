import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/ml_models_table.dart';
import 'package:supabase/supabase.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Manages ML model file synchronization, retrieval, and operations
class MlModelManager {
  // --- Singleton Setup ---
  static final MlModelManager _instance = MlModelManager._internal();
  factory MlModelManager() => _instance;
  MlModelManager._internal() {
    QuizzerLogger.logMessage('MlModelManager initialized.');
  }
  // --------------------

  // --- Model Registry ---
  static const List<String> availableModels = ['accuracy_net'];
  // --------------------

  // --- Internal State ---
  final Map<String, Interpreter> _interpreters = {};
  // --------------------

  // ================================================================================
  // ----- Public API -----
  // ================================================================================

  /// Updates all ML models by checking for newer versions and downloading if needed
  Future<void> updateMlModels() async {
    try {
      final models = await MlModelsTable().getRecord('SELECT * FROM ml_models');
      
      for (final model in models) {
        final modelName = model['model_name'] as String;
        final lastSynced = model['time_last_received_file'] as String?;
        final lastModified = model['last_modified_timestamp'] as String?;
        
        if (lastModified == null) continue;
        
        final lastModifiedDate = DateTime.parse(lastModified);
        final lastSyncedDate = lastSynced != null ? DateTime.parse(lastSynced) : null;
        
        if (lastSyncedDate != null && !lastModifiedDate.isAfter(lastSyncedDate)) continue;
        
        await _downloadAndUpdateModel(modelName);
      }
    } catch (e) {
      QuizzerLogger.logError('MlModelManager.updateMlModels: Error - $e');
      rethrow;
    }
  }

  /// Gets complete model information for the accuracy_net model including loaded TensorFlow Lite interpreter
  Future<Map<String, dynamic>> getAccuracyNetModel() async {
    return await _getModelInfo('accuracy_net');
  }

  // ================================================================================
  // ----- Private Implementation -----
  // ================================================================================

  Future<Map<String, dynamic>> _getModelInfo(String modelName) async {
    try {
      final results = await MlModelsTable().getRecord(
        'SELECT * FROM ml_models WHERE model_name = "$modelName"'
      );
      
      if (results.isEmpty) {
        throw Exception('Model $modelName not found in database');
      }
      
      final model = results.first;

      // Load TensorFlow model if not already loaded
      if (!_interpreters.containsKey(modelName)) {
        await _loadTensorFlowModel(modelName);
      }

      // Parse input features
      final features = model['input_features'];
      Map<String, dynamic> inputFeatures;
      
      if (features is Map<String, dynamic>) {
        inputFeatures = features;
      } else if (features is String) {
        inputFeatures = Map<String, dynamic>.from(json.decode(features));
      } else {
        throw Exception('Input features for model $modelName are in an unexpected format');
      }

      return {
        'model_name': modelName,
        'local_path': await _getModelFilePath(modelName),
        'input_features': inputFeatures,
        'optimal_threshold': model['optimal_threshold'] as double,
        'last_modified': model['last_modified_timestamp'] as String?,
        'last_synced': model['time_last_received_file'] as String?,
        'interpreter': _interpreters[modelName]!,
      };
    } catch (e) {
      QuizzerLogger.logError('MlModelManager._getModelInfo: Error for $modelName - $e');
      rethrow;
    }
  }

  Future<void> _loadTensorFlowModel(String modelName) async {
    final localPath = await _getModelFilePath(modelName);
    final file = File(localPath);
    
    if (!file.existsSync()) {
      try {
        QuizzerLogger.logMessage('Model file not found locally, fetching from Supabase...');
        
        final Uint8List bytes = await SessionManager().supabase.storage
            .from('ml_models')
            .download('$modelName.tflite');
        
        await file.create(recursive: true);
        await file.writeAsBytes(bytes);
        
        QuizzerLogger.logSuccess('Model file downloaded and saved to $localPath');
      } catch (e) {
        QuizzerLogger.logError("Failed to download $modelName.tflite from Supabase: $e");
        rethrow;
      }
    }
    
    try {
      _interpreters[modelName] = Interpreter.fromFile(file);
      QuizzerLogger.logSuccess('MlModelManager: Loaded TensorFlow Lite model: $modelName');
    } catch (e) {
      QuizzerLogger.logError('MlModelManager: Failed to load TensorFlow Lite model $modelName: $e');
      rethrow;
    }
  }

  Future<String> _getModelFilePath(String modelName) async {
    final fileName = '$modelName.tflite';
    return path.join(await getQuizzerMediaPath(), fileName);
  }

  Future<void> _downloadAndUpdateModel(String modelName) async {
    final supabase = SessionManager().supabase;
    final fileName = '$modelName.tflite';
    
    final Uint8List modelFileData;      
    try {
      modelFileData = await supabase.storage.from('ml_models').download(fileName);
    } on StorageException catch (e) {
      QuizzerLogger.logWarning('MlModelManager: Storage error downloading model $modelName: ${e.message}');
      return;
    } on SocketException catch (e) {
      QuizzerLogger.logWarning('MlModelManager: Network error downloading model $modelName: $e');
      return;
    }
    
    // Save model file locally
    final localPath = await _getModelFilePath(modelName);
    await Directory(path.dirname(localPath)).create(recursive: true);
    await File(localPath).writeAsBytes(modelFileData);
    
    // Update sync timestamp in database
    await MlModelsTable().upsertRecord({
      'model_name': modelName,
      'time_last_received_file': DateTime.now().toUtc().toIso8601String(),
    });
    
    QuizzerLogger.logSuccess('MlModelManager: Updated ML model: $modelName');
    
    // Reload the TensorFlow model if it was already loaded
    if (_interpreters.containsKey(modelName)) {
      await _loadTensorFlowModel(modelName);
    }
  }
}