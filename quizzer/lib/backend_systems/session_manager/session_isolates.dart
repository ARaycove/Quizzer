import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile_table.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Spin up necessary processes and get userID from local profile, effectively intialize any session specific variables that should only be brought after successful login
Future<String?> initializeSession(Map<String, dynamic> data) async {
  final email = data['email'] as String;
  QuizzerLogger.logMessage("Recorded email to log in. . .: $email");
  final monitor = getDatabaseMonitor();
  Database? db;
  db = await monitor.requestDatabaseAccess();

  QuizzerLogger.logMessage('Database access granted');

  final userId = await getUserIdByEmail(email, db!);

  QuizzerLogger.logSuccess('Session initialized with userId: $userId');
  monitor.releaseDatabaseAccess();
  return userId;
} 