import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Assuming logger might be needed
import 'unprocessed_cache.dart'; // Import for flushing

// ==========================================

/// Cache for user question records associated with modules that are currently inactive.
/// Implements the singleton pattern.
class ModuleInactiveCache {
  // Singleton pattern setup
  static final ModuleInactiveCache _instance = ModuleInactiveCache._internal();
  factory ModuleInactiveCache() => _instance;
  ModuleInactiveCache._internal(); // Private constructor

  final Lock _lock = Lock();
  List<Map<String, dynamic>> _cache = [];
  final UnprocessedCache _unprocessedCache = UnprocessedCache(); // Get singleton instance

  // --- Add Record (with duplicate check) ---

  /// Adds a single module-inactive question record to the cache, only if a record
  /// with the same question_id does not already exist.
  /// Ensures thread safety using a lock.
  Future<void> addRecord(Map<String, dynamic> record) async {
    // Basic validation: Ensure record has required key
    if (!record.containsKey('question_id')) {
      QuizzerLogger.logWarning('Attempted to add invalid record (missing question_id) to ModuleInactiveCache');
      return; // Or throw ArgumentError
    }
    final String questionId = record['question_id'] as String; // Assume key exists

    await _lock.synchronized(() {
      // Check if record with the same question_id already exists
      final bool alreadyExists = _cache.any((existing) => existing['question_id'] == questionId);

      if (!alreadyExists) {
        _cache.add(record);
        // QuizzerLogger.logMessage('ModuleInactiveCache: Added $questionId.'); // Optional Log
      } else {
         QuizzerLogger.logMessage('ModuleInactiveCache: Duplicate record skipped (QID: $questionId)'); // Optional Log
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

  // --- Flush Cache to Unprocessed ---

  /// Removes all records from this cache and adds them to the UnprocessedCache.
  /// Ensures thread safety using locks on both caches implicitly via their methods.
  Future<void> flushToUnprocessedCache() async {
    List<Map<String, dynamic>> recordsToMove = []; // Initialize to empty list
    // Atomically get and clear records from this cache
    await _lock.synchronized(() {
      recordsToMove = List.from(_cache);
      _cache.clear();
    });

    // Add the retrieved records to the unprocessed cache
    if (recordsToMove.isNotEmpty) {
       QuizzerLogger.logMessage('Flushing ${recordsToMove.length} records from ModuleInactiveCache to UnprocessedCache.');
       await _unprocessedCache.addRecords(recordsToMove);
    } else {
       QuizzerLogger.logMessage('ModuleInactiveCache is empty, nothing to flush.');
    }
  }
}
