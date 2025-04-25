import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart' as user_q_pairs_table;
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile_table.dart' as user_profile_table;
import 'package:quizzer/backend_systems/04_module_management/module_updates_process.dart' as module_processor;
import 'package:quizzer/backend_systems/07_user_question_management/functionality/user_question_processes.dart' as user_question_processor;
import 'package:quizzer/backend_systems/09_data_caches/unprocessed_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/non_circulating_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/module_inactive_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/due_date_beyond_24hrs_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/due_date_within_24hrs_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/circulating_questions_cache.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart' show getModuleNameForQuestionId;

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

    // --- Start Eligibility Worker (Placeholder) ---
    QuizzerLogger.logMessage('PreProcessWorker: Triggering Eligibility Worker start (Placeholder)...');
    // TODO: Implement Eligibility Worker start call here

    QuizzerLogger.logSuccess('PreProcessWorker: Initial loop completed.');
  }

  // --- Subsequent Loop Logic ---
  Future<void> _performSubsequentLoop() async {
    // QuizzerLogger.logMessage('PreProcessWorker: Checking UnprocessedCache...');
    if (!_isRunning) return;

    final Map<String, dynamic> record = await _unprocessedCache.getAndRemoveOldestRecord();

    if (record.isNotEmpty) {
      QuizzerLogger.logMessage('PreProcessWorker: Found record in UnprocessedCache, processing...');
      await _processRecord(record);
    } else {
      QuizzerLogger.logMessage('PreProcessWorker: UnprocessedCache empty, sleeping...');
      // Sleep only if the cache is empty
      await Future.delayed(const Duration(seconds: 30));
    }
  }

  // --- Record Processing Logic ---
  Future<void> _processRecord(Map<String, dynamic> record) async {
    assert(_sessionManager.userId != null, "Current User ID cannot be null for processing.");
    String questionId = record['question_id'];

    // --- Assertions for critical fields (REMOVED module_name check) ---
    assert(record.containsKey('question_id'),       'Record missing question_id: $record');
    assert(record.containsKey('in_circulation'),    'Record missing in_circulation: $record');
    assert(record.containsKey('next_revision_due'), 'Record missing next_revision_due: $record');

    // --- Get Dependencies (Module Name and Status) ---
    String? moduleName; // Declared here, fetched later
    bool isModuleActive = false;
    Database? db;

    db = await _getDbAccess();
    if (!_isRunning || db == null) {
        if (db != null) _dbMonitor.releaseDatabaseAccess();
        return;
    }

    // Fetch module_name using the question_id
    moduleName = await getModuleNameForQuestionId(questionId, db);
    
    // Fetch module activation status using the fetched moduleName
    final Map<String, bool> activationStatus =
        await user_profile_table.getModuleActivationStatus(_sessionManager.userId!, db);
    isModuleActive = activationStatus[moduleName] ?? false; // Default to false if not found

    // --- Release DB lock ---
    _dbMonitor.releaseDatabaseAccess();
    // QuizzerLogger.logMessage('Record Processing: DB access released for $questionId.');
    db = null;
    if (!_isRunning) return;

    // --- Routing Logic (Uses fetched moduleName and isModuleActive) ---
    final bool     inCirculation          = (record['in_circulation'] as int? ?? 0) == 1;
    final String   dueDateString          = record['next_revision_due'] as String;
    final DateTime parsedDueDate          = DateTime.parse(dueDateString);
    final DateTime twentyFourHoursFromNow = DateTime.now().add(const Duration(hours: 24));

    // Route based on isModuleActive and other fields in the original record
    if (!isModuleActive) {
      QuizzerLogger.logMessage('Routing $questionId to ModuleInactiveCache.');
      await _moduleInactiveCache.addRecord(record);
    } else if (!inCirculation) {
      QuizzerLogger.logMessage('Routing $questionId to NonCirculatingQuestionsCache.');
      await _nonCirculatingCache.addRecord(record);
    } else {
      // Module is active AND question is in circulation
      QuizzerLogger.logMessage('Adding $questionId to CirculatingQuestionsCache.');
      await _circulatingCache.addQuestionId(questionId);

      // Now route based on due date
      if (parsedDueDate.isAfter(twentyFourHoursFromNow)) {
        QuizzerLogger.logMessage('Routing $questionId to DueDateBeyond24hrsCache.');
        await _dueDateBeyondCache.addRecord(record);
      } else {
        QuizzerLogger.logMessage('Routing $questionId to DueDateWithin24hrsCache.');
        await _dueDateWithinCache.addRecord(record);
      }
    }
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