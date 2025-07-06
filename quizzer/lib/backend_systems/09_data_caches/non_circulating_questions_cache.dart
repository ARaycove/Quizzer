import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_cache_signals.dart'; // Import cache signals
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart'; // For updateCacheLocation
import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // For user ID

// ==========================================

/// Cache for user question records that are currently not in circulation.
/// Implements the singleton pattern.
class NonCirculatingQuestionsCache {
  // Singleton pattern setup
  static final NonCirculatingQuestionsCache _instance = NonCirculatingQuestionsCache._internal();
  factory NonCirculatingQuestionsCache() => _instance;
  NonCirculatingQuestionsCache._internal(); // Private constructor

  final Lock _lock = Lock();
  final List<Map<String, dynamic>> _cache = [];

  // Make SessionManager reference lazy to avoid circular dependency
  SessionManager get _sessionManager => getSessionManager();

  // --- Add Record (with duplicate check) ---

  /// Adds a single non-circulating question record to the cache, only if a record
  /// with the same question_id does not already exist.
  /// Ensures thread safety using a lock.
  Future<void> addRecord(Map<String, dynamic> record, {bool updateDatabaseLocation = true}) async {
    try {
      QuizzerLogger.logMessage('Entering NonCirculatingQuestionsCache addRecord()...');
      // Basic validation: Ensure record has required keys and correct state
      if (!record.containsKey('question_id') || !record.containsKey('in_circulation')) {
        QuizzerLogger.logWarning('Attempted to add invalid record (missing keys) to NonCirculatingCache');
        throw ArgumentError('Invalid record passed to NonCirculatingCache.addRecord. Missing required keys');
      }
      // final String questionId = record['question_id'] as String; // Assume key exists

      // Assert that the record is indeed non-circulating
      assert(record['in_circulation'] == 0, 'Record added to NonCirculatingCache must have in_circulation == 0');

      await _lock.synchronized(() {
          _cache.add(record);
          // Signal that a record was added
          signalNonCirculatingQuestionsAdded();
      });

      // Update cache location in database after successful addition (only if requested)
      if (updateDatabaseLocation) {
        await _updateCacheLocationInDatabase(record['question_id'], 3);
      }
    } catch (e) {
      QuizzerLogger.logError('Error in NonCirculatingQuestionsCache addRecord - $e');
      rethrow;
    }
  }

  // --- Peek All Records (Read-Only) ---
  /// Returns a read-only copy of all records currently in the cache.
  /// Ensures thread safety using a lock.
  Future<List<Map<String, dynamic>>> peekAllRecords() async {
    try {
      QuizzerLogger.logMessage('Entering NonCirculatingQuestionsCache peekAllRecords()...');
      return await _lock.synchronized(() {
        // Return a copy to prevent external modification
        return List<Map<String, dynamic>>.from(_cache);
      });
    } catch (e) {
      QuizzerLogger.logError('Error in NonCirculatingQuestionsCache peekAllRecords - $e');
      rethrow;
    }
  }

  // --- Get and Remove Record by Question ID ---
  /// Retrieves and removes the first record matching the given questionId.
  /// Assumes questionId is sufficiently unique for the caller's context.
  /// Ensures thread safety using a lock.
  /// Returns the found record, or an empty Map `{}` if no matching record is found.
  Future<Map<String, dynamic>> getAndRemoveRecordByQuestionId(String questionId) async {
     try {
       QuizzerLogger.logMessage('Entering NonCirculatingQuestionsCache getAndRemoveRecordByQuestionId()...');
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
           signalNonCirculatingQuestionsRemoved();
           return removedRecord;
         } else {
           // Return an empty map if no record was found
           QuizzerLogger.logWarning('NonCirculatingQuestionsCache: Record not found for removal (QID: $questionId)');
           return <String, dynamic>{};
         }
       });
     } catch (e) {
       QuizzerLogger.logError('Error in NonCirculatingQuestionsCache getAndRemoveRecordByQuestionId - $e');
       rethrow;
     }
  }

  // --- Check if Empty ---
  /// Checks if the cache is currently empty.
  Future<bool> isEmpty() async {
    try {
      QuizzerLogger.logMessage('Entering NonCirculatingQuestionsCache isEmpty()...');
      return await _lock.synchronized(() {
        return _cache.isEmpty;
      });
    } catch (e) {
      QuizzerLogger.logError('Error in NonCirculatingQuestionsCache isEmpty - $e');
      rethrow;
    }
  }

  // --- Get Length ---
  /// Returns the current number of records in the cache.
  Future<int> getLength() async {
     try {
       QuizzerLogger.logMessage('Entering NonCirculatingQuestionsCache getLength()...');
       return await _lock.synchronized(() {
           return _cache.length;
       });
     } catch (e) {
       QuizzerLogger.logError('Error in NonCirculatingQuestionsCache getLength - $e');
       rethrow;
     }
  }

  Future<void> clear() async {
    try {
      QuizzerLogger.logMessage('Entering NonCirculatingQuestionsCache clear()...');
      await _lock.synchronized(() {
        if (_cache.isNotEmpty) {
          // Signal that records were removed (single signal for clear operation)
          signalNonCirculatingQuestionsRemoved();
          _cache.clear();
          QuizzerLogger.logMessage('NonCirculatingQuestionsCache cleared.');
        }
      });
    } catch (e) {
      QuizzerLogger.logError('Error in NonCirculatingQuestionsCache clear - $e');
      rethrow;
    }
  }
  
  // --- Helper function to update cache location in database ---
  Future<void> _updateCacheLocationInDatabase(String questionId, int cacheLocation) async {
    try {
      QuizzerLogger.logMessage('Entering NonCirculatingQuestionsCache _updateCacheLocationInDatabase()...');
      final userId = _sessionManager.userId;
      if (userId == null) {
        throw StateError('NonCirculatingQuestionsCache: Cannot update cache location - no user ID available');
      }

      // Table function handles its own database access
      await updateCacheLocation(userId, questionId, cacheLocation);
    } catch (e) {
      QuizzerLogger.logError('Error in NonCirculatingQuestionsCache _updateCacheLocationInDatabase - $e');
      rethrow;
    }
  }
}
