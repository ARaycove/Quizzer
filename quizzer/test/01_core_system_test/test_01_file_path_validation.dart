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
  
  group('Group 1: Individual Path Unit Tests', () {
    test('Database path should be correct and database should persist data', () async {
      QuizzerLogger.logMessage('=== DATABASE PATH UNIT TEST ===');
      
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
      
      QuizzerLogger.logSuccess('Database path unit test passed - data persists correctly');
    });
    
    test('Database should use the correct path specified in file_locations', () async {
      QuizzerLogger.logMessage('=== DATABASE PATH VERIFICATION UNIT TEST ===');
      
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
      QuizzerLogger.logSuccess('Database path verification unit test passed - using correct path');
    });

    test('Hive path should be accessible and properly structured', () async {
      QuizzerLogger.logMessage('=== HIVE PATH UNIT TEST ===');
      
      final hivePath = await getQuizzerHivePath();
      QuizzerLogger.logMessage('Hive path: $hivePath');
      
      // Verify path is non-empty
      expect(hivePath, isNotEmpty, reason: 'Hive path should not be empty');
      
      // Verify directory exists or can be created
      final hiveDir = Directory(hivePath);
      expect(await hiveDir.exists(), isTrue, reason: 'Hive directory should exist');
      
      // Verify path structure contains expected components
      expect(hivePath, contains('QuizzerAppHive'), reason: 'Hive path should contain QuizzerAppHive');
      
      QuizzerLogger.logSuccess('Hive path unit test passed - path is properly structured and accessible');
    });

    test('Logs path should be accessible and properly structured', () async {
      QuizzerLogger.logMessage('=== LOGS PATH UNIT TEST ===');
      
      final logsPath = await getQuizzerLogsPath();
      QuizzerLogger.logMessage('Logs path: $logsPath');
      
      // Verify path is non-empty
      expect(logsPath, isNotEmpty, reason: 'Logs path should not be empty');
      
      // Verify directory exists or can be created
      final logsDir = Directory(logsPath);
      expect(await logsDir.exists(), isTrue, reason: 'Logs directory should exist');
      
      // Verify path structure contains expected components
      expect(logsPath, contains('QuizzerAppLogs'), reason: 'Logs path should contain QuizzerAppLogs');
      
      QuizzerLogger.logSuccess('Logs path unit test passed - path is properly structured and accessible');
    });

    test('Media path should be accessible and properly structured', () async {
      QuizzerLogger.logMessage('=== MEDIA PATH UNIT TEST ===');
      
      final mediaPath = await getQuizzerMediaPath();
      QuizzerLogger.logMessage('Media path: $mediaPath');
      
      // Verify path is non-empty
      expect(mediaPath, isNotEmpty, reason: 'Media path should not be empty');
      
      // Verify directory exists or can be created
      final mediaDir = Directory(mediaPath);
      expect(await mediaDir.exists(), isTrue, reason: 'Media directory should exist');
      
      // Verify path structure contains expected components
      expect(mediaPath, contains('QuizzerAppMedia'), reason: 'Media path should contain QuizzerAppMedia');
      expect(mediaPath, contains('question_answer_pair_assets'), reason: 'Media path should contain question_answer_pair_assets');
      
      QuizzerLogger.logSuccess('Media path unit test passed - path is properly structured and accessible');
    });

    test('Input staging path should be accessible and properly structured', () async {
      QuizzerLogger.logMessage('=== INPUT STAGING PATH UNIT TEST ===');
      
      final inputStagingPath = await getInputStagingPath();
      QuizzerLogger.logMessage('Input staging path: $inputStagingPath');
      
      // Verify path is non-empty
      expect(inputStagingPath, isNotEmpty, reason: 'Input staging path should not be empty');
      
      // Verify directory exists or can be created
      final inputStagingDir = Directory(inputStagingPath);
      expect(await inputStagingDir.exists(), isTrue, reason: 'Input staging directory should exist');
      
      // Verify path structure contains expected components
      expect(inputStagingPath, contains('QuizzerAppMedia'), reason: 'Input staging path should contain QuizzerAppMedia');
      expect(inputStagingPath, contains('input_staging'), reason: 'Input staging path should contain input_staging');
      
      QuizzerLogger.logSuccess('Input staging path unit test passed - path is properly structured and accessible');
    });
  });

  group('Group 2: Path Integration Tests', () {
    test('All paths should be unique and not interfere with each other', () async {
      QuizzerLogger.logMessage('=== PATH UNIQUENESS INTEGRATION TEST ===');
      
      // Get all paths
      final dbPath = await getQuizzerDatabasePath();
      final hivePath = await getQuizzerHivePath();
      final logsPath = await getQuizzerLogsPath();
      final mediaPath = await getQuizzerMediaPath();
      final inputStagingPath = await getInputStagingPath();
      
      QuizzerLogger.logMessage('All paths retrieved:');
      QuizzerLogger.logMessage('  Database: $dbPath');
      QuizzerLogger.logMessage('  Hive: $hivePath');
      QuizzerLogger.logMessage('  Logs: $logsPath');
      QuizzerLogger.logMessage('  Media: $mediaPath');
      QuizzerLogger.logMessage('  Input Staging: $inputStagingPath');
      
      // Verify all paths are different from each other
      expect(dbPath, isNot(equals(hivePath)), reason: 'Database and Hive paths should be different');
      expect(dbPath, isNot(equals(logsPath)), reason: 'Database and Logs paths should be different');
      expect(dbPath, isNot(equals(mediaPath)), reason: 'Database and Media paths should be different');
      expect(dbPath, isNot(equals(inputStagingPath)), reason: 'Database and Input staging paths should be different');
      expect(hivePath, isNot(equals(logsPath)), reason: 'Hive and Logs paths should be different');
      expect(hivePath, isNot(equals(mediaPath)), reason: 'Hive and Media paths should be different');
      expect(hivePath, isNot(equals(inputStagingPath)), reason: 'Hive and Input staging paths should be different');
      expect(logsPath, isNot(equals(mediaPath)), reason: 'Logs and Media paths should be different');
      expect(logsPath, isNot(equals(inputStagingPath)), reason: 'Logs and Input staging paths should be different');
      expect(mediaPath, isNot(equals(inputStagingPath)), reason: 'Media and Input staging paths should be different');
      
      QuizzerLogger.logSuccess('Path uniqueness integration test passed - all paths are unique');
    });

    test('Media and input staging paths should share the same parent directory', () async {
      QuizzerLogger.logMessage('=== MEDIA PARENT DIRECTORY INTEGRATION TEST ===');
      
      final mediaPath = await getQuizzerMediaPath();
      final inputStagingPath = await getInputStagingPath();
      
      // Verify that media and input staging are in the same parent directory
      final mediaParent = Directory(mediaPath).parent;
      final inputStagingParent = Directory(inputStagingPath).parent;
      
      QuizzerLogger.logMessage('Media parent directory: ${mediaParent.path}');
      QuizzerLogger.logMessage('Input staging parent directory: ${inputStagingParent.path}');
      
      expect(mediaParent.path, equals(inputStagingParent.path), reason: 'Media and input staging should be in the same parent directory');
      
      QuizzerLogger.logSuccess('Media parent directory integration test passed - both paths share the same parent');
    });

    test('All directories should be accessible simultaneously without conflicts', () async {
      QuizzerLogger.logMessage('=== SIMULTANEOUS ACCESS INTEGRATION TEST ===');
      
      // Get all paths and verify they all exist simultaneously
      final dbPath = await getQuizzerDatabasePath();
      final hivePath = await getQuizzerHivePath();
      final logsPath = await getQuizzerLogsPath();
      final mediaPath = await getQuizzerMediaPath();
      final inputStagingPath = await getInputStagingPath();
      
      // Verify all directories exist
      expect(await Directory(dbPath).parent.exists(), isTrue, reason: 'Database directory should exist');
      expect(await Directory(hivePath).exists(), isTrue, reason: 'Hive directory should exist');
      expect(await Directory(logsPath).exists(), isTrue, reason: 'Logs directory should exist');
      expect(await Directory(mediaPath).exists(), isTrue, reason: 'Media directory should exist');
      expect(await Directory(inputStagingPath).exists(), isTrue, reason: 'Input staging directory should exist');
      
      QuizzerLogger.logSuccess('Simultaneous access integration test passed - all directories are accessible');
    });

    test('Should completely delete all Quizzer app data generated during test sequence', () async {
      QuizzerLogger.logMessage('=== COMPLETE DATA CLEANUP INTEGRATION TEST ===');
      
      // Get all the paths that need to be cleaned up
      final dbPath = await getQuizzerDatabasePath();
      final dbDirectory = Directory(dbPath).parent;
      final hivePath = await getQuizzerHivePath();
      final logsPath = await getQuizzerLogsPath();
      final mediaPath = await getQuizzerMediaPath();
      final inputStagingPath = await getInputStagingPath();
      
      QuizzerLogger.logMessage('Paths to clean up:');
      QuizzerLogger.logMessage('  Database: $dbPath');
      QuizzerLogger.logMessage('  Database directory: $dbDirectory');
      QuizzerLogger.logMessage('  Hive: $hivePath');
      QuizzerLogger.logMessage('  Logs: $logsPath');
      QuizzerLogger.logMessage('  Media: $mediaPath');
      QuizzerLogger.logMessage('  Input staging: $inputStagingPath');
      
      // Check what exists before cleanup
      final dbFile = File(dbPath);
      final dbDir = Directory(dbDirectory.path);
      final hiveDir = Directory(hivePath);
      final logsDir = Directory(logsPath);
      final mediaDir = Directory(mediaPath);
      final inputStagingDir = Directory(inputStagingPath);
      
      final dbExists = await dbFile.exists();
      final dbDirExists = await dbDir.exists();
      final hiveExists = await hiveDir.exists();
      final logsExists = await logsDir.exists();
      final mediaExists = await mediaDir.exists();
      final inputStagingExists = await inputStagingDir.exists();
      
      QuizzerLogger.logMessage('Before cleanup:');
      QuizzerLogger.logMessage('  Database file exists: $dbExists');
      QuizzerLogger.logMessage('  Database directory exists: $dbDirExists');
      QuizzerLogger.logMessage('  Hive directory exists: $hiveExists');
      QuizzerLogger.logMessage('  Logs directory exists: $logsExists');
      QuizzerLogger.logMessage('  Media directory exists: $mediaExists');
      QuizzerLogger.logMessage('  Input staging directory exists: $inputStagingExists');
      
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
      
      // Delete input staging directory and contents
      if (inputStagingExists) {
        try {
          await inputStagingDir.delete(recursive: true);
          QuizzerLogger.logMessage('Input staging directory and contents deleted');
        } catch (e) {
          QuizzerLogger.logMessage('Error deleting input staging directory: $e');
        }
      }
      
      // Try to delete the parent QuizzerAppMedia directory if it's empty
      final mediaParentDir = Directory(mediaPath).parent;
      if (await mediaParentDir.exists()) {
        try {
          final contents = await mediaParentDir.list().toList();
          if (contents.isEmpty) {
            await mediaParentDir.delete();
            QuizzerLogger.logMessage('Empty QuizzerAppMedia parent directory deleted');
          } else {
            QuizzerLogger.logMessage('QuizzerAppMedia parent directory not empty, skipping deletion');
          }
        } catch (e) {
          QuizzerLogger.logMessage('Error checking QuizzerAppMedia parent directory contents: $e');
        }
      }
      
      // Verify cleanup was successful
      final dbExistsAfter = await dbFile.exists();
      final dbDirExistsAfter = await dbDir.exists();
      final hiveExistsAfter = await hiveDir.exists();
      final logsExistsAfter = await logsDir.exists();
      final mediaExistsAfter = await mediaDir.exists();
      final inputStagingExistsAfter = await inputStagingDir.exists();
      
      QuizzerLogger.logMessage('After cleanup:');
      QuizzerLogger.logMessage('  Database file exists: $dbExistsAfter');
      QuizzerLogger.logMessage('  Database directory exists: $dbDirExistsAfter');
      QuizzerLogger.logMessage('  Hive directory exists: $hiveExistsAfter');
      QuizzerLogger.logMessage('  Logs directory exists: $logsExistsAfter');
      QuizzerLogger.logMessage('  Media directory exists: $mediaExistsAfter');
      QuizzerLogger.logMessage('  Input staging directory exists: $inputStagingExistsAfter');
      
      // Assert that all data has been cleaned up
      expect(dbExistsAfter, isFalse, reason: 'Database file should be deleted');
      expect(hiveExistsAfter, isFalse, reason: 'Hive directory should be deleted');
      expect(logsExistsAfter, isFalse, reason: 'Logs directory should be deleted');
      expect(mediaExistsAfter, isFalse, reason: 'Media directory should be deleted');
      expect(inputStagingExistsAfter, isFalse, reason: 'Input staging directory should be deleted');
      
      QuizzerLogger.logSuccess('Complete data cleanup integration test passed - all data cleaned up successfully');
    });
  });
}
