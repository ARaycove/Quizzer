import 'dart:math';
import 'dart:convert'; 
import 'package:quizzer/backend_systems/08_memory_retention_algo/memory_retention_algorithm.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_attempts_table.dart' as attempt_table;
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Logger needed for debugging
import 'package:supabase/supabase.dart'; // For supabase.Session type
import 'package:jwt_decode/jwt_decode.dart'; // For decoding JWT

// ==========================================
// Helper Function for Recording Answer Attempt
// ==========================================
// This file contains helper functions for the session manager. 
// These functions help to reduce the lines of code in the SessionManager class itself. This should simplify the SessionManager class and make it easier to maintain.

Future<void> recordQuestionAnswerAttempt({
  required Map<String, dynamic> recordBeforeUpdate, // User record *before* updates
  required bool isCorrect,
  required DateTime timeAnswerGiven,
  required DateTime timeDisplayed,
  required String userId,
  required String questionId,
  required String? currentSubjects, // From static details
  required String? currentConcepts, // From static details
}) async {
  try {
    QuizzerLogger.logMessage('Entering recordQuestionAnswerAttempt()...');
    
    // Calculate response time
    final double responseTimeSeconds = 
        timeAnswerGiven.difference(timeDisplayed).inMicroseconds / Duration.microsecondsPerSecond;
 
    // Calculate days since last revision
    final String? lastRevisedBeforeStr = 
        recordBeforeUpdate['last_revised'] as String?;
 
    final DateTime? lastRevisedBefore = 
        lastRevisedBeforeStr == null ? null : DateTime.tryParse(lastRevisedBeforeStr);
 
    double? daysSinceLastRevision;
 
    if (lastRevisedBefore != null) {
      daysSinceLastRevision = timeAnswerGiven.difference(lastRevisedBefore).inMicroseconds / Duration.microsecondsPerDay;
    }
    
    // Format context as JSON
    final List<String> subjectsList = (currentSubjects ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final List<String> conceptsList = (currentConcepts ?? '').split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
    final String contextJson = jsonEncode({
      'subjects': subjectsList,
      'concepts': conceptsList,
    });

    // Table function handles its own database access
    await attempt_table.addQuestionAnswerAttempt(
      timeStamp: timeAnswerGiven.toUtc().toIso8601String(),
      questionId: questionId,
      participantId: userId,
      responseTime: responseTimeSeconds,
      responseResult: isCorrect ? 1 : 0,
      questionContextCsv: contextJson, // Pass the JSON string 
      totalAttempts: recordBeforeUpdate['total_attempts'] as int,        // Value *before* update
      revisionStreak: recordBeforeUpdate['revision_streak'] as int,     // Value *before* update
      lastRevisedDate: recordBeforeUpdate['last_revised'] as String?,   // Value *before* update
      daysSinceLastRevision: daysSinceLastRevision,                       // Calculated based on *before* update
    );
    
    QuizzerLogger.logMessage('Successfully recorded question answer attempt for QID: $questionId');
  } catch (e) {
    QuizzerLogger.logError('Error in recordQuestionAnswerAttempt - $e');
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
/// Calculates new SRS values and returns the updated record.
Map<String, dynamic> updateUserQuestionRecordOnAnswer({
  required Map<String, dynamic> currentUserRecord,
  required bool isCorrect,
}) {
  try {
    QuizzerLogger.logMessage('Entering updateUserQuestionRecordOnAnswer()...');
    
    // Create a mutable copy to avoid modifying the original map directly
    final Map<String, dynamic> updatedRecord = Map<String, dynamic>.from(currentUserRecord);

    // --- 1. Extract necessary current values ---
    final int currentRevisionStreak = updatedRecord['revision_streak'] as int;
    final double currentTimeBetweenRevisions = updatedRecord['time_between_revisions'] as double;
    final int currentTotalAttempts = updatedRecord['total_attempts'] as int;
    final String currentNextRevisionDueStr = updatedRecord['next_revision_due'] as String;

    final DateTime now = DateTime.now();
    final DateTime currentNextRevisionDue = DateTime.parse(currentNextRevisionDueStr); 

    QuizzerLogger.logMessage('Current values - streak: $currentRevisionStreak, timeBetweenRevisions: $currentTimeBetweenRevisions, totalAttempts: $currentTotalAttempts, isCorrect: $isCorrect');

    // --- 2. Calculate and Assign Updates Directly to the Copy ---
    // --------------------------------------------------
    // Update total attempts
    updatedRecord['total_attempts'] = currentTotalAttempts + 1;

    // --------------------------------------------------
    // Update Revision Streak and Time Between Revisions
    final double adjustment = _calculateTimeBetweenRevisionsAdjustment(
      isCorrect: isCorrect,
      now: now,
      currentNextRevisionDue: currentNextRevisionDue,
    );

    final int streakAdjustment = _calculateStreakAdjustment(
      isCorrect: isCorrect,
    );

    // Update streak (ensure >= 0)
    updatedRecord['revision_streak'] = max(0, currentRevisionStreak + streakAdjustment);

    // Update time_between_revisions
    updatedRecord['time_between_revisions'] = _calculateUpdatedTimeBetweenRevisions(
      currentTimeBetweenRevisions: currentTimeBetweenRevisions,
      adjustment: adjustment,
    );

    QuizzerLogger.logMessage('Updated values - streak: ${updatedRecord['revision_streak']}, timeBetweenRevisions: ${updatedRecord['time_between_revisions']}, totalAttempts: ${updatedRecord['total_attempts']}');

    // --------------------------------------------------
    // update next_revision_due and average_times_shown_per_day
    final String status = isCorrect ? 'correct' : 'incorrect';
    final Map<String, dynamic> nextRevisionData = _calculateNextRevisionDate(
      status: status,
      updatedStreak: updatedRecord['revision_streak'] as int, // Use the newly updated streak
      updatedTimeBetweenRevisions: updatedRecord['time_between_revisions'] as double, // Use the newly updated time
    );
    updatedRecord['next_revision_due'] = nextRevisionData['next_revision_due'] as String;
    updatedRecord['average_times_shown_per_day'] = nextRevisionData['average_times_shown_per_day'] as double;

    // --------------------------------------------------
    // update last_revised and last_updated
    updatedRecord['last_revised'] = now.toIso8601String();
    updatedRecord['last_updated'] = updatedRecord['last_revised']; // Use same 'now' timestamp

    // --------------------------------------------------
    // CONDITIONAL REMOVAL FROM CIRCULATION
    // --------------------------------------------------
    // Purpose: Remove questions from circulation that users consistently struggle with
    // 
    // Rationale: If a user has attempted a question n+ times and still has a 
    // revision_streak of 0, they are likely struggling with the concept and need
    // a break from seeing this question repeatedly. This prevents frustration and
    // allows the user to focus on other questions they can learn from.
    //
    // Criteria: revision_streak still 0 AND total_attempts >= n
    // This handles patterns like:
    // - Incorrect → Incorrect → ... (triggers on nth attempt)
    // - Correct → Incorrect → Incorrect → ... (triggers on nth attempt)  
    // - Any back-and-forth where they can't consistently get it right
    //
    // Secondary criteria: revision_streak = 1 AND total_attempts >= m
    // This catches inconsistent back-and-forth patterns like:
    // - Correct → Incorrect → Correct → Incorrect → ... (many attempts, low streak)
    // Where someone occasionally gets it right but struggles overall
    //
    // Action: Reset attempts to 0 and remove from circulation
    // This gives the question a "fresh start" when it eventually returns
    final int finalAttempts = updatedRecord['total_attempts'] as int;
    final int finalRevisionStreak = updatedRecord['revision_streak'] as int;
    
    if ((finalAttempts >= 2 && finalRevisionStreak == 0) || 
        (finalAttempts >= 4 && finalRevisionStreak == 1)) {
      QuizzerLogger.logMessage('Removing question from circulation: n+ attempts with revision_streak still 0, or m+ attempts with revision_streak = 1');
      
      // Reset attempts to 0 and remove from circulation
      updatedRecord['total_attempts'] = 0;
      updatedRecord['in_circulation'] = 0; // SQL boolean as integer
      
      QuizzerLogger.logSuccess('Question removed from circulation and attempts reset to 0');
    }

    QuizzerLogger.logMessage('Successfully updated user question record with new SRS values');
    
    return updatedRecord;
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

