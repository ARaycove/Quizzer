import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';

/// Initializes the database for native platforms (mobile and desktop)
Future<Database> initializeDatabase() async {
  DatabaseFactory factory;
  String targetPath = await getQuizzerDatabasePath();
  bool isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  QuizzerLogger.logMessage('[DB_INIT] Starting database initialization. Desktop: $isDesktop');

  if (isDesktop) {
    ffi.sqfliteFfiInit();
    factory = ffi.databaseFactoryFfi;
    QuizzerLogger.logMessage("[DB_INIT] Using sqflite FFI factory (Desktop)");
  } else {
    factory = databaseFactory;
    QuizzerLogger.logMessage("[DB_INIT] Using standard sqflite factory (Mobile)");
  }

  // Force absolute path to prevent test environment from redirecting
  final absolutePath = File(targetPath).absolute.path;
  // Normalize the path to remove ./ prefix and match SQLite's normalization
  final normalizedPath = absolutePath.replaceAll('/./', '/');
  QuizzerLogger.logMessage('[DB_INIT] Original target path: $targetPath');
  QuizzerLogger.logMessage('[DB_INIT] Absolute target path: $absolutePath');
  QuizzerLogger.logMessage('[DB_INIT] Normalized target path: $normalizedPath');

  final dbFile = File(normalizedPath);
  final bool dbFileExists = await dbFile.exists();
  QuizzerLogger.logMessage('[DB_INIT] Checking existence of dbFile at $normalizedPath. Exists: $dbFileExists');

  if (!dbFileExists) {
    QuizzerLogger.logMessage('[DB_INIT] Database NOT found at $normalizedPath. Creating empty database...');
    // Create an empty database instead of copying bundled data
    // This allows fresh users to start with no initial data and get everything through sync
    await dbFile.create(recursive: true);
    QuizzerLogger.logSuccess('[DB_INIT] Empty database created at $normalizedPath');
  } else {
    QuizzerLogger.logMessage('[DB_INIT] Existing database found at $normalizedPath. Using it.');
  }

  QuizzerLogger.logMessage('[DB_INIT] Attempting to open database at $normalizedPath');
  final database = await factory.openDatabase(
    normalizedPath,
    options: OpenDatabaseOptions(
      version: 1,
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        QuizzerLogger.logWarning('[DB_INIT] Database onUpgrade called from $oldVersion to $newVersion.');
      }
    )
  );
  
  // Verify the database is actually at the expected location
  final actualPath = database.path;
  QuizzerLogger.logMessage('[DB_INIT] Database opened at actual path: $actualPath');
  QuizzerLogger.logMessage('[DB_INIT] Expected path: $normalizedPath');
  QuizzerLogger.logMessage('[DB_INIT] Paths match: ${actualPath == normalizedPath}');
  
  QuizzerLogger.logSuccess('[DB_INIT] Database initialized successfully at: $normalizedPath. IsOpen: ${database.isOpen}');
  return database;
} 