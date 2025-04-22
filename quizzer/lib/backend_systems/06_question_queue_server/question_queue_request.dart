import 'package:quizzer/backend_systems/06_question_queue_server/question_queue_monitor.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

/// Requests the next question from the queue
/// Returns null if no questions are available
Future<Map<String, dynamic>> getNextQuestion() async {
  // Request access to the shared question queue through the monitor
  QuizzerLogger.logMessage('Requesting next question from queue');
  final queueMonitor    = getQuestionQueueMonitor();
  
  // Keep trying until we get access to the queue
  while (true) {
    final questionBuffer = await queueMonitor.requestQueueAccess();
    
    // If access denied, wait and try again
    if (questionBuffer == null) {
      QuizzerLogger.logMessage('Queue access denied, retrying in 1 second');
      await Future.delayed(const Duration(seconds: 1));
      continue;
    }

    Map<String, dynamic> questionRecord;
    if (questionBuffer.isNotEmpty) {
      // Remove and return the last question from the queue
      questionRecord = questionBuffer.removeLast();
      queueMonitor.releaseQueueAccess();
      QuizzerLogger.logMessage('Retrieved question from queue');
    } else {
      queueMonitor.releaseQueueAccess();
      // Generate a dummy question when queue is empty to guide user actions
      QuizzerLogger.logMessage('Queue empty, generating dummy question');
      // Define options as a list first for clarity
      final List<String> dummyOptionsList = [
        'Add your own questions',
        'Activate an existing module',
        'Check back later'
      ];
      questionRecord = {
        'question_elements': [
          {'type': 'text', 'content': 'No more eligible questions to present today. You can:'}
        ],
        'answer_elements': [
          {'type': 'text', 'content': '1. Add your own questions\n2. Activate an existing module\n3. Check back later'}
        ],
        'question_type': 'multiple_choice',
        // Convert the list to a comma-separated String
        'options': dummyOptionsList.join(','),
        'correct_option_index': 0,
        'module_name': 'system',
        'time_stamp': DateTime.now().toIso8601String(),
        'question_id': 'dummy_question_01', // Ensure unique dummy ID
        'qst_contrib': 'system',
        // Add missing fields expected by the widget/DB schema if necessary,
        // even if dummy values
        'ans_flagged': 0,
        'ans_contrib': 'system',
        'concepts': '',
        'subjects': '',
        'qst_reviewer': null,
        'has_been_reviewed': true,
        'flag_for_removal': false,
        'completed': true
      };
    }
    
    return questionRecord;
  }
}