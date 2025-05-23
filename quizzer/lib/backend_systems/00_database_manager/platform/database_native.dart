import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:path_provider/path_provider.dart';

/// Initializes the database for native platforms (mobile and desktop)
Future<Database> initializeDatabase() async {
  DatabaseFactory factory;
  String targetPath; // Renamed from path to targetPath for clarity
  bool isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  QuizzerLogger.logMessage('[DB_INIT] Starting database initialization. Desktop: $isDesktop');

  if (isDesktop) {
    // --- Desktop --- 
    ffi.sqfliteFfiInit(); // Initialize FFI *only* for desktop
    factory = ffi.databaseFactoryFfi;
    QuizzerLogger.logMessage("[DB_INIT] Using sqflite FFI factory (Desktop)");
    
    // Get the application support directory
    final Directory appSupportDir = await getApplicationSupportDirectory();
    QuizzerLogger.logMessage('[DB_INIT] Desktop appSupportDir.path: ${appSupportDir.path}');
    // Define *target* path within the application support directory
    String dbDirectoryPath = join(appSupportDir.path, 'QuizzerApp', 'sqlite');
    targetPath = join(dbDirectoryPath, 'quizzer.db');
    QuizzerLogger.logMessage('[DB_INIT] Desktop targetPath: $targetPath');
    
    // Ensure the *target* database directory exists (needed for both copy and direct open)
    // If this fails, the app should crash (Fail Fast)
    try {
      final Directory createdDir = await Directory(dbDirectoryPath).create(recursive: true);
      QuizzerLogger.logMessage('[DB_INIT] Desktop SQLite directory ensured: ${createdDir.path}, Exists: ${await createdDir.exists()}');
    } catch (e) {
      QuizzerLogger.logError('[DB_INIT] CRITICAL: Failed to create desktop database directory $dbDirectoryPath: $e');
      rethrow;
    }

  } else {
    // --- Mobile --- 
    factory = databaseFactory; // Default factory from sqflite package
    QuizzerLogger.logMessage("[DB_INIT] Using standard sqflite factory (Mobile)");
    
    // Get the standard *target* path provided by sqflite for mobile
    String databasesPath = await factory.getDatabasesPath();
    QuizzerLogger.logMessage('[DB_INIT] Mobile databasesPath: $databasesPath');
    targetPath = join(databasesPath, 'quizzer.db');
    QuizzerLogger.logMessage('[DB_INIT] Mobile targetPath: $targetPath');
    // Note: Directory existence is usually handled by sqflite on mobile
  }
  
  QuizzerLogger.logMessage('[DB_INIT] Final Target Database path: $targetPath');

  // --- Check if database exists and copy from assets if needed --- 
  final dbFile = File(targetPath);
  final bool dbFileExists = await dbFile.exists();
  QuizzerLogger.logMessage('[DB_INIT] Checking existence of dbFile at $targetPath. Exists: $dbFileExists');

  if (!dbFileExists) {
    QuizzerLogger.logWarning('[DB_INIT] Database NOT found at $targetPath. Attempting to copy from assets...');
    try {
      // Define the asset path (matches pubspec.yaml)
      const String assetPath = 'runtime_cache/sqlite/quizzer.db'; 
      QuizzerLogger.logMessage('[DB_INIT] Loading asset: $assetPath');
      ByteData data = await rootBundle.load(assetPath);
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      QuizzerLogger.logMessage('[DB_INIT] Asset loaded, ${bytes.length} bytes. Ensuring parent directory for $targetPath');
      
      // Write the bytes to the target file
      // Ensure parent directory exists before writing (especially relevant for mobile)
      try {
        final Directory parentDir = await Directory(dirname(targetPath)).create(recursive: true);
        QuizzerLogger.logMessage('[DB_INIT] Parent directory ${parentDir.path} for $targetPath ensured. Exists: ${await parentDir.exists()}');
      } catch (e) {
        QuizzerLogger.logError('[DB_INIT] CRITICAL: Failed to create parent directory for $targetPath: $e');
        rethrow;
      }
      await dbFile.writeAsBytes(bytes, flush: true);
      QuizzerLogger.logSuccess('[DB_INIT] Database successfully copied from assets to $targetPath. Copied file exists: ${await dbFile.exists()}');
    } catch (e) {
      QuizzerLogger.logError('[DB_INIT] CRITICAL: Error copying database from assets to $targetPath: $e');
      // Decide how to handle error: rethrow, exit, or try opening potentially empty db?
      // Rethrowing is consistent with Fail Fast.
      rethrow; 
    }
  } else {
    QuizzerLogger.logMessage('[DB_INIT] Existing database found at $targetPath. Using it.');
  }
  // ------------------------------------------------------------------

  // Open the database using the selected factory and TARGET path
  // If this fails, the app should crash (Fail Fast)
  QuizzerLogger.logMessage('[DB_INIT] Attempting to open database at $targetPath');
  final database = await factory.openDatabase(
    targetPath,
    options: OpenDatabaseOptions(
      version: 1, // Set your database version
      // onCreate should NOT be needed here if the asset copy works,
      // as the tables should already exist in the copied db.
      // Keep onUpgrade for future schema changes.
      // onCreate: (Database db, int version) async {
      //   QuizzerLogger.logMessage('[DB_INIT] Database onCreate called - THIS SHOULD NOT HAPPEN if asset copy succeeded.');
      // },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        QuizzerLogger.logWarning('[DB_INIT] Database onUpgrade called from $oldVersion to $newVersion.');
      }
    )
  );
  QuizzerLogger.logSuccess('[DB_INIT] Database initialized successfully at: $targetPath. IsOpen: ${database.isOpen}');
  return database;
} 