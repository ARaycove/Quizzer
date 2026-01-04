import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

Future<Map<String, dynamic>> handlePasswordRecovery(Map<String, dynamic> message, SupabaseClient supabase) async {
  try {
    final email = message['email'] as String;

    QuizzerLogger.logMessage('Starting reset password process');
    QuizzerLogger.logMessage('Email: $email');
    QuizzerLogger.logMessage('Received message map: $message');

    Map<String, dynamic> results = {};

    try {
      QuizzerLogger.logMessage('Attempting Supabase password recovery with email: $email');
      await supabase.auth.resetPasswordForEmail(email);
      QuizzerLogger.logMessage('Supabase reset password response received');

    } on AuthException catch (e) {
      // If Supabase returns an authentication error, capture it.
      QuizzerLogger.logError('Supabase AuthException during signup: ${e.message}');
      results = {
        'success': false,
        'message': e.message // Return the specific error from Supabase
      };
      // Return immediately as signup failed.
      return results;
    } // End of allowed try-catch block

    return results;
  } catch (e) {
    QuizzerLogger.logError('Error in handleNewUserProfileCreation - $e');
    rethrow;
  }
}
