import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pair_flags_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/review_system/handle_question_flags.dart';
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
      noQueueServer: true //queueServer not needed for test
    );
    
    expect(loginResult['success'], isTrue, reason: 'Login initialization should succeed');
    QuizzerLogger.logSuccess('Full login initialization completed successfully');
  });
  
  group('addQuestionAnswerPairFlag', () {
    String? existingQuestionId;
    
    setUp(() async {
      // Clear question_answer_pair_flags table and ensure is empty
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db != null) {
        // First verify the table exists, then clear it
        await verifyQuestionAnswerPairFlagsTable(db);
        await db.delete('question_answer_pair_flags');
        QuizzerLogger.logMessage('Cleared question_answer_pair_flags table');
      }
      getDatabaseMonitor().releaseDatabaseAccess();
      
      // Get an existing question_id from question_answer_pair table for testing
      final randomQuestion = await getRandomQuestionAnswerPair();
      if (randomQuestion != null) {
        existingQuestionId = randomQuestion['question_id'] as String;
        QuizzerLogger.logMessage('Using existing question_id for testing: $existingQuestionId');
      } else {
        QuizzerLogger.logWarning('No existing questions found for testing');
      }
    });
    
    test('Test 1: Should reject gracefully if question_id not in question_answer_pair table', () async {
      QuizzerLogger.logMessage('Test 1: Testing rejection of random question_id');
      
      final randomQuestionId = '${DateTime.now().millisecondsSinceEpoch}_random_user';
      
      expect(
        () => addQuestionAnswerPairFlag(
          questionId: randomQuestionId,
          flagType: 'factually_incorrect',
          flagDescription: 'Test flag',
        ),
        throwsA(isA<StateError>()),
        reason: 'Should throw StateError for non-existent question_id'
      );
      
      QuizzerLogger.logSuccess('Test 1 passed: Random question_id correctly rejected');
    });
    
    test('Test 2: Should reject gracefully if invalid flag type', () async {
      QuizzerLogger.logMessage('Test 2: Testing rejection of invalid flag type');
      
      expect(
        () => addQuestionAnswerPairFlag(
          questionId: existingQuestionId!,
          flagType: 'invalid_flag_type',
          flagDescription: 'Test flag',
        ),
        throwsA(isA<StateError>()),
        reason: 'Should throw StateError for invalid flag type'
      );
      
      QuizzerLogger.logSuccess('Test 2 passed: Invalid flag type correctly rejected');
    });
    
    test('Test 3: Should succeed for all valid flag types', () async {
      QuizzerLogger.logMessage('Test 3: Testing all valid flag types');
      
      
      // Test all valid flag types
      for (final flagType in validFlagTypes) {
        final result = await addQuestionAnswerPairFlag(
          questionId: existingQuestionId!,
          flagType: flagType,
          flagDescription: 'Test flag for $flagType',
        );
        
        expect(result, greaterThan(0), reason: 'Should succeed for valid flag type: $flagType');
        QuizzerLogger.logSuccess('Successfully added flag type: $flagType');
      }
      
      QuizzerLogger.logSuccess('Test 3 passed: All valid flag types succeeded');
    });
    
    test('Test 4: Should reject when flag description is empty', () async {
      QuizzerLogger.logMessage('Test 4: Testing rejection of empty flag description');
      

      
      // The function should reject empty flag descriptions
      expect(
        () => addQuestionAnswerPairFlag(
          questionId: existingQuestionId!,
          flagType: 'factually_incorrect',
          flagDescription: '',
        ),
        throwsA(isA<StateError>()),
        reason: 'Should throw StateError for empty flag description'
      );
      
      QuizzerLogger.logSuccess('Test 4 passed: Empty flag description correctly rejected');
    });
    
    tearDown(() async {
      // Clean up: delete all records from table
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db != null) {
        // First verify the table exists, then clear it
        await verifyQuestionAnswerPairFlagsTable(db);
        await db.delete('question_answer_pair_flags');
        QuizzerLogger.logMessage('Cleaned up question_answer_pair_flags table');
      }
      getDatabaseMonitor().releaseDatabaseAccess();
    });
  });
  
  group('getUnsyncedQuestionAnswerPairFlags', () {
    setUp(() async {
      // Clear question_answer_pair_flags table and ensure is empty
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db != null) {
        // First verify the table exists, then clear it
        await verifyQuestionAnswerPairFlagsTable(db);
        await db.delete('question_answer_pair_flags');
        QuizzerLogger.logMessage('Cleared question_answer_pair_flags table');
      }
      getDatabaseMonitor().releaseDatabaseAccess();
    });
    
    test('Test 1: Should return empty list when table is empty', () async {
      QuizzerLogger.logMessage('Test 1: Testing empty table returns empty list');
      
      final result = await getUnsyncedQuestionAnswerPairFlags();
      
      expect(result, isEmpty, reason: 'Should return empty list for empty table');
      QuizzerLogger.logSuccess('Test 1 passed: Empty table correctly returns empty list');
    });
    
    test('Test 2: Should return all unsynced flags', () async {
      QuizzerLogger.logMessage('Test 2: Testing retrieval of unsynced flags');
      
      // Get 5 question_ids from question_answer_pair table
      final List<String> questionIds = [];
      for (int i = 0; i < 5; i++) {
        final randomQuestion = await getRandomQuestionAnswerPair();
        if (randomQuestion != null) {
          questionIds.add(randomQuestion['question_id'] as String);
        }
      }
      

      
      // Add one flag record for each question_id
      for (final questionId in questionIds) {
        await addQuestionAnswerPairFlag(
          questionId: questionId,
          flagType: 'factually_incorrect',
          flagDescription: 'Test flag for $questionId',
        );
      }
      
      // Call function and expect we get 5 records back matching the id's used
      final result = await getUnsyncedQuestionAnswerPairFlags();
      
      expect(result.length, equals(questionIds.length), reason: 'Should return same number of records as added');
      
      // Verify all returned records have the expected question_ids
      final List<String> returnedQuestionIds = result.map((record) => record['question_id'] as String).toList();
      for (final questionId in questionIds) {
        expect(returnedQuestionIds, contains(questionId), reason: 'Should contain question_id: $questionId');
      }
      
      QuizzerLogger.logSuccess('Test 2 passed: Successfully retrieved all unsynced flags');
    });
    
    tearDown(() async {
      // Clean up: delete all records from table
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db != null) {
        // First verify the table exists, then clear it
        await verifyQuestionAnswerPairFlagsTable(db);
        await db.delete('question_answer_pair_flags');
        QuizzerLogger.logMessage('Cleaned up question_answer_pair_flags table');
      }
      getDatabaseMonitor().releaseDatabaseAccess();
    });
  });
  
  group('deleteQuestionAnswerPairFlag', () {
    List<String> testQuestionIds = [];
    
    setUp(() async {
      // Clear question_answer_pair_flags table and ensure is empty
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db != null) {
        // First verify the table exists, then clear it
        await verifyQuestionAnswerPairFlagsTable(db);
        await db.delete('question_answer_pair_flags');
        QuizzerLogger.logMessage('Cleared question_answer_pair_flags table');
      }
      getDatabaseMonitor().releaseDatabaseAccess();
      
      // Get 5 random question_ids from question_answer_pair table for testing
      testQuestionIds = [];
      for (int i = 0; i < 5; i++) {
        final randomQuestion = await getRandomQuestionAnswerPair();
        if (randomQuestion != null) {
          testQuestionIds.add(randomQuestion['question_id'] as String);
        }
      }
      
      if (testQuestionIds.isNotEmpty) {
        // Add records for each question_id
        for (final questionId in testQuestionIds) {
          await addQuestionAnswerPairFlag(
            questionId: questionId,
            flagType: 'factually_incorrect',
            flagDescription: 'Test flag for $questionId',
          );
        }
        QuizzerLogger.logMessage('Added ${testQuestionIds.length} test flag records');
      }
    });
    
    test('Test 1: Should fail with invalid questionId', () async {
      QuizzerLogger.logMessage('Test 1: Testing failure with invalid questionId');
      
      final result = await deleteQuestionAnswerPairFlag('invalid_question_id', 'factually_incorrect');
      
      expect(result, equals(0), reason: 'Should return 0 for invalid questionId');
      QuizzerLogger.logSuccess('Test 1 passed: Invalid questionId correctly failed');
    });
    
    test('Test 2: Should fail with invalid flagType', () async {
      QuizzerLogger.logMessage('Test 2: Testing failure with invalid flagType');
      

      
      final result = await deleteQuestionAnswerPairFlag(testQuestionIds.first, 'invalid_flag_type');
      
      expect(result, equals(0), reason: 'Should return 0 for invalid flagType');
      QuizzerLogger.logSuccess('Test 2 passed: Invalid flagType correctly failed');
    });
    
    test('Test 3: Should fail with valid id but invalid flag', () async {
      QuizzerLogger.logMessage('Test 3: Testing failure with valid id but invalid flag');
      

      
      final result = await deleteQuestionAnswerPairFlag(testQuestionIds.first, 'invalid_flag_type');
      
      expect(result, equals(0), reason: 'Should return 0 for valid id but invalid flag');
      QuizzerLogger.logSuccess('Test 3 passed: Valid id with invalid flag correctly failed');
    });
    
    test('Test 4: Should fail with invalid id but valid flag', () async {
      QuizzerLogger.logMessage('Test 4: Testing failure with invalid id but valid flag');
      
      final result = await deleteQuestionAnswerPairFlag('invalid_question_id', 'factually_incorrect');
      
      expect(result, equals(0), reason: 'Should return 0 for invalid id but valid flag');
      QuizzerLogger.logSuccess('Test 4 passed: Invalid id with valid flag correctly failed');
    });
    
    test('Test 5: Should successfully delete all records with valid arguments', () async {
      QuizzerLogger.logMessage('Test 5: Testing successful deletion of all records');
      

      
      // Delete each record with valid arguments
      for (final questionId in testQuestionIds) {
        final result = await deleteQuestionAnswerPairFlag(questionId, 'factually_incorrect');
        expect(result, equals(1), reason: 'Should return 1 for successful deletion of $questionId');
      }
      
      // Verify table is empty
      final remainingRecords = await getUnsyncedQuestionAnswerPairFlags();
      expect(remainingRecords, isEmpty, reason: 'Table should be empty after all deletions');
      
      QuizzerLogger.logSuccess('Test 5 passed: Successfully deleted all records');
    });
    
    tearDown(() async {
      // Clean up: delete all records from table
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db != null) {
        // First verify the table exists, then clear it
        await verifyQuestionAnswerPairFlagsTable(db);
        await db.delete('question_answer_pair_flags');
        QuizzerLogger.logMessage('Cleaned up question_answer_pair_flags table');
      }
      getDatabaseMonitor().releaseDatabaseAccess();
    });
  });
  
  group('toggleUserQuestionFlaggedStatus', () {
    List<String> testQuestionIds = [];
    String? testUserId;
    
    setUp(() async {
      // Get existing user questions for testing
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db != null) {
        // Get a few existing user question records that are NOT flagged
        final List<Map<String, dynamic>> userQuestions = await db.rawQuery('''
          SELECT user_uuid, question_id, flagged 
          FROM user_question_answer_pairs 
          WHERE flagged = 0
          LIMIT 5
        ''');
        
        if (userQuestions.isNotEmpty) {
          testUserId = userQuestions.first['user_uuid'] as String;
          testQuestionIds = userQuestions.map((q) => q['question_id'] as String).toList();
          QuizzerLogger.logMessage('Found ${testQuestionIds.length} unflagged test questions for user: $testUserId');
        } else {
          QuizzerLogger.logWarning('No unflagged user questions found for testing');
        }
      }
      getDatabaseMonitor().releaseDatabaseAccess();
    });
    
    test('Test 1: Should fail with invalid userUuid', () async {
      QuizzerLogger.logMessage('Test 1: Testing failure with invalid userUuid');
      

      
      final result = await toggleUserQuestionFlaggedStatus(
        userUuid: 'invalid_user_uuid',
        questionId: testQuestionIds.first,
      );
      
      expect(result, isFalse, reason: 'Should return false for invalid userUuid');
      QuizzerLogger.logSuccess('Test 1 passed: Invalid userUuid correctly failed');
    });
    
    test('Test 2: Should fail with invalid questionId', () async {
      QuizzerLogger.logMessage('Test 2: Testing failure with invalid questionId');
      

      
      final result = await toggleUserQuestionFlaggedStatus(
        userUuid: testUserId!,
        questionId: 'invalid_question_id',
      );
      
      expect(result, isFalse, reason: 'Should return false for invalid questionId');
      QuizzerLogger.logSuccess('Test 2 passed: Invalid questionId correctly failed');
    });
    
    test('Test 3: Should fail with both invalid userUuid and questionId', () async {
      QuizzerLogger.logMessage('Test 3: Testing failure with both invalid userUuid and questionId');
      
      final result = await toggleUserQuestionFlaggedStatus(
        userUuid: 'invalid_user_uuid',
        questionId: 'invalid_question_id',
      );
      
      expect(result, isFalse, reason: 'Should return false for both invalid userUuid and questionId');
      QuizzerLogger.logSuccess('Test 3 passed: Both invalid arguments correctly failed');
    });
    
    test('Test 4: Should successfully toggle flagged status for multiple questions', () async {
      QuizzerLogger.logMessage('Test 4: Testing successful toggle of flagged status for multiple questions');
      

      
      // Get initial flagged statuses
      final Map<String, int> initialStatuses = {};
      for (final questionId in testQuestionIds) {
        final userRecord = await getUserQuestionAnswerPairById(testUserId!, questionId);
        initialStatuses[questionId] = userRecord['flagged'] as int? ?? 0;
      }
      
      // Toggle each question's flagged status
      for (final questionId in testQuestionIds) {
        final result = await toggleUserQuestionFlaggedStatus(
          userUuid: testUserId!,
          questionId: questionId,
        );
        
        expect(result, isTrue, reason: 'Should return true for successful toggle of $questionId');
      }
      
      // Verify the flags have been flipped
      for (final questionId in testQuestionIds) {
        final userRecord = await getUserQuestionAnswerPairById(testUserId!, questionId);
        final int newStatus = userRecord['flagged'] as int? ?? 0;
        final int originalStatus = initialStatuses[questionId]!;
        
        // Check that the status was toggled (0 -> 1 or 1 -> 0)
        expect(newStatus, equals(originalStatus == 0 ? 1 : 0), 
               reason: 'Flagged status should be toggled for $questionId');
      }
      
      // Toggle them back to original state
      for (final questionId in testQuestionIds) {
        final result = await toggleUserQuestionFlaggedStatus(
          userUuid: testUserId!,
          questionId: questionId,
        );
        
        expect(result, isTrue, reason: 'Should return true for successful toggle back of $questionId');
      }
      
      // Verify they're back to original state
      for (final questionId in testQuestionIds) {
        final userRecord = await getUserQuestionAnswerPairById(testUserId!, questionId);
        final int finalStatus = userRecord['flagged'] as int? ?? 0;
        final int originalStatus = initialStatuses[questionId]!;
        
        expect(finalStatus, equals(originalStatus), 
               reason: 'Flagged status should be back to original for $questionId');
      }
      
      QuizzerLogger.logSuccess('Test 4 passed: Successfully toggled flagged status for all test questions');
    });
    
    test('Test 5: Should affect eligibility when toggling flagged status', () async {
      QuizzerLogger.logMessage('Test 5: Testing that flagged status affects eligibility');
      

      
      // Ensure all user question answer pairs are set to flagged = 0 for this test
      final List<Map<String, dynamic>> eligibleQuestions = await getEligibleUserQuestionAnswerPairs(testUserId!);
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db != null) {
        await db.update(
          'user_question_answer_pairs',
          {'flagged': 0},
          where: 'user_uuid = ?',
          whereArgs: [testUserId!],
        );
        QuizzerLogger.logMessage('Set all user question answer pairs to flagged = 0 for user: $testUserId');
        
        // Now select 5 test questions from the currently eligible questions
        
        
        if (eligibleQuestions.isNotEmpty) {
          // Take up to 5 questions from the eligible pool
          final int numToSelect = eligibleQuestions.length > 5 ? 5 : eligibleQuestions.length;
          testQuestionIds = eligibleQuestions.take(numToSelect).map((q) => q['question_id'] as String).toList();
          QuizzerLogger.logMessage('Selected ${testQuestionIds.length} eligible test questions for flagging');
        } else {
          QuizzerLogger.logWarning('No eligible questions found for testing');
        }
      }
      getDatabaseMonitor().releaseDatabaseAccess();
      
      // Get the current count of eligible questions
      final List<Map<String, dynamic>> initialEligibleQuestions = await getEligibleUserQuestionAnswerPairs(testUserId!);
      final int initialEligibleCount = initialEligibleQuestions.length;
      QuizzerLogger.logMessage('Initial eligible questions count: $initialEligibleCount');
      
      // Flag all the selected test questions
      for (final questionId in testQuestionIds) {
        final result = await toggleUserQuestionFlaggedStatus(
          userUuid: testUserId!,
          questionId: questionId,
        );
        expect(result, isTrue, reason: 'Should successfully toggle to flagged for $questionId');
      }
      
      // Manually check that we actually got 5 records flagged == 1
      final db3 = await getDatabaseMonitor().requestDatabaseAccess();
      if (db3 != null) {
        final List<Map<String, dynamic>> flaggedRecords = await db3.rawQuery('''
          SELECT question_id, flagged 
          FROM user_question_answer_pairs 
          WHERE user_uuid = ? AND flagged = 1
        ''', [testUserId!]);
        
        expect(flaggedRecords.length, equals(testQuestionIds.length), 
               reason: 'Should have exactly ${testQuestionIds.length} flagged records');
        
        // Verify the flagged records are the ones we intended to flag
        final List<String> flaggedQuestionIds = flaggedRecords.map((r) => r['question_id'] as String).toList();
        for (final questionId in testQuestionIds) {
          expect(flaggedQuestionIds, contains(questionId), 
                 reason: 'Should have flagged question_id: $questionId');
        }
        
        QuizzerLogger.logMessage('Verified ${flaggedRecords.length} questions are flagged');
      }
      getDatabaseMonitor().releaseDatabaseAccess();
      
      // Get the eligible questions count again
      final List<Map<String, dynamic>> afterFlaggedQuestions = await getEligibleUserQuestionAnswerPairs(testUserId!);
      final int afterFlaggedCount = afterFlaggedQuestions.length;
      QuizzerLogger.logMessage('Eligible questions count after flagging: $afterFlaggedCount');
      
      // Should be original - testQuestionIds.length eligible records now
      expect(afterFlaggedCount, equals(initialEligibleCount - testQuestionIds.length), 
             reason: 'Eligible count should decrease by the number of flagged questions');
      
      // Set all questions back to unflagged = 0
      final db2 = await getDatabaseMonitor().requestDatabaseAccess();
      if (db2 != null) {
        await db2.update(
          'user_question_answer_pairs',
          {'flagged': 0},
          where: 'user_uuid = ?',
          whereArgs: [testUserId!],
        );
        QuizzerLogger.logMessage('Set all user question answer pairs back to flagged = 0 for user: $testUserId');
      }
      getDatabaseMonitor().releaseDatabaseAccess();
      
      // Verify final count matches initial count after cleanup
      final List<Map<String, dynamic>> finalEligibleQuestions = await getEligibleUserQuestionAnswerPairs(testUserId!);
      final int finalEligibleCount = finalEligibleQuestions.length;
      expect(finalEligibleCount, equals(initialEligibleCount), 
             reason: 'Final eligible count should match initial count after restoring all to unflagged');
      
      QuizzerLogger.logSuccess('Test 5 passed: Flagged status correctly affects eligibility');
    });
  });
  
  group('getFlaggedQuestionForReview', () {
    List<Map<String, dynamic>> testFlagRecords = [];
    List<Map<String, dynamic>> allTestRecords = [];
    
    test('Test 1: Should return null when supabase table is empty', () async {
      QuizzerLogger.logMessage('Test 1: Testing null response when supabase table is empty');
      
      // Check if supabase table is empty first (limit to 1 for efficiency)
      final supabase = getSessionManager().supabase;
      final response = await supabase
          .from('question_answer_pair_flags')
          .select('*')
          .or('is_reviewed.is.null,is_reviewed.eq.0')
          .limit(1);
      
      if (response.isNotEmpty) {
        QuizzerLogger.logWarning('Skipping Test 1: Supabase table is not empty');
        return;
      }
      
      // Call the function
      final result = await getFlaggedQuestionForReview();
      
      // Should return null for empty table
      expect(result, isNull, reason: 'Should return null when supabase table is empty');
      QuizzerLogger.logSuccess('Test 1 passed: Correctly returned null for empty table');
    });
    
    test('Test 2: Should return complete question flag record when records exist', () async {
      QuizzerLogger.logMessage('Test 2: Testing complete question flag record retrieval');
      
      // Get 10 real question IDs from Supabase question_answer_pairs table
      final supabaseClient = getSessionManager().supabase;
      final List<String> realQuestionIds = [];
      
      final questionResponse = await supabaseClient
          .from('question_answer_pairs')
          .select('question_id')
          .limit(10);
      
      if (questionResponse.length < 10) {
        throw StateError('Could not get 10 real question IDs from Supabase for testing');
      }
      
      for (final record in questionResponse) {
        realQuestionIds.add(record['question_id'] as String);
      }
      
      // Generate 10 test flag records using real question IDs
      for (int i = 0; i < 10; i++) {
        final testFlagRecord = {
          'question_id': realQuestionIds[i],
          'flag_type': 'factually_incorrect',
          'flag_description': 'Test flag $i',
          'is_reviewed': 0,
          'decision': null,
          'flag_id': '0', // Use '0' for unreviewed flags as per implementation
          'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
        };
        testFlagRecords.add(testFlagRecord);
        allTestRecords.add(testFlagRecord);
      }
      
      // Push test records to supabase in parallel
      final insertFutures = testFlagRecords.map((record) => 
        supabaseClient
            .from('question_answer_pair_flags')
            .insert(record)
      );
      await Future.wait(insertFutures);
      
      // Verify test records are in supabase
      final verifyResponse = await supabaseClient
          .from('question_answer_pair_flags')
          .select('*')
          .or('is_reviewed.is.null,is_reviewed.eq.0');
      
      QuizzerLogger.logMessage('Verify response: $verifyResponse');
      
      expect(verifyResponse.length, greaterThanOrEqualTo(10), 
             reason: 'Should have at least 10 test records in supabase');
      
      // Call getFlaggedQuestionForReview
      final result = await getFlaggedQuestionForReview();
      
      // Verify we got back a complete question flag record
      expect(result, isNotNull, reason: 'Should return a non-null result');
      expect(result, contains('question_data'), reason: 'Should contain question_data');
      expect(result, contains('report'), reason: 'Should contain report');
      
      final questionData = result!['question_data'] as Map<String, dynamic>;
      final report = result['report'] as Map<String, dynamic>;
      
      // Validate question_data contains expected fields from question_answer_pairs table
      expect(questionData, contains('question_id'), reason: 'Question data should contain question_id');
      
      // Validate report contains the fields that getFlaggedQuestionForReview actually returns
      expect(report, contains('question_id'), reason: 'Report should contain question_id');
      expect(report, contains('flag_type'), reason: 'Report should contain flag_type');
      expect(report, contains('flag_description'), reason: 'Report should contain flag_description');
      
      QuizzerLogger.logSuccess('Test 2 passed: Successfully retrieved complete question flag record');
    });
    
    test('Test 3: Should return random records on repeated calls', () async {
      QuizzerLogger.logMessage('Test 3: Testing randomness of returned records');
      
      // Test 3 uses the records created in Test 2, so no need to create new ones
      
      // Call getFlaggedQuestionForReview multiple times and record responses
      final List<String> returnedQuestionIds = [];
      for (int i = 0; i < 5; i++) {
        final result = await getFlaggedQuestionForReview();
        if (result != null) {
          final report = result['report'] as Map<String, dynamic>;
          final questionId = report['question_id'] as String;
          returnedQuestionIds.add(questionId);
        }
      }
      
      // Verify we got some responses
      expect(returnedQuestionIds, isNotEmpty, reason: 'Should get some responses');
      
      // Check for randomness (not all the same)
      final uniqueIds = returnedQuestionIds.toSet();
      expect(uniqueIds.length, greaterThan(1), 
             reason: 'Should return different records (random selection)');
      
      QuizzerLogger.logSuccess('Test 3 passed: Records returned are random');
    });
    
    test('Test 4: Should fetch specific record when all primary key components provided', () async {
      QuizzerLogger.logMessage('Test 4: Testing specific record fetch by primary key');
      
      // Test 4 uses the records created in Test 2, so no need to create new ones
      
      // Get a specific record from the test data
      if (allTestRecords.isNotEmpty) {
        final specificRecord = allTestRecords.first;
        final questionId = specificRecord['question_id'] as String;
        final flagType = specificRecord['flag_type'] as String;
        
        // Call getFlaggedQuestionForReview with specific primary key
        // Note: flag_id should be '0' for unreviewed records
        final result = await getFlaggedQuestionForReview(
          primaryKey: {
            'flag_id': '0', // All unreviewed records have flag_id = '0'
            'question_id': questionId,
            'flag_type': flagType,
          },
        );
        
        // Verify we got back the specific record
        expect(result, isNotNull, reason: 'Should return a non-null result');
        expect(result, contains('question_data'), reason: 'Should contain question_data');
        expect(result, contains('report'), reason: 'Should contain report');
        
        final report = result!['report'] as Map<String, dynamic>;
        
        // Verify the returned record matches the requested primary key
        expect(report['question_id'], equals(questionId), reason: 'Should return the specific question_id');
        expect(report['flag_type'], equals(flagType), reason: 'Should return the specific flag_type');
        
        QuizzerLogger.logSuccess('Test 4 passed: Successfully fetched specific record by primary key');
      } else {
        QuizzerLogger.logWarning('Skipping Test 4: No test records available');
      }
    });
    
    test('Test 5: Clean up all test records and verify', () async {
      QuizzerLogger.logMessage('Test 5: Cleaning up all test records and verifying');
      
      if (allTestRecords.isNotEmpty) {
        final supabaseClient = getSessionManager().supabase;
        
        // Delete all test records by their full primary key
        final deleteFutures = allTestRecords.map((record) => 
          supabaseClient
              .from('question_answer_pair_flags')
              .delete()
              .eq('flag_id', '0') // All test records have flag_id = '0'
              .eq('question_id', record['question_id'])
              .eq('flag_type', record['flag_type'])
        );
        await Future.wait(deleteFutures);
        QuizzerLogger.logMessage('Cleaned up all test flag records from supabase');
        
        // Verify the test records are gone
        for (final record in allTestRecords) {
          final verifyResponse = await supabaseClient
              .from('question_answer_pair_flags')
              .select('*')
              .eq('flag_id', '0') // All test records have flag_id = '0'
              .eq('question_id', record['question_id'])
              .eq('flag_type', record['flag_type']);
          
          expect(verifyResponse, isEmpty, 
                 reason: 'Test record should be deleted: ${record['question_id']}');
        }
        
        QuizzerLogger.logSuccess('Test 5 passed: All test records successfully cleaned up and verified');
      } else {
        QuizzerLogger.logWarning('Skipping Test 5: No test records to clean up');
      }
    });
    

  });
  
  group('submitQuestionReview', () {
    test('Test 1: Edit request', () async {
      QuizzerLogger.logMessage('Test 1: Testing edit request for submitQuestionReview');
      
      final supabaseClient = getSessionManager().supabase;
      
      // Create 1 flag record and 1 question_answer_pair record pushing both to supabase
      final testQuestionId = 'test_question_${DateTime.now().millisecondsSinceEpoch}';
      
      // Create test question record
      final testQuestionRecord = {
        'question_id': testQuestionId,
        'time_stamp': DateTime.now().toUtc().toIso8601String(),
        'question_elements': json.encode([{'type': 'text', 'content': 'Original question'}]),
        'answer_elements': json.encode([{'type': 'text', 'content': 'Original answer'}]),
        'module_name': 'test_module',
        'question_type': 'multiple_choice',
        'options': json.encode(['Option A', 'Option B', 'Option C']),
        'correct_option_index': 0,
        'qst_contrib': 'test_contributor',
        'has_been_reviewed': 0,
        'ans_flagged': 0,
        'flag_for_removal': 0,
        'completed': 1,
      };
      
      // Create test flag record
      final testFlagRecord = {
        'question_id': testQuestionId,
        'flag_type': 'factually_incorrect',
        'flag_description': 'Test flag for edit',
        'is_reviewed': 0,
        'decision': null,
        'flag_id': '0', // Use '0' for unreviewed flags
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      
      // Insert both records to supabase
      await supabaseClient.from('question_answer_pairs').insert(testQuestionRecord);
      await supabaseClient.from('question_answer_pair_flags').insert(testFlagRecord);
      
      // Use api to get flag record
      final flagResult = await getFlaggedQuestionForReview(
        primaryKey: {
          'flag_id': '0', // Use '0' for unreviewed flags
          'question_id': testQuestionId,
          'flag_type': 'factually_incorrect',
        },
      );
      
      expect(flagResult, isNotNull, reason: 'Should get flag record from API');
      
      // Using the return data from the api, submit an edit request
      final updatedQuestionData = {
        'question_elements': json.encode([{'type': 'text', 'content': 'Updated question'}]),
        'answer_elements': json.encode([{'type': 'text', 'content': 'Updated answer'}]),
      };
      
      final editResult = await submitQuestionReview(
        questionId: testQuestionId,
        action: 'edit',
        updatedQuestionData: updatedQuestionData,
      );
      
      expect(editResult, isTrue, reason: 'Edit request should succeed');
      
      // Query supabase for the test question_answer_pair
      final updatedQuestionResponse = await supabaseClient
          .from('question_answer_pairs')
          .select('*')
          .eq('question_id', testQuestionId)
          .single();
      
      // Confirm edit was made (both the question answer pair and the flag record)
      expect(updatedQuestionResponse['question_elements'], equals(json.encode([{'type': 'text', 'content': 'Updated question'}])));
      expect(updatedQuestionResponse['answer_elements'], equals(json.encode([{'type': 'text', 'content': 'Updated answer'}])));
      
      // Check flag record was updated
      final updatedFlagResponse = await supabaseClient
          .from('question_answer_pair_flags')
          .select('*')
          .eq('question_id', testQuestionId)
          .eq('flag_type', 'factually_incorrect')
          .single();
      
      expect(updatedFlagResponse['is_reviewed'], equals(1));
      expect(updatedFlagResponse['decision'], equals('edit'));
      expect(updatedFlagResponse['flag_id'], isNotNull);
      
      // Delete both test records
      await supabaseClient
          .from('question_answer_pairs')
          .delete()
          .eq('question_id', testQuestionId);
      
      await supabaseClient
          .from('question_answer_pair_flags')
          .delete()
          .eq('question_id', testQuestionId)
          .eq('flag_type', 'factually_incorrect');
      
      QuizzerLogger.logSuccess('Test 1 passed: Edit request successfully processed');
    });
    
    test('Test 2: Delete request', () async {
      QuizzerLogger.logMessage('Test 2: Testing delete request for submitQuestionReview');
      
      final supabaseClient = getSessionManager().supabase;
      
      // Create 1 flag record and 1 question_answer_pair record pushing both to supabase
      final testQuestionId = 'test_question_delete_${DateTime.now().millisecondsSinceEpoch}';
      
      // Create test question record
      final testQuestionRecord = {
        'question_id': testQuestionId,
        'time_stamp': DateTime.now().toUtc().toIso8601String(),
        'question_elements': json.encode([{'type': 'text', 'content': 'Question to delete'}]),
        'answer_elements': json.encode([{'type': 'text', 'content': 'Answer to delete'}]),
        'module_name': 'test_module',
        'question_type': 'multiple_choice',
        'options': json.encode(['Option A', 'Option B']),
        'correct_option_index': 0,
        'qst_contrib': 'test_contributor',
        'has_been_reviewed': 0,
        'ans_flagged': 0,
        'flag_for_removal': 0,
        'completed': 1,
      };
      
      // Create test flag record
      final testFlagRecord = {
        'question_id': testQuestionId,
        'flag_type': 'factually_incorrect',
        'flag_description': 'Test flag for delete',
        'is_reviewed': 0,
        'decision': null,
        'flag_id': '0', // Use '0' for unreviewed flags
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      
      // Insert both records to supabase
      await supabaseClient.from('question_answer_pairs').insert(testQuestionRecord);
      await supabaseClient.from('question_answer_pair_flags').insert(testFlagRecord);
      
      // Use api to get flag record
      final flagResult = await getFlaggedQuestionForReview(
        primaryKey: {
          'flag_id': '0', // Use '0' for unreviewed flags
          'question_id': testQuestionId,
          'flag_type': 'factually_incorrect',
        },
      );
      
      expect(flagResult, isNotNull, reason: 'Should get flag record from API');
      
      // Submit delete request
      final deleteResult = await submitQuestionReview(
        questionId: testQuestionId,
        action: 'delete',
        updatedQuestionData: testQuestionRecord, // Original data for old_data_record
      );
      
      expect(deleteResult, isTrue, reason: 'Delete request should succeed');
      
      // Validate flag exists (direct query)
      final flagResponse = await supabaseClient
          .from('question_answer_pair_flags')
          .select('*')
          .eq('question_id', testQuestionId)
          .eq('flag_type', 'factually_incorrect');
      
      expect(flagResponse, isNotEmpty, reason: 'Flag record should still exist');
      expect(flagResponse.first['is_reviewed'], equals(1));
      expect(flagResponse.first['decision'], equals('delete'));
      expect(flagResponse.first['old_data_record'], isNotNull);
      
      // Validate old record was deleted (direct query)
      final questionResponse = await supabaseClient
          .from('question_answer_pairs')
          .select('*')
          .eq('question_id', testQuestionId);
      
      expect(questionResponse, isEmpty, reason: 'Question record should be deleted');
      
      // Delete test flag record
      await supabaseClient
          .from('question_answer_pair_flags')
          .delete()
          .eq('question_id', testQuestionId)
          .eq('flag_type', 'factually_incorrect');
      
      QuizzerLogger.logSuccess('Test 2 passed: Delete request successfully processed');
    });
    
    test('Test 3: Should reject invalid action', () async {
      QuizzerLogger.logMessage('Test 3: Testing rejection of invalid action');
      
      final result = await submitQuestionReview(
        questionId: 'test_question',
        action: 'invalid_action',
        updatedQuestionData: {},
      );
      
      expect(result, isFalse, reason: 'Should return false for invalid action');
      
      QuizzerLogger.logSuccess('Test 3 passed: Invalid action correctly rejected');
    });
  });
  
  group('addQuestionFlag API', () {
    test('Test 1: Should successfully add flag to local DB and mark question as flagged', () async {
      QuizzerLogger.logMessage('Test 1: Testing successful addQuestionFlag API call');
      
      final sessionManager = getSessionManager();
      
      // Create a test question record
      final testQuestionId = 'test_question_api_${DateTime.now().millisecondsSinceEpoch}';
      final testQuestionRecord = {
        'question_id': testQuestionId,
        'time_stamp': DateTime.now().toUtc().toIso8601String(),
        'question_elements': json.encode([{'type': 'text', 'content': 'Test question'}]),
        'answer_elements': json.encode([{'type': 'text', 'content': 'Test answer'}]),
        'module_name': 'test_module',
        'question_type': 'multiple_choice',
        'options': json.encode(['Option A', 'Option B']),
        'correct_option_index': 0,
        'qst_contrib': 'test_contributor',
        'has_been_reviewed': 0,
        'ans_flagged': 0,
        'flag_for_removal': 0,
        'completed': 1,
      };
      
      // Add question to local database (required for validation)
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db != null) {
        // Add question to local question_answer_pairs table
        await db.insert('question_answer_pairs', testQuestionRecord);
        
        // Add user question record to local database
        await db.insert('user_question_answer_pairs', {
          'user_uuid': sessionManager.userId,
          'question_id': testQuestionId,
          'flagged': 0,
          'revision_streak': 0,
          'in_circulation': 1,
          'total_attempts': 0,
        });
      }
      getDatabaseMonitor().releaseDatabaseAccess();
      
      // Call the addQuestionFlag API
      final result = await sessionManager.addQuestionFlag(
        questionId: testQuestionId,
        flagType: 'factually_incorrect',
        flagDescription: 'Test flag via API',
      );
      
      expect(result, isTrue, reason: 'API call should return true for successful flag addition');
      
      // Verify flag was added to local database (it syncs outbound later)
      final db3 = await getDatabaseMonitor().requestDatabaseAccess();
      if (db3 != null) {
        final flagResponse = await db3.query(
          'question_answer_pair_flags',
          where: 'question_id = ? AND flag_type = ?',
          whereArgs: [testQuestionId, 'factually_incorrect'],
        );
        
        expect(flagResponse, isNotEmpty, reason: 'Flag record should exist in local database');
        expect(flagResponse.first['flag_description'], equals('Test flag via API'));
        expect(flagResponse.first['has_been_synced'], equals(0), reason: 'Flag should be marked as unsynced');
      }
      getDatabaseMonitor().releaseDatabaseAccess();
      
      // Verify user question was marked as flagged
      final userQuestionResponse = await getUserQuestionAnswerPairById(sessionManager.userId!, testQuestionId);
      expect(userQuestionResponse['flagged'], equals(1), reason: 'User question should be marked as flagged');
      
      // Clean up local database records
      final db2 = await getDatabaseMonitor().requestDatabaseAccess();
      if (db2 != null) {
        // Clean up local question record
        await db2.delete(
          'question_answer_pairs',
          where: 'question_id = ?',
          whereArgs: [testQuestionId],
        );
        
        // Clean up local flag record
        await db2.delete(
          'question_answer_pair_flags',
          where: 'question_id = ? AND flag_type = ?',
          whereArgs: [testQuestionId, 'factually_incorrect'],
        );
        
        // Clean up user question record
        await db2.delete(
          'user_question_answer_pairs',
          where: 'user_uuid = ? AND question_id = ?',
          whereArgs: [sessionManager.userId, testQuestionId],
        );
        QuizzerLogger.logMessage('Cleaned up local database records');
      }
      getDatabaseMonitor().releaseDatabaseAccess();
      
      QuizzerLogger.logSuccess('Test 1 passed: addQuestionFlag API successfully added flag to local DB and marked question as flagged');
    });
    
    test('Test 2: Should fail when user is not logged in', () async {
      QuizzerLogger.logMessage('Test 2: Testing addQuestionFlag API failure when user not logged in');
      
      // Create a new session manager without login
      final sessionManager = SessionManager();
      
      final result = await sessionManager.addQuestionFlag(
        questionId: 'test_question',
        flagType: 'factually_incorrect',
        flagDescription: 'Test flag',
      );
      
      expect(result, isFalse, reason: 'Should return false when user is not logged in');
      
      QuizzerLogger.logSuccess('Test 2 passed: addQuestionFlag API correctly fails when user not logged in');
    });
    
    test('Test 3: Should fail when flag addition fails', () async {
      QuizzerLogger.logMessage('Test 3: Testing addQuestionFlag API failure when flag addition fails');
      
      final sessionManager = getSessionManager();
      
      // Try to add flag for non-existent question
      final result = await sessionManager.addQuestionFlag(
        questionId: 'non_existent_question_id',
        flagType: 'factually_incorrect',
        flagDescription: 'Test flag',
      );
      
      expect(result, isFalse, reason: 'Should return false when flag addition fails');
      
      QuizzerLogger.logSuccess('Test 3 passed: addQuestionFlag API correctly returns false when flag addition fails');
    });
  });
}
