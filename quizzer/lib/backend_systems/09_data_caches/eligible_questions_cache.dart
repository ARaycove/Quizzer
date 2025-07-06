import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_cache_signals.dart'; // Import cache signals
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Uncomment if logging needed
import 'package:quizzer/backend_systems/09_data_caches/unprocessed_cache.dart'; // Import UnprocessedCache
import 'package:quizzer/backend_systems/09_data_caches/past_due_cache.dart'; // ADDED: Import new target cache
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart'; // For updateCacheLocation
import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // For user ID

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
  final List<Map<String, dynamic>> _cache = [];
  final UnprocessedCache _unprocessedCache = UnprocessedCache(); // Get singleton instance

  // Make SessionManager reference lazy to avoid circular dependency
  SessionManager get _sessionManager => getSessionManager();

  // -------------------------

  // --- Add Record (with duplicate check) ---

  /// Adds a single eligible question record to the cache, only if a record
  /// with the same question_id does not already exist.
  /// Ensures thread safety using a lock.
  Future<void> addRecord(Map<String, dynamic> record, {bool updateDatabaseLocation = true}) async {
    try {
      QuizzerLogger.logMessage('Entering EligibleQuestionsCache addRecord()...');
      // Assert required key exists
      assert(record.containsKey('question_id'), 'Record added to EligibleQuestionsCache must contain question_id');
      // final String questionId = record['question_id'] as String; // Assume assertion passes

      await _lock.synchronized(() {
          _cache.add(record);
          // Signal that a record was added
          signalEligibleQuestionsAdded();
      });

      // Update cache location in database after successful addition (only if requested)
      if (updateDatabaseLocation) {
        await _updateCacheLocationInDatabase(record['question_id'], 5);
      }
    } catch (e) {
      QuizzerLogger.logError('Error in EligibleQuestionsCache addRecord - $e');
      rethrow;
    }
  }

  // --- Get and Remove Record by Question ID ---

  /// Retrieves and removes the first record matching the given questionId.
  /// Ensures thread safety using a lock.
  /// Returns the found record, or an empty Map `{}` if no matching record is found.
  Future<Map<String, dynamic>> getAndRemoveRecordByQuestionId(String questionId) async {
     try {
       QuizzerLogger.logMessage('Entering EligibleQuestionsCache getAndRemoveRecordByQuestionId()...');
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
           signalEligibleQuestionsRemoved();
           
           // Check counts and signal AFTER removal but before releasing lock
           _checkAndSignalCacheStatus(); // Call helper within synchronized block
           
           return removedRecord;
         } else {
           // Return an empty map if no record was found
           QuizzerLogger.logWarning('EligibleQuestionsCache: Record not found for removal (QID: $questionId)');
           return <String, dynamic>{};
         }
       });
     } catch (e) {
       QuizzerLogger.logError('Error in EligibleQuestionsCache getAndRemoveRecordByQuestionId - $e');
       rethrow;
     }
  }

  // --- ADDED: Private helper to check and signal within the lock ---
  void _checkAndSignalCacheStatus() {
    try {
      // No need to await getCount/getLowRevisionCount here as we are already inside the lock
      final int totalEligibleCount = _cache.length;
      int lowRevisionCount = 0;
      const int threshold = 3; // Same threshold as getLowRevisionCount method
      for (final record in _cache) {
          if (record.containsKey('revision_streak') && 
              record['revision_streak'] is int && 
              (record['revision_streak'] as int) <= threshold) {
            lowRevisionCount++;
          }
      }
      
      // Signal if EITHER condition is met
      if (totalEligibleCount < 100 || lowRevisionCount < 20) { 
          signalEligibleQuestionsRemoved(); // Use unified signal
      }
    } catch (e) {
      QuizzerLogger.logError('Error in EligibleQuestionsCache _checkAndSignalCacheStatus - $e');
      rethrow;
    }
  }

  // --- Peek All Records (Read-Only) ---

  /// Returns a read-only copy of all eligible question records currently in the cache.
  /// Ensures thread safety using a lock.
  Future<List<Map<String, dynamic>>> peekAllRecords() async {
    try {
      QuizzerLogger.logMessage('Entering EligibleQuestionsCache peekAllRecords()...');
      return await _lock.synchronized(() {
        // Return a copy to prevent external modification
        return List<Map<String, dynamic>>.from(_cache);
      });
    } catch (e) {
      QuizzerLogger.logError('Error in EligibleQuestionsCache peekAllRecords - $e');
      rethrow;
    }
  }

  // --- Flush Cache to Unprocessed ---
  /// Removes all records from this cache and adds them to the UnprocessedCache.
  /// Ensures thread safety using locks on both caches implicitly via their methods.
  Future<void> flushToUnprocessedCache() async {
    try {
      QuizzerLogger.logMessage('Entering EligibleQuestionsCache flushToUnprocessedCache()...');
      List<Map<String, dynamic>> recordsToMove = []; // Initialize
      // Atomically get and clear records from this cache
      await _lock.synchronized(() {
        recordsToMove = List.from(_cache);
        if (_cache.isNotEmpty) {
          // Signal that records were removed (single signal for flush operation)
          signalEligibleQuestionsRemoved();
        }
        _cache.clear();
      });

      // Add the retrieved records to the unprocessed cache
      if (recordsToMove.isNotEmpty) {
         QuizzerLogger.logMessage('Flushing ${recordsToMove.length} records from EligibleQuestionsCache to UnprocessedCache.');
         await _unprocessedCache.addRecords(recordsToMove);
      } else {
         QuizzerLogger.logMessage('EligibleQuestionsCache is empty, nothing to flush.');
      }
    } catch (e) {
      QuizzerLogger.logError('Error in EligibleQuestionsCache flushToUnprocessedCache - $e');
      rethrow;
    }
  }

  // --- Check if Contains Question ID ---
  /// Checks if a record with the specified questionId exists in the cache.
  /// Ensures thread safety using a lock.
  Future<bool> containsQuestionId(String questionId) async {
    try {
      QuizzerLogger.logMessage('Entering EligibleQuestionsCache containsQuestionId()...');
      return await _lock.synchronized(() {
        return _cache.any((record) => record['question_id'] == questionId);
      });
    } catch (e) {
      QuizzerLogger.logError('Error in EligibleQuestionsCache containsQuestionId - $e');
      rethrow;
    }
  }

  // --- Check if Empty ---
  /// Checks if the cache is currently empty.
  Future<bool> isEmpty() async {
    try {
      QuizzerLogger.logMessage('Entering EligibleQuestionsCache isEmpty()...');
      return await _lock.synchronized(() {
        return _cache.isEmpty;
      });
    } catch (e) {
      QuizzerLogger.logError('Error in EligibleQuestionsCache isEmpty - $e');
      rethrow;
    }
  }

  // --- Get Length ---
  /// Returns the current number of records in the cache.
  Future<int> getLength() async {
     try {
       QuizzerLogger.logMessage('Entering EligibleQuestionsCache getLength()...');
       return await _lock.synchronized(() {
           return _cache.length;
       });
     } catch (e) {
       QuizzerLogger.logError('Error in EligibleQuestionsCache getLength - $e');
       rethrow;
     }
  }

  // --- Get Count ---
  /// Returns the current number of records in the cache.
  Future<int> getCount() async {
    try {
      QuizzerLogger.logMessage('Entering EligibleQuestionsCache getCount()...');
      return await _lock.synchronized(() {
        return _cache.length;
      });
    } catch (e) {
      QuizzerLogger.logError('Error in EligibleQuestionsCache getCount - $e');
      rethrow;
    }
  }

  // --- Get Low Revision Count ---
  /// Returns the count of records with a revision_streak <= 3.
  Future<int> getLowRevisionCount({int threshold = 3}) async {
    try {
      QuizzerLogger.logMessage('Entering EligibleQuestionsCache getLowRevisionCount()...');
      return await _lock.synchronized(() {
        int count = 0;
        for (final record in _cache) {
          // Check if the key exists and the value is an int before comparing
          if (record.containsKey('revision_streak') && 
              record['revision_streak'] is int && 
              (record['revision_streak'] as int) <= threshold) {
            count++;
          }
        }
        return count;
      });
    } catch (e) {
      QuizzerLogger.logError('Error in EligibleQuestionsCache getLowRevisionCount - $e');
      rethrow;
    }
  }

  // --- Flush Cache to PastDueCache --- (RENAMED)
  /// Removes all records from this cache and adds them to the PastDueCache.
  /// Intended to be called upon events like module deactivation to force re-evaluation.
  /// Ensures thread safety using locks on both caches implicitly via their methods.
  Future<void> flushToPastDueCache() async { // RENAMED
    try {
      QuizzerLogger.logMessage('Entering EligibleQuestionsCache flushToPastDueCache()...');
      List<Map<String, dynamic>> recordsToMove = []; // Initialize
      bool wasNotEmpty = false; // Track if cache had items before flush
      final PastDueCache pastDueCache = PastDueCache(); // CHANGED: Get instance of new target cache

      // Atomically get and clear records from this cache
      await _lock.synchronized(() {
        recordsToMove = List.from(_cache);
        wasNotEmpty = _cache.isNotEmpty; // Check *before* clearing
        _cache.clear();
        // If it was not empty before clearing, signal that removals happened.
        // This might wake up listeners waiting for eligible records (like PSW),
        // which is okay as they will just find the cache empty again.
        if (wasNotEmpty) {
           QuizzerLogger.logMessage('EligibleQuestionsCache: Flushed non-empty cache. Signaling removal.');
           signalEligibleQuestionsRemoved(); // Use unified signal
        }
      });

      // Add the retrieved records to the target cache
      if (recordsToMove.isNotEmpty) {
         QuizzerLogger.logMessage('Flushing ${recordsToMove.length} records from EligibleQuestionsCache to PastDueCache.'); // CHANGED log message
         // Add records one by one to the target cache to ensure its logic (like signaling) runs correctly
         for (final record in recordsToMove) {
            await pastDueCache.addRecord(record); // CHANGED: Call addRecord on pastDueCache
         }
      } else {
         QuizzerLogger.logMessage('EligibleQuestionsCache was empty, nothing to flush.');
      }
    } catch (e) {
      QuizzerLogger.logError('Error in EligibleQuestionsCache flushToPastDueCache - $e');
      rethrow;
    }
  }
  
  Future<void> clear() async {
    try {
      QuizzerLogger.logMessage('Entering EligibleQuestionsCache clear()...');
      await _lock.synchronized(() {
        if (_cache.isNotEmpty) {
          // Signal that records were removed (single signal for clear operation)
          signalEligibleQuestionsRemoved();
          _cache.clear();
          QuizzerLogger.logMessage('EligibleQuestionsCache cleared.');
        }
      });
    } catch (e) {
      QuizzerLogger.logError('Error in EligibleQuestionsCache clear - $e');
      rethrow;
    }
  }

  // --- Helper function to update cache location in database ---
  Future<void> _updateCacheLocationInDatabase(String questionId, int cacheLocation) async {
    try {
      QuizzerLogger.logMessage('Entering EligibleQuestionsCache _updateCacheLocationInDatabase()...');
      final userId = _sessionManager.userId;
      if (userId == null) {
        throw StateError('EligibleQuestionsCache: Cannot update cache location - no user ID available');
      }

      // Table function handles its own database access
      await updateCacheLocation(userId, questionId, cacheLocation);
    } catch (e) {
      QuizzerLogger.logError('Error in EligibleQuestionsCache _updateCacheLocationInDatabase - $e');
      rethrow;
    }
  }
}
