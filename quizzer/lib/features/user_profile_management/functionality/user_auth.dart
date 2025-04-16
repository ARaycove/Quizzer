// TODO: Add proper error handling for network operations
// TODO: Implement proper logging for authentication failures
// TODO: Add rate limiting for authentication attempts

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quizzer/features/user_profile_management/database/user_profile_table.dart';

final supabase = Supabase.instance.client;
const _secureStorage = FlutterSecureStorage();
const _offlineLoginThresholdDays = 30; // FIXME: Should be a user preference

// ==========================================
// Functions
// ------------------------------------------
// Authenticate User with Supabase
Future<Map<String, dynamic>> authenticateUser(String email, String password) async {
    try {
        // 1. Attempt online authentication
        final AuthResponse onlineAuthResponse = await supabase.auth.signInWithPassword(
            email: email,
            password: password,
        );

    if (onlineAuthResponse.session != null) {
      // Online authentication successful, store tokens
      String timeStamp = DateTime.now().toIso8601String();
      await _secureStorage.write(key: 'access_token', value: onlineAuthResponse.session!.accessToken);
      await _secureStorage.write(key: 'refresh_token', value: onlineAuthResponse.session!.refreshToken);
      await _secureStorage.write(key: 'user_email', value: email);
      await _secureStorage.write(key: 'user_id', value: onlineAuthResponse.user!.id);
      await _secureStorage.write(key: 'last_login_time', value: timeStamp);
      await updateLastLogin(
        timeStamp, email
        );
// 
      return {
        'success': true,
        'user_id': onlineAuthResponse.user!.id,
        'response': onlineAuthResponse.session.toString(),
      };
    } else {
      // Online authentication failed (likely invalid credentials)
      return {
        'success': false,
        'error': onlineAuthResponse.session ?? 'Authentication failed',
      };
    }
  } catch (e) {
    // 2. Online authentication failed with an exception (likely network issue)
    // Check for offline fallback
    final storedEmail = await _secureStorage.read(key: 'user_email');
    final storedAccessToken = await _secureStorage.read(key: 'access_token');
    final lastLoginTimeStr = await _secureStorage.read(key: 'last_login_time');

    if (storedEmail == email && storedAccessToken != null && lastLoginTimeStr != null) {
      final lastLoginTime = DateTime.tryParse(lastLoginTimeStr);
      if (lastLoginTime != null &&
          DateTime.now().difference(lastLoginTime).inDays <= _offlineLoginThresholdDays) {
        // Allow login with stored access token
        return {
          'success': true,
          'user_id': await _secureStorage.read(key: 'user_id'),
          'offline': true, // Indicate it's an offline login
          'response': "offline_login"
        };
      }
    }

    // 3. No valid offline fallback after the exception
    return {
      'success': false,
      'error': 'Network error during authentication', // Generic error for network issues
    };
  }
}

// ------------------------------------------
// Register User with Supabase
Future<Map<String, dynamic>> registerUserWithSupabase(String email, String password) async {
  try {
    // Register user with Supabase Auth
    final AuthResponse response = await supabase.auth.signUp(
      email: email,
      password: password
    );
    
    // Return success with user ID if registration was successful
    if (response.user != null) {
      return {
        'success': true,
        'user_id': response.user!.id,
        'session': response.session
      };
    } else {
      return {
        'success': false,
        'error': 'Registration failed: No user returned'
      };
    }
  } catch (e) {
    // Return error information if registration failed
    return {
      'success': false,
      'error': e.toString()
    };
  }
}