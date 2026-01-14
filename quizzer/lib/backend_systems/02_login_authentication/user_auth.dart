import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'dart:async';
import 'package:hive/hive.dart';

/// Encapsulates all functionality relating to authorizing the user session, and the user's role
class UserAuth {
  /// Catches AuthException for known Supabase errors.
  /// On successful login, stores offline login data and initializes SessionManager.
  Future<Map<String, dynamic>> attemptSupabaseLogin(String email,
      String password, SupabaseClient supabase, Box storage) async {
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

  /// specific logic for Twilio/Supabase which requires E.164 format (e.g., +14155552671).
  String _sanitizePhoneNumber(String rawPhone) {
    // 1. Remove all non-numeric characters except '+'
    String sanitized = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');

    // 2. Handle missing country code (Assume +1 US if missing for now, or just ensure + exists)
    // Note: For a global app, you'd ideally use a country code picker.
    // This is a naive implementation assuming if it doesn't start with +, it might be a local US number.
    if (!sanitized.startsWith('+')) {
      if (sanitized.length == 10) {
        sanitized = '+1$sanitized'; // Append US country code
      } else {
        // If we can't guess, return as is specifically but add + to ensure it tries to be E.164
        sanitized = '+$sanitized';
      }
    }
    return sanitized;
  }

  /// Sends an OTP to the specified phone number.
  /// Returns a map with success status and message.
  Future<Map<String, dynamic>> signInWithPhone(
      String phoneNumber, SupabaseClient supabase) async {
    final cleanPhone = _sanitizePhoneNumber(phoneNumber);

    QuizzerLogger.logMessage(
        'Attempting Phone authentication for $cleanPhone (raw: $phoneNumber)');
    try {
      await supabase.auth.signInWithOtp(
        phone: cleanPhone,
      );
      QuizzerLogger.logSuccess('OTP sent successfully to $cleanPhone');
      return {
        'success': true,
        'message': 'OTP sent successfully',
      };
    } on AuthException catch (e) {
      QuizzerLogger.logWarning('Phone authentication failed: ${e.message}');
      return {
        'success': false,
        'message': e.message,
      };
    } catch (e) {
      QuizzerLogger.logError('Unexpected error in signInWithPhone: $e');
      return {
        'success': false,
        'message': 'Unexpected error occurred',
      };
    }
  }

  /// Verifies the OTP for the phone number.
  /// On success, the user is logged in.
  Future<Map<String, dynamic>> verifyPhoneOtp(
      String phoneNumber, String token, SupabaseClient supabase) async {
    final cleanPhone = _sanitizePhoneNumber(phoneNumber);
    QuizzerLogger.logMessage('Verifying OTP for $cleanPhone');

    try {
      final response = await supabase.auth.verifyOTP(
        phone: cleanPhone,
        token: token,
        type: OtpType.sms,
      );

      if (response.user != null) {
        QuizzerLogger.logSuccess(
            'Phone authentication verify successful for $phoneNumber');

        // Ensure SessionManager knows about the role if possible,
        // essentially similar post-login logic might be needed here.
        // For now, we return the raw data.

        return {
          'success': true,
          'message': 'Login successful',
          'user': response.user!.toJson(),
          'session': response.session?.toJson(),
        };
      } else {
        return {
          'success': false,
          'message': 'Verification failed (no user returned)',
        };
      }
    } on AuthException catch (e) {
      QuizzerLogger.logWarning('OTP verification failed: ${e.message}');
      return {
        'success': false,
        'message': e.message,
      };
    } catch (e) {
      QuizzerLogger.logError('Unexpected error in verifyPhoneOtp: $e');
      return {
        'success': false,
        'message': 'Unexpected error occurred',
      };
    }
  }
}
