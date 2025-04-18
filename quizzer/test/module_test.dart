import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/features/modules/functionality/module_updates_process.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quizzer/global/database/tables/modules_table.dart';

void main() {
  // Initialize FFI
  setUpAll(() {
    // Initialize FFI
    sqfliteFfiInit();
    // Set the database factory to use FFI
    databaseFactory = databaseFactoryFfi;
  });

  group('Module Build Process Tests', () {
    test('buildModuleRecords should build and update module records from question-answer pairs', () async {
      // Run the build function
      await buildModuleRecords();
      
      // Get all modules to verify the results
      final modules = await getAllModules();
      
      // Basic validation
      expect(modules, isA<List<Map<String, dynamic>>>());
      expect(modules, isNotNull);
      
      // Log the results for manual verification
      QuizzerLogger.logMessage('Found ${modules.length} modules in database');
      QuizzerLogger.logMessage('Modules: $modules');
      
      // Verify each module has required fields
      for (final module in modules) {
        expect(module['module_name'], isNotNull);
        expect(module['description'], isNotNull);
        expect(module['primary_subject'], isNotNull);
        expect(module['subjects'], isNotNull);
        expect(module['related_concepts'], isNotNull);
        expect(module['question_ids'], isNotNull);
        expect(module['creator_id'], isNotNull);
      }
    });
  });
} 