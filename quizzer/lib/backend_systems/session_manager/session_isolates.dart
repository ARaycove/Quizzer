import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile_table.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Spin up necessary processes and get userID from local profile, effectively intialize any session specific variables that should only be brought after successful login
Future<String?> initializeSession(Map<String, dynamic> data) async {
  final email = data['email'] as String;
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

    final userId = await getUserIdByEmail(email, db);

    QuizzerLogger.logSuccess('Session initialized with userId: $userId');
    monitor.releaseDatabaseAccess();
    return userId;
  } 
  
  catch (e) {
    QuizzerLogger.logError('Error initializing session: $e');
    monitor.releaseDatabaseAccess();
    return null;
  }
} 