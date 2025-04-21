import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

// Global question queue monitor instance
final QuestionQueueMonitor _globalQuestionQueueMonitor = QuestionQueueMonitor._internal();



/// Gets the global question queue monitor instance
QuestionQueueMonitor getQuestionQueueMonitor() => _globalQuestionQueueMonitor;

/// A monitor for controlling access to the question queue
class QuestionQueueMonitor {
  static final QuestionQueueMonitor _instance = QuestionQueueMonitor._internal();
  factory QuestionQueueMonitor() => _instance;
  QuestionQueueMonitor._internal();

  // Access control state
  bool _isLocked = false;
  final _accessQueue = <Completer<List<Map<String, dynamic>>>>[];

  // The actual question queue
  final List<Map<String, dynamic>> _questionQueue = [];

  /// Requests access to the question queue
  /// Returns the question queue if available, null if locked
  Future<List<Map<String, dynamic>>> requestQueueAccess() async {
    if (_isLocked) {
      final completer = Completer<List<Map<String, dynamic>>>();
      _accessQueue.add(completer);
      QuizzerLogger.logMessage('Question queue access queued, waiting for lock release');
      return await completer.future;
    }

    _isLocked = true;
    QuizzerLogger.logMessage('Question queue access granted with lock');
    return _questionQueue;
  }

  /// Releases the question queue lock
  void releaseQueueAccess() {
    if (!_isLocked) {
      QuizzerLogger.logMessage('Attempted to release unlocked question queue');
      return;
    } else {
      QuizzerLogger.logMessage('Question Queue Lock Released!');
    }

    if (_accessQueue.isNotEmpty) {
      final nextCompleter = _accessQueue.removeAt(0);
      QuizzerLogger.logMessage('Question queue access passed to next in queue');
      nextCompleter.complete(_questionQueue);
    } else {
      _isLocked = false;
      QuizzerLogger.logMessage('Question queue lock released');
    }
    QuizzerLogger.logMessage("Queue object $_questionQueue");
  }

  /// Gets the current size of the queue
  int get queueSize => _questionQueue.length;

  /// Checks if the queue is empty
  bool get isEmpty => _questionQueue.isEmpty;

  /// Clears the entire queue
  /// Should only be called after obtaining queue access
  void clearQueue() {
    if (!_isLocked) {
      QuizzerLogger.logError('Attempted to clear queue without lock');
      return;
    }
    _questionQueue.clear();
    QuizzerLogger.logMessage('Question queue cleared');
  }
}
