import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // Needed for runInitialInboundSync
import 'package:quizzer/backend_systems/04_module_management/module_updates_process.dart'; // For buildModuleRecords
import 'inbound_sync_functions.dart'; // For runInitialInboundSync
import 'dart:io'; // For InternetAddress lookup

// ==========================================
// Inbound Sync Worker
// ==========================================
/// Periodically fetches data changes from the cloud backend and updates the local database.
class InboundSyncWorker {
  // --- Singleton Setup ---
  static final InboundSyncWorker _instance = InboundSyncWorker._internal();
  factory InboundSyncWorker() => _instance;
  InboundSyncWorker._internal() {
    QuizzerLogger.logMessage('InboundSyncWorker initialized.');
  }
  // --------------------

  // --- Worker State ---
  bool _isRunning = false;
  Completer<void>? _stopCompleter;
  StreamSubscription? _syncSubscription; // Subscription to the SwitchBoard stream
  // --------------------

  // --- Dependencies ---
  final DatabaseMonitor _dbMonitor      = getDatabaseMonitor();
  final SwitchBoard     _switchBoard    = getSwitchBoard(); // Use global getter
  final SessionManager  _sessionManager = getSessionManager(); // Use global getter
  // --------------------

  // --- Control Methods ---
  /// Starts the worker loop.
  Future<void> start() async {
    QuizzerLogger.logMessage('Entering InboundSyncWorker start()...');
    if (_isRunning) {
      QuizzerLogger.logMessage('InboundSyncWorker already running.');
      return; // Already running
    }
    if (_sessionManager.userId == null) {
      QuizzerLogger.logWarning('InboundSyncWorker: Cannot start, no user logged in.');
      return;
    }
    _isRunning = true;
    _stopCompleter = Completer<void>();

    // Subscribe to the inbound sync needed stream
    QuizzerLogger.logMessage('InboundSyncWorker: Subscribing to onInboundSyncNeeded stream.');
    _syncSubscription = _switchBoard.onInboundSyncNeeded.listen((_) {
      // Listener body intentionally empty - loop handles the wake-up.
    },
    onError: (error) {
       QuizzerLogger.logError('InboundSyncWorker: Error on onInboundSyncNeeded stream: $error');
    });

    // Perform an initial sync on startup
    QuizzerLogger.logMessage('InboundSyncWorker: Performing initial inbound sync...');
    await runInitialInboundSync(_sessionManager); // Call the renamed function

    // Start the main loop
    _runLoop();
    QuizzerLogger.logMessage('InboundSyncWorker started and initial sync performed.');
  }

  /// Stops the worker loop.
  Future<void> stop() async {
    QuizzerLogger.logMessage('Entering InboundSyncWorker stop()...');
    if (!_isRunning || _stopCompleter == null) {
      QuizzerLogger.logMessage('InboundSyncWorker already stopped.');
      return; // Already stopped
    }
    _isRunning = false;

    QuizzerLogger.logMessage('InboundSyncWorker: Unsubscribing from onInboundSyncNeeded stream.');
    await _syncSubscription?.cancel();
    _syncSubscription = null;

    if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
      // Loop exit handles completion
    }
    QuizzerLogger.logMessage('InboundSyncWorker stop signal sent.');
  }
  // ----------------------

  // --- Main Loop ---
  Future<void> _runLoop() async {
    QuizzerLogger.logMessage('Entering InboundSyncWorker _runLoop()...');
    while (_isRunning) {
      QuizzerLogger.logMessage('InboundSyncWorker: Waiting for sync signal...');
      await _switchBoard.onInboundSyncNeeded.first;

      QuizzerLogger.logMessage('InboundSyncWorker: Woke up by sync signal.');
      if (!_isRunning) break;

      QuizzerLogger.logMessage('InboundSyncWorker: Signal received, performing inbound sync...');
      await _performInboundSync();
      if (!_isRunning) break;
    }
    if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
       _stopCompleter!.complete();
    }
    QuizzerLogger.logMessage('InboundSyncWorker loop finished.');
  }
  // -----------------

  // --- Core Sync Logic ---
  /// The core synchronization logic for subsequent syncs (after initial).
  Future<void> _performInboundSync() async {
    QuizzerLogger.logMessage('InboundSyncWorker: Starting periodic sync cycle.');
    if (_sessionManager.userId == null) {
      QuizzerLogger.logWarning('InboundSyncWorker: Cannot perform sync, no user logged in.');
      return;
    }

    final bool isConnected = await _checkConnectivity();
    if (!isConnected) {
      QuizzerLogger.logMessage('InboundSyncWorker: No network connectivity, skipping sync cycle.');
      return;
    }
    
    // For now, subsequent syncs will also run the full initial sync logic.
    // This can be optimized later to fetch only deltas if needed.
    await runInitialInboundSync(_sessionManager);

    // Build module records after inbound sync completes
    QuizzerLogger.logMessage('InboundSyncWorker: Building module records after sync...');
    await buildModuleRecords();

    QuizzerLogger.logMessage('InboundSyncWorker: Periodic inbound sync functions completed.');
  }
  // ----------------------

  // --- Network Connectivity Check ---
  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
      QuizzerLogger.logWarning('InboundSyncWorker: Network check failed (lookup empty/no address).');
      return false;
    } on SocketException catch (_) {
      QuizzerLogger.logMessage('InboundSyncWorker: Network check failed (SocketException): Likely offline.');
      return false;
    } catch (e) {
      QuizzerLogger.logError('InboundSyncWorker: Unexpected error during network check: $e');
      return false;
    }
  }
  // -------------------------------

   // --- Helper Functions ---
   Future<Database?> _getDbAccess() async {
      QuizzerLogger.logMessage('InboundSyncWorker: Requesting DB access...');
      final Database? db = await _dbMonitor.requestDatabaseAccess();
      if (db == null) {
          QuizzerLogger.logMessage('InboundSyncWorker: Database access not immediately available.');
      } else {
          QuizzerLogger.logMessage('InboundSyncWorker: Database access granted.');
      }
      return db;
   }
   // ------------------------
}

// Global instance (optional, if direct instantiation is preferred elsewhere, this can be removed)
// final InboundSyncWorker _globalInboundSyncWorker = InboundSyncWorker();
// InboundSyncWorker getInboundSyncWorker() => _globalInboundSyncWorker;

