import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_cache_signals.dart'; // Import cache signals
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

// ==========================================
//        Temp Question Details Cache
// ==========================================
// This cache stores the full details of questions that have been selected by
// the PresentationSelectionWorker and are either in the QuestionQueueCache
// or are about to be. The SessionManager will pull from this cache
// to avoid direct DB access when a question is presented.


class TempQuestionDetailsCache {
  // --- Singleton Setup ---
  static final TempQuestionDetailsCache _instance = TempQuestionDetailsCache._internal();
  factory TempQuestionDetailsCache() => _instance;
  TempQuestionDetailsCache._internal() {
    QuizzerLogger.logMessage('TempQuestionDetailsCache initialized.');
  }
  // --------------------

  final Lock _lock = Lock();
  final Map<String, Map<String, dynamic>> _cache = {};

  /// Adds a question's details to the cache, keyed by its question_id.
  /// Overwrites existing entry if one exists for the same question_id.
  Future<void> addRecord(String questionId, Map<String, dynamic> details) async {
    try {
      QuizzerLogger.logMessage('Entering TempQuestionDetailsCache addRecord()...');
      await _lock.synchronized(() {
        QuizzerLogger.logMessage('TempQuestionDetailsCache: Adding/updating details for QID: $questionId');
        _cache[questionId] = details;
        // Signal that a record was added
        signalTempQuestionDetailsAdded();
      });
    } catch (e) {
      QuizzerLogger.logError('Error in TempQuestionDetailsCache addRecord - $e');
      rethrow;
    }
  }

  /// Retrieves a question's details from the cache by its question_id.
  /// Returns null if the question_id is not found.
  Future<Map<String, dynamic>?> getRecord(String questionId) async {
    try {
      QuizzerLogger.logMessage('Entering TempQuestionDetailsCache getRecord()...');
      return await _lock.synchronized(() {
        if (_cache.containsKey(questionId)) {
          QuizzerLogger.logMessage('TempQuestionDetailsCache: Retrieving details for QID: $questionId');
          return _cache[questionId];
        } else {
          QuizzerLogger.logWarning('TempQuestionDetailsCache: No details found for QID: $questionId');
          return null;
        }
      });
    } catch (e) {
      QuizzerLogger.logError('Error in TempQuestionDetailsCache getRecord - $e');
      rethrow;
    }
  }

  /// Retrieves and removes a question's details from the cache.
  /// Returns null if the question_id is not found.
  Future<Map<String, dynamic>?> getAndRemoveRecord(String questionId) async {
    try {
      QuizzerLogger.logMessage('Entering TempQuestionDetailsCache getAndRemoveRecord()...');
      return await _lock.synchronized(() {
        if (_cache.containsKey(questionId)) {
          QuizzerLogger.logMessage('TempQuestionDetailsCache: Getting and removing details for QID: $questionId');
          final removedDetails = _cache.remove(questionId);
          // Signal that a record was removed
          signalTempQuestionDetailsRemoved();
          return removedDetails;
        } else {
          QuizzerLogger.logWarning('TempQuestionDetailsCache: No details to get and remove for QID: $questionId');
          return null;
        }
      });
    } catch (e) {
      QuizzerLogger.logError('Error in TempQuestionDetailsCache getAndRemoveRecord - $e');
      rethrow;
    }
  }

  /// Removes a question's details from the cache by its question_id.
  Future<void> removeRecord(String questionId) async {
    try {
      QuizzerLogger.logMessage('Entering TempQuestionDetailsCache removeRecord()...');
      await _lock.synchronized(() {
        if (_cache.containsKey(questionId)) {
          QuizzerLogger.logMessage('TempQuestionDetailsCache: Removing details for QID: $questionId');
          _cache.remove(questionId);
          // Signal that a record was removed
          signalTempQuestionDetailsRemoved();
        } else {
          QuizzerLogger.logWarning('TempQuestionDetailsCache: No details to remove for QID: $questionId');
        }
      });
    } catch (e) {
      QuizzerLogger.logError('Error in TempQuestionDetailsCache removeRecord - $e');
      rethrow;
    }
  }

  /// Checks if the cache contains details for a given question_id.
  Future<bool> containsRecord(String questionId) async {
    try {
      QuizzerLogger.logMessage('Entering TempQuestionDetailsCache containsRecord()...');
      return await _lock.synchronized(() {
        return _cache.containsKey(questionId);
      });
    } catch (e) {
      QuizzerLogger.logError('Error in TempQuestionDetailsCache containsRecord - $e');
      rethrow;
    }
  }

  /// Clears all records from the cache.
  Future<void> clear() async {
    try {
      QuizzerLogger.logMessage('Entering TempQuestionDetailsCache clear()...');
      await _lock.synchronized(() {
        QuizzerLogger.logMessage('TempQuestionDetailsCache: Clearing all records.');
        if (_cache.isNotEmpty) {
          // Signal that records were removed (single signal for clear operation)
          signalTempQuestionDetailsRemoved();
        }
        _cache.clear();
      });
    } catch (e) {
      QuizzerLogger.logError('Error in TempQuestionDetailsCache clear - $e');
      rethrow;
    }
  }
}