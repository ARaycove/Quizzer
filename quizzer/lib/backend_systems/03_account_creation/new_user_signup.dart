import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
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

        QuizzerLogger.logMessage('Starting new user profile creation process');
        QuizzerLogger.logMessage('Email: $email');

        Map<String, dynamic> results = {};
        
        // TODO: Check for duplicates locally *before* trying Supabase signup
        // This will need to be implemented in the user profile table functions
        // For now, we'll proceed with Supabase signup and let the table function handle duplicates

        // Sign up with supabase
        // NOTE: This try-catch is an ALLOWED EXCEPTION to the no-try-catch rule.
        // It specifically catches AuthException from the external Supabase service.
        // This is necessary to handle predictable signup failures (e.g., email already exists)
        // reported by the external service, allowing the app to return a meaningful
        // error message to the user instead of crashing.
        try {
            final response = await supabase.auth.signUp(
                email: email,
                password: password,
            );
            // If signup is successful, store success results
            results = {
                'success': true,
                'message': 'User registered successfully with Supabase',
                'user': response.user?.toJson(),
                'session': response.session?.toJson(),
            };
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

        // Create the local profile ONLY if Supabase signup succeeded
        final resultTwo = await createLocalUserProfile(message);
        if (!resultTwo) {
            results = {
                'success': false,
                'message': 'Failed to create local user profile'
            };
            return results;
        }

        return results;
    } catch (e) {
        QuizzerLogger.logError('Error in handleNewUserProfileCreation - $e');
        rethrow;
    }
}
