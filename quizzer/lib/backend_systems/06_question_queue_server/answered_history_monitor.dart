import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

// Global answered history monitor instance
final AnsweredHistoryMonitor _globalAnsweredHistoryMonitor = AnsweredHistoryMonitor._internal();

/// Gets the global answered history monitor instance
AnsweredHistoryMonitor getAnsweredHistoryMonitor() => _globalAnsweredHistoryMonitor;

/// A monitor for controlling access to the recently answered questions history
class AnsweredHistoryMonitor {
  static final AnsweredHistoryMonitor _instance = AnsweredHistoryMonitor._internal();
  factory AnsweredHistoryMonitor() => _instance;
  AnsweredHistoryMonitor._internal();

  // Configuration

  // Access control state
  bool _isLocked = false;
  final _accessQueue = <Completer<void>>[]; // Queue for write access

  // The actual history list (stores question_id strings)
  final List<String> _answeredHistory = [];

  // --- Private Lock Management ---

  Future<void> _requestAnswerHistoryAccess() async {
    if (_isLocked) {
      final completer = Completer<void>();
      _accessQueue.add(completer);
      QuizzerLogger.logMessage('Answered History write access queued, waiting for lock release');
      await completer.future;
    }
    _isLocked = true;
     QuizzerLogger.logMessage('Answered History write access granted with lock');
  }

  void _releaseAnswerHistoryAccess() {
    if (!_isLocked) {
      QuizzerLogger.logMessage('Attempted to release unlocked Answered History');
      return;
    }

    if (_accessQueue.isNotEmpty) {
      final nextCompleter = _accessQueue.removeAt(0);
      QuizzerLogger.logMessage('Answered History write access passed to next in queue');
      nextCompleter.complete(); // Still locked, just passing control
    } else {
      _isLocked = false;
      QuizzerLogger.logMessage('Answered History lock released');
    }
  }
  
  // --- Public Methods ---

  /// Adds a question ID to the recently answered history.
  /// Manages the size limit of the history queue.
  Future<void> addAnsweredQuestion(String questionId) async {
    if (questionId.startsWith('dummy_')) {
        QuizzerLogger.logMessage('Skipping adding dummy question to answered history.');
        return; // Do not add dummy questions
    }
    
    await _requestAnswerHistoryAccess();
    try {
      QuizzerLogger.logMessage('Adding question $questionId to answered history.');
      // Remove if already exists to ensure it moves to the front (most recent)
      _answeredHistory.remove(questionId); 
      
      // Add to the front of the list
      _answeredHistory.insert(0, questionId);
      QuizzerLogger.logSuccess('Current answered history size: ${_answeredHistory.length}'); // Log size instead of full list
    } finally {
      _releaseAnswerHistoryAccess();
    }
  }

  /// Checks if a question ID is present in the *most recent* answered history (last 5).
  /// This method does not require a lock as reads on Lists are generally safe,
  /// but be aware of potential race conditions if checking during a concurrent write.
  bool isInRecentHistory(String questionId) {
    // Reading the list directly without a lock.
    // Determine the range to check (last 5 or fewer)
    final int historyLength = _answeredHistory.length;
    final int checkDepth = historyLength < 5 ? historyLength : 5;
    
    if (checkDepth == 0) return false; // History is empty

    // Get the sublist representing the last 'checkDepth' items
    // Note: index 0 is the *most* recent, so we take the first 'checkDepth' elements
    final List<String> recentSublist = _answeredHistory.sublist(0, checkDepth);
    
    final bool found = recentSublist.contains(questionId);
    
    if (found) {
        QuizzerLogger.logMessage('Checked last $checkDepth answered: $questionId IS present.');
    } else {
       // QuizzerLogger.logMessage('Checked last $checkDepth answered: $questionId is NOT present.'); // Reduce log noise
    }
    return found;
  }

  /// Gets a copy of the current answered history list (read-only).
  List<String> getRecentHistoryCopy() {
     // Return a copy to prevent external modification
     return List<String>.from(_answeredHistory);
  }
} 