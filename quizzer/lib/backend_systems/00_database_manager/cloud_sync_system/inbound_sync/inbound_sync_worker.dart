import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'inbound_sync_functions.dart';
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
  // --------------------

  // --- Dependencies ---
  final SwitchBoard     _switchBoard    = getSwitchBoard();
  final SessionManager  _sessionManager = getSessionManager();
  // --------------------

  // --- Control Methods ---
  /// Starts the worker loop.
  Future<void> start() async {
    QuizzerLogger.logMessage('Entering InboundSyncWorker start()...');
    
    if (_sessionManager.userId == null) {
      QuizzerLogger.logWarning('InboundSyncWorker: Cannot start, no user logged in.');
      return;
    }
    
    _isRunning = true;
    _runLoop();
    QuizzerLogger.logMessage('InboundSyncWorker started.');
  }

  /// Stops the worker loop.
  Future<void> stop() async {
    QuizzerLogger.logMessage('Entering InboundSyncWorker stop()...');

    if (!_isRunning) {
      QuizzerLogger.logMessage('InboundSyncWorker: stop() called but worker is not running.');
      return; 
    }

    _isRunning = false;
    // Inbound sync worker only triggers on login, thus this will always be waiting infinitely if we wait on a signal    
    QuizzerLogger.logMessage('InboundSyncWorker stopped.');
  }
  // ----------------------

  // --- Main Loop ---
  Future<void> _runLoop() async {
    QuizzerLogger.logMessage('Entering InboundSyncWorker _runLoop()...');
    
    while (_isRunning) {
      // Check connectivity first
      final bool isConnected = await _checkConnectivity();
      if (!isConnected) {
        QuizzerLogger.logMessage('InboundSyncWorker: No network connectivity, waiting 5 minutes before next attempt...');
        await Future.delayed(const Duration(minutes: 5));
        continue;
      }
      
      // Run inbound sync
      QuizzerLogger.logMessage('InboundSyncWorker: Running inbound sync...');
      await runInboundSync(_sessionManager);
      QuizzerLogger.logMessage('InboundSyncWorker: Inbound sync completed.');
      
      // Signal that the sync cycle is complete
      signalInboundSyncCycleComplete();
      QuizzerLogger.logMessage('InboundSyncWorker: Sync cycle complete signal sent.');
      
      // Wait for signal that another cycle is needed
      QuizzerLogger.logMessage('InboundSyncWorker: Waiting for sync signal...');
      await _switchBoard.onInboundSyncNeeded.first;
      QuizzerLogger.logMessage('InboundSyncWorker: Woke up by sync signal.');
    }
    
    QuizzerLogger.logMessage('InboundSyncWorker loop finished.');
  }
  // -----------------

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
}

// Global instance (optional, if direct instantiation is preferred elsewhere, this can be removed)
// final InboundSyncWorker _globalInboundSyncWorker = InboundSyncWorker();
// InboundSyncWorker getInboundSyncWorker() => _globalInboundSyncWorker;

