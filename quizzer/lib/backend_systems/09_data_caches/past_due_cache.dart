import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_cache_signals.dart'; // Import cache signals
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'unprocessed_cache.dart'; // Import for flushing
import 'dart:math';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart'; // For updateCacheLocation
import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // For user ID

// ==========================================

/// Cache for user question records whose next revision due date is definitively in the past.
/// Read by the Eligibility Worker.
/// Implements the singleton pattern.
class PastDueCache {
  // Singleton pattern setup
  static final PastDueCache _instance = PastDueCache._internal();
  factory PastDueCache() => _instance;
  PastDueCache._internal(); // Private constructor

  final Lock                  _lock = Lock();
  final List<Map<String, dynamic>>  _cache = [];
  final UnprocessedCache      _unprocessedCache = UnprocessedCache(); // Get singleton instance

  // Make SessionManager reference lazy to avoid circular dependency
  SessionManager get _sessionManager => getSessionManager();

  // --- Add Record (with basic validation) ---
  /// Adds a single question record. Assumes the due date check has already happened.
  /// Ensures thread safety using a lock.
  Future<void> addRecord(Map<String, dynamic> record) async {
    try {
      QuizzerLogger.logMessage('Entering PastDueCache addRecord()...');
      // Basic validation: Ensure record has required key
      if (!record.containsKey('question_id')) {
        QuizzerLogger.logError('PastDueCache: Attempted to add record missing question_id.');
        throw ArgumentError("Record added to PastDueCache must have a question_id.");
      }
      final String questionId = record['question_id'] as String;

      // Optional: Add assertion that due date is indeed in the past if needed
      // final dueDateString = record['next_revision_due'] as String?;
      // if (dueDateString != null) {
      //   final parsedDueDate = DateTime.tryParse(dueDateString);
      //   assert(parsedDueDate != null && parsedDueDate.isBefore(DateTime.now()),
      //          'Record added to PastDueCache should have due date in the past. QID: $questionId');
      // }

      await _lock.synchronized(() {
        final bool wasEmpty = _cache.isEmpty;
        _cache.add(record);
        if (wasEmpty) {
          QuizzerLogger.logMessage('[PastDueCache.addRecord] Added to empty cache (QID: $questionId), signaling SwitchBoard.');
          signalPastDueAdded(); // Use unified signal
        }
         QuizzerLogger.logValue('[PastDueCache.addRecord] Added QID: $questionId, Cache Size After: ${_cache.length}');
      });

      // Update cache location in database after successful addition
      await _updateCacheLocationInDatabase(questionId, 2);
    } catch (e) {
      QuizzerLogger.logError('Error in PastDueCache addRecord - $e');
      rethrow;
    }
  }

  // --- Add Multiple Records ---
  /// Adds a list of user question records to the cache.
  /// Ensures thread safety using a lock.
  Future<void> addRecords(List<Map<String, dynamic>> records, {bool updateDatabaseLocation = true}) async {
    try {
      QuizzerLogger.logMessage('Entering PastDueCache addRecords()...');
      if (records.isEmpty) return;

      await _lock.synchronized(() {
        final bool wasEmpty = _cache.isEmpty;
        _cache.addAll(records); // Add all records
        if (wasEmpty && records.isNotEmpty) {
           QuizzerLogger.logMessage('[PastDueCache.addRecords] Added ${records.length} records to empty cache, signaling SwitchBoard.');
           signalPastDueAdded(); // Use unified signal
        }
         QuizzerLogger.logValue('[PastDueCache.addRecords] Added ${records.length} records, Cache Size After: ${_cache.length}');
      });

      // Update cache locations in database for all added records (only if requested)
      if (updateDatabaseLocation) {
        for (final record in records) {
          final String? questionId = record['question_id'] as String?;
          if (questionId != null) {
            await _updateCacheLocationInDatabase(questionId, 2);
          }
        }
      }
    } catch (e) {
      QuizzerLogger.logError('Error in PastDueCache addRecords - $e');
      rethrow;
    }
  }

  /// Retrieves and removes a RANDOM record from the cache.
  /// Ensures thread safety using a lock.
  /// Returns the removed record, or an empty Map `{}` if the cache is empty.
  Future<Map<String, dynamic>> getAndRemoveRandomRecord() async {
    try {
      QuizzerLogger.logMessage('Entering PastDueCache getAndRemoveRandomRecord()...');
      return await _lock.synchronized(() {
        if (_cache.isEmpty) {
          QuizzerLogger.logWarning('PastDueCache: Cache is empty, no record to remove');
          return <String, dynamic>{}; // Return empty map if cache is empty
        }
        // Select a random index
        final randomIndex = Random().nextInt(_cache.length);
        // Remove the record at the random index and return it
        final removedRecord = _cache.removeAt(randomIndex);
        // Signal that a record was removed
        signalPastDueRemoved();
        return removedRecord;
      });
    } catch (e) {
      QuizzerLogger.logError('Error in PastDueCache getAndRemoveRandomRecord - $e');
      rethrow;
    }
  }

  // --- Peek All Records (Read-Only) ---
  /// Returns a read-only copy of all records currently in the cache.
  /// Ensures thread safety using a lock.
  Future<List<Map<String, dynamic>>> peekAllRecords() async {
    try {
      QuizzerLogger.logMessage('Entering PastDueCache peekAllRecords()...');
      return await _lock.synchronized(() {
        // Return a copy to prevent external modification
        return List<Map<String, dynamic>>.from(_cache);
      });
    } catch (e) {
      QuizzerLogger.logError('Error in PastDueCache peekAllRecords - $e');
      rethrow;
    }
  }

  // --- Flush Cache to Unprocessed ---
  /// Removes all records from this cache and adds them to the UnprocessedCache.
  /// Ensures thread safety using locks on both caches implicitly via their methods.
  Future<void> flushToUnprocessedCache() async {
    try {
      QuizzerLogger.logMessage('Entering PastDueCache flushToUnprocessedCache()...');
      List<Map<String, dynamic>> recordsToMove = [];
      await _lock.synchronized(() {
        recordsToMove = List.from(_cache);
        if (_cache.isNotEmpty) {
          // Signal that records were removed (single signal for flush operation)
          signalPastDueRemoved();
        }
        _cache.clear();
      });

      if (recordsToMove.isNotEmpty) {
         QuizzerLogger.logMessage('Flushing ${recordsToMove.length} records from PastDueCache to UnprocessedCache.');
         await _unprocessedCache.addRecords(recordsToMove);
      } else {
         QuizzerLogger.logMessage('PastDueCache is empty, nothing to flush.');
      }
    } catch (e) {
      QuizzerLogger.logError('Error in PastDueCache flushToUnprocessedCache - $e');
      rethrow;
    }
  }

  /// Checks if the cache is currently empty.
  Future<bool> isEmpty() async {
    try {
      QuizzerLogger.logMessage('Entering PastDueCache isEmpty()...');
      return await _lock.synchronized(() {
        return _cache.isEmpty;
      });
    } catch (e) {
      QuizzerLogger.logError('Error in PastDueCache isEmpty - $e');
      rethrow;
    }
  }

  /// Returns the current number of records in the cache.
  Future<int> getLength() async {
     try {
       QuizzerLogger.logMessage('Entering PastDueCache getLength()...');
       return await _lock.synchronized(() {
           return _cache.length;
       });
     } catch (e) {
       QuizzerLogger.logError('Error in PastDueCache getLength - $e');
       rethrow;
     }
  }

  Future<void> clear() async {
    try {
      QuizzerLogger.logMessage('Entering PastDueCache clear()...');
      await _lock.synchronized(() {
        if (_cache.isNotEmpty) {
          // Signal that records were removed (single signal for clear operation)
          signalPastDueRemoved();
          _cache.clear();
          QuizzerLogger.logMessage('PastDueCache cleared.');
        }
      });
    } catch (e) {
      QuizzerLogger.logError('Error in PastDueCache clear - $e');
      rethrow;
    }
  }

  // --- Helper function to update cache location in database ---
  Future<void> _updateCacheLocationInDatabase(String questionId, int cacheLocation) async {
    try {
      QuizzerLogger.logMessage('Entering PastDueCache _updateCacheLocationInDatabase()...');
      final userId = _sessionManager.userId;
      if (userId == null) {
        throw StateError('PastDueCache: Cannot update cache location - no user ID available');
      }

      // Table function handles its own database access
      await updateCacheLocation(userId, questionId, cacheLocation);
    } catch (e) {
      QuizzerLogger.logError('Error in PastDueCache _updateCacheLocationInDatabase - $e');
      rethrow;
    }
  }
}
