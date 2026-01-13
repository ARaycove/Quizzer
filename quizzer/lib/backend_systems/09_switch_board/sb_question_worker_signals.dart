import 'package:quizzer/backend_systems/09_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

// ==========================================
// Question Queue Server Worker Signals
// ==========================================

/// Signals that the PreProcessWorker has completed a processing cycle
void signalPreProcessWorkerCycleComplete() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.preProcessWorkerCycleCompleteController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling PreProcessWorker Cycle Complete');
    switchBoard.preProcessWorkerCycleCompleteController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed PreProcessWorkerCycleComplete stream.');
  }
}

/// Signals that the CirculationWorker has added a question to circulation
void signalCirculationWorkerQuestionAdded() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.circulationWorkerQuestionAddedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling CirculationWorker Question Added');
    switchBoard.circulationWorkerQuestionAddedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed CirculationWorkerQuestionAdded stream.');
  }
}

/// Signals that the EligibilityCheckWorker has completed a processing cycle
void signalEligibilityCheckWorkerCycleComplete() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.eligibilityCheckWorkerCycleCompleteController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling EligibilityCheckWorker Cycle Complete');
    switchBoard.eligibilityCheckWorkerCycleCompleteController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed EligibilityCheckWorkerCycleComplete stream.');
  }
}

/// Signals that the PresentationSelectionWorker has completed a processing cycle
void signalPresentationSelectionWorkerCycleComplete() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.presentationSelectionWorkerCycleCompleteController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling PresentationSelectionWorker Cycle Complete');
    switchBoard.presentationSelectionWorkerCycleCompleteController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed PresentationSelectionWorkerCycleComplete stream.');
  }
}

/// Signals that a question has been answered correctly
void signalQuestionAnsweredCorrectly(String questionId) {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.questionAnsweredCorrectlyController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling question answered correctly: $questionId.');
    switchBoard.questionAnsweredCorrectlyController.add(questionId);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed QuestionAnsweredCorrectly stream.');
  }
}