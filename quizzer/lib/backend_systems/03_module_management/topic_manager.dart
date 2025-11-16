// Class object to contain all functionality related to manipulating what topic(s) a 
// question answer pair record belongs to

// A topic is a semantic clustering of documents, in human terms a topic could be a subject
// label, a concept label, something very granular like "monkeys in spacesuits" which would 
// be a highly specific topic. The topic model used to categorize questions and academic
// material works to find hierarchical clustering of data. For this reason a question may
// belong to multiple topics at once.
import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';



class TopicManager {
  static final TopicManager _instance = TopicManager._internal();
  factory TopicManager() => _instance;
  TopicManager._internal();

  bool _isRunning = false;
  Completer<void>? _stopCompleter;

  // TopicManager will work by implementing a queue structure. The TopicManager will receive
  // questionId's in the queue, and process each item in the queue as necessary
  // TODO Implement Queue Structure

  Future<void> start() async {
    QuizzerLogger.logMessage('Entering TopicManager start()');

    if (_isRunning) {
      QuizzerLogger.logWarning('TopicManager is already running');
      return;
    }

    _isRunning = true;
    _stopCompleter = Completer<void>();
    QuizzerLogger.logMessage('TopicManager started');
    _runLoop();
  }

  Future<void> stop() async {
    QuizzerLogger.logMessage('Entering TopicManager stop()');
    _isRunning = false;
    if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
      _stopCompleter!.complete();
    }

    QuizzerLogger.logMessage('TopicManager stopped.');
  }

  Future<void> _runLoop() async {
    QuizzerLogger.logMessage('Starting Topic Manager Process. . .');

    while (true) {
      await _runCycle();
      break;
    }
  }

  Future<void> _runCycle() async {
    // Collect all items in queue at this moment and process them
    _processQueueItems();
    // TODO Implement
  }

  Future<void> _processQueueItems() async {

  }


}
