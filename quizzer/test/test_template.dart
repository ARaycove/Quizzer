// import 'package:flutter_test/flutter_test.dart';
// import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
// import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
// import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
// import 'test_helpers.dart';
// import 'dart:io';

// void main() {
//   TestWidgetsFlutterBinding.ensureInitialized();
  
//   // Manual iteration variable for reusing accounts across tests
//   late int testIteration;
  
//   // Test credentials - defined once and reused
//   late String testEmail;
//   late String testPassword;
//   late String testAccessPassword;
  
//   // Global instances used across tests
//   late final SessionManager sessionManager;
  
//   setUpAll(() async {
//     await QuizzerLogger.setupLogging();
//     HttpOverrides.global = null;
    
//     // Load test configuration
//     final config = await getTestConfig();
//     testIteration = config['testIteration'] as int;
//     testPassword = config['testPassword'] as String;
//     testAccessPassword = config['testAccessPassword'] as String;
    
//     // Set up test credentials
//     testEmail = 'test_user_$testIteration@example.com';
    
//     sessionManager = getSessionManager();
//     await sessionManager.initializationComplete;
    
//     // Perform full login initialization (excluding sync workers for testing)
//     final loginResult = await loginInitialization(
//       email: testEmail, 
//       password: testPassword, 
//       supabase: sessionManager.supabase, 
//       storage: sessionManager.getBox(testAccessPassword),
//       testRun: true, // This bypasses sync workers for faster testing
//     );
    
//     expect(loginResult['success'], isTrue, reason: 'Login initialization should succeed');
//     QuizzerLogger.logSuccess('Full login initialization completed successfully');
//   });
  
//   group('Test Group Name', () {
//     test('Test description', () async {
//       QuizzerLogger.logMessage('Test description');
      
//       try {
//         // Test Description here
//       } catch (e) {
//         QuizzerLogger.logError('Test failed: $e');
//         rethrow;
//       }
//     });
//   });
// }
