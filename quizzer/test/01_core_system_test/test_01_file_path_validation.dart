import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/quizzer_database.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUpAll(() async {
    await QuizzerLogger.setupLogging();
  });
  
  group('File Path Validation Tests', () {
    test('Database path should be correct and database should persist data', () async {
      QuizzerLogger.logMessage('=== DATABASE PATH VALIDATION ===');
      
      // Get the database path
      final dbPath = await getQuizzerDatabasePath();
      final absolutePath = File(dbPath).absolute.path;
      final normalizedPath = absolutePath.replaceAll('/./', '/');
      
      QuizzerLogger.logMessage('Database path: $dbPath');
      QuizzerLogger.logMessage('Absolute path: $absolutePath');
      QuizzerLogger.logMessage('Normalized path: $normalizedPath');
      
      // Check if file exists before test
      final dbFile = File(normalizedPath);
      final existsBefore = await dbFile.exists();
      final sizeBefore = existsBefore ? await dbFile.length() : 0;
      QuizzerLogger.logMessage('Database exists before test: $existsBefore');
      QuizzerLogger.logMessage('Database size before test: $sizeBefore bytes');
      
      // Initialize database and create a test table
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db == null) {
        throw Exception('Failed to acquire database access');
      }
      
      // Create a test table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS test_persistence (
          id TEXT PRIMARY KEY,
          test_data TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      
      // Insert test data with unique timestamp to avoid conflicts
      final testId = 'test-${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecond}';
      final testData = 'persistence_test_data_${DateTime.now().millisecondsSinceEpoch}';
      final createdAt = DateTime.now().toUtc().toIso8601String();
      
      await db.insert('test_persistence', {
        'id': testId,
        'test_data': testData,
        'created_at': createdAt,
      });
      
      getDatabaseMonitor().releaseDatabaseAccess();
      QuizzerLogger.logMessage('Test data inserted: $testId');
      
      // Verify data was actually written by reading it back
      final db2 = await getDatabaseMonitor().requestDatabaseAccess();
      if (db2 == null) {
        throw Exception('Failed to acquire database access for verification');
      }
      
      final List<Map<String, dynamic>> results = await db2.rawQuery(
        'SELECT * FROM test_persistence WHERE id = ?',
        [testId]
      );
      getDatabaseMonitor().releaseDatabaseAccess();
      
      expect(results.length, equals(1), reason: 'Test data should be immediately readable after insert');
      expect(results.first['test_data'], equals(testData), reason: 'Test data should be correct');
      
      // Close database to force persistence
      await closeDatabase();
      QuizzerLogger.logMessage('Database closed');
      
      // Check file size after closing
      final existsAfterClose = await dbFile.exists();
      final sizeAfterClose = existsAfterClose ? await dbFile.length() : 0;
      QuizzerLogger.logMessage('Database exists after close: $existsAfterClose');
      QuizzerLogger.logMessage('Database size after close: $sizeAfterClose bytes');
      
      // Verify data persists after close
      expect(sizeAfterClose, greaterThan(0), reason: 'Database should persist data after closing');
      
      // Reopen database and verify data still exists
      final db3 = await getDatabaseMonitor().requestDatabaseAccess();
      if (db3 == null) {
        throw Exception('Failed to acquire database access after reopening');
      }
      
      final List<Map<String, dynamic>> resultsAfterReopen = await db3.rawQuery(
        'SELECT * FROM test_persistence WHERE id = ?',
        [testId]
      );
      getDatabaseMonitor().releaseDatabaseAccess();
      
      expect(resultsAfterReopen.length, equals(1), reason: 'Test data should persist after database close/reopen');
      expect(resultsAfterReopen.first['test_data'], equals(testData), reason: 'Test data should be correct after reopen');
      
      QuizzerLogger.logSuccess('Database path validation passed - data persists correctly');
    });
    
    test('Database should use the correct path specified in file_locations', () async {
      QuizzerLogger.logMessage('=== DATABASE PATH VERIFICATION ===');
      
      // Get the expected path
      final expectedPath = await getQuizzerDatabasePath();
      final expectedAbsolute = File(expectedPath).absolute.path;
      final expectedNormalized = expectedAbsolute.replaceAll('/./', '/');
      
      QuizzerLogger.logMessage('Expected path from file_locations: $expectedPath');
      QuizzerLogger.logMessage('Expected absolute path: $expectedAbsolute');
      QuizzerLogger.logMessage('Expected normalized path: $expectedNormalized');
      
      // Initialize database
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db == null) {
        throw Exception('Failed to acquire database access');
      }
      
      // Get the actual path the database is using
      final actualPath = db.path;
      QuizzerLogger.logMessage('Actual database path: $actualPath');
      
      // Verify paths match
      expect(actualPath, equals(expectedNormalized), reason: 'Database should use the path specified in file_locations');
      
      getDatabaseMonitor().releaseDatabaseAccess();
      QuizzerLogger.logSuccess('Database path verification passed - using correct path');
    });
  });

  group('Quizzer App Data Cleanup Tests', () {
    test('Should completely delete all Quizzer app data generated during test sequence', () async {
      QuizzerLogger.logMessage('=== QUIZZER APP DATA CLEANUP ===');
      
      // Get all the paths that need to be cleaned up using existing functions
      final dbPath = await getQuizzerDatabasePath();
      final dbDirectory = Directory(dbPath).parent;
      final hivePath = await getQuizzerHivePath();
      final logsPath = await getQuizzerLogsPath();
      final mediaPath = await getQuizzerMediaPath();
      
      QuizzerLogger.logMessage('Database path: $dbPath');
      QuizzerLogger.logMessage('Database directory: $dbDirectory');
      QuizzerLogger.logMessage('Hive path: $hivePath');
      QuizzerLogger.logMessage('Logs path: $logsPath');
      QuizzerLogger.logMessage('Media path: $mediaPath');
      
      // Check what exists before cleanup
      final dbFile = File(dbPath);
      final dbDir = Directory(dbDirectory.path);
      final hiveDir = Directory(hivePath);
      final logsDir = Directory(logsPath);
      final mediaDir = Directory(mediaPath);
      
      final dbExists = await dbFile.exists();
      final dbDirExists = await dbDir.exists();
      final hiveExists = await hiveDir.exists();
      final logsExists = await logsDir.exists();
      final mediaExists = await mediaDir.exists();
      
      QuizzerLogger.logMessage('Before cleanup:');
      QuizzerLogger.logMessage('  Database file exists: $dbExists');
      QuizzerLogger.logMessage('  Database directory exists: $dbDirExists');
      QuizzerLogger.logMessage('  Hive directory exists: $hiveExists');
      QuizzerLogger.logMessage('  Logs directory exists: $logsExists');
      QuizzerLogger.logMessage('  Media directory exists: $mediaExists');
      
      // Close database if it's open
      try {
        await closeDatabase();
        QuizzerLogger.logMessage('Database closed successfully');
      } catch (e) {
        QuizzerLogger.logMessage('Database was already closed or not open: $e');
      }
      
      // Delete database file
      if (dbExists) {
        await dbFile.delete();
        QuizzerLogger.logMessage('Database file deleted');
      }
      
      // Delete database directory if empty
      if (dbDirExists) {
        try {
          final contents = await dbDir.list().toList();
          if (contents.isEmpty) {
            await dbDir.delete();
            QuizzerLogger.logMessage('Empty database directory deleted');
          } else {
            QuizzerLogger.logMessage('Database directory not empty, skipping deletion');
          }
        } catch (e) {
          QuizzerLogger.logMessage('Error checking database directory contents: $e');
        }
      }
      
      // Delete Hive directory and contents
      if (hiveExists) {
        try {
          await hiveDir.delete(recursive: true);
          QuizzerLogger.logMessage('Hive directory and contents deleted');
        } catch (e) {
          QuizzerLogger.logMessage('Error deleting Hive directory: $e');
        }
      }
      
      // Delete logs directory and contents
      if (logsExists) {
        try {
          await logsDir.delete(recursive: true);
          QuizzerLogger.logMessage('Logs directory and contents deleted');
        } catch (e) {
          QuizzerLogger.logMessage('Error deleting logs directory: $e');
        }
      }
      
      // Delete media directory and contents
      if (mediaExists) {
        try {
          await mediaDir.delete(recursive: true);
          QuizzerLogger.logMessage('Media directory and contents deleted');
        } catch (e) {
          QuizzerLogger.logMessage('Error deleting media directory: $e');
        }
      }
      
      // Verify cleanup was successful
      final dbExistsAfter = await dbFile.exists();
      final dbDirExistsAfter = await dbDir.exists();
      final hiveExistsAfter = await hiveDir.exists();
      final logsExistsAfter = await logsDir.exists();
      final mediaExistsAfter = await mediaDir.exists();
      
      QuizzerLogger.logMessage('After cleanup:');
      QuizzerLogger.logMessage('  Database file exists: $dbExistsAfter');
      QuizzerLogger.logMessage('  Database directory exists: $dbDirExistsAfter');
      QuizzerLogger.logMessage('  Hive directory exists: $hiveExistsAfter');
      QuizzerLogger.logMessage('  Logs directory exists: $logsExistsAfter');
      QuizzerLogger.logMessage('  Media directory exists: $mediaExistsAfter');
      
      // Assert that all data has been cleaned up
      expect(dbExistsAfter, isFalse, reason: 'Database file should be deleted');
      expect(hiveExistsAfter, isFalse, reason: 'Hive directory should be deleted');
      expect(logsExistsAfter, isFalse, reason: 'Logs directory should be deleted');
      expect(mediaExistsAfter, isFalse, reason: 'Media directory should be deleted');
      
      QuizzerLogger.logSuccess('Quizzer app data cleanup completed successfully');
    });
  });
}
