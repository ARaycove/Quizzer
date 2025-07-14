import 'dart:async';
import 'dart:math'; // For min function
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_cache_signals.dart'; // Import cache signals
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Added for error handling

// ==========================================
/// Cache storing an ordered history of recently answered question IDs.
/// Used by the Eligibility Worker.
/// Implements the singleton pattern.
class AnswerHistoryCache {
  // Singleton pattern setup
  static final AnswerHistoryCache _instance = AnswerHistoryCache._internal();
  factory AnswerHistoryCache() => _instance;
  AnswerHistoryCache._internal(); // Private constructor

  final Lock _lock = Lock();
  final List<String> _history = []; // Stores question IDs in order of answering (most recent first)

  // --- Add Record ---

  /// Adds a question ID to the front of the answer history.
  /// If the ID already exists, it is moved to the front.
  /// Asserts that the questionId is not empty.
  /// Ensures thread safety using a lock.
  /// Signals the SwitchBoard when a question is added.
  Future<void> addRecord(String questionId) async {
    try {
      QuizzerLogger.logMessage('Entering AnswerHistoryCache addRecord()...');
      // Assert required key exists and is not empty
      assert(questionId.isNotEmpty, 'questionId added to AnswerHistoryCache cannot be empty');

      await _lock.synchronized(() {
        // Remove if already exists to ensure it moves to the front (most recent)
        final bool wasRemoved = _history.remove(questionId);
        if (wasRemoved) {
          // Signal that the question was removed from its previous position
          signalAnswerHistoryRemoved();
        }
        // Add to the front of the list
        _history.insert(0, questionId);
        // Optional: Trim the list if it grows too large, e.g.:
        // if (_history.length > 1000) { // Example limit
        //   _history.removeRange(1000, _history.length);
        // }
      });
      
      // Signal that a question has been added to history
      signalAnswerHistoryAdded();
    } catch (e) {
      QuizzerLogger.logError('Error in AnswerHistoryCache addRecord - $e');
      rethrow;
    }
  }

  // --- Check Recent History ---

  /// Checks if a question ID is present in the most recent history (up to 5 items).
  /// Asserts that the questionId is not empty.
  /// Ensures thread safety using a lock.
  Future<bool> isInRecentHistory(String questionId) async {
     try {
       QuizzerLogger.logMessage('Entering AnswerHistoryCache isInRecentHistory()...');
       // Assert questionId is not empty
       assert(questionId.isNotEmpty, 'questionId checked in AnswerHistoryCache cannot be empty');

       return await _lock.synchronized(() {
         final int historyLength = _history.length;
         // Determine the range to check (first 5 or fewer if history is shorter)
         final int checkDepth = min(5, historyLength);

         if (checkDepth == 0) {
           return false; // History is empty
         }

         // Get the sublist representing the first 'checkDepth' items (most recent)
         final List<String> recentSublist = _history.sublist(0, checkDepth);
         final bool found = recentSublist.contains(questionId);

         // Optional logging
         // if (found) {
         //     QuizzerLogger.logMessage('Checked last $checkDepth answered: $questionId IS present.');
         // } else {
         //    QuizzerLogger.logMessage('Checked last $checkDepth answered: $questionId is NOT present.');
         // }

         return found;
       });
     } catch (e) {
       QuizzerLogger.logError('Error in AnswerHistoryCache isInRecentHistory - $e');
       rethrow;
     }
  }

  // --- Clear Cache ---

  /// Clears all entries from the answer history cache.
  /// Ensures thread safety using a lock.
  Future<void> clear() async {
    try {
      QuizzerLogger.logMessage('Entering AnswerHistoryCache clear()...');
      await _lock.synchronized(() {
        if (_history.isNotEmpty) {
          // Signal that records were removed (single signal for clear operation)
          signalAnswerHistoryRemoved();
          _history.clear();
          // QuizzerLogger.logMessage('AnswerHistoryCache cleared.'); // Optional log
        }
      });
    } catch (e) {
      QuizzerLogger.logError('Error in AnswerHistoryCache clear - $e');
      rethrow;
    }
  }

  // Optional: Method to peek at the history if needed for debugging/inspection
  Future<List<String>> peekHistory() async {
    try {
      QuizzerLogger.logMessage('Entering AnswerHistoryCache peekHistory()...');
      return await _lock.synchronized(() {
        return List<String>.from(_history);
      });
    } catch (e) {
      QuizzerLogger.logError('Error in AnswerHistoryCache peekHistory - $e');
      rethrow;
    }
  }

  /// Returns the last 5 answered question IDs (most recent first).
  /// Returns fewer than 5 if history is shorter.
  /// Ensures thread safety using a lock.
  Future<List<String>> getLastFiveAnsweredQuestions() async {
    try {
      QuizzerLogger.logMessage('Entering AnswerHistoryCache getLastFiveAnsweredQuestions()...');
      return await _lock.synchronized(() {
        final int historyLength = _history.length;
        final int returnCount = min(5, historyLength);
        
        if (returnCount == 0) {
          return <String>[];
        }
        
        // Return the first 'returnCount' items (most recent first)
        return List<String>.from(_history.take(returnCount));
      });
    } catch (e) {
      QuizzerLogger.logError('Error in AnswerHistoryCache getLastFiveAnsweredQuestions - $e');
      rethrow;
    }
  }
}
