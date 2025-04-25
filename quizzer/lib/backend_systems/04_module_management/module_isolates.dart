import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Map<String, dynamic>> handleLoadModules(Map<String, dynamic> data) async {
  final userId = data['userId'] as String;
  final monitor = getDatabaseMonitor();
  Database? db;
  Map<String, dynamic> result = {
    'modules': [],
    'activationStatus': {},
  };
  
  while (db == null) {
    db = await monitor.requestDatabaseAccess();
    if (db == null) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
  
  result['modules']           = await getAllModules(db);
  result['activationStatus']  = await getModuleActivationStatus(userId, db);
  
  monitor.releaseDatabaseAccess();
  return result;
}

Future<bool> handleModuleActivation(Map<String, dynamic> data) async {
  final userId = data['userId'] as String;
  final moduleName = data['moduleName'] as String;
  final isActive = data['isActive'] as bool;
  
  QuizzerLogger.logMessage('Starting module activation process for user $userId, module $moduleName, isActive: $isActive');
  
  final monitor = getDatabaseMonitor();
  Database? db;
  bool success = false;
  
  try {
    QuizzerLogger.logMessage('Requesting database access');
    while (db == null) {
      db = await monitor.requestDatabaseAccess();
      if (db == null) {
        QuizzerLogger.logMessage('Database access denied, waiting...');
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    QuizzerLogger.logMessage('Database access granted');
    
    QuizzerLogger.logMessage('Updating module activation status');
    success = await updateModuleActivationStatus(userId, moduleName, isActive, db);
    QuizzerLogger.logMessage('Module activation status update ${success ? 'succeeded' : 'failed'}');
    monitor.releaseDatabaseAccess();
    return success;
  } catch (e) {
    QuizzerLogger.logError('Error in module activation: $e');
    monitor.releaseDatabaseAccess();
    return false;
  } finally {
    monitor.releaseDatabaseAccess();
  }
}

Future<bool> handleUpdateModuleDescription(Map<String, dynamic> data) async {
  final moduleName = data['moduleName'] as String;
  final newDescription = data['description'] as String;
  
  QuizzerLogger.logMessage('Starting module description update for module: $moduleName');
  
  final monitor = getDatabaseMonitor();
  Database? db;
  bool success = false;
  
  try {
    QuizzerLogger.logMessage('Requesting database access');
    while (db == null) {
      db = await monitor.requestDatabaseAccess();
      if (db == null) {
        QuizzerLogger.logMessage('Database access denied, waiting...');
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    QuizzerLogger.logMessage('Database access granted');
    
    QuizzerLogger.logMessage('Updating module description in database');
    await updateModule(name: moduleName, description: newDescription, db: db);
    QuizzerLogger.logMessage('Module description update successful');
    success = true;
    monitor.releaseDatabaseAccess();
    return success;
  } catch (e) {
    QuizzerLogger.logError('Error updating module description: $e');
    monitor.releaseDatabaseAccess();
    return false;
  } finally {
    monitor.releaseDatabaseAccess();
  }
} 