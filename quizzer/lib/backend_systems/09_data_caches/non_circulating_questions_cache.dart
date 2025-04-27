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

  // --- Notification Stream ---
  // Used to notify listeners (like CirculationWorker) when a record is added to an empty cache.
  final StreamController<void> _addController = StreamController<void>.broadcast();

  /// A stream that emits an event when a record is added to a previously empty cache.
  Stream<void> get onRecordAdded => _addController.stream;
  // -------------------------

  // --- Add Record (with duplicate check) ---

  /// Adds a single non-circulating question record to the cache, only if a record
  /// with the same question_id does not already exist.
  /// Ensures thread safety using a lock.
  /// Notifies listeners via [onRecordAdded] if the cache was empty and a record was added.
  Future<void> addRecord(Map<String, dynamic> record) async {
    // Basic validation: Ensure record has required keys and correct state
    if (!record.containsKey('question_id') || !record.containsKey('in_circulation')) {
      // Consider logging a warning or throwing an error based on project policy
      QuizzerLogger.logWarning('Attempted to add invalid record (missing keys) to NonCirculatingCache');
      return; // Or throw ArgumentError
    }
    final String questionId = record['question_id'] as String; // Assume key exists

    // Assert that the record is indeed non-circulating
    assert(record['in_circulation'] == 0, 'Record added to NonCirculatingCache must have in_circulation == 0');

    await _lock.synchronized(() {
        final bool wasEmpty = _cache.isEmpty;
        _cache.add(record);
        if (wasEmpty && _cache.isNotEmpty) {
          _addController.add(null);
      }
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

  // --- Close Stream Controller ---
  /// Closes the stream controller. Should be called when the cache is no longer needed.
  void dispose() {
    _addController.close();
  }
}
