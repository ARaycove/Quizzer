import 'dart:async';
import 'package:synchronized/synchronized.dart';

// ==========================================

class UnprocessedCache {
  // Singleton pattern setup
  static final UnprocessedCache _instance = UnprocessedCache._internal();
  factory UnprocessedCache() => _instance;
  UnprocessedCache._internal(); // Private constructor

  final Lock _lock = Lock();
  List<Map<String, dynamic>> _cache = [];

  // --- Add Record ---

  /// Adds a single user question record to the cache.
  /// Ensures thread safety using a lock.
  Future<void> addRecord(Map<String, dynamic> record) async {
    // Input validation could be added here if needed
    await _lock.synchronized(() {
      _cache.add(record);
    });
  }

  // --- Add Multiple Records ---

  /// Adds a list of user question records to the cache.
  /// Ensures thread safety using a lock.
  Future<void> addRecords(List<Map<String, dynamic>> records) async {
    // Input validation could be added here if needed
    await _lock.synchronized(() {
      _cache.addAll(records);
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

  // --- Peek All Records (Read-Only) ---
  /// Returns a read-only copy of all records currently in the cache.
  /// Ensures thread safety using a lock.
  Future<List<Map<String, dynamic>>> peekAllRecords() async {
    return await _lock.synchronized(() {
      // Return a copy to prevent external modification
      return List<Map<String, dynamic>>.from(_cache);
    });
  }
}
