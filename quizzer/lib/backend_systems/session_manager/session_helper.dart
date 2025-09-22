import 'dart:math';
import 'dart:convert'; 
import 'package:quizzer/backend_systems/08_memory_retention_algo/memory_retention_algorithm.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_attempts_table.dart' as attempt_table;
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Logger needed for debugging
import 'package:supabase/supabase.dart'; // For supabase.Session type
import 'package:jwt_decode/jwt_decode.dart'; // For decoding JWT
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart'; // Import for getDatabaseMonitor
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart'; // Import the helper file


// ==========================================
// Helper Function for Recording Answer Attempt
// ==========================================
// This file contains helper functions for the session manager. 
// These functions help to reduce the lines of code in the SessionManager class itself. This should simplify the SessionManager class and make it easier to maintain.

Future<void> recordQuestionAnswerAttempt({
  required String userId,
  required String questionId,
  required bool isCorrect,
}) async {
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
    const questionMetadataQuery = '''
      SELECT 
        question_vector,
        module_name,
        question_type,
        options,
        question_elements
      FROM question_answer_pairs
      WHERE question_id = ?
      LIMIT 1
    ''';
    
    final List<Map<String, dynamic>> questionResults = await db.rawQuery(questionMetadataQuery, [questionId]);
    
    if (questionResults.isEmpty) {
      throw Exception('Question not found: $questionId');
    }
    
    final Map<String, dynamic> questionData = questionResults.first;
    
    // Extract question vector (if exists)
    final String? questionVector = questionData['question_vector'] as String?;
    
    // Extract basic question info
    final String moduleName = questionData['module_name'] as String;
    final String questionType = questionData['question_type'] as String;
    
    // Calculate option counts based on question type and data
    int numMcqOptions = 0;
    int numSoOptions = 0;
    int numSataOptions = 0;
    int numBlanks = 0;
    
    if (questionType == 'multiple_choice' || questionType == 'select_all_that_apply' || questionType == 'sort_order') {
      final String? optionsJson = questionData['options'] as String?;
      if (optionsJson != null) {
        final List<dynamic> options = decodeValueFromDB(optionsJson);
        final int optionCount = options.length;
        
        switch (questionType) {
          case 'multiple_choice':
            numMcqOptions = optionCount;
            break;
          case 'select_all_that_apply':
            numSataOptions = optionCount;
            break;
          case 'sort_order':
            numSoOptions = optionCount;
            break;
        }
      }
    } else if (questionType == 'fill_in_the_blank') {
      // Count blank elements in question_elements
      final String? questionElementsJson = questionData['question_elements'] as String?;
      if (questionElementsJson != null) {
        final List<dynamic> questionElements = decodeValueFromDB(questionElementsJson);
        numBlanks = questionElements.where((element) => 
          element is Map && element['type'] == 'blank'
        ).length;
      }
    }
    
    // ===================================
    // Query 2: Individual Question Performance
    // ===================================
    const userQuestionQuery = '''
      SELECT 
        avg_reaction_time,
        total_correct_attempts,
        total_incorect_attempts,
        total_attempts,
        question_accuracy_rate,
        revision_streak,
        last_revised,
        day_time_introduced
      FROM user_question_answer_pairs
      WHERE user_uuid = ? AND question_id = ?
      LIMIT 1
    ''';
    
    final List<Map<String, dynamic>> userQuestionResults = await db.rawQuery(userQuestionQuery, [userId, questionId]);
    
    if (userQuestionResults.isEmpty) {
      throw Exception('User question pair not found: userId=$userId, questionId=$questionId');
    }
    
    final Map<String, dynamic> userQuestionData = userQuestionResults.first;
    
    // Extract performance metrics
    final double avgReactTime = userQuestionData['avg_reaction_time'] as double? ?? 0.0;
    final int totalCorrectAttempts = userQuestionData['total_correct_attempts'] as int? ?? 0;
    final int totalIncorrectAttempts = userQuestionData['total_incorect_attempts'] as int? ?? 0;
    final int totalAttempts = userQuestionData['total_attempts'] as int? ?? 0;
    final double accuracyRate = userQuestionData['question_accuracy_rate'] as double? ?? 0.0;
    final int revisionStreak = userQuestionData['revision_streak'] as int? ?? 0;
    final String? lastRevisedDate = userQuestionData['last_revised'] as String?;
    final String? dayTimeIntroduced = userQuestionData['day_time_introduced'] as String?;
    
    // Calculate temporal metrics at time of recording
    final String timeOfPresentation = timeStamp;
    final bool wasFirstAttempt = totalAttempts == 0;
    
    // Calculate days since last revision
    double daysSinceLastRevision = 0.0;
    if (lastRevisedDate != null) {
      final DateTime lastRevised = DateTime.parse(lastRevisedDate);
      final DateTime now = DateTime.parse(timeStamp);
      daysSinceLastRevision = now.difference(lastRevised).inMicroseconds / Duration.microsecondsPerDay;
    }
    
    // Calculate days since first introduced
    double daysSinceFirstIntroduced = 0.0;
    double attemptDayRatio = 0.0;
    if (dayTimeIntroduced != null) {
      final DateTime firstIntroduced = DateTime.parse(dayTimeIntroduced);
      final DateTime now = DateTime.parse(timeStamp);
      daysSinceFirstIntroduced = now.difference(firstIntroduced).inMicroseconds / Duration.microsecondsPerDay;
      
      // Calculate attempt day ratio (avoid division by zero)
      if (daysSinceFirstIntroduced > 0) {
        attemptDayRatio = totalAttempts / daysSinceFirstIntroduced;
      }
    }
    
    // ===================================
    // Query 3: User Stats Vector
    // ===================================
    final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    
    const userStatsQuery = '''
      SELECT *
      FROM user_daily_stats
      WHERE user_id = ? AND record_date = ?
      LIMIT 1
    ''';
    
    final List<Map<String, dynamic>> userStatsResults = await db.rawQuery(userStatsQuery, [userId, today]);
    
    String? userStatsVector;
    if (userStatsResults.isNotEmpty) {
      userStatsVector = jsonEncode(userStatsResults.first);
    }
    
    // ===================================
    // Query 4: Module Performance Vector
    // ===================================
    const modulePerformanceQuery = '''
      SELECT 
        module_name,
        num_mcq,
        num_fitb,
        num_sata,
        num_tf,
        num_so,
        num_total,
        total_seen,
        percentage_seen,
        total_correct_attempts,
        total_incorrect_attempts,
        total_attempts,
        overall_accuracy,
        avg_attempts_per_question,
        avg_reaction_time
      FROM user_module_activation_status
      WHERE user_id = ?
      ORDER BY module_name
    ''';
    
    final List<Map<String, dynamic>> modulePerformanceResults = await db.rawQuery(modulePerformanceQuery, [userId]);
    
    String? modulePerformanceVector;
    if (modulePerformanceResults.isNotEmpty) {
      // Calculate days_since_last_seen for each module and add to records
      final DateTime now = DateTime.parse(timeStamp);
      
      // Get last seen dates for all user modules in a single query
      const lastSeenQuery = '''
        SELECT 
          qap.module_name,
          MAX(uqap.last_revised) as last_seen_date
        FROM user_question_answer_pairs uqap
        INNER JOIN question_answer_pairs qap ON uqap.question_id = qap.question_id
        WHERE uqap.user_uuid = ?
        GROUP BY qap.module_name
      ''';
      
      final List<Map<String, dynamic>> lastSeenResults = await db.rawQuery(lastSeenQuery, [userId]);
      
      // Create map of module_name -> last_seen_date for quick lookup
      final Map<String, String?> moduleLastSeen = {};
      for (final result in lastSeenResults) {
        moduleLastSeen[result['module_name'] as String] = result['last_seen_date'] as String?;
      }
      
      // Process each module performance record
      final List<Map<String, dynamic>> processedModuleRecords = [];
      for (final moduleRecord in modulePerformanceResults) {
        final Map<String, dynamic> processedRecord = Map<String, dynamic>.from(moduleRecord);
        final String moduleNameKey = moduleRecord['module_name'] as String;
        
        // Calculate days_since_last_seen
        double daysSinceLastSeen = 0.0;
        final String? lastSeenDateStr = moduleLastSeen[moduleNameKey];
        if (lastSeenDateStr != null) {
          final DateTime lastSeenDate = DateTime.parse(lastSeenDateStr);
          daysSinceLastSeen = now.difference(lastSeenDate).inMicroseconds / Duration.microsecondsPerDay;
        }
        
        processedRecord['days_since_last_seen'] = daysSinceLastSeen;
        processedModuleRecords.add(processedRecord);
      }
      
      modulePerformanceVector = jsonEncode(processedModuleRecords);
    }
    
    // ===================================
    // Query 5: User Profile Record
    // ===================================
    const userProfileQuery = '''
      SELECT 
        highest_level_edu,
        undergrad_major,
        undergrad_minor,
        grad_major,
        years_since_graduation,
        education_background,
        teaching_experience,
        profile_picture,
        country_of_origin,
        current_country,
        current_state,
        current_city,
        urban_rural,
        religion,
        political_affilition,
        marital_status,
        num_children,
        veteran_status,
        native_language,
        secondary_languages,
        num_languages_spoken,
        birth_date,
        age,
        household_income,
        learning_disabilities,
        physical_disabilities,
        housing_situation,
        birth_order,
        current_occupation,
        years_work_experience,
        hours_worked_per_week,
        total_job_changes
      FROM user_profile
      WHERE uuid = ?
      LIMIT 1
    ''';
    
    final List<Map<String, dynamic>> userProfileResults = await db.rawQuery(userProfileQuery, [userId]);
    
    String? userProfileRecord;
    if (userProfileResults.isNotEmpty) {
      userProfileRecord = jsonEncode(userProfileResults.first);
    }
    
    // ===================================
    // Prepare Data for Insert
    // ===================================
    final Map<String, dynamic> additionalFields = {
      'response_result': isCorrect ? 1 : 0,
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
    
    // Add question_vector if it exists
    if (questionVector != null) {
      additionalFields['question_vector'] = questionVector;
    }
    
    // Add user_stats_vector if it exists
    if (userStatsVector != null) {
      additionalFields['user_stats_vector'] = userStatsVector;
    }
    
    // Add module_performance_vector if it exists
    if (modulePerformanceVector != null) {
      additionalFields['module_performance_vector'] = modulePerformanceVector;
    }
    
    // Add user_profile_record if it exists
    if (userProfileRecord != null) {
      additionalFields['user_profile_record'] = userProfileRecord;
    }
    
    // Release database access before calling table function
    getDatabaseMonitor().releaseDatabaseAccess();
 
    // Insert the training sample (this function gets its own db access)
    await attempt_table.addQuestionAnswerAttempt(
      questionId: questionId,
      participantId: userId,
      timeStamp: timeStamp,
      additionalFields: additionalFields,
    );
    
    QuizzerLogger.logMessage('Successfully recorded question answer attempt for QID: $questionId');
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
  required Map<String, dynamic> currentUserRecord,
  required bool isCorrect,
  required String userId,
  required String questionId,
  required double reactionTime,
}) async {
  try {
    QuizzerLogger.logMessage('Entering updateUserQuestionRecordOnAnswer()...');
    
    // --- 1. Extract necessary current values ---
    final int currentRevisionStreak = currentUserRecord['revision_streak'] as int;
    final double currentTimeBetweenRevisions = currentUserRecord['time_between_revisions'] as double;
    final int currentTotalAttempts = currentUserRecord['total_attempts'] as int;
    final String currentNextRevisionDueStr = currentUserRecord['next_revision_due'] as String;
    final double currentAvgReactionTime = (currentUserRecord['avg_reaction_time'] as double?) ?? 0.0;
    final DateTime now = DateTime.now();
    final DateTime currentNextRevisionDue = DateTime.parse(currentNextRevisionDueStr); 
    
    QuizzerLogger.logMessage('Current values - streak: $currentRevisionStreak, timeBetweenRevisions: $currentTimeBetweenRevisions, totalAttempts: $currentTotalAttempts, isCorrect: $isCorrect');
    
    // --- 2. Calculate Updates ---
    
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
    
    // --- 3. CONDITIONAL REMOVAL FROM CIRCULATION ---
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
      };

    // QuizzerLogger.logMessage("Individual Question Record Updated, feed is:");
    // updateData.forEach((key, value) {
    //   QuizzerLogger.logMessage("${key.padRight(20)}, $value");
    // });

    // --- 4. Update Database in Single Atomic Operation ---
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

