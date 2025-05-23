import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/09_data_caches/eligible_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/unprocessed_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/answer_history_cache.dart'; // Needed for check
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';     // Needed for userId
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart'; // Needed for DB access
import 'package:quizzer/backend_systems/06_question_queue_server/circulation_worker.dart'; // Import CirculationWorker
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart'; // Import SwitchBoard
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Needed for Database type
import 'due_date_worker.dart'; // ADDED: Import DueDateWorker
// Table function imports
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart' show getModuleNameForQuestionId;
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart' as user_profile_table;
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart'; // Correct import for editUserQuestionAnswerPair
import 'package:quizzer/backend_systems/09_data_caches/past_due_cache.dart'; // Added

/// Checks if a given user question record is eligible to be shown.
Future<bool> isUserRecordEligible(Map<String, dynamic> record, dynamic db) async {
  SessionManager sessionManager = getSessionManager();
  final AnswerHistoryCache historyCache = AnswerHistoryCache();
  assert(sessionManager.userId != null, 'Eligibility check requires a logged-in user ID.');
  final userId = sessionManager.userId!;
  final questionId = record['question_id'] as String;

  if (await historyCache.isInRecentHistory(questionId)) return false;

  final moduleName = await getModuleNameForQuestionId(questionId, db);
  final Map<String, bool> activationStatusField = await user_profile_table.getModuleActivationStatus(userId, db);
  final isModuleActive = activationStatusField[moduleName] ?? false;

  final nextRevisionDue = DateTime.parse(record['next_revision_due'] as String);
  final isDueForRevision = nextRevisionDue.isBefore(DateTime.now());
  final isInCirculation = (record['in_circulation'] as int? ?? 0) == 1;

  return isDueForRevision && isInCirculation && isModuleActive;
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
  bool _isInitialLoop = true; // Flag for initial loop

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
    if (_isRunning) {
      // QuizzerLogger.logWarning('EligibilityCheckWorker is already running.');
      return;
    }
    _isRunning = true;
    _isInitialLoop = true; // Reset flag on start
    _stopCompleter = Completer<void>();
    // QuizzerLogger.logMessage('EligibilityCheckWorker started.');
    // Run the loop asynchronously
    _runLoop();
  }

  /// Stops the worker loop.
  /// Returns a Future that completes when the loop has fully stopped.
  Future<void> stop() async {
    if (!_isRunning) {
      // QuizzerLogger.logWarning('EligibilityCheckWorker is not running.');
      return Future.value();
    }
    // QuizzerLogger.logMessage('EligibilityCheckWorker stopping...');
    _isRunning = false;
    // Wait for the current loop iteration to finish
    // QuizzerLogger.logMessage('EligibilityCheckWorker stopped.');
  }

  /// Chooses between initial and subsequent loop logic.
  Future<void> _runLoop() async {
     while (_isRunning) {
       if (_isInitialLoop) {
         await _performInitialLoop();
         _isInitialLoop = false; // Ensure initial loop runs only once per start()
       } else {
         await _performSubsequentLoop();
       }
     }
     _stopCompleter?.complete();
     // QuizzerLogger.logMessage('EligibilityCheckWorker loop finished.');
  }

  /// Processes all records from input caches during the first run and starts CirculationWorker.
  Future<void> _performInitialLoop() async {
     QuizzerLogger.logMessage('EligibilityCheckWorker: Starting initial loop...');
     final Set<String> processedInCycle = {}; // Track IDs processed during initial loop

     QuizzerLogger.logMessage('Initial Loop: Processing PastDueCache...');
     Map<String, dynamic> record;
     do {
       if (!_isRunning) break;
       record = await _pastDueCache.getAndRemoveRandomRecord();
       if (record.isNotEmpty) {
         await _processSingleRecord(record, processedInCycle);
       }
     } while (record.isNotEmpty && _isRunning);

     QuizzerLogger.logSuccess('Initial Loop: Finished processing initial records from PastDueCache.');

     if (!_isRunning) return; // Check if stopped during initial processing

     // --- Start Circulation Worker ---
     QuizzerLogger.logMessage('EligibilityCheckWorker: Starting Circulation Worker...');
     final circulationWorker = CirculationWorker(); // Get singleton instance
     circulationWorker.start(); // Start the next worker

     // --- Start Due Date Worker (ADDED) ---
     QuizzerLogger.logMessage('EligibilityCheckWorker: Starting Due Date Worker...');
     final dueDateWorker = DueDateWorker(); // Get singleton instance
     dueDateWorker.start();
     // --------------------------------

     QuizzerLogger.logSuccess('EligibilityCheckWorker: Initial loop completed and Circulation/DueDate Workers started.'); // Updated log
  }

  /// Processes records from input caches sequentially, sleeping if caches are empty.
  Future<void> _performSubsequentLoop() async {
    if (!_isRunning) return;

    // Check if the primary input cache is empty (CHANGED)
    if (await _pastDueCache.isEmpty()) {
      // If empty, wait for a notification that a record was added (CHANGED)
      QuizzerLogger.logMessage('EligibilityCheckWorker: PastDueCache empty, waiting for new records...');
      
      // Await the stream notification. This will Fail Fast on any stream error. (CHANGED)
      await _switchBoard.onPastDueCacheAdded.first;
      
      QuizzerLogger.logMessage('EligibilityCheckWorker: Woke up by PastDueCache notification.');
      // Loop will continue and re-evaluate isEmpty()

    } else {
      // If not empty, get and process one record from PastDueCache (CHANGED)
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
  }

  /// Helper to process a single record (checks eligibility and routes).
  Future<void> _processSingleRecord(Map<String, dynamic> record, Set<String> processedInCycle) async {
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

    // Get database access
    final DatabaseMonitor dbMonitor = getDatabaseMonitor();
    final db = (await dbMonitor.requestDatabaseAccess())!;

    // Perform the actual eligibility check (this function no longer writes to DB or modifies record)
    bool isEligible = await isUserRecordEligible(record, db);

    // Ensure the record is mutable by creating a copy, then update its is_eligible field.
    final Map<String, dynamic> mutableRecord = Map<String, dynamic>.from(record);
    mutableRecord['is_eligible'] = isEligible ? 1 : 0;

    // Persist the is_eligible status to the database, without triggering outbound sync from this specific update.
    await setEligibilityStatus(
      mutableRecord['user_uuid'] as String,
      mutableRecord['question_id'] as String,
      isEligible,
      db,
    );
    dbMonitor.releaseDatabaseAccess();

    if (isEligible) {
       await _eligibleCache.addRecord(mutableRecord); // Use mutableRecord
    } else {
       // Check if the reason for ineligibility was recent history
       bool inRecentHistory = await _historyCache.isInRecentHistory(mutableRecord['question_id'] as String); // Use mutableRecord
       if (inRecentHistory) {
          QuizzerLogger.logMessage('Eligibility Check: ${mutableRecord['question_id']} is NOT eligible (in recent history). Waiting 1s before reprocessing.');
          await Future.delayed(const Duration(seconds: 1));
          if (!_isRunning) return; // Check if stopped during wait
          await _unprocessedCache.addRecord(mutableRecord); // Use mutableRecord
       } else {
          // Ineligible for other reasons (not due, inactive, etc.) - add back immediately
          QuizzerLogger.logMessage('Eligibility Check: ${mutableRecord['question_id']} is NOT eligible (other reason), adding to unprocessed immediately.');
          await _unprocessedCache.addRecord(mutableRecord); // Use mutableRecord
       }
    }
  }
}
