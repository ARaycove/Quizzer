import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:hive/hive.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';

/// Stores offline login data in Hive storage
/// 
/// Stores a structured JSON object containing:
/// - last_sign_in_at: timestamp of last successful login
/// - user_id: user's unique identifier
/// - user_role: user's role/permissions
/// - offline_login_count: number of offline logins (starts at 0)
/// - last_online_sync: timestamp of last online sync
/// 
/// Note: Access tokens are NOT stored for security reasons
Future<void> storeOfflineLoginData(String email, Box storage, Map<String, dynamic> authResult) async {
  try {
    QuizzerLogger.logMessage('Storing offline login data for $email');
    
    final user = authResult['user'];
    
    // Get the local user profile UUID, not the Supabase user ID
    final localUserId = await getUserIdByEmail(email);
    
    final loginData = {
      'last_sign_in_at': user['last_sign_in_at'],
      'user_id': localUserId,
      'user_role': authResult['user_role'],
      'offline_login_count': 0,
      'last_online_sync': DateTime.now().toIso8601String(),
    };
    
    await storage.put(email, loginData);
    QuizzerLogger.logSuccess('Offline login data stored for $email');
  } catch (e) {
    QuizzerLogger.logError('Error storing offline login data for $email - $e');
    rethrow;
  }
}

/// Retrieves offline login data from Hive storage
/// 
/// Returns the structured JSON object or null if not found/invalid
Map<String, dynamic>? getOfflineLoginData(String email, Box storage) {
  try {
    QuizzerLogger.logMessage('Retrieving offline login data for $email');
    
    final data = storage.get(email);
    if (data is Map<String, dynamic>) {
      QuizzerLogger.logMessage('Offline login data found for $email');
      return data;
    }
    
    QuizzerLogger.logMessage('No valid offline login data found for $email');
    return null;
  } catch (e) {
    QuizzerLogger.logError('Error retrieving offline login data for $email - $e');
    return null;
  }
}

/// Checks Hive storage for a recent offline login and updates results accordingly
/// 
/// Validates if the last login was within 30 days and returns appropriate results
/// Note: Offline login does NOT provide Supabase access - user must re-authenticate for online features
Map<String, dynamic> checkOfflineLogin(String email, Box storage, Map<String, dynamic> currentResults) {
  try {
    QuizzerLogger.logMessage('Checking for offline login data for $email');
    Map<String, dynamic> updatedResults = Map.from(currentResults);
    
    // Always initialize offline_mode to false
    updatedResults['offline_mode'] = false;

    final loginData = getOfflineLoginData(email, storage);
    if (loginData != null) {
      final lastSignInAt = loginData['last_sign_in_at'] as String;
      final lastLogin = DateTime.parse(lastSignInAt);
      final today = DateTime.now();
      final difference = today.difference(lastLogin).inDays;

      QuizzerLogger.logMessage('Last login for $email was $difference days ago');
      
      if (difference <= 30) {
        QuizzerLogger.logMessage('Recent offline login detected for $email');
        
        // Increment offline login count
        final currentCount = loginData['offline_login_count'] as int? ?? 0;
        loginData['offline_login_count'] = currentCount + 1;
        storage.put(email, loginData);
        
        updatedResults = {
          'success': true,
          'message': 'offline_login',
          'user_id': loginData['user_id'],
          'user_role': loginData['user_role'],
          'offline_login_count': loginData['offline_login_count'],
          'offline_mode': true, // Flag to indicate offline mode
        };
      } else {
        QuizzerLogger.logMessage('Offline login data found but expired for $email');
        updatedResults['message'] = 'Offline login expired. Please connect and log in online.';
        // offline_mode remains false
      }
    } else {
      QuizzerLogger.logMessage('No valid offline login data found for $email');
      // Keep the original error message from the Supabase failure
      // offline_mode remains false
    }
    
    return updatedResults;
  } catch (e) {
    QuizzerLogger.logError('Error checking offline login for $email - $e');
    rethrow;
  }
}

/// Clears offline login data for a specific user
/// 
/// Removes all stored login data for the given email
Future<void> clearOfflineLoginData(String email, Box storage) async {
  try {
    QuizzerLogger.logMessage('Clearing offline login data for $email');
    await storage.delete(email);
    QuizzerLogger.logSuccess('Offline login data cleared for $email');
  } catch (e) {
    QuizzerLogger.logError('Error clearing offline login data for $email - $e');
    rethrow;
  }
}
