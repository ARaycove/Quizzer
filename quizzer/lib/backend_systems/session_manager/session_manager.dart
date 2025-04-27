import 'package:quizzer/backend_systems/03_account_creation/new_user_signup.dart' as account_creation;
import 'package:quizzer/backend_systems/04_module_management/module_updates_process.dart';
import 'package:quizzer/backend_systems/05_question_answer_pairs/question_isolates.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/04_module_management/module_isolates.dart';
import 'package:quizzer/backend_systems/02_login_authentication/user_auth.dart';
import 'package:quizzer/backend_systems/session_manager/session_isolates.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_helper_utils/utils.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive/hive.dart';
import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/pre_process_worker.dart';
import 'package:path/path.dart' as p; // Use alias to avoid conflicts
import 'dart:io'; // For Directory
import 'dart:async'; // For Completer
import 'package:path_provider/path_provider.dart'; // For mobile path
import 'package:quizzer/backend_systems/07_user_question_management/user_question_processes.dart' show validateAllModuleQuestions;
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
import 'package:quizzer/backend_systems/06_question_queue_server/switch_board.dart'; // Import SwitchBoard
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart' as q_pairs_table; // Import for question details

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
  // MetaData
              DateTime?                       sessionStartTime;
  // Page history tracking
  final       List<String>                    _pageHistory = [];
  static const  int                           _maxHistoryLength = 12;
  final       ToggleScheduler                 _toggleScheduler = getToggleScheduler(); // Get scheduler instance      
  
          
  // --- Public Getters for UI State ---
  Map<String, dynamic>? get currentQuestionUserRecord => _currentQuestionRecord;
  Map<String, dynamic>? get currentQuestionStaticData => _currentQuestionDetails;
  String?               get currentQuestionType       => _currentQuestionType;
  bool                  get showingAnswer             => _isAnswerDisplayed;
  int?                  get optionSelected            => _multipleChoiceOptionSelected;
  DateTime?             get timeQuestionDisplayed     => _timeDisplayed;
  DateTime?             get timeAnswerGiven           => _timeAnswerGiven;

  // --- State Reset Functions ---
  
  /// Reset only the state related to the currently displayed question.
  void _clearQuestionState() {
    _currentQuestionRecord        = null;  // User-specific data
    _currentQuestionDetails       = null;  // Static data (QPair)
    _currentQuestionType          = null;
    _isAnswerDisplayed            = false;
    _multipleChoiceOptionSelected = null;
    _timeDisplayed                = null;
    _timeAnswerGiven              = null;
    
    QuizzerLogger.logMessage('Current Question state has been reset');
  }
  // --------------------------

  /// Builds placeholder records for display when the question queue is empty.
  Map<String, Map<String, dynamic>> _buildDummyNoQuestionsRecord() {
    const String dummyId = "dummy_no_questions";
    
    // Mimics the structure of a user-question record (UQPair)
    final Map<String, dynamic> dummyUserRecord = {
      'question_id': dummyId,
      // Add other UQPair fields with default/placeholder values if needed by UI
      'revision_streak': 0, 
      'next_revision_due': DateTime.now().toIso8601String(), 
      // etc. - keeping minimal for now
    };

    // Mimics the structure of a static question details record (QPair)
    final Map<String, dynamic> dummyStaticDetails = {
      'question_id': dummyId,
      'question_type': 'multiple_choice', // Use multiple choice as requested
      // Format follows the parsed structure from getQuestionAnswerPairById
      'question_elements': [{'type': 'text', 'content': 'No new questions available right now. Check back later!'}], 
      'answer_elements': [{'type': 'text', 'content': ''}], // Empty answer
      'options': ['Okay', 'Add new modules', 'Check Back Later!'], 
      'correct_option_index': 0, // Index of the 'Okay' option (or -1 if no default correct)
      'module_name': 'System', // Placeholder module
      'subjects': '', // Placeholder subjects
      'concepts': '', // Placeholder concepts
      // Add other QPair fields with default/placeholder values if required by UI
      'time_stamp': DateTime.now().millisecondsSinceEpoch.toString(),
      'qst_contrib': 'system',
      'ans_contrib': 'system',
      'citation': '',
      'ans_flagged': false,
      'has_been_reviewed': true,
      'flag_for_removal': false,
      'completed': true, 
      'correct_order': '', // Empty for non-sort_order
    };

    return {
      'userRecord': dummyUserRecord,
      'staticDetails': dummyStaticDetails,
    };
  }

  // Initialize Hive storage (private)
  Future<void> _initializeStorage() async {
    String hivePath;
    // Determine path based on platform (like original main_native)
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop / Test environment: Use runtime_cache/hive
      hivePath = p.join(Directory.current.path, 'runtime_cache', 'hive');
      QuizzerLogger.logMessage("Platform: Desktop/Test. Setting Hive path to: $hivePath");
    } else {
      // Mobile: Use standard application documents directory
      // Assert that path_provider is available if this branch is hit
      final appDocumentsDir = await getApplicationDocumentsDirectory();
      hivePath = appDocumentsDir.path;
      QuizzerLogger.logMessage("Platform: Mobile. Setting Hive path to: $hivePath");
    }
    // Ensure the directory exists
    Directory(hivePath).createSync(recursive: true);
    Hive.init(hivePath);
    QuizzerLogger.logMessage('SessionManager: Hive initialized at $hivePath.');

    QuizzerLogger.logMessage("SessionManager: Opening Hive box 'async_prefs'...");
    _storage = await Hive.openBox('async_prefs');
    QuizzerLogger.logMessage("SessionManager: Hive box 'async_prefs' opened.");
  }

  // SessionManager Constructor (Initializes Supabase and starts async init)
  SessionManager._internal()
      // Initialize cache instance variables
      : _unprocessedCache = UnprocessedCache(),
        _nonCirculatingCache = NonCirculatingQuestionsCache(),
        _moduleInactiveCache = ModuleInactiveCache(),
        _circulatingCache = CirculatingQuestionsCache(),
        _dueDateBeyondCache = DueDateBeyond24hrsCache(),
        _dueDateWithinCache = DueDateWithin24hrsCache(),
        _eligibleCache = EligibleQuestionsCache(),
        _queueCache = QuestionQueueCache(),
        _historyCache = AnswerHistoryCache(),
        _switchBoard = SwitchBoard() // Initialize SwitchBoard
         {
    supabase = SupabaseClient(
      'https://yruvxuvzztnahuuiqxit.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlydXZ4dXZ6enRuYWh1dWlxeGl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQzMTY1NDIsImV4cCI6MjA1OTg5MjU0Mn0.hF1oAILlmzCvsJxFk9Bpjqjs3OEisVdoYVZoZMtTLpo',
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
    QuizzerLogger.logMessage('SessionManager instance created. Starting async initialization...');
    // Start async initialization but don't wait for it here.
    // Complete the completer when done or if an error occurs.
    _initializeStorage().then((_) {
      QuizzerLogger.logMessage('SessionManager async initialization successful.');
      _initializationCompleter.complete();
    }).catchError((error, stackTrace) {
      QuizzerLogger.logError('SessionManager async initialization failed: $error\n$stackTrace');
      _initializationCompleter.completeError(error, stackTrace);
      // Decide how to handle critical init failure - maybe rethrow?
      // For now, just completing with error lets awaiters handle it.
    });
  }

  /// Initialize the SessionManager and its dependencies
  /// This 
  Future<void> _initializeLogin(String email) async {
    userLoggedIn = true;
    userEmail = email;
    userId = await initializeSession({'email': email});
    assert(userId != null, "Failed to retrieve userId during login initialization.");
    sessionStartTime = DateTime.now();

    // --- Start new background processing pipeline --- 
    QuizzerLogger.logMessage('SessionManager: Starting PreProcessWorker...');
    final PreProcessWorker preProcessWorker = PreProcessWorker();
    preProcessWorker.start(); // Worker now fetches userId internally
    QuizzerLogger.logMessage('SessionManager: PreProcessWorker started.');
    // -------------------------------------------------

    // --- Wait for Presentation Selection Worker initial loop completion --- 
    final psw = PresentationSelectionWorker();
    QuizzerLogger.logMessage('SessionManager: Waiting for PresentationSelectionWorker initial loop completion signal...');
    await psw.onInitialLoopComplete.first; // Waits for the signal
    QuizzerLogger.logSuccess('SessionManager: PresentationSelectionWorker initial loop completed signal received.');
    // ----------------------------------------------------------------------

    // TODO: Implement separate data sync process initialization if needed

    QuizzerLogger.logMessage('SessionManager post-worker-start initialization complete');
  }
  /// ==================================================================================
  // API CALLS
  //  ------------------------------------------------
  // Create New User Account
  // INSERT ONLY HERE
  /// Creates a new user account with Supabase and local database
  /// Returns true if successful, false otherwise
  /// BOILER PLATE COMPLETE DO NOT FUCKING TOUCH
  Future<Map<String, dynamic>> createNewUserAccount({
    required String email,
    required String username,
    required String password,
  }) async {
    QuizzerLogger.logMessage('Session Manager: Routing signup request');
    return await account_creation.handleNewUserProfileCreation({
      'email': email,
      'username': username,
      'password': password,
    }, supabase, _dbMonitor);
  }
  //  ------------------------------------------------
  // Login User
  // This initializing spins up sub-system processes that rely on the user profile information
  Future<Map<String, dynamic>> attemptLogin(String email, String password) async {
    // Ensure async initialization is complete before proceeding
    await initializationComplete;
    QuizzerLogger.logMessage('Session Manager: Initialization complete. Attempting login for $email');

    // Now it's safe to access _storage
    final response = await userAuth(
      email: email,
      password: password,
      supabase: supabase,
      storage: _storage,
    );

    if (response['success'] == true) {
      await _initializeLogin(email); // initialize function spins up necessary background processes
    }
    return response; // Response information is for front-end UI, not necessary for backend
  }
  //  ------------------------------------------------
  // Manage Page History
  // Add page to history
  void addPageToHistory(String routeName) {
    QuizzerLogger.logMessage('Current page history: $_pageHistory');
    if (_pageHistory.isNotEmpty && _pageHistory.last == routeName) {
      QuizzerLogger.logMessage('Skipping duplicate page: $routeName');
      return; // Don't add duplicate consecutive pages
    }
    _pageHistory.add(routeName);
    if (routeName == "/home") {
      buildModuleRecords();
      }
    if (_pageHistory.length > _maxHistoryLength) {
      QuizzerLogger.logMessage('Removing oldest page: ${_pageHistory[0]}');
      _pageHistory.removeAt(0);
    }
    QuizzerLogger.logMessage('Updated page history: $_pageHistory');
  }

  // Get previous page, now including /menu if it was the actual previous page
  String getPreviousPage() {
    QuizzerLogger.logMessage('Attempting to get previous page. Current history: $_pageHistory');
    // Check if there are at least two pages in history
    if (_pageHistory.length >= 2) {
      // Return the second-to-last entry
      final previousPage = _pageHistory[_pageHistory.length - 2];
      QuizzerLogger.logMessage('Returning previous page: $previousPage');
      return previousPage;
    } else {
      // If history has 0 or 1 entries, default to /home
      QuizzerLogger.logMessage('History has less than 2 entries. Defaulting to /home.');
      return '/home';
    }
  }

  // Clear page history
  void clearPageHistory() {
    QuizzerLogger.logMessage('Current page history: $_pageHistory');
    _pageHistory.clear();
    QuizzerLogger.logMessage('Page history cleared');
  }

  //  ------------------------------------------------
  // Module management API
  // API for loading module names and their activation status
  Future<Map<String, dynamic>> loadModules() async {
    assert(userId != null);
    QuizzerLogger.logMessage('Loading modules for user: $userId');
    return await handleLoadModules({
      'userId': userId,
    });
  }

  // API for activating or deactivating a module (Reverted to direct execution - Attempt 3)
  Future<void> toggleModuleActivation(String moduleName, bool activate) async {
    assert(userId != null);
    QuizzerLogger.logMessage('Toggling module activation for user: $userId, module: $moduleName, activate: $activate');
    
    // 1. Request slot from scheduler, passing module/state
    await _toggleScheduler.requestToggleSlot();
    QuizzerLogger.logMessage('Toggle slot acquired for $moduleName -> $activate');

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
        QuizzerLogger.logMessage('SessionManager (toggle - validation): Database access denied, waiting...');
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }

    // 2. Validate profile questions (needs DB)
    await validateAllModuleQuestions(db, userId!); 

    // --- Release DB lock immediately after validation ---
    _dbMonitor.releaseDatabaseAccess(); 
    QuizzerLogger.logMessage('SessionManager (toggle - validation): DB released for $moduleName toggle.');
    db = null; // Prevent accidental reuse
    // ----------------------------------------------------

    // 3. Signal deactivation if needed, then flush other caches
    if (!activate) {
       QuizzerLogger.logMessage('SessionManager: Signaling SwitchBoard for deactivated module: $moduleName');
       _eligibleCache.flushToDueDateWithin24hrsCache();
       
    } else {
      _switchBoard.signalModuleActivated(moduleName);
    }
    
    // 4. Release slot AFTER all work is done
    await _toggleScheduler.releaseToggleSlot();
    QuizzerLogger.logMessage('Toggle slot released for $moduleName -> $activate');
    // --- End Direct Execution Logic ---
  }

  // API for updating a module's description
  Future<bool> updateModuleDescription(String moduleName, String newDescription) async {
    assert(userId != null);
    
    QuizzerLogger.logMessage('Updating module description for module: $moduleName');
    return await handleUpdateModuleDescription({
      'moduleName': moduleName,
      'description': newDescription,
    });
  }
  
  // --- Private Helper Functions ---
  
  /// Checks if the necessary session state is valid before submitting an answer.
  bool _isCurrentQuestionStateValidForSubmission() {
    if (_currentQuestionRecord == null) {
      QuizzerLogger.logError("Cannot submit answer: _currentQuestionRecord is null.");
      return false;
    }
    // Check for question_id existence within the record
    if (_currentQuestionRecord!['question_id'] == null) {
        QuizzerLogger.logError("Cannot submit answer: question_id is missing from record.");
        return false;
    }
    if (_timeDisplayed == null) {
      QuizzerLogger.logError("Cannot submit answer: _timeDisplayed is null.");
      return false;
    }
    if (_timeAnswerGiven == null) {
      // This should have been set by setAnswerDisplayed(true)
      QuizzerLogger.logError("Cannot submit answer: _timeAnswerGiven is null.");
      return false;
    }
    // Check for selected option, crucial for determining correctness
    // If other question types are added later, this might need adjustment
    if (_multipleChoiceOptionSelected == null && _currentQuestionType == 'multiple_choice') {
      QuizzerLogger.logWarning("Submitting answer for multiple choice, but _multipleChoiceOptionSelected is null.");
      // Depending on requirements, could return false here if an option MUST be selected
      // return false;
    }
    // All essential checks passed
    return true;
  }
  // ------------------------------

  // ==========================================
  // Public Question Flow API
  // ==========================================

  /// Retrieves the next question, updates state, and makes it available via getters.
  Future<void> requestNextQuestion() async {
    QuizzerLogger.logMessage('SessionManager: requestNextQuestion called.');
    if (userId == null) {
       QuizzerLogger.logError('requestNextQuestion called without a logged-in user.');
       throw StateError('User must be logged in to request a question.');
    }

    // 1. Flush current question record (if exists) to UnprocessedCache
    if (_currentQuestionRecord != null) {
        QuizzerLogger.logMessage('Flushing current question (${_currentQuestionRecord!['question_id']}) to UnprocessedCache.');
        await _unprocessedCache.addRecord(_currentQuestionRecord!); 
    }

    // 2. Clear existing question state
    _clearQuestionState();

    // 3. Get next user record from QuestionQueueCache
    QuizzerLogger.logMessage('Fetching next question from QuestionQueueCache...');
    final Map<String, dynamic> newUserRecord = await _queueCache.getAndRemoveRecord();

    if (newUserRecord.isEmpty) {
        QuizzerLogger.logWarning('QuestionQueueCache is empty. Displaying dummy record.');
        // --- Build and set dummy question state ---
        final dummyRecords = _buildDummyNoQuestionsRecord();
        _currentQuestionRecord = null;
        _currentQuestionDetails = dummyRecords['staticDetails'];
        _currentQuestionType = _currentQuestionDetails!['question_type'] as String; // Should be 'multiple_choice'
        _timeDisplayed = DateTime.now();
        QuizzerLogger.logMessage('Set dummy \'no questions\' state.');
        // --- Dummy state set, stop processing ---
        return; 
    }
    
    // --- If queue was NOT empty, proceed as before ---
    _currentQuestionRecord = newUserRecord;
    final String questionId = _currentQuestionRecord!['question_id'] as String;
    QuizzerLogger.logMessage('Retrieved user record for question ID: $questionId from queue.');

    // 4. Get static question details from DB (Fail Fast)
    Database? db;
    Map<String, dynamic> staticDetails = {};

    // --- Acquire DB Lock (Fail Fast - throw if unavailable) ---
    QuizzerLogger.logMessage('Acquiring DB lock to fetch static details for $questionId...');
    db = await _dbMonitor.requestDatabaseAccess();
    if (db == null) {
        QuizzerLogger.logError('SessionManager (requestNextQuestion): Failed to acquire DB lock immediately.');
        throw StateError('Database lock unavailable while fetching question details.');
    }
    QuizzerLogger.logMessage('DB lock acquired.');
    // ---------------------------------------------------------

    // Fetch details - Let exceptions propagate (Fail Fast)
    staticDetails = await q_pairs_table.getQuestionAnswerPairById(questionId, db);
    QuizzerLogger.logMessage('Fetched static details for $questionId.');

    // --- Release DB Lock (After successful operation) ---
    _dbMonitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('DB lock released after fetching static details.');
    // ----------------------

    // 5. Update state with new details
    _currentQuestionDetails = staticDetails;
    // Assert that the key exists and is not null before casting
    assert(_currentQuestionDetails!.containsKey('question_type') && _currentQuestionDetails!['question_type'] != null, 
           "Question details missing 'question_type'");
    // Directly cast to non-nullable String - will throw if not a String
    _currentQuestionType = _currentQuestionDetails!['question_type'] as String; 
    _timeDisplayed = DateTime.now();
    QuizzerLogger.logSuccess('Successfully set next question state for ID: $questionId (Type: $_currentQuestionType)');
  }
}

// Global instance
final SessionManager _globalSessionManager = SessionManager();

/// Gets the global session manager instance
SessionManager getSessionManager() => _globalSessionManager;
