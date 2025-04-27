import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Import for logging
import 'unprocessed_cache.dart'; // Import for flushing
// import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Optional: if logging needed

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
  static const int queueThreshold = 10; // Threshold for signalling removal
  final UnprocessedCache _unprocessedCache = UnprocessedCache(); // Added

  // --- Notification Stream (for removal) ---
  final StreamController<void> _removeController = StreamController<void>.broadcast();
  /// A stream that emits an event when a record is removed, potentially making space.
  Stream<void> get onRecordRemoved => _removeController.stream;
  // -----------------------------------------

  // --- Add Record (with duplicate check within this cache only) ---

  /// Adds a single question record to the end of the queue, only if a record
  /// with the same question_id does not already exist in this cache.
  /// Asserts that the record contains a 'question_id'.
  /// Ensures thread safety using a lock.
  Future<void> addRecord(Map<String, dynamic> record) async {
    // Assert required key exists
    assert(record.containsKey('question_id'), 'Record added to QuestionQueueCache must contain question_id');
    final String questionId = record['question_id'] as String; // Assume assertion passes

    await _lock.synchronized(() { // Lambda is no longer async
      // Check only if it already exists in this QuestionQueueCache
      final bool alreadyExists = _cache.any((existing) => existing['question_id'] == questionId);
      if (!alreadyExists) {
        _cache.add(record);
        // QuizzerLogger.logMessage('QuestionQueueCache: Added $questionId.'); // Optional Log
      } else {
         QuizzerLogger.logMessage('QuestionQueueCache: Duplicate record skipped (QID: $questionId already in queue).'); // Optional Log
      }
    });
  }

  // --- Get and Remove Record (FIFO) ---

  /// Removes and returns the first record added to the cache (FIFO).
  /// Used to get the next question for presentation.
  /// Ensures thread safety using a lock.
  /// Returns an empty Map `{}` if the cache is empty.
  Future<Map<String, dynamic>> getAndRemoveRecord() async {
     return await _lock.synchronized(() {
       if (_cache.isNotEmpty) {
         final int lengthBeforeRemove = _cache.length;
         final record = _cache.removeAt(0);
         final int lengthAfterRemove = _cache.length;

         // Notify if length dropped below the threshold
         if (lengthBeforeRemove >= queueThreshold && lengthAfterRemove < queueThreshold) {
            // QuizzerLogger.logMessage('QuestionQueueCache: Notifying record removed, length now $lengthAfterRemove.');
            _removeController.add(null);
         }
         return record;
       } else {
         // Return an empty map if the cache is empty
         return <String, dynamic>{};
       }
     });
  }

  // --- Get Length ---
  /// Returns the current number of records in the queue.
  /// Ensures thread safety using a lock.
  Future<int> getLength() async {
    return await _lock.synchronized(() {
      return _cache.length;
    });
  }

  // --- Peek All Records (Read-Only) ---

  /// Returns a read-only copy of all records currently in the queue.
  /// Ensures thread safety using a lock.
  Future<List<Map<String, dynamic>>> peekAllRecords() async {
    return await _lock.synchronized(() {
      // Return a copy to prevent external modification
      return List<Map<String, dynamic>>.from(_cache);
    });
  }

  // --- Flush Cache to Unprocessed ---
  /// Removes all records from this cache and adds them to the UnprocessedCache.
  /// Ensures thread safety using locks on both caches implicitly via their methods.
  /// Sends a signal on [onRecordRemoved] if the cache was not empty before clearing.
  Future<void> flushToUnprocessedCache() async {
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
         _removeController.add(null);
      }
    });

    // Add the retrieved records to the unprocessed cache
    if (recordsToMove.isNotEmpty) {
       QuizzerLogger.logMessage('Flushing ${recordsToMove.length} records from QuestionQueueCache to UnprocessedCache.');
       await _unprocessedCache.addRecords(recordsToMove);
    } else {
       // QuizzerLogger.logMessage('QuestionQueueCache was empty, nothing to flush.'); // Optional log
    }
  }

  // --- Check if Contains Question ID ---
  /// Checks if a record with the specified questionId exists in the cache.
  /// Ensures thread safety using a lock.
  Future<bool> containsQuestionId(String questionId) async {
    return await _lock.synchronized(() {
      return _cache.any((record) => record['question_id'] == questionId);
    });
  }

  // --- Dispose Stream Controller ---
  void dispose() {
    _removeController.close();
  }
}
