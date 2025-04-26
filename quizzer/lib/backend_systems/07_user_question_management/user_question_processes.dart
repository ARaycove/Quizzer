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

// Future<bool> isUserQuestionEligible(String userId, String questionId) async {
//   // TODO: Refactor eligibility checking.
//   // replace with a multiplicative approach.
//   // Calculate component scores (time past due, subject interest, in circulation value, module active value) If anything hits 0 then the result will be 0, if the result is 0 then not eligible else above 0 will be eligible
//   // where a component is 0 if a condition isn't met. The final eligibility score
//   // would be the product of these components. A question is eligible if the product > 0.
//   // This might be computationally simpler than multiple conditional checks inside the function.
//   QuizzerLogger.logMessage(
//       'Checking eligibility for question $questionId for user $userId');

//   // Get Monitors
//   final queueMonitor    = getQuestionQueueMonitor();
//   final historyMonitor  = getAnsweredHistoryMonitor();

//   // --- Check if question is already in the QUEUE (using monitor's internal lock) ---
//   bool alreadyInQueue = await queueMonitor.containsQuestion(questionId);
//   if (alreadyInQueue) {
//     QuizzerLogger.logMessage('Question $questionId is currently in the queue (checked via monitor), marking as ineligible.');
//     return false; // Not eligible if already queued
//   }
//   // --------------------------------------------------------------------------------
//   // --- Check if question is in RECENTLY ANSWERED history (using monitor's internal lock) ---
//   bool inRecentHistory = await historyMonitor.isInRecentHistory(questionId);
//   if (inRecentHistory) {
//     QuizzerLogger.logMessage('Question $questionId is in recent answered history (last 5), marking as ineligible.');
//     return false; // Not eligible if recently answered
//   }
//   // ---------------------------------------------------------------------

//   // --- Proceed with Database checks only if not queued/recent ---
//   Database? db;
//   DatabaseMonitor monitor = getDatabaseMonitor();
//   while (db == null) {
//     db = await monitor.requestDatabaseAccess();
//     if (db == null) {
//       QuizzerLogger.logMessage('Database access denied, waiting...');
//       await Future.delayed(const Duration(milliseconds: 100));
//     }
//   }
//   // We need the userQuestionAnswerPairRecord
//   Map<String, dynamic>? userQuestionAnswerPair = await getUserQuestionAnswerPairById(userId, questionId, db);
//   // We need the modulename of that the user QuestionAnswerPairRecord, which we can get from the question_answer_pair_table
//   String moduleName = await getModuleNameForQuestionId(questionId, db);

//   // We need the module activation status of the given module
//   Map<String, dynamic> activationStatusField = await user_profile.getModuleActivationStatus(userId, db);

//   // Once we're done reading we can return
//   monitor.releaseDatabaseAccess();
//   late bool isEligible;

//   // Now that we have required data, we need to use it make our decision

//   // Is due date in the past?
//   // Parse the next revision due date from the user question record
//   final nextRevisionDueString = userQuestionAnswerPair['next_revision_due'] as String;
//   final nextRevisionDue = DateTime.parse(nextRevisionDueString);
  
//   // Compare with current time to see if it's due (in the past)
//   final now = DateTime.now();
//   final isDueForRevision = nextRevisionDue.isBefore(now);
  
//   QuizzerLogger.logMessage('Question $questionId next revision due: $nextRevisionDueString');
//   QuizzerLogger.logMessage('Question $questionId is ${isDueForRevision ? 'due' : 'not due'} for revision');
//   // Is the userQuestion in circulation?
//   // Check if the question is in circulation
//   final inCirculationValue = userQuestionAnswerPair['in_circulation'] as int;
//   final isInCirculation = inCirculationValue == 1;
  
//   QuizzerLogger.logMessage('Question $questionId is ${isInCirculation ? 'in' : 'not in'} circulation');
//   // is the userQuestion's module active?
//   // Check if the module is active in the user's activation status
//   final moduleActivationStatus = activationStatusField[moduleName];
//   final isModuleActive = moduleActivationStatus != null && moduleActivationStatus == true;
  
//   QuizzerLogger.logMessage('Module $moduleName is ${isModuleActive ? 'active' : 'inactive'} for user $userId');
  
//   // A question is eligible if:
//   // 1. It's due for revision
//   // 2. It's in circulation
//   // 3. Its module is active
//   isEligible = isDueForRevision && isInCirculation && isModuleActive;
  
//   QuizzerLogger.logMessage('Question $questionId eligibility result: $isEligible');

//   return isEligible;
// }

/// answerStatus should be ("correct", "incorrect")
/// timeToAnswer should be in seconds
Future<void> recordQuestionAttempt(String questionId, String userId, double timeToAnswer, String answerStatus) async{
  QuizzerLogger.logMessage('Recording attempt for Q: $questionId, User: $userId, Status: $answerStatus, Time: $timeToAnswer');
  
  // Get access to the DB
  Database? db;
  final dbMonitor = getDatabaseMonitor();
  while(db == null) {
      db = await dbMonitor.requestDatabaseAccess();
      if(db == null) {
          QuizzerLogger.logMessage('DB access denied for recording attempt, waiting...');
          await Future.delayed(const Duration(milliseconds: 100));
      }
  }
  QuizzerLogger.logMessage('DB access granted for recording attempt.');
  
  // --- Get Pre-Attempt State --- 
  // Fetch user-question pair to get current streak and last revised date
  final userQPair = await getUserQuestionAnswerPairById(userId, questionId, db);
  final int revisionStreak = userQPair['revision_streak'] as int? ?? 0; // Use new name
  final String? lastRevisedDate = userQPair['last_revised'] as String?; // Nullable

  // Fetch previous attempts count for this user/question
  final List<Map<String, dynamic>> previousAttempts = await getAttemptsByQuestionAndUser(questionId, userId, db);
  final int totalAttempts = previousAttempts.length; // Use new name (represents count *before* this one)
  
  // Calculate days since last revision
  double? daysSinceLastRevision; // Nullable double
  if (lastRevisedDate != null && lastRevisedDate != '') {
      QuizzerLogger.logValue(lastRevisedDate);
      final lastRevisedDateTime = DateTime.parse(lastRevisedDate);
      final now = DateTime.now();
      daysSinceLastRevision = now.difference(lastRevisedDateTime).inMicroseconds / (1000000.0 * 60 * 60 * 24);
  } else {
      QuizzerLogger.logMessage("No lastRevisedDate found for $questionId, setting daysSinceLastRevision to null.");
  }

  QuizzerLogger.logMessage('Pre-attempt state: Streak=$revisionStreak, LastRevised=$lastRevisedDate, TotalAttempts=$totalAttempts, DaysSinceRevision=$daysSinceLastRevision');
  // -----------------------------

  // --- Construct and Add Question Attempt Record --- 
  // Fetch the original question to get context (subjects/concepts)
  final questionRecord = await getQuestionAnswerPairById(questionId, db); 
  final String subjects = questionRecord['subjects'] as String? ?? '';
  final String concepts = questionRecord['concepts'] as String? ?? '';
  // Combine subjects and concepts into the context string (handle empty cases)
  final String questionContextCsv = [subjects, concepts].where((s) => s.isNotEmpty).join(',');
  // Convert answerStatus string to integer (0 or 1)
  final int responseResult = (answerStatus.toLowerCase() == 'correct') ? 1 : 0;

  // Add the attempt record, including pre-attempt state
  await addQuestionAnswerAttempt(
    timeStamp: DateTime.now().toIso8601String(), 
    questionId: questionId,
    participantId: userId,
    responseTime: timeToAnswer,
    responseResult: responseResult,
    questionContextCsv: questionContextCsv,
    totalAttempts: totalAttempts, 
    revisionStreak: revisionStreak,
    lastRevisedDate: lastRevisedDate,
    daysSinceLastRevision: daysSinceLastRevision, 
    // knowledgeBase is calculated later or elsewhere
    db: db,
  );
  QuizzerLogger.logSuccess('Successfully added attempt record to DB.');
  // --------------------------------------------------

  // --- Update User Question Pair Record --- 
  // Fetch necessary current values from userQPair
  double currentTimeBetweenRevisions = userQPair['time_between_revisions'] as double? ?? 0.37; // Default if null
  int currentRevisionStreak = userQPair['revision_streak'] as int? ?? 0;
  final String currentDueDateStr = userQPair['next_revision_due'] as String;
  final DateTime currentDueDate = DateTime.parse(currentDueDateStr);
  final DateTime now = DateTime.now(); // Use consistent time for calculations

  // Initialize updated values
  int updatedRevisionStreak = currentRevisionStreak;
  double updatedTimeBetweenRevisions = currentTimeBetweenRevisions;

  // 1. Increment total_attempts field in user_question_answer_pairs
  await incrementTotalAttempts(userId, questionId, db);
  QuizzerLogger.logMessage('Incremented total_attempts in user_question_answer_pairs.');

  // 2. & 3. Adjust streak and timeBetweenRevisions based on answer status
  final Duration difference = now.difference(currentDueDate);
  if (answerStatus.toLowerCase() == 'correct') {
    // Correct answer logic
    if (difference.inHours > 24) { // Way past due
      updatedTimeBetweenRevisions += 0.005;
      QuizzerLogger.logMessage('Correct & way past due: Incremented timeBetweenRevisions to $updatedTimeBetweenRevisions');
    }
    updatedRevisionStreak += 1;
     QuizzerLogger.logMessage('Correct: Incremented revisionStreak to $updatedRevisionStreak');
  } else {
    // Incorrect answer logic
    if (difference.inHours <= 24 && currentRevisionStreak < 3) { // Not way past due and low streak
        updatedTimeBetweenRevisions -= 0.015;
        QuizzerLogger.logMessage('Incorrect, not way past due, low streak: Decremented timeBetweenRevisions to $updatedTimeBetweenRevisions');
    }
    updatedRevisionStreak -= 1;
    if (updatedRevisionStreak < 0) updatedRevisionStreak = 0; // Ensure streak doesn't go negative
    QuizzerLogger.logMessage('Incorrect: Decremented revisionStreak to $updatedRevisionStreak');
  }

  // 4. increment total_question_attempts in user_profile
  await user_profile.incrementTotalQuestionsAnswered(userId, db);
  QuizzerLogger.logMessage('Incremented total_questions_answered in user_profile.');

  // 5. calculate next revision due date using formula
  final Map<String, dynamic> memoryAlgoResults = calculateNextRevisionDate(
    answerStatus, // Pass the original status
    updatedRevisionStreak,
    updatedTimeBetweenRevisions,
  );
  final String newDueDateString = memoryAlgoResults['next_revision_due'] as String;
  final double newAvgShown = memoryAlgoResults['average_times_shown_per_day'] as double;
  QuizzerLogger.logMessage('Calculated new due date: $newDueDateString, new avg shown: $newAvgShown');

  // 6. Update the user_question_answer_pairs record with all new values
  await editUserQuestionAnswerPair(
      userUuid: userId,
      questionId: questionId,
      db: db,
      revisionStreak: updatedRevisionStreak,
      lastRevised: now.toIso8601String(), // Set last_revised to now
      nextRevisionDue: newDueDateString,
      timeBetweenRevisions: updatedTimeBetweenRevisions,
      averageTimesShownPerDay: newAvgShown,
      lastUpdated: now.toIso8601String(), // Update last_updated timestamp
      // predictedRevisionDueHistory could be updated here if needed
  );
   QuizzerLogger.logSuccess('Successfully updated user_question_answer_pairs record.');

  /* --- Original TODO kept for reference --- 
  // 1. Increment total_attempts field
  // 2. If correct 
  // - if due date not within 24 hours (way past due) -> increment time_between_revisions by 0.005
  // - increment revision streak by 1
  // 3. If not correct
  // - if due date within 24 hours (not way past due) && revision streak is less than 3 -> decrease time_between_revisions by 0.015 
  // - decrease revsion streak by 1
  // 4. increment total_question_attempts in user_profile (use function in table file)
  // 5. calculate next revision due date using formula (use memory_retention_algorithm)
  // 6. set average_shown_per_day stat in record (using result from memory_retention_algorithm)
  */
  // ---------------------------------------------
  dbMonitor.releaseDatabaseAccess();
}