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
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p; // Import path package for basename

// Log levels enum for type safety
enum LogLevel {
  debug,
  info,
  success,
  warning,
  error,
}

// Logger class using the standard logging package
class QuizzerLogger {
  // Private constructor to prevent instantiation
  QuizzerLogger._();

  // Create a logger instance
  static final _logger = Logger('QuizzerApp');
  static IOSink? _logFileSink; // Sink for writing to file
  static const String _logFileName = 'quizzer_log.txt';
  static const String _logDir = 'runtime_cache';

  // --- Source Filtering --- 
  static List<String> _excludedSources = [
    "user_question_processes.dart",
    "user_profile_table.dart",
    "database_monitor.dart",
    "question_answer_pairs_table.dart",
    "login_attempts_table.dart",
    "login_attempts_record.dart",
    "session_manager.dart",
    "circulation_worker.dart",
    "question_queue_monitor.dart",
    "module_updates_process.dart",
    "modules_table.dart",
    "module_isolates.dart",
    "answered_history_monitor.dart",
    "user_question_answer_pairs_table.dart",
    "module_inactive_cache.dart",
    "session_toggle_scheduler.dart",
    "unprocessed_cache.dart",
    "past_due_cache.dart"
  ]; // List of source filenames to exclude

  /// Sets the list of source filenames (e.g., 'my_table.dart') to exclude from logging.
  static void setExcludedSources(List<String> sources) {
    _excludedSources = sources;
    // Optional: Log the change (but respect exclusion potentially)
    final source = _getCallerInfo();
    if (!_excludedSources.contains(source)) {
      _logger.info('[$source] Logger exclusion list updated: $_excludedSources');
    }
  }
  // ----------------------

  // ANSI color codes for terminal output (can be used in listener)
  static const String _reset = '\x1B[0m';
  static const String _red = '\x1B[31m';
  // static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _blue = '\x1B[34m';
  static const String _magenta = '\x1B[35m';
  static const String _cyan = '\x1B[36m';

  // Helper to format timestamp (can be used in listener)
  static String _getTimestamp(DateTime time) {
    return '[${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}]';
  }

  // --- New Helper to Get Caller Info --- 
  static String _getCallerInfo() {
    // Removed try-catch to adhere to Fail Fast principle.
    // Errors during stack trace parsing will now propagate.
    final traceString = StackTrace.current.toString();
    final lines = traceString.split('\n');
    // Find the first frame outside the logger itself
    // Start search from index 2 to skip StackTrace.current and _getCallerInfo frames
    for (int i = 2; i < lines.length; i++) {
      final line = lines[i];
      if (!line.contains('quizzer_logging.dart')) {
        // Attempt to extract the file path/name from the frame
        // This parsing is brittle and might need adjustment
        final match = RegExp(r'\(([^\)]+\.dart):\d+:\d+\)').firstMatch(line);
        if (match != null && match.groupCount >= 1) {
          // Use basename to get just the file name
          return p.basename(match.group(1)!);
        } else {
           // Fallback parsing for different formats if needed
           // Or just return the line if parsing fails
           return line.trim(); // Return the raw line as fallback
        }
      }
    }
    // If no suitable frame is found outside the logger, return default.
    // This scenario might indicate an issue or unexpected stack structure.
    return 'UnknownSource'; 
  }
  // -------------------------------------

  // Configure the root logger (call this from main.dart)
  static void setupLogging({Level level = Level.INFO}) {
    Logger.root.level = level; // Set desired log level
    Logger.root.onRecord.listen((record) {
      // Custom formatting matching the old style
      String levelColor;
      String levelName = record.level.name;
      switch (record.level) {
        case Level.FINE:
        case Level.FINER:
        case Level.FINEST:
          levelColor = _cyan; 
          levelName = 'DEBUG'; // Map FINE levels to DEBUG
          break;
        case Level.INFO:
          levelColor = _blue;
          break;
        case Level.CONFIG: // Treat config like info for color
           levelColor = _blue;
           levelName = 'INFO';
           break;
        case Level.WARNING:
          levelColor = _yellow;
          break;
        case Level.SEVERE:
          levelColor = _red;
          levelName = 'ERROR'; // Map SEVERE to ERROR
          break;
        case Level.SHOUT: // Treat shout like severe/error
           levelColor = _red;
           levelName = 'ERROR';
           break;
        default:
          levelColor = _reset; // Default to no color
      }
      
      final timestamp = _getTimestamp(record.time);
      // Create the core formatted message (timestamp, level, message)
      final coreFormattedMessage = '$timestamp $levelColor[$levelName]$_reset ${record.message}';

      // Prepend "Quizzer:" before printing
      print("Quizzer: $coreFormattedMessage"); // print allows logs to be shown when testing on Android

      // --- Log to File --- 
      if (_logFileSink != null) {
        _logFileSink!.writeln("Quizzer: $coreFormattedMessage");
      }
      // ------------------
    });
    // Use the logger itself for the initialization message now
    logMessage('QuizzerLogger initialized with level: ${level.name}'); 

    // --- File Setup --- 
    final String logFilePath = p.join(_logDir, _logFileName);
    // Ensure directory exists
    final Directory dir = Directory(_logDir);
    if (!dir.existsSync()) {
      print('Quizzer: Creating log directory: $_logDir'); // Use print before logger is fully ready
      dir.createSync(recursive: true);
    }
    // Open file sink in write mode (overwrites existing file)
    // Errors opening file will now crash (Fail Fast)
    _logFileSink = File(logFilePath).openWrite(mode: FileMode.write);
    print('Quizzer: Logging to file: $logFilePath');
    // ----------------
  }

  // Logging functions using the standard logger
  static void logValue(String message) {
    final source = _getCallerInfo();
    if (_excludedSources.contains(source)) return; // Check exclusion
    _logger.fine('[$source] $message'); // Map logValue to FINE level (like DEBUG)
  }

  static void logMessage(String message) {
    final source = _getCallerInfo();
    if (_excludedSources.contains(source)) return; // Check exclusion
    _logger.info('[$source] $message');
  }

  static void logError(String message) {
    final source = _getCallerInfo();
    if (_excludedSources.contains(source)) return; // Check exclusion
    _logger.severe('[$source] $message'); // Map logError to SEVERE level
  }

  static void logWarning(String message) {
    final source = _getCallerInfo();
    if (_excludedSources.contains(source)) return; // Check exclusion
    _logger.warning('[$source] $message');
  }

  static void logSuccess(String message) {
    final source = _getCallerInfo();
    if (_excludedSources.contains(source)) return; // Check exclusion
    _logger.info('[$source] SUCCESS: $message'); // Use INFO level for success
  }

  // Formatting functions (kept separate, still using stdout)
  static void printHeader(String message) {
    stdout.writeln('\n$_magenta$message$_reset\n');
  }

  static void printSubheader(String message) {
    stdout.writeln('\n$_cyan$message$_reset\n');
  }

  static void printDivider() {
    stdout.writeln('$_blue${'-' * 80}$_reset');
  }

  static Future<void> dispose() async {
    if (_logFileSink != null) {
      await _logFileSink!.flush();
      await _logFileSink!.close();
      print('Quizzer: Log file sink closed.');
      _logFileSink = null;
    }
  }
}


