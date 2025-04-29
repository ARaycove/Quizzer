import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_attempts_record.dart';
import 'package:supabase/supabase.dart';
import 'package:hive/hive.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile_table.dart' as user_profile;
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'dart:async';
import 'package:sqflite/sqflite.dart';

// --- Private Helper Functions ---

/// Checks Hive storage for a recent offline login and updates results accordingly.
Map<String, dynamic> _checkOfflineLogin(String email, Box storage, Map<String, dynamic> currentResults) {
  QuizzerLogger.logMessage('Checking for offline login data for $email');
  Map<String, dynamic> updatedResults = Map.from(currentResults); // Copy to avoid modifying original directly here

  final lastLoginStr = storage.get(email);
  if (lastLoginStr is String) { // Check type for safety
    // DateTime.parse will throw FormatException on invalid string (Fail Fast)
    final lastLogin = DateTime.parse(lastLoginStr);
    final today = DateTime.now();
    final difference = today.difference(lastLogin).inDays;

    QuizzerLogger.logMessage('Last login for $email was $difference days ago');
    if (difference <= 30) {
      QuizzerLogger.logMessage('Recent offline login detected for $email');
      // Retrieve token if available
      final token = storage.get('${email}_token');
      updatedResults = {
        'success': true,
        'message': 'offline_login',
        'token': token, // Include token if found
      };
    } else {
        QuizzerLogger.logMessage('Offline login data found but expired for $email');
        updatedResults['message'] = 'Offline login expired. Please connect and log in online.'; // Update message only
    }
  } else {
      QuizzerLogger.logMessage('No valid offline login data found for $email');
      // Keep the original error message from the Supabase failure (already in updatedResults)
  }
  return updatedResults;
}

/// Handles storing data to Hive after a successful Supabase login.
Future<void> _handleSuccessfulSupabaseLogin(String email, Box storage, Map<String, dynamic> supabaseResults) async {
  QuizzerLogger.logMessage('Handling successful Supabase login for $email');
  // Store session data
  final user = supabaseResults['user'];
  final session = supabaseResults['session'];
  if (user != null && session != null) {
    // Add null checks or assertions for potentially null fields if necessary
    final String? lastSignInAt = user['last_sign_in_at'] as String?;
    final String? accessToken = session['access_token'] as String?;

    if (lastSignInAt != null && accessToken != null) {
        await storage.put(email, lastSignInAt);
        await storage.put('${email}_token', accessToken);
        QuizzerLogger.logMessage("Stored last login ($lastSignInAt) and token for $email");
    } else {
        QuizzerLogger.logWarning("last_sign_in_at or access_token missing in successful Supabase response for $email.");
    }
  } else {
    QuizzerLogger.logWarning("Supabase login success reported, but user or session data missing in results map.");
    // Consider if an error should be thrown here based on application logic
  }
}

/// Catches AuthException for known Supabase errors.
Future<Map<String, dynamic>> _attemptSupabaseLogin(String email, String password, SupabaseClient supabase) async {
  QuizzerLogger.logMessage('Attempting Supabase authentication for $email');
  try {
    QuizzerLogger.logMessage('Attempting Supabase authentication'); // Keep log here
    final response = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    // Success Case
    QuizzerLogger.logSuccess('Supabase authentication successful for $email');
    return {
        'success': true,
        'message': 'Login successful',
        'user': response.user!.toJson(), // Assert non-null user on success
        'session': response.session?.toJson(), // Session can be null
    };
  } on AuthException catch (e) {
    // Known Supabase Auth Failure Case
    QuizzerLogger.logWarning('Supabase authentication failed: ${e.message}');
    return {
      'success': false,
      'message': e.message
    };
  }
  // Note: Other exceptions (network errors, etc.) are not caught here and will propagate (Fail Fast).
}

/// Ensures a local user profile exists for the given email after successful Supabase auth.
/// If not found locally, creates a minimal profile using data from Supabase.
Future<void> _ensureLocalProfileExists(String email) async {
  QuizzerLogger.logMessage("Ensuring local profile exists for $email");

  // Acquire DB access - Loop will continue until success or unexpected error
  Database? db;
  DatabaseMonitor monitor = getDatabaseMonitor();
  while (db == null) {
    db = await monitor.requestDatabaseAccess();
    if (db == null) {
      QuizzerLogger.logMessage('DB access denied for profile check, waiting...');
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
  // Get list of emails currently in profile table
  List<String> emailList = await user_profile.getAllUserEmails(db);
  // Check if email is in the list
  bool isEmailInList = emailList.contains(email);
  // If not in list add profile
  // TODO Fetch username from cloud database if username == "not_found" for later once cloud data is implemented
  if (!isEmailInList) {user_profile.createNewUserProfile(email, "not_found", db);}
  monitor.releaseDatabaseAccess(); // Release DB after successful creation
}

// --- Main Authentication Function ---

Future<Map<String, dynamic>> userAuth({
  required String email,
  required String password,
  required SupabaseClient supabase,
  required Box storage,
}) async {
  QuizzerLogger.logMessage("User authentication requested for $email");
  // 1. Attempt Supabase authentication
  Map<String, dynamic> results = await _attemptSupabaseLogin(email, password, supabase);

  // Flag to track if login succeeded (online or offline)
  bool loginSuccess = results['success'] == true;

  // 2. Handle successful Supabase login (Store data)
  if (loginSuccess) {
    // Store the data for future login (only if online success)
    await _handleSuccessfulSupabaseLogin(email, storage, results);
  }
  // 3. Handle failed Supabase login (Check offline)
  else {
    results = _checkOfflineLogin(email, storage, results);
    // Update success flag based on offline check
    loginSuccess = results['success'] == true;
  }

  // 4. Ensure local profile exists *after* any successful login attempt
  if (loginSuccess) {
    await _ensureLocalProfileExists(email);
  }


  await recordLoginAttempt(
    email: email,
    statusCode: results['message'],
  );
  // 5. Record the login attempt regardless of outcome
  // Note: This might still fail if loginSuccess is false and the profile *never* existed locally.
  // Consider if recording attempts for completely unknown users is desired.


  // 6. Return final results
  return results;
}