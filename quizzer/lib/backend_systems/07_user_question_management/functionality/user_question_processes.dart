import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Checks if a module is active for a specific user
/// Returns true if the module is active, false otherwise
Future<bool> isModuleActiveForUser(String userId, String moduleName, Database db) async {
  QuizzerLogger.logMessage('Checking if module $moduleName is active for user $userId');
  
  // Get the module activation status from the user profile
  final moduleActivationStatus = await getModuleActivationStatus(userId, db);
  
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
        lastRevised: DateTime.now().toIso8601String(),
        predictedRevisionDueHistory: '[]',
        nextRevisionDue: DateTime.now().toIso8601String(),
        timeBetweenRevisions: 1.0,
        averageTimesShownPerDay: 0.0,
        isEligible: true,
        inCirculation: false,
        db: db
      );
    }
  }
  
  QuizzerLogger.logSuccess('Successfully validated questions for module $moduleName');
}

/// Validates questions for all modules in the user profile
/// This function will check both active and inactive modules
Future<void> validateAllModuleQuestions(Database db, String userId) async {
  QuizzerLogger.logMessage('Starting validation of all module questions');
  
  // Get the module activation status map from the user's profile
  final moduleActivationStatus = await getModuleActivationStatus(userId, db);
  
  // Validate questions for each module in the user's profile
  for (final moduleName in moduleActivationStatus.keys) {
    await validateModuleQuestionsInUserProfile(moduleName, db, userId);
  }
  
  QuizzerLogger.logSuccess('Completed validation of all module questions');
}

Future<bool> isUserQuestionEligible(String userId, String questionId) async {
  // TODO: Refactor eligibility checking.
  // replace with a multiplicative approach.
  // Calculate component scores (time past due, subject interest, in circulation value, module active value) If anything hits 0 then the result will be 0, if the result is 0 then not eligible else above 0 will be eligible
  // where a component is 0 if a condition isn't met. The final eligibility score
  // would be the product of these components. A question is eligible if the product > 0.
  // This might be computationally simpler than multiple conditional checks inside the function.
  QuizzerLogger.logMessage(
      'Checking eligibility for question $questionId for user $userId');
  // First we need to read the required data
  Database? db;
  DatabaseMonitor monitor = getDatabaseMonitor();
  while (db == null) {
    db = await monitor.requestDatabaseAccess();
    if (db == null) {
      QuizzerLogger.logMessage('Database access denied, waiting...');
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
  // We need the userQuestionAnswerPairRecord
  Map<String, dynamic>? userQuestionAnswerPair = await getUserQuestionAnswerPairById(userId, questionId, db);
  // We need the modulename of that the user QuestionAnswerPairRecord, which we can get from the question_answer_pair_table
  String moduleName = await getModuleNameForQuestionId(questionId, db);

  // We need the module activation status of the given module
  Map<String, dynamic> activationStatusField = await getModuleActivationStatus(userId, db);

  // Once we're done reading we can return
  monitor.releaseDatabaseAccess();
  late bool isEligible;

  // Now that we have required data, we need to use it make our decision

  // Is due date in the past?
  // Parse the next revision due date from the user question record
  final nextRevisionDueString = userQuestionAnswerPair['next_revision_due'] as String;
  final nextRevisionDue = DateTime.parse(nextRevisionDueString);
  
  // Compare with current time to see if it's due (in the past)
  final now = DateTime.now();
  final isDueForRevision = nextRevisionDue.isBefore(now);
  
  QuizzerLogger.logMessage('Question $questionId next revision due: $nextRevisionDueString');
  QuizzerLogger.logMessage('Question $questionId is ${isDueForRevision ? 'due' : 'not due'} for revision');
  // Is the userQuestion in circulation?
  // Check if the question is in circulation
  final inCirculationValue = userQuestionAnswerPair['in_circulation'] as int;
  final isInCirculation = inCirculationValue == 1;
  
  QuizzerLogger.logMessage('Question $questionId is ${isInCirculation ? 'in' : 'not in'} circulation');
  // is the userQuestion's module active?
  // Check if the module is active in the user's activation status
  final moduleActivationStatus = activationStatusField[moduleName];
  final isModuleActive = moduleActivationStatus != null && moduleActivationStatus == true;
  
  QuizzerLogger.logMessage('Module $moduleName is ${isModuleActive ? 'active' : 'inactive'} for user $userId');
  
  // A question is eligible if:
  // 1. It's due for revision
  // 2. It's in circulation
  // 3. Its module is active
  isEligible = isDueForRevision && isInCirculation && isModuleActive;
  
  QuizzerLogger.logMessage('Question $questionId eligibility result: $isEligible');

  return isEligible;
}