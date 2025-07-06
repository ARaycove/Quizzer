import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:flutter/services.dart' show ByteData, rootBundle;
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