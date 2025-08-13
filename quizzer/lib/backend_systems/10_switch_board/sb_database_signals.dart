import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

// ==========================================
// Database Monitor Signals
// ==========================================

/// Signals that the database monitor has finished processing all pending requests
/// This is emitted when the queue becomes empty after processing requests
void signalDatabaseMonitorQueueEmpty() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.databaseMonitorQueueEmptyController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Database Monitor Queue Empty');
    switchBoard.databaseMonitorQueueEmptyController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed DatabaseMonitorQueueEmpty stream.');
  }
}