import 'package:flutter/foundation.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

// ==========================================
// Global Critical Error Handling
// ==========================================

class CriticalErrorDetails {
  final String message;
  final dynamic error; // The original error/exception
  final StackTrace? stackTrace;

  CriticalErrorDetails({
    required this.message,
    this.error,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'CriticalErrorDetails(message: $message, error: $error, stackTrace: $stackTrace)';
  }
}

// --- Notifier and Reporter ---

/// Notifier for signaling a global critical error to the UI.
final ValueNotifier<CriticalErrorDetails?> globalCriticalErrorNotifier =
    ValueNotifier<CriticalErrorDetails?>(null);

/// Reports a critical error, updating the global notifier and logging the error.
/// This should be called by global error handlers or by specific services
/// when an unrecoverable error occurs.
void reportCriticalError(String message, {dynamic error, StackTrace? stackTrace}) {
  final details = CriticalErrorDetails(
    message: message,
    error: error,
    stackTrace: stackTrace,
  );

  // Format error and stackTrace into the log message for QuizzerLogger
  String logMessage = 'CRITICAL ERROR REPORTED TO UI: $message';
  if (error != null) {
    logMessage += '\nError: ${error.toString()}';
  }
  if (stackTrace != null) {
    logMessage += '\nStackTrace: ${stackTrace.toString()}';
  }
  QuizzerLogger.logError(logMessage);

  globalCriticalErrorNotifier.value = details;
} 