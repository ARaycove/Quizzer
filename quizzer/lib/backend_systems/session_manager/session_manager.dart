import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile_table.dart';
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
import 'package:quizzer/backend_systems/12_switch_board/switch_board.dart'; // Import SwitchBoard
import 'package:quizzer/backend_systems/session_manager/session_helper.dart';
import 'package:quizzer/backend_systems/session_manager/session_answer_validation.dart' as answer_validator;
import 'package:quizzer/backend_systems/06_question_queue_server/circulation_worker.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/due_date_worker.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/eligibility_check_worker.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/outbound_sync/outbound_sync_worker.dart'; // Import the new worker



/*
TODO: Implement proper secure storage for the Hive encryption key.
The current implementation regenerates the key on each launch, making
persistent encrypted data inaccessible across sessions. This requires
a platform-aware secure storage mechanism (like flutter_secure_storage)
abstracted away from the SessionManager core logic to maintain backend
isolation while providing necessary security in the production app.
For now, offline persistence relies on unencrypted or obscure data.
*/

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

  // user State
              bool                            userLoggedIn = false;
              String?                         userId;
              String?                         userEmail;
              String?                         userRole;
  // Current Question information and booleans
              Map<String, dynamic>?           _currentQuestionRecord;         // userQuestionRecord
              Map<String, dynamic>?           _currentQuestionDetails;        // questionAnswerPairRecord
              String?                         _currentQuestionType;
              bool                            _isAnswerDisplayed = false;
              int?                            _multipleChoiceOptionSelected;  // would be null if no option is presently selected
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

    // Start background workers that don't depend on login state
    QuizzerLogger.logMessage("SessionManager Constructor: Starting OutboundSyncWorker...");
    final outboundSyncWorker = OutboundSyncWorker();
    outboundSyncWorker.start();
    QuizzerLogger.logSuccess("SessionManager Constructor: OutboundSyncWorker started.");
    // TODO: Start other non-login-dependent workers here if any
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

    // --- Start new background processing pipeline --- 
    final PreProcessWorker preProcessWorker = PreProcessWorker();
    preProcessWorker.start(); // Worker now fetches userId internally
    // -------------------------------------------------

    // --- Wait for Presentation Selection Worker initial loop completion --- 
    final psw = PresentationSelectionWorker();
    await psw.onInitialLoopComplete.first; // Waits for the signal
    // ----------------------------------------------------------------------

    // OutboundSyncWorker is now started in the constructor
    // TODO: Start InboundSyncWorker here when implemented

  }
  
  // =================================================================================
  // --- State Reset Functions ---
  // =================================================================================
  /// Reset only the state related to the currently displayed question.
  void _clearQuestionState() {
    _currentQuestionRecord        = null;  // User-specific data
    _currentQuestionDetails       = null;  // Static data (QPair)
    _currentQuestionType          = null;
    _isAnswerDisplayed            = false;
    _multipleChoiceOptionSelected = null;
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
    userRole = null;
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
    QuizzerLogger.printHeader("Starting User Logout Process...");

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
    
    // Stop them (await completion)
    await psw.stop();
    await dueDateWorker.stop();
    await circulationWorker.stop();
    await eligibilityWorker.stop();
    await preProcessWorker.stop(); 
    await inactiveModuleWorker.stop();
    await outboundSyncWorker.stop(); // Stop the outbound sync worker
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
    // TODO potential error here, when logging out ensure properly state reset of backend systems (_isRunning flags should terminate loops and force workers to reawait the start command)
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
    return await handleLoadModules({
      'userId': userId,
    });
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
    // TODO Need to include this in the full_session_test
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
    // TODO Need to include this in the full_session_test
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

    // 4. Get static question details from DB (Fail Fast)
    Database? db;
    Map<String, dynamic> staticDetails = {};

    // --- Acquire DB Lock (Fail Fast - throw if unavailable) ---
    db = await _dbMonitor.requestDatabaseAccess();
    if (db == null) {
        throw StateError('Database lock unavailable while fetching question details.');
    }
    // ---------------------------------------------------------

    // Fetch details - Let exceptions propagate (Fail Fast)
    staticDetails = await q_pairs_table.getQuestionAnswerPairById(questionId, db);

    // --- DIAGNOSTIC LOGGING --- 
    final dynamic fetchedOptions = staticDetails['options'];
    QuizzerLogger.logValue('SessionManager.requestNextQuestion: Fetched options type: ${fetchedOptions.runtimeType}, value: $fetchedOptions');
    // --- END DIAGNOSTIC LOGGING ---

    // --- Release DB Lock (After successful operation) ---
    _dbMonitor.releaseDatabaseAccess();
    // ----------------------

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
  
      // TODO: Implement correctness logic for all question types
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
       lastUpdated: updatedUserRecord['last_updated'] as String,
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

    final String timeStamp = DateTime.now().toIso8601String();
    final String qstContrib = userId!; // Use current user ID as the question contributor

    // --- 2. Database Operation (Lock Acquisition) --- 
    Database? db;
    int result = 0; // Initialize result
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

}

// Global instance
final SessionManager _globalSessionManager = SessionManager();

/// Gets the global session manager instance
SessionManager getSessionManager() => _globalSessionManager;
