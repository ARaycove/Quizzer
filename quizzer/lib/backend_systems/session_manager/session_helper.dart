import 'package:jwt_decode/jwt_decode.dart';
import 'package:supabase/supabase.dart'; // For supabase.Session type
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Logger needed for debugging
import 'package:hive/hive.dart';

/// Contains all private functions for the SessionManager
/// Designed to declutter the SessionManager
class SessionHelper {
  /// Extracts the 'user_role' claim from the Supabase session object by decoding the JWT.
  ///
  /// Returns 'public_user_unverified' if the session or access token is null/empty,
  /// or if the role claim is null/empty after successful JWT decoding.
  static String determineUserRoleFromSupabaseSession(Session? session) {
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

  /// Clears all Hive storage data (for testing purposes)
  Future<void> clearStorage(Box storage) async {
    try {
      QuizzerLogger.logMessage('Entering clearStorage()...');
      await storage.clear();
      QuizzerLogger.logSuccess('Storage cleared successfully');
    } catch (e) {
      QuizzerLogger.logError('Error in clearStorage - $e');
      rethrow;
    }
  }

}



