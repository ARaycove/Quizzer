import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart'; // Import SwitchBoard
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'dart:io'; // Import for InternetAddress lookup
import 'outbound_sync_functions.dart'; // Import the abstracted sync functions

// ==========================================
// Outbound Sync Worker
// ==========================================
/// Pushes local data changes (marked for sync) to the cloud backend.
class OutboundSyncWorker {
  // --- Singleton Setup ---
  static final OutboundSyncWorker _instance = OutboundSyncWorker._internal();
  factory OutboundSyncWorker() => _instance;
  OutboundSyncWorker._internal() {
    QuizzerLogger.logMessage('OutboundSyncWorker initialized.');
  }
  // --------------------

  // --- Worker State ---
  bool _isRunning = false;
  bool _syncNeeded = false;
  StreamSubscription? _signalSubscription;
  // --------------------

  // --- Dependencies ---
  final SwitchBoard _switchBoard = SwitchBoard();
  final SessionManager _sessionManager = getSessionManager();
  // --------------------

  // --- Control Methods ---
  /// Starts the worker loop.
  Future<void> start() async {
    QuizzerLogger.logMessage('Entering OutboundSyncWorker start()...');
    
    if (_sessionManager.userId == null) {
      QuizzerLogger.logWarning('OutboundSyncWorker: Cannot start, no user logged in.');
      return;
    }
    
    _isRunning = true;
    
    // Start listening for sync signals
    _signalSubscription = _switchBoard.onOutboundSyncNeeded.listen((_) {
      _syncNeeded = true;
    });
    
    _runLoop();
    QuizzerLogger.logMessage('OutboundSyncWorker started.');
  }

  /// Stops the worker loop.
  Future<void> stop() async {
    QuizzerLogger.logMessage('Entering OutboundSyncWorker stop()...');

    if (!_isRunning) {
      QuizzerLogger.logMessage('OutboundSyncWorker: stop() called but worker is not running.');
      return; 
    }

    _isRunning = false;
    
    // Wait for current sync cycle to complete before returning
    QuizzerLogger.logMessage('OutboundSyncWorker: Waiting for current sync cycle to complete...');
    await _switchBoard.onOutboundSyncCycleComplete.first;
    QuizzerLogger.logMessage('OutboundSyncWorker: Current sync cycle completed.');
    
    await _signalSubscription?.cancel();
    QuizzerLogger.logMessage('OutboundSyncWorker stopped.');
  }
  // ----------------------

  // --- Main Loop ---
  Future<void> _runLoop() async {
    QuizzerLogger.logMessage('Entering OutboundSyncWorker _runLoop()...');
    
    while (_isRunning) {
      // Check connectivity first
      final bool isConnected = await _checkConnectivity();
      if (!isConnected) {
        QuizzerLogger.logMessage('OutboundSyncWorker: No network connectivity, waiting 5 minutes before next attempt...');
        await Future.delayed(const Duration(minutes: 5));
        continue;
      }
      
      // Run outbound sync
      QuizzerLogger.logMessage('OutboundSyncWorker: Running outbound sync...');
      await _performSync();
      QuizzerLogger.logMessage('OutboundSyncWorker: Outbound sync completed.');
      
      // Signal that the sync cycle is complete
      signalOutboundSyncCycleComplete();
      QuizzerLogger.logMessage('OutboundSyncWorker: Sync cycle complete signal sent.');
      
      // Add cooldown period to prevent infinite loops from self-signaling
      QuizzerLogger.logMessage('OutboundSyncWorker: Sync completed, entering 30-second cooldown...');
      await Future.delayed(const Duration(seconds: 30));
      
      // Check if sync is needed after cooldown
      if (_syncNeeded) {
        QuizzerLogger.logMessage('OutboundSyncWorker: Sync needed after cooldown, continuing to next cycle.');
        _syncNeeded = false;
      } else {
        // Wait for signal that another cycle is needed
        QuizzerLogger.logMessage('OutboundSyncWorker: Waiting for sync signal...');
        await _switchBoard.onOutboundSyncNeeded.first;
        QuizzerLogger.logMessage('OutboundSyncWorker: Woke up by sync signal.');
      }
    }
    
    QuizzerLogger.logMessage('OutboundSyncWorker loop finished.');
  }
  // -----------------

  // --- Core Sync Logic (Refactored) ---
  /// The core synchronization logic.
  Future<void> _performSync() async {
    // All sync functions should be grouped, get all records that need synced and group them into one long list, then using the unified push record function, group the pushes and send them all in batches ASYNC style.
    QuizzerLogger.logMessage('OutboundSyncWorker: Starting sync cycle.');

    // 1. Check connectivity
    final bool isConnected = await _checkConnectivity();
    if (!isConnected) {
      QuizzerLogger.logMessage('OutboundSyncWorker: No network connectivity detected, skipping sync cycle.');
      return;
    }
    // 2. Check and sync User Profile Data
    await syncUserProfiles();

    // 3. Check and Sync Question Answer Pairs
    await syncQuestionAnswerPairs();

    // 4. Check and sync Login Attempt Data
    await syncLoginAttempts();

    // 5. Check and sync Question Answer Attempt Data
    await syncQuestionAnswerAttempts();
    
    // 6. Check and Sync UserQuestionAnswerPairs
    await syncUserQuestionAnswerPairs();
    
    // 7. Check and Sync Question Answer Pair Flags
    await syncQuestionAnswerPairFlags();
    
    // 8. Check and Sync Error Logs
    await syncErrorLogs();
    
    // 9. Check and Sync User Settings
    await syncUserSettings();
    
    // 10. Check and Sync Modules
    await syncModules();

    // 11. Check and Sync User Module Activation Status
    await syncUserModuleActivationStatus();

    // 12. Check and Sync User Feedback
    await syncUserFeedback();
    
    // 13. Check and Sync User Stats Eligible Questions
    await syncUserStatsEligibleQuestions();

    // 14. Check and Sync User Stats Non-Circulating Questions
    await syncUserStatsNonCirculatingQuestions();

    // 15. Check and Sync User Stats In Circulation Questions
    await syncUserStatsInCirculationQuestions();

    // 16. Check and Sync User Stats Revision Streak Sum
    await syncUserStatsRevisionStreakSum();
    
    // 17. Check and Sync User Stats Total User Question Answer Pairs
    await syncUserStatsTotalUserQuestionAnswerPairs();

    // 18. Check and Sync User Stats Average Questions Shown Per Day
    await syncUserStatsAverageQuestionsShownPerDay();

    // 19. Check and Sync User Stats Total Questions Answered
    await syncUserStatsTotalQuestionsAnswered();

    // 20. Check and Sync User Stats Daily Questions Answered
    await syncUserStatsDailyQuestionsAnswered();

    // 21. Check and Sync User Stats Days Left Until Questions Exhaust
    await syncUserStatsDaysLeftUntilQuestionsExhaust();

    // 22. Check and Sync User Stats Average Daily Questions Learned
    await syncUserStatsAverageDailyQuestionsLearned();

    QuizzerLogger.logMessage('All outbound sync functions completed.');
  }
  // ----------------------

  // --- Network Connectivity Check ---
  /// Attempts a simple network operation to check for connectivity.
  /// Returns true if likely connected, false otherwise.
  /// Uses a try-catch specifically for this pre-check.
  Future<bool> _checkConnectivity() async {
    try {
      // Use a common domain for lookup, less likely to be blocked/down than specific API endpoints.
      final result = await InternetAddress.lookup('google.com'); 
      // Check if the lookup returned any results and if the first result has an address.
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        QuizzerLogger.logMessage('Network check successful.');
        return true;
      }
      // If lookup returned empty or with no address, treat as disconnected.
      QuizzerLogger.logWarning('Network check failed (lookup empty/no address).');
      return false;
    } on SocketException catch (_) {
      // Specifically catch SocketException, typical for network errors (offline, DNS fail).
      QuizzerLogger.logMessage('Network check failed (SocketException): Likely offline.');
      return false;
    } catch (e) {
      // Catch any other unexpected error during the check, log it, return false.
      QuizzerLogger.logError('Unexpected error during network check: $e');
      return false;
    }
  }
  // -------------------------------


}

