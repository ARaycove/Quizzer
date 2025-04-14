// TODO: Implement logging for the quizzer app

// Logger should follow functional programming paradigm

// Logger should be able to log messages at different levels taking a parameter for the log level

// Instead of print statements, use the logger. The purpose of the logger is provide a more structured way to log messages.

// Logger should have discrete log functions for the following:
// 1. logging values
// 2. Logging general messages
// 3. Logging errors
// 4. Logging warnings (which should be treated as errors)
// 5. Logging success messages
// 6. Logging a main header
// 7. Logging a subheader
// 8. Logging a divider (should be a horizontal line)

import 'dart:io';

// Log levels enum for type safety
enum LogLevel {
  debug,
  info,
  success,
  warning,
  error,
}

// Logger class following functional programming principles
class QuizzerLogger {
  // Private constructor to prevent instantiation
  QuizzerLogger._();

  // ANSI color codes for terminal output
  static const String _reset = '\x1B[0m';
  static const String _red = '\x1B[31m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _blue = '\x1B[34m';
  static const String _magenta = '\x1B[35m';
  static const String _cyan = '\x1B[36m';

  // Pure function to format timestamp
  static String _getTimestamp() {
    final now = DateTime.now();
    return '[${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}]';
  }

  // Pure function to format log message
  static String _formatMessage(LogLevel level, String message) {
    final timestamp = _getTimestamp();
    switch (level) {
      case LogLevel.debug:
        return '$timestamp $_cyan[DEBUG]$_reset $message';
      case LogLevel.info:
        return '$timestamp $_blue[INFO]$_reset $message';
      case LogLevel.success:
        return '$timestamp $_green[SUCCESS]$_reset $message';
      case LogLevel.warning:
        return '$timestamp $_yellow[WARNING]$_reset $message';
      case LogLevel.error:
        return '$timestamp $_red[ERROR]$_reset $message';
    }
  }

  // Logging functions
  static void logValue(String message) {
    stdout.writeln(_formatMessage(LogLevel.debug, message));
  }

  static void logMessage(String message) {
    stdout.writeln(_formatMessage(LogLevel.info, message));
  }

  static void logError(String message) {
    stderr.writeln(_formatMessage(LogLevel.error, message));
  }

  static void logWarning(String message) {
    stderr.writeln(_formatMessage(LogLevel.warning, message));
  }

  static void logSuccess(String message) {
    stdout.writeln(_formatMessage(LogLevel.success, message));
  }

  // Formatting functions
  static void printHeader(String message) {
    stdout.writeln('\n$_magenta$message$_reset\n');
  }

  static void printSubheader(String message) {
    stdout.writeln('\n$_cyan$message$_reset\n');
  }

  static void printDivider() {
    stdout.writeln('${_blue}${'-' * 80}$_reset');
  }
}


