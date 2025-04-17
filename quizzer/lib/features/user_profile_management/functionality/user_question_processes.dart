import 'package:quizzer/features/user_profile_management/database/user_question_answer_pairs_table.dart';
import 'package:quizzer/features/user_profile_management/database/user_profile_table.dart';
import 'package:quizzer/features/question_management/database/question_answer_pairs_table.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';
import 'package:quizzer/global/functionality/session_manager.dart';
import 'package:quizzer/features/modules/database/modules_table.dart';

/// Checks if a module is active for a specific user
/// Returns true if the module is active, false otherwise
Future<bool> isModuleActiveForUser(String userId, String moduleName) async {
  QuizzerLogger.logMessage('Checking if module $moduleName is active for user $userId');
  
  // Get the module activation status from the user profile
  final moduleActivationStatus = await getModuleActivationStatus(userId);
  
  // Check if the module exists in the activation status map
  final isActive = moduleActivationStatus[moduleName] ?? false;
  
  QuizzerLogger.logMessage('Module $moduleName is ${isActive ? 'active' : 'inactive'} for user $userId');
  return isActive;
}

/// Ensures all questions from a module are present in the user's question-answer pairs table
/// If the module is not active, this function will skip validation
Future<void> validateModuleQuestionsInUserProfile(String moduleName) async {
  QuizzerLogger.logMessage('Ensuring questions from module $moduleName are in user profile');
  
  // Get the current user's ID from the session manager
  final userId = SessionManager().userId;
  if (userId == null) {
    QuizzerLogger.logError('No user ID found in session');
    return;
  }
  
  // Check if the module is active for this user
  final isActive = await isModuleActiveForUser(userId, moduleName);
  if (!isActive) {
    QuizzerLogger.logMessage('Module $moduleName is not active, skipping question validation');
    return;
  }
  
  // Get the module data from the modules table
  final module = await getModule(moduleName);
  if (module == null) {
    QuizzerLogger.logError('Module $moduleName not found in modules table');
    return;
  }
  
  final questionIds = module['question_ids'] as List<String>;
  
  // Get all existing user question-answer pairs
  final existingPairs = await getUserQuestionAnswerPairsByUser(userId);
  final existingQuestionIds = existingPairs.map((pair) => pair['question_id'] as String).toSet();
  
  // Add any missing questions to the user's profile
  for (final questionId in questionIds) {
    if (!existingQuestionIds.contains(questionId)) {
      QuizzerLogger.logMessage('Adding question $questionId to user profile');
      
      // Get the question details from the question-answer pairs table
      final timeStamp = questionId.split('_')[0];
      final qstContrib = questionId.split('_')[1];
      final question = await getQuestionAnswerPairById(timeStamp, qstContrib);
      if (question == null) {
        QuizzerLogger.logError('Question $questionId not found in question-answer pairs table');
        continue;
      }
      
      // Add the question to the user's profile
      await addUserQuestionAnswerPair(
        userUuid: userId,
        questionAnswerReference: questionId,
        revisionStreak: 0,
        lastRevised: DateTime.now().toIso8601String(),
        predictedRevisionDueHistory: '[]',
        nextRevisionDue: DateTime.now().toIso8601String(),
        timeBetweenRevisions: 1.0,
        averageTimesShownPerDay: 0.0,
        isEligible: true,
        inCirculation: false,
      );
    }
  }
  
  QuizzerLogger.logSuccess('Successfully validated questions for module $moduleName');
}

/// Validates questions for all modules in the user profile
/// This function will check both active and inactive modules
Future<void> validateAllModuleQuestions() async {
  QuizzerLogger.logMessage('Starting validation of all module questions');
  
  // Get the current user's ID from the session manager
  final userId = SessionManager().userId;
  if (userId == null) {
    QuizzerLogger.logError('No user ID found in session');
    return;
  }
  
  // Get the module activation status map from the user's profile
  final moduleActivationStatus = await getModuleActivationStatus(userId);
  
  // Validate questions for each module in the user's profile
  for (final moduleName in moduleActivationStatus.keys) {
    await validateModuleQuestionsInUserProfile(moduleName);
  }
  
  QuizzerLogger.logSuccess('Completed validation of all module questions');
}
