import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/inactive_module_worker.dart';
import 'package:quizzer/backend_systems/07_user_question_management/user_question_processes.dart' show validateAllModuleQuestions;
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart' as q_pairs_table;
import 'package:quizzer/backend_systems/03_account_creation/new_user_signup.dart' as account_creation;
import 'package:quizzer/backend_systems/04_module_management/module_management.dart';
import 'package:quizzer/backend_systems/09_data_caches/past_due_cache.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:hive/hive.dart';
import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/06_question_queue_server/pre_process_worker.dart';
import 'dart:async'; // For Completer and StreamController
import 'dart:io'; // For Directory
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
import 'package:quizzer/backend_systems/09_data_caches/temp_question_details.dart'; // Added import
import 'package:quizzer/backend_systems/00_database_manager/review_system/get_send_postgre.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/error_logs_table.dart'; // Direct import
import 'package:quizzer/backend_systems/00_database_manager/tables/user_feedback_table.dart'; // Removed alias
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_settings_table.dart' as user_settings_table;
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart'; // Added for direct access
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/stat_update_aggregator.dart'; // do not use aliases in the import statements
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_eligible_questions_table.dart'; // Added import for user_stats_eligible_questions_table
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_non_circulating_questions_table.dart'; // Added import for user_stats_non_circulating_questions_table
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_in_circulation_questions_table.dart'; // Added import for user_stats_in_circulation_questions_table
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_revision_streak_sum_table.dart'; // Added import for user_stats_revision_streak_sum_table
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_total_user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_average_questions_shown_per_day_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_total_questions_answered_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_daily_questions_answered_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_average_daily_questions_learned_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_stats/user_stats_days_left_until_questions_exhaust_table.dart';


import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';

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
              
  // Submission data tracking for answered state reconstruction
              List<int>?                      _lastSubmittedCustomOrderIndices; // Order of indices when answer was submitted
              dynamic                         _lastSubmittedUserAnswer; // The actual answer that was submitted
              bool                            _lastSubmittedIsCorrect = false; // Whether the submitted answer was correct
  // MetaData
              DateTime?                       sessionStartTime;
  final       ToggleScheduler                 _toggleScheduler = getToggleScheduler(); // Get scheduler instance      
  
          
  // --- Public Getters for UI State ---
  Map<String, dynamic>? get currentQuestionUserRecord => _currentQuestionRecord;
  Map<String, dynamic>? get currentQuestionStaticData => _currentQuestionDetails;
  String?               get initialProfileLastModified => _initialProfileLastModified;
  // ADDED: Getter that dynamically determines user role from JWT
  String                get userRole => determineUserRoleFromSupabaseSession(supabase.auth.currentSession);
  
  // Login progress stream is now managed by SwitchBoard
  Stream<String> get loginProgressStream => _switchBoard.onLoginProgress;
  
  
  // int?                  get optionSelected            => _multipleChoiceOptionSelected;
  DateTime?             get timeQuestionDisplayed     => _timeDisplayed;
  DateTime?             get timeAnswerGiven           => _timeAnswerGiven;

  // --- Getters for Submission Data (for answered state reconstruction) ---
  List<int>?            get lastSubmittedCustomOrderIndices => _lastSubmittedCustomOrderIndices;
  dynamic               get lastSubmittedUserAnswer => _lastSubmittedUserAnswer;
  bool                  get lastSubmittedIsCorrect => _lastSubmittedIsCorrect;

  /// Sets the custom order indices for the current question (called by widgets before submission)
  void setCurrentQuestionCustomOrderIndices(List<int> customOrderIndices) {
    _lastSubmittedCustomOrderIndices = List<int>.from(customOrderIndices);
  }

  /// Sets the user answer for the current question (called by widgets before submission)
  void setCurrentQuestionUserAnswer(dynamic userAnswer) {
    _lastSubmittedUserAnswer = userAnswer;
  }

  /// Sets the correctness flag for the current question (called by widgets before submission)
  void setCurrentQuestionIsCorrect(bool isCorrect) {
    _lastSubmittedIsCorrect = isCorrect;
  }

  /// Clears all submission data for the current question
  void clearCurrentQuestionSubmissionData() {
    _lastSubmittedCustomOrderIndices = null;
    _lastSubmittedUserAnswer = null;
    _lastSubmittedIsCorrect = false;
  }

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
    final String hivePath = await getQuizzerHivePath();
    // Log the determined path before initializing Hive
    QuizzerLogger.logMessage('SessionManager: Initializing Hive at path: $hivePath');

    // Ensure the directory exists
    await Directory(hivePath).create(recursive: true); // Use async create
    Hive.init(hivePath);

    _storage = await Hive.openBox('async_prefs');
  }
  
  // =================================================================================
  // --- State Reset Functions ---
  // =================================================================================
  /// Reset only the state related to the currently displayed question.
  void _clearQuestionState() {
    try {
      QuizzerLogger.logMessage('Entering _clearQuestionState()...');
      
      _currentQuestionRecord        = null;  // User-specific data
      _currentQuestionDetails       = null;  // Static data (QPair)
      _currentQuestionType          = null;
      _timeDisplayed                = null;
      _timeAnswerGiven              = null;
      _isAnswerSubmitted            = false; // Reset the flag
      
      // Clear submission data tracking
      _lastSubmittedCustomOrderIndices = null;
      _lastSubmittedUserAnswer = null;
      _lastSubmittedIsCorrect = false;
      
      QuizzerLogger.logMessage('Successfully cleared question state');
    } catch (e) {
      QuizzerLogger.logError('Error in _clearQuestionState - $e');
      rethrow;
    }
  }

  /// Clears all session-specific user state.
  void _clearSessionState() {
    try {
      QuizzerLogger.logMessage('Entering _clearSessionState()...');
      
      userLoggedIn = false;
      userId = null;
      userEmail = null;
      sessionStartTime = null;
      _clearQuestionState(); // Clear current question state
      // Note: Does not stop workers or clear persistent storage, assumes logout function handles that.
      
      QuizzerLogger.logMessage('Successfully cleared session state');
    } catch (e) {
      QuizzerLogger.logError('Error in _clearSessionState - $e');
      rethrow;
    }
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
    try {
      QuizzerLogger.logMessage('Entering createNewUserAccount()...');
      
      final result = await account_creation.handleNewUserProfileCreation({
        'email': email,
        'username': username,
        'password': password,
      }, supabase);
      
      QuizzerLogger.logMessage('Successfully created new user account for email: $email');
      return result;
    } catch (e) {
      QuizzerLogger.logError('Error in createNewUserAccount - $e');
      rethrow;
    }
  }

  //  --------------------------------------------------------------------------------
    // Login User
  // This initializing spins up sub-system processes that rely on the user profile information
  Future<Map<String, dynamic>> attemptLogin(String email, String password) async {
    try {
      QuizzerLogger.logMessage('Entering attemptLogin()...');
      
      // Ensure async initialization is complete before proceeding
      QuizzerLogger.logMessage("Logging in user with email: $email");
      await initializationComplete;

      // Now it's safe to access _storage
      final response = await loginInitialization(
        email: email,
        password: password,
        supabase: supabase,
        storage: _storage,
      );

      if (response['success'] == true) {
        // If we reach this point, it means the question queue server is initialized and ready to go.
        await requestNextQuestion();
      }

      // Response information is for front-end UI, not necessary for backend
      // Send signal to UI that it's ok to login now
      QuizzerLogger.logMessage('Successfully completed attemptLogin for email: $email');
      return response;
    } catch (e) {
      QuizzerLogger.logError('Error in attemptLogin - $e');
      rethrow;
    }
  }

  //  --------------------------------------------------------------------------------
  /// Logs out the current user, stops workers, clears caches, and resets state.
  Future<void> logoutUser() async {
    try {
      QuizzerLogger.logMessage('Entering logoutUser()...');
      
      if (!userLoggedIn) {
        QuizzerLogger.logWarning("Logout called, but no user was logged in.");
        return;
      }

      // Store essential user info for operations within this logout function,
      // then immediately mark the user as logged out for the rest of the system.
      final String? currentUserIdForLogoutOps = userId; 
      final String? currentUserEmailForLogoutOps = userEmail;
      userLoggedIn = false; // Set userLoggedIn to false IMMEDIATELY.
      QuizzerLogger.logMessage("SessionManager: userLoggedIn flag set to false at the beginning of logoutUser.");
      QuizzerLogger.logMessage("Starting user logout process for user: $currentUserEmailForLogoutOps, Current UserID for final ops: $currentUserIdForLogoutOps");


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

      // Update total study time
      if (sessionStartTime != null && currentUserIdForLogoutOps != null) { // MODIFIED: Use stored userId
        final Duration elapsedDuration = DateTime.now().difference(sessionStartTime!); // Use non-null assertion
        final double hoursToAdd = elapsedDuration.inMilliseconds / (1000.0 * 60 * 60);


        QuizzerLogger.logMessage("Updating total study time for user $currentUserIdForLogoutOps..."); // MODIFIED: Use stored userId for logging
        await updateTotalStudyTime(currentUserIdForLogoutOps, hoursToAdd); // MODIFIED: Use stored userId
        QuizzerLogger.logSuccess("Total study time updated.");
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
      QuizzerLogger.logMessage('Successfully completed logoutUser');
    } catch (e) {
      QuizzerLogger.logError('Error in logoutUser - $e');
      rethrow;
    }
  }


  // =================================================================================
  // Module management Calls
  // =================================================================================
  // API for loading module names and their activation status
  Future<Map<String, dynamic>> loadModules() async {
    try {
      QuizzerLogger.logMessage('Entering loadModules()...');
      
      assert(userId != null);
      final result = await handleLoadModules({
        'userId': userId,
      });
      // The getAllModulesWithQuestionInfo function now handles all the data formatting
      
      QuizzerLogger.logMessage('Successfully loaded modules for user: $userId');
      return result;
    } catch (e) {
      QuizzerLogger.logError('Error in loadModules - $e');
      rethrow;
    }
  }

  //  --------------------------------------------------------------------------------
  // API for activating or deactivating a module (Reverted to direct execution - Attempt 3)
  Future<void> toggleModuleActivation(String moduleName, bool activate) async {
    try {
      QuizzerLogger.logMessage('Entering toggleModuleActivation()...');
      
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

      // 2. Validate profile questions (table function handles its own DB access)
      await validateAllModuleQuestions(userId!);

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
      
      QuizzerLogger.logMessage('Successfully toggled module activation for module: $moduleName, activate: $activate');
    } catch (e) {
      QuizzerLogger.logError('Error in toggleModuleActivation - $e');
      rethrow;
    }
  }

  //  --------------------------------------------------------------------------------
  // API for updating a module's description
  Future<bool> updateModuleDescription(String moduleName, String newDescription) async {
    try {
      QuizzerLogger.logMessage('Entering updateModuleDescription()...');
      
      assert(userId != null);
      
      final result = await handleUpdateModuleDescription({
        'moduleName': moduleName,
        'description': newDescription,
      });
      
      QuizzerLogger.logMessage('Successfully updated module description for module: $moduleName');
      return result;
    } catch (e) {
      QuizzerLogger.logError('Error in updateModuleDescription - $e');
      rethrow;
    }
  }
  // =================================================================================
  // Question Flow API
  // =================================================================================

  //  --------------------------------------------------------------------------------
  /// Retrieves the next question, updates state, and makes it available via getters.
  Future<void> requestNextQuestion() async {
    try {
      QuizzerLogger.logMessage('Entering requestNextQuestion()...');
      
      if (userId == null) {
         throw StateError('User must be logged in to request a question.');
      }

      // 1. Clear existing question state
      _clearQuestionState();

      // 2. Get next user record from QuestionQueueCache
      final Map<String, dynamic> newUserRecord = await _queueCache.getAndRemoveRecord();

      if (newUserRecord.isEmpty) {
          // --- Build and set dummy question state ---
          final dummyRecords = buildDummyNoQuestionsRecord();
          _currentQuestionRecord = null;
          _currentQuestionDetails = dummyRecords['staticDetails'];
          _currentQuestionType = _currentQuestionDetails!['question_type'] as String;
          _timeDisplayed = DateTime.now();
          // --- Dummy state set, stop processing ---
          QuizzerLogger.logMessage('Successfully loaded dummy question (no questions available)');
          return; 
      }
      
      // --- If queue was NOT empty, proceed as before ---
      _currentQuestionRecord = newUserRecord;
      final String questionId = _currentQuestionRecord!['question_id'] as String;

      // 3. Get static question details from TempQuestionDetailsCache
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
          QuizzerLogger.logMessage('Successfully loaded error question due to missing details for QID: $questionId');
          return; // Stop further processing for this question
      }

      // --- DIAGNOSTIC LOGGING (can be kept or removed) ---
      final dynamic fetchedOptions = staticDetails['options'];
      QuizzerLogger.logValue('SessionManager.requestNextQuestion: Fetched options type: ${fetchedOptions.runtimeType}, value: $fetchedOptions');
      // --- END DIAGNOSTIC LOGGING ---

      // 4. Update state with new details
      _currentQuestionDetails = staticDetails;
      // Assert that the key exists and is not null before casting
      assert(_currentQuestionDetails!.containsKey('question_type') && _currentQuestionDetails!['question_type'] != null, 
             "Question details missing 'question_type'");
      // Directly cast to non-nullable String - will throw if not a String
      _currentQuestionType = _currentQuestionDetails!['question_type'] as String; 
      _timeDisplayed = DateTime.now();
      
      QuizzerLogger.logMessage('Successfully loaded next question with QID: $questionId, type: $_currentQuestionType');
    } catch (e) {
      QuizzerLogger.logError('Error in requestNextQuestion - $e');
      rethrow;
    }
  }

  //  --------------------------------------------------------------------------------
  /// Submits the user's answer for the current question.
  /// Updates user-question stats, calculates next due date, and records the attempt.
  /// Returns a map: {success: bool, message: String}
  Future<Map<String, dynamic>> submitAnswer({required dynamic userAnswer}) async {
    try {
      QuizzerLogger.logMessage('Entering submitAnswer()...');
      
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

      // Note: Submission data (_lastSubmittedUserAnswer, _lastSubmittedIsCorrect, _lastSubmittedCustomOrderIndices) 
      // should be set by widgets BEFORE calling submitAnswer

      // --- 4. Calculate Updated User Record ---
      // Keep a copy of the record *before* updates for the attempt log
      final Map<String, dynamic> recordBeforeUpdate = Map<String, dynamic>.from(_currentQuestionRecord!); 
      final Map<String, dynamic> updatedUserRecord = updateUserQuestionRecordOnAnswer(
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

      // --- 6. Update User-Question Pair in DB (table functions handle their own DB access) ---
      await updateAllUserDailyStats(userId!, isCorrect: isCorrect);
      
      // Table functions handle their own database access
      await incrementTotalAttempts(userId!, questionId);
      
      await editUserQuestionAnswerPair(
        userUuid: userId!,
        questionId: questionId,
        revisionStreak: updatedUserRecord['revision_streak'] as int,
        lastRevised: updatedUserRecord['last_revised'] as String,
        nextRevisionDue: updatedUserRecord['next_revision_due'] as String,
        timeBetweenRevisions: updatedUserRecord['time_between_revisions'] as double,
        averageTimesShownPerDay: updatedUserRecord['average_times_shown_per_day'] as double,
        isEligible: (updatedUserRecord['is_eligible'] as int? ?? 0) == 1,
        inCirculation: (updatedUserRecord['in_circulation'] as int? ?? 0) == 1,
      );

      // --- 7. Update In-Memory State ---
      _currentQuestionRecord = updatedUserRecord;

      // --- 8. Move updated question to unprocessed cache and add to history ---
      await _historyCache.addRecord(questionId);
      await _unprocessedCache.addRecord(updatedUserRecord);
      
      QuizzerLogger.logMessage('Successfully submitted answer for QID: $questionId, isCorrect: $isCorrect');
      return {'success': true, 'message': 'Answer submitted successfully.'};
    } catch (e) {
      QuizzerLogger.logError('Error in submitAnswer - $e');
      rethrow;
    }
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
    try {
      QuizzerLogger.logMessage('Entering addNewQuestion()...');
      QuizzerLogger.logMessage('SessionManager: Attempting to add new question of type $questionType');
      
      // --- 1. Pre-checks --- 
      assert(userId != null, 'User must be logged in to add a question.'); 

      final String qstContrib = userId!; // Use current user ID as the question contributor

      // --- 2. Database Operation (table functions handle their own DB access) --- 
      Map<String, dynamic> response;

      switch (questionType) {
        case 'multiple_choice':
          // Validate required fields for this type
          if (options == null || correctOptionIndex == null) {
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
            citation: citation,
            concepts: concepts,
            subjects: subjects,
          );
          break;

        case 'select_all_that_apply':
          // Validate required fields for this type
          if (options == null || indexOptionsThatApply == null) {
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
            citation: citation,
            concepts: concepts,
            subjects: subjects,
          );
          break;

        // --- Add cases for other question types here --- 
        case 'true_false':
          // Validate required fields for this type using assert (Fail Fast)
          if (correctOptionIndex == null) {
              throw ArgumentError('Missing required field correctOptionIndex for true_false');
          }
          
          // Call refactored function with correct args
          await q_pairs_table.addQuestionTrueFalse(
              moduleName: moduleName,
              questionElements: questionElements,
              answerElements: answerElements,
              correctOptionIndex: correctOptionIndex, // Already checked non-null
              qstContrib: qstContrib,
              citation: citation,
              concepts: concepts,
              subjects: subjects,
            );
          break;
        
        case 'sort_order':
          // Validate the new sortOrderOptions parameter
          if (options == null) {
            throw ArgumentError('Missing required field for sort_order: sortOrderOptions (List<String>).');
          }
          // Call the specific function using the correct parameter
          await q_pairs_table.addSortOrderQuestion(
            moduleId: moduleName,
            questionElements: questionElements,
            answerElements: answerElements,
            options: options, // Pass the validated List<String>
            qstContrib: qstContrib,
            citation: citation,
            concepts: concepts,
            subjects: subjects,
          );
          break;

        default:
          throw UnimplementedError('Adding questions of type \'$questionType\' is not yet supported.');
      }

      // --- 3. Post-question operations (table functions handle their own DB access) ---
      await updateModuleActivationStatus(userId!, moduleName, true);
      // TODO validateAll is very inefficient, should probably write a proper function that just adds the userRecord directly to the unprocessedCache and to the table (works but slower at scale)
      await validateAllModuleQuestions(userId!);
      
      QuizzerLogger.logMessage('SessionManager.addNewQuestion: Question added successfully.');
      
      // --- 4. Return Result ---
      response = {};
      QuizzerLogger.logMessage('Successfully added new question of type: $questionType');
      return response;
    } catch (e) {
      QuizzerLogger.logError('Error in addNewQuestion - $e');
      rethrow;
    }
  }

  // TODO Need a service feature that enables text to speech, take in String input, send to service, return audio recording. UI will use this api call to get an audio recording, receive it, then play it.
  // To test in isolation we will generate a few sentences and then pass to service, save the audio recording to a file, then use a different software to play it.

  /// Fetches the full details of a question by its ID (for UI preview, editing, etc.)
  Future<Map<String, dynamic>> fetchQuestionDetailsById(String questionId) async {
    try {
      QuizzerLogger.logMessage('Entering fetchQuestionDetailsById()...');
      
      // Table function handles its own database access
      final details = await q_pairs_table.getQuestionAnswerPairById(questionId);
      
      QuizzerLogger.logMessage('Successfully fetched question details for QID: $questionId');
      return details;
    } catch (e) {
      QuizzerLogger.logError('Error in fetchQuestionDetailsById - $e');
      rethrow;
    }
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
    try {
      QuizzerLogger.logMessage('Entering updateExistingQuestion()...');
      
      // Fail fast if not logged in
      assert(userId != null, 'User must be logged in to update a question.');
      
      // Table function handles its own database access
      final int result = await q_pairs_table.editQuestionAnswerPair(
        questionId: questionId,
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
      
      QuizzerLogger.logMessage('Successfully updated existing question with QID: $questionId, rows affected: $result');
      return result;
    } catch (e) {
      QuizzerLogger.logError('Error in updateExistingQuestion - $e');
      rethrow;
    }
  }



  // =====================================================================
  // --- User Settings API ---
  // =====================================================================

  /// Updates a specific user setting in the local database.
  /// Triggers outbound sync.
  Future<void> updateUserSetting(String settingName, dynamic newValue) async {
    try {
      QuizzerLogger.logMessage('Entering updateUserSetting()...');
      
      assert(userId != null, 'User must be logged in to update a setting.');
      
      // Table function handles its own database access
      await user_settings_table.updateUserSetting(userId!, settingName, newValue);
      
      QuizzerLogger.logMessage('Successfully updated user setting: $settingName');
    } catch (e) {
      QuizzerLogger.logError('Error in updateUserSetting - $e');
      rethrow;
    }
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
    try {
      QuizzerLogger.logMessage('Entering getUserSettings()...');
      
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
          // Table function handles its own database access
          final Map<String, Map<String, dynamic>> allSettingsWithFlags = await user_settings_table.getAllUserSettings(userId!);
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
          QuizzerLogger.logMessage('SessionManager: Getting setting "$settingName" for user $userId (Role: $currentUserRole).');
          // Table function handles its own database access
          final Map<String, dynamic>? settingDetails = await user_settings_table.getSettingValue(userId!, settingName!);
          if (settingDetails != null) {
            final bool isAdminSetting = (settingDetails['is_admin_setting'] as int? ?? 0) == 1;
            if (!isAdminSetting || currentUserRole == 'admin' || currentUserRole == 'contributor') {
              resultToReturn = settingDetails['value'];
            } else {
              resultToReturn = null; // Admin setting, non-admin/contributor user
              QuizzerLogger.logWarning('SessionManager: Access denied for user $userId (Role: $currentUserRole) to admin/contributor setting "$settingName".');
            }
          } else {
            resultToReturn = null; // Setting not found
          }
          break;
        case "list":
          QuizzerLogger.logMessage('SessionManager: Getting specific settings for user $userId (Role: $currentUserRole): ${settingNames!.join(", ")}.');
          final Map<String, dynamic> listedResults = {};
          for (final name in settingNames) {
            // Table function handles its own database access
            final Map<String, dynamic>? settingDetails = await user_settings_table.getSettingValue(userId!, name);
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

      QuizzerLogger.logMessage('Successfully retrieved user settings for operation mode: $operationMode');
      return resultToReturn;
    } catch (e) {
      QuizzerLogger.logError('Error in getUserSettings - $e');
      rethrow;
    }
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
  /// Returns:
  ///   The ID of the created or updated error log record.
  Future<String> reportError({
    String? id, 
    String? errorMessage, 
    String? userFeedback,
  }) async {
    try {
      QuizzerLogger.logMessage('Entering reportError()...');
      
      await initializationComplete;

      if (id == null && (errorMessage == null || errorMessage.isEmpty)) {
        QuizzerLogger.logError('reportError: Attempted to create a new error log without an error message.');
        throw ArgumentError('errorMessage must be provided when creating a new error log.');
      }

      // Table function handles its own database access
      final String resultId = await upsertErrorLog(
        id: id,
        userId: userId,
        errorMessage: errorMessage,
        userFeedback: userFeedback,
      );

      QuizzerLogger.logMessage('Successfully reported error with ID: $resultId');
      return resultId;
    } catch (e) {
      QuizzerLogger.logError('Error in reportError - $e');
      rethrow;
    }
  }

  // ================================================================================
  // --- User Feedback Functionality ---
  // ================================================================================
  /// Submits user feedback to the local database.
  ///
  /// Returns the ID of the created feedback record.
  Future<String> submitUserFeedback({
    required String feedbackType,
    required String feedbackContent,
  }) async {
    try {
      QuizzerLogger.logMessage('Entering submitUserFeedback()...');
      
      await initializationComplete;
      // userId can be null if the user is not logged in, which is fine for feedback.

      // Table function handles its own database access
      final String feedbackId = await addUserFeedback(
        userId: userId, // Pass current userId, can be null
        feedbackType: feedbackType,
        feedbackContent: feedbackContent,
      );

      QuizzerLogger.logMessage('Successfully submitted user feedback with ID: $feedbackId');
      return feedbackId;
    } catch (e) {
      QuizzerLogger.logError('Error in submitUserFeedback - $e');
      rethrow;
    }
  }

  // =====================================================================
  // --- User Stats API (Eligible Questions) ---
  // =====================================================================

  /// Fetches eligible questions stats for the current user.
  /// - If [date] is provided, returns the stat for that date (or null if not found).
  /// - If [getAll] is true, returns the full history as a List.
  /// - If neither is provided, returns today's stat.
  /// Only one mode can be used at a time.
  Future<dynamic> getEligibleQuestionsStats({DateTime? date, bool getAll = false}) async {
    try {
      QuizzerLogger.logMessage('Entering getEligibleQuestionsStats()...');
      
      assert(userId != null, 'User must be logged in to get stats.');

      if (getAll) {
        // Table function handles its own database access
        final records = await getUserStatsEligibleQuestionsRecordsByUser(userId!);
        QuizzerLogger.logMessage('Successfully retrieved all eligible questions stats for user: $userId');
        return records;
      }

      final String dateString = (date ?? DateTime.now().toUtc()).toIso8601String().substring(0, 10);
      // Table function handles its own database access
      final record = await getUserStatsEligibleQuestionsRecordByDate(userId!, dateString);
      QuizzerLogger.logMessage('Successfully retrieved eligible questions stats for date: $dateString, user: $userId');
      return record;
    } catch (e) {
      QuizzerLogger.logError('Error in getEligibleQuestionsStats - $e');
      rethrow;
    }
  }

  /// Fetches non-circulating questions stats for the current user.
  /// - If [date] is provided, returns the stat for that date (or null if not found).
  /// - If [getAll] is true, returns the full history as a List.
  /// - If neither is provided, returns today's stat.
  /// Only one mode can be used at a time.
  Future<dynamic> getNonCirculatingQuestionsStats({DateTime? date, bool getAll = false}) async {
    try {
      QuizzerLogger.logMessage('Entering getNonCirculatingQuestionsStats()...');
      
      assert(userId != null, 'User must be logged in to get stats.');

      if (getAll) {
        // Table function handles its own database access
        final records = await getUserStatsNonCirculatingQuestionsRecordsByUser(userId!);
        QuizzerLogger.logMessage('Successfully retrieved all non-circulating questions stats for user: $userId');
        return records;
      }

      final String dateString = (date ?? DateTime.now().toUtc()).toIso8601String().substring(0, 10);
      // Table function handles its own database access
      final record = await getUserStatsNonCirculatingQuestionsRecordByDate(userId!, dateString);
      QuizzerLogger.logMessage('Successfully retrieved non-circulating questions stats for date: $dateString, user: $userId');
      return record;
    } catch (e) {
      QuizzerLogger.logError('Error in getNonCirculatingQuestionsStats - $e');
      rethrow;
    }
  }

  /// Fetches in-circulating questions stats for the current user.
  /// - If [date] is provided, returns the stat for that date (or null if not found).
  /// - If [getAll] is true, returns the full history as a List.
  /// - If neither is provided, returns today's stat.
  /// Only one mode can be used at a time.
  Future<dynamic> getInCirculationQuestionsStats({DateTime? date, bool getAll = false}) async {
    try {
      QuizzerLogger.logMessage('Entering getInCirculationQuestionsStats()...');
      
      assert(userId != null, 'User must be logged in to get stats.');

      if (getAll) {
        // Table function handles its own database access
        final records = await getUserStatsInCirculationQuestionsRecordsByUser(userId!);
        QuizzerLogger.logMessage('Successfully retrieved all in-circulating questions stats for user: $userId');
        return records;
      }

      final String dateString = (date ?? DateTime.now().toUtc()).toIso8601String().substring(0, 10);
      // Table function handles its own database access
      final record = await getUserStatsInCirculationQuestionsRecordByDate(userId!, dateString);
      QuizzerLogger.logMessage('Successfully retrieved in-circulating questions stats for date: $dateString, user: $userId');
      return record;
    } catch (e) {
      QuizzerLogger.logError('Error in getInCirculationQuestionsStats - $e');
      rethrow;
    }
  }

  /// Fetches the current day's revision streak sum records for the logged-in user.
  Future<List<Map<String, dynamic>>> getCurrentRevisionStreakSumStats() async {
    try {
      QuizzerLogger.logMessage('Entering getCurrentRevisionStreakSumStats()...');
      
      if (userId == null) {
        QuizzerLogger.logWarning('SessionManager.getCurrentRevisionStreakSumStats: User ID is null.');
        return [];
      }

      // Table function handles its own database access
      final List<Map<String, dynamic>> result = await getTodayUserStatsRevisionStreakSumRecords(userId!);
      
      QuizzerLogger.logMessage('Successfully retrieved current revision streak sum stats for user: $userId');
      return result;
    } catch (e) {
      QuizzerLogger.logError('Error in getCurrentRevisionStreakSumStats - $e');
      rethrow;
    }
  }

  /// Fetches all historical revision streak sum records for the logged-in user.
  Future<List<Map<String, dynamic>>> getHistoricalRevisionStreakSumStats() async {
    try {
      QuizzerLogger.logMessage('Entering getHistoricalRevisionStreakSumStats()...');
      
      if (userId == null) {
        QuizzerLogger.logWarning('SessionManager.getHistoricalRevisionStreakSumStats: User ID is null.');
        return [];
      }

      // Table function handles its own database access
      final List<Map<String, dynamic>> result = await getUserStatsRevisionStreakSumRecordsByUser(userId!);
      
      QuizzerLogger.logMessage('Successfully retrieved historical revision streak sum stats for user: $userId');
      return result;
    } catch (e) {
      QuizzerLogger.logError('Error in getHistoricalRevisionStreakSumStats - $e');
      rethrow;
    }
  }

  /// Fetches the current day's total user question answer pairs count for the logged-in user.
  Future<int> getCurrentTotalUserQuestionAnswerPairsCount() async {
    try {
      QuizzerLogger.logMessage('Entering getCurrentTotalUserQuestionAnswerPairsCount()...');
      
      if (userId == null) {
        QuizzerLogger.logWarning('SessionManager.getCurrentTotalUserQuestionAnswerPairsCount: User ID is null.');
        return 0;
      }

      // Table function handles its own database access
      final Map<String, dynamic> record = await getTodayUserStatsTotalUserQuestionAnswerPairsRecord(userId!);
      
      final int count = record['total_question_answer_pairs'] as int? ?? 0;
      QuizzerLogger.logMessage('Successfully retrieved current total user question answer pairs count: $count for user: $userId');
      return count;
    } catch (e) {
      QuizzerLogger.logError('Error in getCurrentTotalUserQuestionAnswerPairsCount - $e');
      rethrow;
    }
  }

  /// Fetches all historical total user question answer pairs records for the logged-in user.
  Future<List<Map<String, dynamic>>> getHistoricalTotalUserQuestionAnswerPairsStats() async {
    try {
      QuizzerLogger.logMessage('Entering getHistoricalTotalUserQuestionAnswerPairsStats()...');
      
      if (userId == null) {
        QuizzerLogger.logWarning('SessionManager.getHistoricalTotalUserQuestionAnswerPairsStats: User ID is null.');
        return [];
      }

      // Table function handles its own database access
      final List<Map<String, dynamic>> result = await getUserStatsTotalUserQuestionAnswerPairsRecordsByUser(userId!);
      
      QuizzerLogger.logMessage('Successfully retrieved historical total user question answer pairs stats for user: $userId');
      return result;
    } catch (e) {
      QuizzerLogger.logError('Error in getHistoricalTotalUserQuestionAnswerPairsStats - $e');
      rethrow;
    }
  }

  /// Fetches the current day's average questions shown per day stat for the logged-in user.
  Future<Map<String, dynamic>?> getCurrentAverageQuestionsShownPerDayStat() async {
    try {
      QuizzerLogger.logMessage('Entering getCurrentAverageQuestionsShownPerDayStat()...');
      
      if (userId == null) {
        QuizzerLogger.logWarning('SessionManager.getCurrentAverageQuestionsShownPerDayStat: User ID is null.');
        return null;
      }

      // Table function handles its own database access
      final Map<String, dynamic> record = await getTodayUserStatsAverageQuestionsShownPerDayRecord(userId!);
      
      QuizzerLogger.logMessage('Successfully retrieved current average questions shown per day stat for user: $userId');
      return record;
    } catch (e) {
      QuizzerLogger.logWarning('SessionManager.getCurrentAverageQuestionsShownPerDayStat: $e');
      return null;
    }
  }

  /// Fetches all historical average questions shown per day records for the logged-in user.
  Future<List<Map<String, dynamic>>> getHistoricalAverageQuestionsShownPerDayStats() async {
    try {
      QuizzerLogger.logMessage('Entering getHistoricalAverageQuestionsShownPerDayStats()...');
      
      if (userId == null) {
        QuizzerLogger.logWarning('SessionManager.getHistoricalAverageQuestionsShownPerDayStats: User ID is null.');
        return [];
      }

      // Table function handles its own database access
      final List<Map<String, dynamic>> result = await getUserStatsAverageQuestionsShownPerDayRecordsByUser(userId!);
      
      QuizzerLogger.logMessage('Successfully retrieved historical average questions shown per day stats for user: $userId');
      return result;
    } catch (e) {
      QuizzerLogger.logWarning('SessionManager.getHistoricalAverageQuestionsShownPerDayStats: $e');
      return [];
    }
  }

  /// Fetches the current day's total questions answered count for the logged-in user.
  Future<int> getCurrentTotalQuestionsAnsweredCount() async {
    try {
      QuizzerLogger.logMessage('Entering getCurrentTotalQuestionsAnsweredCount()...');
      
      if (userId == null) {
        QuizzerLogger.logWarning('SessionManager.getCurrentTotalQuestionsAnsweredCount: User ID is null.');
        return 0;
      }

      // Table function handles its own database access
      final Map<String, dynamic> record = await getTodayUserStatsTotalQuestionsAnsweredRecord(userId!);
      
      final int count = record['total_questions_answered'] as int? ?? 0;
      QuizzerLogger.logMessage('Successfully retrieved current total questions answered count: $count for user: $userId');
      return count;
    } catch (e) {
      QuizzerLogger.logError('Error in getCurrentTotalQuestionsAnsweredCount - $e');
      rethrow;
    }
  }

  /// Fetches all historical total questions answered records for the logged-in user.
  Future<List<Map<String, dynamic>>> getHistoricalTotalQuestionsAnsweredStats() async {
    try {
      QuizzerLogger.logMessage('Entering getHistoricalTotalQuestionsAnsweredStats()...');
      
      if (userId == null) {
        QuizzerLogger.logWarning('SessionManager.getHistoricalTotalQuestionsAnsweredStats: User ID is null.');
        return [];
      }

      // Table function handles its own database access
      final List<Map<String, dynamic>> result = await getUserStatsTotalQuestionsAnsweredRecordsByUser(userId!);
      
      QuizzerLogger.logMessage('Successfully retrieved historical total questions answered stats for user: $userId');
      return result;
    } catch (e) {
      QuizzerLogger.logError('Error in getHistoricalTotalQuestionsAnsweredStats - $e');
      rethrow;
    }
  }

  /// Fetches all historical daily questions answered records for the logged-in user.
  Future<List<Map<String, dynamic>>> getHistoricalDailyQuestionsAnsweredStats() async {
    try {
      QuizzerLogger.logMessage('Entering getHistoricalDailyQuestionsAnsweredStats()...');
      
      if (userId == null) {
        QuizzerLogger.logWarning('SessionManager.getHistoricalDailyQuestionsAnsweredStats: User ID is null.');
        return [];
      }

      // Table function handles its own database access
      final List<Map<String, dynamic>> result = await getUserStatsDailyQuestionsAnsweredRecordsByUser(userId!);
      
      QuizzerLogger.logMessage('Successfully retrieved historical daily questions answered stats for user: $userId');
      return result;
    } catch (e) {
      QuizzerLogger.logError('Error in getHistoricalDailyQuestionsAnsweredStats - $e');
      rethrow;
    }
  }

  /// Fetches the current day's average daily questions learned stat for the logged-in user.
  Future<Map<String, dynamic>?> getCurrentAverageDailyQuestionsLearnedStat() async {
    try {
      QuizzerLogger.logMessage('Entering getCurrentAverageDailyQuestionsLearnedStat()...');
      
      if (userId == null) {
        QuizzerLogger.logWarning('SessionManager.getCurrentAverageDailyQuestionsLearnedStat: User ID is null.');
        return null;
      }

      // Table function handles its own database access
      final Map<String, dynamic> record = await getTodayUserStatsAverageDailyQuestionsLearnedRecord(userId!);
      
      QuizzerLogger.logMessage('Successfully retrieved current average daily questions learned stat for user: $userId');
      return record;
    } catch (e) {
      QuizzerLogger.logWarning('SessionManager.getCurrentAverageDailyQuestionsLearnedStat: $e');
      return null;
    }
  }

  /// Fetches all historical average daily questions learned records for the logged-in user.
  Future<List<Map<String, dynamic>>> getHistoricalAverageDailyQuestionsLearnedStats() async {
    try {
      QuizzerLogger.logMessage('Entering getHistoricalAverageDailyQuestionsLearnedStats()...');
      
      if (userId == null) {
        QuizzerLogger.logWarning('SessionManager.getHistoricalAverageDailyQuestionsLearnedStats: User ID is null.');
        return [];
      }

      // Table function handles its own database access
      final List<Map<String, dynamic>> result = await getUserStatsAverageDailyQuestionsLearnedRecordsByUser(userId!);
      
      QuizzerLogger.logMessage('Successfully retrieved historical average daily questions learned stats for user: $userId');
      return result;
    } catch (e) {
      QuizzerLogger.logWarning('SessionManager.getHistoricalAverageDailyQuestionsLearnedStats: $e');
      return [];
    }
  }

  /// Fetches the current day's days left until questions exhaust stat for the logged-in user.
  Future<Map<String, dynamic>?> getCurrentDaysLeftUntilQuestionsExhaustStat() async {
    try {
      QuizzerLogger.logMessage('Entering getCurrentDaysLeftUntilQuestionsExhaustStat()...');
      
      if (userId == null) {
        QuizzerLogger.logWarning('SessionManager.getCurrentDaysLeftUntilQuestionsExhaustStat: User ID is null.');
        return null;
      }

      // Table function handles its own database access
      final Map<String, dynamic> record = await getTodayUserStatsDaysLeftUntilQuestionsExhaustRecord(userId!);
      
      QuizzerLogger.logMessage('Successfully retrieved current days left until questions exhaust stat for user: $userId');
      return record;
    } catch (e) {
      QuizzerLogger.logWarning('SessionManager.getCurrentDaysLeftUntilQuestionsExhaustStat: $e');
      return null;
    }
  }

  /// Fetches all historical days left until questions exhaust records for the logged-in user.
  Future<List<Map<String, dynamic>>> getHistoricalDaysLeftUntilQuestionsExhaustStats() async {
    try {
      QuizzerLogger.logMessage('Entering getHistoricalDaysLeftUntilQuestionsExhaustStats()...');
      
      if (userId == null) {
        QuizzerLogger.logWarning('SessionManager.getHistoricalDaysLeftUntilQuestionsExhaustStats: User ID is null.');
        return [];
      }

      // Table function handles its own database access
      final List<Map<String, dynamic>> result = await getUserStatsDaysLeftUntilQuestionsExhaustRecordsByUser(userId!);
      
      QuizzerLogger.logMessage('Successfully retrieved historical days left until questions exhaust stats for user: $userId');
      return result;
    } catch (e) {
      QuizzerLogger.logWarning('SessionManager.getHistoricalDaysLeftUntilQuestionsExhaustStats: $e');
      return [];
    }
  }
}

// Global instance
final SessionManager _globalSessionManager = SessionManager();

/// Gets the global session manager instance
SessionManager getSessionManager() => _globalSessionManager;


// TODO Fix flag question dialogue to actually work
