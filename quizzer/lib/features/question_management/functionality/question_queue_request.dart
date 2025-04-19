import 'package:quizzer/features/question_management/functionality/question_queue_monitor.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';

/// Requests the next question from the queue
/// Returns null if no questions are available
Future<Map<String, dynamic>?> getNextQuestion() async {
  // TODO: Implement queue access and question retrieval
  QuizzerLogger.logMessage('Requesting next question from queue');
  return null;
}

/// Checks if there are questions available in the queue
Future<bool> hasQuestions() async {
  // TODO: Implement queue availability check
  QuizzerLogger.logMessage('Checking queue availability');
  return false;
}

/// Returns the current size of the question queue
int getQueueSize() {
  return getQuestionQueueMonitor().queueSize;
}
