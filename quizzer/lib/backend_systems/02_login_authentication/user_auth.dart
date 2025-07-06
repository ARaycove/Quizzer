import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart' as user_profile;
import 'dart:async';
import 'package:quizzer/backend_systems/session_manager/session_helper.dart';

/// Catches AuthException for known Supabase errors.
Future<Map<String, dynamic>> attemptSupabaseLogin(String email, String password, SupabaseClient supabase) async {
  QuizzerLogger.logMessage('Attempting Supabase authentication for $email');
  try {
    QuizzerLogger.logMessage('Attempting Supabase authentication');
    final response = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    // Success Case
    QuizzerLogger.logSuccess('Supabase authentication successful for $email');
    
    // --- EXTRACT USER ROLE ---
    final String userRole = determineUserRoleFromSupabaseSession(response.session);
    // --- END EXTRACT USER ROLE ---

    return {
        'success': true,
        'message': 'Login successful',
        'user': response.user!.toJson(), 
        'session': response.session?.toJson(), 
        'user_role': userRole,
    };
  } on AuthException catch (e) {
    QuizzerLogger.logWarning('Supabase authentication failed: ${e.message}');
    return {
      'success': false,
      'message': e.message,
      'user_role': 'public_user_unverified', // Default on failure
    };
  }
}

/// Ensures a local user profile exists for the given email after successful Supabase auth.
/// If not found locally, fetches the profile from Supabase. If not found on server either,
/// creates a new profile as fallback for truly new users.
Future<void> ensureLocalProfileExists(String email) async {
  try {
    QuizzerLogger.logMessage("Ensuring local profile exists for $email");

    // Get list of emails currently in profile table
    List<String> emailList = await user_profile.getAllUserEmails();
    // Check if email is in the list
    bool isEmailInList = emailList.contains(email);
    // If not in list, try to fetch profile from Supabase first
    QuizzerLogger.logMessage("Is user in list -> $isEmailInList");
    if (!isEmailInList) {
      QuizzerLogger.logMessage("User profile not found locally, attempting to fetch from Supabase for $email");
      try {
        await user_profile.fetchAndInsertUserProfileFromSupabase(email);
        QuizzerLogger.logSuccess("Successfully fetched and inserted user profile from Supabase for $email");
      } catch (e) {
        QuizzerLogger.logWarning("Failed to fetch user profile from Supabase for $email: $e");
        QuizzerLogger.logMessage("Creating new local profile as fallback for $email");
        // Fallback: create a new profile for truly new users
        await user_profile.createNewUserProfile(email, "not_found");
      }
    }

    emailList = await user_profile.getAllUserEmails();
    isEmailInList = emailList.contains(email);
    QuizzerLogger.logMessage("Is user in list -> $isEmailInList");
  } catch (e) {
    QuizzerLogger.logError('Error ensuring local profile exists for $email - $e');
    rethrow;
  }
}