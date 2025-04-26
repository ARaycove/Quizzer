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
  List<Map<String, dynamic>> _cache = [];

  // --- Notification Stream ---
  // Used to notify listeners (like PreProcessWorker) when a record is added to an empty cache.
  final StreamController<void> _addController = StreamController<void>.broadcast();

  /// A stream that emits an event when a record is added to a previously empty cache.
  Stream<void> get onRecordAdded => _addController.stream;
  // -------------------------

  // --- Add Record ---

  /// Adds a single user question record to the cache.
  /// Ensures thread safety using a lock.
  /// Notifies listeners via [onRecordAdded] if the cache was empty.
  Future<void> addRecord(Map<String, dynamic> record) async {
    await _lock.synchronized(() {
      final bool wasEmpty = _cache.isEmpty;
      _cache.add(record);
      if (wasEmpty && _cache.isNotEmpty) {
        // QuizzerLogger.logMessage('UnprocessedCache: Notifying record added.'); // Optional log
        _addController.add(null);
      }
    });
  }

  // --- Add Multiple Records ---

  /// Adds a list of user question records to the cache.
  /// Ensures thread safety using a lock.
  /// Notifies listeners via [onRecordAdded] if the cache was empty before adding.
  Future<void> addRecords(List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return; // Avoid processing empty lists
    await _lock.synchronized(() {
      final bool wasEmpty = _cache.isEmpty;
      _cache.addAll(records);
      if (wasEmpty && _cache.isNotEmpty) {
        // QuizzerLogger.logMessage('UnprocessedCache: Notifying records added.'); // Optional log
        _addController.add(null);
      }
    });
  }

  // --- Get and Remove Record ---
  /// Retrieves and removes a single record based on userUuid and questionId.
  /// Ensures thread safety using a lock.
  /// Returns the found record, or an empty Map `{}` if no matching record is found.
  Future<Map<String, dynamic>> getAndRemoveRecord(String userUuid, String questionId) async {
     return await _lock.synchronized(() {
       int foundIndex = -1;
       for (int i = 0; i < _cache.length; i++) {
         final record = _cache[i];
         if (record['user_uuid'] == userUuid && record['question_id'] == questionId) {
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

  // --- Get and Remove Oldest Record (FIFO) ---

  /// Removes and returns the oldest record added to the cache (FIFO).
  /// Used by workers processing records in the order they arrived.
  /// Ensures thread safety using a lock.
  /// Returns an empty Map `{}` if the cache is empty.
  Future<Map<String, dynamic>> getAndRemoveOldestRecord() async {
     return await _lock.synchronized(() {
       if (_cache.isNotEmpty) {
         return _cache.removeAt(0); // Removes and returns the first element (oldest)
       } else {
         // Return an empty map if the cache is empty
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

  // --- Close Stream Controller ---
  /// Closes the stream controller. Should be called when the cache is no longer needed.
  void dispose() {
    _addController.close();
  }
}
