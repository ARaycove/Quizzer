import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart' show getModuleNameForQuestionId;
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart' as user_q_pairs_table;
import 'package:quizzer/backend_systems/07_user_question_management/user_question_processes.dart' as user_question_processor;
import 'package:quizzer/backend_systems/06_question_queue_server/eligibility_check_worker.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile_table.dart' as user_profile_table;
import 'package:quizzer/backend_systems/04_module_management/module_updates_process.dart' as module_processor;
import 'package:quizzer/backend_systems/09_data_caches/non_circulating_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/due_date_beyond_24hrs_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/due_date_within_24hrs_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/circulating_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/module_inactive_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/past_due_cache.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/09_data_caches/unprocessed_cache.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:async';
import 'inactive_module_worker.dart'; // Import the new worker


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
  bool _isRunning      = false;
  bool _isInitialLoop  = true;

  // --- Dependencies ---
  final UnprocessedCache              _unprocessedCache     = UnprocessedCache();
  final NonCirculatingQuestionsCache  _nonCirculatingCache  = NonCirculatingQuestionsCache();
  final ModuleInactiveCache           _moduleInactiveCache  = ModuleInactiveCache();
  final DueDateBeyond24hrsCache       _dueDateBeyondCache   = DueDateBeyond24hrsCache();
  final DueDateWithin24hrsCache       _dueDateWithinCache   = DueDateWithin24hrsCache();
  final PastDueCache                  _pastDueCache         = PastDueCache();
  final CirculatingQuestionsCache     _circulatingCache     = CirculatingQuestionsCache();
  final DatabaseMonitor               _dbMonitor            = getDatabaseMonitor();
  final SessionManager                _sessionManager       = getSessionManager(); // Get SessionManager instance

  // --- Control Methods ---
  /// Starts the worker loop.
  /// Fetches the current user ID from the SessionManager.
  void start() {
    if (_isRunning) {
      QuizzerLogger.logWarning('PreProcessWorker already running.');
      return;
    }

    QuizzerLogger.logMessage('Starting PreProcessWorker for user: ${_sessionManager.userId}...');
    assert(_sessionManager.userId != null);

    _isRunning      = true;
    _isInitialLoop  = true; // Reset initial loop flag on start
    _runLoop();
  }

  /// Stops the worker loop.
  void stop() {
    if (!_isRunning) {
      QuizzerLogger.logWarning('PreProcessWorker already stopped.');
      return;
    }
    QuizzerLogger.logMessage('Stopping PreProcessWorker...');
    _isRunning = false;
  }

  // --- Main Loop ---
  /// Checks if initial startup loop
  /// Chooses which loop to execute based on whether we are initializing or not
  Future<void> _runLoop() async {
    while (_isRunning) {
      if (_isInitialLoop) {
        await _performInitialLoop();
        _isInitialLoop = false; // Ensure initial loop runs only once per start()
      } else {
        await _performSubsequentLoop();
      }
    }
    QuizzerLogger.logMessage('PreProcessWorker loop finished.');
  }

  // --- Initial Loop Logic ---
  Future<void> _performInitialLoop() async {
    QuizzerLogger.logMessage('PreProcessWorker: Starting initial loop...');
    
    QuizzerLogger.logMessage('Initial Loop: Building/Validating Module Records...');
    // Assume buildModuleRecords handles its own DB access/release or crashes
    await module_processor.buildModuleRecords();
    if (!_isRunning) { _dbMonitor.releaseDatabaseAccess(); return; } // Check running status

    Database? db;
    // --- Database Operations ---
    db = await _getDbAccess();
    // If DB access failed or worker stopped, exit early
    if (!_isRunning || db == null) {
        if (db != null) _dbMonitor.releaseDatabaseAccess(); // Release if acquired before stop
        return;
    }

    QuizzerLogger.logMessage('Initial Loop: Fetching all user records from DB...');
    final List<Map<String, dynamic>> allUserRecords =
        await user_q_pairs_table.getAllUserQuestionAnswerPairs(db, _sessionManager.userId!); 
    QuizzerLogger.logSuccess('Initial Loop: Fetched ${allUserRecords.length} records from DB.');
    if (!_isRunning) { _dbMonitor.releaseDatabaseAccess(); return; } // Check running status
    
    // Assume validateAllModuleQuestions handles its own DB access/release or crashes
    // It needs the db instance passed here though
    QuizzerLogger.logMessage('Initial Loop: Validating User Questions vs Modules...');
    await user_question_processor.validateAllModuleQuestions(db, _sessionManager.userId!); 
    if (!_isRunning) { _dbMonitor.releaseDatabaseAccess(); return; } // Check running status

    // --- Release DB lock BEFORE cache operations ---
    _dbMonitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('Initial Loop: DB access released BEFORE cache processing.');
    db = null; // Ensure db variable isn't accidentally reused

    if (!_isRunning) return; // Check running status

    // --- Place into Unprocessed Cache ---
    if (allUserRecords.isNotEmpty) {
      await _unprocessedCache.addRecords(allUserRecords);
      QuizzerLogger.logMessage('Initial Loop: Added ${allUserRecords.length} records to UnprocessedCache.');
    }

    if (!_isRunning) return; // Check running status

    // --- Process all initially fetched records ---
    QuizzerLogger.logMessage('Initial Loop: Processing records from UnprocessedCache...');

    Map<String, dynamic> recordToProcess;
    do {
       if (!_isRunning) break; // Check running status within the loop
       recordToProcess = await _unprocessedCache.getAndRemoveOldestRecord();
       if (recordToProcess.isNotEmpty) {
         await _processRecord(recordToProcess);
       }
    } while (recordToProcess.isNotEmpty);
    QuizzerLogger.logSuccess('Initial Loop: Finished processing initial records.');

    // --- Start Inactive Module Worker ---
    QuizzerLogger.logMessage('PreProcessWorker: Starting Inactive Module Worker...');
    final inactiveWorker = InactiveModuleWorker(); // Get singleton instance
    inactiveWorker.start();

    // --- Start Queue Cache Removal Worker (REMOVED) ---
    /*
    QuizzerLogger.logMessage('PreProcessWorker: Starting Queue Cache Removal Worker...');
    final queueRemovalWorker = QueueCacheRemovalWorker(); // Get singleton instance
    queueRemovalWorker.start();
    */

    // --- Start Eligibility Worker --- 
    QuizzerLogger.logMessage('PreProcessWorker: Starting Eligibility Check Worker...');
    final eligibilityWorker = EligibilityCheckWorker(); // Get singleton instance
    eligibilityWorker.start(); // Start the next worker

    QuizzerLogger.logSuccess('PreProcessWorker: Initial loop completed and Eligibility Worker started.');
  }

  // --- Subsequent Loop Logic ---
  Future<void> _performSubsequentLoop() async {
    // QuizzerLogger.logMessage('PreProcessWorker: Checking UnprocessedCache...');
    if (!_isRunning) return;

    // Check if the cache is empty BEFORE attempting to get a record
    if (await _unprocessedCache.isEmpty()) {
      // If empty, wait for a notification that a record was added
      // QuizzerLogger.logMessage('PreProcessWorker: UnprocessedCache empty, waiting for new records...');
      await _unprocessedCache.onRecordAdded.first;
      // QuizzerLogger.logMessage('PreProcessWorker: Woke up by UnprocessedCache notification.');
      // After waking up, the loop will continue and re-check the cache.
    } else {
      // Cache is not empty, attempt to get and process the oldest record
      final Map<String, dynamic> record = await _unprocessedCache.getAndRemoveOldestRecord();
      
      // Check if a record was actually retrieved (could be empty due to race condition)
      if (record.isNotEmpty) {
        await _processRecord(record); 
        
        // Add a check AFTER processing attempt: if worker was stopped DURING processing, put record back.
        if (!_isRunning) {
           QuizzerLogger.logWarning('PreProcessWorker: Stopped during processing record ${record['question_id']}. Putting back in UnprocessedCache.');
           await _unprocessedCache.addRecord(record); // Add it back
        }
      } 
      // else: Record was empty, likely due to race condition. Log or ignore.
      // QuizzerLogger.logWarning('PreProcessWorker: Cache was not empty but getOldest returned empty? Possible race condition.');
    }
  }

  // --- Record Processing Logic ---
  Future<void> _processRecord(Map<String, dynamic> record) async {
    // Check if stopped right at the beginning
    if (!_isRunning) {
      await _unprocessedCache.addRecord(record);
      return;
    }

    assert(_sessionManager.userId != null, "Current User ID cannot be null for processing.");
    String questionId = record['question_id'];

    // Critical field assertions
    assert(record.containsKey('in_circulation'),    'Record missing in_circulation: $record');
    assert(record.containsKey('next_revision_due'), 'Record missing next_revision_due: $record');

    // --- Get Dependencies (DB Access & Checks) ---
    String? moduleName;
    bool isModuleActive = false;
    Database? db;

    db = await _getDbAccess();
    assert(db != null); // DO NOT REMOVE THIS ASSERT

    // Check if stopped during DB access OR if DB access failed
    if (!_isRunning || db == null) {
      // Log removed
      _dbMonitor.releaseDatabaseAccess(); 
      await _unprocessedCache.addRecord(record);
      return;
    }

    // Perform DB checks within try/finally to ensure release
    try {
      moduleName = await getModuleNameForQuestionId(questionId, db);
      final Map<String, bool> activationStatus =
          await user_profile_table.getModuleActivationStatus(_sessionManager.userId!, db);
      isModuleActive = activationStatus[moduleName] ?? false;
    } finally {
      _dbMonitor.releaseDatabaseAccess();
    }

    // Check if stopped AFTER DB operations but BEFORE routing
    if (!_isRunning) {
      await _unprocessedCache.addRecord(record);
      return;
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
          return;
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
        return;
    }

    // Log the routing decision just before the operation
    QuizzerLogger.logMessage('[PreProcessWorker] Routing $questionId to $destinationCacheName.');
    
    // Perform the actual add to the destination cache
    await routeToAdd; 
  }

  // --- Helper for DB Access ---
  Future<Database?> _getDbAccess() async {
     Database? db;
     int retries       = 0;
     const maxRetries  = 5; // Prevent infinite loops
     while (db == null && _isRunning && retries < maxRetries) {
       db = await _dbMonitor.requestDatabaseAccess();
       if (db == null) {
         QuizzerLogger.logMessage('PreProcessWorker: DB access denied, waiting...');
         await Future.delayed(const Duration(milliseconds: 250));
         retries++;
       }
     }
     if (db == null && _isRunning) {
        QuizzerLogger.logError('PreProcessWorker: Failed to acquire DB access after $maxRetries retries.');
        // Optional: throw an exception here for fail-fast
     }
     return db;
  }
}