import 'package:quizzer/backend_systems/00_database_manager/tables/login_attempts_table.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';


/// Records a login attempt in the database
/// 
/// This function records the login attempt using the addLoginAttemptRecord function
/// 
/// Any errors will propagate to the caller.
Future<void> recordLoginAttempt({
  required String email,
  required String statusCode,
}) async {
  try {
    QuizzerLogger.logMessage("Recording login Attempt $email with result $statusCode");
    
    // Record the login attempt - the table function handles its own database access
    await addLoginAttemptRecord(
      email: email,
      statusCode: statusCode,
    );
      
    QuizzerLogger.logMessage('Login attempt recorded for user: $email with status: $statusCode');
  } catch (e) {
    QuizzerLogger.logError('Error recording login attempt for user: $email - $e');
    rethrow;
  }
}

