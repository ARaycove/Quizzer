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
    final password = message['password'] as String;

    QuizzerLogger.logMessage('Starting local user profile creation');
    QuizzerLogger.logMessage('Email: $email, Username: $username');
    
    Database? db;
    try {
        while (db == null) {
            db = await monitor.requestDatabaseAccess();
            if (db == null) {
                QuizzerLogger.logMessage('Database access denied, waiting...');
                await Future.delayed(const Duration(milliseconds: 100));
            }
        }
        QuizzerLogger.logMessage('Database access granted');
        
        final userExists = await getUserIdByEmail(email, db);
        if (userExists != null) {
            QuizzerLogger.logMessage('User already exists in database with ID: $userExists');
            monitor.releaseDatabaseAccess();
            return false;
        }

        QuizzerLogger.logMessage('Creating new user profile in database');
        await createNewUserProfile(email, username, password, db);
        QuizzerLogger.logSuccess('User profile created successfully');
        monitor.releaseDatabaseAccess();
        return true;
    } catch (e) {
        QuizzerLogger.logError('Error in local profile creation: $e');
        return false;
    } finally {
        monitor.releaseDatabaseAccess();
    }
}

Future<Map<String, dynamic>> handleNewUserProfileCreation(Map<String, dynamic> message, SupabaseClient supabase, DatabaseMonitor monitor) async {
    final email = message['email'] as String;
    final password = message['password'] as String;

    QuizzerLogger.logMessage('Starting new user profile creation process');
    QuizzerLogger.logMessage('Email: $email');

    Map<String, dynamic> results = {};
    
    // Check for existing user and username
    Database? db;

    try {
        while (db == null) {
            db = await monitor.requestDatabaseAccess();
            if (db == null) {
                QuizzerLogger.logMessage('Database access denied, waiting...');
                await Future.delayed(const Duration(milliseconds: 100));
            }
        }
        final duplicateCheck = await verifyNonDuplicateProfile(email, message['username'] as String, db);
        if (!duplicateCheck['isValid']) {
            results = {
                'success': false,
                'message': duplicateCheck['message']
            };
            monitor.releaseDatabaseAccess();
            return results;
        }
        
        monitor.releaseDatabaseAccess();
    } catch (e) {
        QuizzerLogger.logError('Error checking existing users: $e');
        monitor.releaseDatabaseAccess();
        results = {
            'success': false,
            'message': 'Error checking existing users'
        };
        return results;
    }
    // TODO Integrate with central DB, check record in cloud if it exists before attempting signUp

    // Sign up with supabase
    try {
        final response = await supabase.auth.signUp(
            email: email,
            password: password,
        );
        results = {
            'success': true,
            'message': 'User registered successfully with Supabase',
            'user': response.user?.toJson(),
            'session': response.session?.toJson(),
        };
    } on AuthException catch (e) {
        results = {
            'success': false,
            'message': e.message
        };
        return results;
    }

    // Create the local profile
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
