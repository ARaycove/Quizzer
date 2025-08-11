import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_settings_table.dart' as user_settings_table;
import '../test_expectations.dart';
import '../test_helpers.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/outbound_sync/outbound_sync_functions.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/inbound_sync/inbound_sync_functions.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'dart:io';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
import 'package:supabase/supabase.dart';

void main() {
  group('User Settings Full Integration Sync Tests', () {
    test('Full integration test from login to settings sync', () async {
      // Mimick the setup from main.dart
      await QuizzerLogger.setupLogging();
      HttpOverrides.global = null;
      
      // Load test configuration
      final config = await getTestConfig();
      final testIteration = config['testIteration'] as int;
      final testPassword = config['testPassword'] as String;
      final testAccessPassword = config['testAccessPassword'] as String;
      
      // Set up test credentials
      final testEmail = 'test_user_$testIteration@example.com';
      
      final sessionManager = getSessionManager();
      final switchBoard = getSwitchBoard();
      final supabase = sessionManager.supabase;
      await sessionManager.initializationComplete;
      // A user logins with their credentials, the session manager api is called which calls login initialization
      // This is the breakdown function call by function call of what happens. Our goal is to test expectations for user settings consistency
      await performLoginProcess(
        email: testEmail, 
        password: testPassword, 
        supabase: sessionManager.supabase, 
        storage: sessionManager.getBox(testAccessPassword)
      );


    });
  });
}