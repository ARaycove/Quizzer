import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Uncomment if logging needed
import 'unprocessed_cache.dart'; // Import UnprocessedCache
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
  List<Map<String, dynamic>> _cache = [];
  final UnprocessedCache _unprocessedCache = UnprocessedCache(); // Get singleton instance

  // --- Notification Stream ---
  final StreamController<void> _addController = StreamController<void>.broadcast();
  Stream<void> get onRecordAdded => _addController.stream;
  // -------------------------

  // --- Add Record ---

  /// Adds a single eligible question record to the cache.
  /// Ensures thread safety using a lock.
  Future<void> addRecord(Map<String, dynamic> record) async {
    // Assert required key exists
    assert(record.containsKey('question_id'), 'Record added to EligibleQuestionsCache must contain question_id');

    await _lock.synchronized(() {
      final bool wasEmpty = _cache.isEmpty;
      _cache.add(record);
       if (wasEmpty && _cache.isNotEmpty) {
        // QuizzerLogger.logMessage('EligibleQuestionsCache: Notifying record added.'); // Optional log
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
         return _cache.removeAt(foundIndex);
       } else {
         // Return an empty map if no record was found
         return <String, dynamic>{};
       }
     });
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

  // --- Dispose Stream Controller ---
  void dispose() {
    _addController.close();
  }
}
