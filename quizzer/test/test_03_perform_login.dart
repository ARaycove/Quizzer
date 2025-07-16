import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/02_login_authentication/user_auth.dart';
import 'package:quizzer/backend_systems/02_login_authentication/offline_login.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_attempts_record.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/system_data/login_attempts_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'test_helpers.dart';
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
  
  group('Login Form Validation Tests', () {
    test('Valid email and password should pass validation', () async {
      QuizzerLogger.logMessage('Testing valid email and password validation');
      
      final result = validateLoginForm(testEmail, testPassword);
      
      QuizzerLogger.logMessage('Validation result: $result');
      expect(result['valid'], true);
      expect(result['message'], 'Validation successful');
      QuizzerLogger.logSuccess('Valid credentials test passed');
    });
    
    test('Empty email should fail validation', () async {
      QuizzerLogger.logMessage('Testing empty email validation');
      
      final result = validateLoginForm('', testPassword);
      
      QuizzerLogger.logMessage('Validation result: $result');
      expect(result['valid'], false);
      expect(result['message'], 'Please enter your email address');
      QuizzerLogger.logSuccess('Empty email test passed');
    });
    
    test('Empty password should fail validation', () async {
      QuizzerLogger.logMessage('Testing empty password validation');
      
      final result = validateLoginForm(testEmail, '');
      
      QuizzerLogger.logMessage('Validation result: $result');
      expect(result['valid'], false);
      expect(result['message'], 'Please enter your password');
      QuizzerLogger.logSuccess('Empty password test passed');
    });
    
    test('Invalid email formats should fail validation', () async {
      QuizzerLogger.logMessage('Testing various invalid email formats');
      
      // Test various invalid email formats to stress test the validation
      final invalidEmails = [
        'invalid-email',           // No @ symbol
        'test@',                   // Missing domain
        '@example.com',            // Missing local part
        'test..test@example.com',  // Double dots in local part
        'test@.com',               // Missing domain name
        'test@example.',           // Missing TLD
        'test@example..com',       // Double dots in domain
        'test@@example.com',       // Double @ symbols
        'test@example@com',        // Multiple @ symbols
        'test@example_com',        // Underscore in domain (invalid)
        'test@example-.com',       // Hyphen at end of domain (invalid)
        'test@-example.com',       // Hyphen at start of domain (invalid)
        'test@example.com-',       // Hyphen at end of domain (invalid)
        'test@example.com.',       // Trailing dot (invalid)
        '.test@example.com',       // Leading dot in local part (invalid)
        'test@example.com ',       // Trailing space
        ' test@example.com',       // Leading space
        'test @example.com',       // Space before @
        'test@ example.com',       // Space after @
      ];
      
      for (int i = 0; i < invalidEmails.length; i++) {
        final invalidEmail = invalidEmails[i];
        QuizzerLogger.logMessage('Testing invalid email $i: "$invalidEmail"');
        
        final result = validateLoginForm(invalidEmail, testPassword);
        
        QuizzerLogger.logMessage('Result for "$invalidEmail": $result');
        expect(result['valid'], false, reason: 'Email "$invalidEmail" should be invalid');
        expect(result['message'], 'Please enter a valid email address', 
               reason: 'Email "$invalidEmail" should return validation error message');
      }
      
      QuizzerLogger.logSuccess('All invalid email format tests passed');
    });
  });

  group('Direct Supabase Authentication Tests', () {
    test('Valid credentials should authenticate successfully', () async {
      QuizzerLogger.logMessage('Testing successful Supabase authentication with valid credentials');
      
      try {
        // Step 1: Clear Hive storage to ensure clean state
        QuizzerLogger.logMessage('Clearing Hive storage for clean test state');
        await sessionManager.clearStorage();
        
        // Step 2: Perform authentication
        QuizzerLogger.logMessage('Attempting Supabase authentication');
        final result = await attemptSupabaseLogin(testEmail, testPassword, sessionManager.supabase, sessionManager.getBox(testAccessPassword));
        
        QuizzerLogger.logMessage('Authentication result: $result');
        expect(result['success'], true);
        expect(result['message'], 'Login successful');
        expect(result['user'], isNotNull);
        expect(result['session'], isNotNull);
        expect(result['user_role'], isNotNull);
        
        // Step 3: Validate that offline login data was recorded
        QuizzerLogger.logMessage('Validating offline login data was recorded');
        final storage = sessionManager.getBox(testAccessPassword);
        
        // Log the entire contents of the Hive box to see what was actually stored
        QuizzerLogger.logMessage('=== Hive Box Contents ===');
        final allKeys = storage.keys.toList();
        QuizzerLogger.logMessage('Total keys in storage: ${allKeys.length}');
        for (final key in allKeys) {
          final value = storage.get(key);
          QuizzerLogger.logMessage('Key: "$key" -> Value: "$value"');
        }
        QuizzerLogger.logMessage('=== End Hive Box Contents ===');
        
        // Check that offline login data was stored under the email key
        expect(storage.containsKey(testEmail), isTrue);
        
        // Get the stored offline login data
        final offlineLoginData = storage.get(testEmail) as Map<String, dynamic>;
        expect(offlineLoginData, isNotNull);
        
        // The data is already a Map, no need to parse
        final Map<String, dynamic> loginData = offlineLoginData;
        
        // Validate the stored data contains the expected fields
        expect(loginData['user_id'], isNotNull);
        expect(loginData['last_sign_in_at'], isNotNull);
        expect(loginData['user_role'], isNotNull);
        
        // Validate the stored user_id matches the local user profile UUID
        final storedUserId = loginData['user_id'] as String;
        final localUserId = await getUserIdByEmail(testEmail);
        expect(storedUserId, equals(localUserId));
        
        QuizzerLogger.logSuccess('Valid credentials authentication test passed');
        
      } catch (e, stackTrace) {
        QuizzerLogger.logError('Valid credentials authentication test failed: $e');
        QuizzerLogger.logError('Stack trace: $stackTrace');
        rethrow;
      }
    });

    test('Invalid password should fail authentication', () async {
      QuizzerLogger.logMessage('Testing failed Supabase authentication with invalid password');
      
      const invalidPassword = 'WrongPassword123!';
      
      try {
        // Step 1: Clear Hive storage to ensure clean state
        QuizzerLogger.logMessage('Clearing Hive storage for clean test state');
        await sessionManager.clearStorage();
        
        // Step 2: Perform authentication with invalid password
        QuizzerLogger.logMessage('Attempting Supabase authentication with invalid password');
        final result = await attemptSupabaseLogin(testEmail, invalidPassword, sessionManager.supabase, sessionManager.getBox(testAccessPassword));
        
        QuizzerLogger.logMessage('Authentication result: $result');
        expect(result['success'], false);
        expect(result['message'], isNotEmpty);
        expect(result['user_role'], 'public_user_unverified');
        
        // The message should contain some indication of authentication failure
        expect(result['message'], anyOf(
          contains('Invalid login credentials'),
          contains('Invalid email or password'),
          contains('Invalid credentials'),
          contains('Email not confirmed'),
          contains('User not found')
        ));
        
        // Step 3: Verify that Hive storage is still empty after failed login
        QuizzerLogger.logMessage('Validating Hive storage is empty after failed login');
        final storage = sessionManager.getBox(testAccessPassword);
        
        // Check that no offline login data was stored
        expect(storage.get('user_id'), isNull);
        expect(storage.get('user_email'), isNull);
        expect(storage.get('last_login'), isNull);
        
        QuizzerLogger.logSuccess('Invalid password authentication test passed');
        
      } catch (e, stackTrace) {
        QuizzerLogger.logError('Invalid password authentication test failed: $e');
        QuizzerLogger.logError('Stack trace: $stackTrace');
        rethrow;
      }
    });

    test('Empty password should fail authentication', () async {
      QuizzerLogger.logMessage('Testing failed Supabase authentication with empty password');
      
      try {
        // Step 1: Clear Hive storage to ensure clean state
        QuizzerLogger.logMessage('Clearing Hive storage for clean test state');
        await sessionManager.clearStorage();
        
        // Step 2: Perform authentication with empty password
        QuizzerLogger.logMessage('Attempting Supabase authentication with empty password');
        final result = await attemptSupabaseLogin(testEmail, '', sessionManager.supabase, sessionManager.getBox(testAccessPassword));
        
        QuizzerLogger.logMessage('Authentication result: $result');
        expect(result['success'], false);
        expect(result['message'], isNotEmpty);
        expect(result['user_role'], 'public_user_unverified');
        
        // Step 3: Verify that Hive storage is still empty after failed login
        QuizzerLogger.logMessage('Validating Hive storage is empty after failed login');
        final storage = sessionManager.getBox(testAccessPassword);
        
        // Check that no offline login data was stored (keys don't exist)
        expect(storage.containsKey('user_id'), isFalse);
        expect(storage.containsKey('user_email'), isFalse);
        expect(storage.containsKey('last_login'), isFalse);
        
        QuizzerLogger.logSuccess('Empty password authentication test passed');
        
      } catch (e, stackTrace) {
        QuizzerLogger.logError('Empty password authentication test failed: $e');
        QuizzerLogger.logError('Stack trace: $stackTrace');
        rethrow;
      }
    });

    test('Non-existent user should fail authentication', () async {
      QuizzerLogger.logMessage('Testing failed Supabase authentication with non-existent user');
      
      const nonExistentEmail = 'nonexistent@example.com';
      
      try {
        final result = await attemptSupabaseLogin(nonExistentEmail, testPassword, sessionManager.supabase, sessionManager.getBox(testAccessPassword));
        
        QuizzerLogger.logMessage('Authentication result: $result');
        expect(result['success'], false);
        expect(result['message'], isNotEmpty);
        expect(result['user_role'], 'public_user_unverified');
        
        // The message should contain some indication of user not found
        expect(result['message'], anyOf(
          contains('Invalid login credentials'),
          contains('Invalid email or password'),
          contains('User not found'),
          contains('Email not confirmed')
        ));
        
        QuizzerLogger.logSuccess('Non-existent user authentication test passed');
        
      } catch (e, stackTrace) {
        QuizzerLogger.logError('Non-existent user authentication test failed: $e');
        QuizzerLogger.logError('Stack trace: $stackTrace');
        rethrow;
      }
    });
  });

  group('Offline Login Determination Tests', () {
    test('Should detect offline mode when previous login exists and current login fails', () async {
      QuizzerLogger.logMessage('Testing offline mode detection with previous successful login');
      
      try {
        // Step 1: Perform a successful login to create offline login data
        QuizzerLogger.logMessage('Step 1: Creating offline login data with successful login');
        await sessionManager.clearStorage();
        
        final successResult = await attemptSupabaseLogin(testEmail, testPassword, sessionManager.supabase, sessionManager.getBox(testAccessPassword));
        expect(successResult['success'], true);
        
        // Verify offline login data was stored
        final storage = sessionManager.getBox(testAccessPassword);
        expect(storage.containsKey(testEmail), isTrue);
        
        // Step 2: Perform an invalid login attempt
        QuizzerLogger.logMessage('Step 2: Attempting invalid login to trigger offline mode');
        final invalidResult = await attemptSupabaseLogin(testEmail, 'WrongPassword123!', sessionManager.supabase, sessionManager.getBox(testAccessPassword));
        expect(invalidResult['success'], false);
        
        // Step 3: Check offline login determination
        QuizzerLogger.logMessage('Step 3: Checking offline login determination');
        final offlineResult = checkOfflineLogin(testEmail, storage, invalidResult);
        
        QuizzerLogger.logMessage('Offline login result: $offlineResult');
        expect(offlineResult['offline_mode'], isTrue);
        expect(offlineResult['success'], isTrue);
        expect(offlineResult['message'], 'offline_login');
        expect(offlineResult['user_id'], isNotNull);
        expect(offlineResult['user_role'], isNotNull);
        expect(offlineResult['offline_login_count'], isNotNull);
        
        QuizzerLogger.logSuccess('Offline mode detection test passed');
        
      } catch (e, stackTrace) {
        QuizzerLogger.logError('Offline mode detection test failed: $e');
        QuizzerLogger.logError('Stack trace: $stackTrace');
        rethrow;
      }
    });

    test('Should not detect offline mode when no previous login exists', () async {
      QuizzerLogger.logMessage('Testing offline mode detection with no previous login');
      
      try {
        // Step 1: Clear storage to ensure no previous login data
        QuizzerLogger.logMessage('Step 1: Clearing storage to ensure no previous login');
        await sessionManager.clearStorage();
        
        // Step 2: Perform an invalid login attempt
        QuizzerLogger.logMessage('Step 2: Attempting invalid login with no previous data');
        final invalidResult = await attemptSupabaseLogin(testEmail, 'WrongPassword123!', sessionManager.supabase, sessionManager.getBox(testAccessPassword));
        expect(invalidResult['success'], false);
        
        // Step 3: Check offline login determination
        QuizzerLogger.logMessage('Step 3: Checking offline login determination');
        final storage = sessionManager.getBox(testAccessPassword);
        final offlineResult = checkOfflineLogin(testEmail, storage, invalidResult);
        
        QuizzerLogger.logMessage('Offline login result: $offlineResult');
        expect(offlineResult['offline_mode'], isFalse);
        expect(offlineResult['success'], isFalse);
        
        QuizzerLogger.logSuccess('No offline mode detection test passed');
        
      } catch (e, stackTrace) {
        QuizzerLogger.logError('No offline mode detection test failed: $e');
        QuizzerLogger.logError('Stack trace: $stackTrace');
        rethrow;
      }
    });

    test('Should not detect offline mode for non-existent user', () async {
      QuizzerLogger.logMessage('Testing offline mode detection for non-existent user');
      
      try {
        // Step 1: Clear storage and perform invalid login for non-existent user
        QuizzerLogger.logMessage('Step 1: Attempting invalid login for non-existent user');
        await sessionManager.clearStorage();
        
        const nonExistentEmail = 'nonexistent@example.com';
        final invalidResult = await attemptSupabaseLogin(nonExistentEmail, testPassword, sessionManager.supabase, sessionManager.getBox(testAccessPassword));
        expect(invalidResult['success'], false);
        
        // Step 2: Check offline login determination
        QuizzerLogger.logMessage('Step 2: Checking offline login determination');
        final storage = sessionManager.getBox(testAccessPassword);
        final offlineResult = checkOfflineLogin(nonExistentEmail, storage, invalidResult);
        
        QuizzerLogger.logMessage('Offline login result: $offlineResult');
        expect(offlineResult['offline_mode'], isFalse);
        expect(offlineResult['success'], isFalse);
        
        QuizzerLogger.logSuccess('Non-existent user offline mode test passed');
        
      } catch (e, stackTrace) {
        QuizzerLogger.logError('Non-existent user offline mode test failed: $e');
        QuizzerLogger.logError('Stack trace: $stackTrace');
        rethrow;
      }
    });


  });

  group('Login Attempt Recording Tests', () {
    test('Should record successful login attempt through actual authentication', () async {
      QuizzerLogger.logMessage('Testing successful login attempt recording through real authentication');
      
      try {
        // Step 1: Get count of existing login attempts for this user
        QuizzerLogger.logMessage('Step 1: Checking existing login attempts');
        final existingAttempts = await getLoginAttemptsByEmail(testEmail);
        final initialCount = existingAttempts.length;
        
        // Step 2: Perform actual successful authentication
        QuizzerLogger.logMessage('Step 2: Performing actual successful authentication');
        await sessionManager.clearStorage();
        final authResult = await attemptSupabaseLogin(testEmail, testPassword, sessionManager.supabase, sessionManager.getBox(testAccessPassword));
        expect(authResult['success'], true);
        
        // Step 3: Record the login attempt
        QuizzerLogger.logMessage('Step 3: Recording the login attempt');
        await recordLoginAttempt(
          email: testEmail,
          statusCode: authResult['message'],
        );
        
        // Step 4: Verify the login attempt was recorded
        QuizzerLogger.logMessage('Step 4: Verifying login attempt was recorded');
        final attempts = await getLoginAttemptsByEmail(testEmail);
        expect(attempts.length, equals(initialCount + 1));
        
        final recordedAttempt = attempts.first;
        expect(recordedAttempt['email'], equals(testEmail));
        expect(recordedAttempt['status_code'], equals('Login successful'));
        expect(recordedAttempt['user_id'], isNotNull);
        expect(recordedAttempt['timestamp'], isNotNull);
        expect(recordedAttempt['ip_address'], isNotNull);
        expect(recordedAttempt['device_info'], isNotNull);
        expect(recordedAttempt['has_been_synced'], equals(0));
        expect(recordedAttempt['edits_are_synced'], equals(0));
        expect(recordedAttempt['last_modified_timestamp'], isNotNull);
        
        // Verify the user_id matches the local user profile
        final localUserId = await getUserIdByEmail(testEmail);
        expect(recordedAttempt['user_id'], equals(localUserId));
        
        QuizzerLogger.logSuccess('Successful login attempt recording test passed');
        
      } catch (e, stackTrace) {
        QuizzerLogger.logError('Successful login attempt recording test failed: $e');
        QuizzerLogger.logError('Stack trace: $stackTrace');
        rethrow;
      }
    });

    test('Should record failed login attempt through actual authentication', () async {
      QuizzerLogger.logMessage('Testing failed login attempt recording through real authentication');
      
      try {
        // Step 1: Clear any existing login attempts for this user
        QuizzerLogger.logMessage('Step 1: Clearing existing login attempts');
        final existingAttempts = await getLoginAttemptsByEmail(testEmail);
        for (final attempt in existingAttempts) {
          await deleteLoginAttemptRecord(attempt['login_attempt_id'] as String);
        }
        
        // Step 2: Perform actual failed authentication
        QuizzerLogger.logMessage('Step 2: Performing actual failed authentication');
        await sessionManager.clearStorage();
        final authResult = await attemptSupabaseLogin(testEmail, 'WrongPassword123!', sessionManager.supabase, sessionManager.getBox(testAccessPassword));
        expect(authResult['success'], false);
        
        // Step 3: Record the failed login attempt
        QuizzerLogger.logMessage('Step 3: Recording the failed login attempt');
        await recordLoginAttempt(
          email: testEmail,
          statusCode: authResult['message'],
        );
        
        // Step 4: Verify the failed login attempt was recorded
        QuizzerLogger.logMessage('Step 4: Verifying failed login attempt was recorded');
        final attempts = await getLoginAttemptsByEmail(testEmail);
        expect(attempts.length, equals(1));
        
        final recordedAttempt = attempts.first;
        expect(recordedAttempt['email'], equals(testEmail));
        expect(recordedAttempt['status_code'], isNotEmpty);
        expect(recordedAttempt['user_id'], isNotNull);
        expect(recordedAttempt['timestamp'], isNotNull);
        expect(recordedAttempt['ip_address'], isNotNull);
        expect(recordedAttempt['device_info'], isNotNull);
        
        // The status code should contain some indication of failure
        expect(recordedAttempt['status_code'], anyOf(
          contains('Invalid login credentials'),
          contains('Invalid email or password'),
          contains('Invalid credentials'),
          contains('Email not confirmed'),
          contains('User not found')
        ));
        
        QuizzerLogger.logSuccess('Failed login attempt recording test passed');
        
      } catch (e, stackTrace) {
        QuizzerLogger.logError('Failed login attempt recording test failed: $e');
        QuizzerLogger.logError('Stack trace: $stackTrace');
        rethrow;
      }
    });

    test('Should record multiple real login attempts for same user', () async {
      QuizzerLogger.logMessage('Testing multiple real login attempts recording');
      
      try {
        // Step 1: Get initial count of existing login attempts
        QuizzerLogger.logMessage('Step 1: Getting initial login attempts count');
        final initialAttempts = await getLoginAttemptsByEmail(testEmail);
        final initialCount = initialAttempts.length;
        QuizzerLogger.logMessage('Initial login attempts count: $initialCount');
        
        // Step 2: Perform multiple real login attempts
        QuizzerLogger.logMessage('Step 2: Performing multiple real login attempts');
        await sessionManager.clearStorage();
        
        // First attempt: successful
        final successResult = await attemptSupabaseLogin(testEmail, testPassword, sessionManager.supabase, sessionManager.getBox(testAccessPassword));
        expect(successResult['success'], true);
        await recordLoginAttempt(email: testEmail, statusCode: successResult['message']);
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Second attempt: failed
        final failResult = await attemptSupabaseLogin(testEmail, 'WrongPassword123!', sessionManager.supabase, sessionManager.getBox(testAccessPassword));
        expect(failResult['success'], false);
        await recordLoginAttempt(email: testEmail, statusCode: failResult['message']);
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Third attempt: successful again
        final successResult2 = await attemptSupabaseLogin(testEmail, testPassword, sessionManager.supabase, sessionManager.getBox(testAccessPassword));
        expect(successResult2['success'], true);
        await recordLoginAttempt(email: testEmail, statusCode: successResult2['message']);
        
        // Step 3: Verify all records were created
        QuizzerLogger.logMessage('Step 3: Verifying all login attempts were recorded');
        final attempts = await getLoginAttemptsByEmail(testEmail);
        expect(attempts.length, equals(initialCount + 3), reason: 'Should have initial count + 3 login attempts after performing 3 attempts');
        
        QuizzerLogger.logSuccess('Multiple real login attempts recording test passed');
        
      } catch (e, stackTrace) {
        QuizzerLogger.logError('Multiple real login attempts recording test failed: $e');
        QuizzerLogger.logError('Stack trace: $stackTrace');
        rethrow;
      }
    });
  });

  // === User Profile Sync Mechanism Tests ===
  group('User Profile Sync Mechanism Tests', () {
    test('Neither local nor Supabase profile exists: both are created', () async {
      // Delete both profiles to start clean
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db != null) {
        await db.delete('user_profile', where: 'email = ?', whereArgs: [testEmail]);
        getDatabaseMonitor().releaseDatabaseAccess();
      }
      await sessionManager.supabase.from('user_profile').delete().eq('email', testEmail);
      
      // Verify neither exists
      final localProfile = await getUserProfileByEmail(testEmail);
      final supabaseResponse = await sessionManager.supabase.from('user_profile').select().eq('email', testEmail).maybeSingle();
      expect(localProfile, isNull);
      expect(supabaseResponse, isNull);
      
      // Create local profile
      await ensureLocalProfileExists(testEmail);
      final newLocalProfile = await getUserProfileByEmail(testEmail);
      expect(newLocalProfile, isNotNull, reason: 'Local profile should exist for $testEmail');
      if (newLocalProfile != null) {
        expect(newLocalProfile['email'], equals(testEmail), reason: 'Local profile email should match test email');
      }
      
      // Create Supabase profile
      await ensureUserProfileExistsInSupabase(testEmail, sessionManager.supabase);
      final newSupabaseResponse = await sessionManager.supabase.from('user_profile').select().eq('email', testEmail).maybeSingle();
      expect(newSupabaseResponse, isNotNull);
    });

    test('Only Supabase profile exists: local is created from Supabase', () async {
      // Delete both profiles to start clean
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db != null) {
        await db.delete('user_profile', where: 'email = ?', whereArgs: [testEmail]);
        getDatabaseMonitor().releaseDatabaseAccess();
      }
      await sessionManager.supabase.from('user_profile').delete().eq('email', testEmail);
      
      // Create in Supabase only
      await ensureLocalProfileExists(testEmail);
      await ensureUserProfileExistsInSupabase(testEmail, sessionManager.supabase);
      
      // Delete local to simulate only Supabase existing
      final db2 = await getDatabaseMonitor().requestDatabaseAccess();
      if (db2 != null) {
        await db2.delete('user_profile', where: 'email = ?', whereArgs: [testEmail]);
        getDatabaseMonitor().releaseDatabaseAccess();
      }
      
      // Verify only Supabase exists
      final localProfile = await getUserProfileByEmail(testEmail);
      final supabaseResponse = await sessionManager.supabase.from('user_profile').select().eq('email', testEmail).maybeSingle();
      expect(localProfile, isNull);
      expect(supabaseResponse, isNotNull);
      
      // Create local from Supabase
      await ensureLocalProfileExists(testEmail);
      final newLocalProfile = await getUserProfileByEmail(testEmail);
      expect(newLocalProfile, isNotNull);
    });

    test('Both local and Supabase profiles exist: nothing is duplicated/overwritten', () async {
      // Delete both profiles to start clean
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db != null) {
        await db.delete('user_profile', where: 'email = ?', whereArgs: [testEmail]);
        getDatabaseMonitor().releaseDatabaseAccess();
      }
      await sessionManager.supabase.from('user_profile').delete().eq('email', testEmail);
      
      // Create both
      await ensureLocalProfileExists(testEmail);
      await ensureUserProfileExistsInSupabase(testEmail, sessionManager.supabase);
      
      // Verify both exist
      final localProfile = await getUserProfileByEmail(testEmail);
      final supabaseResponse = await sessionManager.supabase.from('user_profile').select().eq('email', testEmail).maybeSingle();
      expect(localProfile, isNotNull);
      expect(supabaseResponse, isNotNull);
      
      // Call both again to ensure idempotency
      await ensureLocalProfileExists(testEmail);
      await ensureUserProfileExistsInSupabase(testEmail, sessionManager.supabase);
      
      // Verify still both exist
      final localProfile2 = await getUserProfileByEmail(testEmail);
      final supabaseResponse2 = await sessionManager.supabase.from('user_profile').select().eq('email', testEmail).maybeSingle();
      expect(localProfile2, isNotNull);
      expect(supabaseResponse2, isNotNull);
    });

    test('Only local profile exists: Supabase is created from local', () async {
      // Delete both profiles to start clean
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db != null) {
        await db.delete('user_profile', where: 'email = ?', whereArgs: [testEmail]);
        getDatabaseMonitor().releaseDatabaseAccess();
      }
      await sessionManager.supabase.from('user_profile').delete().eq('email', testEmail);
      
      // Create local only
      await ensureLocalProfileExists(testEmail);
      await sessionManager.supabase.from('user_profile').delete().eq('email', testEmail);
      
      // Verify only local exists
      final localProfile = await getUserProfileByEmail(testEmail);
      final supabaseResponse = await sessionManager.supabase.from('user_profile').select().eq('email', testEmail).maybeSingle();
      expect(localProfile, isNotNull);
      expect(supabaseResponse, isNull);
      
      // Create Supabase from local
      await ensureUserProfileExistsInSupabase(testEmail, sessionManager.supabase);
      final newSupabaseResponse = await sessionManager.supabase.from('user_profile').select().eq('email', testEmail).maybeSingle();
      expect(newSupabaseResponse, isNotNull);
    });
  });

  // === Final Verification Test ===
  group('Final Verification Tests', () {
    test('Local user profile should have very old or null last_login after database clearing', () async {
      QuizzerLogger.logMessage('Verifying local user profile last_login state after all tests');
      
      try {
        // Get the local user profile record
        final localProfile = await getUserProfileByEmail(testEmail);
        expect(localProfile, isNotNull, reason: 'Local profile should exist for $testEmail');
        
        if (localProfile != null) {
          final lastLogin = localProfile['last_login'];
          QuizzerLogger.logMessage('Local profile last_login value: $lastLogin');
          
          // The last_login should either be null or very old since the database was cleared
          // and the profile was recreated during testing
          if (lastLogin != null) {
            // If it's not null, it should be a very old date (before the test started)
            final lastLoginDate = DateTime.parse(lastLogin);
            final testStartDate = DateTime.now().subtract(const Duration(minutes: 30)); // Conservative estimate
            
            expect(lastLoginDate.isBefore(testStartDate), true, 
              reason: 'last_login should be very old since profile was recreated. Found: $lastLogin');
            
            QuizzerLogger.logMessage('✅ last_login is very old: $lastLogin');
          } else {
            QuizzerLogger.logMessage('✅ last_login is null as expected');
          }
          
          // Additional verification: check that the profile was created recently
          final accountCreationDate = localProfile['account_creation_date'];
          if (accountCreationDate != null) {
            final creationDate = DateTime.parse(accountCreationDate);
            final recentDate = DateTime.now().subtract(const Duration(minutes: 30));
            
            expect(creationDate.isAfter(recentDate), true,
              reason: 'Profile should have been created recently during testing. Found: $accountCreationDate');
            
            QuizzerLogger.logMessage('✅ Profile was created recently: $accountCreationDate');
          }
        }
        
        QuizzerLogger.logSuccess('Local user profile last_login verification passed');
        
      } catch (e, stackTrace) {
        QuizzerLogger.logError('Local user profile last_login verification failed: $e');
        QuizzerLogger.logError('Stack trace: $stackTrace');
        rethrow;
      }
    });
  });
}
