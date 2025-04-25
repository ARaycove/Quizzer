import 'dart:async';
import 'package:synchronized/synchronized.dart';
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

  // --- Add Record ---

  /// Adds a single question record to the end of the queue.
  /// Asserts that the record contains a 'question_id'.
  /// Ensures thread safety using a lock.
  Future<void> addRecord(Map<String, dynamic> record) async {
    // Assert required key exists
    assert(record.containsKey('question_id'), 'Record added to QuestionQueueCache must contain question_id');

    await _lock.synchronized(() {
      _cache.add(record);
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
         return _cache.removeAt(0); // Efficiently removes and returns the first element
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
}
