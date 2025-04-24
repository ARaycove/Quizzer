import 'package:quizzer/backend_systems/06_question_queue_server/answered_history_monitor.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'dart:async';



// Global instance
final QuestionQueueMonitor _globalQuestionQueueMonitor = QuestionQueueMonitor._internal();
QuestionQueueMonitor getQuestionQueueMonitor() => _globalQuestionQueueMonitor;

/// Monitor for the question queue with internal locking.
class QuestionQueueMonitor {
  static final QuestionQueueMonitor _instance = QuestionQueueMonitor._internal();
  factory QuestionQueueMonitor() => _instance;
  QuestionQueueMonitor._internal();

  // Access control state
  bool _isLocked = false;
  // Change completer type to void as we don't return queue directly from request
  final _accessQueue = <Completer<void>>[]; 

  // The actual question queue
  final List<Map<String, dynamic>> _questionQueue = [];

  // --- Private Lock Management ---
  // Renamed to private
  Future<void> _requestQueueAccess() async {
    if (_isLocked) {
      final completer = Completer<void>();
      _accessQueue.add(completer);
      QuizzerLogger.logMessage('Question queue lock requested, waiting...');
      await completer.future;
    }
    // Lock is now held by the current caller
    _isLocked = true;
    QuizzerLogger.logMessage('Question queue lock acquired.');
  }

  // Renamed to private
  void _releaseQueueAccess() {
    if (!_isLocked) {
      QuizzerLogger.logMessage('Attempted to release unlocked question queue');
      return;
    }
    
    // If others are waiting, pass control (lock remains held by the next completer)
    if (_accessQueue.isNotEmpty) {
      final nextCompleter = _accessQueue.removeAt(0);
      QuizzerLogger.logMessage('Question queue lock passed to next waiter.');
      // Complete the next waiter's completer, allowing them to acquire the lock
      nextCompleter.complete(); 
    } else {
      // No waiters, release the lock fully
      _isLocked = false;
      QuizzerLogger.logMessage('Question queue lock released (no waiters).');
    }
  }
  // -----------------------------

  // --- Public API Methods (Internal Locking) ---

  /// Adds a question if it's not already present. Handles locking internally.
  /// Returns true if added, false if duplicate.
  Future<bool> addQuestion(Map<String, dynamic> questionDetails) async {
    final String questionId = questionDetails['question_id'];
    await _requestQueueAccess();
    QuizzerLogger.logMessage('addQuestion: Acquired lock for $questionId');
    
    // Check for duplicates within the lock
    bool alreadyExists = _questionQueue.any((q) => q['question_id'] == questionId);
    bool added = false;

    if (!alreadyExists) {
      _questionQueue.add(questionDetails);
      added = true;
      QuizzerLogger.logMessage('addQuestion: Added $questionId. New size: ${_questionQueue.length}');
    } else {
      QuizzerLogger.logWarning('addQuestion: Duplicate $questionId not added.');
    }

    _releaseQueueAccess();
    QuizzerLogger.logMessage('addQuestion: Released lock for $questionId');
    return added;
  }

  /// Removes and returns the next question (last in list). Handles locking internally.
  /// Returns an empty map {} if the queue is empty.
  Future<Map<String, dynamic>> removeNextQuestion() async {
    await _requestQueueAccess();
    QuizzerLogger.logMessage('removeNextQuestion: Acquired lock.');
    Map<String, dynamic> removedQuestion = {};

    if (_questionQueue.isNotEmpty) {
      removedQuestion = _questionQueue.removeLast();
      QuizzerLogger.logMessage('removeNextQuestion: Removed ${removedQuestion['question_id']}. New size: ${_questionQueue.length}');
      // while holding the question queue lock, add the question we are about to return to the answer history queue
      final answerHistory = getAnsweredHistoryMonitor();
      answerHistory.addAnsweredQuestion(removedQuestion['question_id']);
    } else {
      QuizzerLogger.logMessage('removeNextQuestion: Queue empty, returning empty map.');
    }

    _releaseQueueAccess();
    QuizzerLogger.logMessage('removeNextQuestion: Released lock.');
    return removedQuestion;
  }

  /// Checks if a question ID exists in the queue. Handles locking internally.
  Future<bool> containsQuestion(String questionId) async {
    await _requestQueueAccess();
    QuizzerLogger.logMessage('containsQuestion: Acquired lock for $questionId check.');
    
    bool found = _questionQueue.any((q) => q['question_id'] == questionId);

    _releaseQueueAccess();
    QuizzerLogger.logMessage('containsQuestion: Released lock for $questionId check.');
    return found;
  }

  /// Gets a copy of the current list of question IDs. Handles locking internally.
  Future<List<String>> getQuestionIdsCopy() async {
    await _requestQueueAccess();
    QuizzerLogger.logMessage('getQuestionIdsCopy: Acquired lock.');

    List<String> idCopy = _questionQueue.map((q) => q['question_id'] as String).toList();

    _releaseQueueAccess();
    QuizzerLogger.logMessage('getQuestionIdsCopy: Released lock.');
    return idCopy;
  }

  /// Clears the entire queue. Handles locking internally.
  Future<void> clearQueue() async { // Made async
    await _requestQueueAccess();
    QuizzerLogger.logMessage('clearQueue: Acquired lock.');

    _questionQueue.clear();
    QuizzerLogger.logMessage('Question queue cleared internally.');

    _releaseQueueAccess();
    QuizzerLogger.logMessage('clearQueue: Released lock.');
  }

  // --- Public Getters (Read without lock - use with caution) ---
  /// Gets the current size of the queue (reads without lock).
  int get queueSize => _questionQueue.length;
  /// Checks if the queue is empty (reads without lock).
  bool get isEmpty => _questionQueue.isEmpty;

  // Removed old getQuestionIdsInQueue() as getQuestionIdsCopy() replaces it with locking.

}
