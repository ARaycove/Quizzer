import 'package:quizzer/backend_systems/database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quizzer/backend_systems/database_manager/tables/login_attempts_table.dart';
import 'package:quizzer/backend_systems/database_manager/tables/user_profile_table.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


void handleLoginAttempt(Map<String, dynamic> message) async {

    final email = message['email'] as String;
    final response = message['response'];

    QuizzerLogger.logMessage('Logging login attempt for: $email');
    
    final monitor = getDatabaseMonitor();
    Database? db;
    while (db == null) {
        db = await monitor.requestDatabaseAccess();
        if (db == null) {
            QuizzerLogger.logMessage('Database access denied, waiting...');
            await Future.delayed(const Duration(milliseconds: 100));
        }
    }
    QuizzerLogger.logMessage('Database access granted');
    
    try {
        // Get user ID if it exists
        final userId = await getUserIdByEmail(email, db);
        
        // Determine status code based on response type
        String statusCode;
        if (response is AuthResponse && response.user != null) {
            statusCode = 'success';
        } else if (response is AuthException) {
            statusCode = response.message;
        } else {
            statusCode = 'unknown_error';
        }

        // Add login attempt record
        await addLoginAttemptRecord(
            userId: userId ?? 'unknown_user',
            email: email,
            statusCode: statusCode,
            db: db
        );
        
        QuizzerLogger.logSuccess('Login attempt logged successfully');
    } catch (e) {
        QuizzerLogger.logError('Error logging login attempt: $e');
    } finally {
        monitor.releaseDatabaseAccess();
    }
}
