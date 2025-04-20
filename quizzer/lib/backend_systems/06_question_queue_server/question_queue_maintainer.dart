import 'dart:async';
import 'package:quizzer/backend_systems/06_question_queue_server/question_queue_monitor.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';


/// Starts the question queue maintenance process
/// This function runs continuously in the background to maintain the queue
Future<void> startQuestionQueueMaintenance() async {
  QuizzerLogger.logMessage('Starting question queue maintenance');
  final queueMonitor = getQuestionQueueMonitor();
  final dbMonitor = getDatabaseMonitor();
  
  while (true) {
    // 1. Check if we need to add questions to circulation
    if (await _shouldAddToCirculation(dbMonitor)) {
      // FIXME Do a very quick read operation to get required data, this frees up the dbMonitor sooner.
      await _addQuestionsToCirculation(dbMonitor);

    }

    // 2. Check if queue needs new items
    if (await _shouldAddToQueue(queueMonitor)) {
      // FIXME Do a very quick read operation to get required data for the _selectNextQuestion function
      // this ensure the dbMonitor is released sooner for other processes to use

      // selectNextQuestion won't be modifying the db at all so it should only need to take raw data for processing
      final question = await _selectNextQuestion(dbMonitor);
      if (question != null) {
        await _addToQueue(question, queueMonitor);
      }
    }

    // Delay ensures we don't gum up the system and CPU
    await Future.delayed(const Duration(seconds: 3));
  }
}

/// Determines if new questions should be added to circulation
Future<bool> _shouldAddToCirculation(DatabaseMonitor dbMonitor) async {
  final db = await dbMonitor.requestDatabaseAccess();
  if (db == null) {
    QuizzerLogger.logError('Failed to get database access');
    return false;
  }

  // TODO: Implement circulation check logic
  // - Check current circulation count
  // - Compare to desired ratio
  // - Consider user's daily question target
  dbMonitor.releaseDatabaseAccess();
  return false;
}

/// Adds new questions to circulation based on subject ratios
Future<void> _addQuestionsToCirculation(DatabaseMonitor dbMonitor) async {
  // Should take raw data and the monitor

  // TODO: Implement question addition logic
  // - Calculate subject ratios
  // - Select questions that help maintain ratios
  // - Update question status in database

  // Should return a list of questionId's that should be added to circulation
  // Up to now, the monitor should not be needed.
  // Once the list of questionId's is ready, request access from the monitor and make those updates.
}

/// Determines if the queue needs new items
Future<bool> _shouldAddToQueue(QuestionQueueMonitor queueMonitor) async {
  return queueMonitor.queueSize < 10;
}

/// Selects the next question to add to the queue
Future<Map<String, dynamic>?> _selectNextQuestion(DatabaseMonitor dbMonitor) async {
  final db = await dbMonitor.requestDatabaseAccess();
  if (db == null) {
    QuizzerLogger.logError('Failed to get database access');
    return null;
  }

  // TODO: Implement question selection logic
  // - Consider subject ratios
  // - Account for question history
  // - Ensure even distribution
  dbMonitor.releaseDatabaseAccess();
  return null;
}

/// Adds a question to the queue
Future<void> _addToQueue(Map<String, dynamic> question, QuestionQueueMonitor queueMonitor) async {
  // TODO: Implement queue addition logic
  // - Get queue access
  // - Add question
  // - Release queue access
}