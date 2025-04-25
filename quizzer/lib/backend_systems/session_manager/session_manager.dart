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
import 'package:quizzer/backend_systems/07_user_question_management/functionality/user_question_processes.dart' show validateAllModuleQuestions;
import 'package:quizzer/backend_systems/09_data_caches/module_inactive_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/unprocessed_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/non_circulating_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/circulating_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/due_date_beyond_24hrs_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/due_date_within_24hrs_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/eligible_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/question_queue_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/answer_history_cache.dart';


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
  late Box _storage;
  // Completer to signal when async initialization (like storage) is done
  final Completer<void> _initializationCompleter = Completer<void>();
  /// Future that completes when asynchronous initialization is finished.
  /// Await this before accessing components that depend on async init (e.g., _storage).
  Future<void> get initializationComplete => _initializationCompleter.future;
  // Supabase client instance
  late final SupabaseClient supabase;
  // Database monitor instance
  final DatabaseMonitor _dbMonitor = getDatabaseMonitor();
  // Cache Instances (as instance variables)
  final UnprocessedCache                _unprocessedCache;
  final NonCirculatingQuestionsCache _nonCirculatingCache;
  final ModuleInactiveCache _moduleInactiveCache;
  final CirculatingQuestionsCache _circulatingCache;
  final DueDateBeyond24hrsCache _dueDateBeyondCache;
  final DueDateWithin24hrsCache _dueDateWithinCache;
  final EligibleQuestionsCache _eligibleCache;
  final QuestionQueueCache _queueCache;
  final AnswerHistoryCache _historyCache;
  bool      userLoggedIn = false;
  String?   userId;
  String?   userEmail;
  String?   userRole;
  // Current Question information and booleans
  Map<String, dynamic>? _currentQuestionRecord;
  String?               _currentQuestionType;
  bool                  _isAnswerDisplayed = false;
  int?                  _multipleChoiceOptionSelected; // would be null if no option is presently selected
  DateTime?             _timeDisplayed;
  DateTime?             _timeAnswerGiven;
  // --- Public Getters for UI State ---
  Map<String, dynamic>? get currentQuestionData   => _currentQuestionRecord;
  String?               get currentType           => _currentQuestionType;
  bool                  get showingAnswer         => _isAnswerDisplayed;
  int?                  get optionSelected        => _multipleChoiceOptionSelected;
  DateTime?             get timeAnswerGiven       => _timeAnswerGiven;
  DateTime?             get timeQuestionDisplayed => _timeDisplayed;
  // MetaData
  DateTime? sessionStartTime;
  // Page history tracking
  final List<String> _pageHistory = [];
  static const int _maxHistoryLength = 12;

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
        _historyCache = AnswerHistoryCache() {
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

    // TODO: Implement separate data sync process initialization if needed

    // Optional: Keep a delay if needed for UI/other reasons, or remove.
    // TODO: create a mechanism to detect when the question maintainer worker has started and picked an initial question
    await Future.delayed(const Duration(seconds: 3));
    QuizzerLogger.logMessage('SessionManager post-worker-start initialization complete');
  }

  // Reset Complete Session State
  void clearSessionState() {
    // Reset user information
    userLoggedIn = false;       userId = null;                    userEmail = null;
    userRole = null;            _currentQuestionRecord = null;    _isAnswerDisplayed = false;
    sessionStartTime = null;    _multipleChoiceOptionSelected = null;
    _timeAnswerGiven = null;    _timeDisplayed = null;
    _pageHistory.clear();
    
    QuizzerLogger.logMessage('Session state has been reset');
  }

  // Reset Question State
  void clearQuestionState() {
    _currentQuestionRecord        = null;  _isAnswerDisplayed   = false;
    _multipleChoiceOptionSelected = null;  _currentQuestionType = null;
    _timeAnswerGiven              = null;  _timeDisplayed       = null;
    
    QuizzerLogger.logMessage('Question state has been reset');
  }
  
  // --- Public Setters for UI Interaction State ---
  void setMultipleChoiceSelection(int? index) {
    // Add any validation if needed
    _multipleChoiceOptionSelected = index;
    QuizzerLogger.logMessage('UI set multiple choice selection to: $index');
  }

  void setAnswerDisplayed(bool isDisplayed) {
    // Add any validation if needed
    _isAnswerDisplayed = isDisplayed;
    // Also set timeAnswerGiven when answer is displayed
    if (isDisplayed) {
        _timeAnswerGiven = DateTime.now();
         QuizzerLogger.logMessage('UI set timeAnswerGiven to: $_timeAnswerGiven');
    }
     QuizzerLogger.logMessage('UI set answer displayed state to: $isDisplayed');
  }

  // New Setter for display time
  void setQuestionDisplayTime() {
    _timeDisplayed = DateTime.now();
    _timeAnswerGiven = null; // Reset answer time when new question is displayed
    QuizzerLogger.logMessage('UI set timeDisplayed to: $_timeDisplayed');
  }
  /// ==================================================================================
  // API CALLS
  //  ------------------------------------------------
  /// Called when answer is given by the user to a particular question
  Future<bool> submitAnswer() async {
    QuizzerLogger.logMessage("submitAnswer called.");
    
    // --- Use validation helper function --- 
    // Stop if state is invalid
    
    assert(_isCurrentQuestionStateValidForSubmission());
    // -------------------------------------
    final questionId = _currentQuestionRecord!['question_id'] as String;
    
    // --- Skip processing for dummy question --- 
    if (questionId == 'dummy_question_01') {
      QuizzerLogger.logMessage('Skipping answer submission for dummy question.');
      return true; // Indicate handled (by skipping)
    }
    // ------------------------------------------
    
    // --- Calculate Time to Answer ---
    final Duration timeDifference = _timeAnswerGiven!.difference(_timeDisplayed!); 
    // Assert that time difference is not negative (Fail Fast)
    assert(!timeDifference.isNegative, "Time difference cannot be negative! _timeAnswerGiven ($_timeAnswerGiven) should be after _timeDisplayed ($_timeDisplayed)");
    // Calculate time in seconds with microsecond precision
    final double timeToAnswer = timeDifference.inMicroseconds / 1000000;
    QuizzerLogger.logMessage("Calculated timeToAnswer: $timeToAnswer seconds.");
    
    // --- Determine Answer Status ---
    String answerStatus = "incorrect"; // Default to incorrect
    final correctIndex = _currentQuestionRecord!['correct_option_index'] as int?; // Still check for null from DB
    
    if (correctIndex == null) {
        QuizzerLogger.logError("Cannot determine answer status: correct_option_index is missing or null in record for $questionId.");
        // Keep status as incorrect
    } else if (_multipleChoiceOptionSelected == correctIndex) {
        // _multipleChoiceOptionSelected might be null, but comparison handles it
        answerStatus = "correct";
    }
    QuizzerLogger.logMessage("Determined answerStatus: $answerStatus");

    // TODO Should call backend functions for this
    // recordQuestionAttempt(questionId, userId!, timeToAnswer, answerStatus);

    
    return true; // Indicate submission process completed 
  }

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

  // API for activating or deactivating a module
  Future<void> toggleModuleActivation(String moduleName, bool activate) async {
    assert(userId != null);
    QuizzerLogger.logMessage('Toggling module activation for user: $userId, module: $moduleName, activate: $activate'); 
    await handleModuleActivation({
      'userId': userId,
      'moduleName': moduleName,
      'isActive': activate,
    });

    // When activation status is updated we also need to validate the profile questions
    Database? db;
    while (db == null) {
      db = await _dbMonitor.requestDatabaseAccess();
      if (db == null) {
        QuizzerLogger.logMessage('SessionManager: Database access denied, waiting...');
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }

    final currentUserId = userId!;
    await validateAllModuleQuestions(db, currentUserId);
    
    // Now use the instance variable instead of creating a new instance
    await _moduleInactiveCache.flushToUnprocessedCache(); 

    _dbMonitor.releaseDatabaseAccess();
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
  
  //  ------------------------------------------------
  // Add & Edit Question_Answer Pairs
  // API for adding a question-answer pair to the database
  Future<void> addQuestionAnswerPair({
    required String timeStamp,
    required List<Map<String, dynamic>> questionElements,
    required List<Map<String, dynamic>> answerElements,
    required String moduleName,
    required String questionType,
    required List<String>? sourcePaths, // If there are media to be uploaded they need to be passed
    List<String>? options,
    int? correctOptionIndex,
  }) async {
    // Validation
    assert(userId != null);
    // Need to construct the map before passing 
    // Create a map with required fields
    final Map<String, dynamic> questionData = {
      'timeStamp':        timeStamp,
      'questionElements': questionElements,
      'answerElements':   answerElements,
      'ansFlagged':       false,
      'ansContrib':       userId,
      'qstContrib':       userId,
      'hasBeenReviewed':  false,
      'flagForRemoval':   false,
      'moduleName':       moduleName,
      'questionType':     questionType,
    };
    // Add optional fields only if they're not null
    if (options != null) {questionData['options'] = options;}
    if (correctOptionIndex != null) {questionData['correctOptionIndex'] = correctOptionIndex;}
    

    // Add the Question Answer Pair to the database
    QuizzerLogger.logMessage('Adding question-answer pair for module: $moduleName');
    await handleAddQuestionAnswerPair({
      'timeStamp':          timeStamp,
      'questionElements':   questionElements,
      'answerElements':     answerElements,
      'ansFlagged':         false,
      'ansContrib':         userId,
      'qstContrib':         userId,
      'hasBeenReviewed':    false,
      'flagForRemoval':     false,
      'moduleName':         moduleName,
      'questionType':       questionType,
      'options':            options,
      'correctOptionIndex': correctOptionIndex,
      });
    // If there was an image related to the question answer pair submitted, move it to the correct location
    // Move any image files to their final location if sourcePaths are provided
    if (sourcePaths != null && sourcePaths.isNotEmpty) {
      for (final path in sourcePaths) {
        try {
          await moveImageToFinalLocation(path);
          QuizzerLogger.logMessage('Moved image file: $path');
        } catch (e) {
          QuizzerLogger.logError('Failed to move image file: $path - Error: $e');
          // Continue with other files even if one fails
        }
      }
    }

    // Validate the user profile questions (that way if the added question belongs to a module they've added to it will get shown to them)
    Database? db;
    while (db == null) {
      db = await dbMonitor.requestDatabaseAccess();
      if (db == null) {
        QuizzerLogger.logMessage('Database access denied, waiting...');
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }
    dbMonitor.releaseDatabaseAccess();
    // End of function  
  }



  /// Get the database monitor instance
  DatabaseMonitor get dbMonitor => _dbMonitor;

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
}

// Global instance
final SessionManager _globalSessionManager = SessionManager();

/// Gets the global session manager instance
SessionManager getSessionManager() => _globalSessionManager;
