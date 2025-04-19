import 'package:quizzer/global/database/database_monitor.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';
import 'package:quizzer/global/database/tables/user_profile_table.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<bool> handleSignupInIsolate(Map<String, dynamic> message) async {
    final email = message['email'] as String;
    final username = message['username'] as String;
    final password = message['password'] as String;

    QuizzerLogger.logMessage('Starting user signup process');
    QuizzerLogger.logMessage('Email: $email, Username: $username');
    
    final monitor = getDatabaseMonitor();
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
            QuizzerLogger.logMessage('User already exists in database');
            monitor.releaseDatabaseAccess();
            return false;
        }

        QuizzerLogger.logMessage('Creating user profile in database');
        await createNewUserProfile(email, username, password, db);
        QuizzerLogger.logSuccess('User profile created successfully');
        monitor.releaseDatabaseAccess();
        return true;
    } catch (e) {
        QuizzerLogger.logError('Error in signup process: $e');
        return false;
    } finally {
        monitor.releaseDatabaseAccess();
    }
}
