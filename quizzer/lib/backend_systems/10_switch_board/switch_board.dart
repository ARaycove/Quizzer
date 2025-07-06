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

  // ==========================================
  // Inbound Sync Streams
  // ==========================================
  
  // --- Inbound Sync Needed Stream ---
  final StreamController<void> inboundSyncNeededController = StreamController<void>.broadcast();
  Stream<void> get onInboundSyncNeeded => inboundSyncNeededController.stream;
  // -------------------------------------

  // --- Inbound Sync Cycle Complete Stream ---
  final StreamController<void> inboundSyncCycleCompleteController = StreamController<void>.broadcast();
  Stream<void> get onInboundSyncCycleComplete => inboundSyncCycleCompleteController.stream;
  // -------------------------------------

  // ==========================================
  // Outbound Sync Streams
  // ==========================================
  
  // --- Outbound Sync Needed Stream ---
  final StreamController<void> outboundSyncNeededController = StreamController<void>.broadcast();
  Stream<void> get onOutboundSyncNeeded => outboundSyncNeededController.stream;
  // -------------------------------------

  // --- Outbound Sync Cycle Complete Stream ---
  final StreamController<void> outboundSyncCycleCompleteController = StreamController<void>.broadcast();
  Stream<void> get onOutboundSyncCycleComplete => outboundSyncCycleCompleteController.stream;
  // -------------------------------------

  // ==========================================
  // Media Sync Streams
  // ==========================================
  
  // --- Media Sync Needed Stream ---
  final StreamController<void> mediaSyncNeededController = StreamController<void>.broadcast();
  Stream<void> get onMediaSyncNeeded => mediaSyncNeededController.stream;
  // -------------------------------------

  // --- Media Sync Cycle Complete Stream ---
  final StreamController<void> mediaSyncCycleCompleteController = StreamController<void>.broadcast();
  Stream<void> get onMediaSyncCycleComplete => mediaSyncCycleCompleteController.stream;
  // -------------------------------------

  // ==========================================
  // Data Caches Streams
  // ==========================================

  // --- Answer History Cache Streams ---
  final StreamController<void> answerHistoryAddedController = StreamController<void>.broadcast();
  Stream<void> get onAnswerHistoryAdded => answerHistoryAddedController.stream;
  // -------------------------------------

  final StreamController<void> answerHistoryRemovedController = StreamController<void>.broadcast();
  Stream<void> get onAnswerHistoryRemoved => answerHistoryRemovedController.stream;
  // -------------------------------------

  // --- Circulating Questions Cache Streams ---
  final StreamController<void> circulatingQuestionsAddedController = StreamController<void>.broadcast();
  Stream<void> get onCirculatingQuestionsAdded => circulatingQuestionsAddedController.stream;
  // -------------------------------------

  final StreamController<void> circulatingQuestionsRemovedController = StreamController<void>.broadcast();
  Stream<void> get onCirculatingQuestionsRemoved => circulatingQuestionsRemovedController.stream;
  // -------------------------------------

  // --- Due Date Beyond 24hrs Cache Streams ---
  final StreamController<void> dueDateBeyond24hrsAddedController = StreamController<void>.broadcast();
  Stream<void> get onDueDateBeyond24hrsAdded => dueDateBeyond24hrsAddedController.stream;
  // -------------------------------------

  final StreamController<void> dueDateBeyond24hrsRemovedController = StreamController<void>.broadcast();
  Stream<void> get onDueDateBeyond24hrsRemoved => dueDateBeyond24hrsRemovedController.stream;
  // -------------------------------------

  // --- Due Date Within 24hrs Cache Streams ---
  final StreamController<void> dueDateWithin24hrsAddedController = StreamController<void>.broadcast();
  Stream<void> get onDueDateWithin24hrsAdded => dueDateWithin24hrsAddedController.stream;
  // -------------------------------------

  final StreamController<void> dueDateWithin24hrsRemovedController = StreamController<void>.broadcast();
  Stream<void> get onDueDateWithin24hrsRemoved => dueDateWithin24hrsRemovedController.stream;
  // -------------------------------------

  // --- Eligible Questions Cache Streams ---
  final StreamController<void> eligibleQuestionsAddedController = StreamController<void>.broadcast();
  Stream<void> get onEligibleQuestionsAdded => eligibleQuestionsAddedController.stream;
  // -------------------------------------

  final StreamController<void> eligibleQuestionsRemovedController = StreamController<void>.broadcast();
  Stream<void> get onEligibleQuestionsRemoved => eligibleQuestionsRemovedController.stream;
  // -------------------------------------

  // --- Module Inactive Cache Streams ---
  final StreamController<void> moduleInactiveAddedController = StreamController<void>.broadcast();
  Stream<void> get onModuleInactiveAdded => moduleInactiveAddedController.stream;
  // -------------------------------------

  final StreamController<void> moduleInactiveRemovedController = StreamController<void>.broadcast();
  Stream<void> get onModuleInactiveRemoved => moduleInactiveRemovedController.stream;
  // -------------------------------------

  // --- Non Circulating Questions Cache Streams ---
  final StreamController<void> nonCirculatingQuestionsAddedController = StreamController<void>.broadcast();
  Stream<void> get onNonCirculatingQuestionsAdded => nonCirculatingQuestionsAddedController.stream;
  // -------------------------------------

  final StreamController<void> nonCirculatingQuestionsRemovedController = StreamController<void>.broadcast();
  Stream<void> get onNonCirculatingQuestionsRemoved => nonCirculatingQuestionsRemovedController.stream;
  // -------------------------------------

  // --- Past Due Cache Streams ---
  final StreamController<void> pastDueAddedController = StreamController<void>.broadcast();
  Stream<void> get onPastDueAdded => pastDueAddedController.stream;
  // -------------------------------------

  final StreamController<void> pastDueRemovedController = StreamController<void>.broadcast();
  Stream<void> get onPastDueRemoved => pastDueRemovedController.stream;
  // -------------------------------------

  // --- Question Queue Cache Streams ---
  final StreamController<void> questionQueueAddedController = StreamController<void>.broadcast();
  Stream<void> get onQuestionQueueAdded => questionQueueAddedController.stream;
  // -------------------------------------

  final StreamController<void> questionQueueRemovedController = StreamController<void>.broadcast();
  Stream<void> get onQuestionQueueRemoved => questionQueueRemovedController.stream;
  // -------------------------------------

  // --- Temp Question Details Cache Streams ---
  final StreamController<void> tempQuestionDetailsAddedController = StreamController<void>.broadcast();
  Stream<void> get onTempQuestionDetailsAdded => tempQuestionDetailsAddedController.stream;
  // -------------------------------------

  final StreamController<void> tempQuestionDetailsRemovedController = StreamController<void>.broadcast();
  Stream<void> get onTempQuestionDetailsRemoved => tempQuestionDetailsRemovedController.stream;
  // -------------------------------------

  // --- Unprocessed Cache Streams ---
  final StreamController<void> unprocessedAddedController = StreamController<void>.broadcast();
  Stream<void> get onUnprocessedAdded => unprocessedAddedController.stream;
  // -------------------------------------

  final StreamController<void> unprocessedRemovedController = StreamController<void>.broadcast();
  Stream<void> get onUnprocessedRemoved => unprocessedRemovedController.stream;
  // -------------------------------------

  // --- Question Queue Server Worker Streams ---
  final StreamController<void> preProcessWorkerCycleCompleteController = StreamController<void>.broadcast();
  Stream<void> get onPreProcessWorkerCycleComplete => preProcessWorkerCycleCompleteController.stream;
  // -------------------------------------

  final StreamController<void> circulationWorkerQuestionAddedController = StreamController<void>.broadcast();
  Stream<void> get onCirculationWorkerQuestionAdded => circulationWorkerQuestionAddedController.stream;
  // -------------------------------------

  final StreamController<void> eligibilityCheckWorkerCycleCompleteController = StreamController<void>.broadcast();
  Stream<void> get onEligibilityCheckWorkerCycleComplete => eligibilityCheckWorkerCycleCompleteController.stream;
  // -------------------------------------

  final StreamController<void> presentationSelectionWorkerCycleCompleteController = StreamController<void>.broadcast();
  Stream<void> get onPresentationSelectionWorkerCycleComplete => presentationSelectionWorkerCycleCompleteController.stream;
  // -------------------------------------

  // ==========================================
  // Other System Streams
  // ==========================================

  // --- Login Progress Stream ---
  final StreamController<String> loginProgressController = StreamController<String>.broadcast();
  Stream<String> get onLoginProgress => loginProgressController.stream;
  // -------------------------------------

  // --- Module Activated Stream ---
  final StreamController<String> _moduleActivatedController = StreamController<String>.broadcast();
  Stream<String> get onModuleActivated => _moduleActivatedController.stream;
  void signalModuleActivated(String moduleName) {
    if (!_moduleActivatedController.isClosed) {
      QuizzerLogger.logMessage('SwitchBoard: Signaling module activated: $moduleName.');
      _moduleActivatedController.add(moduleName);
    } else {
      QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed ModuleActivated stream.');
    }
  }
  // -------------------------------------

  // --- Module Recently Activated Stream ---
  final StreamController<DateTime> _moduleRecentlyActivatedController = StreamController<DateTime>.broadcast();
  Stream<DateTime> get onModuleRecentlyActivated => _moduleRecentlyActivatedController.stream;
  void signalModuleRecentlyActivated(DateTime activationTime) {
    if (!_moduleRecentlyActivatedController.isClosed) {
      QuizzerLogger.logMessage('SwitchBoard: Signaling module recently activated at $activationTime.');
      _moduleRecentlyActivatedController.add(activationTime);
    } else {
      QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed ModuleRecentlyActivated stream.');
    }
  }
  // -------------------------------------

  // --- Dispose Method ---
  /// Closes all stream controllers. Should be called on application shutdown.
  void dispose() {
    QuizzerLogger.logMessage('Disposing SwitchBoard streams...');
    
    // Sync streams
    inboundSyncNeededController.close();
    inboundSyncCycleCompleteController.close();
    outboundSyncNeededController.close();
    outboundSyncCycleCompleteController.close();
    mediaSyncNeededController.close();
    mediaSyncCycleCompleteController.close();
    
    // Data cache streams
    answerHistoryAddedController.close();
    answerHistoryRemovedController.close();
    circulatingQuestionsAddedController.close();
    circulatingQuestionsRemovedController.close();
    dueDateBeyond24hrsAddedController.close();
    dueDateBeyond24hrsRemovedController.close();
    dueDateWithin24hrsAddedController.close();
    dueDateWithin24hrsRemovedController.close();
    eligibleQuestionsAddedController.close();
    eligibleQuestionsRemovedController.close();
    moduleInactiveAddedController.close();
    moduleInactiveRemovedController.close();
    nonCirculatingQuestionsAddedController.close();
    nonCirculatingQuestionsRemovedController.close();
    pastDueAddedController.close();
    pastDueRemovedController.close();
    questionQueueAddedController.close();
    questionQueueRemovedController.close();
    tempQuestionDetailsAddedController.close();
    tempQuestionDetailsRemovedController.close();
    unprocessedAddedController.close();
    unprocessedRemovedController.close();

    // Question Queue Server Worker Streams
    preProcessWorkerCycleCompleteController.close();
    circulationWorkerQuestionAddedController.close();
    eligibilityCheckWorkerCycleCompleteController.close();
    presentationSelectionWorkerCycleCompleteController.close();
    
    // Other streams
    loginProgressController.close();
    _moduleActivatedController.close();
    _moduleRecentlyActivatedController.close();
    
    QuizzerLogger.logMessage('SwitchBoard disposed.');
  }
  // --------------------
}

// Optional: Global getter function
final SwitchBoard _switchBoard = SwitchBoard();
SwitchBoard getSwitchBoard() => _switchBoard;
