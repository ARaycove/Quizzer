import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/login_attempts_table.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';


/// Records a login attempt in the database
/// 
/// This function gets access from the database monitor and then records
/// the login attempt using the addLoginAttemptRecord function.
/// 
/// Returns true if the login attempt was successfully recorded.
/// Any errors will propagate to the caller.
Future<void> recordLoginAttempt({
  required String email,
  required String statusCode,
}) async {
  QuizzerLogger.logMessage("Recording login Attempt $email with result $statusCode");
  final DatabaseMonitor monitor = getDatabaseMonitor();
  
  // Request access to the database

  Database? db;
  while (db == null) {
      db = await monitor.requestDatabaseAccess();
      if (db == null) {
          QuizzerLogger.logMessage('Database access denied, waiting...');
          await Future.delayed(const Duration(milliseconds: 100));
      }
  }

  // Record the login attempt
  await addLoginAttemptRecord(
    email: email,
    statusCode: statusCode,
    db: db,
  );
    
  QuizzerLogger.logMessage('Login attempt recorded for user: $email with status: $statusCode');
  monitor.releaseDatabaseAccess();    
}

