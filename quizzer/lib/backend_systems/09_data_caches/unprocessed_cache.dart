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
  final List<Map<String, dynamic>> _cache = [];

  // --- Notification Stream ---
  // Used to notify listeners (like PreProcessWorker) when a record is added to an empty cache.
  final StreamController<void> _addController = StreamController<void>.broadcast();

  /// A stream that emits an event when a record is added to a previously empty cache.
  Stream<void> get onRecordAdded => _addController.stream;
  // -------------------------

  // --- Add Record (with duplicate check) ---

  /// Adds a single user question record to the cache.
  /// Ensures thread safety using a lock.
  /// Notifies listeners via [onRecordAdded] if the cache was empty.
  Future<void> addRecord(Map<String, dynamic> record) async {
    final String? questionId = record['question_id'] as String?;
    if (questionId == null) {
       QuizzerLogger.logError('UnprocessedCache: Attempted to add record missing question_id.');
       throw StateError("Can't do that");
    }
    await _lock.synchronized(() {
        QuizzerLogger.logValue('[UnprocessedCache.addRecord START] QID: $questionId, Cache Size Before: ${_cache.length}');
        final bool wasEmpty = _cache.isEmpty;
        _cache.add(record);
        if (wasEmpty) {
          QuizzerLogger.logMessage('[UnprocessedCache.addRecord] Added to empty cache, signaling addController.');
          _addController.add(null);
        }
        QuizzerLogger.logValue('[UnprocessedCache.addRecord END] QID: $questionId, Added: true, Cache Size After: ${_cache.length}');
    });
  }

  // --- Add Multiple Records ---

  /// Adds a list of user question records to the cache.
  /// Ensures thread safety using a lock.
  /// Notifies listeners via [onRecordAdded] if the cache was empty before adding.
  Future<void> addRecords(List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return; // Avoid processing empty lists

    List<Map<String, dynamic>> recordsToAdd = [];
    await _lock.synchronized(() {
      final int sizeBefore = _cache.length;
      QuizzerLogger.logValue('[UnprocessedCache.addRecords START] Input Count: ${records.length}, Cache Size Before: $sizeBefore');
      final bool wasEmpty = _cache.isEmpty;
      // Create a set of existing IDs for efficient lookup
      final Set<String> existingIds = _cache.map((r) => r['question_id'] as String).toSet();

      for (final record in records) {
        final String? questionId = record['question_id'] as String?;
        // Only add if ID exists and is not already in the cache
        if (questionId != null && !existingIds.contains(questionId)) {
          recordsToAdd.add(record);
          existingIds.add(questionId); // Add to set immediately to handle duplicates within the input list
        }
         else if (questionId != null && existingIds.contains(questionId)) {
           QuizzerLogger.logMessage('UnprocessedCache: Duplicate record skipped during bulk add (QID: $questionId)'); // Optional log
         }
         else {
            QuizzerLogger.logWarning('UnprocessedCache: Record missing question_id during bulk add, skipped.');
         }
      }

      if (recordsToAdd.isNotEmpty) {
        QuizzerLogger.logValue('[UnprocessedCache.addRecords] Adding ${recordsToAdd.length} new records.');
        _cache.addAll(recordsToAdd);
        if (wasEmpty) {
          QuizzerLogger.logMessage('[UnprocessedCache.addRecords] Added to empty cache, signaling addController.');
          _addController.add(null);
        }
      }
      QuizzerLogger.logValue('[UnprocessedCache.addRecords END] Added: ${recordsToAdd.length}, Cache Size After: ${_cache.length}');
    });
  }

  // --- Get and Remove Record ---
  /// Retrieves and removes a single record based on userUuid and questionId.
  /// Ensures thread safety using a lock.
  /// Returns the found record, or an empty Map `{}` if no matching record is found.
  Future<Map<String, dynamic>> getAndRemoveRecord(String userUuid, String questionId) async {
     return await _lock.synchronized(() {
       final int sizeBefore = _cache.length;
       QuizzerLogger.logValue('[UnprocessedCache.getAndRemoveRecord START] User: $userUuid, QID: $questionId, Cache Size Before: $sizeBefore');
       int foundIndex = -1;
       for (int i = 0; i < _cache.length; i++) {
         final record = _cache[i];
         if (record['user_uuid'] == userUuid && record['question_id'] == questionId) {
           foundIndex = i;
           break;
         }
       }

       if (foundIndex != -1) {
         final removedRecord = _cache.removeAt(foundIndex);
         QuizzerLogger.logValue('[UnprocessedCache.getAndRemoveRecord END] Found & Removed QID: $questionId, Cache Size After: ${_cache.length}');
         return removedRecord;
       } else {
         QuizzerLogger.logValue('[UnprocessedCache.getAndRemoveRecord END] QID: $questionId Not Found, Cache Size After: ${_cache.length}');
         return <String, dynamic>{};
       }
     });
  }

  // --- Get and Remove Oldest Record (FIFO) ---

  /// Removes and returns the oldest record added to the cache (FIFO).
  /// Used by workers processing records in the order they arrived.
  /// Ensures thread safety using a lock.
  /// Returns an empty Map `{}` if the cache is empty.
  Future<Map<String, dynamic>> getAndRemoveOldestRecord() async {
     return await _lock.synchronized(() {
       final int sizeBefore = _cache.length;
       QuizzerLogger.logValue('[UnprocessedCache.getAndRemoveOldestRecord START] Cache Size Before: $sizeBefore');
       if (_cache.isNotEmpty) {
         final removedRecord = _cache.removeAt(0);
         final String removedQid = removedRecord['question_id'] ?? 'UNKNOWN_ID';
         QuizzerLogger.logValue('[UnprocessedCache.getAndRemoveOldestRecord END] Removed QID: $removedQid, Cache Size After: ${_cache.length}');
         return removedRecord; 
       } else {
         QuizzerLogger.logValue('[UnprocessedCache.getAndRemoveOldestRecord END] Cache Empty, Cache Size After: ${_cache.length}');
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

  // --- Close Stream Controller ---
  /// Closes the stream controller. Should be called when the cache is no longer needed.
  void dispose() {
    _addController.close();
  }
}
