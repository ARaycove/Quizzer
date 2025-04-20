import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:supabase/supabase.dart';
// FIXME add in the quizzer logger

void main() {
  SessionManager session = getSessionManager();
  String email = 'test_07@example.com';
  String username = 'testuser7';
  String password = 'testpass123';
  test('Create dummy user account', () async {
    // Create dummy account
    final results = await session.createNewUserAccount(
      email: email,
      username: username,
      password: password,
    );
    QuizzerLogger.logMessage('Test account creation results: $results');

  });

  test('Login with dummy account', () async {
    // // test invalid credentials with no first time login
    // final invalidLogin = await session.attemptLogin(email, "invalid");
    // QuizzerLogger.logMessage('Invalid login results: $invalidLogin');
    // assert(invalidLogin["success"] == false);

    // test valid login
    final validLogin = await session.attemptLogin(email, password);
    QuizzerLogger.logMessage('Valid login results: $validLogin');
    assert(validLogin["success"]);


    // // test invalid credentials 
    // final bypassLogin = await session.attemptLogin(email, "invalid");
    // QuizzerLogger.logMessage('Invalid login results: $bypassLogin');
    // assert(bypassLogin["success"]);
  });

  test('Check session state after login', () async {
    // Log initial state of session
    QuizzerLogger.logMessage('Session state after login: ${session.toString()}');
    
    // Assert that userUUID is not null after successful login
    assert(session.userId != null, 'User UUID should not be null after successful login');
    QuizzerLogger.logMessage('User UUID verification passed: ${session.userId}');

    assert(session.userEmail != null);
    QuizzerLogger.logMessage('${session.userEmail}');
  });

  test('Load modules for logged in user', () async {
    // Ensure user is logged in before testing module loading
    if (!session.userLoggedIn) {
      await session.attemptLogin(email, password);
    }
    
    // Call the loadModules API
    final moduleData = await session.loadModules();
    
    // Log the results for debugging
    QuizzerLogger.logMessage('Module data loaded: $moduleData');
    
    // Verify the structure of the returned data
    assert(moduleData.containsKey('modules'), 'Response should contain modules key');
    assert(moduleData.containsKey('activationStatus'), 'Response should contain activationStatus key');
    
    // Verify the types of the returned data
    assert(moduleData['modules'] is List, 'Modules should be a list');
    assert(moduleData['activationStatus'] is Map, 'Activation status should be a map');
    
    // Additional verification if modules exist
    if ((moduleData['modules'] as List).isNotEmpty) {
      final firstModule = (moduleData['modules'] as List).first;
      assert(firstModule is Map, 'Each module should be a map of data');
      assert(firstModule.containsKey('module_name'), 'Module should have a name');
    }

    // Test toggling module activation
    if ((moduleData['modules'] as List).length >= 2) {
      // Get the first two modules
      final firstModule = (moduleData['modules'] as List)[0]['module_name'] as String;
      final secondModule = (moduleData['modules'] as List)[1]['module_name'] as String;
      
      QuizzerLogger.logMessage('Testing module activation toggle for: $firstModule and $secondModule');
      
      // Toggle first module on
      session.toggleModuleActivation(firstModule, true);
      
      // Toggle second module on
      session.toggleModuleActivation(secondModule, true);
      
      // Toggle first module off
      session.toggleModuleActivation(firstModule, false);
      
      // Toggle second module off
      session.toggleModuleActivation(secondModule, false);
    } else {
      QuizzerLogger.logMessage('Not enough modules to test activation toggle (need at least 2)');
    }

    // Test updating module description
    if ((moduleData['modules'] as List).isNotEmpty) {
      // Find the general module
      final generalModuleIndex = (moduleData['modules'] as List).indexWhere(
          (module) => module['module_name'].toString().toLowerCase() == 'general');
      
      if (generalModuleIndex >= 0) {
        final generalModule = (moduleData['modules'] as List)[generalModuleIndex];
        final String originalDescription = generalModule['description'] as String;
        QuizzerLogger.logMessage('Original description: $originalDescription');
        
        // Generate a garbage description
        final String garbageDescription = 'Temporary test description ${DateTime.now().millisecondsSinceEpoch}';
        
        // Update the description
        final updateSuccess = await session.updateModuleDescription('general', garbageDescription);
        assert(updateSuccess, 'Module description update should succeed');
        
        // Reload module data to get fresh state
        final updatedModuleData = await session.loadModules();
        final updatedGeneralModuleIndex = (updatedModuleData['modules'] as List).indexWhere(
            (module) => module['module_name'].toString().toLowerCase() == 'general');
        
        if (updatedGeneralModuleIndex >= 0) {
          final updatedGeneralModule = (updatedModuleData['modules'] as List)[updatedGeneralModuleIndex];
          final String updatedDescription = updatedGeneralModule['description'] as String;
          
          // Verify the description was updated
          assert(updatedDescription == garbageDescription, 
              'Module description should be updated to: $garbageDescription, but was: $updatedDescription');
          
          // Set the description back to the original
          final restoreSuccess = await session.updateModuleDescription('general', originalDescription);
          assert(restoreSuccess, 'Module description restore should succeed');
          
          // Reload module data again
          final restoredModuleData = await session.loadModules();
          final restoredGeneralModuleIndex = (restoredModuleData['modules'] as List).indexWhere(
              (module) => module['module_name'].toString().toLowerCase() == 'general');
          
          if (restoredGeneralModuleIndex >= 0) {
            final restoredGeneralModule = (restoredModuleData['modules'] as List)[restoredGeneralModuleIndex];
            final String restoredDescription = restoredGeneralModule['description'] as String;
            
            // Verify the description was restored
            assert(restoredDescription == originalDescription, 
                'Module description should be restored to: $originalDescription, but was: $restoredDescription');
            
            QuizzerLogger.logSuccess('Module description update and restore test passed');
          } else {
            QuizzerLogger.logError('Could not find general module after restore');
          }
        } else {
          QuizzerLogger.logError('Could not find general module after update');
        }
      } else {
        QuizzerLogger.logMessage('General module not found for description update test');
      }
    } else {
      QuizzerLogger.logMessage('No modules available to test description update');
    }

  });



}
