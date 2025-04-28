import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_attempts_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile_table.dart' as user_profile;
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/08_memory_retention_algo/memory_retention_algorithm.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/09_data_caches/unprocessed_cache.dart';

/// Checks if a module is active for a specific user
/// Returns true if the module is active, false otherwise
Future<bool> isModuleActiveForUser(String userId, String moduleName, Database db) async {
  QuizzerLogger.logMessage('Checking if module $moduleName is active for user $userId');
  
  // Get the module activation status from the user profile
  final moduleActivationStatus = await user_profile.getModuleActivationStatus(userId, db);
  
  // Check if the module exists in the activation status map
  final isActive = moduleActivationStatus[moduleName] ?? false;
  
  QuizzerLogger.logMessage('Module $moduleName is ${isActive ? 'active' : 'inactive'} for user $userId');
  return isActive;
}

/// Ensures all questions from a module are present in the user's question-answer pairs table
/// If the module is not active, this function will skip validation
Future<void> validateModuleQuestionsInUserProfile(String moduleName, Database db, String userId) async {
  QuizzerLogger.logMessage('Ensuring questions from module $moduleName are in user profile');
  
  // Check if the module is active for this user
  final isActive = await isModuleActiveForUser(userId, moduleName, db);
  if (!isActive) {
    QuizzerLogger.logMessage('Module $moduleName is not active, skipping question validation');
    return;
  }
  
  // Get the module data from the modules table
  final module = await getModule(moduleName, db);
  if (module == null) {
    QuizzerLogger.logError('Module $moduleName not found in modules table');
    return;
  }
  
  final questionIds = module['question_ids'] as List<String>;
  
  // Get all existing user question-answer pairs
  final existingPairs = await getUserQuestionAnswerPairsByUser(userId, db);
  final existingQuestionIds = existingPairs.map((pair) => pair['question_id'] as String).toSet();
  
  // Add any missing questions to the user's profile
  for (final questionId in questionIds) {
    if (!existingQuestionIds.contains(questionId)) {
      QuizzerLogger.logMessage('Adding question $questionId to user profile');
      
      // Add the question to the user's profile
      await addUserQuestionAnswerPair(
        userUuid: userId,
        questionAnswerReference: questionId,
        revisionStreak: 0,
        lastRevised: null,
        predictedRevisionDueHistory: '[]',
        nextRevisionDue: DateTime.now().toIso8601String(),
        timeBetweenRevisions: 0.37,
        averageTimesShownPerDay: 0.0,
        inCirculation: false,
        db: db
      );
      
      // Fetch the newly added record from the DB
      final newUserRecord = await getUserQuestionAnswerPairById(userId, questionId, db);
      
      // Add the new record to the UnprocessedCache
      final unprocessedCache = UnprocessedCache(); 
      await unprocessedCache.addRecord(newUserRecord);
    }
  }
  
  QuizzerLogger.logSuccess('Successfully validated questions for module $moduleName');
}

/// Validates questions for all modules in the user profile
/// This function will check both active and inactive modules
Future<void> validateAllModuleQuestions(Database db, String userId) async {
  QuizzerLogger.logMessage('Starting validation of all module questions');
  
  // Get the module activation status map from the user's profile
  final moduleActivationStatus = await user_profile.getModuleActivationStatus(userId, db);
  
  // Validate questions for each module in the user's profile
  for (final moduleName in moduleActivationStatus.keys) {
    await validateModuleQuestionsInUserProfile(moduleName, db, userId);
  }
  
  QuizzerLogger.logSuccess('Completed validation of all module questions');
}