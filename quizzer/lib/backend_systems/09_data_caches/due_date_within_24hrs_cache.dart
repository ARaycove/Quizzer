import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'unprocessed_cache.dart'; // Import for flushing

// ==========================================

/// Cache for user question records whose next revision due date is within 24 hours (or past due).
/// Checked by the Eligibility Worker.
/// Implements the singleton pattern.
class DueDateWithin24hrsCache {
  // Singleton pattern setup
  static final DueDateWithin24hrsCache _instance = DueDateWithin24hrsCache._internal();
  factory DueDateWithin24hrsCache() => _instance;
  DueDateWithin24hrsCache._internal(); // Private constructor

  final Lock _lock = Lock();
  List<Map<String, dynamic>> _cache = [];
  final UnprocessedCache _unprocessedCache = UnprocessedCache(); // Get singleton instance

  // --- Add Record ---

  /// Adds a single question record if its due date is within 24 hours.
  /// Asserts that the due date condition is met.
  /// Ensures thread safety using a lock.
  Future<void> addRecord(Map<String, dynamic> record) async {
    // Basic validation: Ensure record has required keys
    if (!record.containsKey('question_id') || !record.containsKey('next_revision_due')) {
      QuizzerLogger.logWarning('Attempted to add invalid record (missing keys) to DueDateWithin24hrsCache');
      return; // Or throw ArgumentError
    }

    final dueDateString = record['next_revision_due'];
    if (dueDateString == null || dueDateString is! String) {
       QuizzerLogger.logWarning('Invalid or missing next_revision_due format in record added to DueDateWithin24hrsCache');
       return;
    }

    // Parse the date string. This will throw FormatException if invalid.
    final DateTime parsedDueDate = DateTime.parse(dueDateString);

    final now = DateTime.now();
    final twentyFourHoursFromNow = now.add(const Duration(hours: 24));

    // Assert that the due date is within 24 hours (not after 24 hours from now)
    assert(
        !parsedDueDate.isAfter(twentyFourHoursFromNow),
        'Record added to DueDateWithin24hrsCache must have next_revision_due <= 24 hours from now. Got: $parsedDueDate'
    );

    // Check again just in case asserts are disabled in production
    if (parsedDueDate.isAfter(twentyFourHoursFromNow)) {
        QuizzerLogger.logWarning('Record failed <=24hr check (asserts might be off): $parsedDueDate');
        return; // Don't add if condition isn't met
    }

    await _lock.synchronized(() {
      // Optional: Check if record already exists by question_id before adding?
      _cache.add(record);
    });
  }

  // --- Get and Remove Record (LIFO) ---

  /// Removes and returns the last record added to the cache (LIFO).
  /// Used by the Eligibility Worker to get the next available record.
  /// Ensures thread safety using a lock.
  /// Returns an empty Map `{}` if the cache is empty.
  Future<Map<String, dynamic>> getAndRemoveRecord() async {
     return await _lock.synchronized(() {
       if (_cache.isNotEmpty) {
         return _cache.removeLast(); // Efficiently removes and returns the last element
       } else {
         // Return an empty map if the cache is empty
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
       QuizzerLogger.logMessage('Flushing ${recordsToMove.length} records from DueDateWithin24hrsCache to UnprocessedCache.');
       await _unprocessedCache.addRecords(recordsToMove);
    } else {
       QuizzerLogger.logMessage('DueDateWithin24hrsCache is empty, nothing to flush.');
    }
  }
}
