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

  // --- Outbound Sync Needed Stream ---
  // Notifies when local data has changed and might need syncing *out* to the server.
  final StreamController<void> _outboundSyncNeededController = StreamController<void>.broadcast();

  /// Stream that fires when local data changes potentially requiring an outbound sync.
  Stream<void> get onOutboundSyncNeeded => _outboundSyncNeededController.stream;

  /// Signals that local data has changed and might need outbound synchronization.
  void signalOutboundSyncNeeded() {
    if (!_outboundSyncNeededController.isClosed) {
      // QuizzerLogger.logMessage('SwitchBoard: Signaling Outbound Sync Needed.'); // Keep commented for less noise initially
      _outboundSyncNeededController.add(null);
    } else {
      QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed OutboundSyncNeeded stream.');
    }
  }
  // -------------------------------------

  // --- Media Sync Status Processed Stream ---
  final StreamController<void> _mediaSyncStatusProcessedController = StreamController<void>.broadcast();

  /// Stream that fires after a media sync status has been processed (e.g., inserted/updated).
  Stream<void> get onMediaSyncStatusProcessed => _mediaSyncStatusProcessedController.stream;

  /// Signals that a media sync status has been processed.
  void signalMediaSyncStatusProcessed() {
    if (!_mediaSyncStatusProcessedController.isClosed) {
      QuizzerLogger.logMessage('SwitchBoard: Signaling Media Sync Status Processed.');
      _mediaSyncStatusProcessedController.add(null);
    } else {
      QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed MediaSyncStatusProcessed stream.');
    }
  }
  // -------------------------------------

  // --- Inbound Sync Needed Stream (NEW) ---
  final StreamController<void> _inboundSyncNeededController = StreamController<void>.broadcast();

  /// Stream that fires when an inbound sync is needed (e.g., after a push notification or periodic check).
  Stream<void> get onInboundSyncNeeded => _inboundSyncNeededController.stream;

  /// Signals that an inbound data sync should be triggered.
  void signalInboundSyncNeeded() {
    if (!_inboundSyncNeededController.isClosed) {
      // QuizzerLogger.logMessage('SwitchBoard: Signaling Inbound Sync Needed.'); // Keep commented for less noise
      _inboundSyncNeededController.add(null);
    } else {
      QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed InboundSyncNeeded stream.');
    }
  }
  // -------------------------------------

  // --- Initial Inbound Sync Complete Stream (NEW) ---
  final StreamController<void> _initialInboundSyncCompleteController = StreamController<void>.broadcast();

  /// Stream that fires when the InboundSyncWorker has completed its initial critical sync.
  Stream<void> get onInitialInboundSyncComplete => _initialInboundSyncCompleteController.stream;

  /// Signals that the InboundSyncWorker has completed its initial critical sync.
  void signalInitialInboundSyncComplete() {
    if (!_initialInboundSyncCompleteController.isClosed) {
      QuizzerLogger.logMessage('SwitchBoard: Signaling Initial Inbound Sync COMPLETE.');
      _initialInboundSyncCompleteController.add(null);
    } else {
      QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed InitialInboundSyncComplete stream.');
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
      //  QuizzerLogger.logMessage('Signaling PastDueCache added.');
      _pastDueCacheController.add(null);
    } else {
       QuizzerLogger.logWarning('Attempted to signal on closed PastDueCache stream.');
    }
  }

  // Consolidated signal method
  void signalEligibleCacheLow() { // Consolidated
    if (!_eligibleCacheLowController.isClosed) {
      //  QuizzerLogger.logMessage('SwitchBoard: Signaling EligibleCacheLow added.');
      _eligibleCacheLowController.add(null);
    } else {
       QuizzerLogger.logWarning('Attempted to signal on closed EligibleCacheLow stream.');
    }
  }

  // --- Dispose Method ---
  /// Closes all stream controllers. Should be called on application shutdown.
  void dispose() {
    QuizzerLogger.logMessage('Disposing SwitchBoard streams...');
    _dueDateWithin24hrsController.close();
    _moduleActivatedController.close();
    _moduleRecentlyActivatedController.close();
    _pastDueCacheController.close();
    _eligibleCacheLowController.close();
    _outboundSyncNeededController.close();
    _mediaSyncStatusProcessedController.close();
    _inboundSyncNeededController.close();
    _initialInboundSyncCompleteController.close();
    QuizzerLogger.logMessage('SwitchBoard disposed.');
  }
  // --------------------
}

// Optional: Global getter function
final SwitchBoard _switchBoard = SwitchBoard();
SwitchBoard getSwitchBoard() => _switchBoard;
