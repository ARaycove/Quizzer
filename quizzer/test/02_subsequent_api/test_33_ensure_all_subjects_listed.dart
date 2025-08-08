import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/academic_archive.dart/subject_details_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/outbound_sync/outbound_sync_functions.dart';
import '../test_helpers.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Manual iteration variable for reusing accounts across tests
  late int testIteration;
  
  // Test credentials - defined once and reused
  late String testEmail;
  late String testPassword;
  late String testAccessPassword;
  
  // Global instances used across tests
  late final SessionManager sessionManager;
  
  setUpAll(() async {
    await QuizzerLogger.setupLogging();
    HttpOverrides.global = null;
    
    // Load test configuration
    final config = await getTestConfig();
    testIteration = config['testIteration'] as int;
    testPassword = config['testPassword'] as String;
    testAccessPassword = config['testAccessPassword'] as String;
    
    // Set up test credentials
    testEmail = 'test_user_$testIteration@example.com';
    
    sessionManager = getSessionManager();
    await sessionManager.initializationComplete;
    
    // Perform full login initialization (excluding sync workers for testing)
    final loginResult = await loginInitialization(
      email: testEmail, 
      password: testPassword, 
      supabase: sessionManager.supabase, 
      storage: sessionManager.getBox(testAccessPassword),
      testRun: true, // This bypasses sync workers for faster testing
    );
    
    expect(loginResult['success'], isTrue, reason: 'Login initialization should succeed');
    QuizzerLogger.logSuccess('Full login initialization completed successfully');
  });
  
  group('Subject Taxonomy Tests', skip: 'Bypassing Subject Taxonomy, this test only needs to be run when taxonomy get\'s updated', () {
    // DISABLED: Subject Taxonomy Tests - lengthy test that doesn't need to run every time
    // Global variable to store all subjects with their immediate parents
    List<Map<String, String>>? allSubjectsWithParents;
    
    test('Test 1: Recursively extract all subjects from taxonomy JSON with their immediate parents', () async {
      QuizzerLogger.logMessage('=== Test 1: Recursively extract all subjects from taxonomy JSON with their immediate parents ===');
      
      try {
        // Extract all subjects using the helper function
        allSubjectsWithParents = await extractAllSubjectsFromTaxonomy();
        
        QuizzerLogger.logMessage('Successfully loaded subject taxonomy JSON');
        
        // Save the extracted subjects to a JSON file for examination
        final outputFile = File('test/extracted_subjects.json');
        final jsonString = const JsonEncoder.withIndent('  ').convert(allSubjectsWithParents);
        await outputFile.writeAsString(jsonString);
        
        // Log the results
        QuizzerLogger.logMessage('Total subjects extracted: ${allSubjectsWithParents!.length}');
        QuizzerLogger.logMessage('Saved to: ${outputFile.absolute.path}');
        QuizzerLogger.logMessage('First 10 subjects:');
        for (int i = 0; i < allSubjectsWithParents!.length && i < 10; i++) {
          final subject = allSubjectsWithParents![i];
          QuizzerLogger.logMessage('  ${i + 1}. Subject: "${subject['subject']}", Parent: "${subject['immediate_parent']}"');
        }
        
        if (allSubjectsWithParents!.length > 10) {
          QuizzerLogger.logMessage('... and ${allSubjectsWithParents!.length - 10} more subjects');
        }
        
        // Verify we got some results
        expect(allSubjectsWithParents, isNotNull, reason: 'Should have extracted subjects');
        expect(allSubjectsWithParents!.length, greaterThan(0), reason: 'Should have extracted at least one subject');
        
        QuizzerLogger.logSuccess('✅ Successfully extracted ${allSubjectsWithParents!.length} subjects from taxonomy and saved to JSON file');
        
      } catch (e) {
        QuizzerLogger.logError('Test 1 failed: $e');
        rethrow;
      }
    });
    
    test('Test 2: Insert all extracted subjects into subject_details table with null descriptions', () async {
      QuizzerLogger.logMessage('=== Test 2: Insert all extracted subjects into subject_details table with null descriptions ===');
      
      try {
        // Ensure we have the subjects from Test 1
        expect(allSubjectsWithParents, isNotNull, reason: 'Test 1 must run first to extract subjects');
        expect(allSubjectsWithParents!.isNotEmpty, isTrue, reason: 'Must have subjects to insert');
        
        final int taxonomySubjectCount = allSubjectsWithParents!.length;
        final int uniqueSubjectCount = await getUniqueSubjectCountFromTaxonomy();
        QuizzerLogger.logMessage('Taxonomy subject count (total): $taxonomySubjectCount');
        QuizzerLogger.logMessage('Unique subjects count: $uniqueSubjectCount');
        QuizzerLogger.logMessage('Inserting $taxonomySubjectCount subjects into subject_details table...');
        
        int insertedCount = 0;
        int skippedCount = 0;
        
        // FIRST PASS: Insert all subjects with single parent (as before)
        QuizzerLogger.logMessage('=== FIRST PASS: Inserting subjects with single parent ===');
        
        for (final subjectData in allSubjectsWithParents!) {
          try {
            final String subjectName = subjectData['subject']!;
            final String? rawImmediateParent = subjectData['immediate_parent']!.isEmpty ? null : subjectData['immediate_parent'];
            
            // Convert single parent to JSON string list format
            String? immediateParentJson;
            if (rawImmediateParent != null) {
              immediateParentJson = jsonEncode([rawImmediateParent]);
            }
            
            // Check if record already exists
            final existingRecord = await getSubjectDetail(subjectName);
            
            if (existingRecord == null) {
              // Insert new record with null description
              await insertSubjectDetail(
                subject: subjectName,
                immediateParent: immediateParentJson,
                subjectDescription: null, // NULL as requested for admin to fill out
              );
              insertedCount++;
            } else {
              // Check if the existing record needs updating
              final existingImmediateParent = existingRecord['immediate_parent'];
              final needsUpdate = existingImmediateParent != immediateParentJson;
              
              if (needsUpdate) {
                // Update existing record with just immediate_parent
                await updateSubjectDetail(
                  subject: subjectName,
                  immediateParent: immediateParentJson,
                );
                insertedCount++;
              } else {
                // No update needed, but still count as processed
                insertedCount++;
              }
            }
          } catch (e) {
            QuizzerLogger.logWarning('Failed to insert/update subject "${subjectData['subject']}": $e');
            skippedCount++;
          }
        }
        
        QuizzerLogger.logMessage('First pass complete:');
        QuizzerLogger.logMessage('  - Successfully processed: $insertedCount subjects');
        QuizzerLogger.logMessage('  - Skipped/failed: $skippedCount subjects');
        
        // SECOND PASS: Handle duplicates by updating with JSON list of all parents
        QuizzerLogger.logMessage('=== SECOND PASS: Handling duplicates with multiple parents ===');
        
        // Get duplicate subjects from taxonomy
        final Map<String, List<String>> duplicateSubjects = await extractDuplicateSubjectsFromTaxonomy();
        QuizzerLogger.logMessage('Found ${duplicateSubjects.length} subjects with multiple parents');
        
        int duplicateUpdateCount = 0;
        
        for (final entry in duplicateSubjects.entries) {
          try {
            final String subjectName = entry.key;
            final List<String> allParents = entry.value;
            
            // Convert list to JSON string
            final String parentsJsonString = jsonEncode(allParents);
            
            // Update the subject with the JSON list of all parents
            await updateSubjectDetail(
              subject: subjectName,
              immediateParent: parentsJsonString,
            );
            duplicateUpdateCount++;
            
            QuizzerLogger.logMessage('Updated "$subjectName" with parents: $allParents');
          } catch (e) {
            QuizzerLogger.logWarning('Failed to update duplicate subject "${entry.key}": $e');
          }
        }
        
        QuizzerLogger.logMessage('Second pass complete:');
        QuizzerLogger.logMessage('  - Updated duplicates: $duplicateUpdateCount subjects');
        
        // Get final table state
        final allSubjectsInTable = await getAllSubjectDetails();
        final int tableSubjectCount = allSubjectsInTable.length;
        QuizzerLogger.logMessage('Total subjects in table: $tableSubjectCount');
        
        // Check that all subjects from taxonomy are in the table
        final taxonomySubjectNames = allSubjectsWithParents!.map((s) => s['subject']!).toSet();
        final tableSubjectNames = allSubjectsInTable.map((s) => s['subject']!).toSet();
        
        final missingSubjects = taxonomySubjectNames.difference(tableSubjectNames);
        final int missingSubjectCount = missingSubjects.length;
        QuizzerLogger.logMessage('Missing subjects: $missingSubjectCount');
        
        if (missingSubjects.isNotEmpty) {
          QuizzerLogger.logError('Missing subjects in table: $missingSubjectCount');
          for (final missing in missingSubjects.take(10)) {
            QuizzerLogger.logError('  - $missing');
          }
        }
        
        // VALIDATE ALL FOUR VALUES
        QuizzerLogger.logMessage('=== FINAL VALIDATION ===');
        QuizzerLogger.logMessage('1. Taxonomy subject count (total): $taxonomySubjectCount');
        QuizzerLogger.logMessage('2. Unique subjects count: $uniqueSubjectCount');
        QuizzerLogger.logMessage('3. Table subject count: $tableSubjectCount');
        QuizzerLogger.logMessage('4. Insertions count: $insertedCount');
        QuizzerLogger.logMessage('5. Missing subjects count: $missingSubjectCount');
        QuizzerLogger.logMessage('6. Duplicate updates count: $duplicateUpdateCount');
        
        // Updated expectations based on unique subjects
        expect(tableSubjectCount, equals(uniqueSubjectCount),
               reason: 'Table should have exactly $uniqueSubjectCount unique subjects, but has $tableSubjectCount');
        expect(insertedCount, equals(taxonomySubjectCount),
               reason: 'Should have processed exactly $taxonomySubjectCount subjects (including duplicates), but processed $insertedCount');
        expect(missingSubjectCount, equals(0),
               reason: 'Should have 0 missing subjects, but has $missingSubjectCount');
        
        QuizzerLogger.logSuccess('✅ All values match: $uniqueSubjectCount unique subjects in table, $taxonomySubjectCount total processed');
        QuizzerLogger.logSuccess('✅ Updated $duplicateUpdateCount subjects with multiple parents as JSON lists');
        
      } catch (e) {
        QuizzerLogger.logError('Test 2 failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
    
    test('Test 3: Examine for duplicate subjects in taxonomy', () async {
      QuizzerLogger.logMessage('=== Test 3: Examine for duplicate subjects in taxonomy ===');
      
      try {
        // Extract duplicate subjects using the helper function
        final Map<String, List<String>> duplicateSubjects = await extractDuplicateSubjectsFromTaxonomy();
        
        QuizzerLogger.logMessage('Found ${duplicateSubjects.length} subjects with multiple parents');
        
        // Save the duplicate subjects to a JSON file for examination
        final outputFile = File('test/duplicate_subjects.json');
        final jsonString = const JsonEncoder.withIndent('  ').convert(duplicateSubjects);
        await outputFile.writeAsString(jsonString);
        
        // Log the results
        QuizzerLogger.logMessage('Saved duplicates to: ${outputFile.absolute.path}');
        QuizzerLogger.logMessage('First 10 duplicate subjects:');
        int count = 0;
        for (final entry in duplicateSubjects.entries) {
          if (count >= 10) break;
          QuizzerLogger.logMessage('  ${count + 1}. Subject: "${entry.key}"');
          QuizzerLogger.logMessage('     Parents: ${entry.value.join(', ')}');
          count++;
        }
        
        if (duplicateSubjects.length > 10) {
          QuizzerLogger.logMessage('... and ${duplicateSubjects.length - 10} more duplicate subjects');
        }
        
        // Verify we got some results (or none, depending on the taxonomy)
        expect(duplicateSubjects, isNotNull, reason: 'Should have extracted duplicate subjects data');
        
        QuizzerLogger.logSuccess('✅ Successfully extracted ${duplicateSubjects.length} duplicate subjects from taxonomy and saved to JSON file');
        
      } catch (e) {
        QuizzerLogger.logError('Test 3 failed: $e');
        rethrow;
      }
    });
    
    test('Test 4: Test all CRUD operations on subject_details table via Supabase', () async {
      QuizzerLogger.logMessage('=== Test 4: Test all CRUD operations on subject_details table via Supabase ===');
      
      try {
        final sessionManager = getSessionManager();
        final supabase = sessionManager.supabase;
        
        // Test data
        const String testSubject = 'Test Subject CRUD';
        const String testParent = '["Test Parent"]';
        const String testDescription = 'Initial description';
        final String updatedDescription = 'Updated description ${DateTime.now().millisecondsSinceEpoch}';
        
        QuizzerLogger.logMessage('Testing CRUD operations for subject: $testSubject');
        
        // 1. INSERT - Add a record
        QuizzerLogger.logMessage('1. Testing INSERT...');
        await supabase
            .from('subject_details')
            .insert({
              'subject': testSubject,
              'immediate_parent': testParent,
              'subject_description': testDescription,
            });
        QuizzerLogger.logSuccess('✅ INSERT successful');
        
        // 2. SELECT - Get the record to verify it was added
        QuizzerLogger.logMessage('2. Testing SELECT after INSERT...');
        final insertedRecord = await supabase
            .from('subject_details')
            .select()
            .eq('subject', testSubject)
            .single();
        
        expect(insertedRecord['subject'], equals(testSubject));
        expect(insertedRecord['immediate_parent'], equals(testParent));
        expect(insertedRecord['subject_description'], equals(testDescription));
        QuizzerLogger.logSuccess('✅ SELECT after INSERT successful - record verified');
        
        // 3. UPDATE - Update the record with random description
        QuizzerLogger.logMessage('3. Testing UPDATE...');
        await supabase
            .from('subject_details')
            .update({
              'subject_description': updatedDescription,
            })
            .eq('subject', testSubject);
        QuizzerLogger.logSuccess('✅ UPDATE successful');
        
        // 4. SELECT - Get the record and check for the update
        QuizzerLogger.logMessage('4. Testing SELECT after UPDATE...');
        final updatedRecord = await supabase
            .from('subject_details')
            .select()
            .eq('subject', testSubject)
            .single();
        
        expect(updatedRecord['subject'], equals(testSubject));
        expect(updatedRecord['immediate_parent'], equals(testParent));
        expect(updatedRecord['subject_description'], equals(updatedDescription));
        QuizzerLogger.logSuccess('✅ SELECT after UPDATE successful - update verified');
        
        // 5. DELETE - Delete the record
        QuizzerLogger.logMessage('5. Testing DELETE...');
        await supabase
            .from('subject_details')
            .delete()
            .eq('subject', testSubject);
        QuizzerLogger.logSuccess('✅ DELETE successful');
        
        // 6. SELECT - Try to get the record (should not exist)
        QuizzerLogger.logMessage('6. Testing SELECT after DELETE (should fail)...');
        final selectAfterDeleteResult = await supabase
            .from('subject_details')
            .select()
            .eq('subject', testSubject)
            .maybeSingle();
        
        // This should return null since the record was deleted
        expect(selectAfterDeleteResult, isNull);
        QuizzerLogger.logSuccess('✅ SELECT after DELETE successful - record confirmed deleted');
        
        QuizzerLogger.logSuccess('✅ All CRUD operations completed successfully');
        
      } catch (e) {
        QuizzerLogger.logError('Test 4 failed: $e');
        rethrow;
      }
    });
    
    test('Test 5: Push all subject_details records to Supabase', () async {
      QuizzerLogger.logMessage('=== Test 5: Push all subject_details records to Supabase ===');
      
      try {
        // Get all records from local subject_details table
        final List<Map<String, dynamic>> allSubjectDetails = await getAllSubjectDetails();
        QuizzerLogger.logMessage('Found ${allSubjectDetails.length} subject details in local table');
        
        if (allSubjectDetails.isEmpty) {
          QuizzerLogger.logWarning('No subject details found in local table. Skipping push to Supabase.');
          return;
        }
        
        // Get all local subject names for batching
        final List<String> localSubjectNames = allSubjectDetails.map((record) => record['subject'] as String).toList();
        QuizzerLogger.logMessage('Checking ${localSubjectNames.length} subjects against Supabase in batches...');
        
        // Create batches of 500 subjects each
        const int batchSize = 500;
        final List<List<String>> subjectBatches = [];
        for (int i = 0; i < localSubjectNames.length; i += batchSize) {
          final int endIndex = (i + batchSize < localSubjectNames.length) ? i + batchSize : localSubjectNames.length;
          subjectBatches.add(localSubjectNames.sublist(i, endIndex));
        }
        
        QuizzerLogger.logMessage('Created ${subjectBatches.length} batches of up to $batchSize subjects each');
        
        // Get all subjects from Supabase in batches
        final Map<String, Map<String, dynamic>> supabaseSubjectsMap = {};
        final supabase = sessionManager.supabase;
        
        for (int batchIndex = 0; batchIndex < subjectBatches.length; batchIndex++) {
          final List<String> batch = subjectBatches[batchIndex];
          QuizzerLogger.logMessage('Fetching batch ${batchIndex + 1}/${subjectBatches.length} (${batch.length} subjects)...');
          
          final List<dynamic> supabaseRecords = await supabase
              .from('subject_details')
              .select('subject, immediate_parent, subject_description, last_modified_timestamp')
              .inFilter('subject', batch);
          
          // Add to our lookup map
          for (final record in supabaseRecords) {
            final String subject = record['subject'] as String;
            supabaseSubjectsMap[subject] = Map<String, dynamic>.from(record);
          }
        }
        
        QuizzerLogger.logMessage('Found ${supabaseSubjectsMap.length} subjects in Supabase');
        
        // Compare local records with Supabase records
        final List<Map<String, dynamic>> recordsToPush = [];
        int missingCount = 0;
        int differentCount = 0;
        
        for (final localRecord in allSubjectDetails) {
          final String subjectName = localRecord['subject'];
          final supabaseRecord = supabaseSubjectsMap[subjectName];
          
          bool needsPush = false;
          if (supabaseRecord == null) {
            // Record doesn't exist in Supabase, needs to be pushed
            needsPush = true;
            missingCount++;
            if (missingCount <= 10) { // Only log first 10 for performance
              QuizzerLogger.logMessage('Subject "$subjectName" not in Supabase - will push');
            }
          } else {
            // Record exists, check if it needs updating
            final localParent = localRecord['immediate_parent'];
            final supabaseParent = supabaseRecord['immediate_parent'];
            final localDescription = localRecord['subject_description'];
            final supabaseDescription = supabaseRecord['subject_description'];
            final localTimestamp = localRecord['last_modified_timestamp'];
            final supabaseTimestamp = supabaseRecord['last_modified_timestamp'];
            
            if (localParent != supabaseParent || 
                localDescription != supabaseDescription ||
                localTimestamp != supabaseTimestamp) {
              needsPush = true;
              differentCount++;
              if (differentCount <= 10) { // Only log first 10 for performance
                QuizzerLogger.logMessage('Subject "$subjectName" differs in Supabase - will update');
              }
            }
          }
          
          if (needsPush) {
            recordsToPush.add(localRecord);
          }
        }
        
        if (missingCount > 10) {
          QuizzerLogger.logMessage('... and ${missingCount - 10} more missing subjects');
        }
        if (differentCount > 10) {
          QuizzerLogger.logMessage('... and ${differentCount - 10} more different subjects');
        }
        
        QuizzerLogger.logMessage('Found ${recordsToPush.length} records that need to be pushed out of ${allSubjectDetails.length} total');
        
        if (recordsToPush.isEmpty) {
          QuizzerLogger.logSuccess('✅ All subject details are already up to date in Supabase');
          return;
        }
        
        // Push records in parallel batches
        QuizzerLogger.logMessage('Pushing ${recordsToPush.length} records to Supabase...');
        const int pushBatchSize = 200; // Process 200 records at a time
        int successCount = 0;
        int failureCount = 0;
        
        for (int i = 0; i < recordsToPush.length; i += pushBatchSize) {
          final int endIndex = (i + pushBatchSize < recordsToPush.length) ? i + pushBatchSize : recordsToPush.length;
          final List<Map<String, dynamic>> batch = recordsToPush.sublist(i, endIndex);
          
          // Create futures for parallel execution
          final List<Future<bool>> pushFutures = batch.map((record) async {
            try {
              return await pushRecordToSupabase('subject_details', record);
            } catch (e) {
              QuizzerLogger.logError('Error pushing subject ${record['subject']}: $e');
              return false;
            }
          }).toList();
          
          // Wait for all pushes in this batch to complete
          final List<bool> results = await Future.wait(pushFutures);
          
          // Count successes and failures
          for (int j = 0; j < results.length; j++) {
            if (results[j]) {
              successCount++;
            } else {
              failureCount++;
              QuizzerLogger.logWarning('Failed to push subject: ${batch[j]['subject']}');
            }
          }
          
          QuizzerLogger.logMessage('Batch ${(i ~/ pushBatchSize) + 1} complete: ${results.where((r) => r).length}/${batch.length} successful');
        }
        
        QuizzerLogger.logMessage('Push results: $successCount successful, $failureCount failed');
        
        if (failureCount > 0) {
          throw Exception('Failed to push $failureCount subject details to Supabase');
        }
        
        QuizzerLogger.logSuccess('✅ Successfully pushed all $successCount subject details to Supabase');
        
      } catch (e) {
        QuizzerLogger.logError('Test 5 failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 10)));
  });
}
