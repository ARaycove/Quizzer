import 'dart:math';
import 'package:quizzer/backend_systems/08_memory_retention_algo/memory_retention_algorithm.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_attempts_table.dart' as attempt_table;
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Logger needed for debugging
import 'package:supabase/supabase.dart'; // For supabase.Session type
import 'package:jwt_decode/jwt_decode.dart'; // For decoding JWT
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';

// ==========================================
// Helper Function for Recording Answer Attempt
// ==========================================
// This file contains helper functions for the session manager. 
// These functions help to reduce the lines of code in the SessionManager class itself. This should simplify the SessionManager class and make it easier to maintain.

Future<Map<String, dynamic>?> recordQuestionAnswerAttempt({
  required String userId,
  required String questionId,
  bool? isCorrect,
  bool forInference = false,
}) async {
  if (!forInference && isCorrect == null) {
    throw ArgumentError('isCorrect is required when forInference is false');
  }
  
  try {
    QuizzerLogger.logMessage('Entering recordQuestionAnswerAttempt()...');
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    
    final String timeStamp = DateTime.now().toUtc().toIso8601String();
    
    // ===================================
    // Query 1: Question Metadata
    // ===================================
    final Map<String, dynamic> questionMetadata = await attempt_table.fetchQuestionMetadata(
      db: db,
      questionId: questionId,
    );
    
    final String? questionVector = questionMetadata['question_vector'] as String?;
    final String moduleName = questionMetadata['module_name'] as String;
    final String questionType = questionMetadata['question_type'] as String;
    final int numMcqOptions = questionMetadata['num_mcq_options'] as int;
    final int numSoOptions = questionMetadata['num_so_options'] as int;
    final int numSataOptions = questionMetadata['num_sata_options'] as int;
    final int numBlanks = questionMetadata['num_blanks'] as int;
    final String? kNearestNeighbors = questionMetadata['k_nearest_neighbors'] as String?;
    
    // ===================================
    // Query 2: Individual Question Performance
    // ===================================
    final Map<String, dynamic> userQuestionPerformance = await attempt_table.fetchUserQuestionPerformance(
      db: db,
      userId: userId,
      questionId: questionId,
      timeStamp: timeStamp,
    );
    
    final double avgReactTime = userQuestionPerformance['avg_react_time'] as double;
    final bool wasFirstAttempt = userQuestionPerformance['was_first_attempt'] as bool;
    final int totalCorrectAttempts = userQuestionPerformance['total_correct_attempts'] as int;
    final int totalIncorrectAttempts = userQuestionPerformance['total_incorrect_attempts'] as int;
    final int totalAttempts = userQuestionPerformance['total_attempts'] as int;
    final double accuracyRate = userQuestionPerformance['accuracy_rate'] as double;
    final int revisionStreak = userQuestionPerformance['revision_streak'] as int;
    final String timeOfPresentation = userQuestionPerformance['time_of_presentation'] as String;
    final String? lastRevisedDate = userQuestionPerformance['last_revised_date'] as String?;
    final double daysSinceLastRevision = userQuestionPerformance['days_since_last_revision'] as double;
    final double daysSinceFirstIntroduced = userQuestionPerformance['days_since_first_introduced'] as double;
    final double attemptDayRatio = userQuestionPerformance['attempt_day_ratio'] as double;
    
    
    // ===================================
    // Query 3: User Stats Vector
    // ===================================
    final String? userStatsVector = await attempt_table.fetchUserStatsVector(
      db: db,
      userId: userId,
    );
    
    // ===================================
    // Query 4: Module Performance Vector
    // ===================================
    const String? modulePerformanceVector = null;
    // TODO - This can't be done until the topic model is tuned
    // final String? modulePerformanceVector = await attempt_table.fetchModulePerformanceVector(
    //   db: db,
    //   userId: userId,
    //   timeStamp: timeStamp,
    // );
    
    // ===================================
    // Query 5: User Profile Record
    // ===================================
    final String? userProfileRecord = await attempt_table.fetchUserProfileRecord(
      db: db,
      userId: userId,
    );

    // ===================================
    // Query 6: K Nearest Performance Vector
    // ===================================
    final String? kNearestPerformanceVector = await attempt_table.fetchKNearestPerformanceVector(
      db: db,
      userId: userId,
      kNearestNeighbors: kNearestNeighbors,
      timeStamp: timeStamp,
    );

    // ===================================
    // Prepare Data for Insert/Return
    // ===================================
    final Map<String, dynamic> sampleData = {
      'module_name': moduleName,
      'question_type': questionType,
      'num_mcq_options': numMcqOptions,
      'num_so_options': numSoOptions,
      'num_sata_options': numSataOptions,
      'num_blanks': numBlanks,
      // Individual question performance
      'avg_react_time': avgReactTime,
      'was_first_attempt': wasFirstAttempt ? 1 : 0,
      'total_correct_attempts': totalCorrectAttempts,
      'total_incorrect_attempts': totalIncorrectAttempts,
      'total_attempts': totalAttempts,
      'accuracy_rate': accuracyRate,
      'revision_streak': revisionStreak,
      // Temporal metrics
      'time_of_presentation': timeOfPresentation,
      'last_revised_date': lastRevisedDate,
      'days_since_last_revision': daysSinceLastRevision,
      'days_since_first_introduced': daysSinceFirstIntroduced,
      'attempt_day_ratio': attemptDayRatio,
    };
    
    // Add response_result only if not for inference
    if (!forInference) {
      sampleData['response_result'] = isCorrect! ? 1 : 0;
    }
    
    // Add question_vector if it exists
    if (questionVector != null) {
      sampleData['question_vector'] = questionVector;
    }
    
    // Add k_nearest_neighbors if it exists
    if (kNearestNeighbors != null) {
      sampleData['k_nearest_neighbors'] = kNearestNeighbors;
    }
    
    // Add user_stats_vector if it exists
    if (userStatsVector != null) {
      sampleData['user_stats_vector'] = userStatsVector;
    }
    
    // Add module_performance_vector if it exists
    if (modulePerformanceVector != null) {
      sampleData['module_performance_vector'] = modulePerformanceVector;
    }
    
    // Add user_profile_record if it exists
    if (userProfileRecord != null) {
      sampleData['user_profile_record'] = userProfileRecord;
    }
    
    // Add k_nearest_performance_vector if it exists
    if (kNearestPerformanceVector != null) {
      sampleData['knn_performance_vector'] = kNearestPerformanceVector;
    }
    
    // Release database access before proceeding
    getDatabaseMonitor().releaseDatabaseAccess();
    
    if (forInference) {
      // Return the sample for inference
      QuizzerLogger.logMessage('Successfully generated inference sample for QID: $questionId');
      return sampleData;
    } else {
      // Insert the training sample (this function gets its own db access)
      await attempt_table.addQuestionAnswerAttempt(
        questionId: questionId,
        participantId: userId,
        timeStamp: timeStamp,
        additionalFields: sampleData,
      );
      
      QuizzerLogger.logMessage('Successfully recorded question answer attempt for QID: $questionId');
      return null;
    }
  } catch (e) {
    QuizzerLogger.logError('Error in recordQuestionAnswerAttempt - $e');
    // Make sure we release the connection even if there's an error
    getDatabaseMonitor().releaseDatabaseAccess();
    rethrow;
  }
}


/// Calculates the adjustment factor for time_between_revisions.
double _calculateTimeBetweenRevisionsAdjustment({
  required bool isCorrect,
  required DateTime now,
  required DateTime currentNextRevisionDue,
}) {
  try {
    QuizzerLogger.logMessage('Entering _calculateTimeBetweenRevisionsAdjustment()...');
    
    double adjustment = 0.0;
    
    // Check if the due date passed within the last 24 hours from now
    final bool isDueWithinLast24Hrs = now.difference(currentNextRevisionDue).inHours <= 24 && now.isAfter(currentNextRevisionDue);

    if (isCorrect && !isDueWithinLast24Hrs) {
      // Apply bonus only if correct AND overdue by > 24 hours
      adjustment = 0.005;
      QuizzerLogger.logMessage('Applied bonus adjustment: +0.005 (correct answer, overdue > 24h)');
    } else if (!isCorrect && isDueWithinLast24Hrs) {
      // Apply penalty only if incorrect AND it became due within the last 24 hours
      adjustment = -0.015;
      QuizzerLogger.logMessage('Applied penalty adjustment: -0.015 (incorrect answer, due within 24h)');
    } else {
      QuizzerLogger.logMessage('No adjustment applied (adjustment: $adjustment)');
    }
    
    return adjustment;
  } catch (e) {
    QuizzerLogger.logError('Error in _calculateTimeBetweenRevisionsAdjustment - $e');
    rethrow;
  }
}

/// Calculates the adjustment (+1 or -1) for the revision streak.
int _calculateStreakAdjustment({
  required bool isCorrect,
  // currentRevisionStreak is no longer needed here
}) {
  try {
    QuizzerLogger.logMessage('Entering _calculateStreakAdjustment()...');
    
    final int adjustment = isCorrect ? 1 : -1;
    
    QuizzerLogger.logMessage('Calculated streak adjustment: $adjustment (isCorrect: $isCorrect)');
    
    return adjustment;
  } catch (e) {
    QuizzerLogger.logError('Error in _calculateStreakAdjustment - $e');
    rethrow;
  }
}

/// Applies adjustment and bounds (0.05 to 1.0) to time_between_revisions.
double _calculateUpdatedTimeBetweenRevisions({
  required double currentTimeBetweenRevisions,
  required double adjustment,
}) {
  try {
    QuizzerLogger.logMessage('Entering _calculateUpdatedTimeBetweenRevisions()...');
    
    double updated = currentTimeBetweenRevisions + adjustment;
    
    QuizzerLogger.logMessage('Initial calculation: $currentTimeBetweenRevisions + $adjustment = $updated');
    
    if (updated > 1.0) {
      QuizzerLogger.logMessage('Bounding to maximum: 1.0');
      return 1.0;
    } else if (updated < 0.05) {
      QuizzerLogger.logMessage('Bounding to minimum: 0.05');
      return 0.05;
    }
    
    QuizzerLogger.logMessage('Final time_between_revisions: $updated (within bounds)');
    return updated;
  } catch (e) {
    QuizzerLogger.logError('Error in _calculateUpdatedTimeBetweenRevisions - $e');
    rethrow;
  }
}

/// Calls the SRS algorithm to get next revision date and avg times shown.
Map<String, dynamic> _calculateNextRevisionDate({
  required String status,
  required int updatedStreak,
  required double updatedTimeBetweenRevisions,
}) {
  // TODO This will need to be updated once the probability model is in place
  try {
    QuizzerLogger.logMessage('Entering _calculateNextRevisionDate()...');
    
    QuizzerLogger.logMessage('Calling SRS algorithm with: status=$status, streak=$updatedStreak, timeBetweenRevisions=$updatedTimeBetweenRevisions');
    
    final Map<String, dynamic> result = calculateNextRevisionDate(
      status,
      updatedStreak,
      updatedTimeBetweenRevisions,
    );
    
    QuizzerLogger.logMessage('SRS algorithm returned: next_revision_due=${result['next_revision_due']}, average_times_shown_per_day=${result['average_times_shown_per_day']}');
    
    return result;
  } catch (e) {
    QuizzerLogger.logError('Error in _calculateNextRevisionDate - $e');
    rethrow;
  }
}


// ==========================================
// Public Helper Function
// ==========================================

/// Updates the user-specific question record based on the answer correctness.
/// Calculates new SRS values and directly updates the database.
/// All updates happen in a single atomic operation.
Future<void> updateUserQuestionRecordOnAnswer({
  required bool isCorrect,
  required String userId,
  required String questionId,
  required double reactionTime,
}) async {
  try {
    QuizzerLogger.logMessage('Entering updateUserQuestionRecordOnAnswer()...');
    
    // --- 1. Get current user record from database ---
    final Map<String, dynamic> currentUserRecord = await getUserQuestionAnswerPairById(userId, questionId);
    
    // --- 2. Extract necessary current values ---
    final int currentRevisionStreak = currentUserRecord['revision_streak'] as int;
    final double currentTimeBetweenRevisions = currentUserRecord['time_between_revisions'] as double;
    final int currentTotalAttempts = currentUserRecord['total_attempts'] as int;
    final String currentNextRevisionDueStr = currentUserRecord['next_revision_due'] as String;
    final double currentAvgReactionTime = (currentUserRecord['avg_reaction_time'] as double?) ?? 0.0;
    final DateTime now = DateTime.now();
    final DateTime currentNextRevisionDue = DateTime.parse(currentNextRevisionDueStr); 
    
    QuizzerLogger.logMessage('Current values - streak: $currentRevisionStreak, timeBetweenRevisions: $currentTimeBetweenRevisions, totalAttempts: $currentTotalAttempts, isCorrect: $isCorrect');
    
    // --- 3. Calculate Updates ---
    // Calculate correct/incorrect attempt counters
    final int currentTotalCorrectAttempts = (currentUserRecord['total_correct_attempts'] as int?) ?? 0;
    final int currentTotalIncorrectAttempts = (currentUserRecord['total_incorect_attempts'] as int?) ?? 0;
    
    final int newTotalCorrectAttempts = isCorrect ? currentTotalCorrectAttempts + 1 : currentTotalCorrectAttempts;
    final int newTotalIncorrectAttempts = !isCorrect ? currentTotalIncorrectAttempts + 1 : currentTotalIncorrectAttempts;
    
    // Calculate new total attempts as sum of correct and incorrect attempts
    final int newTotalAttempts = newTotalCorrectAttempts + newTotalIncorrectAttempts;
    
    // Calculate new avg_reaction_time using the derived total attempts:
    final double newAvgReactionTime = ((currentAvgReactionTime * currentTotalAttempts) + reactionTime) / newTotalAttempts;
    
    // Calculate accuracy rates
    final double newQuestionAccuracyRate = newTotalCorrectAttempts / newTotalAttempts;
    final double newQuestionInaccuracyRate = newTotalIncorrectAttempts / newTotalAttempts;
    
    // Update Revision Streak and Time Between Revisions
    final double adjustment = _calculateTimeBetweenRevisionsAdjustment(
      isCorrect: isCorrect,
      now: now,
      currentNextRevisionDue: currentNextRevisionDue,
    );
    
    final int streakAdjustment = _calculateStreakAdjustment(
      isCorrect: isCorrect,
    );
    
    // Calculate new streak (ensure >= 0)
    final int newRevisionStreak = max(0, currentRevisionStreak + streakAdjustment);
    
    // Calculate new time_between_revisions // FIXME Deprecated, there will be no k (time between revision metric once probability model is in place)
    final double newTimeBetweenRevisions = _calculateUpdatedTimeBetweenRevisions(
      currentTimeBetweenRevisions: currentTimeBetweenRevisions,
      adjustment: adjustment,
    );
    
    // Calculate next_revision_due and average_times_shown_per_day
    final String status = isCorrect ? 'correct' : 'incorrect';
    
    final Map<String, dynamic> nextRevisionData = _calculateNextRevisionDate(
      status: status,
      updatedStreak: newRevisionStreak,
      updatedTimeBetweenRevisions: newTimeBetweenRevisions,
    );
    final String newNextRevisionDue = nextRevisionData['next_revision_due'] as String;
    final double newAverageTimesShownPerDay = nextRevisionData['average_times_shown_per_day'] as double;
    
    // Calculate last_revised
    final String newLastRevised = now.toIso8601String();
    
    // Calculate day_time_introduced if it doesn't exist
    final String? dayTimeIntroduced = currentUserRecord['day_time_introduced'] as String?;
    final String finalDayTimeIntroduced = dayTimeIntroduced ?? DateTime.now().toUtc().toIso8601String();
    
    // --- 4. CONDITIONAL REMOVAL FROM CIRCULATION ---
    // Determine final values based on circulation removal logic
    int finalTotalAttempts = newTotalAttempts;
    bool finalInCirculation = (currentUserRecord['in_circulation'] as int? ?? 1) == 1;
    
    if ((newTotalAttempts >= 2 && newRevisionStreak == 0) || 
        (newTotalAttempts >= 4 && newRevisionStreak == 1)) {
      QuizzerLogger.logMessage('Removing question from circulation: attempts >= threshold with low streak');
      
      finalTotalAttempts = 0;
      finalInCirculation = false;
      
      QuizzerLogger.logSuccess('Question removed from circulation and attempts reset to 0');
    }
    
    QuizzerLogger.logMessage('Final values - streak: $newRevisionStreak, timeBetweenRevisions: $newTimeBetweenRevisions, totalAttempts: $finalTotalAttempts, inCirculation: $finalInCirculation, avgReactionTime: $newAvgReactionTime, correctAttempts: $newTotalCorrectAttempts, incorrectAttempts: $newTotalIncorrectAttempts, accuracyRate: $newQuestionAccuracyRate');
    
    Map<String, dynamic> updateData = {
        'revision_streak': newRevisionStreak,
        'last_revised': newLastRevised,
        'next_revision_due': newNextRevisionDue,
        'time_between_revisions': newTimeBetweenRevisions,
        'average_times_shown_per_day': newAverageTimesShownPerDay,
        'in_circulation': finalInCirculation,
        'total_attempts': finalTotalAttempts,
        'avg_reaction_time': newAvgReactionTime,
        'day_time_introduced': finalDayTimeIntroduced,
        'total_correct_attempts': newTotalCorrectAttempts,
        'total_incorect_attempts': newTotalIncorrectAttempts,
        'question_accuracy_rate': newQuestionAccuracyRate,
        'question_inaccuracy_rate': newQuestionInaccuracyRate,
        'last_prob_calc': DateTime.utc(1970, 1, 1).toIso8601String() // Immediately trigger this question to be re-evaluated by the accuracy net
      };
    // QuizzerLogger.logMessage("Individual Question Record Updated, feed is:");
    // updateData.forEach((key, value) {
    //   QuizzerLogger.logMessage("${key.padRight(20)}, $value");
    // });
    // --- 5. Update Database in Single Atomic Operation ---
    await editUserQuestionAnswerPair(
      userUuid: userId,
      questionId: questionId,
      updates: updateData,
    );
    
    QuizzerLogger.logMessage('Successfully updated user question record in database');
  } catch (e) {
    QuizzerLogger.logError('Error in updateUserQuestionRecordOnAnswer - $e');
    rethrow;
  }
}

/// Extracts the 'user_role' claim from the Supabase session object by decoding the JWT.
///
/// Returns 'public_user_unverified' if the session or access token is null/empty,
/// or if the role claim is null/empty after successful JWT decoding.
String determineUserRoleFromSupabaseSession(Session? session) {
  try {
    QuizzerLogger.logMessage('Entering determineUserRoleFromSupabaseSession()...');
    
    if (session == null || session.accessToken.isEmpty) {
      QuizzerLogger.logWarning('No valid session or access token found, defaulting to "public_user_unverified".');
      return 'public_user_unverified';
    }

    // Directly attempt to decode. Errors during parsing will propagate.
    Map<String, dynamic> decodedToken = Jwt.parseJwt(session.accessToken);
    
    // --- LOG REDACTED TOKEN PAYLOAD FOR DEBUGGING ---
    // QuizzerLogger.logValue("$supabaseSession"); // Avoid logging entire session object
    QuizzerLogger.logValue("Access Token: [REDACTED]"); // Log redacted token

    // Create a redacted copy for logging
    final Map<String, dynamic> redactedPayload = Map.from(decodedToken);
    const String redactedValue = '[REDACTED]';
    // Redact potentially sensitive fields
    if (redactedPayload.containsKey('email')) redactedPayload['email'] = redactedValue;
    if (redactedPayload.containsKey('sub')) redactedPayload['sub'] = redactedValue;
    if (redactedPayload.containsKey('session_id')) redactedPayload['session_id'] = redactedValue;
    if (redactedPayload.containsKey('user_metadata')) redactedPayload['user_metadata'] = redactedValue;
    // Add any other fields considered sensitive here
    
    QuizzerLogger.logValue('Decoded JWT Token Payload (Redacted): $redactedPayload');
    // --------------------------------------------------

    // The key 'user_role' must match exactly what your Supabase trigger function sets in the claims.
    final role = decodedToken['user_role'] as String?;

    if (role == null || role.isEmpty) {
      QuizzerLogger.logWarning('\'user_role\' claim not found or empty in decoded JWT, defaulting to "public_user_unverified".');
      return 'public_user_unverified'; // Default if claim is null or empty string
    }
    QuizzerLogger.logValue('User role determined from JWT: $role');
    return role;
  } catch (e) {
    QuizzerLogger.logError('Error in determineUserRoleFromSupabaseSession - $e');
    rethrow;
  }
}
// ----------------------------------------------------------------

