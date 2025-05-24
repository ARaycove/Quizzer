import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:path_provider/path_provider.dart';

/// Returns the full path to the Quizzer SQLite database, creating directories as needed.
Future<String> getQuizzerDatabasePath() async {
  Directory baseDir;
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
  final Directory appDir = Directory(join(baseDir.path, 'QuizzerApp', 'sqlite'));
  if (!await appDir.exists()) {
    await appDir.create(recursive: true);
  }
  final String dbPath = join(appDir.path, 'quizzer.db');
  QuizzerLogger.logMessage('[PATH] Quizzer database path: $dbPath');
  return dbPath;
}

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

  QuizzerLogger.logMessage('[DB_INIT] Final Target Database path: $targetPath');

  final dbFile = File(targetPath);
  final bool dbFileExists = await dbFile.exists();
  QuizzerLogger.logMessage('[DB_INIT] Checking existence of dbFile at $targetPath. Exists: $dbFileExists');

  if (!dbFileExists) {
    QuizzerLogger.logWarning('[DB_INIT] Database NOT found at $targetPath. Copying bundled database...');
    // Copy the bundled database from runtime_cache/sqlite/quizzer.db
    final ByteData data = await rootBundle.load('runtime_cache/sqlite/quizzer.db');
    final List<int> bytes = data.buffer.asUint8List();
    await dbFile.create(recursive: true);
    await dbFile.writeAsBytes(bytes);
    QuizzerLogger.logSuccess('[DB_INIT] Bundled database copied to $targetPath');
  } else {
    QuizzerLogger.logMessage('[DB_INIT] Existing database found at $targetPath. Using it.');
  }

  QuizzerLogger.logMessage('[DB_INIT] Attempting to open database at $targetPath');
  final database = await factory.openDatabase(
    targetPath,
    options: OpenDatabaseOptions(
      version: 1,
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        QuizzerLogger.logWarning('[DB_INIT] Database onUpgrade called from $oldVersion to $newVersion.');
      }
    )
  );
  QuizzerLogger.logSuccess('[DB_INIT] Database initialized successfully at: $targetPath. IsOpen: ${database.isOpen}');
  return database;
} 