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
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile_table.dart' as user_profile_table;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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

test('spam module activation toggle', () async {
  final sessionManager = getSessionManager();
  assert(sessionManager.userLoggedIn, "User must be logged in for this test");

  QuizzerLogger.printHeader('Starting Module Activation Spam Test (50 Cycles)...');

  // Load modules once
  final moduleData = await sessionManager.loadModules();
  final List<Map<String, dynamic>> modules = moduleData['modules'] as List<Map<String, dynamic>>? ?? [];
  expect(modules, isNotEmpty, reason: "No modules found to perform spam test.");
  QuizzerLogger.logMessage('Loaded ${modules.length} modules for spam test.');

  const int spamCycles = 50;
  final random = Random(); // Create Random instance once
  for (int i = 0; i < spamCycles; i++) {
    final bool activate = i % 2 == 0; // Activate on even, deactivate on odd
    // QuizzerLogger.logMessage('Spam Cycle ${i + 1}/$spamCycles: Setting all modules to active=$activate');
    for (final module in modules) {
      final moduleName = module['module_name'] as String?;
      if (moduleName != null) {
        // Fire and forget - DO NOT await
        sessionManager.toggleModuleActivation(moduleName, activate);
      }
    }
  }

  QuizzerLogger.logSuccess('Finished sending $spamCycles toggle cycles (with 67-100ms random delay) for ${modules.length} modules.');

  // Explicitly activate all modules after the spam loop
  QuizzerLogger.logMessage('Explicitly activating all modules after spam cycle...');
  for (final module in modules) {
      final moduleName = module['module_name'] as String?;
      if (moduleName != null) {
          // Fire and forget
          sessionManager.toggleModuleActivation(moduleName, true);
      }
  }
  QuizzerLogger.logSuccess('Finished final explicit activation call for all modules.');

}, timeout: Timeout(const Duration(minutes: 2))); // Allow slightly more time for the loop

// --- Test Block: Monitor Caches After Spam ---
test('monitor caches after spam toggle', () async {
    // Call the extracted monitoring function again to see the result of the spam
    // Monitor for 30 seconds this time
    await monitorCaches(monitoringSeconds: 30);
  }, timeout: Timeout(const Duration(seconds: 45))); // Timeout > monitor duration + buffer

test('Question loop test', () async {
    final sessionManager = getSessionManager();
    assert(sessionManager.userLoggedIn, "User must be logged in for this test");

    QuizzerLogger.printHeader('Starting requestNextQuestion loop test (3 iterations)...');

    for (int i = 1; i <= 3; i++) {
      QuizzerLogger.printDivider();
      QuizzerLogger.logMessage('--- Iteration $i ---');
      QuizzerLogger.logMessage('--- State BEFORE requestNextQuestion Call ---');
      // Call the new helper function
      await logCurrentQuestionDetails(sessionManager);
      await logCurrentUserQuestionRecordDetails(sessionManager);
      await logCurrentUserRecordFromDB(sessionManager);
      await waitTime(2000);



      QuizzerLogger.logMessage('Calling requestNextQuestion...');
      await sessionManager.requestNextQuestion();
      QuizzerLogger.logMessage('--- State AFTER requestNextQuestion Call ---');
      // Call the new helper function again
      await logCurrentQuestionDetails(sessionManager);
      await waitTime(2000);

      QuizzerLogger.logMessage('Submitting random answer');
      await sessionManager.submitAnswer(userAnswer: sessionManager.currentCorrectOptionIndex);
      await waitTime(250);
      await logCurrentUserQuestionRecordDetails(sessionManager);
      await logCurrentUserRecordFromDB(sessionManager);
      await waitTime(2000);

      // Monitor caches to observe changes
      await monitorCaches(monitoringSeconds: 3);
    }

    QuizzerLogger.printHeader('Finished requestNextQuestion loop test.');
  }, timeout: Timeout(Duration(minutes: 3))); // Allow more time for loops + monitoring

  test('Update Module Description Test', () async {
    final sessionManager = getSessionManager();
    assert(sessionManager.userLoggedIn, "User must be logged in for this test");

    QuizzerLogger.printHeader('Starting Update Module Description Test...');

    // 1. Load modules
    QuizzerLogger.logMessage('Loading modules to get current description...');
    Map<String, dynamic> moduleData = await sessionManager.loadModules();
    List<Map<String, dynamic>> modules = moduleData['modules'] as List<Map<String, dynamic>>? ?? [];
    assert(modules.isNotEmpty, "No modules found to test description update.");

    // Assuming there's at least one module, target the first one
    final targetModule = modules.first;
    final moduleName = targetModule['module_name'] as String;
    final originalDescription = targetModule['description'] as String? ?? ''; // Handle null case

    // 2. Log original description
    QuizzerLogger.logMessage('Module Name: $moduleName');
    QuizzerLogger.logValue('Original Description: $originalDescription');

    // 3. Update description
    final newDescription = 'This is the updated test description - ${DateTime.now()}.';
    QuizzerLogger.logMessage('Attempting to update description to: $newDescription');
    bool updateSuccess = await sessionManager.updateModuleDescription(moduleName, newDescription);
    expect(updateSuccess, isTrue, reason: "Failed to update module description.");
    QuizzerLogger.logSuccess('Description update call successful.');
    await waitTime(500); // Brief pause for potential async operations

    // 4. Load modules again and log the new description
    QuizzerLogger.logMessage('Re-loading modules to verify description update...');
    moduleData = await sessionManager.loadModules();
    modules = moduleData['modules'] as List<Map<String, dynamic>>? ?? [];
    final updatedModule = modules.firstWhere((m) => m['module_name'] == moduleName, orElse: () => {});
    assert(updatedModule.isNotEmpty, "Target module disappeared after update?");
    final currentDescriptionAfterUpdate = updatedModule['description'] as String? ?? '';
    QuizzerLogger.logValue('Description after update: $currentDescriptionAfterUpdate');
    expect(currentDescriptionAfterUpdate, equals(newDescription), reason: "Description did not update correctly.");

    // 5. Revert description
    QuizzerLogger.logMessage('Attempting to revert description to original: $originalDescription');
    updateSuccess = await sessionManager.updateModuleDescription(moduleName, originalDescription);
    expect(updateSuccess, isTrue, reason: "Failed to revert module description.");
    QuizzerLogger.logSuccess('Description revert call successful.');
    await waitTime(500);

    // 6. Load modules final time and log reverted description
    QuizzerLogger.logMessage('Re-loading modules to verify description revert...');
    moduleData = await sessionManager.loadModules();
    modules = moduleData['modules'] as List<Map<String, dynamic>>? ?? [];
    final revertedModule = modules.firstWhere((m) => m['module_name'] == moduleName, orElse: () => {});
    assert(revertedModule.isNotEmpty, "Target module disappeared after revert?");
    final currentDescriptionAfterRevert = revertedModule['description'] as String? ?? '';
    QuizzerLogger.logValue('Description after revert: $currentDescriptionAfterRevert');
    expect(currentDescriptionAfterRevert, equals(originalDescription), reason: "Description did not revert correctly.");

    QuizzerLogger.printHeader('Finished Update Module Description Test.');
  });
}


