import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart' as user_profile;
import 'package:quizzer/backend_systems/02_login_authentication/offline_login.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'dart:async';
import 'package:quizzer/backend_systems/session_manager/session_helper.dart';
import 'package:hive/hive.dart';

/// Catches AuthException for known Supabase errors.
/// On successful login, stores offline login data and initializes SessionManager.
Future<Map<String, dynamic>> attemptSupabaseLogin(String email, String password, SupabaseClient supabase, Box storage) async {
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

    final authResult = {
        'success': true,
        'message': 'Login successful',
        'user': response.user!.toJson(), 
        'session': response.session?.toJson(), 
        'user_role': userRole,
    };
    // Ensure local profile exists immediately after successful Supabase auth
    await ensureLocalProfileExists(email);
    // Store offline login data for future offline access
    await storeOfflineLoginData(email, storage, authResult);
    
    // Initialize SessionManager with user data
    final sessionManager = getSessionManager();
    // Ensure SessionManager is fully initialized before accessing storage
    await sessionManager.initializationComplete;
    

    
    // Get the local user ID from the user profile table, not the Supabase user ID
    final localUserId = await user_profile.getUserIdByEmail(email);
    sessionManager.userId = localUserId;
    sessionManager.userEmail = email;
    sessionManager.userLoggedIn = true;
    sessionManager.sessionStartTime = DateTime.now();

    return authResult;
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
/// creates a new profile as fallback for users with Supabase auth but no profile.
Future<void> ensureLocalProfileExists(String email) async {
  try {
    QuizzerLogger.logMessage("Ensuring local profile exists for $email");

    // Get list of emails currently in profile table
    List<String> emailList = await user_profile.getAllUserEmails();
    // Check if email is in the list
    bool isEmailInList = emailList.contains(email);
    QuizzerLogger.logMessage("Is user in local profile list -> $isEmailInList");
    
    if (!isEmailInList) {
      QuizzerLogger.logMessage("User profile not found locally, attempting to fetch from Supabase for $email");
      try {
        await user_profile.fetchAndInsertUserProfileFromSupabase(email);
        QuizzerLogger.logSuccess("Successfully fetched and inserted user profile from Supabase for $email");
      } catch (e) {
        QuizzerLogger.logWarning("Failed to fetch user profile from Supabase for $email: $e");
        QuizzerLogger.logMessage("Creating new local profile for user with Supabase auth but no profile for $email");
        
        // Generate a username from the email (remove domain and any special characters)
        final String username = _generateUsernameFromEmail(email);
        
        // Create a new profile for users who have Supabase authentication but no profile
        final bool profileCreated = await user_profile.createNewUserProfile(email, username);
        if (profileCreated) {
          QuizzerLogger.logSuccess("Successfully created new local profile for $email with username: $username");
        } else {
          QuizzerLogger.logError("Failed to create new local profile for $email");
          throw StateError("Failed to create local profile for $email");
        }
      }
    }

    // Verify the profile now exists
    emailList = await user_profile.getAllUserEmails();
    isEmailInList = emailList.contains(email);
    QuizzerLogger.logMessage("Final check - is user in local profile list -> $isEmailInList");
    
    if (!isEmailInList) {
      throw StateError("Failed to ensure local profile exists for $email");
    }
  } catch (e) {
    QuizzerLogger.logError('Error ensuring local profile exists for $email - $e');
    rethrow;
  }
}

/// Generates a username from an email address
/// Removes the domain part and any special characters
String _generateUsernameFromEmail(String email) {
  try {
    // Extract the local part of the email (before the @)
    final String localPart = email.split('@')[0];
    
    // Remove any special characters and replace with underscores
    final String cleanUsername = localPart.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    
    // Ensure it's not empty and has a reasonable length
    if (cleanUsername.isEmpty) {
      return 'user_${DateTime.now().millisecondsSinceEpoch}';
    }
    
    // Limit length to 20 characters
    final String finalUsername = cleanUsername.length > 20 
        ? cleanUsername.substring(0, 20) 
        : cleanUsername;
    
    QuizzerLogger.logMessage("Generated username '$finalUsername' from email '$email'");
    return finalUsername;
  } catch (e) {
    QuizzerLogger.logError('Error generating username from email $email - $e');
    // Fallback to timestamp-based username
    return 'user_${DateTime.now().millisecondsSinceEpoch}';
  }
}