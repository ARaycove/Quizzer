import 'package:quizzer/global/database/tables/user_profile_table.dart';
import 'package:quizzer/global/database/tables/modules_table.dart';
import 'package:quizzer/global/database/database_monitor.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:isolate';

void handleLoadModules(Map<String, dynamic> data) async {
  final sendPort = data['sendPort'] as SendPort;
  final userId = data['userId'] as String;
  
  Database? db;
  Map<String, dynamic> result = {
    'modules': [],
    'activationStatus': {},
  };
  
  try {
    while (db == null) {
      db = await DatabaseMonitor().requestDatabaseAccess();
      if (db == null) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    result['modules'] = await getAllModules(db);
    result['activationStatus'] = await getModuleActivationStatus(userId, db);
  } catch (e) {
    QuizzerLogger.logError('Error in load modules isolate: $e');
  } finally {
    DatabaseMonitor().releaseDatabaseAccess();
    sendPort.send(result);
    Isolate.exit();
  }
}

void handleModuleActivation(Map<String, dynamic> data) async {
  final sendPort = data['sendPort'] as SendPort;
  final userId = data['userId'] as String;
  final moduleName = data['moduleName'] as String;
  final isActive = data['isActive'] as bool;
  
  QuizzerLogger.logMessage('Starting module activation process for user $userId, module $moduleName, isActive: $isActive');
  
  Database? db;
  bool success = false;
  
  try {
    QuizzerLogger.logMessage('Requesting database access');
    while (db == null) {
      db = await DatabaseMonitor().requestDatabaseAccess();
      if (db == null) {
        QuizzerLogger.logMessage('Database access denied, waiting...');
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    QuizzerLogger.logMessage('Database access granted');
    
    QuizzerLogger.logMessage('Updating module activation status');
    success = await updateModuleActivationStatus(userId, moduleName, isActive, db);
    QuizzerLogger.logMessage('Module activation status update ${success ? 'succeeded' : 'failed'}');
  } catch (e) {
    QuizzerLogger.logError('Error in module activation isolate: $e');
  } finally {
    QuizzerLogger.logMessage('Sending result and terminating isolate');
    sendPort.send(success);
    Isolate.exit();
  }
} 