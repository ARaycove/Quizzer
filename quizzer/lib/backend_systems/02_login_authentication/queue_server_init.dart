import 'package:quizzer/backend_systems/06_question_queue_server/circulation_worker.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/question_selection_worker.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/09_data_caches/question_queue_cache.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

/// Starts all question queue server workers in the correct order
/// This function should be called after data caches are initialized
/// Waits for a question to be added to the queue cache before returning
Future<void> startQuestionQueueServer() async {
  try {
    QuizzerLogger.logMessage('Starting question queue server workers...');
    
    // Start CirculationWorker first
    QuizzerLogger.logMessage('Starting CirculationWorker...');
    final circulationWorker = CirculationWorker();
    circulationWorker.start(); // Don't await - start in rapid succession
    
    // Start PresentationSelectionWorker second
    QuizzerLogger.logMessage('Starting PresentationSelectionWorker...');
    final presentationSelectionWorker = PresentationSelectionWorker();
    presentationSelectionWorker.start(); // Don't await - start in rapid succession
    
    QuizzerLogger.logMessage('Question queue server worker startup initiated');
    
    // Check if there are eligible questions for the user
    final sessionManager = getSessionManager();
    if (sessionManager.userId != null) {
      final eligibleQuestions = await getEligibleUserQuestionAnswerPairs(sessionManager.userId!);
      
      if (eligibleQuestions.isNotEmpty) {
        QuizzerLogger.logMessage('Found ${eligibleQuestions.length} eligible questions - waiting for questions to be added to cache...');
        
        // Wait for at least one question to be added to the cache
        final questionQueueCache = QuestionQueueCache();
        while (await questionQueueCache.getLength() == 0) {
          await Future.delayed(const Duration(milliseconds: 100)); // Small delay to avoid busy waiting
        }
        
        QuizzerLogger.logSuccess('Questions are now available in cache');
      } else {
        QuizzerLogger.logMessage('No eligible questions found - proceeding without waiting');
      }
    } else {
      QuizzerLogger.logMessage('No user logged in - proceeding without waiting for questions');
    }
    
  } catch (e) {
    QuizzerLogger.logError('Error starting question queue server workers - $e');
    rethrow;
  }
}
