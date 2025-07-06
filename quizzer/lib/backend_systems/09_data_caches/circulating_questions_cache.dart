import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_cache_signals.dart'; // Import cache signals
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
    try {
      QuizzerLogger.logMessage('Entering CirculatingQuestionsCache addQuestionId()...');
      // Basic validation: Ensure ID is not empty
      if (questionId.isEmpty) {
         QuizzerLogger.logWarning('Attempted to add empty question ID to CirculatingQuestionsCache');
         return;
      }
      await _lock.synchronized(() {
        // Re-added check: Add only if not already present to avoid duplicates
        if (!_questionIds.contains(questionId)) {
          _questionIds.add(questionId);
          // Signal that a question was added
          signalCirculatingQuestionsAdded();
          // QuizzerLogger.logValue('CirculatingCache: Added $questionId');
        } else {
          // QuizzerLogger.logMessage('CirculatingCache: Duplicate ID skipped: $questionId');
        }
      });
    } catch (e) {
      QuizzerLogger.logError('Error in CirculatingQuestionsCache addQuestionId - $e');
      rethrow;
    }
  }

  // --- Peek All Question IDs (Read-Only) ---

  /// Returns a read-only copy of all question IDs currently in the cache.
  /// Ensures thread safety using a lock.
  Future<List<String>> peekAllQuestionIds() async {
    try {
      QuizzerLogger.logMessage('Entering CirculatingQuestionsCache peekAllQuestionIds()...');
      return await _lock.synchronized(() {
        // Return a copy to prevent external modification
        return List<String>.from(_questionIds);
      });
    } catch (e) {
      QuizzerLogger.logError('Error in CirculatingQuestionsCache peekAllQuestionIds - $e');
      rethrow;
    }
  }

  // --- Clear Cache ---

  /// Clears all question IDs from the cache.
  /// Ensures thread safety using a lock.
  Future<void> clear() async {
    try {
      QuizzerLogger.logMessage('Entering CirculatingQuestionsCache clear()...');
      await _lock.synchronized(() {
        if (_questionIds.isNotEmpty) {
          // Signal that records were removed (single signal for clear operation)
          signalCirculatingQuestionsRemoved();
          _questionIds.clear();
          // QuizzerLogger.logMessage('CirculatingQuestionsCache cleared.'); // Optional log
        }
      });
    } catch (e) {
      QuizzerLogger.logError('Error in CirculatingQuestionsCache clear - $e');
      rethrow;
    }
  }
}
