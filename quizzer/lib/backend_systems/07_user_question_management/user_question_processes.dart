import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart' as user_profile;
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

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
    
    // 1. Get all existing user question-answer pairs
    final existingPairs = await getUserQuestionAnswerPairsByUser(userId);
    final existingQuestionIds = existingPairs.map((pair) => pair['question_id'] as String).toSet();
    QuizzerLogger.logMessage('Found ${existingQuestionIds.length} existing questions for user');
    
    // 2. Get all question IDs that belong to the module we are validating
    final List<String> moduleQuestionIds = await getQuestionIdsForModule(moduleName);
    QuizzerLogger.logMessage('Found ${moduleQuestionIds.length} questions for module $moduleName');
    
    // 3. Create an empty working list
    final List<String> questionsToAdd = [];
    
    // 4. Iterate over the question IDs that belong to the module, if that question ID is not in the existing list, add that ID to the working list
    for (final questionId in moduleQuestionIds) {
      if (!existingQuestionIds.contains(questionId)) {
        questionsToAdd.add(questionId);
        QuizzerLogger.logMessage('Question $questionId needs to be added to user profile');
      }
    }
    
    QuizzerLogger.logMessage('Found ${questionsToAdd.length} questions to add for module $moduleName');
    
    // 5. Iterate over the now constructed working list and run the addUserQuestionAnswerPair to add our non-existent questions
    for (final questionId in questionsToAdd) {
      QuizzerLogger.logMessage('Adding question $questionId to user profile');
      
      try {
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
      } catch (e) {
        // If this is a unique constraint violation, ignore it (question already exists)
        if (e.toString().contains('UNIQUE constraint failed') || e.toString().contains('1555')) {
          QuizzerLogger.logMessage('Question $questionId already exists, skipping insert');
        } else {
          // Re-throw any other errors
          rethrow;
        }
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