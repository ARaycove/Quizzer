import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/outbound_sync/outbound_sync_functions.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:supabase/supabase.dart';

Future<bool> createLocalUserProfile(Map<String, dynamic> message) async {
    try {
        final email = message['email'] as String;
        final username = message['username'] as String;

        QuizzerLogger.logMessage('Starting local user profile creation');
        QuizzerLogger.logMessage('Email: $email, Username: $username');
        
        // Delegate creation logic (including duplicate check) to createNewUserProfile
        // The table function handles its own database access internally
        // If it fails unexpectedly, it will throw (Fail Fast)
        // If user exists, it returns false.
        // If creation succeeds, it returns true.
        final bool creationResult = await createNewUserProfile(email, username);
        
        QuizzerLogger.logMessage('Local user profile creation completed with result: $creationResult');
        return creationResult;
    } catch (e) {
        QuizzerLogger.logError('Error creating local user profile - $e');
        rethrow;
    }
}

Future<Map<String, dynamic>> handleNewUserProfileCreation(Map<String, dynamic> message, SupabaseClient supabase) async {
    try {
        final email = message['email'] as String;
        final password = message['password'] as String;
        final username = message['username'] as String;

        QuizzerLogger.logMessage('Starting new user profile creation process');
        QuizzerLogger.logMessage('Email: $email');
        QuizzerLogger.logMessage('Received message map: $message');

        Map<String, dynamic> results = {};

        try {
            QuizzerLogger.logMessage('Attempting Supabase signup with email: $email');
            final response = await supabase.auth.signUp(
                email: email,
                password: password,
            );



            QuizzerLogger.logMessage('Supabase signup response received: ${response.user != null ? 'User created' : 'No user returned'}');
            
            // If Supabase signup is successful, create local user profile and sync to Supabase
            if (response.user != null) {
                final bool localProfileCreated = await createLocalUserProfile({
                    'email': email,
                    'username': username,
                });
                
                if (localProfileCreated) {
                    // Authenticate with Supabase to get session token for sync
                    QuizzerLogger.logMessage('Authenticating with Supabase for profile sync');
                    try {
                        final authResponse = await supabase.auth.signInWithPassword(
                            email: email,
                            password: password,
                        );

                        
                        if (authResponse.user != null && authResponse.session != null) {
                            QuizzerLogger.logMessage('Authentication successful, syncing user profile to Supabase');
                            
                            // Set SessionManager user state so syncUserProfiles can work
                            final sessionManager = getSessionManager();
                            sessionManager.userId = await getUserIdByEmail(email);
                            sessionManager.userEmail = email;
                            sessionManager.userLoggedIn = true;
                            
                            // Now sync the profile using the existing outbound sync function
                            await syncUserProfiles();
                            
                            QuizzerLogger.logSuccess('User profile successfully synced to Supabase');
                            
                            // Clean up SessionManager state since we're not actually logging in
                            sessionManager.userId = null;
                            sessionManager.userEmail = null;
                            sessionManager.userLoggedIn = false;
                            
                            results = {
                                'success': true,
                                'message': 'User registered successfully with Supabase and local database',
                                'user': response.user?.toJson(),
                                'session': response.session?.toJson(),
                            };
                        } else {
                            QuizzerLogger.logError('Authentication failed after account creation');
                            results = {
                                'success': false,
                                'message': 'User created but authentication failed for sync',
                            };
                        }
                    } catch (e) {
                        QuizzerLogger.logError('Error during authentication and sync: $e');
                        results = {
                            'success': false,
                            'message': 'User created but sync failed: $e',
                        };
                    }
                } else {
                    // Local profile creation failed (likely duplicate user)
                    results = {
                        'success': false,
                        'message': 'User already exists in local database',
                    };
                }
            } else {
                results = {
                    'success': false,
                    'message': 'Supabase signup failed - no user returned',
                };
            }
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


Future<Map<String, dynamic>> handleResetPssword(Map<String, dynamic> message, SupabaseClient supabase) async {
    try {
        final email = message['email'] as String;
        final password = message['password'] as String;
        // final username = message['username'] as String; //TODO Username is not implemented

        QuizzerLogger.logMessage('Starting reset password process');
        QuizzerLogger.logMessage('Email: $email');
        QuizzerLogger.logMessage('Received message map: $message');

        Map<String, dynamic> results = {};

        try {
            QuizzerLogger.logMessage('Attempting Supabase password reset with email: $email');
            final response = await supabase.auth.updateUser(
                UserAttributes(
                    password: password,
                ),
            );



            QuizzerLogger.logMessage('Supabase password reset response received: ${response.user != null ? 'User updated' : 'No user returned'}');

        } on AuthException catch (e) {
            // If Supabase returns an authentication error, capture it.
            QuizzerLogger.logError('Supabase AuthException during password reset: ${e.message}');
            results = {
                'success': false,
                'message': e.message // Return the specific error from Supabase
            };
            // Return immediately as signup failed.
            return results;
        } // End of allowed try-catch block

        return results;
    } catch (e) {
        QuizzerLogger.logError('Error in handleResetPssword - $e');
        rethrow;
    }
}
