import 'package:quizzer/backend_systems/06_question_queue_server/pre_process_worker.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/circulation_worker.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/inactive_module_worker.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/due_date_worker.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/eligibility_check_worker.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/question_selection_worker.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

/// Starts all question queue server workers in the correct order
/// This function should be called after data caches are initialized
Future<void> startQuestionQueueServerWorkers() async {
  try {
    QuizzerLogger.logMessage('Starting question queue server workers...');
    
    // Start PreProcessWorker first
    QuizzerLogger.logMessage('Starting PreProcessWorker...');
    final preProcessWorker = PreProcessWorker();
    preProcessWorker.start();
    
    // Start CirculationWorker second
    QuizzerLogger.logMessage('Starting CirculationWorker...');
    final circulationWorker = CirculationWorker();
    circulationWorker.start();
    
    // Start InactiveModuleWorker third
    QuizzerLogger.logMessage('Starting InactiveModuleWorker...');
    final inactiveModuleWorker = InactiveModuleWorker();
    inactiveModuleWorker.start();
    
    // Start DueDateWorker fourth
    QuizzerLogger.logMessage('Starting DueDateWorker...');
    final dueDateWorker = DueDateWorker();
    dueDateWorker.start();
    
    // Start EligibilityCheckWorker fifth
    QuizzerLogger.logMessage('Starting EligibilityCheckWorker...');
    final eligibilityCheckWorker = EligibilityCheckWorker();
    eligibilityCheckWorker.start();
    
    // Start PresentationSelectionWorker sixth
    QuizzerLogger.logMessage('Starting PresentationSelectionWorker...');
    final presentationSelectionWorker = PresentationSelectionWorker();
    presentationSelectionWorker.start();
    
    QuizzerLogger.logMessage('Question queue server worker startup initiated');
  } catch (e) {
    QuizzerLogger.logError('Error starting question queue server workers - $e');
    rethrow;
  }
}
