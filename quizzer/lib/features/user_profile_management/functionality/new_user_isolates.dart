import 'dart:isolate';
import 'package:quizzer/global/database/database_monitor.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';
import 'package:quizzer/global/database/tables/user_profile_table.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void handleSignupInIsolate(Map<String, dynamic> message) async {
    final sendPort = message['sendPort'] as SendPort;
    final email = message['email'] as String;
    final username = message['username'] as String;
    final password = message['password'] as String;

    QuizzerLogger.logMessage('Starting user signup process');
    QuizzerLogger.logMessage('Email: $email, Username: $username');
    
    Database? db;
    // Wait for Access from the monitor
    QuizzerLogger.logMessage('Requesting database access');
    while (db == null) {
        db = await DatabaseMonitor().requestDatabaseAccess();
        if (db == null) {
            QuizzerLogger.logMessage('Database access denied, waiting...');
            await Future.delayed(const Duration(milliseconds: 100));
        }
    }
    QuizzerLogger.logMessage('Database access granted');
    
    final userExists = await getUserIdByEmail(email, db);
    if (userExists != null) {
        QuizzerLogger.logMessage('User already exists in database');
        sendPort.send(false);
        DatabaseMonitor().releaseDatabaseAccess();
        Isolate.exit();
    }

    QuizzerLogger.logMessage('Creating user profile in database');
    await createNewUserProfile(email, username, password, db);
    QuizzerLogger.logSuccess('User profile created successfully');
    
    QuizzerLogger.logMessage('Sending result and terminating isolate');
    sendPort.send(true);
    DatabaseMonitor().releaseDatabaseAccess();
    Isolate.exit();
}
