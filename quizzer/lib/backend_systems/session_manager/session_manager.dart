import 'package:quizzer/backend_systems/07_user_question_management/user_question_processes.dart' show validateAllModuleQuestions;
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart' as q_pairs_table;
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart' as uqap_table;
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_attempts_table.dart' as attempt_table;
import 'package:quizzer/backend_systems/03_account_creation/new_user_signup.dart' as account_creation;
import 'package:quizzer/backend_systems/04_module_management/module_updates_process.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/04_module_management/module_isolates.dart';
import 'package:quizzer/backend_systems/02_login_authentication/user_auth.dart';
import 'package:quizzer/backend_systems/session_manager/session_isolates.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive/hive.dart';
import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/pre_process_worker.dart';
import 'package:path/path.dart' as p; // Use alias to avoid conflicts
import 'dart:async'; // For Completer
import 'dart:io'; // For Directory
import 'dart:convert'; // For jsonEncode

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
import 'package:quizzer/backend_systems/06_question_queue_server/switch_board.dart'; // Import SwitchBoard
import 'package:quizzer/backend_systems/session_manager/session_helper.dart';
import 'package:quizzer/backend_systems/session_manager/session_answer_validation.dart' as answer_validator;



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
  
  bool                  get showingAnswer             => _isAnswerDisplayed;
  int?                  get optionSelected            => _multipleChoiceOptionSelected;
  DateTime?             get timeQuestionDisplayed     => _timeDisplayed;
  DateTime?             get timeAnswerGiven           => _timeAnswerGiven;

  // --- Getters for Static Question Data (_currentQuestionDetails) ---
  // Assumes _currentQuestionDetails is non-null when accessed (post requestNextQuestion)
  String                      get currentQuestionType           => _currentQuestionDetails!['question_type'] 
  as String;
  
  String                      get currentQuestionId             => _currentQuestionDetails!['question_id'] 
  as String;

  List<Map<String, dynamic>>  get currentQuestionElements       => _currentQuestionDetails!['question_elements'] 
  as List<Map<String, dynamic>>;

  List<Map<String, dynamic>>  get currentQuestionAnswerElements => _currentQuestionDetails!['answer_elements'] 
  as List<Map<String, dynamic>>;

  List<String>                get currentQuestionOptions        => _currentQuestionDetails!['options'] 
  as List<String>; // Parsed in DB layer

  int?                        get currentCorrectOptionIndex     => _currentQuestionDetails!['correct_option_index'] as int?; // Nullable if not MC or not set

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

    // --- Start new background processing pipeline --- 
    final PreProcessWorker preProcessWorker = PreProcessWorker();
    preProcessWorker.start(); // Worker now fetches userId internally
    // -------------------------------------------------

    // --- Wait for Presentation Selection Worker initial loop completion --- 
    final psw = PresentationSelectionWorker();
    await psw.onInitialLoopComplete.first; // Waits for the signal
    // ----------------------------------------------------------------------

    // TODO: Implement separate data sync process initialization if needed

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
  /// TODO clear sessionState function (to be called when logout is called)

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
    }
    return response; // Response information is for front-end UI, not necessary for backend
  }

  //  --------------------------------------------------------------------------------
  /// TODO Logout function that will call the clearSessionState function (also not written)
  /// 
  /// 
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
     final String  questionType  = currentQuestionType; // Use getter
     final String  questionId    = currentQuestionId;     // Use getter
  
      // TODO: Implement correctness logic for all question types
      switch (questionType) {
        case 'multiple_choice':
          final int? correctIndex = currentCorrectOptionIndex;
          isCorrect = answer_validator.validateMultipleChoiceAnswer(
            userAnswer: userAnswer,
            correctIndex: correctIndex,
          );
          break;
        // case 'sort_order':
        //   // Compare userAnswer (List?) with currentCorrectOrder
        //   isCorrect = /* ... comparison logic ... */ ;
        //   break;
        // case 'text_input':
        //   // Compare userAnswer (String?) with currentQuestionAnswerElements
        //   isCorrect = /* ... comparison logic ... */ ;
        //   break;
        default:
           throw UnimplementedError('Correctness check not implemented for question type: $questionType');
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

     // Explicitly increment total_attempts using the dedicated function
     await uqap_table.incrementTotalAttempts(userId!, questionId, db);

      // Release lock AFTER successful operations
      _dbMonitor.releaseDatabaseAccess();

    // --- 7. Update In-Memory State ---
    _currentQuestionRecord = updatedUserRecord;

    return {'success': true, 'message': 'Answer submitted successfully.'};
  }

}

// Global instance
final SessionManager _globalSessionManager = SessionManager();

/// Gets the global session manager instance
SessionManager getSessionManager() => _globalSessionManager;
