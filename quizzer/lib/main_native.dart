import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

/// Initializes Hive for native platforms (mobile and desktop)
Future<void> initializeHive() async {
  // Native platform initialization (Desktop or Mobile)
  String hivePath;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Desktop: Use the ambiguous runtime_cache directory
    hivePath = join(Directory.current.path, 'runtime_cache', 'hive');
    QuizzerLogger.logMessage("Platform: Desktop. Setting Hive path to: $hivePath");
  } else {
    // Mobile: Use standard application documents directory
    final appDocumentsDir = await getApplicationDocumentsDirectory();
    hivePath = appDocumentsDir.path;
    QuizzerLogger.logMessage("Platform: Mobile. Setting Hive path to: $hivePath");
  }

  // Ensure the directory exists (important for desktop)
  // If this fails, the app should crash (Fail Fast)
  Directory(dirname(hivePath)).createSync(recursive: true); // Ensure parent dir exists
  // For mobile, appDocumentsDir usually exists, but createSync is safe
  // For desktop, create runtime_cache if needed
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    Directory(hivePath).createSync(recursive: true); // Create the hive subdir
  }
  Hive.init(hivePath); // Initialize Hive with the determined path
  QuizzerLogger.logMessage("Hive Initialized at: $hivePath");
} 