import 'package:quizzer/backend_systems/06_question_queue_server/answered_history_monitor.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/question_queue_monitor.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

/// Requests the next question from the queue
/// Returns a dummy question if no real questions are available
Future<Map<String, dynamic>> getNextQuestion() async {
  QuizzerLogger.logMessage('API: Requesting next question from queue');
  final queueMonitor    = getQuestionQueueMonitor();

  
  // Use the monitor's method which handles locking and removal

  Map<String, dynamic> questionRecord = await queueMonitor.removeNextQuestion();

  if (questionRecord.isNotEmpty) {
    // Successfully removed a question from the queue
    QuizzerLogger.logMessage('Retrieved question from queue: ${questionRecord['question_id']}');
    // Add to answered history
    return questionRecord;
  } 
  else {
    // Queue was empty, generate a dummy question
    QuizzerLogger.logMessage('Queue empty, generating dummy question.');
    // Define options as a list first for clarity
    final List<String> dummyOptionsList = [
      'Add your own questions',
      'Activate an existing module',
      'Check back later'
    ];
    // Return the dummy question map
    return {
      'question_elements': [
        {'type': 'text', 'content': 'No more eligible questions to present today. You can:'}
      ],
      'answer_elements': [
        {'type': 'text', 'content': '1. Add your own questions\n2. Activate an existing module\n3. Check back later'}
      ],
      'question_type': 'multiple_choice',
      'options': dummyOptionsList.join(','),
      'correct_option_index': 0,
      'module_name': 'system',
      'time_stamp': DateTime.now().toIso8601String(),
      'question_id': 'dummy_question_01', // Ensure unique dummy ID
      'qst_contrib': 'system',
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
}