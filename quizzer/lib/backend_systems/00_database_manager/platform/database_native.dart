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

  if (isDesktop) {
    // --- Desktop --- 
    ffi.sqfliteFfiInit(); // Initialize FFI *only* for desktop
    factory = ffi.databaseFactoryFfi;
    QuizzerLogger.logMessage("Using sqflite FFI factory (Desktop)");
    
    // Get the application support directory
    final Directory appSupportDir = await getApplicationSupportDirectory();
    // Define *target* path within the application support directory
    String dbDirectoryPath = join(appSupportDir.path, 'QuizzerApp', 'sqlite');
    targetPath = join(dbDirectoryPath, 'quizzer.db');
    
    // Ensure the *target* database directory exists (needed for both copy and direct open)
    // If this fails, the app should crash (Fail Fast)
    await Directory(dbDirectoryPath).create(recursive: true);
    QuizzerLogger.logMessage('Desktop SQLite directory ensured: $dbDirectoryPath');

  } else {
    // --- Mobile --- 
    factory = databaseFactory; // Default factory from sqflite package
    QuizzerLogger.logMessage("Using standard sqflite factory (Mobile)");
    
    // Get the standard *target* path provided by sqflite for mobile
    String databasesPath = await factory.getDatabasesPath();
    targetPath = join(databasesPath, 'quizzer.db');
    // Note: Directory existence is usually handled by sqflite on mobile
  }
  
  QuizzerLogger.logMessage('Target Database path: $targetPath');

  // --- Check if database exists and copy from assets if needed --- 
  final dbFile = File(targetPath);
  if (!await dbFile.exists()) {
    QuizzerLogger.logMessage('Database not found at target path. Copying from assets...');
    try {
      // Define the asset path (matches pubspec.yaml)
      const String assetPath = 'runtime_cache/sqlite/quizzer.db'; 
      ByteData data = await rootBundle.load(assetPath);
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      
      // Write the bytes to the target file
      // Ensure parent directory exists before writing (especially relevant for mobile)
      await Directory(dirname(targetPath)).create(recursive: true);
      await dbFile.writeAsBytes(bytes, flush: true);
      QuizzerLogger.logSuccess('Database successfully copied from assets to $targetPath');
    } catch (e) {
      QuizzerLogger.logError('Error copying database from assets: $e');
      // Decide how to handle error: rethrow, exit, or try opening potentially empty db?
      // Rethrowing is consistent with Fail Fast.
      rethrow; 
    }
  } else {
    QuizzerLogger.logMessage('Existing database found at $targetPath. Using it.');
  }
  // ------------------------------------------------------------------

  // Open the database using the selected factory and TARGET path
  // If this fails, the app should crash (Fail Fast)
  final database = await factory.openDatabase(
    targetPath,
    options: OpenDatabaseOptions(
      version: 1, // Set your database version
      // onCreate should NOT be needed here if the asset copy works,
      // as the tables should already exist in the copied db.
      // Keep onUpgrade for future schema changes.
      // onCreate: (Database db, int version) async {
      //   QuizzerLogger.logMessage('Database onCreate called - THIS SHOULD NOT HAPPEN if asset copy succeeded.');
      // },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        QuizzerLogger.logWarning('Database onUpgrade called from $oldVersion to $newVersion.');
      }
    )
  );
  QuizzerLogger.logSuccess('Database initialized successfully at: $targetPath');
  return database;
} 