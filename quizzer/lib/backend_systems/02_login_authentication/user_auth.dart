import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'dart:async';
import 'package:hive/hive.dart';

/// Encapsulates all functionality relating to authorizing the user session, and the user's role
class UserAuth {
  /// Catches AuthException for known Supabase errors.
  /// On successful login, stores offline login data and initializes SessionManager.
  Future<Map<String, dynamic>> attemptSupabaseLogin(
      String email, String password, SupabaseClient supabase, Box storage) async {
    QuizzerLogger.logMessage('Attempting Supabase authentication for $email');
    try {
      QuizzerLogger.logMessage('Attempting Supabase authentication');
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // Success Case
      QuizzerLogger.logSuccess('Supabase authentication successful for $email');
      final authResult = {
        'success': true,
        'message': 'Login successful',
        'user': response.user!.toJson(),
        'session': response.session?.toJson(),
        'user_role': SessionManager().userRole,
      };
      return authResult;
    } on AuthException catch (e) {
      QuizzerLogger.logWarning('Supabase authentication failed: ${e.message}');
      return {
        'success': false,
        'message': e.message,
        'user_role': 'public_user_unverified',
        // Default on failure
      };
    }
  }
}