import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart' show getModuleNameForQuestionId;
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart' as user_profile_table;
import 'package:quizzer/backend_systems/09_data_caches/non_circulating_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/due_date_beyond_24hrs_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/due_date_within_24hrs_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/circulating_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/module_inactive_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/past_due_cache.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/09_data_caches/unprocessed_cache.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart'; // Import SwitchBoard for signals
import 'package:quizzer/backend_systems/10_switch_board/sb_question_worker_signals.dart'; // Import worker signals
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'dart:async';
// ==========================================
/// Worker responsible for pre-processing user question records.
/// Fetches records from the database (on initial run) or UnprocessedCache,
/// validates them, and routes them to appropriate downstream caches.
class PreProcessWorker {
  // --- Singleton Setup ---
  static final PreProcessWorker _instance = PreProcessWorker._internal();
  factory PreProcessWorker() => _instance;
  PreProcessWorker._internal();

  // --- State ---
  bool _isRunning = false;

  // --- Dependencies ---
  final UnprocessedCache              _unprocessedCache     = UnprocessedCache();
  final NonCirculatingQuestionsCache  _nonCirculatingCache  = NonCirculatingQuestionsCache();
  final ModuleInactiveCache           _moduleInactiveCache  = ModuleInactiveCache();
  final DueDateBeyond24hrsCache       _dueDateBeyondCache   = DueDateBeyond24hrsCache();
  final DueDateWithin24hrsCache       _dueDateWithinCache   = DueDateWithin24hrsCache();
  final PastDueCache                  _pastDueCache         = PastDueCache();
  final CirculatingQuestionsCache     _circulatingCache     = CirculatingQuestionsCache();
  final SessionManager                _sessionManager       = getSessionManager(); // Get SessionManager instance

  // --- Control Methods ---
  /// Starts the worker loop.
  /// Fetches the current user ID from the SessionManager.
  void start() {
    try {
      QuizzerLogger.logMessage('Entering PreProcessWorker start()...');
      if (_isRunning) {
        QuizzerLogger.logWarning('PreProcessWorker already running.');
        return;
      }

      QuizzerLogger.logMessage('Starting PreProcessWorker for user: ${_sessionManager.userId}...');
      assert(_sessionManager.userId != null);

      _isRunning = true;
      _runLoop();
    } catch (e) {
      QuizzerLogger.logError('Error starting PreProcessWorker - $e');
      rethrow;
    }
  }

  /// Stops the worker loop.
  Future<void> stop() async {
    try {
      QuizzerLogger.logMessage('Entering PreProcessWorker stop()...');
      if (!_isRunning) {
        QuizzerLogger.logWarning('PreProcessWorker already stopped.');
        return;
      }
      QuizzerLogger.logMessage('Stopping PreProcessWorker...');
      _isRunning = false;
    } catch (e) {
      QuizzerLogger.logError('Error stopping PreProcessWorker - $e');
      rethrow;
    }
  }

  // --- Main Loop ---
  /// Main worker loop that processes all records in UnprocessedCache until empty,
  /// then waits for new records to be added.
  Future<void> _runLoop() async {
    try {
      QuizzerLogger.logMessage('Entering PreProcessWorker _runLoop()...');
      final SwitchBoard switchBoard = SwitchBoard();
      
      while (_isRunning) {
        // Process all records in the cache until it's empty
        Map<String, dynamic> recordToProcess;
        do {
          if (!_isRunning) break;
          recordToProcess = await _unprocessedCache.getAndRemoveOldestRecord();
          if (recordToProcess.isNotEmpty) {
            await _processRecord(recordToProcess);
          }
        } while (recordToProcess.isNotEmpty);
        
        // Cache is now empty, signal cycle complete and wait for new records
        if (_isRunning) {
          QuizzerLogger.logMessage('PreProcessWorker: UnprocessedCache empty, signaling cycle complete...');
          signalPreProcessWorkerCycleComplete();
          QuizzerLogger.logMessage('PreProcessWorker: Waiting for new records...');
          await switchBoard.onUnprocessedAdded.first;
          QuizzerLogger.logMessage('PreProcessWorker: Woke up by UnprocessedCache signal.');
        }
      }
      QuizzerLogger.logMessage('PreProcessWorker loop finished.');
    } catch (e) {
      QuizzerLogger.logError('Error in PreProcessWorker _runLoop - $e');
      rethrow;
    }
  }

  // --- Record Processing Logic ---
  Future<String> _processRecord(Map<String, dynamic> record) async {
    try {
      QuizzerLogger.logMessage('Entering PreProcessWorker _processRecord()...');
      
      // Check if stopped right at the beginning
      if (!_isRunning) {
        await _unprocessedCache.addRecord(record);
        return 'UnprocessedCache';
      }

      assert(_sessionManager.userId != null, "Current User ID cannot be null for processing.");
      String questionId = record['question_id'];

      // Critical field assertions
      assert(record.containsKey('in_circulation'),    'Record missing in_circulation: $record');
      assert(record.containsKey('next_revision_due'), 'Record missing next_revision_due: $record');

      // --- Get Dependencies (Table functions handle their own database access) ---
      String? moduleName;
      bool isModuleActive = false;

      // Table functions handle their own database access
      moduleName = await getModuleNameForQuestionId(questionId);
      final Map<String, bool> activationStatus = await user_profile_table.getModuleActivationStatus(_sessionManager.userId!);
      isModuleActive = activationStatus[moduleName] ?? false;

      // Check if stopped AFTER DB operations but BEFORE routing
      if (!_isRunning) {
        await _unprocessedCache.addRecord(record);
        return 'UnprocessedCache';
      }

      // --- Routing Logic ---
      final bool     inCirculation          = (record['in_circulation'] as int? ?? 0) == 1;
      final String   dueDateString          = record['next_revision_due'] as String;
      // Let potential FormatException propagate (Fail Fast)
      final DateTime parsedDueDate          = DateTime.parse(dueDateString);
      final DateTime twentyFourHoursFromNow = DateTime.now().add(const Duration(hours: 24));

      // Determine destination and add, checking for stop signal BEFORE the await
      Future<void> routeToAdd;
      String destinationCacheName = "Unknown"; // For logging

      if (!isModuleActive) {
        destinationCacheName = "ModuleInactiveCache";
        routeToAdd = _moduleInactiveCache.addRecord(record);
      } else if (!inCirculation) {
        destinationCacheName = "NonCirculatingQuestionsCache";
        routeToAdd = _nonCirculatingCache.addRecord(record);
      } else {
        // Add ID first
        await _circulatingCache.addQuestionId(questionId);
        // Check stop signal again *after* adding ID but *before* adding full record
        if (!_isRunning) {
            await _unprocessedCache.addRecord(record);
            return 'UnprocessedCache';
        }
        // Now determine final destination (updated logic)
        final now = DateTime.now(); // Need current time for past due check
        if (parsedDueDate.isBefore(now)) { // Check if past due first
          destinationCacheName = "PastDueCache";
          routeToAdd = _pastDueCache.addRecord(record);
        } else if (parsedDueDate.isBefore(twentyFourHoursFromNow)) { // Then check if within 24hrs
          destinationCacheName = "DueDateWithin24hrsCache";
          routeToAdd = _dueDateWithinCache.addRecord(record);
        } else { // Otherwise, it must be beyond 24hrs
          destinationCacheName = "DueDateBeyond24hrsCache";
          routeToAdd = _dueDateBeyondCache.addRecord(record);
        }
      }

      // Check if stopped right before the final add operation
      if (!_isRunning) {
          await _unprocessedCache.addRecord(record);
          return 'UnprocessedCache';
      }

      // Log the routing decision just before the operation
      QuizzerLogger.logMessage('[PreProcessWorker] Routing $questionId to $destinationCacheName.');
      
      // Perform the actual add to the destination cache
      await routeToAdd; 
      return destinationCacheName;
    } catch (e) {
      QuizzerLogger.logError('Error in PreProcessWorker _processRecord - $e');
      rethrow;
    }
  }


}