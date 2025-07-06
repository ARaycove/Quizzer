import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_cache_signals.dart'; // Import cache signals
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // For logging
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart'; // For updateCacheLocation
import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // For user ID

// ==========================================

class UnprocessedCache {
  // Singleton pattern setup
  static final UnprocessedCache _instance = UnprocessedCache._internal();
  factory UnprocessedCache() => _instance;
  UnprocessedCache._internal(); // Private constructor

  final Lock _lock = Lock();
  // Three separate queues for prioritization
  final List<Map<String, dynamic>> _eligiblePriorityQueue = [];
  final List<Map<String, dynamic>> _circulatingPriorityQueue = [];
  final List<Map<String, dynamic>> _otherRecordsQueue = [];
  // Set to track all unique question IDs currently in any queue
  final Set<String> _allKnownIdsInCache = {};

  // Make SessionManager reference lazy to avoid circular dependency
  SessionManager get _sessionManager => getSessionManager();

  // --- Add Record (with duplicate check and prioritization) ---
  Future<void> addRecord(Map<String, dynamic> record, {bool updateDatabaseLocation = true}) async {
    try {
      QuizzerLogger.logMessage('Entering UnprocessedCache addRecord()...');
      final String? questionId = record['question_id'] as String?;
      if (questionId == null) {
        QuizzerLogger.logError('UnprocessedCache: Attempted to add record missing question_id.');
        throw StateError("Record must have a question_id to be added to UnprocessedCache.");
      }

      await _lock.synchronized(() {
        if (_allKnownIdsInCache.contains(questionId)) {
          QuizzerLogger.logValue('[UnprocessedCache.addRecord] QID: $questionId already in cache, skipping.');
          return;
        }

        final bool wasOverallEmpty = _eligiblePriorityQueue.isEmpty &&
                                   _circulatingPriorityQueue.isEmpty &&
                                   _otherRecordsQueue.isEmpty;

        bool isEligible = (record['is_eligible'] as int? ?? 0) == 1;
        bool inCirculation = (record['in_circulation'] as int? ?? 0) == 1;

        if (isEligible) {
          _eligiblePriorityQueue.add(record);
          QuizzerLogger.logValue('[UnprocessedCache.addRecord] QID: $questionId added to _eligiblePriorityQueue.');
        } else if (inCirculation) {
          _circulatingPriorityQueue.add(record);
          QuizzerLogger.logValue('[UnprocessedCache.addRecord] QID: $questionId added to _circulatingPriorityQueue.');
        } else {
          _otherRecordsQueue.add(record);
          QuizzerLogger.logValue('[UnprocessedCache.addRecord] QID: $questionId added to _otherRecordsQueue.');
        }
        _allKnownIdsInCache.add(questionId);

        if (wasOverallEmpty) {
          QuizzerLogger.logMessage('[UnprocessedCache.addRecord] Added to overall empty cache, signaling SwitchBoard.');
          signalUnprocessedAdded(); // Use unified signal
        }
      });

      // Update cache location in database after successful addition (only if requested)
      if (updateDatabaseLocation) {
        await _updateCacheLocationInDatabase(questionId, 0);
      }
    } catch (e) {
      QuizzerLogger.logError('Error in UnprocessedCache addRecord - $e');
      rethrow;
    }
  }

  // --- Add Multiple Records (with duplicate check and prioritization) ---
  Future<void> addRecords(List<Map<String, dynamic>> records, {bool updateDatabaseLocation = true}) async {
    try {
      QuizzerLogger.logMessage('Entering UnprocessedCache addRecords()...');
      if (records.isEmpty) return;

      await _lock.synchronized(() {
        final bool wasOverallEmpty = _eligiblePriorityQueue.isEmpty &&
                                   _circulatingPriorityQueue.isEmpty &&
                                   _otherRecordsQueue.isEmpty;
        int addedCount = 0;

        for (final record in records) {
          final String? questionId = record['question_id'] as String?;
          if (questionId == null) {
            QuizzerLogger.logWarning('UnprocessedCache: Record missing question_id during bulk add, skipped.');
            continue;
          }

          if (_allKnownIdsInCache.contains(questionId)) {
            QuizzerLogger.logMessage('UnprocessedCache: Duplicate record skipped during bulk add (QID: $questionId)');
            continue;
          }

          bool isEligible = (record['is_eligible'] as int? ?? 0) == 1;
          bool inCirculation = (record['in_circulation'] as int? ?? 0) == 1;

          if (isEligible) {
            _eligiblePriorityQueue.add(record);
          } else if (inCirculation) {
            _circulatingPriorityQueue.add(record);
          } else {
            _otherRecordsQueue.add(record);
          }
          _allKnownIdsInCache.add(questionId);
          addedCount++;
        }

        if (addedCount > 0 && wasOverallEmpty) {
          QuizzerLogger.logMessage('[UnprocessedCache.addRecords] Added records to overall empty cache, signaling SwitchBoard.');
          signalUnprocessedAdded(); // Use unified signal
        }
        QuizzerLogger.logValue('[UnprocessedCache.addRecords END] Processed: ${records.length}, Newly Added: $addedCount');
      });

      // Update cache locations in database for all added records (only if requested)
      if (updateDatabaseLocation) {
        for (final record in records) {
          final String? questionId = record['question_id'] as String?;
          if (questionId != null && !_allKnownIdsInCache.contains(questionId)) {
            await _updateCacheLocationInDatabase(questionId, 0);
          }
        }
      }
    } catch (e) {
      QuizzerLogger.logError('Error in UnprocessedCache addRecords - $e');
      rethrow;
    }
  }
  
  // --- Get and Remove Record by ID (Mainly for specific removal if needed, not prioritization) ---
  Future<Map<String, dynamic>> getAndRemoveRecord(String userUuid, String questionId) async {
     try {
       QuizzerLogger.logMessage('Entering UnprocessedCache getAndRemoveRecord()...');
       return await _lock.synchronized(() {
         Map<String, dynamic>? foundRecord;
         List<Map<String, dynamic>>? sourceQueue;

         if (_eligiblePriorityQueue.any((r) => r['question_id'] == questionId && r['user_uuid'] == userUuid)) {
           sourceQueue = _eligiblePriorityQueue;
         } else if (_circulatingPriorityQueue.any((r) => r['question_id'] == questionId && r['user_uuid'] == userUuid)) {
           sourceQueue = _circulatingPriorityQueue;
         } else if (_otherRecordsQueue.any((r) => r['question_id'] == questionId && r['user_uuid'] == userUuid)) {
           sourceQueue = _otherRecordsQueue;
         }

         if (sourceQueue != null) {
           int foundIndex = sourceQueue.indexWhere((r) => r['question_id'] == questionId && r['user_uuid'] == userUuid);
           if (foundIndex != -1) {
             foundRecord = sourceQueue.removeAt(foundIndex);
             _allKnownIdsInCache.remove(questionId);
             // Signal that a record was removed
             signalUnprocessedRemoved();
             QuizzerLogger.logValue('[UnprocessedCache.getAndRemoveRecord END] Found & Removed QID: $questionId.');
             return foundRecord;
           }
         }
         
         QuizzerLogger.logWarning('[UnprocessedCache.getAndRemoveRecord END] QID: $questionId Not Found.');
         return <String, dynamic>{};
       });
     } catch (e) {
       QuizzerLogger.logError('Error in UnprocessedCache getAndRemoveRecord - $e');
       rethrow;
     }
  }

  // --- Get and Remove Oldest Record (now with prioritization logic) ---
  Future<Map<String, dynamic>> getAndRemoveOldestRecord() async {
    try {
      QuizzerLogger.logMessage('Entering UnprocessedCache getAndRemoveOldestRecord()...');
      return await _lock.synchronized(() {
        Map<String, dynamic>? removedRecord;
        String? removedQid;

        if (_eligiblePriorityQueue.isNotEmpty) {
          removedRecord = _eligiblePriorityQueue.removeAt(0);
          removedQid = removedRecord['question_id'] as String?;
          QuizzerLogger.logValue('[UnprocessedCache.getAndRemoveOldestRecord] Removed QID: $removedQid from Eligible Queue.');
        } else if (_circulatingPriorityQueue.isNotEmpty) {
          removedRecord = _circulatingPriorityQueue.removeAt(0);
          removedQid = removedRecord['question_id'] as String?;
          QuizzerLogger.logValue('[UnprocessedCache.getAndRemoveOldestRecord] Removed QID: $removedQid from Circulating Queue.');
        } else if (_otherRecordsQueue.isNotEmpty) {
          removedRecord = _otherRecordsQueue.removeAt(0);
          removedQid = removedRecord['question_id'] as String?;
          QuizzerLogger.logValue('[UnprocessedCache.getAndRemoveOldestRecord] Removed QID: $removedQid from Other Records Queue.');
        }

        if (removedRecord != null && removedQid != null) {
          _allKnownIdsInCache.remove(removedQid);
          // Signal that a record was removed
          signalUnprocessedRemoved();
          return removedRecord;
        } else {
          QuizzerLogger.logWarning('[UnprocessedCache.getAndRemoveOldestRecord] All queues empty.');
          return <String, dynamic>{};
        }
      });
    } catch (e) {
      QuizzerLogger.logError('Error in UnprocessedCache getAndRemoveOldestRecord - $e');
      rethrow;
    }
  }

  // --- Check if Empty ---
  Future<bool> isEmpty() async {
    try {
      QuizzerLogger.logMessage('Entering UnprocessedCache isEmpty()...');
      return await _lock.synchronized(() {
        return _eligiblePriorityQueue.isEmpty &&
               _circulatingPriorityQueue.isEmpty &&
               _otherRecordsQueue.isEmpty;
      });
    } catch (e) {
      QuizzerLogger.logError('Error in UnprocessedCache isEmpty - $e');
      rethrow;
    }
  }

  // --- Peek All Records (Read-Only, in priority order) ---
  Future<List<Map<String, dynamic>>> peekAllRecords() async {
    try {
      QuizzerLogger.logMessage('Entering UnprocessedCache peekAllRecords()...');
      return await _lock.synchronized(() {
        return [
          ..._eligiblePriorityQueue,
          ..._circulatingPriorityQueue,
          ..._otherRecordsQueue
        ];
      });
    } catch (e) {
      QuizzerLogger.logError('Error in UnprocessedCache peekAllRecords - $e');
      rethrow;
    }
  }

  Future<void> clear() async {
    try {
      QuizzerLogger.logMessage('Entering UnprocessedCache clear()...');
      await _lock.synchronized(() {
        final bool wasNotEmpty = _eligiblePriorityQueue.isNotEmpty ||
                               _circulatingPriorityQueue.isNotEmpty ||
                               _otherRecordsQueue.isNotEmpty;
        
        if (wasNotEmpty) {
          // Signal that records were removed (single signal for clear operation)
          signalUnprocessedRemoved();
        }
        
        _eligiblePriorityQueue.clear();
        _circulatingPriorityQueue.clear();
        _otherRecordsQueue.clear();
        _allKnownIdsInCache.clear();
        QuizzerLogger.logMessage('UnprocessedCache all queues cleared.');
      });
    } catch (e) {
      QuizzerLogger.logError('Error in UnprocessedCache clear - $e');
      rethrow;
    }
  }

  // --- Helper function to update cache location in database ---
  Future<void> _updateCacheLocationInDatabase(String questionId, int cacheLocation) async {
    try {
      QuizzerLogger.logMessage('Entering UnprocessedCache _updateCacheLocationInDatabase()...');
      final userId = _sessionManager.userId;
      if (userId == null) {
        throw StateError('UnprocessedCache: Cannot update cache location - no user ID available');
      }

      // Table function handles its own database access
      await updateCacheLocation(userId, questionId, cacheLocation);
    } catch (e) {
      QuizzerLogger.logError('Error in UnprocessedCache _updateCacheLocationInDatabase - $e');
      rethrow;
    }
  }
}
