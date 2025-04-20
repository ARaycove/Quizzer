import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/login_authentication/login_attempts_record.dart';
import 'package:supabase/supabase.dart';
import 'package:hive/hive.dart';

// TODO Need more extensive logging 

Future<Map<String, dynamic>> userAuth({
  required String email,
  required String password,
  required SupabaseClient supabase,
  required Box storage,
}) async {
QuizzerLogger.logMessage('Starting login process for: $email');

// Initialize variable for return
Map<String, dynamic> results = {};

// 1. Attempt Supabase authentication
try {
  QuizzerLogger.logMessage('Attempting Supabase authentication');
  final response = await supabase.auth.signInWithPassword(
    email: email,
    password: password,
  );  
    results = {
      'success': true,
      'message': 'Login successful',
      'user': response.user!.toJson(),
      'session': response.session?.toJson(),
    };
  }
// If the login fails for some reason
on AuthException catch (e) {
  QuizzerLogger.logWarning('Supabase authentication failed: ${e.message}');
  // 3. Check secure storage for recent login
  results = {
    'success': false,
    'message': e.message
  };
}

// Check if results indicate success (from Supabase auth)
if (results['success'] == true) {
  // Store session data
  final user = results['user'];
  final session = results['session'];
  if (user != null && session != null) {
    await storage.put(email, user['last_sign_in_at']);
    await storage.put('${email}_token', session['access_token']);
    QuizzerLogger.logMessage("Stored last login and token for $email");
  } else {
    QuizzerLogger.logWarning("Supabase login success reported, but user or session data missing in response.");
    // Consider reverting success state if data is crucial
    // results = {'success': false, 'message': 'Incomplete login data received.'};
  }
}
// If we did not login successfully through supabase, check for recent offline login
else { // Simplified: only check offline if online failed
  final lastLoginStr = storage.get(email);
  if (lastLoginStr is String) { // Check type for safety
    try {
      final lastLogin = DateTime.parse(lastLoginStr);
      final today = DateTime.now();
      final difference = today.difference(lastLogin).inDays;

      QuizzerLogger.logMessage('Last login for $email was $difference days ago');
      if (difference <= 30) {
        QuizzerLogger.logMessage('Recent offline login detected for $email');
        // Retrieve token if available
        final token = storage.get('${email}_token');
        results = {
          'success': true,
          'message': 'offline_login',
          'token': token, // Include token if found
          // Cannot include user/session JSON as we didn't get it from Supabase
        };
      } else {
          QuizzerLogger.logMessage('Offline login data found but expired for $email');
          results['message'] = 'Offline login expired. Please connect and log in online.';
      }
    } catch (e) {
        QuizzerLogger.logError('Error parsing last login date for $email: $e');
        results['message'] = 'Error processing offline login data.';
    }
  } else {
      QuizzerLogger.logMessage('No valid offline login data found for $email');
      // Keep the original error message from the Supabase failure
  }
}
// Regardless of what the results are we need to log the login attempts
// Record the login attempt without awaiting to avoid delaying the response
recordLoginAttempt(
  email: email,
  statusCode: results['message'],
);


// Now return
return results;
}