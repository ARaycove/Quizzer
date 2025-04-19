import 'package:quizzer/global/database/database_monitor.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';
import 'package:quizzer/global/database/tables/user_profile_table.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<String?> handleSessionInitialization(Map<String, dynamic> data) async {
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
    if (userId == null) {
      throw Exception('No user found with email: $email');
    }
    QuizzerLogger.logSuccess('Session initialized with userId: $userId');
    monitor.releaseDatabaseAccess();
    return userId;
  } catch (e) {
    QuizzerLogger.logError('Error initializing session: $e');
    monitor.releaseDatabaseAccess();
    return null;
  }
} 