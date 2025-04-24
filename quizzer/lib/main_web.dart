import 'package:hive/hive.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

/// Initializes Hive for web platform
Future<void> initializeHive() async {
  // Web platform initialization - no need to specify path for web
  Hive.init('');
  QuizzerLogger.logMessage("Platform: Web. Initialized Hive without specific path");
} 