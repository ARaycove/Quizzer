import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

// ==========================================
//               Switch Board
// ==========================================
// The purpose of the switch board is to allow different sub-systems to
// efficiently communicate with one another via Streams, providing a central
// hub for event signaling and listening.

/// Manages various broadcast streams for inter-system communication.
/// Implements the singleton pattern.
class SwitchBoard {
  // --- Singleton Setup ---
  static final SwitchBoard _instance = SwitchBoard._internal();
  factory SwitchBoard() => _instance;
  SwitchBoard._internal() {
    QuizzerLogger.logMessage('SwitchBoard initialized.');
  }
  // --------------------

  // --- Due Date Within 24hrs Cache Stream ---
  // Notifies when a record is added to the DueDateWithin24hrsCache *when it was previously empty*.
  final StreamController<void> _dueDateWithin24hrsController = StreamController<void>.broadcast();

  /// Stream that fires when a record is added to a previously empty DueDateWithin24hrsCache.
  Stream<void> get onDueDateWithin24hrsAdded => _dueDateWithin24hrsController.stream;

  /// Signals that a record has been added to the DueDateWithin24hrsCache when it was empty.
  void signalDueDateWithin24hrsAdded() {
    if (!_dueDateWithin24hrsController.isClosed) {
       // QuizzerLogger.logMessage('SwitchBoard: Signaling DueDateWithin24hrs added.'); // Optional Log
      _dueDateWithin24hrsController.add(null);
    } else {
       QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed DueDateWithin24hrs stream.');
    }
  }
  // -------------------------------------
  // --- Module Activated Stream ---
  // Notifies when a module has been deactivated by the user.
  final StreamController<String> _moduleActivatedController = StreamController<String>.broadcast();

  /// Stream that fires when a module is deactivated, emitting the module name.
  Stream<String> get onModuleActivated => _moduleActivatedController.stream;

  /// Signals that a module has been deactivated.
  void signalModuleActivated(String moduleName) {
    if (!_moduleActivatedController.isClosed) {
       QuizzerLogger.logMessage('SwitchBoard: Signaling module deactivated: $moduleName.');
      _moduleActivatedController.add(moduleName);
    } else {
       QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed ModuleDeactivated stream.');
    }
  }
  // -------------------------------------

  // --- Module Recently Activated Stream (New) ---
  // Notifies when a module has just been activated by the user, providing the activation time.
  final StreamController<DateTime> _moduleRecentlyActivatedController = StreamController<DateTime>.broadcast();

  /// Stream that fires when a module is recently activated, emitting the activation time.
  Stream<DateTime> get onModuleRecentlyActivated => _moduleRecentlyActivatedController.stream;

  /// Signals that a module has been recently activated.
  void signalModuleRecentlyActivated(DateTime activationTime) {
    if (!_moduleRecentlyActivatedController.isClosed) {
       QuizzerLogger.logMessage('SwitchBoard: Signaling module recently activated at $activationTime.');
      _moduleRecentlyActivatedController.add(activationTime);
    } else {
       QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed ModuleRecentlyActivated stream.');
    }
  }
  // -------------------------------------

  // --- Past Due Cache Stream (New) ---
  final StreamController<void> _pastDueCacheController = StreamController<void>.broadcast();
  // Single stream for low eligible cache conditions
  final StreamController<void> _eligibleCacheLowController = StreamController<void>.broadcast(); // Consolidated

  /// Stream that fires when a record is added to a previously empty PastDueCache.
  Stream<void> get onPastDueCacheAdded => _pastDueCacheController.stream;
  // Public getter for the consolidated stream
  Stream<void> get onEligibleCacheLowSignal => _eligibleCacheLowController.stream; // Consolidated

  /// Signals that a record has been added to the PastDueCache when it was empty.
  void signalPastDueCacheAdded() {
    if (!_pastDueCacheController.isClosed) {
       QuizzerLogger.logMessage('SwitchBoard: Signaling PastDueCache added.');
      _pastDueCacheController.add(null);
    } else {
       QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed PastDueCache stream.');
    }
  }

  // Consolidated signal method
  void signalEligibleCacheLow() { // Consolidated
    if (!_eligibleCacheLowController.isClosed) {
       QuizzerLogger.logMessage('SwitchBoard: Signaling EligibleCacheLow added.');
      _eligibleCacheLowController.add(null);
    } else {
       QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed EligibleCacheLow stream.');
    }
  }

  // --- Dispose Method ---
  /// Closes all stream controllers. Should be called on application shutdown.
  void dispose() {
    QuizzerLogger.logMessage('Disposing SwitchBoard streams...');
    _dueDateWithin24hrsController.close();
    _moduleActivatedController.close(); // Close original controller
    _moduleRecentlyActivatedController.close(); // Close new controller
    _pastDueCacheController.close(); // Close new PastDue stream
    _eligibleCacheLowController.close(); // Consolidated
    QuizzerLogger.logMessage('SwitchBoard disposed.');
  }
  // --------------------
}

// Optional: Global getter function
final SwitchBoard _switchBoard = SwitchBoard();
SwitchBoard getSwitchBoard() => _switchBoard;
