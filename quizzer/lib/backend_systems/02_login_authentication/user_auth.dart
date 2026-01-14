import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'dart:async';
import 'package:hive/hive.dart';

/// Encapsulates all functionality relating to authorizing the user session, and the user's role
class UserAuth {
  /// Catches AuthException for known Supabase errors.
  /// On successful login, stores offline login data and initializes SessionManager.
  Future<Map<String, dynamic>> attemptSupabaseLogin(String emailOrPhone,
      String password, SupabaseClient supabase, Box storage) async {
    QuizzerLogger.logMessage(
        'Attempting Supabase authentication for $emailOrPhone');
    try {
      QuizzerLogger.logMessage('Attempting Supabase authentication');
      AuthResponse response;

      // Determine if input is Email or Phone
      if (emailOrPhone.contains('@')) {
        // Treat as Email
        response = await supabase.auth.signInWithPassword(
          email: emailOrPhone,
          password: password,
        );
      } else {
        // Treat as Phone
        final cleanPhone = _sanitizePhoneNumber(emailOrPhone);
        response = await supabase.auth.signInWithPassword(
          phone: cleanPhone,
          password: password,
        );
      }

      // Success Case
      QuizzerLogger.logSuccess(
          'Supabase authentication successful for $emailOrPhone');
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

  /// Sends an OTP to the specified phone number or email.
  /// Returns a map with success status and message.
  Future<Map<String, dynamic>> sendOtp(
      String contact, SupabaseClient supabase) async {
    final isEmail = contact.contains('@');
    final cleanContact = isEmail ? contact : _sanitizePhoneNumber(contact);
    QuizzerLogger.logMessage(
        'Attempting OTP authentication for $cleanContact (isEmail: $isEmail)');

    try {
      if (isEmail) {
        await supabase.auth.signInWithOtp(
          email: cleanContact,
          shouldCreateUser:
              false, // For password reset, we likely only want existing users, but setting true is safer for "magic link" style flows if we wanted that.
          // However, for password reset, we usually imply the user exists.
          // Supabase defaults to creating a user if they don't exist, which might be confusing for "Reset Password".
          // But effectively, if they don't exist, they claim the account now.
        );
      } else {
        await supabase.auth.signInWithOtp(
          phone: cleanContact,
        );
      }
      QuizzerLogger.logSuccess('OTP sent successfully to $cleanContact');
      return {
        'success': true,
        'message': 'OTP sent successfully',
      };
    } on AuthException catch (e) {
      QuizzerLogger.logWarning('OTP authentication failed: ${e.message}');
      return {
        'success': false,
        'message': e.message,
      };
    } catch (e) {
      QuizzerLogger.logError('Unexpected error in sendOtp: $e');
      return {
        'success': false,
        'message': 'Unexpected error occurred',
      };
    }
  }

  /// Verifies the OTP for the phone number or email.
  /// On success, the user is logged in.
  Future<Map<String, dynamic>> verifyOtp(
      String contact, String token, SupabaseClient supabase) async {
    final isEmail = contact.contains('@');
    final cleanContact = isEmail ? contact : _sanitizePhoneNumber(contact);
    QuizzerLogger.logMessage(
        'Verifying OTP for $cleanContact (isEmail: $isEmail)');

    try {
      final response = await supabase.auth.verifyOTP(
        email: isEmail ? cleanContact : null,
        phone: isEmail ? null : cleanContact,
        token: token,
        type: isEmail ? OtpType.email : OtpType.sms,
      );

      if (response.user != null) {
        QuizzerLogger.logSuccess(
            'OTP verification successful for $cleanContact');

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
      QuizzerLogger.logError('Unexpected error in verifyOtp: $e');
      return {
        'success': false,
        'message': 'Unexpected error occurred',
      };
    }
  }
}
