import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/inactive_module_worker.dart';
import 'package:quizzer/backend_systems/07_user_question_management/user_question_processes.dart' show validateAllModuleQuestions;
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart' as q_pairs_table;
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart' as uqap_table;
import 'package:quizzer/backend_systems/03_account_creation/new_user_signup.dart' as account_creation;
import 'package:quizzer/backend_systems/04_module_management/module_updates_process.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/04_module_management/module_isolates.dart';
import 'package:quizzer/backend_systems/02_login_authentication/user_auth.dart';
import 'package:quizzer/backend_systems/09_data_caches/past_due_cache.dart';
import 'package:quizzer/backend_systems/session_manager/session_isolates.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive/hive.dart';
import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/pre_process_worker.dart';
import 'package:path/path.dart' as p; // Use alias to avoid conflicts
import 'dart:async'; // For Completer
import 'dart:io'; // For Directory

import 'package:path_provider/path_provider.dart'; // For mobile path
// Data Caches for Backend management
import 'package:quizzer/backend_systems/09_data_caches/module_inactive_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/unprocessed_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/non_circulating_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/circulating_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/due_date_beyond_24hrs_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/due_date_within_24hrs_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/eligible_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/question_queue_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/answer_history_cache.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/question_selection_worker.dart';
import 'session_toggle_scheduler.dart'; // Import the new scheduler
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart'; // Import SwitchBoard
import 'package:quizzer/backend_systems/session_manager/session_helper.dart';
import 'package:quizzer/backend_systems/session_manager/session_answer_validation.dart' as answer_validator;
import 'package:quizzer/backend_systems/06_question_queue_server/circulation_worker.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/due_date_worker.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/eligibility_check_worker.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/outbound_sync/outbound_sync_worker.dart'; // Import the new worker
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/media_sync_worker.dart'; // Added import for MediaSyncWorker
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/inbound_sync/inbound_sync_worker.dart'; // Import for InboundSyncWorker (NEW)
import 'package:quizzer/backend_systems/09_data_caches/temp_question_details.dart'; // Added import
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart' as modules_table;
import 'package:quizzer/backend_systems/00_database_manager/review_system/get_send_postgre.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/error_logs_table.dart'; // Direct import
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_settings_table.dart' as user_settings_table;
// FIXME DO NOT USE ALIASING ON IMPORTS

class SessionManager {
  // Singleton instance
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  // Secure Storage
  // Hive storage for offline persistence
  late Box                                    _storage;
  // Completer to signal when async initialization (like storage) is done
  final       Completer<void>                 _initializationCompleter = Completer<void>();
  /// Future that completes when asynchronous initialization is finished.
  /// Await this before accessing components that depend on async init (e.g., _storage).
              Future<void> get                initializationComplete => _initializationCompleter.future;
  // Supabase client instance
  late final  SupabaseClient                  supabase;
  // Database monitor instance
  final       DatabaseMonitor                 _dbMonitor = getDatabaseMonitor();
  // Cache Instances (as instance variables)
  final       UnprocessedCache                _unprocessedCache;
  final       NonCirculatingQuestionsCache    _nonCirculatingCache;
  final       ModuleInactiveCache             _moduleInactiveCache;
  final       CirculatingQuestionsCache       _circulatingCache;
  final       DueDateBeyond24hrsCache         _dueDateBeyondCache;
  final       DueDateWithin24hrsCache         _dueDateWithinCache;
  final       EligibleQuestionsCache          _eligibleCache;
  final       QuestionQueueCache              _queueCache;
  final       AnswerHistoryCache              _historyCache;
  final       SwitchBoard                     _switchBoard; // Add SwitchBoard instance
  final       PastDueCache                    _pastDueCache = PastDueCache();
  final       TempQuestionDetailsCache        _tempDetailsCache = TempQuestionDetailsCache();

  // user State
              bool                            userLoggedIn = false;
              String?                         userId;
              String?                         userEmail;
              String?                         _initialProfileLastModified; // Store initial last_modified_timestamp
  // Current Question information and booleans
              Map<String, dynamic>?           _currentQuestionRecord;         // userQuestionRecord
              Map<String, dynamic>?           _currentQuestionDetails;        // questionAnswerPairRecord
              String?                         _currentQuestionType;
              DateTime?                       _timeDisplayed;
              DateTime?                       _timeAnswerGiven;
              bool                            _isAnswerSubmitted = false; // Flag for preventing duplicate submissions
  // MetaData
              DateTime?                       sessionStartTime;
  // Page history tracking
  final       List<String>                    _pageHistory = [];
  static const  int                           _maxHistoryLength = 12;
  final       ToggleScheduler                 _toggleScheduler = getToggleScheduler(); // Get scheduler instance      
  
          
  // --- Public Getters for UI State ---
  Map<String, dynamic>? get currentQuestionUserRecord => _currentQuestionRecord;
  Map<String, dynamic>? get currentQuestionStaticData => _currentQuestionDetails;
  String?               get initialProfileLastModified => _initialProfileLastModified;
  // ADDED: Getter that dynamically determines user role from JWT
  String                get userRole => determineUserRoleFromSupabaseSession(supabase.auth.currentSession);
  
  
  // int?                  get optionSelected            => _multipleChoiceOptionSelected;
  DateTime?             get timeQuestionDisplayed     => _timeDisplayed;
  DateTime?             get timeAnswerGiven           => _timeAnswerGiven;

  // --- Getters for Static Question Data (_currentQuestionDetails) ---
  // Assumes _currentQuestionDetails is non-null when accessed (post requestNextQuestion)
  String                      get currentQuestionType           => _currentQuestionDetails!['question_type'] 
  as String;
  
  String                      get currentQuestionId             => _currentQuestionDetails!['question_id'] 
  as String;

  // Safely cast List<dynamic> to List<Map<String, dynamic>>
  List<Map<String, dynamic>>  get currentQuestionElements { 
    final dynamic elements = _currentQuestionDetails!['question_elements'];
    if (elements is List) {
      // Explicitly create List<Map<String, dynamic>> from List<dynamic>
      return List<Map<String, dynamic>>.from(elements.map((item) => Map<String, dynamic>.from(item as Map)));
    } 
    return []; // Return empty list if null or not a list
  }

  // Safely cast List<dynamic> to List<Map<String, dynamic>>
  List<Map<String, dynamic>>  get currentQuestionAnswerElements { 
    final dynamic elements = _currentQuestionDetails!['answer_elements'];
    if (elements is List) {
      // Explicitly create List<Map<String, dynamic>> from List<dynamic>
      return List<Map<String, dynamic>>.from(elements.map((item) => Map<String, dynamic>.from(item as Map)));
    }
    return []; // Return empty list if null or not a list
  }

  // REVERTED: Assumes options arrive decoded from table_helper
  List<Map<String, dynamic>> get currentQuestionOptions { 
    final dynamic options = _currentQuestionDetails?['options']; 
    if (options is List) {
      // Attempt direct conversion, assuming items are maps. Fail Fast if not.
      return List<Map<String, dynamic>>.from(options.map((item) => Map<String, dynamic>.from(item as Map)));
    }
    // If null or not a List, return empty. Log if it's an unexpected type.
    if (options != null) { 
        QuizzerLogger.logWarning('currentQuestionOptions: Expected List but got ${options.runtimeType}');
    }
    return [];
  }

  int?                        get currentCorrectOptionIndex     => _currentQuestionDetails!['correct_option_index'] as int?; // Nullable if not MC or not set

  // Safely cast List<dynamic> to List<int>
  List<int>                   get currentCorrectIndices {        
    final dynamic indices = _currentQuestionDetails?['index_options_that_apply']; // Use null-aware access
    if (indices is List) {
       // Attempt to create a List<int> from the List<dynamic>
       // If any item is not an int, the 'item as int' cast will throw, adhering to Fail Fast.
       return List<int>.from(indices.map((item) => item as int));
    }
    return []; // Return empty list if null or not a list
  }

  List<Map<String, dynamic>>  get currentCorrectOrder           => _currentQuestionDetails!['correct_order'] 
  as List<Map<String, dynamic>>; // Parsed in DB layer

  String                      get currentModuleName             => _currentQuestionDetails!['module_name'] 
  as String;

  String?                     get currentCitation               => _currentQuestionDetails!['citation'] 
  as String?;

  String?                     get currentConcepts               => _currentQuestionDetails!['concepts'] 
  as String?;

  String?                     get currentSubjects               => _currentQuestionDetails!['subjects'] 
  as String?;
  // ================================================================================
  // --- Initialization Functionality ---
  // ================================================================================
  // --------------------------------------------------------------------------------
  // SessionManager Constructor (Initializes Supabase and starts async init)
  SessionManager._internal()
      // Initialize cache instance variables
      : _unprocessedCache       = UnprocessedCache(),
        _nonCirculatingCache    = NonCirculatingQuestionsCache(),
        _moduleInactiveCache    = ModuleInactiveCache(),
        _circulatingCache       = CirculatingQuestionsCache(),
        _dueDateBeyondCache     = DueDateBeyond24hrsCache(),
        _dueDateWithinCache     = DueDateWithin24hrsCache(),
        _eligibleCache          = EligibleQuestionsCache(),
        _queueCache             = QuestionQueueCache(),
        _historyCache           = AnswerHistoryCache(),
        _switchBoard            = SwitchBoard()
         {
    supabase = SupabaseClient(
      'https://yruvxuvzztnahuuiqxit.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlydXZ4dXZ6enRuYWh1dWlxeGl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQzMTY1NDIsImV4cCI6MjA1OTg5MjU0Mn0.hF1oAILlmzCvsJxFk9Bpjqjs3OEisVdoYVZoZMtTLpo',
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
    // Start async initialization but don't wait for it here.
    // Complete the completer when done or if an error occurs.
    _initializeStorage().then((_) {
      _initializationCompleter.complete();
    }).catchError((error, stackTrace) {
      _initializationCompleter.completeError(error, stackTrace);
      // Decide how to handle critical init failure - maybe rethrow?
      // For now, just completing with error lets awaiters handle it.
    });
  }

  // Initialize Hive storage (private)
  Future<void> _initializeStorage() async {
    String hivePath;
    // Determine path based on platform (like original main_native)
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop / Test environment: Use runtime_cache/hive
      hivePath = p.join(Directory.current.path, 'runtime_cache', 'hive');
    } else {
      // Mobile: Use standard application documents directory
      // Assert that path_provider is available if this branch is hit
      final appDocumentsDir = await getApplicationDocumentsDirectory();
      hivePath = appDocumentsDir.path;
    }
    // Ensure the directory exists
    Directory(hivePath).createSync(recursive: true);
    Hive.init(hivePath);

    _storage = await Hive.openBox('async_prefs');
  }

  /// Initialize the SessionManager and its dependencies
  Future<void> _initializeLogin(String email) async {
    userLoggedIn = true;
    userEmail = email;
    userId = await initializeSession({'email': email});
    assert(userId != null, "Failed to retrieve userId during login initialization.");
    sessionStartTime = DateTime.now();


    // Fetch and store initial last_modified_timestamp before any sync operations
    Database? db = await _dbMonitor.requestDatabaseAccess();
    if (db == null) {
      throw StateError('Failed to acquire database access during login initialization');
    }
    _initialProfileLastModified = await getLastModifiedTimestampForUser(userId!, db);
    QuizzerLogger.logMessage('Stored initial profile last_modified_timestamp: $_initialProfileLastModified');
    _dbMonitor.releaseDatabaseAccess();

    // Start MediaSyncWorker before inbound sync
    QuizzerLogger.logMessage('SessionManager: Starting MediaSyncWorker...');
    final mediaSyncWorker = MediaSyncWorker();
    await mediaSyncWorker.start(); // Assuming start() is async and should be awaited if it performs critical setup
    QuizzerLogger.logMessage('SessionManager: MediaSyncWorker started.');

    // Start InboundSyncWorker (which runs initial sync internally)
    QuizzerLogger.logMessage('SessionManager: Starting InboundSyncWorker...');
    final inboundSyncWorker = InboundSyncWorker();
    await inboundSyncWorker.start();
    QuizzerLogger.logMessage('SessionManager: InboundSyncWorker started and initial sync completed.');
      
    // --- Start new background processing pipeline --- 
    final PreProcessWorker preProcessWorker = PreProcessWorker();
    preProcessWorker.start(); // Worker now fetches userId internally
    // -------------------------------------------------

    // --- Wait for Presentation Selection Worker initial loop completion --- 
    final psw = PresentationSelectionWorker();
    await psw.onInitialLoopComplete.first; // Waits for the signal
    // ----------------------------------------------------------------------

    // --- Update last_login at the very end ---
    db = await _dbMonitor.requestDatabaseAccess();
    await updateLastLogin(userId!, db!);
    _dbMonitor.releaseDatabaseAccess();

    // Start OutboundSyncWorker after all initialization is complete
    final outboundSyncWorker = OutboundSyncWorker();
    await outboundSyncWorker.start();
  }
  
  // =================================================================================
  // --- State Reset Functions ---
  // =================================================================================
  /// Reset only the state related to the currently displayed question.
  void _clearQuestionState() {
    _currentQuestionRecord        = null;  // User-specific data
    _currentQuestionDetails       = null;  // Static data (QPair)
    _currentQuestionType          = null;
    _timeDisplayed                = null;
    _timeAnswerGiven              = null;
    _isAnswerSubmitted            = false; // Reset the flag
    
  }

  /// Clears all session-specific user state.
  void _clearSessionState() {
    QuizzerLogger.logMessage("Clearing session state...");
    userLoggedIn = false;
    userId = null;
    userEmail = null;
    sessionStartTime = null;
    _clearQuestionState(); // Clear current question state
    clearPageHistory(); // Clear navigation history
    // Note: Does not stop workers or clear persistent storage, assumes logout function handles that.
    QuizzerLogger.logSuccess("Session state cleared.");
  }

  // =================================================================================
  // =================================================================================
  // Public API CALLS
  // =================================================================================
  // =================================================================================
  // =================================================================================
  // =================================================================================
  // =================================================================================
  //  --------------------------------------------------------------------------------
  /// Creates a new user account with Supabase and local database
  /// Returns true if successful, false otherwise
  Future<Map<String, dynamic>> createNewUserAccount({
    required String email,
    required String username,
    required String password,
  }) async {
    return await account_creation.handleNewUserProfileCreation({
      'email': email,
      'username': username,
      'password': password,
    }, supabase, _dbMonitor);
  }

  //  --------------------------------------------------------------------------------
  // Login User
  // This initializing spins up sub-system processes that rely on the user profile information
  Future<Map<String, dynamic>> attemptLogin(String email, String password) async {
    // Ensure async initialization is complete before proceeding
    QuizzerLogger.logMessage("Logging in user with email: $email");
    await initializationComplete;

    // Now it's safe to access _storage
    final response = await userAuth(
      email: email,
      password: password,
      supabase: supabase,
      storage: _storage,
    );

    if (response['success'] == true) {
      await _initializeLogin(email); // initialize function spins up necessary background processes
      // Once that's complete, request the first question
      await requestNextQuestion();
    }

    // Response information is for front-end UI, not necessary for backend
    // Send signal to UI that it's ok to login now
    return response; 
  }

  //  --------------------------------------------------------------------------------
  /// Logs out the current user, stops workers, clears caches, and resets state.
  Future<void> logoutUser() async {
    if (!userLoggedIn) {
      QuizzerLogger.logWarning("Logout called, but no user was logged in.");
      return;
    }

    // 1. Stop Workers (Order might matter depending on dependencies, stop consumers first?)
    QuizzerLogger.logMessage("Stopping background workers...");
    // Get worker instances (assuming they are singletons accessed via factory)
    final psw                   = PresentationSelectionWorker();
    final dueDateWorker         = DueDateWorker();
    final circulationWorker     = CirculationWorker();
    final eligibilityWorker     = EligibilityCheckWorker();
    final preProcessWorker      = PreProcessWorker(); 
    final inactiveModuleWorker  = InactiveModuleWorker();
    final outboundSyncWorker    = OutboundSyncWorker(); // Get the outbound sync worker instance
    final mediaSyncWorker       = MediaSyncWorker(); // Get MediaSyncWorker instance
    
    // Stop them (await completion)
    await psw.stop();
    await dueDateWorker.stop();
    await circulationWorker.stop();
    await eligibilityWorker.stop();
    await preProcessWorker.stop(); 
    await inactiveModuleWorker.stop();
    await outboundSyncWorker.stop(); // Stop the outbound sync worker
    await mediaSyncWorker.stop(); // Stop the media sync worker
    QuizzerLogger.logSuccess("Background workers stopped.");
    

    // 2. Clear Caches (TODO: Implement clear methods in caches)
    QuizzerLogger.logMessage("Clearing data caches...");
    _queueCache.          clear();
    _eligibleCache.       clear();
    _dueDateWithinCache.  clear();
    _dueDateBeyondCache.  clear();
    _pastDueCache.        clear();
    _circulatingCache.    clear();
    _nonCirculatingCache. clear();
    _moduleInactiveCache. clear(); 
    _unprocessedCache.    clear();
    _historyCache.        clear();
    QuizzerLogger.logSuccess("Data caches cleared (Placeholder - Clear methods TBD).");

    QuizzerLogger.logMessage("Disposing SwitchBoard");
    // TODO potential error here, when logging out ensure properly state reset of backend systems (_isRunning flags should terminate loops and force workers to reawait the start command) Should do extensive testing, logging out user, logging them in, answering a butt ton of questions, logging out, logging in, and repeatedly doing this in an aggressive manner. This should reveal if there are issues in the login/logout process
    // _switchBoard.dispose();

    // Update total study time
    if (sessionStartTime != null && userId != null) {
      final Duration elapsedDuration = DateTime.now().difference(sessionStartTime!); // Use non-null assertion
      final double hoursToAdd = elapsedDuration.inMilliseconds / (1000.0 * 60 * 60);
      Database? db;
      db = await _dbMonitor.requestDatabaseAccess();
      QuizzerLogger.logMessage("Updating total study time for user $userId...");
      await updateTotalStudyTime(userId!, hoursToAdd, db!); // Let it throw if it fails
      QuizzerLogger.logSuccess("Total study time updated.");
      _dbMonitor.releaseDatabaseAccess(); // Release lock AFTER successful update
    }

    // 3. Sign out from Supabase
    QuizzerLogger.logMessage("Signing out from Supabase...");
    try {
       await supabase.auth.signOut();
       QuizzerLogger.logSuccess("Supabase sign out successful.");
    } catch (e) {
       // Log error but continue logout process
       QuizzerLogger.logError("Error during Supabase sign out: $e"); 
    }

    // 4. Clear local session token (ensure key matches auth logic)
    QuizzerLogger.logMessage("Clearing local session token...");
    await _storage.delete('supabase.auth.token'); // Assume returns Future<void>
    QuizzerLogger.logSuccess("Local session token cleared.");

    // 5. Reset SessionManager state
    _clearSessionState(); // Already logs internally

    QuizzerLogger.printHeader("User Logout Process Completed.");
  }

  //  --------------------------------------------------------------------------------
  // Manage Page History
  // Add page to history
  void addPageToHistory(String routeName) {
    if (_pageHistory.isNotEmpty && _pageHistory.last == routeName) {
      return; // Don't add duplicate consecutive pages
    }
    _pageHistory.add(routeName);
    if (routeName == "/home") {
      buildModuleRecords();
      }
    if (_pageHistory.length > _maxHistoryLength) {
      _pageHistory.removeAt(0);
    }
  }

  //  --------------------------------------------------------------------------------
  // Get previous page, now including /menu if it was the actual previous page
  String getPreviousPage() {
    // Check if there are at least two pages in history
    if (_pageHistory.length >= 2) {
      // Return the second-to-last entry
      final previousPage = _pageHistory[_pageHistory.length - 2];
      return previousPage;
    } else {
      // If history has 0 or 1 entries, default to /home
      return '/home';
    }
  }

  //  --------------------------------------------------------------------------------
  // Clear page history
  void clearPageHistory() {
    _pageHistory.clear();
  }

  //  --------------------------------------------------------------------------------
  // =================================================================================
  // Module management Calls
  // =================================================================================
  // API for loading module names and their activation status
  Future<Map<String, dynamic>> loadModules() async {
    assert(userId != null);
    final result = await handleLoadModules({
      'userId': userId,
    });
    // Ensure all module fields are properly typed
    if (result.containsKey('modules')) {
      final modules = result['modules'] as List<dynamic>;
      result['modules'] = modules.map((module) {
        final mod = Map<String, dynamic>.from(module);
        // Explicitly cast question_ids to List<String> if present
        if (mod.containsKey('question_ids') && mod['question_ids'] is List) {
          mod['question_ids'] = List<String>.from(mod['question_ids']);
        }
        // Add similar casts for other fields if needed
        return mod;
      }).toList();
    }
    return result;
  }

  //  --------------------------------------------------------------------------------
  // API for activating or deactivating a module (Reverted to direct execution - Attempt 3)
  Future<void> toggleModuleActivation(String moduleName, bool activate) async {
    assert(userId != null);
    
    // 1. Request slot from scheduler, passing module/state
    await _toggleScheduler.requestToggleSlot();

    // --- START of actual toggle work (after acquiring slot) --- 
    
    // 2. Update DB activation status FIRST 
    await handleModuleActivation({
      'userId': userId,
      'moduleName': moduleName,
      'isActive': activate,
    });

    // --- Acquire DB Lock ONLY for validation ---
    Database? db;
    while (db == null) {
      db = await _dbMonitor.requestDatabaseAccess(); 
      if (db == null) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }

    // 2. Validate profile questions (needs DB)
    await validateAllModuleQuestions(db, userId!); 

    // --- Release DB lock immediately after validation ---
    _dbMonitor.releaseDatabaseAccess(); 
    db = null; // Prevent accidental reuse
    // ----------------------------------------------------

    // 3. Signal deactivation if needed, then flush other caches
    if (!activate) {
       _eligibleCache.flushToPastDueCache();
       _queueCache.flushToUnprocessedCache();
       
    } else {
      _switchBoard.signalModuleActivated(moduleName);
    }
    
    // 4. Release slot AFTER all work is done
    await _toggleScheduler.releaseToggleSlot();
    // --- End Direct Execution Logic ---
  }

  //  --------------------------------------------------------------------------------
  // API for updating a module's description
  Future<bool> updateModuleDescription(String moduleName, String newDescription) async {
    assert(userId != null);
    
    return await handleUpdateModuleDescription({
      'moduleName': moduleName,
      'description': newDescription,
    });
  }
  // =================================================================================
  // Question Flow API
  // =================================================================================

  //  --------------------------------------------------------------------------------
  /// Retrieves the next question, updates state, and makes it available via getters.
  Future<void> requestNextQuestion() async {
    if (userId == null) {
       throw StateError('User must be logged in to request a question.');
    }

    // 1. Flush current question record (if exists) to UnprocessedCache
    if (_currentQuestionRecord != null) {
        await _unprocessedCache.addRecord(_currentQuestionRecord!); 
        await _historyCache.addRecord(_currentQuestionRecord!['question_id']);
    }

    // 2. Clear existing question state
    _clearQuestionState();

    // 3. Get next user record from QuestionQueueCache
    final Map<String, dynamic> newUserRecord = await _queueCache.getAndRemoveRecord();

    if (newUserRecord.isEmpty) {
        // --- Build and set dummy question state ---
        final dummyRecords = buildDummyNoQuestionsRecord();
        _currentQuestionRecord = null;
        _currentQuestionDetails = dummyRecords['staticDetails'];
        _currentQuestionType = _currentQuestionDetails!['question_type'] as String;
        _timeDisplayed = DateTime.now();
        // --- Dummy state set, stop processing ---
        return; 
    }
    
    // --- If queue was NOT empty, proceed as before ---
    _currentQuestionRecord = newUserRecord;
    final String questionId = _currentQuestionRecord!['question_id'] as String;

    // 4. Get static question details from TempQuestionDetailsCache
    Map<String, dynamic>? staticDetails = await _tempDetailsCache.getAndRemoveRecord(questionId);

    if (staticDetails == null) {
        // This is a critical error: details for a queued question are missing.
        // This might indicate a logic flaw where details weren't added or were prematurely removed.
        QuizzerLogger.logError('SessionManager.requestNextQuestion: CRITICAL - Failed to get question details for QID: $questionId from TempQuestionDetailsCache. The question was in the queue, but its details were not found in the details cache.');
        // Create a dummy error question to display to the user, or handle error appropriately.
        // For now, setting a specific error state that the UI can check.
        final dummyRecords = buildDummyNoQuestionsRecord(); // Or a specific error dummy
        _currentQuestionDetails = dummyRecords['staticDetails'];
        _currentQuestionDetails!['question_elements'] = [{'type': 'text', 'content': 'Error: Could not load question details. Please try again.'}];
        _currentQuestionType = _currentQuestionDetails!['question_type'] as String;
        _timeDisplayed = DateTime.now();
        return; // Stop further processing for this question
    }

    // --- DIAGNOSTIC LOGGING (can be kept or removed) ---
    final dynamic fetchedOptions = staticDetails['options'];
    QuizzerLogger.logValue('SessionManager.requestNextQuestion: Fetched options type: ${fetchedOptions.runtimeType}, value: $fetchedOptions');
    // --- END DIAGNOSTIC LOGGING ---

    // 5. Update state with new details
    _currentQuestionDetails = staticDetails;
    // Assert that the key exists and is not null before casting
    assert(_currentQuestionDetails!.containsKey('question_type') && _currentQuestionDetails!['question_type'] != null, 
           "Question details missing 'question_type'");
    // Directly cast to non-nullable String - will throw if not a String
    _currentQuestionType = _currentQuestionDetails!['question_type'] as String; 
    _timeDisplayed = DateTime.now();
  }

  //  --------------------------------------------------------------------------------
  /// Submits the user's answer for the current question.
  /// Updates user-question stats, calculates next due date, and records the attempt.
  /// Returns a map: {success: bool, message: String}
  Future<Map<String, dynamic>> submitAnswer({required dynamic userAnswer}) async {
    // --- ADDED: Check for Dummy Record State --- 
    if (_currentQuestionRecord == null) {
      // This means the dummy "No Questions" record is loaded
      QuizzerLogger.logWarning('submitAnswer called when no real question was loaded (currentQuestionRecord is null).');
      return {'success': false, 'message': 'No real question loaded to submit answer for.'};
    }
    // --- Original validation continues below ---

    // --- 1. Input Validation and State Checks (Fail Fast Internally, Graceful Return for API) ---
    if (userId == null) {
      return {'success': false, 'message': 'User not logged in.'};
    }
    if (_currentQuestionRecord == null || _currentQuestionDetails == null) {
      return {'success': false, 'message': 'No question currently loaded.'};
    }
    if (_isAnswerSubmitted) {
       return {'success': false, 'message': 'Answer already submitted for this question.'}; 
    }
    if (_timeDisplayed == null) {
      // This indicates an internal state issue, less likely UI recoverable
      // For now, return failure, but consider if throwing is better here.
      return {'success': false, 'message': 'Internal error: Question display time missing.'};
    }

    // --- 2. Set Submission State & Time ---
    _isAnswerSubmitted          = true;
    _timeAnswerGiven            = DateTime.now();

    // --- 3. Determine Correctness ---
           bool    isCorrect;
     final String  questionId    = currentQuestionId;     // Use getter
  
      switch (_currentQuestionType) {
        case 'multiple_choice':
          final int? correctIndex = currentCorrectOptionIndex;
          isCorrect = answer_validator.validateMultipleChoiceAnswer(
            userAnswer: userAnswer,
            correctIndex: correctIndex,
          );
          break;
        case 'select_all_that_apply':
          final List<int> correctIndices = currentCorrectIndices; // Use getter
          isCorrect = answer_validator.validateSelectAllThatApplyAnswer(
            userAnswer: userAnswer,
            correctIndices: correctIndices,
          );
          break;
        case 'true_false':
          // User answer should be 0 (True) or 1 (False)
          assert(currentCorrectOptionIndex != null);
          isCorrect = answer_validator.validateTrueFalseAnswer(
            userAnswer: userAnswer,
            correctIndex: currentCorrectOptionIndex!,
          );
          break;
        case 'sort_order':
          // Get the correct order (List<Map<String, dynamic>>) using existing getter
          final List<Map<String, dynamic>> correctOrder = currentQuestionOptions;
          // Validate user's answer (expected List<Map<String, dynamic>>)
          isCorrect = answer_validator.validateSortOrderAnswer(
            userAnswer: userAnswer,
            correctOrder: correctOrder,
          );
          break;
        // case 'text_input':
        //   // Compare userAnswer (String?) with currentQuestionAnswerElements
        //   isCorrect = /* ... comparison logic ... */ ;
        //   break;
        default:
           throw UnimplementedError('Correctness check not implemented for question type: $_currentQuestionType');
      }

    // --- 4. Calculate Updated User Record ---
    // Keep a copy of the record *before* updates for the attempt log
    final Map<String, dynamic> recordBeforeUpdate = Map<String, dynamic>.from(_currentQuestionRecord!); 
    final Map<String, dynamic> updatedUserRecord = updateUserQuestionRecordOnAnswer( //TODO Check me
       currentUserRecord:  _currentQuestionRecord!,
       isCorrect:          isCorrect,
    );
    // Call the top-level helper function from session_helper.dart
    await recordQuestionAnswerAttempt(
      recordBeforeUpdate: recordBeforeUpdate,
      isCorrect: isCorrect,
      timeAnswerGiven: _timeAnswerGiven!, 
      timeDisplayed: _timeDisplayed!, 
      userId: userId!,
      questionId: questionId,
      currentSubjects: currentSubjects, // Use getter
      currentConcepts: currentConcepts, // Use getter
    );

    // --- 6. Update User-Question Pair in DB (Moved After Attempt Record) ---
    Database? db;
    db = await _dbMonitor.requestDatabaseAccess(); // Re-acquire lock
    if (db == null) {
      throw StateError('Database unavailable during answer submission.');
    }
     await uqap_table.editUserQuestionAnswerPair(
       userUuid: userId!,
       questionId: questionId,
       db: db,
       revisionStreak: updatedUserRecord['revision_streak'] as int,
       lastRevised: updatedUserRecord['last_revised'] as String,
       nextRevisionDue: updatedUserRecord['next_revision_due'] as String,
       timeBetweenRevisions: updatedUserRecord['time_between_revisions'] as double,
       averageTimesShownPerDay: updatedUserRecord['average_times_shown_per_day'] as double,
     );
    // ADDED: Increment total questions answered in user_profile table
     // Explicitly increment total_attempts using the dedicated function -> for the questionObject
     await uqap_table.incrementTotalAttempts(userId!, questionId, db);
     await incrementTotalQuestionsAnswered(userId!, db);

    // Release lock AFTER successful operations
    _dbMonitor.releaseDatabaseAccess();

    // --- 7. Update In-Memory State ---
    _currentQuestionRecord = updatedUserRecord;

    return {'success': true, 'message': 'Answer submitted successfully.'};
  }

  //  --------------------------------------------------------------------------------
  /// Adds a new question to the database.
  /// Accepts parameters for various question types and routes to the specific
  /// database function based on `questionType`.
  /// Throws errors directly if validation fails or DB operations fail (Fail Fast).
  Future<Map<String, dynamic>> addNewQuestion({
    required String questionType,
    required List<Map<String, dynamic>> questionElements,
    required List<Map<String, dynamic>> answerElements,
    required String moduleName,
    // --- Type-specific --- (Add more as needed)
    List<Map<String, dynamic>>? options, // For MC & SelectAll
    int? correctOptionIndex, // For MC & TrueFalse
    List<int>? indexOptionsThatApply, // For select_all_that_apply
    // --- Common Optional/Metadata ---
    String? citation,
    String? concepts,
    String? subjects,
  }) async {
    QuizzerLogger.logMessage('SessionManager: Attempting to add new question of type $questionType');
    // --- 1. Pre-checks --- 
    assert(userId != null, 'User must be logged in to add a question.'); 

    final String qstContrib = userId!; // Use current user ID as the question contributor

    // --- 2. Database Operation (Lock Acquisition) --- 
    Database? db;
    Map<String, dynamic> response;

    // Acquire DB Lock (Fail Fast - throw if unavailable)
    db = await _dbMonitor.requestDatabaseAccess();
    // Assert that db is not null after awaiting access
    assert(db != null, 'Failed to acquire database access to add question.');

    switch (questionType) {
      case 'multiple_choice':
        // Validate required fields for this type
        if (options == null || correctOptionIndex == null) {
          _dbMonitor.releaseDatabaseAccess(); // Release lock before throwing
          throw ArgumentError('Missing required fields for multiple_choice: options and correctOptionIndex.');
        }
        // Call refactored function with correct args
        await q_pairs_table.addQuestionMultipleChoice(
          moduleName: moduleName,
          questionElements: questionElements,
          answerElements: answerElements,
          options: options,
          correctOptionIndex: correctOptionIndex,
          qstContrib: qstContrib, 
          db: db!,
          citation: citation,
          concepts: concepts,
          subjects: subjects,
        );
        break;

      case 'select_all_that_apply':
        // Validate required fields for this type
        if (options == null || indexOptionsThatApply == null) {
          _dbMonitor.releaseDatabaseAccess(); // Release lock before throwing
          throw ArgumentError('Missing required fields for select_all_that_apply: options and indexOptionsThatApply.');
        }
        // Call refactored function with correct args
        await q_pairs_table.addQuestionSelectAllThatApply(
          moduleName: moduleName,
          questionElements: questionElements,
          answerElements: answerElements,
          options: options,
          indexOptionsThatApply: indexOptionsThatApply,
          qstContrib: qstContrib,
          db: db!,
          citation: citation,
          concepts: concepts,
          subjects: subjects,
        );
        break;

      // --- Add cases for other question types here --- 
      case 'true_false':
        // Validate required fields for this type using assert (Fail Fast)
        if (correctOptionIndex == null) {
            _dbMonitor.releaseDatabaseAccess(); // Release lock before throwing
            throw ArgumentError('Missing required field correctOptionIndex for true_false');
        }
        
        // Call refactored function with correct args
        await q_pairs_table.addQuestionTrueFalse(
            moduleName: moduleName,
            questionElements: questionElements,
            answerElements: answerElements,
            correctOptionIndex: correctOptionIndex, // Already checked non-null
            qstContrib: qstContrib,
            db: db!,
            citation: citation,
            concepts: concepts,
            subjects: subjects,
          );
        break;
      
      case 'sort_order':
        // Validate the new sortOrderOptions parameter
        if (options == null) {
          _dbMonitor.releaseDatabaseAccess(); // Release lock before throwing
          throw ArgumentError('Missing required field for sort_order: sortOrderOptions (List<String>).');
        }
        // Call the specific function using the correct parameter
        await q_pairs_table.addSortOrderQuestion(
          moduleId: moduleName,
          questionElements: questionElements,
          answerElements: answerElements,
          options: options, // Pass the validated List<String>
          qstContrib: qstContrib,
          db: db!, // Use non-null assertion after lock check
          citation: citation,
          concepts: concepts,
          subjects: subjects,
        );
        break;

      default:
        _dbMonitor.releaseDatabaseAccess(); // Release lock before throwing
        throw UnimplementedError('Adding questions of type \'$questionType\' is not yet supported.');
    }

    // --- 3. Release DB Lock ---
    // Release lock *after* try-catch completes. 
    // Adheres to no-finally, but assumes DB operations don't hang indefinitely on error.
    await updateModuleActivationStatus(userId!, moduleName, true, db);
    // TODO validateAll is very inefficient, should probably write a proper function that just adds the userRecord directly to the unprocessedCache and to the table (works but slower at scale)
    _dbMonitor.releaseDatabaseAccess();
    await buildModuleRecords();

    db = await _dbMonitor.requestDatabaseAccess();
    await validateAllModuleQuestions(db!, userId!);
    _dbMonitor.releaseDatabaseAccess();
    
    QuizzerLogger.logMessage('SessionManager.addNewQuestion: DB access released.');
    
    // --- 4. Return Result ---
    response = {};
    return response;
  }

  // TODO Need a service feature that enables text to speech, take in String input, send to service, return audio recording. UI will use this api call to get an audio recording, receive it, then play it.
  // To test in isolation we will generate a few sentences and then pass to service, save the audio recording to a file, then use a different software to play it.

  /// Fetches the full details of a question by its ID (for UI preview, editing, etc.)
  Future<Map<String, dynamic>> fetchQuestionDetailsById(String questionId) async {
    final dbMonitor = getDatabaseMonitor();
    final db = await dbMonitor.requestDatabaseAccess();
    if (db == null) {
      QuizzerLogger.logError('Failed to acquire database access in fetchQuestionDetailsById');
      throw StateError('Could not acquire database access');
    }
    final details = await q_pairs_table.getQuestionAnswerPairById(questionId, db);
    dbMonitor.releaseDatabaseAccess();
    return details;
  }

  /// Updates an existing question in the question_answer_pairs table.
  /// Returns the number of rows affected (should be 1 if successful).
  Future<int> updateExistingQuestion({
    required String questionId,
    String? citation,
    List<Map<String, dynamic>>? questionElements,
    List<Map<String, dynamic>>? answerElements,
    List<int>? indexOptionsThatApply,
    bool? ansFlagged,
    String? ansContrib,
    String? concepts,
    String? subjects,
    String? qstReviewer,
    bool? hasBeenReviewed,
    bool? flagForRemoval,
    String? moduleName,
    String? questionType,
    List<Map<String, dynamic>>? options,
    int? correctOptionIndex,
    List<Map<String, dynamic>>? correctOrderElements,
    String? originalModuleName, // NEW optional parameter
  }) async {
    // Fail fast if not logged in
    assert(userId != null, 'User must be logged in to update a question.');
    Database? db = await _dbMonitor.requestDatabaseAccess();
    assert(db != null, 'Failed to acquire database access to update question.');
    final int result = await q_pairs_table.editQuestionAnswerPair(
      questionId: questionId,
      db: db!,
      citation: citation,
      questionElements: questionElements,
      answerElements: answerElements,
      indexOptionsThatApply: indexOptionsThatApply,
      ansFlagged: ansFlagged,
      ansContrib: ansContrib,
      concepts: concepts,
      subjects: subjects,
      qstReviewer: qstReviewer,
      hasBeenReviewed: hasBeenReviewed,
      flagForRemoval: flagForRemoval,
      moduleName: moduleName,
      questionType: questionType,
      options: options,
      correctOptionIndex: correctOptionIndex,
      correctOrderElements: correctOrderElements,
    );
    _dbMonitor.releaseDatabaseAccess();

    // Only update the affected modules
    if (originalModuleName != null && moduleName != null && originalModuleName != moduleName) {
      // If the module name changed, update both the old and new modules
      await buildSpecificModuleRecords([originalModuleName, moduleName]);
    } else if (moduleName != null) {
      // Only update the current module
      await buildSpecificModuleRecords([moduleName]);
    }
    return result;
  }

  /// Fetches a module record by its name, including up-to-date question IDs.
  Future<Map<String, dynamic>> fetchModuleByName(String moduleName) async {
    assert(userId != null, 'User must be logged in to fetch a module.');
    Database? db = await _dbMonitor.requestDatabaseAccess();
    final module = await modules_table.getModule(moduleName, db!);
    _dbMonitor.releaseDatabaseAccess();
    return module!;
  }

  // =====================================================================
  // --- User Settings API ---
  // =====================================================================

  /// Updates a specific user setting in the local database.
  /// Triggers outbound sync.
  Future<void> updateUserSetting(String settingName, dynamic newValue) async {
    assert(userId != null, 'User must be logged in to update a setting.');
    Database? db;
    
    db = await _dbMonitor.requestDatabaseAccess();

    await user_settings_table.updateUserSetting(userId!, settingName, newValue, db!);
    QuizzerLogger.logSuccess('SessionManager: User setting \"$settingName\" updated locally.');
    
    // Release database access directly after operations
    _dbMonitor.releaseDatabaseAccess();
  }

  /// Fetches user settings from the local database.
  ///
  /// Can fetch a single setting by [settingName], a list of settings by [settingNames],
  /// or all settings if [getAll] is true.
  /// Throws an ArgumentError if more than one mode is specified or if no mode is specified.
  Future<dynamic> getUserSettings({
    String? settingName,
    List<String>? settingNames,
    bool getAll = false,
  }) async {
    assert(userId != null, 'User must be logged in to get settings.');

    final int modesSpecified = (settingName != null ? 1 : 0) +
                               (settingNames != null ? 1 : 0) +
                               (getAll ? 1 : 0);
    if (modesSpecified == 0) {
      throw ArgumentError('No mode specified for getUserSettings. Provide settingName, settingNames, or set getAll to true.');
    }
    if (modesSpecified > 1) {
      throw ArgumentError('Multiple modes specified for getUserSettings. Only one of settingName, settingNames, or getAll can be used.');
    }

    Database? db;
    db = await _dbMonitor.requestDatabaseAccess();
    assert(db != null, 'Failed to acquire database access to get user settings.');

    final String currentUserRole = userRole; // Get current user's role
    dynamic resultToReturn;

    String operationMode;
    if (getAll) {
      operationMode = "all";
    } else if (settingName != null) {
      operationMode = "single";
    } else { 
      operationMode = "list";
    }

    switch (operationMode) {
      case "all":
        QuizzerLogger.logMessage('SessionManager: Getting all user settings for user $userId (Role: $currentUserRole).');
        final Map<String, Map<String, dynamic>> allSettingsWithFlags = await user_settings_table.getAllUserSettings(userId!, db!);
        final Map<String, dynamic> filteredSettings = {};
        allSettingsWithFlags.forEach((key, settingDetails) {
          final bool isAdminSetting = (settingDetails['is_admin_setting'] as int? ?? 0) == 1;
          if (!isAdminSetting || currentUserRole == 'admin' || currentUserRole == 'contributor') {
            filteredSettings[key] = settingDetails['value'];
          }
        });
        resultToReturn = filteredSettings;
        break;
      case "single":
        QuizzerLogger.logMessage('SessionManager: Getting setting \"$settingName\" for user $userId (Role: $currentUserRole).');
        final Map<String, dynamic>? settingDetails = await user_settings_table.getSettingValue(userId!, settingName!, db!);
        if (settingDetails != null) {
          final bool isAdminSetting = (settingDetails['is_admin_setting'] as int? ?? 0) == 1;
          if (!isAdminSetting || currentUserRole == 'admin' || currentUserRole == 'contributor') {
            resultToReturn = settingDetails['value'];
          } else {
            resultToReturn = null; // Admin setting, non-admin/contributor user
            QuizzerLogger.logWarning('SessionManager: Access denied for user $userId (Role: $currentUserRole) to admin/contributor setting \"$settingName\".');
          }
        } else {
          resultToReturn = null; // Setting not found
        }
        break;
      case "list":
        QuizzerLogger.logMessage('SessionManager: Getting specific settings for user $userId (Role: $currentUserRole): ${settingNames!.join(", ")}.');
        final Map<String, dynamic> listedResults = {};
        for (final name in settingNames) {
          final Map<String, dynamic>? settingDetails = await user_settings_table.getSettingValue(userId!, name, db!);
          if (settingDetails != null) {
            final bool isAdminSetting = (settingDetails['is_admin_setting'] as int? ?? 0) == 1;
            if (!isAdminSetting || currentUserRole == 'admin' || currentUserRole == 'contributor') {
              listedResults[name] = settingDetails['value'];
            }
            // If it's an admin setting and user is not admin/contributor, we simply don't add it to the map for listedResults.
          }
          // If settingDetails is null (not found), it's also not added.
        }
        resultToReturn = listedResults;
        break;
    }

    _dbMonitor.releaseDatabaseAccess();
    return resultToReturn;
  }

  // =====================================================================
  // --- Review System Interface ---

  /// Fetches a random question requiring review from the backend.
  ///
  /// Returns a map containing:
  /// - \'data\': The decoded question data map, or null if none/error.
  /// - \'source_table\': The name of the table the question came from, or null.
  /// - \'primary_key\': The map representing the primary key(s) for deletion, or null.
  /// - \'error\': An error message string if applicable, or null.
  Future<Map<String, dynamic>> getReviewQuestion() async {
    QuizzerLogger.logMessage('SessionManager: Requesting a question for review...');
    // Directly call the function without the alias
    return getRandomQuestionToBeReviewed();
  }

  /// Submits a review decision (approve or deny) for a question.
  ///
  /// Args:
  ///   isApproved: Boolean indicating if the question is approved (true) or denied (false).
  ///   questionDetails: The full, potentially edited, decoded question data map.
  ///                    **Required only if isApproved is true.**
  ///   sourceTable: The name of the review table the question originated from.
  ///   primaryKey: The map representing the primary key(s) to identify the record in the source table.
  ///
  /// Returns:
  ///   `true` if the operation (approve/deny) was successful, `false` otherwise.
  Future<bool> submitReview({
    required bool isApproved,
    Map<String, dynamic>? questionDetails, // Required only for approval
    required String sourceTable,
    required Map<String, dynamic> primaryKey,
  }) async {
    QuizzerLogger.logMessage('SessionManager: Submitting review decision (Approved: $isApproved) for PK: $primaryKey from $sourceTable');

    if (isApproved) {
      // Check if questionDetails are provided for approval
      if (questionDetails == null) {
        QuizzerLogger.logError('submitReview: questionDetails are required for approving a question.');
        // Fail Fast: Throw an error if essential data for the operation is missing.
        throw ArgumentError('questionDetails cannot be null when approving a question.');
      }
      // Call the approve function without the alias
      return approveQuestion(questionDetails, sourceTable, primaryKey);
    } else {
      // Call the deny function without the alias
      return denyQuestion(sourceTable, primaryKey);
    }
  }

  // --- End Review System Interface ---

  // Modify/replace the existing reportError or add this as the primary error reporting API
  // ================================================================================
  // --- Error Reporting Functionality ---
  // ================================================================================
  // --------------------------------------------------------------------------------
  /// Reports an error to the backend. This can be used for both new errors
  /// and for adding feedback to existing errors.
  ///
  /// If an [id] is provided, it attempts to update the existing error log
  /// primarily with [userFeedback].
  /// If no [id] is provided, a new error log is created. [errorMessage] is
  /// required in this case.
  ///
  /// **CRITICAL NOTE:** This method uses a direct, unlocked database connection via
  /// `getDirectDatabaseAccessForCriticalLogging()` to ensure that error logging
  /// has the highest chance of succeeding even if the main database access is locked
  /// (e.g., due to the error being reported). This bypasses normal safety locks
  /// and should ONLY be used here.
  ///
  /// Returns:
  ///   The ID of the created or updated error log record.
  Future<String> reportError({
    String? id, 
    String? errorMessage, 
    String? userFeedback,
  }) async {
    await initializationComplete;

    if (id == null && (errorMessage == null || errorMessage.isEmpty)) {
      QuizzerLogger.logError('reportError: Attempted to create a new error log without an error message.');
      throw ArgumentError('errorMessage must be provided when creating a new error log.');
    }

    // CRITICAL: Use direct, unlocked database access for error reporting.
    // This bypasses the standard locking mechanism to ensure logs can be written
    // even if the database monitor is locked up by the error that occurred.
    final Database? db = await _dbMonitor.getDirectDatabaseAccessForCriticalLogging();
    
    // Assert db is not null, as direct access should always provide it or throw earlier.
    assert(db != null, 'CRITICAL: Direct database access for error logging failed to return a DB instance.');

    // Call the upsertErrorLog function from error_logs_table.dart
    // this.userId can be null if no user is logged in, which is handled by upsertErrorLog.
    final String resultId = await upsertErrorLog(
      db: db!, // Safe to use ! due to assertion
      id: id,
      userId: userId,
      errorMessage: errorMessage,
      userFeedback: userFeedback,
    );

    // DO NOT call _dbMonitor.releaseDatabaseAccess() here because no lock was acquired.
    QuizzerLogger.logSuccess('Error report processed using direct DB access. Log ID: $resultId');
    return resultId;
  }
}

// Global instance
final SessionManager _globalSessionManager = SessionManager();

/// Gets the global session manager instance
SessionManager getSessionManager() => _globalSessionManager;
