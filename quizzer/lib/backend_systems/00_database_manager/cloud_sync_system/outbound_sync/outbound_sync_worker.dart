import 'dart:async';
import 'package:sqflite/sqflite.dart'; // Likely needed for DB operations later
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart'; // Import SwitchBoard
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
  Completer<void>? _stopCompleter;
  StreamSubscription? _syncSubscription; // Subscription to the SwitchBoard stream
  // --------------------

  // --- Dependencies ---
  final DatabaseMonitor _dbMonitor = getDatabaseMonitor();
  final SwitchBoard _switchBoard = SwitchBoard(); // Get SwitchBoard instance
  // Access Supabase client via getSessionManager().supabase
  // --------------------

  // --- Control Methods ---
  /// Starts the worker loop.
  Future<void> start() async {
    QuizzerLogger.logMessage('Entering OutboundSyncWorker start()...');
    if (_isRunning) {
      QuizzerLogger.logMessage('OutboundSyncWorker already running.');
      return; // Already running
    }
    _isRunning = true;
    _stopCompleter = Completer<void>();

    // Subscribe to the outbound sync needed stream directly here
    QuizzerLogger.logMessage('OutboundSyncWorker: Subscribing to onOutboundSyncNeeded stream.');
    _syncSubscription = _switchBoard.onOutboundSyncNeeded.listen((_) {
      // Listener body intentionally empty - loop handles the wake-up.
    }, 
    onError: (error) {
       // Optional: Log errors from the stream itself
       QuizzerLogger.logError('OutboundSyncWorker: Error on onOutboundSyncNeeded stream: $error');
    });

    // Perform an initial sync check on startup in case anything was missed
    await _performSync();

    // Start the main loop
    _runLoop();
    QuizzerLogger.logMessage('OutboundSyncWorker started and initial sync performed.');
  }

  /// Stops the worker loop.
  Future<void> stop() async {
    QuizzerLogger.logMessage('Entering OutboundSyncWorker stop()...');
    if (!_isRunning || _stopCompleter == null) {
      QuizzerLogger.logMessage('OutboundSyncWorker already stopped.');
      return; // Already stopped
    }
    _isRunning = false;

    // Unsubscribe directly here
    QuizzerLogger.logMessage('OutboundSyncWorker: Unsubscribing from onOutboundSyncNeeded stream.');
    await _syncSubscription?.cancel();
    _syncSubscription = null;

    // Complete the completer to signal the loop has been requested to stop
    if (_stopCompleter !=null && !_stopCompleter!.isCompleted) {
         // Loop exit handles completion
    }
    QuizzerLogger.logMessage('OutboundSyncWorker stop signal sent.');
  }
  // ----------------------

  // --- Main Loop ---
  Future<void> _runLoop() async {
    QuizzerLogger.logMessage('Entering OutboundSyncWorker _runLoop()...');
    while (_isRunning) {
      QuizzerLogger.logMessage('OutboundSyncWorker: Waiting for sync signal...');
      // Wait indefinitely for the next signal
      await _switchBoard.onOutboundSyncNeeded.first;

      QuizzerLogger.logMessage('OutboundSyncWorker: Woke up by sync signal.');
      if (!_isRunning) break; // Check if stopped while waiting

      QuizzerLogger.logMessage('OutboundSyncWorker: Signal received, performing sync...');
      await _performSync(); // Let errors propagate (Fail Fast for sync logic)

      if (!_isRunning) break; // Check if stopped during sync
    }
    // Ensure completer is completed when loop exits
    if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
       _stopCompleter!.complete();
    }
    QuizzerLogger.logMessage('OutboundSyncWorker loop finished.');
  }
  // -----------------

  // --- Core Sync Logic (Refactored) ---
  /// The core synchronization logic.
  Future<void> _performSync() async {
    QuizzerLogger.logMessage('OutboundSyncWorker: Starting sync cycle.');

    // 1. Check connectivity
    final bool isConnected = await _checkConnectivity();
    if (!isConnected) {
      QuizzerLogger.logMessage('OutboundSyncWorker: No network connectivity detected, skipping sync cycle.');
      return;
    }
    Database? db;

    // 2. Check and Sync Question Answer Pairs
    db = await _getDbAccess();
    await syncQuestionAnswerPairs(db!); // Call the abstracted function
    _dbMonitor.releaseDatabaseAccess();

    // 3. Check and sync Login Attempt Data
    db = await _getDbAccess();
    await syncLoginAttempts(db!);
    _dbMonitor.releaseDatabaseAccess();

    // 4. Check and sync User Profile Data
    db = await _getDbAccess();
    await syncUserProfiles(db!);
    _dbMonitor.releaseDatabaseAccess();

    // 5. Check and sync Question Answer Attempt Data
    db = await _getDbAccess();
    await syncQuestionAnswerAttempts(db!);
    _dbMonitor.releaseDatabaseAccess();
    
    // 6. Check and Sync UserQuestionAnswerPairs
    db = await _getDbAccess(); 
    await syncUserQuestionAnswerPairs(db!);
    _dbMonitor.releaseDatabaseAccess();
    
    // 7. Check and Sync Error Logs
    db = await _getDbAccess();
    await syncErrorLogs(db!);
    _dbMonitor.releaseDatabaseAccess();
    
    // 8. Check and Sync User Settings
    db = await _getDbAccess();
    await syncUserSettings(db!);
    _dbMonitor.releaseDatabaseAccess();
    
    // 9. Check and Sync Modules
    db = await _getDbAccess();
    await syncModules(db!);
    _dbMonitor.releaseDatabaseAccess();

    // 10. Check and Sync User Feedback (New)
    db = await _getDbAccess();
    await syncUserFeedback(db!); // Call the new sync function
    _dbMonitor.releaseDatabaseAccess();
    
    // 11. Check and Sync User Stats Eligible Questions
    db = await _getDbAccess();
    await syncUserStatsEligibleQuestions(db!);
    _dbMonitor.releaseDatabaseAccess();

    // 12. Check and Sync User Stats Non-Circulating Questions
    db = await _getDbAccess();
    await syncUserStatsNonCirculatingQuestions(db!);
    _dbMonitor.releaseDatabaseAccess();

    // 13. Check and Sync User Stats In Circulation Questions
    db = await _getDbAccess();
    await syncUserStatsInCirculationQuestions(db!);
    _dbMonitor.releaseDatabaseAccess();
    
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

   // --- Helper Functions ---
   // Helper to get DB access (simplified)
   Future<Database?> _getDbAccess() async {
      QuizzerLogger.logMessage('Entering OutboundSyncWorker _getDbAccess()...');
      // Attempt to get database access once.
      final Database? db = await _dbMonitor.requestDatabaseAccess();

      if (db == null) {
          // Log if access was not immediately granted (it might be queued in the monitor)
          QuizzerLogger.logMessage('OutboundSyncWorker: Database access not immediately available (queued or worker stopped?).');
      } else {
          QuizzerLogger.logMessage('OutboundSyncWorker: Database access granted.');
      }
      
      // Return the database instance or null if access wasn't granted.
      // The caller (_performSync) needs to handle the null case.
      return db;
   }
   // ------------------------
}

