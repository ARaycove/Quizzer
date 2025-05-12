import 'dart:math';
import 'dart:convert'; 
import 'package:quizzer/backend_systems/08_memory_retention_algo/memory_retention_algorithm.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_attempts_table.dart' as attempt_table;
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; 
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart'; // Import DatabaseMonitor
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Logger needed for debugging
import 'package:supabase/supabase.dart'; // For supabase.Session type
import 'package:jwt_decode/jwt_decode.dart'; // For decoding JWT

// ==========================================
// Helper Function for Recording Answer Attempt
// ==========================================
Future<void> recordQuestionAnswerAttempt({
  required Map<String, dynamic> recordBeforeUpdate, // User record *before* updates
  required bool isCorrect,
  required DateTime timeAnswerGiven,
  required DateTime timeDisplayed,
  required String userId,
  required String questionId,
  required String? currentSubjects, // From static details
  required String? currentConcepts, // From static details
}) async{
    // Record Answer Attempt in DB (Moved Before User Record Update) ---
    DatabaseMonitor dbMonitor = getDatabaseMonitor();
    Database? db = await dbMonitor.requestDatabaseAccess();
    if (db == null) {
      throw StateError('Database unavailable during answer submission.');
    }
     final double    responseTimeSeconds   = 
     timeAnswerGiven.difference(timeDisplayed).inMicroseconds / Duration.microsecondsPerSecond;
 
     final String?   lastRevisedBeforeStr  = 
     recordBeforeUpdate['last_revised'] as String?;
 
     final DateTime? lastRevisedBefore     = 
     lastRevisedBeforeStr == null ? null : DateTime.tryParse(lastRevisedBeforeStr);
 
     double?         daysSinceLastRevision;
 
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
      db: db,
    );
    // Release lock AFTER successful operation
    dbMonitor.releaseDatabaseAccess();
}


/// Calculates the adjustment factor for time_between_revisions.
double _calculateTimeBetweenRevisionsAdjustment({
  required bool isCorrect,
  required DateTime now,
  required DateTime currentNextRevisionDue,
}) {
  double adjustment = 0.0;
  
  // Check if the due date passed within the last 24 hours from now
  final bool isDueWithinLast24Hrs = now.difference(currentNextRevisionDue).inHours <= 24 && now.isAfter(currentNextRevisionDue);

  if (isCorrect && !isDueWithinLast24Hrs) {
    // Apply bonus only if correct AND overdue by > 24 hours
    adjustment = 0.005;
  } else if (!isCorrect && isDueWithinLast24Hrs) {
    // Apply penalty only if incorrect AND it became due within the last 24 hours
    adjustment = -0.015;
  }
  return adjustment;
}

/// Calculates the adjustment (+1 or -1) for the revision streak.
int _calculateStreakAdjustment({
  required bool isCorrect,
  // currentRevisionStreak is no longer needed here
}) {
  return isCorrect ? 1 : -1;
}

/// Applies adjustment and bounds (0.05 to 1.0) to time_between_revisions.
double _calculateUpdatedTimeBetweenRevisions({
  required double currentTimeBetweenRevisions,
  required double adjustment,
}) {
  double updated = currentTimeBetweenRevisions + adjustment;
  if (updated > 1.0) {
    return 1.0;
  } else if (updated < 0.05) {
    return 0.05;
  }
  return updated;
}

/// Calls the SRS algorithm to get next revision date and avg times shown.
Map<String, dynamic> _calculateNextRevisionDate({
  required String status,
  required int updatedStreak,
  required double updatedTimeBetweenRevisions,
}) {
  return calculateNextRevisionDate(
    status,
    updatedStreak,
    updatedTimeBetweenRevisions,
  );
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

  // Create a mutable copy to avoid modifying the original map directly
  final Map<String, dynamic> updatedRecord = Map<String, dynamic>.from(currentUserRecord);

  // --- 1. Extract necessary current values ---
  final int currentRevisionStreak = updatedRecord['revision_streak'] as int;
  final double currentTimeBetweenRevisions = updatedRecord['time_between_revisions'] as double;
  final int currentTotalAttempts = updatedRecord['total_attempts'] as int;
  final String currentNextRevisionDueStr = updatedRecord['next_revision_due'] as String;

  final DateTime now = DateTime.now();
  final DateTime currentNextRevisionDue = DateTime.parse(currentNextRevisionDueStr); 

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

  return updatedRecord;
}

// --- Helper to Determine User Role from Supabase Session Object ---
/// Extracts the 'user_role' claim from the Supabase session object by decoding the JWT.
///
/// Returns 'public_user_unverified' if the session or access token is null/empty,
/// or if the role claim is null/empty after successful JWT decoding.
/// Throws an error if JWT decoding itself fails.
String determineUserRoleFromSupabaseSession(Session? supabaseSession) {
  if (supabaseSession == null || supabaseSession.accessToken.isEmpty) {
    QuizzerLogger.logWarning('Supabase session or access token is null/empty, defaulting role to "public_user_unverified".');
    return 'public_user_unverified'; 
  }

  // Directly attempt to decode. Errors during parsing will propagate.
  Map<String, dynamic> decodedToken = Jwt.parseJwt(supabaseSession.accessToken);
  
  // --- LOG THE ENTIRE DECODED TOKEN FOR DEBUGGING ---
  QuizzerLogger.logValue("$supabaseSession");
  QuizzerLogger.logValue("${supabaseSession.accessToken}");
  QuizzerLogger.logValue('Decoded JWT Token Payload: $decodedToken');
  // --------------------------------------------------

  // The key 'user_role' must match exactly what your Supabase trigger function sets in the claims.
  final role = decodedToken['user_role'] as String?;

  if (role == null || role.isEmpty) {
    QuizzerLogger.logWarning('\'user_role\' claim not found or empty in decoded JWT, defaulting to "public_user_unverified".');
    return 'public_user_unverified'; // Default if claim is null or empty string
  }
  QuizzerLogger.logValue('User role determined from JWT: $role');
  return role;
}
// ----------------------------------------------------------------

/// Builds placeholder records for display when the question queue is empty.
Map<String, Map<String, dynamic>> buildDummyNoQuestionsRecord() {
  const String dummyId = "dummy_no_questions";
  
  // Mimics the structure of a user-question record (UQPair)
  final Map<String, dynamic> dummyUserRecord = {
    'question_id': dummyId,
    // Add other UQPair fields with default/placeholder values if needed by UI
    'revision_streak': 0, 
    'next_revision_due': DateTime.now().toIso8601String(), 
    // etc. - keeping minimal for now
  };

  // Mimics the structure of a static question details record (QPair)
  final Map<String, dynamic> dummyStaticDetails = {
    'question_id': dummyId,
    'question_type': 'multiple_choice', // Use multiple choice as requested
    // Format follows the parsed structure from getQuestionAnswerPairById
    'question_elements': [{'type': 'text', 'content': 'No new questions available right now. Check back later!'}], 
    'answer_elements': [{'type': 'text', 'content': ''}], // Empty answer
    'options': [
      {'type': 'text', 'content': 'Okay'},
      {'type': 'text', 'content': 'Add new modules'},
      {'type': 'text', 'content': 'Check Back Later!'},
    ], 
    'correct_option_index': 0, // Index of the 'Okay' option (or -1 if no default correct)
    'module_name': 'System', // Placeholder module
    'subjects': '', // Placeholder subjects
    'concepts': '', // Placeholder concepts
    // Add other QPair fields with default/placeholder values if required by UI
    'time_stamp': DateTime.now().millisecondsSinceEpoch.toString(),
    'qst_contrib': 'system',
    'ans_contrib': 'system',
    'citation': '',
    'ans_flagged': false,
    'has_been_reviewed': true,
    'flag_for_removal': false,
    'completed': true, 
    'correct_order': '', // Empty for non-sort_order
  };

  return {
    'userRecord': dummyUserRecord,
    'staticDetails': dummyStaticDetails,
  };
}