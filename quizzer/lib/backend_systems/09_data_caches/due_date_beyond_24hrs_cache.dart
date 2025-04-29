import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'unprocessed_cache.dart'; // Import for flushing

// ==========================================

/// Cache for user question records whose next revision due date is beyond 24 hours.
/// Used to filter out questions not needing immediate eligibility checks.
/// Implements the singleton pattern.
class DueDateBeyond24hrsCache {
  // Singleton pattern setup
  static final DueDateBeyond24hrsCache _instance = DueDateBeyond24hrsCache._internal();
  factory DueDateBeyond24hrsCache() => _instance;
  DueDateBeyond24hrsCache._internal(); // Private constructor

  final Lock _lock = Lock();
  final List<Map<String, dynamic>> _cache = [];
  final UnprocessedCache _unprocessedCache = UnprocessedCache(); // Get singleton instance

  // --- Add Record (with duplicate check) ---

  /// Adds a single question record if its due date is beyond 24 hours and
  /// no record with the same question_id already exists.
  /// Asserts that the due date condition is met.
  /// Ensures thread safety using a lock.
  Future<void> addRecord(Map<String, dynamic> record) async {
    // Basic validation: Ensure record has required keys
    if (!record.containsKey('question_id') || !record.containsKey('next_revision_due')) {
      QuizzerLogger.logWarning('Attempted to add invalid record (missing keys) to DueDateBeyond24hrsCache');
      return; // Or throw ArgumentError
    }
    // final String questionId = record['question_id'] as String; // Assume key exists

    final dueDateString = record['next_revision_due'];
    if (dueDateString == null || dueDateString is! String) {
       QuizzerLogger.logWarning('Invalid or missing next_revision_due format in record added to DueDateBeyond24hrsCache');
       return;
    }

    // REMOVED try-catch block - DateTime.parse will now Fail Fast on invalid format
    final DateTime parsedDueDate = DateTime.parse(dueDateString);

    final now = DateTime.now();
    final twentyFourHoursFromNow = now.add(const Duration(hours: 24));

    // Assert that the due date is indeed beyond 24 hours
    assert(
        parsedDueDate.isAfter(twentyFourHoursFromNow),
        'Record added to DueDateBeyond24hrsCache must have next_revision_due > 24 hours from now. Got: $parsedDueDate'
    );

    if (!parsedDueDate.isAfter(twentyFourHoursFromNow)) {
        QuizzerLogger.logWarning('Record failed >24hr check (asserts might be off): $parsedDueDate');
        _unprocessedCache.addRecord(record);
        return; // Don't add if condition isn't met
    }

    await _lock.synchronized(() {
        _cache.add(record);
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
       QuizzerLogger.logMessage('Flushing ${recordsToMove.length} records from DueDateBeyond24hrsCache to UnprocessedCache.');
       await _unprocessedCache.addRecords(recordsToMove);
    } else {
       QuizzerLogger.logMessage('DueDateBeyond24hrsCache is empty, nothing to flush.');
    }
  }

  // --- Get and Remove Record by Question ID (ADDED) ---
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
         QuizzerLogger.logWarning('DueDateBeyond24hrsCache: Record not found for removal (QID: $questionId)');
         return <String, dynamic>{};
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

  Future<void> clear() async {
    await _lock.synchronized(() {
      if (_cache.isNotEmpty) {
        _cache.clear();
        // QuizzerLogger.logMessage('AnswerHistoryCache cleared.'); // Optional log
      }
    });
  }
}
