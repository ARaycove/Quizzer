import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Optional: if logging needed

// ==========================================

/// Cache storing only the IDs of questions currently in circulation.
/// Optimized for quick lookup by the Circulation Worker.
/// Implements the singleton pattern.
class CirculatingQuestionsCache {
  // Singleton pattern setup
  static final CirculatingQuestionsCache _instance = CirculatingQuestionsCache._internal();
  factory CirculatingQuestionsCache() => _instance;
  CirculatingQuestionsCache._internal(); // Private constructor

  final Lock _lock = Lock();
  final List<String> _questionIds = []; // Store only IDs

  // --- Add Question ID ---

  /// Adds a single question ID to the cache if it's not already present.
  /// Ensures thread safety using a lock.
  Future<void> addQuestionId(String questionId) async {
    // Basic validation: Ensure ID is not empty
    if (questionId.isEmpty) {
       QuizzerLogger.logWarning('Attempted to add empty question ID to CirculatingQuestionsCache');
       return;
    }
    await _lock.synchronized(() {
      // Re-added check: Add only if not already present to avoid duplicates
      if (!_questionIds.contains(questionId)) {
        _questionIds.add(questionId);
        // QuizzerLogger.logValue('CirculatingCache: Added $questionId');
      } else {
        // QuizzerLogger.logMessage('CirculatingCache: Duplicate ID skipped: $questionId');
      }
    });
  }

  // --- Peek All Question IDs (Read-Only) ---

  /// Returns a read-only copy of all question IDs currently in the cache.
  /// Ensures thread safety using a lock.
  Future<List<String>> peekAllQuestionIds() async {
    return await _lock.synchronized(() {
      // Return a copy to prevent external modification
      return List<String>.from(_questionIds);
    });
  }
}
