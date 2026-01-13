import 'package:quizzer/backend_systems/09_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

// ==========================================
// Answer History Cache Signals
// ==========================================

/// Signals that a question ID has been added to the answer history cache
void signalAnswerHistoryAdded() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.answerHistoryAddedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Answer History Added');
    switchBoard.answerHistoryAddedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed AnswerHistoryAdded stream.');
  }
}

/// Signals that a question ID has been removed from the answer history cache
void signalAnswerHistoryRemoved() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.answerHistoryRemovedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Answer History Removed');
    switchBoard.answerHistoryRemovedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed AnswerHistoryRemoved stream.');
  }
}

// ==========================================
// Circulating Questions Cache Signals
// ==========================================

/// Signals that a question ID has been added to the circulating questions cache
void signalCirculatingQuestionsAdded() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.circulatingQuestionsAddedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Circulating Questions Added');
    switchBoard.circulatingQuestionsAddedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed CirculatingQuestionsAdded stream.');
  }
}

/// Signals that a question ID has been removed from the circulating questions cache
void signalCirculatingQuestionsRemoved() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.circulatingQuestionsRemovedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Circulating Questions Removed');
    switchBoard.circulatingQuestionsRemovedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed CirculatingQuestionsRemoved stream.');
  }
}

// ==========================================
// Due Date Beyond 24hrs Cache Signals
// ==========================================

/// Signals that a record has been added to the due date beyond 24hrs cache
void signalDueDateBeyond24hrsAdded() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.dueDateBeyond24hrsAddedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Due Date Beyond 24hrs Added');
    switchBoard.dueDateBeyond24hrsAddedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed DueDateBeyond24hrsAdded stream.');
  }
}

/// Signals that a record has been removed from the due date beyond 24hrs cache
void signalDueDateBeyond24hrsRemoved() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.dueDateBeyond24hrsRemovedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Due Date Beyond 24hrs Removed');
    switchBoard.dueDateBeyond24hrsRemovedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed DueDateBeyond24hrsRemoved stream.');
  }
}

// ==========================================
// Due Date Within 24hrs Cache Signals
// ==========================================

/// Signals that a record has been added to the due date within 24hrs cache
void signalDueDateWithin24hrsAdded() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.dueDateWithin24hrsAddedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Due Date Within 24hrs Added');
    switchBoard.dueDateWithin24hrsAddedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed DueDateWithin24hrsAdded stream.');
  }
}

/// Signals that a record has been removed from the due date within 24hrs cache
void signalDueDateWithin24hrsRemoved() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.dueDateWithin24hrsRemovedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Due Date Within 24hrs Removed');
    switchBoard.dueDateWithin24hrsRemovedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed DueDateWithin24hrsRemoved stream.');
  }
}

// ==========================================
// Eligible Questions Cache Signals
// ==========================================

/// Signals that a record has been added to the eligible questions cache
void signalEligibleQuestionsAdded() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.eligibleQuestionsAddedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Eligible Questions Added');
    switchBoard.eligibleQuestionsAddedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed EligibleQuestionsAdded stream.');
  }
}

/// Signals that a record has been removed from the eligible questions cache
void signalEligibleQuestionsRemoved() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.eligibleQuestionsRemovedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Eligible Questions Removed');
    switchBoard.eligibleQuestionsRemovedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed EligibleQuestionsRemoved stream.');
  }
}

// ==========================================
// Module Inactive Cache Signals
// ==========================================

/// Signals that a record has been added to the module inactive cache
void signalModuleInactiveAdded() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.moduleInactiveAddedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Module Inactive Added');
    switchBoard.moduleInactiveAddedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed ModuleInactiveAdded stream.');
  }
}

/// Signals that a record has been removed from the module inactive cache
void signalModuleInactiveRemoved() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.moduleInactiveRemovedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Module Inactive Removed');
    switchBoard.moduleInactiveRemovedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed ModuleInactiveRemoved stream.');
  }
}

// ==========================================
// Non Circulating Questions Cache Signals
// ==========================================

/// Signals that a record has been added to the non circulating questions cache
void signalNonCirculatingQuestionsAdded() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.nonCirculatingQuestionsAddedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Non Circulating Questions Added');
    switchBoard.nonCirculatingQuestionsAddedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed NonCirculatingQuestionsAdded stream.');
  }
}

/// Signals that a record has been removed from the non circulating questions cache
void signalNonCirculatingQuestionsRemoved() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.nonCirculatingQuestionsRemovedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Non Circulating Questions Removed');
    switchBoard.nonCirculatingQuestionsRemovedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed NonCirculatingQuestionsRemoved stream.');
  }
}

// ==========================================
// Past Due Cache Signals
// ==========================================

/// Signals that a record has been added to the past due cache
void signalPastDueAdded() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.pastDueAddedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Past Due Added');
    switchBoard.pastDueAddedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed PastDueAdded stream.');
  }
}

/// Signals that a record has been removed from the past due cache
void signalPastDueRemoved() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.pastDueRemovedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Past Due Removed');
    switchBoard.pastDueRemovedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed PastDueRemoved stream.');
  }
}

// ==========================================
// Question Queue Cache Signals
// ==========================================

/// Signals that a record has been added to the question queue cache
void signalQuestionQueueAdded() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.questionQueueAddedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Question Queue Added');
    switchBoard.questionQueueAddedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed QuestionQueueAdded stream.');
  }
}

/// Signals that a record has been removed from the question queue cache
void signalQuestionQueueRemoved() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.questionQueueRemovedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Question Queue Removed');
    switchBoard.questionQueueRemovedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed QuestionQueueRemoved stream.');
  }
}

// ==========================================
// Temp Question Details Cache Signals
// ==========================================

/// Signals that a record has been added to the temp question details cache
void signalTempQuestionDetailsAdded() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.tempQuestionDetailsAddedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Temp Question Details Added');
    switchBoard.tempQuestionDetailsAddedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed TempQuestionDetailsAdded stream.');
  }
}

/// Signals that a record has been removed from the temp question details cache
void signalTempQuestionDetailsRemoved() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.tempQuestionDetailsRemovedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Temp Question Details Removed');
    switchBoard.tempQuestionDetailsRemovedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed TempQuestionDetailsRemoved stream.');
  }
}

// ==========================================
// Unprocessed Cache Signals
// ==========================================

/// Signals that a record has been added to the unprocessed cache
void signalUnprocessedAdded() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.unprocessedAddedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Unprocessed Added');
    switchBoard.unprocessedAddedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed UnprocessedAdded stream.');
  }
}

/// Signals that a record has been removed from the unprocessed cache
void signalUnprocessedRemoved() {
  final switchBoard = getSwitchBoard();
  if (!switchBoard.unprocessedRemovedController.isClosed) {
    QuizzerLogger.logMessage('SwitchBoard: Signaling Unprocessed Removed');
    switchBoard.unprocessedRemovedController.add(null);
  } else {
    QuizzerLogger.logWarning('SwitchBoard: Attempted to signal on closed UnprocessedRemoved stream.');
  }
}
