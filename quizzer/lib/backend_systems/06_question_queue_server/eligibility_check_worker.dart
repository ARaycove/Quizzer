import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/09_data_caches/eligible_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/unprocessed_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/answer_history_cache.dart'; // Needed for check
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';     // Needed for userId
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart'; // Import SwitchBoard
import 'package:quizzer/backend_systems/10_switch_board/sb_question_worker_signals.dart'; // Import worker signals
// Table function imports
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart' show getModuleNameForQuestionId;
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart' as user_profile_table;
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart'; // Correct import for editUserQuestionAnswerPair
import 'package:quizzer/backend_systems/09_data_caches/past_due_cache.dart'; // Added

/// Checks if a given user question record is eligible to be shown.
Future<bool> isUserRecordEligible(Map<String, dynamic> record) async {
  try {
    QuizzerLogger.logMessage('Entering isUserRecordEligible()...');
    SessionManager sessionManager = getSessionManager();
    final AnswerHistoryCache historyCache = AnswerHistoryCache();
    assert(sessionManager.userId != null, 'Eligibility check requires a logged-in user ID.');
    final userId = sessionManager.userId!;
    final questionId = record['question_id'] as String;

    if (await historyCache.isInRecentHistory(questionId)) return false;

    // Table functions handle their own database access
    final moduleName = await getModuleNameForQuestionId(questionId);
    final Map<String, bool> activationStatusField = await user_profile_table.getModuleActivationStatus(userId);
    final isModuleActive = activationStatusField[moduleName] ?? false;

    final nextRevisionDue = DateTime.parse(record['next_revision_due'] as String);
    final isDueForRevision = nextRevisionDue.isBefore(DateTime.now());
    final isInCirculation = (record['in_circulation'] as int? ?? 0) == 1;

    return isDueForRevision && isInCirculation && isModuleActive;
  } catch (e) {
    QuizzerLogger.logError('Error in isUserRecordEligible - $e');
    rethrow;
  }
}

// ==========================================
// Eligibility Check Worker
// ==========================================

class EligibilityCheckWorker {
  // Singleton pattern setup
  static final EligibilityCheckWorker _instance = EligibilityCheckWorker._internal();
  factory EligibilityCheckWorker() => _instance;
  EligibilityCheckWorker._internal();

  // Worker state
  bool _isRunning = false;
  Completer<void>? _stopCompleter;
  
  // Generic failure counter for consecutive "ineligible due to recent history" events
  int _consecutiveHistoryFailures = 0; // Track consecutive failures due to recent history
  static const int maxConsecutiveFailures = 3; // Maximum consecutive failures before stopping

  // Cache instances & Managers/Monitors needed
  final PastDueCache            _pastDueCache = PastDueCache(); // ADDED
  final EligibleQuestionsCache  _eligibleCache = EligibleQuestionsCache();
  final UnprocessedCache        _unprocessedCache = UnprocessedCache();
  final AnswerHistoryCache      _historyCache = AnswerHistoryCache(); // For check #1
  // final DatabaseMonitor         _dbMonitor = getDatabaseMonitor();       // For DB access
  // final SessionManager          _sessionManager = SessionManager();       // For userId
  final SwitchBoard             _switchBoard = SwitchBoard();             // Get SwitchBoard instance

  /// Starts the worker loop.
  /// Does nothing if the worker is already running.
  void start() {
    try {
      QuizzerLogger.logMessage('Entering EligibilityCheckWorker start()...');
      if (_isRunning) {
        QuizzerLogger.logWarning('EligibilityCheckWorker is already running.');
        return;
      }
      _isRunning = true;
      _stopCompleter = Completer<void>();
      QuizzerLogger.logMessage('EligibilityCheckWorker started.');
      // Run the loop asynchronously
      _runLoop();
    } catch (e) {
      QuizzerLogger.logError('Error starting EligibilityCheckWorker - $e');
      rethrow;
    }
  }

  /// Stops the worker loop.
  /// Returns a Future that completes when the loop has fully stopped.
  Future<void> stop() async {
    try {
      QuizzerLogger.logMessage('Entering EligibilityCheckWorker stop()...');
      if (!_isRunning) {
        QuizzerLogger.logWarning('EligibilityCheckWorker is not running.');
        return Future.value();
      }
      QuizzerLogger.logMessage('EligibilityCheckWorker stopping...');
      _isRunning = false;
      // Wait for the current loop iteration to finish
      QuizzerLogger.logMessage('EligibilityCheckWorker stopped.');
    } catch (e) {
      QuizzerLogger.logError('Error stopping EligibilityCheckWorker - $e');
      rethrow;
    }
  }

  /// Main worker loop that processes records from PastDueCache.
  Future<void> _runLoop() async {
    try {
      QuizzerLogger.logMessage('Entering EligibilityCheckWorker _runLoop()...');
      while (_isRunning) {
        await _performLoopLogic();
      }
      _stopCompleter?.complete();
      QuizzerLogger.logMessage('EligibilityCheckWorker loop finished.');
    } catch (e) {
      QuizzerLogger.logError('Error in EligibilityCheckWorker _runLoop - $e');
      rethrow;
    }
  }

  /// Main loop logic that processes records from PastDueCache.
  Future<void> _performLoopLogic() async {
    try {
      QuizzerLogger.logMessage('Entering EligibilityCheckWorker _performLoopLogic()...');
      if (!_isRunning) return;

      // Check if the PastDueCache is empty
      if (await _pastDueCache.isEmpty()) {
        // If empty, wait for a notification that a record was added
        QuizzerLogger.logMessage('EligibilityCheckWorker: PastDueCache empty, waiting for new records...');
        
        // Await the stream notification. This will Fail Fast on any stream error.
        await _switchBoard.onPastDueAdded.first;
        
        QuizzerLogger.logMessage('EligibilityCheckWorker: Woke up by PastDueCache notification.');
        // Loop will continue and re-evaluate isEmpty()
      } else {
        // If not empty, get and process one record from PastDueCache
        final record = await _pastDueCache.getAndRemoveRandomRecord();
        if (record.isNotEmpty) {
          QuizzerLogger.logMessage('EligibilityCheckWorker: Found record in PastDueCache, processing...');
          await _processSingleRecord(record, {}); // Pass empty set for cycle tracking

          // Add a check AFTER processing attempt: if worker was stopped DURING processing, put record back.
          if (!_isRunning) {
             QuizzerLogger.logWarning('EligibilityCheckWorker: Stopped during processing record ${record['question_id']}. Putting back in UnprocessedCache.');
             await _unprocessedCache.addRecord(record); // Add it back to Unprocessed
          }
        } 
        // else { // Record was empty, likely race condition
        //   QuizzerLogger.logWarning('EligibilityCheckWorker: PastDueCache not empty but getRecord failed?');
        // }
      }
      
      // Signal cycle completion
      signalEligibilityCheckWorkerCycleComplete();
    } catch (e) {
      QuizzerLogger.logError('Error in EligibilityCheckWorker _performLoopLogic - $e');
      rethrow;
    }
  }

  /// Helper to process a single record (checks eligibility and routes).
  Future<void> _processSingleRecord(Map<String, dynamic> record, Set<String> processedInCycle) async {
    try {
      QuizzerLogger.logMessage('Entering EligibilityCheckWorker _processSingleRecord()...');
      if (!_isRunning) return;

      // Extract question ID (assuming it exists)
      final questionId = record['question_id'] as String?;
      assert(questionId != null);

      // --- Duplicate Check (Optional for subsequent loops, important for initial) ---
      if (processedInCycle.contains(questionId)) {
         QuizzerLogger.logWarning('Duplicate eligibility check detected in same cycle for QID: $questionId. Record: $record');
         await _unprocessedCache.addRecord(record); // Add back to unprocessed to avoid loss
         return; // Skip further processing of this duplicate in this cycle
      }
      processedInCycle.add(questionId!); // Mark as processed for this cycle/initial run
      // ----------------------

      // Perform the actual eligibility check - table function handles its own database access
      bool isEligible = await isUserRecordEligible(record);

      // Ensure the record is mutable by creating a copy, then update its is_eligible field.
      final Map<String, dynamic> mutableRecord = Map<String, dynamic>.from(record);
      mutableRecord['is_eligible'] = isEligible ? 1 : 0;

      // Persist the is_eligible status to the database - table function handles its own database access
      await setEligibilityStatus(
        mutableRecord['user_uuid'] as String,
        mutableRecord['question_id'] as String,
        isEligible,
      );

      if (isEligible) {
         // Reset consecutive history failures for this question since it's now eligible
         _consecutiveHistoryFailures = 0;
         await _eligibleCache.addRecord(mutableRecord); // Use mutableRecord
      } else {
         // Check if the reason for ineligibility was recent history
         bool inRecentHistory = await _historyCache.isInRecentHistory(mutableRecord['question_id'] as String); // Use mutableRecord
         if (inRecentHistory) {
            // Increment consecutive history failures for this question
            _consecutiveHistoryFailures++;
            final int currentFailures = _consecutiveHistoryFailures;
            
            if (currentFailures >= maxConsecutiveFailures) {
               // Max consecutive failures reached, stop processing and wait for signal
               QuizzerLogger.logMessage('Eligibility Check: ${mutableRecord['question_id']} hit max consecutive failures ($maxConsecutiveFailures) due to recent history. Waiting for new answer signal.');
               await _waitForAnswerHistorySignal();
               // Reset consecutive history failures after waiting
               _consecutiveHistoryFailures = 0;
            } else {
               QuizzerLogger.logMessage('Eligibility Check: ${mutableRecord['question_id']} is NOT eligible (in recent history). Failures $currentFailures/$maxConsecutiveFailures. Waiting 1s before reprocessing.');
               await Future.delayed(const Duration(seconds: 1));
            }
            
            if (!_isRunning) return; // Check if stopped during wait
            await _unprocessedCache.addRecord(mutableRecord); // Use mutableRecord
         } else {
            // Ineligible for other reasons (not due, inactive, etc.) - add back immediately
            // Reset consecutive history failures since it's not due to recent history
            _consecutiveHistoryFailures = 0;
            QuizzerLogger.logMessage('Eligibility Check: ${mutableRecord['question_id']} is NOT eligible (other reason), adding to unprocessed immediately.');
            await _unprocessedCache.addRecord(mutableRecord); // Use mutableRecord
         }
      }
    } catch (e) {
      QuizzerLogger.logError('Error in EligibilityCheckWorker _processSingleRecord - $e');
      rethrow;
    }
  }
  
  /// Waits for a signal from AnswerHistoryCache indicating a new question was answered.
  Future<void> _waitForAnswerHistorySignal() async {
    try {
      QuizzerLogger.logMessage('Entering EligibilityCheckWorker _waitForAnswerHistorySignal()...');
      QuizzerLogger.logMessage('EligibilityCheckWorker: Waiting for AnswerHistory signal...');
      await _switchBoard.onAnswerHistoryAdded.first;
      QuizzerLogger.logMessage('EligibilityCheckWorker: Received AnswerHistory signal, resuming processing.');
    } catch (e) {
      QuizzerLogger.logError('Error in EligibilityCheckWorker _waitForAnswerHistorySignal - $e');
      rethrow;
    }
  }
}
