import 'dart:async';
import 'package:quizzer/backend_systems/09_data_caches/module_inactive_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/unprocessed_cache.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'switch_board.dart'; // Import SwitchBoard

// ==========================================

/// Worker responsible for handling module deactivation events.
/// Moves records from the ModuleInactiveCache back to the UnprocessedCache
/// when a module is deactivated.
class InactiveModuleWorker {
  // --- Singleton Setup ---
  static final InactiveModuleWorker _instance = InactiveModuleWorker._internal();
  factory InactiveModuleWorker() => _instance;
  InactiveModuleWorker._internal();

  // --- State ---
  bool _isRunning = false;

  // --- Dependencies ---
  final SwitchBoard           _switchBoard         = SwitchBoard();
  final ModuleInactiveCache   _moduleInactiveCache = ModuleInactiveCache();
  final UnprocessedCache      _unprocessedCache    = UnprocessedCache();

  // --- Control Methods ---
  /// Starts the worker loop.
  void start() {
    if (_isRunning) {
      QuizzerLogger.logWarning('InactiveModuleWorker already running.');
      return;
    }
    QuizzerLogger.logMessage('Starting InactiveModuleWorker...');
    _isRunning = true;
    _runLoop();
  }

  /// Stops the worker loop.
  void stop() {
    if (!_isRunning) {
      QuizzerLogger.logWarning('InactiveModuleWorker already stopped.');
      return;
    }
    QuizzerLogger.logMessage('Stopping InactiveModuleWorker...');
    _isRunning = false;
  }

  // --- Main Loop --- 
  /// Continuously listens for module deactivation signals and processes them.
  Future<void> _runLoop() async {
    while (_isRunning) {
      await _performLoopLogic();
    }
    QuizzerLogger.logMessage('InactiveModuleWorker loop finished.');
  }

  // --- Loop Logic --- 
  /// Waits for a module deactivation signal, then moves relevant records.
  Future<void> _performLoopLogic() async {
    QuizzerLogger.logMessage('InactiveModuleWorker: Waiting for module deactivation signal...');
    // Wait for the next deactivation signal from the SwitchBoard
    final String activatedModuleName = await _switchBoard.onModuleActivated.first;

    if (!_isRunning) return; // Check if stopped while waiting

    QuizzerLogger.logMessage('InactiveModuleWorker: Received signal for module: $activatedModuleName. Processing...');

    final Set<String> processedIdsInCycle = {}; // Track IDs processed in this cycle
    Map<String, dynamic> recordToMove;

    do {
      if (!_isRunning) break; // Check if stopped during processing

      // Get and remove one record for the deactivated module
      recordToMove = await _moduleInactiveCache.getAndRemoveOneRecordFromModule(activatedModuleName);

      if (recordToMove.isNotEmpty) {
        final String questionId = recordToMove['question_id'] as String;

        // Check if we already processed this ID *in this specific deactivation cycle*
        if (processedIdsInCycle.contains(questionId)) {
          QuizzerLogger.logMessage('InactiveModuleWorker: Skipping re-added record $questionId for module $activatedModuleName in this cycle.');
          continue; // Skip this record and get the next one
        }

        // Mark as processed for this cycle and move to UnprocessedCache
        processedIdsInCycle.add(questionId);
        // QuizzerLogger.logMessage('InactiveModuleWorker: Moving $questionId from module $deactivatedModuleName to UnprocessedCache.');
        await _unprocessedCache.addRecord(recordToMove);
      } 
      // else: No more records for this module in the cache

    } while (recordToMove.isNotEmpty && _isRunning);

    if (_isRunning) {
      QuizzerLogger.logSuccess('InactiveModuleWorker: Finished processing deactivated module: $activatedModuleName.');
    }
  }
}
