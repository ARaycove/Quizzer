import 'package:quizzer/backend_systems/09_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

// ==========================================
// Inbound Sync Signals
// ==========================================

/// Signals that an inbound sync is needed
void signalInboundSyncNeeded() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.inboundSyncNeededController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Inbound Sync Needed.');
    switchBoard.inboundSyncNeededController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed InboundSyncNeeded stream.');
  }
}

/// Signals that the InboundSyncWorker has completed a sync cycle
void signalInboundSyncCycleComplete() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.inboundSyncCycleCompleteController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Inbound Sync Cycle Complete.');
    switchBoard.inboundSyncCycleCompleteController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed InboundSyncCycleComplete stream.');
  }
}

// ==========================================
// Outbound Sync Signals
// ==========================================

/// Signals that an outbound sync is needed
void signalOutboundSyncNeeded() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.outboundSyncNeededController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Outbound Sync Needed.');
    switchBoard.outboundSyncNeededController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed OutboundSyncNeeded stream.');
  }
}

/// Signals that the OutboundSyncWorker has completed a sync cycle
void signalOutboundSyncCycleComplete() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.outboundSyncCycleCompleteController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Outbound Sync Cycle Complete.');
    switchBoard.outboundSyncCycleCompleteController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed OutboundSyncCycleComplete stream.');
  }
}

// ==========================================
// Media Sync Signals
// ==========================================

/// Signals that a media sync is needed
void signalMediaSyncNeeded() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.mediaSyncNeededController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Media Sync Needed.');
    switchBoard.mediaSyncNeededController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed MediaSyncNeeded stream.');
  }
}

/// Signals that the MediaSyncWorker has completed a sync cycle
void signalMediaSyncCycleComplete() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.mediaSyncCycleCompleteController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Media Sync Cycle Complete.');
    switchBoard.mediaSyncCycleCompleteController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed MediaSyncCycleComplete stream.');
  }
}

/// Signals that media sync status has been processed
void signalMediaSyncStatusProcessed() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.mediaSyncCycleCompleteController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Media Sync Status Processed.');
    switchBoard.mediaSyncCycleCompleteController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed MediaSyncStatusProcessed stream.');
  }
}
