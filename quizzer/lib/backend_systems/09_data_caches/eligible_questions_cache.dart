import 'dart:async';
import 'package:synchronized/synchronized.dart';
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

  // --- Add Record ---

  /// Adds a single eligible question record to the cache.
  /// Ensures thread safety using a lock.
  Future<void> addRecord(Map<String, dynamic> record) async {
    // Assert required key exists
    assert(record.containsKey('question_id'), 'Record added to EligibleQuestionsCache must contain question_id');

    await _lock.synchronized(() {
       // Optional: Check if record with same question_id already exists?
      _cache.add(record);
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
}
