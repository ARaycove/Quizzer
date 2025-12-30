import 'dart:io';
import 'dart:async';
import 'package:hive/hive.dart';
import 'package:supabase/supabase.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:quizzer/backend_systems/00_helper_utils/utils.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/09_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/session_manager/session_helper.dart';
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';
import 'package:quizzer/backend_systems/08_data_caches/question_queue_cache.dart';
import 'package:quizzer/backend_systems/08_data_caches/answer_history_cache.dart';
import 'package:quizzer/backend_systems/10_settings_manager/settings_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initializer.dart';
import 'package:quizzer/backend_systems/09_switch_board/sb_question_worker_signals.dart';
import 'package:quizzer/backend_systems/05_question_queue_server/circulation_worker.dart';
import 'package:quizzer/backend_systems/01_account_creation_and_management/account_manager.dart';
import 'package:quizzer/backend_systems/05_question_queue_server/question_selection_worker.dart';
import 'package:quizzer/backend_systems/06_question_answer_pair_management/question_generator.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/media_sync_worker.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/system_data/error_logs_table.dart';
import 'package:quizzer/backend_systems/12_answer_validator/answer_validation/text_analysis_tools.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/system_data/user_feedback_table.dart';
import 'package:quizzer/backend_systems/06_question_answer_pair_management/question_review_manager.dart';
import 'package:quizzer/backend_systems/05_question_queue_server/user_questions/user_question_manager.dart';
import 'package:quizzer/backend_systems/05_question_queue_server/user_questions/user_answer_submitter.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_daily_stats_table.dart';
import 'package:quizzer/backend_systems/06_question_answer_pair_management/question_answer_pair_manager.dart';
import 'package:quizzer/backend_systems/12_answer_validator/answer_validation/session_answer_validation.dart';
import 'package:quizzer/backend_systems/12_answer_validator/answer_validation/text_validation_functionality.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/inbound_sync/inbound_sync_worker.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/outbound_sync/outbound_sync_worker.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pair_flags_table.dart';

class SessionManager {
  // Singleton instance
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  // Secure Storage
  // Hive storage for offline persistence
  late        Box                             _storage;
  // Completer to signal when async initialization (like storage) is done
  final       Completer<void>                 _initializationCompleter = Completer<void>();
  /// Future that completes when asynchronous initialization is finished.
  /// Await this before accessing components that depend on async init (e.g., _storage).
              Future<void> get                initializationComplete => _initializationCompleter.future;
  // Supabase client instance
  late final  SupabaseClient                  supabase;
  // Database monitor instance
  // Cache Instances (as instance variables)
  final       QuestionQueueCache              _queueCache;
  final       AnswerHistoryCache              _historyCache;
  final       SwitchBoard                     _switchBoard; // Add SwitchBoard instance

  // ================================================================================
  // --- Home Page Stat Display Cache ---
  // ================================================================================
  // Cached values for home page stat display settings
  // These are updated when stats are calculated and cached for quick access
  int?                                        _cachedEligibleQuestionsCount;
  int?                                        _cachedInCirculationQuestionsCount;
  int?                                        _cachedNonCirculatingQuestionsCount;
  int?                                        _cachedLifetimeTotalQuestionsAnswered;
  int?                                        _cachedDailyQuestionsAnswered;
  double?                                     _cachedAverageDailyQuestionsLearned;
  double?                                     _cachedAverageQuestionsShownPerDay;
  double?                                     _cachedDaysLeftUntilQuestionsExhaust;
  int?                                        _cachedRevisionStreakScore;
  DateTime?                                   _cachedLastReviewed;

  // ================================================================================
  // --- User Settings Cache ---
  // ================================================================================
  // Cached values for user settings
  // These are updated when settings are fetched or updated
  Map<String, dynamic>                       _cachedUserSettings = {};

  // --- Getters for User Settings Cache ---
  Map<String, dynamic> get cachedUserSettings => _cachedUserSettings;

  // --- Setters for User Settings Cache ---
  void setCachedUserSettings(Map<String, dynamic> settings) => _cachedUserSettings = settings;

  // TODO rebuild this update call to use the SettingManager() once the SettingsManager() is made
  void updateCachedUserSetting(String settingName, dynamic value) {
    _cachedUserSettings[settingName] = value;
  }

  void clearCachedUserSettings() => _cachedUserSettings.clear();

  // --- Getters for Home Page Stat Display Cache ---
  int?      get cachedEligibleQuestionsCount 
  => _cachedEligibleQuestionsCount;

  int?      get cachedInCirculationQuestionsCount 
  => _cachedInCirculationQuestionsCount;

  int?      get cachedNonCirculatingQuestionsCount 
  => _cachedNonCirculatingQuestionsCount;

  int?      get cachedLifetimeTotalQuestionsAnswered 
  => _cachedLifetimeTotalQuestionsAnswered;

  int?      get cachedDailyQuestionsAnswered 
  => _cachedDailyQuestionsAnswered;

  double?   get cachedAverageDailyQuestionsLearned 
  => _cachedAverageDailyQuestionsLearned;

  double?   get cachedAverageQuestionsShownPerDay 
  => _cachedAverageQuestionsShownPerDay;

  double?   get cachedDaysLeftUntilQuestionsExhaust
  => _cachedDaysLeftUntilQuestionsExhaust;

  // Get revision streak from current question record if available, otherwise from cache
  int? get cachedRevisionStreakScore {
    if (_currentQuestionRecord != null) {
      return _currentQuestionRecord!['revision_streak'] as int?;
    }
    return _cachedRevisionStreakScore;
  }

  // Get last reviewed from current question record if available, otherwise from cache
  DateTime? get cachedLastReviewed {
    if (_currentQuestionRecord != null) {
      final String? lastRevisedStr = _currentQuestionRecord!['last_revised'] as String?;
      if (lastRevisedStr != null && lastRevisedStr.isNotEmpty) {
        try {
          return DateTime.parse(lastRevisedStr);
        } catch (e) {
          QuizzerLogger.logWarning('Failed to parse last_revised date: $lastRevisedStr');
        }
      }
    }
    return _cachedLastReviewed;
  }

  // user State
              bool          _userLoggedIn = false;
              bool    get   userLoggedIn  => _userLoggedIn;
                      set userLoggedIn(bool value) {
                        QuizzerLogger.logMessage("Setting userLoggedIn to: $value");
                        _userLoggedIn = value;
                        QuizzerLogger.logMessage("userLoggedIn is now: $_userLoggedIn");
                        assert(_userLoggedIn == value, "Failed to set userLoggedIn to $value");
                      }

              String?       _userId;
              String? get   userId        => _userId;
                      set   userId(String? value) {
                QuizzerLogger.logMessage("Setting SessionManager.userId to: $value");
                _userId = value;
                QuizzerLogger.logMessage("SessionManager.userId is now: $_userId");
                assert(_userId == value, "Failed to set userId. Expected: $value, Actual: $_userId");
              }

              String? _userEmail;
              String? get userEmail => _userEmail;
                      set userEmail(String? value) {
                        QuizzerLogger.logMessage("Setting userEmail to: $value");
                        _userEmail = value;
                        QuizzerLogger.logMessage("userEmail is now: $_userEmail");
                        assert(_userEmail == value, "Failed to set userEmail to $value");
                      }

              String?       _initialProfileLastModified; // Store initial last_modified_timestamp
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
              DateTime?                       _sessionStartTime;
              DateTime? get                   sessionStartTime => _sessionStartTime;
                        set                   sessionStartTime(DateTime? value) {
                          QuizzerLogger.logMessage("Setting sessionStartTime to: $value");
                          _sessionStartTime = value;
                          QuizzerLogger.logMessage("sessionStartTime is now: $_sessionStartTime");
                          assert(_sessionStartTime == value, "Failed to set sessionStartTime to $value");
                        }
  
          
  // --- Public Getters for UI State ---
  Map<String, dynamic>? get currentQuestionUserRecord   => _currentQuestionRecord;
  Map<String, dynamic>? get currentQuestionStaticData   => _currentQuestionDetails;
  String?               get initialProfileLastModified  => _initialProfileLastModified;
  
  // How will a fill in the blank be evaluated?
  String getFillInTheBlankValidationType(primaryAnswer) {
    return getValidationType(primaryAnswer);
  }
  // Decode the JWT everytime to ensure security
  String get userRole {return SessionHelper.determineUserRoleFromSupabaseSession(supabase.auth.currentSession);}
  
  // --- Public Method for Testing (Password Protected) ---
  Box getBox(String password) {
    // Password protection to prevent accidental access in production
    // Only use this for testing purposes
    const String testAccessPassword = "⌘✆✈✉✌✍✎✏✐✑✒✓✔✕✖✗✘✙✚✛✜✝✞✟✠✡✢✣✤✥✦✧★✩✪✫✬✭✮✯✰✱✲✳✴✵✶✷✸✹✺✻✼✽✾✿❀❁❂❃❄❅❆❇❈❉❊❋●❍■❏❐❑❒▲▼◆◇◈◉◊○◌◍◎●◐◑◒◓◔◕◖◗◘◙◎◌◍◎●◐◑◒◓◔◕◖◗◘◙";
    
    if (password != testAccessPassword) {
      throw UnsupportedError('Storage access is password protected for testing only');
    }
    
    return _storage;
  }
  
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

  /// Returns whether the current question has been answered (for UI state management)
  bool get isCurrentQuestionAnswered => _isAnswerSubmitted;

  /// Validates fill-in-the-blank answers and returns detailed correctness information
  /// Returns: {"isCorrect": bool, "ind_blanks": List<bool>}
  Future<Map<String, dynamic>> validateFillInTheBlankAnswer(List<String> userAnswers) async {
    if (_currentQuestionDetails == null) {
      throw Exception('No current question loaded');
    }
    
    if (_currentQuestionDetails!['question_type'] != 'fill_in_the_blank') {
      throw Exception('Current question is not a fill_in_the_blank type');
    }
    
    final List<Map<String, List<String>>> answersToBlanks = currentAnswersToBlanks;
    
    return await validateFillInTheBlank(
      {
        'question_type': 'fill_in_the_blank',
        'answers_to_blanks': answersToBlanks,
      },
      userAnswers,
    );
  }

  /// Gets synonym suggestions for a given word using the Datamuse API
  /// Returns a list of suggested synonyms
  Future<List<String>> getSynonymSuggestions(String word) async {
    try {
      QuizzerLogger.logMessage('Getting synonym suggestions for word: $word');
      final synonyms = await callSynonymAPI(word);  // FIXME Move function to QuestionGenerator
      QuizzerLogger.logSuccess('Retrieved ${synonyms.length} synonym suggestions for "$word"');
      return synonyms;
    } catch (e) {
      QuizzerLogger.logError('Error getting synonym suggestions for "$word": $e');
      rethrow;
    }
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

  String?                     get currentCitation               => _currentQuestionDetails!['citation'] 
  as String?;

  String?                     get currentConcepts               => _currentQuestionDetails!['concepts'] 
  as String?;

  String?                     get currentSubjects               => _currentQuestionDetails!['subjects'] 
  as String?;

  // Safely cast List<dynamic> to List<Map<String, List<String>>>
  List<Map<String, List<String>>> get currentAnswersToBlanks {
    final dynamic answers = _currentQuestionDetails?['answers_to_blanks'];
    QuizzerLogger.logMessage("SessionManager currentAnswersToBlanks: _currentQuestionDetails is null: ${_currentQuestionDetails == null}");
    if (_currentQuestionDetails != null) {
      // QuizzerLogger.logMessage("SessionManager currentAnswersToBlanks: answers_to_blanks type: ${answers.runtimeType}");
      // QuizzerLogger.logMessage("SessionManager currentAnswersToBlanks: answers_to_blanks value: $answers");
    }
    if (answers is List) {
      return List<Map<String, List<String>>>.from(answers.map((item) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(item as Map);
        return Map<String, List<String>>.from(map.map((key, value) {
          return MapEntry(key, List<String>.from(value as List));
        }));
      }));
    }
    return [];
  }
  // ================================================================================
  // --- Initialization Functionality ---
  // ================================================================================
  // --------------------------------------------------------------------------------
  // SessionManager Constructor (Initializes Supabase and starts async init)
  // FIXME Move to Initialization object
  SessionManager._internal(): 
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
      // QuizzerLogger.logMessage('Entering _clearQuestionState()...');
      
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
      
      // QuizzerLogger.logMessage('Successfully cleared question state');
    } catch (e) {
      QuizzerLogger.logError('Error in _clearQuestionState - $e');
      rethrow;
    }
  }

  /// Clears all session-specific user state.
  Future<void> _clearSessionState() async{
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
  // Public API CALLS
  // =================================================================================
  //  --------------------------------------------------------------------------------
  /// Creates a new user account with Supabase and local database
  /// Returns true if successful, false otherwise
  Future<Map<String, dynamic>> createNewUserAccount({
    required String email,
    required String username,
    required String password,
  }) async {
    bool isConnected = await checkConnectivity();
    if (!isConnected) {return {
        'success': false,
        'message': 'Not Connected to the Internet, signup required internet access',
      };}
    try {
      QuizzerLogger.logMessage('Entering createNewUserAccount()...');

      final result = await AccountManager().handleNewUserProfileCreation({
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
  /// AuthType may be one of ["email_login", "google_login"]
  Future<Map<String, dynamic>> attemptLogin({required String authType, String? email, String? password}) async {
    try {
      QuizzerLogger.logMessage('Entering attemptLogin()...');
      
      // Ensure async initialization is complete before proceeding
      QuizzerLogger.logMessage("Logging in user with email: $email");
      await initializationComplete;
      // Resolve no email by inserting empty string
      // email is not required in the case of social login
      email ??= "";
      password ??= "";
      // Now it's safe to access _storage
      final response = await LoginInitializer().loginUserAuthenticateAndInitializeCoreQuizzerSystem(
        email: email,
        password: password,
        supabase: supabase, 
        storage: _storage, 
        authType: authType);

      // Response information is for front-end UI, not necessary for backend
      // Send signal to UI that it's ok to login now
      QuizzerLogger.logMessage('Successfully completed attemptLogin for email: $email');
      return response!;
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

      // Preserve current user info for cleanup ops
      final String? currentUserIdForLogoutOps = userId;
      final String? currentUserEmailForLogoutOps = userEmail;
      QuizzerLogger.logMessage(
        "Starting logout process for $currentUserEmailForLogoutOps (ID: $currentUserIdForLogoutOps)",
      );

      // Stop background workers
      QuizzerLogger.logMessage("Stopping background workers...");
      final psw = PresentationSelectionWorker();
      final circWorker = CirculationWorker();
      final inboundSyncWorker = InboundSyncWorker();
      final outboundSyncWorker = OutboundSyncWorker();
      final mediaSyncWorker = MediaSyncWorker();

      // TODO Refactor SessionManager to have an Enum or List of a background processes then pass this list to futureWait
      await Future.wait([
        psw.stop(),
        circWorker.stop(),
        outboundSyncWorker.stop(),
        inboundSyncWorker.stop(),
        mediaSyncWorker.stop(),
      ]);

      QuizzerLogger.logSuccess("✅ Background workers stopped.");

      // Clear DB queues
      QuizzerLogger.logMessage("Clearing all pending database requests...");
      final databaseMonitor = getDatabaseMonitor();
      await databaseMonitor.clearAllQueues();
      QuizzerLogger.logSuccess("✅ Database request queues cleared.");

      // Clear local caches safely
      QuizzerLogger.logMessage("Clearing data caches...");
      await _queueCache.clear();
      await _historyCache.clear();
      SettingsManager().clearSettingsCache();

      QuizzerLogger.logSuccess("✅ Data caches cleared.");

      // Google Sign-Out (if active)
      QuizzerLogger.logMessage("Checking for active Google Sign-In session...");
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final googleUser = await googleSignIn.signInSilently();

      if (googleUser != null) {
        QuizzerLogger.logMessage("Google user detected (${googleUser.email}), signing out...");
        await googleSignIn.disconnect();
        await googleSignIn.signOut();
        QuizzerLogger.logSuccess("✅ Google Sign-Out successful.");
      } else {
        QuizzerLogger.logMessage("No active Google Sign-In session found.");
      }

      // Supabase Sign-Out
      QuizzerLogger.logMessage("Signing out from Supabase...");
      await supabase.auth.signOut();
      QuizzerLogger.logSuccess("✅ Supabase Sign-Out successful.");

      // Clear session state - FIXED: Added parentheses to call the method
      QuizzerLogger.logMessage("Clearing session state...");
      _clearSessionState(); // Fixed this line
      userLoggedIn = false;
      QuizzerLogger.logSuccess("✅ Session state cleared.");

      QuizzerLogger.printHeader("✅ User Logout Process Completed.");
      QuizzerLogger.logMessage('Successfully completed logoutUser.');
    } catch (e, st) {
      QuizzerLogger.logError('Error in logoutUser - $e\n$st');
      rethrow;
    }
  }
  // =================================================================================
  // Question Flow API
  // =================================================================================

  //  --------------------------------------------------------------------------------
  /// Retrieves the next question, updates state, and makes it available via getters.
  /// 
  /// Args:
  ///   testDebug: Optional test record to use instead of getting from queue cache.
  ///              This bypasses the queue cache entirely for testing purposes.
  Future<void> requestNextQuestion({Map<String, dynamic>? testDebug}) async {
    try {
      // QuizzerLogger.logMessage('Entering requestNextQuestion()...');
      
      if (userId == null) {
         throw StateError('User must be logged in to request a question.');
      }

      // 1. Clear existing question state
      _clearQuestionState();

      // 2. Get next user record from QuestionQueueCache (now handles dummy records internally)
      // Or use testDebug record if provided for testing
      final Map<String, dynamic> newUserRecord = testDebug ?? await _queueCache.getAndRemoveRecord();

      // Check if this is a dummy record
      final String questionId = newUserRecord['question_id'] as String;
      if (questionId == 'dummy_no_questions') {
        // This is a dummy record - set it up appropriately
        _currentQuestionRecord = null; // No user record for dummy
        _currentQuestionDetails = newUserRecord; // Use the dummy record as static details
          _currentQuestionType = _currentQuestionDetails!['question_type'] as String;
          _timeDisplayed = DateTime.now();
          QuizzerLogger.logMessage('Successfully loaded dummy question (no questions available)');
          // Note: Dummy questions are NOT added to answer history cache
          return; 
      }
      
      // --- If queue was NOT empty, proceed as before ---
      _currentQuestionRecord = newUserRecord;

      // The record from queue cache now contains both user data and question details
      _currentQuestionDetails = newUserRecord;
      // Assert that the key exists and is not null before casting
      assert(_currentQuestionDetails!.containsKey('question_type') && _currentQuestionDetails!['question_type'] != null, 
             "Question details missing 'question_type'");
      // Directly cast to non-nullable String - will throw if not a String
      _currentQuestionType = _currentQuestionDetails!['question_type'] as String; 
      _timeDisplayed = DateTime.now();
      
      // Add the question to answer history cache when it's requested (not when answered)
      await _historyCache.addRecord(questionId);
      
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
      QuizzerLogger.logMessage("Received a userAnswer of $userAnswer");
      
      // --- ADDED: Check for Dummy Record State --- 
      if (_currentQuestionRecord == null) {
        // This means the dummy "No Questions" record is loaded
        QuizzerLogger.logWarning('submitAnswer called when no real question was loaded (currentQuestionRecord is null).');
        signalQuestionAnsweredCorrectly("dummy_no_questions");
        return {'success': true, 'message': 'No real question loaded to submit answer for.'};
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
            isCorrect = validateMultipleChoiceAnswer(
              userAnswer: userAnswer,
              correctIndex: correctIndex,
            );
            break;
          case 'select_all_that_apply':
            final List<int> correctIndices = currentCorrectIndices; // Use getter
            isCorrect = validateSelectAllThatApplyAnswer(
              userAnswer: userAnswer,
              correctIndices: correctIndices,
            );
            break;
          case 'true_false':
            // User answer should be 0 (True) or 1 (False)
            // QuizzerLogger.logMessage("Evaluating true/false correctness");
            assert(currentCorrectOptionIndex != null);
            // QuizzerLogger.logMessage("provided answer is: $userAnswer");
            // QuizzerLogger.logMessage("CorrectOptionIndex is: $currentCorrectOptionIndex");
            int finalAnswer = 3; // 3 is not valid and will trigger an error. . .
            if (userAnswer == "true" || userAnswer == true) {
              finalAnswer = 0;
            } else if (userAnswer == "false" || userAnswer == false) {
              finalAnswer = 1;
            }
            // QuizzerLogger.logMessage("$userAnswer transformed in $finalAnswer, passing the value of $finalAnswer into validation");
            isCorrect = validateTrueFalseAnswer(
              userAnswer: finalAnswer,
              correctIndex: currentCorrectOptionIndex!,
            );
            break;
          case 'sort_order':
            // Get the correct order (List<Map<String, dynamic>>) using existing getter
            final List<Map<String, dynamic>> correctOrder = currentQuestionOptions;
            // Validate user's answer (expected List<Map<String, dynamic>>)
            isCorrect = validateSortOrderAnswer(
              userAnswer: userAnswer,
              correctOrder: correctOrder,
            );
            break;
          case 'fill_in_the_blank':
            // Validate user's answer (expected List<String>) against the question's answers_to_blanks
            final Map<String, dynamic> validationResult = await validateFillInTheBlankAnswer(userAnswer as List<String>);
            isCorrect = validationResult['isCorrect'] as bool;
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

      // --- Record Answer Attempt (at time of presentation) ---
      // Keep a copy of the record *before* updates for the attempt log
      
      // Call the top-level helper function from session_helper.dart
      await UserAnswerSubmitter().recordQuestionAnswerAttempt(
        isCorrect: isCorrect,
        userId: userId!,
        questionId: questionId,
      );
      
      // We got a null check operator error, so there is a potential that one of these two timestamps failed to be generated
      double reactionTime = (
        (_timeAnswerGiven ?? DateTime.now())
        .difference(
          _timeDisplayed ?? DateTime.now().subtract(const Duration(seconds: 60))
        )
      ).inMicroseconds / Duration.microsecondsPerSecond;

      // --- Update User-Question Pair Record ---
      // Update user-question pair record (this now handles all DB operations internally)
      await UserAnswerSubmitter().updateUserQuestionRecordOnAnswer(
        isCorrect: isCorrect,
        questionId: questionId,
        reactionTime: reactionTime,
      );

      // --- Update Daily User Stats ---
      await UserDailyStatsTable().updateAllUserDailyStats(isCorrect: isCorrect, reactionTime: reactionTime, questionId: questionId);

      // --- Signal completion and update in-memory state ---
      // Don't send signal until the current question is updated in the DB
      if (isCorrect) {
        signalQuestionAnsweredCorrectly(questionId);
      }
      
      QuizzerLogger.logMessage('Successfully submitted answer for QID: $questionId, isCorrect: $isCorrect, userAnswer: $userAnswer');
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
    // --- Type-specific --- (Add more as needed)
    List<Map<String, dynamic>>?       options, // For MC & SelectAll
    int?                              correctOptionIndex, // For MC & TrueFalse
    List<int>?                        indexOptionsThatApply, // For select_all_that_apply
    List<Map<String, List<String>>>?  answersToBlanks, // For fill_in_the_blank
  }) async {
    // TODO Refactor this entire chain of logic into the QuestionGenerator to handle the switch statement internally, then the API layer here 
    // just needs to collect the data and pass it on, and not worry about routing logic
    try {
      QuizzerLogger.logMessage('Entering addNewQuestion()...');
      QuizzerLogger.logMessage('SessionManager: Attempting to add new question of type $questionType');
      
      // --- Pre-checks --- 
      assert(userId != null, 'User must be logged in to add a question.'); 

      // --- Database Operation (table functions handle their own DB access) --- 
      Map<String, dynamic> response;

      switch (questionType) {
        case 'multiple_choice':
          // Validate required fields for this type
          if (options == null || correctOptionIndex == null) {
            throw ArgumentError('Missing required fields for multiple_choice: options and correctOptionIndex.');
          }
          // Call refactored function with correct args
          await QuestionGenerator().addQuestionMultipleChoice(
            questionElements: questionElements,
            answerElements: answerElements,
            options: options,
            correctOptionIndex: correctOptionIndex,
          );
          break;

        case 'select_all_that_apply':
          // Validate required fields for this type
          if (options == null || indexOptionsThatApply == null) {
            throw ArgumentError('Missing required fields for select_all_that_apply: options and indexOptionsThatApply.');
          }
          // Call refactored function with correct args
          await QuestionGenerator().addQuestionSelectAllThatApply(
            questionElements: questionElements,
            answerElements: answerElements,
            options: options,
            indexOptionsThatApply: indexOptionsThatApply,
          );
          break;

        // --- Add cases for other question types here --- 
        case 'true_false':
          // Validate required fields for this type using assert (Fail Fast)
          if (correctOptionIndex == null) {
              throw ArgumentError('Missing required field correctOptionIndex for true_false');
          }
          
          // Call refactored function with correct args
          await QuestionGenerator().addQuestionTrueFalse(
              questionElements: questionElements,
              answerElements: answerElements,
              correctOptionIndex: correctOptionIndex, // Already checked non-null
            );
          break;
        
        case 'sort_order':
          // Validate the new sortOrderOptions parameter
          if (options == null) {
            throw ArgumentError('Missing required field for sort_order: sortOrderOptions (List<String>).');
          }
          // Call the specific function using the correct parameter
          await QuestionGenerator().addSortOrderQuestion(
            questionElements: questionElements,
            answerElements: answerElements,
            options: options, // Pass the validated List<String>
          );
          break;

        case 'fill_in_the_blank':
          // Validate required fields for this type
          if (answersToBlanks == null) {
            throw ArgumentError('Missing required field for fill_in_the_blank: answersToBlanks.');
          }
          // Call the specific function for fill_in_the_blank
          await QuestionGenerator().addFillInTheBlankQuestion(
            questionElements: questionElements,
            answerElements: answerElements,
            answersToBlanks: answersToBlanks,
          );
          break;

        default:
          throw UnimplementedError('Adding questions of type \'$questionType\' is not yet supported.');
      }
      
      QuizzerLogger.logMessage('SessionManager.addNewQuestion: Question added successfully.');
      // --- Return Result ---
      response = {};
      QuizzerLogger.logMessage('Successfully added new question of type: $questionType');
      return response;
    } catch (e) {
      QuizzerLogger.logError('Error in addNewQuestion - $e');
      rethrow;
    }
  }


  /// Fetches the full details of a question by its ID (for UI preview, editing, etc.)
  Future<Map<String, dynamic>> fetchQuestionDetailsById(String questionId) async {
    try {
      QuizzerLogger.logMessage('Entering fetchQuestionDetailsById()...');
      
      // Table function handles its own database access
      final details = await QuestionAnswerPairManager().getQuestionAnswerPairById(questionId);
      
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
    List<Map<String, dynamic>>? questionElements,
    List<Map<String, dynamic>>? answerElements,
    List<int>? indexOptionsThatApply,
    bool? ansFlagged,
    String? ansContrib,
    String? qstReviewer,
    bool? hasBeenReviewed,
    bool? flagForRemoval,
    String? questionType,
    List<Map<String, dynamic>>? options,
    int? correctOptionIndex,
    List<Map<String, dynamic>>? correctOrderElements,
    List<Map<String, List<String>>>? answersToBlanks, // Added for fill-in-the-blank
  }) async {
    try {
      QuizzerLogger.logMessage('Entering updateExistingQuestion()...');
      
      // Fail fast if not logged in
      assert(userId != null, 'User must be logged in to update a question.');
      
      // Table function handles its own database access
      final int result = await QuestionAnswerPairManager().editQuestionAnswerPair(
        questionId: questionId,
        questionElements: questionElements,
        answerElements: answerElements,
        indexOptionsThatApply: indexOptionsThatApply,
        ansFlagged: ansFlagged,
        ansContrib: ansContrib,
        qstReviewer: qstReviewer,
        hasBeenReviewed: hasBeenReviewed,
        flagForRemoval: flagForRemoval,
        questionType: questionType,
        options: options,
        correctOptionIndex: correctOptionIndex,
        correctOrderElements: correctOrderElements,
        answersToBlanks: answersToBlanks,
      );
      
      QuizzerLogger.logMessage('Successfully updated existing question with QID: $questionId, rows affected: $result');
      return result;
    } catch (e) {
      QuizzerLogger.logError('Error in updateExistingQuestion - $e');
      rethrow;
    }
  }

  /// Adds a flag for a question answer pair.
  /// This creates a temporary local record that will be synced to the server and then deleted.
  /// Also marks the user's question as flagged to prevent it from being shown until reviewed.
  /// Returns true if successful, false otherwise.
  Future<bool> addQuestionFlag({
    required String questionId,
    required String flagType,
    required String flagDescription,
  }) async {
    try {
      QuizzerLogger.logMessage('Entering addQuestionFlag()...');
      
      // Fail fast if not logged in
      assert(userId != null, 'User must be logged in to add a question flag.');
      
      // Table function handles its own database access and validation
      final int result = await QuestionAnswerPairFlagsTable().upsertRecord({
        'question_id': questionId,
        'flag_type': flagType,
        'flag_description': flagDescription,
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      });
      
      final bool flagAdded = result > 0;
      if (flagAdded) {
        // Also toggle the flagged status in the user_question_answer_pairs table
        final bool flaggedToggled = await UserQuestionManager().toggleUserQuestionFlaggedStatus(
          questionId: questionId,
        );
        
        if (flaggedToggled) {
          QuizzerLogger.logMessage('Successfully added question flag for QID: $questionId, type: $flagType and marked as flagged');
          return true;
        } else {
          QuizzerLogger.logWarning('Flag was added but failed to mark question as flagged for QID: $questionId');
          return false;
        }
      } else {
        QuizzerLogger.logMessage('Failed to add question flag for QID: $questionId, type: $flagType');
        return false;
      }
    } catch (e) {
      QuizzerLogger.logError('Error in addQuestionFlag - $e');
      return false;
    }
  }


  // =====================================================================
  // --- User Settings API ---
  // =====================================================================
  /// Expose the SettingsManager() public functions
  SettingsManager settings = SettingsManager();

  // =====================================================================
  // --- Review System Interface ---
  // =====================================================================
  /// Expose the QuestionReviewManager() public function
  QuestionReviewManager questionReviewManager = QuestionReviewManager();


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
  Future<void> reportError({
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

      // Use the table's upsertRecord method
      await ErrorLogsTable().upsertRecord({
        if (id != null) 'id': id,
        'user_id': userId,
        'error_message': errorMessage,
        if (userFeedback != null) 'user_feedback': userFeedback,
      });
      
      QuizzerLogger.logMessage('Successfully reported error');
    } catch (e) {
      QuizzerLogger.logError('Error in reportError - $e');
      rethrow;
    }
  }

  // ================================================================================
  // --- User Feedback Functionality ---
  // ================================================================================
  // TODO move to page specific api for the user feedback page, then expose the userFeedbackPage api here
  /// Submits user feedback to the local database.
  ///
  /// Returns the ID of the created feedback record.
  Future<int> submitUserFeedback({
    required String feedbackType,
    required String feedbackContent,
  }) async {
    try {
      // The table's finishRecord method will handle ID generation and other fields
      return await UserFeedbackTable().upsertRecord({
        'user_id': SessionManager().userId, // Can be null for anonymous feedback
        'feedback_type': feedbackType,
        'feedback_content': feedbackContent,
      });
    } catch (e) {
      QuizzerLogger.logError('Error in submitUserFeedback - $e');
      rethrow;
    }
  }

  // =====================================================================
  // --- User Stats API (Eligible Questions) ---
  // =====================================================================
  // TODO Since individual stat tables are removed, we have removed all individual api calls, to be replaced with one master api call
  // TODO create a stats object that will serve as the api to collect user stats, and expose that object here. (this object should double as a cache of data to be updated whenever the update stats is called, individual stats are already cached in concrete stat objects, so we can just expose those through the stats object)
}