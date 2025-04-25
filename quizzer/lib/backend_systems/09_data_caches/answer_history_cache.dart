import 'dart:async';
import 'dart:math'; // For min function
import 'package:synchronized/synchronized.dart';
// import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Optional: if logging needed

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
  Future<void> addRecord(String questionId) async {
    // Assert required key exists and is not empty
    assert(questionId.isNotEmpty, 'questionId added to AnswerHistoryCache cannot be empty');

    await _lock.synchronized(() {
      // Remove if already exists to ensure it moves to the front (most recent)
      _history.remove(questionId);
      // Add to the front of the list
      _history.insert(0, questionId);
      // Optional: Trim the list if it grows too large, e.g.:
      // if (_history.length > 1000) { // Example limit
      //   _history.removeRange(1000, _history.length);
      // }
    });
  }

  // --- Check Recent History ---

  /// Checks if a question ID is present in the most recent history (up to 5 items).
  /// Asserts that the questionId is not empty.
  /// Ensures thread safety using a lock.
  Future<bool> isInRecentHistory(String questionId) async {
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
  }

  // Optional: Method to peek at the history if needed for debugging/inspection
  Future<List<String>> peekHistory() async {
    return await _lock.synchronized(() {
      return List<String>.from(_history);
    });
  }
}
