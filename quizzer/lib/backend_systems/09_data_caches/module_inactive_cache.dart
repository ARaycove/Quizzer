import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Assuming logger might be needed
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart'; // For DB access
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart' show getModuleNameForQuestionId; // Function to get module name
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // For Database type

// ==========================================

/// Cache for user question records associated with modules that are currently inactive.
/// Stores records in a map keyed by module name.
/// Implements the singleton pattern.
class ModuleInactiveCache {
  // Singleton pattern setup
  static final ModuleInactiveCache _instance = ModuleInactiveCache._internal();
  factory ModuleInactiveCache() => _instance;
  ModuleInactiveCache._internal(); // Private constructor

  final Lock _lock = Lock();
  // Cache structure changed to Map<moduleName, List<records>>
  final Map<String, List<Map<String, dynamic>>> _cache = {};
  final DatabaseMonitor _dbMonitor = getDatabaseMonitor(); // Get DB monitor instance

  // --- Add Record (with duplicate check per module) ---

  /// Adds a single module-inactive question record to the cache under its module name,
  /// only if a record with the same question_id does not already exist *for that module*.
  /// Ensures thread safety using a lock.
  Future<void> addRecord(Map<String, dynamic> record) async {
    // Basic validation: Ensure record has question_id
    if (!record.containsKey('question_id')) {
      // Log removed
      throw StateError('Invalid record passed to ModuleInactiveCache.addRecord. Missing key: question_id');
    }
    final String questionId = record['question_id'] as String;
    // REMOVED: moduleName is NOT expected in the input record
    // final String moduleName = record['module_name'] as String;

    // Fetch moduleName from DB
    Database? db;
    String moduleName;
    
    // Acquire DB access (Fail Fast if not acquired)
    int retries = 0;
    const maxRetries = 5;
    while (db == null && retries < maxRetries) {
      db = await _dbMonitor.requestDatabaseAccess();
      if (db == null) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
      }
    }
    if (db == null) {
      QuizzerLogger.logError('ModuleInactiveCache.addRecord: Failed to acquire DB lock for $questionId after $maxRetries retries.');
      throw StateError('Failed to acquire DB lock in ModuleInactiveCache.addRecord for $questionId');
    }

    // Get module name - let it fail fast if questionId not found
    moduleName = await getModuleNameForQuestionId(questionId, db);

    // Release DB lock AFTER successful DB operations
    _dbMonitor.releaseDatabaseAccess();
    
    // Now add the record under the fetched moduleName
    await _lock.synchronized(() {
      _cache.putIfAbsent(moduleName, () => []);
      _cache[moduleName]!.add(record);
    });
  }

  // --- Check if Entire Cache is Empty ---
  /// Checks if the cache is currently empty across all modules.
  Future<bool> isCacheEmpty() async {
    return await _lock.synchronized(() {
      return _cache.isEmpty;
    });
  }

  // --- Check if Specific Module is Empty ---
  /// Checks if the cache for a specific module is empty.
  /// Returns true if the module name is not found or if its list is empty.
  Future<bool> isModuleEmpty(String moduleName) async {
    return await _lock.synchronized(() {
      // Check if the module exists and if its list is empty
      final bool moduleExists = _cache.containsKey(moduleName);
      if (!moduleExists) {
        return true; // Module not found, so it's empty
      }
      // Module exists, check if its list is empty
      return _cache[moduleName]!.isEmpty;
    });
  }

  // --- Get Total Record Count ---
  /// Returns the total number of records across all modules in the cache.
  /// Intended for debugging and monitoring.
  Future<int> peekTotalRecordCount() async {
    return await _lock.synchronized(() {
      int totalCount = 0;
      for (final recordList in _cache.values) {
        totalCount += recordList.length;
      }
      return totalCount;
    });
  }

  // --- Get and Remove One Record From Module (FIFO) ---
  /// Retrieves and removes the oldest record added for a specific module.
  /// Returns an empty Map `{}` if the module is not found or is empty.
  Future<Map<String, dynamic>> getAndRemoveOneRecordFromModule(String moduleName) async {
    return await _lock.synchronized(() {
      // Check if the module exists and has records
      if (_cache.containsKey(moduleName) && _cache[moduleName]!.isNotEmpty) {
        // Remove and return the first (oldest) record from the list
        final record = _cache[moduleName]!.removeAt(0);
        // Optional: Clean up the map entry if the list becomes empty
        if (_cache[moduleName]!.isEmpty) {
           _cache.remove(moduleName);
        }
        return record;
      } else {
        // Module not found or is empty
        return <String, dynamic>{};
      }
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
}
