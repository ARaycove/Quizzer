import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'unprocessed_cache.dart'; // Import for flushing
import 'package:quizzer/backend_systems/06_question_queue_server/switch_board.dart'; // Import SwitchBoard
import 'dart:math';

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
  final SwitchBoard           _switchBoard = SwitchBoard(); // Get SwitchBoard instance

  // --- Notification Stream ---
  // Used to notify listeners (like EligibilityCheckWorker) when a record is added to an empty cache.
  final StreamController<void> _addController = StreamController<void>.broadcast();

  /// A stream that emits an event when a record is added to a previously empty cache.
  Stream<void> get onRecordAdded => _addController.stream;
  // -------------------------

  // --- Add Record (with basic validation) ---
  /// Adds a single question record. Assumes the due date check has already happened.
  /// Ensures thread safety using a lock.
  /// Notifies listeners via [onRecordAdded] if the cache was empty.
  Future<void> addRecord(Map<String, dynamic> record) async {
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
        QuizzerLogger.logMessage('[PastDueCache.addRecord] Added to empty cache (QID: $questionId), signaling addController.');
        _switchBoard.signalPastDueCacheAdded(); // Signal the SwitchBoard
        _addController.add(null); // Also signal local stream for direct listeners if any
      }
       QuizzerLogger.logValue('[PastDueCache.addRecord] Added QID: $questionId, Cache Size After: ${_cache.length}');
    });
  }

  // --- Add Multiple Records ---
  /// Adds a list of user question records to the cache.
  /// Ensures thread safety using a lock.
  /// Notifies listeners via [onRecordAdded] if the cache was empty before adding.
  Future<void> addRecords(List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return;

    await _lock.synchronized(() {
      final bool wasEmpty = _cache.isEmpty;
      _cache.addAll(records); // Add all records
      if (wasEmpty && records.isNotEmpty) {
         QuizzerLogger.logMessage('[PastDueCache.addRecords] Added ${records.length} records to empty cache, signaling addController.');
         _switchBoard.signalPastDueCacheAdded(); // Signal the SwitchBoard
         _addController.add(null); // Also signal local stream
      }
       QuizzerLogger.logValue('[PastDueCache.addRecords] Added ${records.length} records, Cache Size After: ${_cache.length}');
    });
  }


  /// Retrieves and removes a RANDOM record from the cache.
  /// Ensures thread safety using a lock.
  /// Returns the removed record, or an empty Map `{}` if the cache is empty.
  Future<Map<String, dynamic>> getAndRemoveRandomRecord() async {
    return await _lock.synchronized(() {
      if (_cache.isEmpty) {
        return <String, dynamic>{}; // Return empty map if cache is empty
      }
      // Select a random index
      final randomIndex = Random().nextInt(_cache.length);
      // Remove the record at the random index and return it
      return _cache.removeAt(randomIndex);
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
    List<Map<String, dynamic>> recordsToMove = [];
    await _lock.synchronized(() {
      recordsToMove = List.from(_cache);
      _cache.clear();
    });

    if (recordsToMove.isNotEmpty) {
       QuizzerLogger.logMessage('Flushing ${recordsToMove.length} records from PastDueCache to UnprocessedCache.');
       await _unprocessedCache.addRecords(recordsToMove);
    } else {
       QuizzerLogger.logMessage('PastDueCache is empty, nothing to flush.');
    }
  }

  /// Checks if the cache is currently empty.
  Future<bool> isEmpty() async {
    return await _lock.synchronized(() {
      return _cache.isEmpty;
    });
  }

  /// Returns the current number of records in the cache.
  Future<int> getLength() async {
     return await _lock.synchronized(() {
         return _cache.length;
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
     QuizzerLogger.logMessage('PastDueCache disposed.');
  }
}
