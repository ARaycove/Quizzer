import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/08_data_caches/question_queue_cache.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_module_activation_status_table.dart';
import '../test_helpers.dart';
import 'dart:io';

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
  
  // Performance tracking variables
  Duration? totalLoginTime;
  
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
  });
  
  group('Full Login Integration Tests', () {
    test('Should complete full login initialization and verify final state', () async {
      QuizzerLogger.logMessage('Testing complete login initialization and final state verification');
      
      try {
        // Step 1: Perform full login initialization
        QuizzerLogger.logMessage('Step 1: Performing full login initialization...');
        final stopwatch = Stopwatch()..start();
        
        final loginResult = await loginInitialization(
          email: testEmail, 
          password: testPassword, 
          supabase: sessionManager.supabase, 
          storage: sessionManager.getBox(testAccessPassword));
        
        stopwatch.stop();
        totalLoginTime = stopwatch.elapsed;
        
        // Verify login was successful
        expect(loginResult['success'], isTrue, reason: 'Login should be successful');
        QuizzerLogger.logSuccess('Login initialization completed successfully in ${totalLoginTime!.inMilliseconds}ms');
        
        // Step 2: Verify SessionManager state
        QuizzerLogger.logMessage('Step 2: Verifying SessionManager state...');
        expect(sessionManager.userLoggedIn, isTrue, reason: 'User should be logged in');
        expect(sessionManager.userId, isNotNull, reason: 'User ID should be set');
        expect(sessionManager.userEmail, equals(testEmail), reason: 'User email should be set');
        expect(sessionManager.sessionStartTime, isNotNull, reason: 'Session start time should be set');
        QuizzerLogger.logSuccess('SessionManager state verified');
        
        // Step 3: Verify user profile exists
        QuizzerLogger.logMessage('Step 3: Verifying user profile exists...');
        final userProfile = await getUserProfileByEmail(testEmail);
        expect(userProfile, isNotNull, reason: 'User profile should exist');
        expect(userProfile!['email'], equals(testEmail), reason: 'Profile email should match');
        QuizzerLogger.logSuccess('User profile verified');
        
        // Step 4: Verify question queue cache is accessible and functional
        QuizzerLogger.logMessage('Step 4: Verifying question queue cache is accessible and functional...');
        final QuestionQueueCache queueCache = QuestionQueueCache();
        final bool cacheIsEmpty = await queueCache.isEmpty();
        final int cacheLength = await queueCache.getLength();
        // Don't make assumptions about cache state - just verify it's functional
        QuizzerLogger.logSuccess('Queue cache is accessible and functional (empty: $cacheIsEmpty, length: $cacheLength)');
        
        // Step 5: Verify user question answer pairs table is accessible
        QuizzerLogger.logMessage('Step 5: Verifying user question answer pairs table is accessible...');
        final List<Map<String, dynamic>> userPairs = await getAllUserQuestionAnswerPairs(sessionManager.userId!);
        // User may have 0 pairs if no modules are activated, which is valid
        QuizzerLogger.logSuccess('User question answer pairs table accessible (pairs: ${userPairs.length})');
        
        // Step 6: Verify module activation status table is accessible
        QuizzerLogger.logMessage('Step 6: Verifying module activation status table is accessible...');
        final Map<String, bool> activationStatus = await getModuleActivationStatus(sessionManager.userId!);
        // User may have no activated modules initially, which is valid
        QuizzerLogger.logSuccess('Module activation status table accessible (modules: ${activationStatus.length})');
        
        QuizzerLogger.logSuccess('✅ Full login initialization and state verification completed successfully');
        
      } catch (e) {
        QuizzerLogger.logError('Full login integration test failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 10)));
    
    test('Should print complete login performance report', () async {
      QuizzerLogger.logMessage('Printing complete login performance report');
      
      try {
        QuizzerLogger.printHeader('=== COMPLETE LOGIN PERFORMANCE REPORT ===');
        
        // Log total login time
        if (totalLoginTime != null) {
          QuizzerLogger.logMessage('Total Complete Login Time: ${totalLoginTime!.inMilliseconds}ms');
        }
        
        QuizzerLogger.printHeader('=== END PERFORMANCE REPORT ===');
        
        QuizzerLogger.logSuccess('✅ Complete login performance report printed');
        
      } catch (e) {
        QuizzerLogger.logError('Complete login performance report failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

  });
}
