import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Uncomment if logging needed
import 'unprocessed_cache.dart'; // Import UnprocessedCache
import 'past_due_cache.dart'; // ADDED: Import new target cache
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart'; // Import SwitchBoard
// import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Optional: if logging needed

// ==========================================

/// Cache for user question records deemed eligible for presentation.
/// Populated by the Eligibility Worker and read by other workers.
/// Implements the singleton pattern.
class EligibleQuestionsCache {
  // Singleton pattern setup
  static final EligibleQuestionsCache _instance = EligibleQuestionsCache._internal();
  factory EligibleQuestionsCache() => _instance;
  EligibleQuestionsCache._internal(); // Private constructor

  final Lock _lock = Lock();
  final List<Map<String, dynamic>> _cache = [];
  final UnprocessedCache _unprocessedCache = UnprocessedCache(); // Get singleton instance

  // --- Notification Stream ---
  final StreamController<void> _addController = StreamController<void>.broadcast();
  Stream<void> get onRecordAdded => _addController.stream;
  // -------------------------

  // --- Add Record (with duplicate check) ---

  /// Adds a single eligible question record to the cache, only if a record
  /// with the same question_id does not already exist.
  /// Ensures thread safety using a lock.
  Future<void> addRecord(Map<String, dynamic> record) async {
    // Assert required key exists
    assert(record.containsKey('question_id'), 'Record added to EligibleQuestionsCache must contain question_id');
    // final String questionId = record['question_id'] as String; // Assume assertion passes

    await _lock.synchronized(() {
        final bool wasEmpty = _cache.isEmpty;
        _cache.add(record);
        if (wasEmpty && _cache.isNotEmpty) {
          _addController.add(null);
      }
    });
  }

  // --- Get and Remove Record by Question ID ---

  /// Retrieves and removes the first record matching the given questionId.
  /// Ensures thread safety using a lock.
  /// Returns the found record, or an empty Map `{}` if no matching record is found.
  Future<Map<String, dynamic>> getAndRemoveRecordByQuestionId(String questionId) async {
     return await _lock.synchronized(() {
       int foundIndex = -1;
       for (int i = 0; i < _cache.length; i++) {
         final record = _cache[i];
         // Check key exists and matches
         if (record.containsKey('question_id') && record['question_id'] == questionId) {
           foundIndex = i;
           break;
         }
       }

       if (foundIndex != -1) {
         // Remove the record at the found index and return it
         final removedRecord = _cache.removeAt(foundIndex);
         
         // Check counts and signal AFTER removal but before releasing lock
         _checkAndSignalCacheStatus(); // Call helper within synchronized block
         
         return removedRecord;
       } else {
         // Return an empty map if no record was found
         return <String, dynamic>{};
       }
     });
  }

  // --- ADDED: Private helper to check and signal within the lock ---
  void _checkAndSignalCacheStatus() {
      // No need to await getCount/getLowRevisionCount here as we are already inside the lock
      final int totalEligibleCount = _cache.length;
      int lowRevisionCount = 0;
      const int threshold = 3; // Same threshold as getLowRevisionCount method
      for (final record in _cache) {
          if (record.containsKey('revision_streak') && 
              record['revision_streak'] is int && 
              (record['revision_streak'] as int) <= threshold) {
            lowRevisionCount++;
          }
      }
      
      // Signal if EITHER condition is met
      if (totalEligibleCount < 100 || lowRevisionCount < 20) { 
          getSwitchBoard().signalEligibleCacheLow(); // Use getter to access singleton
      }
  }

  // --- Peek All Records (Read-Only) ---

  /// Returns a read-only copy of all eligible question records currently in the cache.
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
  Future<void> flushToUnprocessedCache() async {
    List<Map<String, dynamic>> recordsToMove = []; // Initialize
    // Atomically get and clear records from this cache
    await _lock.synchronized(() {
      recordsToMove = List.from(_cache);
      _cache.clear();
    });

    // Add the retrieved records to the unprocessed cache
    if (recordsToMove.isNotEmpty) {
       QuizzerLogger.logMessage('Flushing ${recordsToMove.length} records from EligibleQuestionsCache to UnprocessedCache.');
       await _unprocessedCache.addRecords(recordsToMove);
    } else {
       // QuizzerLogger.logMessage('EligibleQuestionsCache is empty, nothing to flush.'); // Optional log
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

  // --- Check if Empty ---
  /// Checks if the cache is currently empty.
  Future<bool> isEmpty() async {
    return await _lock.synchronized(() {
      return _cache.isEmpty;
    });
  }

  // --- Get Length ---
  /// Returns the current number of records in the cache.
  Future<int> getLength() async {
     return await _lock.synchronized(() {
         return _cache.length;
     });
  }

  // --- Get Count ---
  /// Returns the current number of records in the cache.
  Future<int> getCount() async {
    return await _lock.synchronized(() {
      return _cache.length;
    });
  }

  // --- Get Low Revision Count ---
  /// Returns the count of records with a revision_streak <= 3.
  Future<int> getLowRevisionCount({int threshold = 3}) async {
    return await _lock.synchronized(() {
      int count = 0;
      for (final record in _cache) {
        // Check if the key exists and the value is an int before comparing
        if (record.containsKey('revision_streak') && 
            record['revision_streak'] is int && 
            (record['revision_streak'] as int) <= threshold) {
          count++;
        }
      }
      return count;
    });
  }

  // --- Flush Cache to PastDueCache --- (RENAMED)
  /// Removes all records from this cache and adds them to the PastDueCache.
  /// Intended to be called upon events like module deactivation to force re-evaluation.
  /// Ensures thread safety using locks on both caches implicitly via their methods.
  Future<void> flushToPastDueCache() async { // RENAMED
    List<Map<String, dynamic>> recordsToMove = []; // Initialize
    bool wasNotEmpty = false; // Track if cache had items before flush
    final PastDueCache pastDueCache = PastDueCache(); // CHANGED: Get instance of new target cache

    // Atomically get and clear records from this cache
    await _lock.synchronized(() {
      recordsToMove = List.from(_cache);
      wasNotEmpty = _cache.isNotEmpty; // Check *before* clearing
      _cache.clear();
      // If it was not empty before clearing, signal that removals happened.
      // This might wake up listeners waiting for eligible records (like PSW),
      // which is okay as they will just find the cache empty again.
      if (wasNotEmpty) {
         QuizzerLogger.logMessage('EligibleQuestionsCache: Flushed non-empty cache. Signaling removal.');
         _addController.add(null); // Signal using the existing add/remove stream
      }
    });

    // Add the retrieved records to the target cache
    if (recordsToMove.isNotEmpty) {
       QuizzerLogger.logMessage('Flushing ${recordsToMove.length} records from EligibleQuestionsCache to PastDueCache.'); // CHANGED log message
       // Add records one by one to the target cache to ensure its logic (like signaling) runs correctly
       for (final record in recordsToMove) {
          await pastDueCache.addRecord(record); // CHANGED: Call addRecord on pastDueCache
       }
    } else {
       QuizzerLogger.logWarning('EligibleQuestionsCache was empty, nothing to flush.'); // Optional log
    }
  }
  
  Future<void> clear() async {
    await _lock.synchronized(() {
      if (_cache.isNotEmpty) {
        _cache.clear();
        // QuizzerLogger.logMessage('AnswerHistoryCache cleared.'); // Optional log
      }
    });
  }

  // --- Dispose Stream Controller ---
  void dispose() {
    _addController.close();
  }
}
