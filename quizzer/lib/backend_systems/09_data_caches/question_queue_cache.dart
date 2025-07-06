import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_cache_signals.dart'; // Import cache signals
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Import for logging
import 'unprocessed_cache.dart'; // Import for flushing
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart'; // For updateCacheLocation
import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // For user ID

// ==========================================

/// Cache holding questions selected and ready for presentation to the user.
/// Populated by the Presentation Selection Worker, consumed by the Session API/UI.
/// Implements the singleton pattern.
class QuestionQueueCache {
  // Singleton pattern setup
  static final QuestionQueueCache _instance = QuestionQueueCache._internal();
  factory QuestionQueueCache() => _instance;
  QuestionQueueCache._internal(); // Private constructor

  final Lock _lock = Lock();
  final List<Map<String, dynamic>> _cache = [];
  static const int queueThreshold = 15; // Threshold for signalling removal
  final UnprocessedCache _unprocessedCache = UnprocessedCache(); // Added

  // Make SessionManager reference lazy to avoid circular dependency
  SessionManager get _sessionManager => getSessionManager();

  // --- Add Record (with duplicate check within this cache only) ---

  /// Adds a single question record to the end of the queue, only if a record
  /// with the same question_id does not already exist in this cache.
  /// Asserts that the record contains a 'question_id'.
  /// Ensures thread safety using a lock.
  Future<bool> addRecord(Map<String, dynamic> record, {bool updateDatabaseLocation = true}) async {
    try {
      QuizzerLogger.logMessage('Entering QuestionQueueCache addRecord()...');
      // Assert required key exists
      assert(record.containsKey('question_id'), 'Record added to QuestionQueueCache must contain question_id');

      return await _lock.synchronized(() async {
        final bool wasEmpty = _cache.isEmpty;
        final String questionId = record['question_id'];
        final bool alreadyExists = _cache.any((r) => r['question_id'] == questionId);
        if (alreadyExists) return false;
        _cache.add(record);
        if (wasEmpty && _cache.isNotEmpty) {
          QuizzerLogger.logMessage("QuestionQueueCache: Added record $questionId to empty queue.");
          signalQuestionQueueAdded(); // Use unified signal
        }
        return true;
      }).then((added) async {
        // Update cache location in database after successful addition (only if requested)
        if (added && updateDatabaseLocation) {
          await _updateCacheLocationInDatabase(record['question_id'], 1);
        }
        return added;
      });
    } catch (e) {
      QuizzerLogger.logError('Error in QuestionQueueCache addRecord - $e');
      rethrow;
    }
  }

  // --- Get and Remove Record (FIFO) ---

  /// Removes and returns the first record added to the cache (FIFO).
  /// Used to get the next question for presentation.
  /// Ensures thread safety using a lock.
  /// Returns an empty Map `{}` if the cache is empty.
  Future<Map<String, dynamic>> getAndRemoveRecord() async {
     try {
       QuizzerLogger.logMessage('Entering QuestionQueueCache getAndRemoveRecord()...');
       return await _lock.synchronized(() {
         if (_cache.isNotEmpty) {
           final int lengthBeforeRemove = _cache.length;
           final record = _cache.removeAt(0);
           final int lengthAfterRemove = _cache.length;

           // Signal that a record was removed
           signalQuestionQueueRemoved();
           // Notify if length dropped below the threshold
           if (lengthBeforeRemove >= queueThreshold && lengthAfterRemove < queueThreshold) {
              QuizzerLogger.logMessage('QuestionQueueCache: Notifying record removed, length now $lengthAfterRemove.');
           }
           return record;
         } else {
           // Return an empty map if the cache is empty
           QuizzerLogger.logWarning('QuestionQueueCache: Cache is empty, no record to remove');
           return <String, dynamic>{};
         }
       });
     } catch (e) {
       QuizzerLogger.logError('Error in QuestionQueueCache getAndRemoveRecord - $e');
       rethrow;
     }
  }

  // --- Get Length ---
  /// Returns the current number of records in the queue.
  /// Ensures thread safety using a lock.
  Future<int> getLength() async {
    try {
      QuizzerLogger.logMessage('Entering QuestionQueueCache getLength()...');
      return await _lock.synchronized(() {
        return _cache.length;
      });
    } catch (e) {
      QuizzerLogger.logError('Error in QuestionQueueCache getLength - $e');
      rethrow;
    }
  }

  // --- Peek All Records (Read-Only) ---

  /// Returns a read-only copy of all records currently in the queue.
  /// Ensures thread safety using a lock.
  Future<List<Map<String, dynamic>>> peekAllRecords() async {
    try {
      QuizzerLogger.logMessage('Entering QuestionQueueCache peekAllRecords()...');
      return await _lock.synchronized(() {
        // Return a copy to prevent external modification
        return List<Map<String, dynamic>>.from(_cache);
      });
    } catch (e) {
      QuizzerLogger.logError('Error in QuestionQueueCache peekAllRecords - $e');
      rethrow;
    }
  }

  // --- Flush Cache to Unprocessed ---
  /// Removes all records from this cache and adds them to the UnprocessedCache.
  /// Ensures thread safety using locks on both caches implicitly via their methods.
  Future<void> flushToUnprocessedCache() async {
    try {
      QuizzerLogger.logMessage('Entering QuestionQueueCache flushToUnprocessedCache()...');
      List<Map<String, dynamic>> recordsToMove = []; // Initialize
      bool wasNotEmpty = false; // Track if cache had items before flush
      // Atomically get and clear records from this cache
      await _lock.synchronized(() {
        recordsToMove = List.from(_cache);
        wasNotEmpty = _cache.isNotEmpty; // Check *before* clearing
        _cache.clear();
        // If it was not empty before clearing, signal that removals happened.
        // This wakes up listeners waiting for space (like PresentationSelectionWorker).
        if (wasNotEmpty) {
           QuizzerLogger.logMessage('QuestionQueueCache: Flushed non-empty queue. Signaling removal.');
           signalQuestionQueueRemoved(); // Use unified signal
        }
      });

      // Add the retrieved records to the unprocessed cache
      if (recordsToMove.isNotEmpty) {
         QuizzerLogger.logMessage('Flushing ${recordsToMove.length} records from QuestionQueueCache to UnprocessedCache.');
         await _unprocessedCache.addRecords(recordsToMove);
      } else {
         QuizzerLogger.logMessage('QuestionQueueCache was empty, nothing to flush.');
      }
    } catch (e) {
      QuizzerLogger.logError('Error in QuestionQueueCache flushToUnprocessedCache - $e');
      rethrow;
    }
  }

  // --- Check if Contains Question ID ---
  /// Checks if a record with the specified questionId exists in the cache.
  /// Ensures thread safety using a lock.
  Future<bool> containsQuestionId(String questionId) async {
    try {
      QuizzerLogger.logMessage('Entering QuestionQueueCache containsQuestionId()...');
      return await _lock.synchronized(() {
        return _cache.any((record) => record['question_id'] == questionId);
      });
    } catch (e) {
      QuizzerLogger.logError('Error in QuestionQueueCache containsQuestionId - $e');
      rethrow;
    }
  }

  // --- Check if Empty ---
  /// Checks if the cache is currently empty.
  Future<bool> isEmpty() async {
    try {
      QuizzerLogger.logMessage('Entering QuestionQueueCache isEmpty()...');
      return await _lock.synchronized(() {
        return _cache.isEmpty;
      });
    } catch (e) {
      QuizzerLogger.logError('Error in QuestionQueueCache isEmpty - $e');
      rethrow;
    }
  }

  Future<void> clear() async {
    try {
      QuizzerLogger.logMessage('Entering QuestionQueueCache clear()...');
      await _lock.synchronized(() {
        if (_cache.isNotEmpty) {
          // Signal that records were removed (single signal for clear operation)
          signalQuestionQueueRemoved();
          _cache.clear();
          QuizzerLogger.logMessage('QuestionQueueCache cleared.');
        }
      });
    } catch (e) {
      QuizzerLogger.logError('Error in QuestionQueueCache clear - $e');
      rethrow;
    }
  }

  // --- Helper function to update cache location in database ---
  Future<void> _updateCacheLocationInDatabase(String questionId, int cacheLocation) async {
    try {
      QuizzerLogger.logMessage('Entering QuestionQueueCache _updateCacheLocationInDatabase()...');
      final userId = _sessionManager.userId;
      if (userId == null) {
        throw StateError('QuestionQueueCache: Cannot update cache location - no user ID available');
      }

      // Table function handles its own database access
      await updateCacheLocation(userId, questionId, cacheLocation);
    } catch (e) {
      QuizzerLogger.logError('Error in QuestionQueueCache _updateCacheLocationInDatabase - $e');
      rethrow;
    }
  }
}
