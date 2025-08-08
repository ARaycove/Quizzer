import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'test_helpers.dart';
import 'dart:io';

void main() async {
  await QuizzerLogger.setupLogging();
  HttpOverrides.global = null;
  
  // Load test configuration
  final config = await getTestConfig();
  final testIteration = config['testIteration'] as int;
  final testPassword = config['testPassword'] as String;
  final testAccessPassword = config['testAccessPassword'] as String;
  
  // Set up test credentials
  final testEmail = 'test_user_$testIteration@example.com';
  
  final sessionManager = getSessionManager();
  await sessionManager.initializationComplete;
  
  // Perform login process for testing
  await performLoginProcess(
    email: testEmail, 
    password: testPassword, 
    supabase: sessionManager.supabase, 
    storage: sessionManager.getBox(testAccessPassword));
  
  QuizzerLogger.logMessage('Starting cleanup of test modules...');
  
  // Get all modules
  final allModules = await getAllModules();
  QuizzerLogger.logMessage('Found ${allModules.length} total modules');
  
  // Identify test modules to clean up
  final List<String> testModulesToClean = [];
  
  for (final module in allModules) {
    final moduleName = module['module_name'] as String;
    
    // Check if this is a test module
    if (moduleName.startsWith('test') || 
        moduleName.startsWith('Test') ||
        moduleName.contains('testmodule') ||
        moduleName.contains('testmodule') ||
        moduleName.contains('test module') ||
        moduleName.contains('bulktestmodule') ||
        moduleName.contains('merge test module') ||
        moduleName.contains('test rename module') ||
        moduleName.contains('renamed module')) {
      testModulesToClean.add(moduleName);
      QuizzerLogger.logMessage('Found test module: $moduleName');
    }
  }
  
  QuizzerLogger.logMessage('Found ${testModulesToClean.length} test modules to clean up');
  
  if (testModulesToClean.isNotEmpty) {
    // Clean up the test modules
    await cleanupTestModules(testModulesToClean);
    QuizzerLogger.logSuccess('Successfully cleaned up ${testModulesToClean.length} test modules');
  } else {
    QuizzerLogger.logMessage('No test modules found to clean up');
  }
  
  // Verify cleanup
  final remainingModules = await getAllModules();
  QuizzerLogger.logMessage('Remaining modules after cleanup: ${remainingModules.length}');
  
  for (final module in remainingModules) {
    final moduleName = module['module_name'] as String;
    QuizzerLogger.logMessage('Remaining module: $moduleName');
  }
  
  QuizzerLogger.logSuccess('Test module cleanup completed');
} 