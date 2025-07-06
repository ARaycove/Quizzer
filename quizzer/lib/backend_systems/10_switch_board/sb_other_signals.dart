import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';

/// Signals login progress to the SwitchBoard
void signalLoginProgress(String message) {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.loginProgressController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling login progress: $message');
    switchBoard.loginProgressController.add(message);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed LoginProgress stream.');
  }
}
