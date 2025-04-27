import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/09_data_caches/due_date_within_24hrs_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/eligible_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/unprocessed_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/answer_history_cache.dart'; // Needed for check
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';     // Needed for userId
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart'; // Needed for DB access
import 'package:quizzer/backend_systems/06_question_queue_server/circulation_worker.dart'; // Import CirculationWorker
import 'package:quizzer/backend_systems/06_question_queue_server/switch_board.dart'; // Import SwitchBoard
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Needed for Database type
// Table function imports
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart' show getModuleNameForQuestionId;
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile_table.dart' as user_profile_table;

/// Checks if a given user question record is eligible to be shown.
Future<bool> isUserRecordEligible(Map<String, dynamic> record) async {
        SessionManager          sessionManager  = getSessionManager();
  final AnswerHistoryCache      historyCache   = AnswerHistoryCache();
  final DatabaseMonitor         dbMonitor = getDatabaseMonitor(); 
  // Fail fast if userId isn't available in session (shouldn't happen if worker runs after login)
  assert(sessionManager.userId != null, 'Eligibility check requires a logged-in user ID.');
  final userId = sessionManager.userId!;
  final questionId = record['question_id'] as String;

    // 1. Check if in recent answer history
  bool inRecentHistory = await historyCache.isInRecentHistory(questionId);
  if (inRecentHistory) {
    // QuizzerLogger.logMessage('$questionId ineligible: In recent history.'); // Optional log
    return false;
  }
  // --- End Cache Checks ---


  // --- Proceed with Database Checks (Only for data NOT in the record) ---
  Database? db;
  String moduleName;
  bool isModuleActive;

  // Acquire DB lock
  int retries = 0;
  const maxRetries = 5;
  while (db == null && retries < maxRetries) {
    db = await dbMonitor.requestDatabaseAccess();
    if (db == null) {
      await Future.delayed(const Duration(milliseconds: 100));
      retries++;
    }
  }
  if (db == null) {
      QuizzerLogger.logError('EligibilityWorker: Failed to acquire DB lock for eligibility check of $questionId.');
      throw StateError('Failed to acquire DB lock in EligibilityWorker'); // Fail Fast
  }


  // Fetch module name and activation status from DB
  // final userQuestionAnswerPair = await getUserQuestionAnswerPairById(userId, questionId, db!); // REMOVED - Data is in `record`
  moduleName = await getModuleNameForQuestionId(questionId, db);
  final Map<String, bool> activationStatusField = await user_profile_table.getModuleActivationStatus(userId, db);
  isModuleActive = activationStatusField[moduleName] ?? false;

  // Release DB lock AFTER DB operations are done
  dbMonitor.releaseDatabaseAccess();
  // --- End Database Checks ---

  // --- Use data from the input record ---
  // 3. Check if due date is in the past (using input record)
  final nextRevisionDueString = record['next_revision_due'] as String;
  final nextRevisionDue = DateTime.parse(nextRevisionDueString);
  final bool isDueForRevision = nextRevisionDue.isBefore(DateTime.now());

  // 4. Check if in circulation (using input record)
  final inCirculationValue = record['in_circulation'] as int? ?? 0;
  final bool isInCirculation = inCirculationValue == 1;
  // -------------------------------------

  // Final eligibility check: All conditions must be true
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
  final DueDateWithin24hrsCache _dueDateWithinCache = DueDateWithin24hrsCache();
  final EligibleQuestionsCache  _eligibleCache = EligibleQuestionsCache();
  final UnprocessedCache        _unprocessedCache = UnprocessedCache();
  final AnswerHistoryCache      _historyCache = AnswerHistoryCache(); // For check #1
  final DatabaseMonitor         _dbMonitor = getDatabaseMonitor();       // For DB access
  final SessionManager          _sessionManager = SessionManager();       // For userId
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
    await _stopCompleter?.future;
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

     // Exhaust DueDateWithin24hrsCache
     QuizzerLogger.logMessage('Initial Loop: Processing DueDateWithin24hrsCache...');
     Map<String, dynamic> record;
     do {
       if (!_isRunning) break;
       record = await _dueDateWithinCache.getAndRemoveRecord();
       if (record.isNotEmpty) {
         await _processSingleRecord(record, processedInCycle);
       }
     } while (record.isNotEmpty && _isRunning);

     QuizzerLogger.logSuccess('Initial Loop: Finished processing initial records.');

     if (!_isRunning) return; // Check if stopped during initial processing

     // --- Start Circulation Worker ---
     QuizzerLogger.logMessage('EligibilityCheckWorker: Starting Circulation Worker...');
     final circulationWorker = CirculationWorker(); // Get singleton instance
     circulationWorker.start(); // Start the next worker

     QuizzerLogger.logSuccess('EligibilityCheckWorker: Initial loop completed and Circulation Worker started.');
  }

  /// Processes records from input caches sequentially, sleeping if caches are empty.
  Future<void> _performSubsequentLoop() async {
    if (!_isRunning) return;

    // Check if the primary input cache is empty
    if (await _dueDateWithinCache.isEmpty()) {
      // If empty, wait for a notification that a record was added
      // QuizzerLogger.logMessage('EligibilityCheckWorker: DueDateWithin24hrsCache empty, waiting for new records...');
      
      // Await the stream notification. This will Fail Fast on any stream error.
      await _switchBoard.onDueDateWithin24hrsAdded.first;
      
      // QuizzerLogger.logMessage('EligibilityCheckWorker: Woke up by DueDateWithin24hrsCache notification.');
      // Loop will continue and re-evaluate isEmpty()

    } else {
      // If not empty, get and process one record from DueDateWithin24hrsCache
      final record = await _dueDateWithinCache.getAndRemoveRecord();
      if (record.isNotEmpty) {
        // QuizzerLogger.logMessage('EligibilityCheckWorker: Found record in DueDateWithin24hrsCache, processing...');
        await _processSingleRecord(record, {}); // Pass empty set for cycle tracking

        // Add a check AFTER processing attempt: if worker was stopped DURING processing, put record back.
        if (!_isRunning) {
           QuizzerLogger.logWarning('EligibilityCheckWorker: Stopped during processing record ${record['question_id']}. Putting back in UnprocessedCache.');
           await _unprocessedCache.addRecord(record); // Add it back to Unprocessed
        }
      } 
      // else { // Record was empty, likely race condition
      //   QuizzerLogger.logWarning('EligibilityCheckWorker: DueDateWithin24hrsCache not empty but getRecord failed?');
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

    // Perform the actual eligibility check
    bool isEligible = await isUserRecordEligible(record);

    if (isEligible) {
       // QuizzerLogger.logMessage('Eligibility Check: $questionId is eligible.');
       await _eligibleCache.addRecord(record);
    } else {
       // QuizzerLogger.logMessage('Eligibility Check: $questionId is NOT eligible, adding to unprocessed.');
       await _unprocessedCache.addRecord(record);
    }
  }
}
