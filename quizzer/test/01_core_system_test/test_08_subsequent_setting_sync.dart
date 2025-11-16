import 'package:flutter_test/flutter_test.dart';
import '../test_helpers.dart';
import '../test_expectations.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/09_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/inbound_sync/inbound_sync_worker.dart';

void main() {
  group('Subsequent Settings Sync Tests', () {
    late SessionManager sessionManager;
    late SwitchBoard switchBoard;
    String? testUserId;
    String? testEmail;
    String? testPassword;
    String? testAccessPassword;

    setUpAll(() async {
      resetToFreshDevice();
      QuizzerLogger.setupLogging();
      sessionManager = getSessionManager();
      switchBoard = getSwitchBoard();
      
      // Load test configuration
      final config = await getTestConfig();
      final testIteration = config['testIteration'] as int;
      testPassword = config['testPassword'] as String;
      testAccessPassword = config['testAccessPassword'] as String;
      testEmail = 'test_user_$testIteration@example.com';
    });

    tearDownAll(() async {
      if (testUserId != null) {
        await deleteAllUserSettingsOnSupabase(testUserId!);
      }
    });

    test('Fresh device login and settings verification', () async {
      // Run the full login process, by defining the individual function calls, by doing it this way we can throw expectations inbetween to try and isolate where the failure happens
      // Between each call we will place in expectations of what we want the current state to be
      // 1. User submits credentials, triggering SessionManager.attemptLogin,

      // Following that chain the first function call is:
      await performLoginProcess(
        email: testEmail!, 
        password: testPassword!, 
        supabase: sessionManager.supabase, 
        storage: sessionManager.getBox(testAccessPassword!)
      );
      // Fresh device should not have this table made yet
      await expectTableIsMissing("user_settings");
      // user profile table should exist, and local user_id for local profile should match what's in supabase.
      await expectUserProfileTableExistsAndUserIdsMatch(sessionManager);

      // The next step is to initialize the sync workers:
      // Start inbound sync worker
      QuizzerLogger.logMessage('Starting inbound sync worker...');
      final inboundSyncWorker = InboundSyncWorker();
      inboundSyncWorker.start();
      
      // Wait for inbound sync cycle to complete before starting other workers
      QuizzerLogger.logMessage('Waiting for inbound sync cycle to complete...');
      await switchBoard.onInboundSyncCycleComplete.first;
      QuizzerLogger.logSuccess('Inbound sync cycle completed');

      // Since the settings in supabase were 1, they should now be one locally after the inbound sync
      expectAllLocalHomeDisplaySettingsEqualOne(sessionManager.userId!);
      // They also should not have changed in the user settings
      expectAllSupabaseHomeDisplaySettingsEqualOne(sessionManager.userId!);

      testUserId = sessionManager.userId;
    });
  });
}
