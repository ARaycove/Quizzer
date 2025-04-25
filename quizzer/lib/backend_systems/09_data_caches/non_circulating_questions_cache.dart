import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

// ==========================================

/// Cache for user question records that are currently not in circulation.
/// Implements the singleton pattern.
class NonCirculatingQuestionsCache {
  // Singleton pattern setup
  static final NonCirculatingQuestionsCache _instance = NonCirculatingQuestionsCache._internal();
  factory NonCirculatingQuestionsCache() => _instance;
  NonCirculatingQuestionsCache._internal(); // Private constructor

  final Lock _lock = Lock();
  List<Map<String, dynamic>> _cache = [];

  // --- Add Record ---

  /// Adds a single non-circulating question record to the cache.
  /// Ensures thread safety using a lock.
  Future<void> addRecord(Map<String, dynamic> record) async {
    // Basic validation: Ensure record has required keys and correct state
    if (!record.containsKey('question_id') || !record.containsKey('in_circulation')) {
      // Consider logging a warning or throwing an error based on project policy
      QuizzerLogger.logWarning('Attempted to add invalid record (missing keys) to NonCirculatingCache');
      return; // Or throw ArgumentError
    }
    // Assert that the record is indeed non-circulating
    assert(record['in_circulation'] == 0, 'Record added to NonCirculatingCache must have in_circulation == 0');

    await _lock.synchronized(() {
      _cache.add(record);
    });
  }
  // --- Peek All Records (Read-Only) ---
  /// Returns a read-only copy of all records currently in the cache.
  /// Ensures thread safety using a lock.
  Future<List<Map<String, dynamic>>> peekAllRecords() async {
    return await _lock.synchronized(() {
      // Return a copy to prevent external modification
      return List<Map<String, dynamic>>.from(_cache);
    });
  }

  // --- Get and Remove Record by Question ID ---
  /// Retrieves and removes the first record matching the given questionId.
  /// Assumes questionId is sufficiently unique for the caller's context.
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
}
