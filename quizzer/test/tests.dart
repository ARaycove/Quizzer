// // Dump location for test calls I'm not using right now
// import 'package:flutter_test/flutter_test.dart';
// import 'dart:math'; // Import for max function
// import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
// import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
// import 'package:quizzer/backend_systems/09_data_caches/unprocessed_cache.dart';
// import 'package:quizzer/backend_systems/09_data_caches/non_circulating_questions_cache.dart';
// import 'package:quizzer/backend_systems/09_data_caches/module_inactive_cache.dart';
// import 'package:quizzer/backend_systems/09_data_caches/circulating_questions_cache.dart';
// import 'package:quizzer/backend_systems/09_data_caches/due_date_beyond_24hrs_cache.dart';
// import 'package:quizzer/backend_systems/09_data_caches/due_date_within_24hrs_cache.dart';
// import 'package:quizzer/backend_systems/09_data_caches/eligible_questions_cache.dart';
// import 'package:quizzer/backend_systems/09_data_caches/question_queue_cache.dart';
// import 'package:quizzer/backend_systems/09_data_caches/answer_history_cache.dart';
// import 'package:logging/logging.dart';
// import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
// import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile_table.dart' as user_profile_table;
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'test_helpers.dart';
// void main() {
// // Ensure logger is initialized first, setting level to FINE to see logValue messages
// QuizzerLogger.setupLogging(level: Level.FINE);
// // New test block to monitor caches
// test('monitor caches after activation', () async {
//   // Call the extracted monitoring function
//   await monitorCaches();
// }, timeout: Timeout(const Duration(seconds: 15))); // Timeout just > monitor duration

// // --- Test Block: Deactivate Modules via SessionManager ---
// test('deactivate all modules via SessionManager', () async {
//   final sessionManager = getSessionManager();
//   assert(sessionManager.userLoggedIn, "User must be logged in for this test");

//   QuizzerLogger.printHeader("Deactivating All Modules via SessionManager");

//   // 1. Load current module state via SessionManager to know which modules exist
//   final initialModuleData = await sessionManager.loadModules();
//   final List<Map<String, dynamic>> modules = initialModuleData['modules'] as List<Map<String, dynamic>>? ?? [];
//   final Map<String, bool> initialActivationStatus = initialModuleData['activationStatus'] as Map<String, bool>? ?? {};
//   QuizzerLogger.logValue('Initial Module Activation Status (via SM): $initialActivationStatus');

//   expect(modules, isNotEmpty, reason: "No modules found via SessionManager to test deactivation.");

//   // 2. Deactivate each module currently active using SessionManager
//   QuizzerLogger.logMessage('Sending deactivation requests via SessionManager for active modules...');
//   int deactivatedCount = 0;
//   for (final module in modules) {
//     final moduleName = module['module_name'] as String?;
//     // Only toggle if the module exists and is currently active
//     if (moduleName != null && (initialActivationStatus[moduleName] ?? false)) {
//         QuizzerLogger.logMessage('Deactivating module: $moduleName via SM');
//         sessionManager.toggleModuleActivation(moduleName, false);
//         deactivatedCount++;
//     }
//   }
  
//   if (deactivatedCount > 0) {
//       QuizzerLogger.logSuccess('Sent $deactivatedCount deactivation requests via SessionManager.');
//   } else {
//       QuizzerLogger.logWarning('No modules were active to deactivate.');
//   }

//   // 3. Removed verification step within this test.
//   //    The effects will be observed in the subsequent cache monitoring test.

//   QuizzerLogger.logSuccess("--- Test: Module Deactivation via SessionManager Triggered ---");
// }, timeout: Timeout(const Duration(seconds: 20))); // Reduced timeout

// // --- Test Block: Monitor Caches Again ---
// test('monitor caches after deactivation', () async {
//   // Call the extracted monitoring function again
//   await monitorCaches();
// }, timeout: Timeout(const Duration(seconds: 15))); // Timeout just > monitor duration


// test('simulate activating all modules', () async {
//   final sessionManager = getSessionManager();
//   assert(sessionManager.userLoggedIn, "User must be logged in for this test");

//   QuizzerLogger.printHeader('Loading module data...');
//   final moduleData = await sessionManager.loadModules();
//   final List<Map<String, dynamic>> modules = moduleData['modules'] as List<Map<String, dynamic>>? ?? [];
//   final Map<String, bool> initialActivationStatus = moduleData['activationStatus'] as Map<String, bool>? ?? {};
  
//   QuizzerLogger.logSuccess('Loaded ${modules.length} modules. Initial status: $initialActivationStatus');
//   expect(modules, isNotEmpty, reason: "No modules found in the database to test activation.");

//   // Activate each module
//   QuizzerLogger.printHeader('Activating all modules...');
//   for (final module in modules) {
//     final moduleName = module['module_name'] as String;
//     // Only activate if not already active (optional optimization)
//     if (!(initialActivationStatus[moduleName] ?? false)) {
//           QuizzerLogger.logMessage('Activating module: $moduleName');
//           sessionManager.toggleModuleActivation(moduleName, true);
//     } else {
//           QuizzerLogger.logMessage('Module $moduleName already active, skipping.');
//     }
//   }
//   QuizzerLogger.logSuccess('Finished activating all modules.');

//   // Pause slightly after triggering activations before test block finishes
//   await Future.delayed(const Duration(seconds: 2)); 

//   // REMOVED Cache Monitoring Loop from here

// }, timeout: Timeout(Duration(minutes: 1))); // Reduced timeout slightly

// // New test block to monitor caches
// test('monitor caches after activation', () async {
//   // Call the extracted monitoring function
//   await monitorCaches();
// }, timeout: Timeout(const Duration(seconds: 15))); // Timeout just > monitor duration
// // --- Test Block: Spam Module Activation Toggle ---


// // multiple choice questions
// test('Add Questions From JSON Test', () async {
//   final sessionManager = getSessionManager();
//   assert(sessionManager.userLoggedIn, "User must be logged in for this test");

//   QuizzerLogger.printHeader('Starting Add Questions From JSON Test...');

//   // 1. Load the JSON file
//   const String jsonPath = 'runtime_cache/elementary_addition_questions.json';
//   QuizzerLogger.logMessage('Loading questions from: $jsonPath');
//   final File jsonFile = File(jsonPath);
//   if (!await jsonFile.exists()) {
//     throw Exception('JSON test data file not found at $jsonPath. Run generate_math_questions.dart first.');
//   }
//   final String jsonString = await jsonFile.readAsString();
//   final List<dynamic> questionsData = jsonDecode(jsonString) as List<dynamic>;
//   QuizzerLogger.logSuccess('Loaded ${questionsData.length} questions from JSON.');

//   int successCount = 0;
//   int failureCount = 0;

//   // 2. Iterate and add questions
//   for (final questionDynamic in questionsData) {
//     final questionMap = questionDynamic as Map<String, dynamic>; // Cast

//     // 3. Use SessionManager to add the question
//     QuizzerLogger.logMessage('Adding question: ${questionMap['questionElements']?[0]?['content'] ?? 'N/A'}');

//     // Ensure data types match the API expectations
//     final List<Map<String, dynamic>> questionElements = 
//         List<Map<String, dynamic>>.from(questionMap['questionElements'] ?? []);
//     final List<Map<String, dynamic>> answerElements = 
//         List<Map<String, dynamic>>.from(questionMap['answerElements'] ?? []);
//     final List<Map<String, dynamic>>? options = 
//         (questionMap['options'] as List<dynamic>?)
//             ?.map((e) => Map<String, dynamic>.from(e as Map)).toList(); 
//     final int? correctOptionIndex = questionMap['correctOptionIndex'] as int?;

//     final response = await sessionManager.addNewQuestion(
//       questionType: questionMap['questionType'] as String,
//       questionElements: questionElements,
//       answerElements: answerElements,
//       moduleName: questionMap['moduleName'] as String,
//       options: options,
//       correctOptionIndex: correctOptionIndex,
//       // Pass other potential fields if they exist in JSON, otherwise they default
//       citation: questionMap['citation'] as String?,
//       concepts: questionMap['concepts'] as String?,
//       subjects: questionMap['subjects'] as String?,
//     );

//     // 4. Check API response (instead of direct DB check)
//     if (response['success'] == true) {
//       QuizzerLogger.logSuccess('Successfully added question via API.');
//       successCount++;
//     } else {
//       QuizzerLogger.logError('Failed to add question via API: ${response['message']}');
//       failureCount++;
//     }
//     // Asserting success for every question added
//     expect(response['success'], isTrue, reason: "Failed to add question: ${questionMap['questionElements']?[0]?['content'] ?? 'N/A'}. Error: ${response['message']}");

//     // 5. Wait
//     await waitTime(250);
//   }

//   QuizzerLogger.printDivider();
//   QuizzerLogger.logSuccess('Finished adding questions. Success: $successCount, Failed: $failureCount');
//   expect(failureCount, equals(0), reason: "Some questions failed to add.");
//   QuizzerLogger.printHeader('Finished Add Questions From JSON Test.');

// }, timeout: Timeout(Duration(minutes: 5))); // Increase timeout for file IO and looping
// // select all that apply
// test('add all Is Even or Odd questions', () async {
//     final sessionManager = getSessionManager();
//     assert(sessionManager.userLoggedIn, "User must be logged in for this test");

//     QuizzerLogger.printHeader('Starting Add All Number Properties Questions Test...');

//     // 1. Read the JSON file
//     final filePath = 'runtime_cache/number_properties_questions.json';
//     QuizzerLogger.logMessage('Reading questions from: $filePath');
//     final file = File(filePath);
//     assert(await file.exists(), "JSON file not found: $filePath. Run the generation script first.");
//     final jsonString = await file.readAsString();

//     // 2. Decode JSON (Removed try-catch for Fail Fast)
//     List<dynamic> questionsJson = jsonDecode(jsonString) as List<dynamic>;
//     QuizzerLogger.logSuccess('Successfully decoded ${questionsJson.length} questions from JSON.');

//     // 3. Loop and add each question
//     int addedCount = 0;
//     for (final questionData in questionsJson) {
//       // Cast to Map<String, dynamic> for easier access
//       final questionMap = questionData as Map<String, dynamic>; 

//       // Extract parameters (with type casting)
//       final String moduleName = questionMap['moduleName'] as String;
//       final String questionType = questionMap['questionType'] as String;
//       // Cast inner list elements too
//       final List<Map<String, dynamic>> questionElements = (questionMap['questionElements'] as List<dynamic>)
//           .map((e) => Map<String, dynamic>.from(e as Map)).toList();
//       final List<Map<String, dynamic>> answerElements = (questionMap['answerElements'] as List<dynamic>)
//           .map((e) => Map<String, dynamic>.from(e as Map)).toList();
//       final List<Map<String, dynamic>> options = (questionMap['options'] as List<dynamic>)
//           .map((e) => Map<String, dynamic>.from(e as Map)).toList();
//       // Specifically cast indexOptionsThatApply to List<int>
//       final List<int> indexOptionsThatApply = (questionMap['indexOptionsThatApply'] as List<dynamic>)
//           .map((e) => e as int).toList(); 

//       // Assert the type is correct before calling addNewQuestion
//       assert(questionType == 'select_all_that_apply', 
//              "Unexpected question type found in JSON: $questionType");

//       // Call addNewQuestion
//       final response = await sessionManager.addNewQuestion(
//         questionType: questionType,
//         moduleName: moduleName,
//         questionElements: questionElements,
//         answerElements: answerElements,
//         options: options,
//         indexOptionsThatApply: indexOptionsThatApply,
//         // Set other common fields to defaults or null as needed
//         citation: null,
//         concepts: null,
//         subjects: null,
//         // Correct option index is not used for this type
//         correctOptionIndex: null, 
//         correctOrderElements: null,
//       );

//       // Assert success
//       expect(response['success'], isTrue,
//              reason: 'Failed to add question ${questionMap['questionElements']}: ${response['message']}');
//       addedCount++;
      
//       // Log current state (Note: Won't show the *just added* question details)
//       await logCurrentQuestionDetails(sessionManager);
//       // Wait 250ms between adds
//       await waitTime(250); 
//     }

//     QuizzerLogger.logSuccess('Successfully attempted to add $addedCount questions.');
//     QuizzerLogger.printHeader('Finished Add All Number Properties Questions Test.');

//     // Monitor caches to see if questions were processed
//     await monitorCaches(monitoringSeconds: 60);
  
//   }, timeout: Timeout(Duration(minutes: 3))); // Increased timeout for monitoring


// }


