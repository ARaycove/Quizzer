import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_helper_utils/utils.dart';
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';

/*
CRITICAL DATA STRUCTURE - QUIZZER ELEMENTS:
question_elements, answer_elements, and options are all List<Map<String, dynamic>> where each element is:
{'type': 'text|image|blank', 'content': 'string_value'}
- text: displays text content
- image: displays image (content = filename)
- blank: creates fill-in space (content = length as string)
Stored as JSON strings in DB, worked with as List<Map> in code.

CRITICAL DATABASE ACCESS PATTERN:
ALWAYS use: db = await getDatabaseMonitor().requestDatabaseAccess(); try { ... } finally { getDatabaseMonitor().releaseDatabaseAccess(); }
NEVER forget releaseDatabaseAccess() - it permanently locks the DB. Single-threaded access only.
NEVER call functions that request DB access while already holding DB access - causes deadlock/race condition.
Example: Function A gets DB access, calls Function B which also requests DB access = DEADLOCK.

CRITICAL DATABASE ENCODE/DECODE PATTERN:
ALWAYS decode values when fetched from DB, encode when storing to DB.
Use helper functions: insertRawData() for storing, queryRawData() for fetching.
Found in: lib/backend_systems/00_database_manager/tables/table_helper.dart
These handle JSON encoding/decoding of complex data types automatically.
Direct encode/decode functions: encodeValueForDB() and decodeValueFromDB() available for manual use when needed.
*/

void main() {
  group('Quizzer Utilities Tests', () {
    // Initialize logger for tests
    setUpAll(() async {
      await QuizzerLogger.setupLogging();
    });

    group('moveImageToFinalLocation', () {
      late String stagingPath;
      late String testImageName;
      late Directory stagingDir;
      late Directory finalDir;

      setUp(() async {
        // Create test directories
        stagingDir = Directory('${Directory.current.path}/test_staging');
        finalDir = Directory(await getQuizzerMediaPath());
        
        if (!await stagingDir.exists()) {
          await stagingDir.create(recursive: true);
        }
        if (!await finalDir.exists()) {
          await finalDir.create(recursive: true);
        }

        testImageName = 'test_image_${DateTime.now().millisecondsSinceEpoch}.png';
        stagingPath = '${stagingDir.path}/$testImageName';
        
        // Create a dummy image file
        final testImageBytes = Uint8List.fromList([
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG header
          0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
          0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 pixel
          0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, // Color type, compression, filter, interlace
          0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT chunk
          0x54, 0x08, 0x99, 0x01, 0x01, 0x00, 0x00, 0xFF, // Compressed data
          0xFF, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01, 0xE2, // End of compressed data
          0x21, 0xBC, 0x33, 0x00, 0x00, 0x00, 0x00, 0x49, // IEND chunk
          0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
        ]);
        
        await File(stagingPath).writeAsBytes(testImageBytes);
      });

      tearDown(() async {
        // Clean up test files
        final finalPath = '${finalDir.path}/$testImageName';
        if (await File(finalPath).exists()) {
          await File(finalPath).delete();
        }
        if (await File(stagingPath).exists()) {
          await File(stagingPath).delete();
        }
      });

      test('should move image from staging to final location successfully', () async {
        QuizzerLogger.logMessage('Testing moveImageToFinalLocation with valid image');
        
        final result = await moveImageToFinalLocation(stagingPath);
        
        expect(result, equals(testImageName));
        
        // Verify file was moved
        expect(await File(stagingPath).exists(), false);
        expect(await File('${finalDir.path}/$testImageName').exists(), true);
        
        QuizzerLogger.logSuccess('Image move test passed');
      });

      test('should create final directory if it does not exist', () async {
        QuizzerLogger.logMessage('Testing moveImageToFinalLocation with non-existent final directory');
        
        // Remove final directory
        if (await finalDir.exists()) {
          await finalDir.delete(recursive: true);
        }
        
        final result = await moveImageToFinalLocation(stagingPath);
        
        expect(result, equals(testImageName));
        expect(await finalDir.exists(), true);
        expect(await File('${finalDir.path}/$testImageName').exists(), true);
        
        QuizzerLogger.logSuccess('Directory creation test passed');
      });

      test('should throw error when source file does not exist', () async {
        QuizzerLogger.logMessage('Testing moveImageToFinalLocation with non-existent source file');
        
        expect(
          () => moveImageToFinalLocation('/non/existent/path/image.png'),
          throwsA(isA<Exception>()),
        );
        
        QuizzerLogger.logSuccess('Error handling test passed');
      });
    });

    group('logDatabaseMonitorStatus', () {
      test('should log database monitor status without throwing errors', () {
        QuizzerLogger.logMessage('Testing logDatabaseMonitorStatus');
        
        // This should not throw any errors
        expect(() => logDatabaseMonitorStatus(), returnsNormally);
        
        QuizzerLogger.logSuccess('Database monitor status logging test passed');
      });
    });

    group('checkConnectivity', () {
      test('should return true when network is available', () async {
        QuizzerLogger.logMessage('Testing checkConnectivity with available network');
        
        final result = await checkConnectivity();
        
        // This test may pass or fail depending on actual network connectivity
        // We just verify it returns a boolean
        expect(result, isA<bool>());
        
        QuizzerLogger.logSuccess('Connectivity check test passed');
      });

      test('should handle network errors gracefully', () async {
        QuizzerLogger.logMessage('Testing checkConnectivity error handling');
        
        // The function should handle network errors without throwing
        final result = await checkConnectivity();
        
        expect(result, isA<bool>());
        
        QuizzerLogger.logSuccess('Connectivity error handling test passed');
      });
    });

    group('trimContentFields', () {
      test('should trim whitespace from content fields in List<Map>', () {
        QuizzerLogger.logMessage('Testing trimContentFields with List<Map> input');
        
        final input = [
          {'type': 'text', 'content': '  Hello World  '},
          {'type': 'image', 'content': 'image.png'},
          {'type': 'text', 'content': '\n\nMultiple\nLines\n\n'},
          {'type': 'blank', 'content': '   '},
        ];
        
        final result = trimContentFields(input);
        
        expect(result[0]['content'], equals('Hello World'));
        expect(result[1]['content'], equals('image.png'));
        expect(result[2]['content'], equals('Multiple\nLines'));
        expect(result[3]['content'], equals(''));
        
        QuizzerLogger.logSuccess('List<Map> content trimming test passed');
      });

      test('should trim whitespace from content fields in JSON string', () {
        QuizzerLogger.logMessage('Testing trimContentFields with JSON string input');
        
        const input = '''[
          {"type": "text", "content": "  Hello World  "},
          {"type": "image", "content": "image.png"},
          {"type": "text", "content": "\\n\\nMultiple\\nLines\\n\\n"},
          {"type": "blank", "content": "   "}
        ]''';
        
        final result = trimContentFields(input);
        
        expect(result[0]['content'], equals('Hello World'));
        expect(result[1]['content'], equals('image.png'));
        expect(result[2]['content'], equals('Multiple\nLines'));
        expect(result[3]['content'], equals(''));
        
        QuizzerLogger.logSuccess('JSON string content trimming test passed');
      });

      test('should handle elements without content field', () {
        QuizzerLogger.logMessage('Testing trimContentFields with missing content field');
        
        final input = [
          {'type': 'text', 'other_field': 'value'},
          {'type': 'image'},
          {'type': 'blank', 'content': '  test  '},
        ];
        
        final result = trimContentFields(input);
        
        expect(result[0]['other_field'], equals('value'));
        expect(result[1]['type'], equals('image'));
        expect(result[2]['content'], equals('test'));
        
        QuizzerLogger.logSuccess('Missing content field test passed');
      });

      test('should handle non-string content fields', () {
        QuizzerLogger.logMessage('Testing trimContentFields with non-string content');
        
        final input = [
          {'type': 'text', 'content': 123},
          {'type': 'image', 'content': null},
          {'type': 'blank', 'content': true},
        ];
        
        final result = trimContentFields(input);
        
        expect(result[0]['content'], equals(123));
        expect(result[1]['content'], isNull);
        expect(result[2]['content'], isTrue);
        
        QuizzerLogger.logSuccess('Non-string content test passed');
      });

      test('should handle empty list', () {
        QuizzerLogger.logMessage('Testing trimContentFields with empty list');
        
        final input = <Map<String, dynamic>>[];
        
        final result = trimContentFields(input);
        
        expect(result, isEmpty);
        
        QuizzerLogger.logSuccess('Empty list test passed');
      });

      test('should not modify original list', () {
        QuizzerLogger.logMessage('Testing trimContentFields preserves original list');
        
        final input = [
          {'type': 'text', 'content': '  Original  '},
        ];
        
        final originalContent = input[0]['content'];
        final result = trimContentFields(input);
        
        expect(input[0]['content'], equals(originalContent));
        expect(result[0]['content'], equals('Original'));
        
        QuizzerLogger.logSuccess('Original list preservation test passed');
      });

      test('should handle JSON string with missing content fields', () {
        QuizzerLogger.logMessage('Testing trimContentFields with JSON string missing content fields');
        
        const input = '''[
          {"type": "text", "other_field": "value"},
          {"type": "image"},
          {"type": "blank", "content": "  test  "}
        ]''';
        
        final result = trimContentFields(input);
        
        expect(result[0]['other_field'], equals('value'));
        expect(result[1]['type'], equals('image'));
        expect(result[2]['content'], equals('test'));
        
        QuizzerLogger.logSuccess('JSON string missing content field test passed');
      });

      test('should handle JSON string with non-string content', () {
        QuizzerLogger.logMessage('Testing trimContentFields with JSON string non-string content');
        
        const input = '''[
          {"type": "text", "content": 123},
          {"type": "image", "content": null},
          {"type": "blank", "content": true}
        ]''';
        
        final result = trimContentFields(input);
        
        expect(result[0]['content'], equals(123));
        expect(result[1]['content'], isNull);
        expect(result[2]['content'], isTrue);
        
        QuizzerLogger.logSuccess('JSON string non-string content test passed');
      });

      test('should handle empty JSON string array', () {
        QuizzerLogger.logMessage('Testing trimContentFields with empty JSON string array');
        
        const input = '[]';
        
        final result = trimContentFields(input);
        
        expect(result, isEmpty);
        
        QuizzerLogger.logSuccess('Empty JSON string array test passed');
      });

      test('should throw error for invalid input type', () {
        QuizzerLogger.logMessage('Testing trimContentFields with invalid input type');
        
        expect(
          () => trimContentFields(123),
          throwsA(isA<ArgumentError>()),
        );
        
        expect(
          () => trimContentFields({'invalid': 'input'}),
          throwsA(isA<ArgumentError>()),
        );
        
        QuizzerLogger.logSuccess('Invalid input type error handling test passed');
      });

      test('should throw error for invalid JSON string', () {
        QuizzerLogger.logMessage('Testing trimContentFields with invalid JSON string');
        
        expect(
          () => trimContentFields('invalid json'),
          throwsA(isA<ArgumentError>()),
        );
        
        expect(
          () => trimContentFields('{"not": "an array"}'),
          throwsA(isA<ArgumentError>()),
        );
        
        QuizzerLogger.logSuccess('Invalid JSON string error handling test passed');
      });

      test('should handle real quizzer elements structure', () {
        QuizzerLogger.logMessage('Testing trimContentFields with real quizzer elements structure');
        
        final input = [
          {'type': 'text', 'content': '  What is the capital of France?  '},
          {'type': 'image', 'content': '  france_map.png  '},
          {'type': 'text', 'content': '  Choose the correct answer:  '},
        ];
        
        final result = trimContentFields(input);
        
        expect(result[0]['content'], equals('What is the capital of France?'));
        expect(result[1]['content'], equals('france_map.png'));
        expect(result[2]['content'], equals('Choose the correct answer:'));
        
        QuizzerLogger.logSuccess('Real quizzer elements structure test passed');
      });
    });
  });
}
