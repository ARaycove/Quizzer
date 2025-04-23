import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile_table.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase/supabase.dart';

// TODO find the function that handles sign up through supabase and place herre in this file, since it's part of the account creation sub-system

// I found the function, and it doesn't exist, we need a function here that first takes email, username, and password and attempts to create a signup with Supabase
// We either get an AuthException or AuthResponse
// If AuthException it means the user already exists, otherwise we we're successful in registering. It's not a null response

// We will record results and return them only at the end

// After we get a response (either the profile exists or it doesn't)
// Run the createLocalUserProfile below, to ensure that we also create the profile record locally.

// return all results

// Finally we need to update the session manager createNewUserAccount function to user this master function

Future<bool> createLocalUserProfile(Map<String, dynamic> message, DatabaseMonitor monitor) async {
    final email = message['email'] as String;
    final username = message['username'] as String;

    QuizzerLogger.logMessage('Starting local user profile creation');
    QuizzerLogger.logMessage('Email: $email, Username: $username');
    
    Database? db;
    // Acquire DB access
    while (db == null) {
        db = await monitor.requestDatabaseAccess();
        if (db == null) {
            QuizzerLogger.logMessage('Database access denied, waiting...');
            await Future.delayed(const Duration(milliseconds: 100));
        }
    }
    QuizzerLogger.logMessage('Database access granted');
    
    // Delegate creation logic (including duplicate check) to createNewUserProfile
    // If it fails unexpectedly, it will throw (Fail Fast)
    // If user exists, it returns false.
    // If creation succeeds, it returns true.
    final bool creationResult = await createNewUserProfile(email, username, db);
    
    // Release DB access *after* the operation completes or returns a non-fatal result
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Database access released');

    // Return the result from the creation attempt
    return creationResult;
}

Future<Map<String, dynamic>> handleNewUserProfileCreation(Map<String, dynamic> message, SupabaseClient supabase, DatabaseMonitor monitor) async {
    final email = message['email'] as String;
    final password = message['password'] as String;

    QuizzerLogger.logMessage('Starting new user profile creation process');
    QuizzerLogger.logMessage('Email: $email');

    Map<String, dynamic> results = {};
    
    // Acquire DB Access
    Database? db;
    while (db == null) {
        db = await monitor.requestDatabaseAccess();
        if (db == null) {
            QuizzerLogger.logMessage('Database access denied, waiting...');
            await Future.delayed(const Duration(milliseconds: 100));
        }
    }
    // try {
        // Check for duplicates locally *before* trying Supabase signup
        final duplicateCheck = await verifyNonDuplicateProfile(email, message['username'] as String, db);
        if (!duplicateCheck['isValid']) {
            results = {
                'success': false,
                'message': duplicateCheck['message']
            };
            monitor.releaseDatabaseAccess();
            return results;
        }
        
        // If no duplicates, release DB for now
        monitor.releaseDatabaseAccess();
    // TODO Integrate with central DB, check record in cloud if it exists before attempting signUp

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
    final resultTwo = await createLocalUserProfile(message, monitor);
    if (!resultTwo) {
        results = {
            'success': false,
            'message': 'Failed to create local user profile'
        };
        return results;
    }

    return results;
}
