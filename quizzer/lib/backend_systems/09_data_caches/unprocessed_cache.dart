import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // For logging

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

  // --- Notification Stream ---
  // Used to notify listeners (like PreProcessWorker) when a record is added to an empty cache.
  final StreamController<void> _addController = StreamController<void>.broadcast();

  /// A stream that emits an event when a record is added to a previously empty cache.
  Stream<void> get onRecordAdded => _addController.stream;
  // -------------------------

  // --- Add Record (with duplicate check and prioritization) ---
  Future<void> addRecord(Map<String, dynamic> record) async {
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
        QuizzerLogger.logMessage('[UnprocessedCache.addRecord] Added to overall empty cache, signaling addController.');
        _addController.add(null);
      }
    });
  }

  // --- Add Multiple Records (with duplicate check and prioritization) ---
  Future<void> addRecords(List<Map<String, dynamic>> records) async {
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
        QuizzerLogger.logMessage('[UnprocessedCache.addRecords] Added records to overall empty cache, signaling addController.');
        _addController.add(null);
      }
      QuizzerLogger.logValue('[UnprocessedCache.addRecords END] Processed: ${records.length}, Newly Added: $addedCount');
    });
  }
  
  // --- Get and Remove Record by ID (Mainly for specific removal if needed, not prioritization) ---
  Future<Map<String, dynamic>> getAndRemoveRecord(String userUuid, String questionId) async {
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
           QuizzerLogger.logValue('[UnprocessedCache.getAndRemoveRecord END] Found & Removed QID: $questionId.');
           return foundRecord!;
         }
       }
       
       QuizzerLogger.logValue('[UnprocessedCache.getAndRemoveRecord END] QID: $questionId Not Found.');
       return <String, dynamic>{};
     });
  }

  // --- Get and Remove Oldest Record (now with prioritization logic) ---
  Future<Map<String, dynamic>> getAndRemoveOldestRecord() async {
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
        return removedRecord;
      } else {
        QuizzerLogger.logValue('[UnprocessedCache.getAndRemoveOldestRecord] All queues empty.');
        return <String, dynamic>{};
      }
    });
  }

  // --- Check if Empty ---
  Future<bool> isEmpty() async {
    return await _lock.synchronized(() {
      return _eligiblePriorityQueue.isEmpty &&
             _circulatingPriorityQueue.isEmpty &&
             _otherRecordsQueue.isEmpty;
    });
  }

  // --- Peek All Records (Read-Only, in priority order) ---
  Future<List<Map<String, dynamic>>> peekAllRecords() async {
    return await _lock.synchronized(() {
      return [
        ..._eligiblePriorityQueue,
        ..._circulatingPriorityQueue,
        ..._otherRecordsQueue
      ];
    });
  }

  Future<void> clear() async {
    await _lock.synchronized(() {
      _eligiblePriorityQueue.clear();
      _circulatingPriorityQueue.clear();
      _otherRecordsQueue.clear();
      _allKnownIdsInCache.clear();
      QuizzerLogger.logMessage('UnprocessedCache all queues cleared.');
    });
  }

  // --- Close Stream Controller ---
  /// Closes the stream controller. Should be called when the cache is no longer needed.
  void dispose() {
    _addController.close();
  }
}
