import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Manual iteration variable for reusing accounts across tests
  late int testIteration;
  
  // Test credentials - defined once and reused
  late String testEmail;
  late String testUsername;
  const testPassword = 'TestPassword123!';
  
  // Initialize logger and disable HTTP client warnings for tests
  setUpAll(() async {
    // Initialize the logger for tests
    await QuizzerLogger.setupLogging();
    
    // This will suppress the HTTP client warning in tests
    HttpOverrides.global = null;
    
    testIteration = DateTime.now().millisecondsSinceEpoch; // new user creation test should use a new email each time
    
    // Set up test credentials
    testEmail = 'test_user_$testIteration@example.com';
    testUsername = 'test_user_$testIteration';
  });
  
  group('Account Creation Tests', () {
    test('Brand new user should be able to create account successfully', () async {
      QuizzerLogger.logMessage('Testing successful account creation for new user');
      
      final sessionManager = getSessionManager();
      
      try {
          QuizzerLogger.logMessage('Creating account with email: $testEmail, username: $testUsername');
          final result = await sessionManager.createNewUserAccount(
            email: testEmail,
            username: testUsername,
            password: testPassword,
          );
        
        QuizzerLogger.logMessage('Account creation result: $result');
        expect(result['success'], true);
        expect(result['message'], contains('User registered successfully'));
        
        // Validate that profile was created in local database
        QuizzerLogger.logMessage('Validating local database profile creation');
        final userId = await getUserIdByEmail(testEmail);
        expect(userId, isNotNull);
        expect(userId, isNotEmpty);
        QuizzerLogger.logSuccess('Local database profile validation passed');
        
        // Validate that profile was synced to Supabase
        QuizzerLogger.logMessage('Validating Supabase profile creation');
        final supabase = sessionManager.supabase;
        
        // Wait a moment for outbound sync to complete
        await Future.delayed(const Duration(seconds: 2));
        
        // Authenticate with Supabase to bypass RLS
        QuizzerLogger.logMessage('Authenticating with Supabase for profile validation');
        final authResponse = await supabase.auth.signInWithPassword(
          email: testEmail,
          password: testPassword,
        );
        expect(authResponse.user, isNotNull);
        expect(authResponse.session, isNotNull);
        QuizzerLogger.logSuccess('Supabase authentication successful');
        
        final supabaseResponse = await supabase
            .from('user_profile')
            .select('*')
            .eq('email', testEmail)
            .limit(1);
        
        expect(supabaseResponse, isNotEmpty);
        expect(supabaseResponse.first['email'], equals(testEmail));
        expect(supabaseResponse.first['username'], equals(testUsername));
        expect(supabaseResponse.first['uuid'], equals(userId));
        QuizzerLogger.logSuccess('Supabase profile validation passed');
        
        QuizzerLogger.logSuccess('New user account creation test passed');
        
      } catch (e, stackTrace) {
        QuizzerLogger.logError('New user account creation test failed: $e');
        QuizzerLogger.logError('Stack trace: $stackTrace');
        rethrow;
      }
    });
    
    test('Existing user should not be able to create duplicate account', () async {
      QuizzerLogger.logMessage('Testing failed account creation for existing user');
      
      final sessionManager = getSessionManager();
      
      try {
        // Try to create the same account again using credentials from first test
        QuizzerLogger.logMessage('Attempting to create duplicate account with email: $testEmail');
        final result = await sessionManager.createNewUserAccount(
          email: testEmail,
          username: testUsername,
          password: testPassword,
        );
        
        QuizzerLogger.logMessage('Duplicate account creation result: $result');
        expect(result['success'], false);
        expect(result['message'], contains('already registered'));
        QuizzerLogger.logSuccess('Duplicate user account creation test passed');
        
      } catch (e, stackTrace) {
        QuizzerLogger.logError('Duplicate user account creation test failed: $e');
        QuizzerLogger.logError('Stack trace: $stackTrace');
        rethrow;
      }
    });
  });
}


