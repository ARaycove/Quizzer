import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final supabase = Supabase.instance.client;
const _secureStorage = FlutterSecureStorage();

Future<Map<String, dynamic>> authenticateUser(String email, String password) async {
  try {
    // Attempt to sign in with Supabase Auth
    final AuthResponse response = await supabase.auth.signInWithPassword(
      email: email,
      password: password
    );
    
    // If login successful, store authentication tokens for offline use
    if (response.session != null) {
      await _secureStorage.write(key: 'access_token', value: response.session!.accessToken);
      await _secureStorage.write(key: 'refresh_token', value: response.session!.refreshToken);
      await _secureStorage.write(key: 'user_email', value: email);
      await _secureStorage.write(key: 'user_id', value: response.user!.id);
      await _secureStorage.write(key: 'last_login_time', value: DateTime.now().toIso8601String());
      
      return {
        'success': true,
        'user_id': response.user!.id,
      };
    } else {
      return {
        'success': false,
        'error': 'Authentication failed: No session returned'
      };
    }
  } catch (e) {
    return {
      'success': false,
      'error': e.toString()
    };
  }
}