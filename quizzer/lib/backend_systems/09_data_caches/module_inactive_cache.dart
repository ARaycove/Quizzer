import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_cache_signals.dart'; // Import cache signals
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Assuming logger might be needed
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart' show getModuleNameForQuestionId; // Function to get module name
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart'; // For updateCacheLocation
import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // For user ID

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
  // Make SessionManager reference lazy to avoid circular dependency
  SessionManager get _sessionManager => getSessionManager();

  // --- Add Record (with duplicate check per module) ---

  /// Adds a single module-inactive question record to the cache under its module name,
  /// only if a record with the same question_id does not already exist *for that module*.
  /// Ensures thread safety using a lock.
  /// If moduleName is provided, it will be used instead of fetching from database.
  Future<void> addRecord(Map<String, dynamic> record, {bool updateDatabaseLocation = true, String? moduleName}) async {
    try {
      QuizzerLogger.logMessage('Entering ModuleInactiveCache addRecord()...');
      // Basic validation: Ensure record has question_id
      if (!record.containsKey('question_id')) {
        QuizzerLogger.logWarning('Invalid record passed to ModuleInactiveCache.addRecord. Missing key: question_id');
        throw StateError('Invalid record passed to ModuleInactiveCache.addRecord. Missing key: question_id');
      }
      final String questionId = record['question_id'] as String;
      
      String finalModuleName;
      
      // If moduleName is provided, use it; otherwise fetch from DB
      if (moduleName != null) {
        finalModuleName = moduleName;
      } else {
        // Table function handles its own database access
        finalModuleName = await getModuleNameForQuestionId(questionId);
      }
      
      // Now add the record under the fetched moduleName
      await _lock.synchronized(() {
        _cache.putIfAbsent(finalModuleName, () => []);
        _cache[finalModuleName]!.add(record);
        // Signal that a record was added
        signalModuleInactiveAdded();
      });

      // Update cache location in database after successful addition (only if requested)
      if (updateDatabaseLocation) {
        await _updateCacheLocationInDatabase(questionId, 4);
      }
    } catch (e) {
      QuizzerLogger.logError('Error in ModuleInactiveCache addRecord - $e');
      rethrow;
    }
  }

  // --- Check if Entire Cache is Empty ---
  /// Checks if the cache is currently empty across all modules.
  Future<bool> isCacheEmpty() async {
    try {
      QuizzerLogger.logMessage('Entering ModuleInactiveCache isCacheEmpty()...');
      return await _lock.synchronized(() {
        return _cache.isEmpty;
      });
    } catch (e) {
      QuizzerLogger.logError('Error in ModuleInactiveCache isCacheEmpty - $e');
      rethrow;
    }
  }

  // --- Check if Specific Module is Empty ---
  /// Checks if the cache for a specific module is empty.
  /// Returns true if the module name is not found or if its list is empty.
  Future<bool> isModuleEmpty(String moduleName) async {
    try {
      QuizzerLogger.logMessage('Entering ModuleInactiveCache isModuleEmpty()...');
      return await _lock.synchronized(() {
        // Check if the module exists and if its list is empty
        final bool moduleExists = _cache.containsKey(moduleName);
        if (!moduleExists) {
          return true; // Module not found, so it's empty
        }
        // Module exists, check if its list is empty
        return _cache[moduleName]!.isEmpty;
      });
    } catch (e) {
      QuizzerLogger.logError('Error in ModuleInactiveCache isModuleEmpty - $e');
      rethrow;
    }
  }

  // --- Get Total Record Count ---
  /// Returns the total number of records across all modules in the cache.
  /// Intended for debugging and monitoring.
  Future<int> peekTotalRecordCount() async {
    try {
      QuizzerLogger.logMessage('Entering ModuleInactiveCache peekTotalRecordCount()...');
      return await _lock.synchronized(() {
        int totalCount = 0;
        for (final recordList in _cache.values) {
          totalCount += recordList.length;
        }
        return totalCount;
      });
    } catch (e) {
      QuizzerLogger.logError('Error in ModuleInactiveCache peekTotalRecordCount - $e');
      rethrow;
    }
  }

  // --- Get and Remove One Record From Module (FIFO) ---
  /// Retrieves and removes the oldest record added for a specific module.
  /// Returns an empty Map `{}` if the module is not found or is empty.
  Future<Map<String, dynamic>> getAndRemoveOneRecordFromModule(String moduleName) async {
    try {
      QuizzerLogger.logMessage('Entering ModuleInactiveCache getAndRemoveOneRecordFromModule()...');
      return await _lock.synchronized(() {
        // Check if the module exists and has records
        if (_cache.containsKey(moduleName) && _cache[moduleName]!.isNotEmpty) {
          // Remove and return the first (oldest) record from the list
          final record = _cache[moduleName]!.removeAt(0);
          // Signal that a record was removed
          signalModuleInactiveRemoved();
          // Optional: Clean up the map entry if the list becomes empty
          if (_cache[moduleName]!.isEmpty) {
             _cache.remove(moduleName);
          }
          return record;
        } else {
          // Module not found or is empty
          QuizzerLogger.logWarning('ModuleInactiveCache: Module not found or empty for removal (Module: $moduleName)');
          return <String, dynamic>{};
        }
      });
    } catch (e) {
      QuizzerLogger.logError('Error in ModuleInactiveCache getAndRemoveOneRecordFromModule - $e');
      rethrow;
    }
  }

  Future<void> clear() async {
    try {
      QuizzerLogger.logMessage('Entering ModuleInactiveCache clear()...');
      await _lock.synchronized(() {
        if (_cache.isNotEmpty) {
          // Signal that records were removed (single signal for clear operation)
          signalModuleInactiveRemoved();
          _cache.clear();
          QuizzerLogger.logMessage('ModuleInactiveCache cleared.');
        }
      });
    } catch (e) {
      QuizzerLogger.logError('Error in ModuleInactiveCache clear - $e');
      rethrow;
    }
  }

  // --- Helper function to update cache location in database ---
  Future<void> _updateCacheLocationInDatabase(String questionId, int cacheLocation) async {
    try {
      QuizzerLogger.logMessage('Entering ModuleInactiveCache _updateCacheLocationInDatabase()...');
      final userId = _sessionManager.userId;
      if (userId == null) {
        throw StateError('ModuleInactiveCache: Cannot update cache location - no user ID available');
      }

      // Table function handles its own database access
      await updateCacheLocation(userId, questionId, cacheLocation);
    } catch (e) {
      QuizzerLogger.logError('Error in ModuleInactiveCache _updateCacheLocationInDatabase - $e');
      rethrow;
    }
  }
}
