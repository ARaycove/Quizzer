import 'package:path/path.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

/// Returns the full path to the Quizzer SQLite database, creating directories as needed.
Future<String> getQuizzerDatabasePath() async {
  Directory baseDir;
  try {
  if (Platform.isAndroid || Platform.isIOS) {
    baseDir = await getApplicationDocumentsDirectory();
    QuizzerLogger.logMessage('[PATH] Using mobile documents directory: ${baseDir.path}');
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    baseDir = await getApplicationSupportDirectory();
    QuizzerLogger.logMessage('[PATH] Using application support directory for desktop: ${baseDir.path}');
  } else {
    QuizzerLogger.logWarning('[PATH] Unsupported platform or environment, defaulting to current directory.');
      baseDir = Directory('.');
    }
  } catch (e) {
    // Fallback for test environment where path_provider is not available
    QuizzerLogger.logMessage('[PATH] Path provider not available (likely test environment), using current directory.');
    baseDir = Directory('.');
  }
  final Directory appDir = Directory(join(baseDir.path, 'QuizzerApp', 'sqlite'));
  if (!await appDir.exists()) {
    await appDir.create(recursive: true);
  }
  final String dbPath = join(appDir.path, 'quizzer.db');
  QuizzerLogger.logMessage('[PATH] Quizzer database path: $dbPath');
  return dbPath;
}

/// Returns the full path to the QuizzerMedia directory for storing final media assets.
/// Creates directories as needed and handles platform-specific paths consistently.
Future<String> getQuizzerMediaPath() async {
  Directory baseDir;
  try {
  if (Platform.isAndroid || Platform.isIOS) {
    baseDir = await getApplicationDocumentsDirectory();
    QuizzerLogger.logMessage('[PATH] Using mobile documents directory for media: ${baseDir.path}');
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    baseDir = await getApplicationSupportDirectory();
    QuizzerLogger.logMessage('[PATH] Using application support directory for desktop media: ${baseDir.path}');
  } else {
    QuizzerLogger.logWarning('[PATH] Unsupported platform for media, defaulting to current directory.');
      baseDir = Directory('.');
    }
  } catch (e) {
    // Fallback for test environment where path_provider is not available
    QuizzerLogger.logMessage('[PATH] Path provider not available (likely test environment), using current directory for media.');
    baseDir = Directory('.');
  }
  final Directory mediaDir = Directory(join(baseDir.path, 'QuizzerAppMedia', 'question_answer_pair_assets'));
  if (!await mediaDir.exists()) {
    await mediaDir.create(recursive: true);
  }
  final String mediaPath = mediaDir.path;
  QuizzerLogger.logMessage('[PATH] QuizzerMedia path: $mediaPath');
  return mediaPath;
}

/// Returns the full path to the input staging directory for temporary media files.
/// This uses platform-specific paths to ensure proper staging regardless of OS.
/// Creates directories as needed.
Future<String> getInputStagingPath() async {
  Directory baseDir;
  try {
  if (Platform.isAndroid || Platform.isIOS) {
    baseDir = await getApplicationDocumentsDirectory();
    QuizzerLogger.logMessage('[PATH] Using mobile documents directory for staging: ${baseDir.path}');
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    baseDir = await getApplicationSupportDirectory();
    QuizzerLogger.logMessage('[PATH] Using application support directory for desktop staging: ${baseDir.path}');
  } else {
    QuizzerLogger.logWarning('[PATH] Unsupported platform for staging, defaulting to current directory.');
      baseDir = Directory('.');
    }
  } catch (e) {
    // Fallback for test environment where path_provider is not available
    QuizzerLogger.logMessage('[PATH] Path provider not available (likely test environment), using current directory for staging.');
    baseDir = Directory('.');
  }
  final Directory stagingDir = Directory(join(baseDir.path, 'QuizzerAppMedia', 'input_staging'));
  if (!await stagingDir.exists()) {
    await stagingDir.create(recursive: true);
  }
  final String stagingPath = stagingDir.path;
  QuizzerLogger.logMessage('[PATH] Input staging path: $stagingPath');
  return stagingPath;
}

/// Returns the full path to the Hive storage directory for persistent data.
/// Creates directories as needed and handles platform-specific paths consistently.
Future<String> getQuizzerHivePath() async {
  Directory baseDir;
  try {
  if (Platform.isAndroid || Platform.isIOS) {
    baseDir = await getApplicationDocumentsDirectory();
    QuizzerLogger.logMessage('[PATH] Using mobile documents directory for Hive: ${baseDir.path}');
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    baseDir = await getApplicationSupportDirectory();
    QuizzerLogger.logMessage('[PATH] Using application support directory for desktop Hive: ${baseDir.path}');
  } else {
    QuizzerLogger.logWarning('[PATH] Unsupported platform for Hive, defaulting to current directory.');
      baseDir = Directory('.');
    }
  } catch (e) {
    // Fallback for test environment where path_provider is not available
    QuizzerLogger.logMessage('[PATH] Path provider not available (likely test environment), using current directory for Hive.');
    baseDir = Directory('.');
  }
  final Directory hiveDir = Directory(join(baseDir.path, 'QuizzerAppHive'));
  if (!await hiveDir.exists()) {
    await hiveDir.create(recursive: true);
  }
  final String hivePath = hiveDir.path;
  QuizzerLogger.logMessage('[PATH] QuizzerHive path: $hivePath');
  return hivePath;
}

/// Returns the full path to the log files directory.
/// Creates directories as needed and handles platform-specific paths consistently.
Future<String> getQuizzerLogsPath() async {
  Directory baseDir;
  try {
  if (Platform.isAndroid || Platform.isIOS) {
    baseDir = await getApplicationDocumentsDirectory();
    QuizzerLogger.logMessage('[PATH] Using mobile documents directory for logs: ${baseDir.path}');
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    baseDir = await getApplicationSupportDirectory();
    QuizzerLogger.logMessage('[PATH] Using application support directory for desktop logs: ${baseDir.path}');
  } else {
    QuizzerLogger.logWarning('[PATH] Unsupported platform for logs, defaulting to current directory.');
      baseDir = Directory('.');
    }
  } catch (e) {
    // Fallback for test environment where path_provider is not available
    QuizzerLogger.logMessage('[PATH] Path provider not available (likely test environment), using current directory for logs.');
    baseDir = Directory('.');
  }
  final Directory logsDir = Directory(join(baseDir.path, 'QuizzerAppLogs'));
  if (!await logsDir.exists()) {
    await logsDir.create(recursive: true);
  }
  final String logsPath = logsDir.path;
  QuizzerLogger.logMessage('[PATH] QuizzerLogs path: $logsPath');
  return logsPath;
}
