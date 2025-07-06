import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart' as user_profile;
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/09_data_caches/unprocessed_cache.dart';

/// Checks if a module is active for a specific user
/// Returns true if the module is active, false otherwise
Future<bool> isModuleActiveForUser(String userId, String moduleName) async {
  try {
    QuizzerLogger.logMessage('Entering isModuleActiveForUser()...');
    QuizzerLogger.logMessage('Checking if module $moduleName is active for user $userId');
    
    // Table functions handle their own database access
    final moduleActivationStatus = await user_profile.getModuleActivationStatus(userId);
    
    // Check if the module exists in the activation status map
    final isActive = moduleActivationStatus[moduleName] ?? false;
    
    QuizzerLogger.logMessage('Module $moduleName is ${isActive ? 'active' : 'inactive'} for user $userId');
    return isActive;
  } catch (e) {
    QuizzerLogger.logError('Error in isModuleActiveForUser - $e');
    rethrow;
  }
}

/// Ensures all questions from a module are present in the user's question-answer pairs table
/// If the module is not active, this function will skip validation
Future<void> validateModuleQuestionsInUserProfile(String moduleName, String userId) async {
  try {
    QuizzerLogger.logMessage('Entering validateModuleQuestionsInUserProfile()...');
    QuizzerLogger.logMessage('Ensuring questions from module $moduleName are in user profile');
    
    // Check if the module is active for this user
    final isActive = await isModuleActiveForUser(userId, moduleName);
    if (!isActive) {
      QuizzerLogger.logMessage('Module $moduleName is not active, skipping question validation');
      return;
    }
    
    // Get the module data from the modules table - table function handles its own database access
    final module = await getModule(moduleName);
    if (module == null) {
      QuizzerLogger.logError('Module $moduleName not found in modules table');
      return;
    }
    
    // Verbose -> just here to log
    // QuizzerLogger.logMessage("Getting list of question ids from this ->\n $module");
    // Correctly handle List<dynamic> from decoded data
    final List<dynamic> dynamicQuestionIds = module['question_ids'] as List<dynamic>? ?? []; 
    final List<String> questionIds = List<String>.from(dynamicQuestionIds.map((id) => id.toString()));
    
    // Get all existing user question-answer pairs - table function handles its own database access
    final existingPairs = await getUserQuestionAnswerPairsByUser(userId);
    final existingQuestionIds = existingPairs.map((pair) => pair['question_id'] as String).toSet();
    
    // Add any missing questions to the user's profile
    for (final questionId in questionIds) {
      if (!existingQuestionIds.contains(questionId)) {
        QuizzerLogger.logMessage('Adding question $questionId to user profile');
        
        // Add the question to the user's profile - table function handles its own database access
        await addUserQuestionAnswerPair(
          userUuid: userId,
          questionAnswerReference: questionId,
          revisionStreak: 0,
          lastRevised: null,
          predictedRevisionDueHistory: '[]',
          nextRevisionDue: DateTime.now().toUtc().toIso8601String(),
          timeBetweenRevisions: 0.37,
          averageTimesShownPerDay: 0.0,
        );
        
        // Fetch the newly added record from the DB - table function handles its own database access
        final newUserRecord = await getUserQuestionAnswerPairById(userId, questionId);
        
        // Add the new record to the UnprocessedCache
        final unprocessedCache = UnprocessedCache(); 
        await unprocessedCache.addRecord(newUserRecord); // Also add to the unprocessed Cache
      }
    }
    
    QuizzerLogger.logSuccess('Successfully validated questions for module $moduleName');
  } catch (e) {
    QuizzerLogger.logError('Error in validateModuleQuestionsInUserProfile - $e');
    rethrow;
  }
}

/// Validates questions for all modules in the user profile
/// This function will check both active and inactive modules
Future<void> validateAllModuleQuestions(String userId) async {
  try {
    QuizzerLogger.logMessage('Entering validateAllModuleQuestions()...');
    QuizzerLogger.logMessage('Starting validation of all module questions');
    
    // Get the module activation status map from the user's profile - table function handles its own database access
    final moduleActivationStatus = await user_profile.getModuleActivationStatus(userId);
    
    // Validate questions for each module in the user's profile
    for (final moduleName in moduleActivationStatus.keys) {
      await validateModuleQuestionsInUserProfile(moduleName, userId);
    }
    
    QuizzerLogger.logSuccess('Completed validation of all module questions');
  } catch (e) {
    QuizzerLogger.logError('Error in validateAllModuleQuestions - $e');
    rethrow;
  }
}