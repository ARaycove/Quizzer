// Dump location for test calls I'm not using right now
import 'package:flutter_test/flutter_test.dart';
import 'dart:math'; // Import for max function
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/09_data_caches/unprocessed_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/non_circulating_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/module_inactive_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/circulating_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/due_date_beyond_24hrs_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/due_date_within_24hrs_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/eligible_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/question_queue_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/answer_history_cache.dart';
import 'package:logging/logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart' as user_profile_table;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers.dart';
void main() {
// Ensure logger is initialized first, setting level to FINE to see logValue messages
QuizzerLogger.setupLogging(level: Level.FINE);
// New test block to monitor caches
test('monitor caches after activation', () async {
  // Call the extracted monitoring function
  await monitorCaches();
}, timeout: Timeout(const Duration(seconds: 15))); // Timeout just > monitor duration

// --- Test Block: Deactivate Modules via SessionManager ---
test('deactivate all modules via SessionManager', () async {
  final sessionManager = getSessionManager();
  assert(sessionManager.userLoggedIn, "User must be logged in for this test");

  QuizzerLogger.printHeader("Deactivating All Modules via SessionManager");

  // 1. Load current module state via SessionManager to know which modules exist
  final initialModuleData = await sessionManager.loadModules();
  final List<Map<String, dynamic>> modules = initialModuleData['modules'] as List<Map<String, dynamic>>? ?? [];
  final Map<String, bool> initialActivationStatus = initialModuleData['activationStatus'] as Map<String, bool>? ?? {};
  QuizzerLogger.logValue('Initial Module Activation Status (via SM): $initialActivationStatus');

  expect(modules, isNotEmpty, reason: "No modules found via SessionManager to test deactivation.");

  // 2. Deactivate each module currently active using SessionManager
  QuizzerLogger.logMessage('Sending deactivation requests via SessionManager for active modules...');
  int deactivatedCount = 0;
  for (final module in modules) {
    final moduleName = module['module_name'] as String?;
    // Only toggle if the module exists and is currently active
    if (moduleName != null && (initialActivationStatus[moduleName] ?? false)) {
        QuizzerLogger.logMessage('Deactivating module: $moduleName via SM');
        sessionManager.toggleModuleActivation(moduleName, false);
        deactivatedCount++;
    }
  }
  
  if (deactivatedCount > 0) {
      QuizzerLogger.logSuccess('Sent $deactivatedCount deactivation requests via SessionManager.');
  } else {
      QuizzerLogger.logWarning('No modules were active to deactivate.');
  }

  // 3. Removed verification step within this test.
  //    The effects will be observed in the subsequent cache monitoring test.

  QuizzerLogger.logSuccess("--- Test: Module Deactivation via SessionManager Triggered ---");
}, timeout: Timeout(const Duration(seconds: 20))); // Reduced timeout

// --- Test Block: Monitor Caches Again ---
test('monitor caches after deactivation', () async {
  // Call the extracted monitoring function again
  await monitorCaches();
}, timeout: Timeout(const Duration(seconds: 15))); // Timeout just > monitor duration


test('simulate activating all modules', () async {
  final sessionManager = getSessionManager();
  assert(sessionManager.userLoggedIn, "User must be logged in for this test");

  QuizzerLogger.printHeader('Loading module data...');
  final moduleData = await sessionManager.loadModules();
  final List<Map<String, dynamic>> modules = moduleData['modules'] as List<Map<String, dynamic>>? ?? [];
  final Map<String, bool> initialActivationStatus = moduleData['activationStatus'] as Map<String, bool>? ?? {};
  
  QuizzerLogger.logSuccess('Loaded ${modules.length} modules. Initial status: $initialActivationStatus');
  expect(modules, isNotEmpty, reason: "No modules found in the database to test activation.");

  // Activate each module
  QuizzerLogger.printHeader('Activating all modules...');
  for (final module in modules) {
    final moduleName = module['module_name'] as String;
    // Only activate if not already active (optional optimization)
    if (!(initialActivationStatus[moduleName] ?? false)) {
          QuizzerLogger.logMessage('Activating module: $moduleName');
          sessionManager.toggleModuleActivation(moduleName, true);
    } else {
          QuizzerLogger.logMessage('Module $moduleName already active, skipping.');
    }
  }
  QuizzerLogger.logSuccess('Finished activating all modules.');

  // Pause slightly after triggering activations before test block finishes
  await Future.delayed(const Duration(seconds: 2)); 

  // REMOVED Cache Monitoring Loop from here

}, timeout: Timeout(Duration(minutes: 1))); // Reduced timeout slightly

// New test block to monitor caches
test('monitor caches after activation', () async {
  // Call the extracted monitoring function
  await monitorCaches();
}, timeout: Timeout(const Duration(seconds: 15))); // Timeout just > monitor duration
// --- Test Block: Spam Module Activation Toggle ---


// multiple choice questions

// select all that apply

}


