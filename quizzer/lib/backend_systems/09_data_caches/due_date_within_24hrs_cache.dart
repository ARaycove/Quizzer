import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_cache_signals.dart'; // Import cache signals
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/09_data_caches/unprocessed_cache.dart'; // Import for flushing
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart'; // For updateCacheLocation
import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // For user ID

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
  final List<Map<String, dynamic>> _cache = [];
  final UnprocessedCache _unprocessedCache = UnprocessedCache(); // Get singleton instance

  // Make SessionManager reference lazy to avoid circular dependency
  SessionManager get _sessionManager => getSessionManager();

  // --- Add Record (with duplicate check) ---

  /// Adds a single question record if its due date is within 24 hours and
  /// no record with the same question_id already exists.
  /// Asserts that the due date condition is met.
  /// Ensures thread safety using a lock.
  /// Notifies listeners via [SwitchBoard] if the cache was empty and a record was added.
  Future<void> addRecord(Map<String, dynamic> record, {bool updateDatabaseLocation = true}) async {
    try {
      QuizzerLogger.logMessage('Entering DueDateWithin24hrsCache addRecord()...');
      // Basic validation: Ensure record has required keys
      if (!record.containsKey('question_id') || !record.containsKey('next_revision_due')) {
        QuizzerLogger.logWarning('Attempted to add invalid record (missing keys) to DueDateWithin24hrsCache');
        throw ArgumentError("processed question record is invalid, internal issue needs to be addressed");
      }
      // final String questionId = record['question_id'] as String; // Assume key exists

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
        final bool wasEmpty = _cache.isEmpty;
        _cache.add(record);
        if (wasEmpty && _cache.isNotEmpty) {
          // QuizzerLogger.logMessage('DueDateWithin24hrsCache: Signaling SwitchBoard.'); // Optional log
          signalDueDateWithin24hrsAdded(); // Use unified signal
        }
      });

      // Update cache location in database after successful addition (only if requested)
      if (updateDatabaseLocation) {
        await _updateCacheLocationInDatabase(record['question_id'], 6);
      }
    } catch (e) {
      QuizzerLogger.logError('Error in DueDateWithin24hrsCache addRecord - $e');
      rethrow;
    }
  }

  // --- Get and Remove Record (LIFO) ---

  /// Removes and returns the last record added to the cache (LIFO).
  /// Used by the Eligibility Worker to get the next available record.
  /// Ensures thread safety using a lock.
  /// Returns an empty Map `{}` if the cache is empty.
  Future<Map<String, dynamic>> getAndRemoveRecord() async {
     try {
       QuizzerLogger.logMessage('Entering DueDateWithin24hrsCache getAndRemoveRecord()...');
       return await _lock.synchronized(() {
         if (_cache.isNotEmpty) {
           final removedRecord = _cache.removeLast(); // Efficiently removes and returns the last element
           // Signal that a record was removed
           signalDueDateWithin24hrsRemoved();
           return removedRecord;
         } else {
           // Return an empty map if the cache is empty
           return <String, dynamic>{};
         }
       });
     } catch (e) {
       QuizzerLogger.logError('Error in DueDateWithin24hrsCache getAndRemoveRecord - $e');
       rethrow;
     }
  }

  // --- Get and Remove Record by Question ID (ADDED) ---
  /// Retrieves and removes the first record matching the given questionId.
  /// Ensures thread safety using a lock.
  /// Returns the found record, or an empty Map `{}` if no matching record is found.
  Future<Map<String, dynamic>> getAndRemoveRecordByQuestionId(String questionId) async {
     try {
       QuizzerLogger.logMessage('Entering DueDateWithin24hrsCache getAndRemoveRecordByQuestionId()...');
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
           // Signal that a record was removed
           signalDueDateWithin24hrsRemoved();
           return removedRecord;
         } else {
           // Return an empty map if no record was found
           QuizzerLogger.logWarning('DueDateWithin24hrsCache: Record not found for removal (QID: $questionId)');
           return <String, dynamic>{};
         }
       });
     } catch (e) {
       QuizzerLogger.logError('Error in DueDateWithin24hrsCache getAndRemoveRecordByQuestionId - $e');
       rethrow;
     }
  }

  // --- Peek All Records (Read-Only) ---
  /// Returns a read-only copy of all records currently in the cache.
  /// Ensures thread safety using a lock.
  Future<List<Map<String, dynamic>>> peekAllRecords() async {
    try {
      QuizzerLogger.logMessage('Entering DueDateWithin24hrsCache peekAllRecords()...');
      return await _lock.synchronized(() {
        // Return a copy to prevent external modification
        return List<Map<String, dynamic>>.from(_cache);
      });
    } catch (e) {
      QuizzerLogger.logError('Error in DueDateWithin24hrsCache peekAllRecords - $e');
      rethrow;
    }
  }

  // --- Flush Cache to Unprocessed ---
  /// Removes all records from this cache and adds them to the UnprocessedCache.
  /// Ensures thread safety using locks on both caches implicitly via their methods.
  Future<void> flushToUnprocessedCache() async {
    try {
      QuizzerLogger.logMessage('Entering DueDateWithin24hrsCache flushToUnprocessedCache()...');
      List<Map<String, dynamic>> recordsToMove = []; // Initialize
      // Atomically get and clear records from this cache
      await _lock.synchronized(() {
        recordsToMove = List.from(_cache);
        if (_cache.isNotEmpty) {
          // Signal that records were removed (single signal for flush operation)
          signalDueDateWithin24hrsRemoved();
        }
        _cache.clear();
      });

      // Add the retrieved records to the unprocessed cache
      if (recordsToMove.isNotEmpty) {
         QuizzerLogger.logMessage('Flushing ${recordsToMove.length} records from DueDateWithin24hrsCache to UnprocessedCache.');
         await _unprocessedCache.addRecords(recordsToMove);
      } else {
         QuizzerLogger.logMessage('DueDateWithin24hrsCache is empty, nothing to flush.');
      }
    } catch (e) {
      QuizzerLogger.logError('Error in DueDateWithin24hrsCache flushToUnprocessedCache - $e');
      rethrow;
    }
  }

  /// Checks if the cache is currently empty.
  Future<bool> isEmpty() async {
    try {
      QuizzerLogger.logMessage('Entering DueDateWithin24hrsCache isEmpty()...');
      return await _lock.synchronized(() {
        return _cache.isEmpty;
      });
    } catch (e) {
      QuizzerLogger.logError('Error in DueDateWithin24hrsCache isEmpty - $e');
      rethrow;
    }
  }

  /// Returns the current number of records in the cache.
  Future<int> getLength() async {
     try {
       QuizzerLogger.logMessage('Entering DueDateWithin24hrsCache getLength()...');
       return await _lock.synchronized(() {
           return _cache.length;
       });
     } catch (e) {
       QuizzerLogger.logError('Error in DueDateWithin24hrsCache getLength - $e');
       rethrow;
     }
  }

  Future<void> clear() async {
    try {
      QuizzerLogger.logMessage('Entering DueDateWithin24hrsCache clear()...');
      await _lock.synchronized(() {
        if (_cache.isNotEmpty) {
          // Signal that records were removed (single signal for clear operation)
          signalDueDateWithin24hrsRemoved();
          _cache.clear();
          // QuizzerLogger.logMessage('AnswerHistoryCache cleared.'); // Optional log
        }
      });
    } catch (e) {
      QuizzerLogger.logError('Error in DueDateWithin24hrsCache clear - $e');
      rethrow;
    }
  }

  // --- Helper function to update cache location in database ---
  Future<void> _updateCacheLocationInDatabase(String questionId, int cacheLocation) async {
    try {
      QuizzerLogger.logMessage('Entering DueDateWithin24hrsCache _updateCacheLocationInDatabase()...');
      final userId = _sessionManager.userId;
      if (userId == null) {
        throw StateError('DueDateWithin24hrsCache: Cannot update cache location - no user ID available');
      }

      // Table function handles its own database access
      await updateCacheLocation(userId, questionId, cacheLocation);
    } catch (e) {
      QuizzerLogger.logError('Error in DueDateWithin24hrsCache _updateCacheLocationInDatabase - $e');
      rethrow;
    }
  }
}
