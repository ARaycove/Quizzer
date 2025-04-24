import 'package:quizzer/backend_systems/06_question_queue_server/question_queue_maintainer.dart';
import 'package:quizzer/backend_systems/07_user_question_management/functionality/user_question_processes.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/03_account_creation/new_user_signup.dart' as account_creation;
import 'package:quizzer/backend_systems/06_question_queue_server/question_queue_request.dart';
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
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile_table.dart' as user_profile_table;
import 'package:quizzer/backend_systems/06_question_queue_server/answered_history_monitor.dart';


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
  
  // Initialize Hive storage without encryption
  Future<void> _initializeStorage() async {
    // Let hive_flutter determine the correct path automatically
    _storage = await Hive.openBox('async_prefs');
  }
  
  // Supabase client instance
  late final SupabaseClient supabase;

  // Database monitor instance
  final DatabaseMonitor _dbMonitor = getDatabaseMonitor();

  // Session state variables

  // The active user information (These don't get initialized until we first login with a user)
  // FIXME Security assertions and validation of user authentication all throughout session
  // Once we attempt login and the session is set, these variables will be assigned. At that point a lock of sorts should be placed upon them. A security check would then determine if the values have been changed, or altered at any point.
  // If and Only If the user logs out should the state allowed to be changed.
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


  // SessionManager Constructor
  SessionManager._internal() {
    supabase = SupabaseClient(
      'https://yruvxuvzztnahuuiqxit.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlydXZ4dXZ6enRuYWh1dWlxeGl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQzMTY1NDIsImV4cCI6MjA1OTg5MjU0Mn0.hF1oAILlmzCvsJxFk9Bpjqjs3OEisVdoYVZoZMtTLpo',
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
    _initializeStorage();
  }

  /// Initialize the SessionManager and its dependencies
  /// This 
  Future<void> _initializeLogin(String email) async {
    userLoggedIn = true;
    userEmail = email;
    userId = await initializeSession({'email': email});
    sessionStartTime = DateTime.now();
    // Initial process spin up
    buildModuleRecords();

    startQuestionQueueMaintenance();

    //TODO Create data sync process, connecting the local DB to the cloud
    Database? db;
    while (db == null) {
      db = await _dbMonitor.requestDatabaseAccess();
      if (db == null) {
        QuizzerLogger.logMessage('DB access denied for updating circulation, waiting...');
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    await validateAllModuleQuestions(db, userId!);
    _dbMonitor.releaseDatabaseAccess();

    // QuestionQueueMonitor questionQueueMonitor = getQuestionQueueMonitor();
    // while(questionQueueMonitor.isEmpty) {}
    
    // Wait for 3 seconds before completing initialization
    await Future.delayed(const Duration(seconds: 3));
    QuizzerLogger.logMessage('SessionManager initialization complete');
  }

  // Reset Complete Session State
  void clearSessionState() {
    // Reset user information
    userLoggedIn = false;       userId = null;                  userEmail = null;
    userRole = null;            _currentQuestionRecord = null;   _isAnswerDisplayed = false;
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
  // ---------------------------------------------

  /// ==================================================================================
  // Private API Calls for testing and internal use (When tests are complete these should all be made private, during testing they will be public so we can use them in our tests)
  //  ------------------------------------------------
  // Get Eligible Questions
  Future<List<Map<String, dynamic>>> getEligibleQuestions() async{
    assert(userId != null);
    Database? db;
    // Acquire DB Access using the established loop pattern
    while (db == null) {
      db = await _dbMonitor.requestDatabaseAccess();
      if (db == null) {
        QuizzerLogger.logMessage('DB access denied for updating circulation, waiting...');
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    List<Map<String, dynamic>> userQuestionRecords = await getAllUserQuestionAnswerPairs(db, userId!);
    _dbMonitor.releaseDatabaseAccess();

    List<Map<String,dynamic>> eligibleQuestionRecords = [];

    for (Map<String, dynamic> userQuestionRecord in userQuestionRecords) {
      bool isEligible = await checkQuestionEligibility(userQuestionRecord['question_id']);
      if (isEligible) {
        eligibleQuestionRecords.add(userQuestionRecord);
      }
    }

    return eligibleQuestionRecords;
  }

  //  ------------------------------------------------
  /// Updates the user-specific record to mark a question as in circulation.
  Future<void> addQuestionToCirculation(String questionId) async {
    assert(userId != null, 'User must be logged in to update circulation status.');
    QuizzerLogger.logMessage('SessionManager: Adding question $questionId to circulation for user $userId');

    Database? db;
    // Acquire DB Access using the established loop pattern
    while (db == null) {
      db = await _dbMonitor.requestDatabaseAccess();
      if (db == null) {
        QuizzerLogger.logMessage('DB access denied for updating circulation, waiting...');
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    QuizzerLogger.logMessage('DB acquired for updating circulation status for $questionId.');

    // Perform the update using the imported function with named parameters
    final int rowsAffected = await editUserQuestionAnswerPair(
      userUuid: userId!, 
      questionId: questionId, 
      db: db, 
      inCirculation: true, // Set inCirculation to true (which becomes 1)
      lastUpdated: DateTime.now().toIso8601String() // Use camelCase: lastUpdated
      );
    
    // Release DB access
    _dbMonitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('DB released after updating circulation status for $questionId.');

    if (rowsAffected == 0) {
        // Fail fast if the specific record wasn't found for update
        QuizzerLogger.logWarning('Update circulation status failed: No record found for user $userId and question $questionId');
        throw Exception('Record not found for user $userId and question $questionId during circulation update.');
    }

    QuizzerLogger.logMessage('Successfully updated circulation status for question $questionId. Rows affected: $rowsAffected');
  }

  //  ------------------------------------------------
  // Get specfic question-answer pair
  /// Fetches the full question record from the main question_answer_pairs table.
  /// Takes questionId in the format 'timeStamp_qstContrib'.
  /// Returns the record map or throws an error if not found or on other issues.
  Future<Map<String, dynamic>> getQuestionAnswerPair(String questionId) async {
    assert(userId != null);
    QuizzerLogger.logMessage('SessionManager API: Fetching question pair for ID $questionId');

    Database? db;
    final dbMonitor = getDatabaseMonitor();
    Map<String, dynamic>? questionRecord;
    // Acquire DB Access
    while (db == null) {
      db = await dbMonitor.requestDatabaseAccess();
      if (db == null) {
        QuizzerLogger.logMessage('DB access denied for fetching question pair, waiting...');
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    QuizzerLogger.logMessage('DB acquired for fetching question pair $questionId.');

    // Call the backend function
    questionRecord = await getQuestionAnswerPairById(questionId, db);
      
    QuizzerLogger.logMessage('Successfully fetched question pair for $questionId');
    
    dbMonitor.releaseDatabaseAccess();
    return questionRecord; 
  }
  
  //  ------------------------------------------------
  // Check User Question Eligibility
  /// Checks if a specific question is eligible for review for the current user.
  /// Returns true if eligible, false otherwise (including if user not logged in).
  Future<bool> checkQuestionEligibility(String questionId) async {
    // FIXME Should be a private api call, but temporarily public during testing, if testing is done make this private
    QuizzerLogger.logMessage('SessionManager API: Checking eligibility for question $questionId');
    assert(userId != null);
    // Call the function from user_question_processes.dart
    return await isUserQuestionEligible(userId!, questionId);
  }
  //  ------------------------------------------------
  // Get All User Question Answer Pairs
  Future<List<Map<String, dynamic>>> getAllUserQuestionPairs() async {
    // FIXME Should be a private api call, but temporarily public during testing, if testing is done make this private
    QuizzerLogger.logMessage('SessionManager API: Fetching all question pairs for user');
    assert(userId != null, 'Cannot fetch user question pairs: User not logged in.');

    Database? db;
    final dbMonitor = getDatabaseMonitor();
    List<Map<String, dynamic>> userPairs;

    // Acquire DB Access
    while (db == null) {
      db = await dbMonitor.requestDatabaseAccess();
      if (db == null) {
        QuizzerLogger.logMessage('DB access denied for fetching user pairs, waiting...');
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    QuizzerLogger.logMessage('DB acquired for fetching user pairs.');

    // Call the backend function using the prefix
    userPairs = await getUserQuestionAnswerPairsByUser(userId!, db);
    QuizzerLogger.logMessage('Fetched ${userPairs.length} pairs for user $userId');

    // Release DB
    dbMonitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('DB released after fetching user pairs.');

    return userPairs;
  }
  
  //  ------------------------------------------------
  // API call to get the user's current subject interest settings
  /// gets the subject interest map for the current user.
  /// Asserts that the user is logged in. Lets backend handle DB errors.
  Future<Map<String, int>> getUserSubjectInterests() async {
    // FIXME Should be a private api call, but temporarily public during testing, if testing is done make this private
    assert(userId != null, 'Cannot fetch user subject interests: User not logged in.');

    Database? db;
    final dbMonitor = getDatabaseMonitor(); 
    Map<String, int> interests;

    // Acquire DB Access
    while (db == null) {
      db = await dbMonitor.requestDatabaseAccess();
      if (db == null) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // Call the backend function directly. Errors will propagate.
    // If this call throws, the DB release below will NOT happen.
    interests = await user_profile_table.getUserSubjectInterests(userId!, db);

    // Release DB (Only happens if getUserSubjectInterests succeeds)
    dbMonitor.releaseDatabaseAccess();
       
    return interests;
  }

  /// ==================================================================================
  // API CALLS
  //  ------------------------------------------------
  // Request Question from Queue
  /// Provides an API endpoint within SessionManager to call the external getNextQuestion function.
  /// When using requestNextQuestion, ensure to set the display time in the UI when the question is actually displayed
  Future<bool> requestNextQuestion() async {
    assert(userId != null);
    QuizzerLogger.logMessage('SessionManager API: Requesting next question');
    // Since we're getting the next question to be presented clear the question state
    clearQuestionState();

    Map<String, dynamic> questionObject = await getNextQuestion(); 
    // Before we return we need to:
    // Store the questionObject as the current record
    _currentQuestionRecord = questionObject;
    // Extract the question type:
    _currentQuestionType   = questionObject['question_type'];

    // Display time will be set by UI

    return true;
  }

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

    recordQuestionAttempt(questionId, userId!, timeToAnswer, answerStatus);

    
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
    QuizzerLogger.logMessage('Session Manager: Attempting login for $email');
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
    /*
    does not need to be awaited, UI will have to accomodate
    */
    assert(userId != null);
    // Toggle the activation Status
    QuizzerLogger.logMessage('Toggling module activation for user: $userId, module: $moduleName, activate: $activate');
    handleModuleActivation({
      'userId': userId,
      'moduleName': moduleName,
      'isActive': activate,
    });

    // When activation status is updated we also need to validate the profile questions
    Database? db;
    while (db == null) {
      db = await dbMonitor.requestDatabaseAccess();
      if (db == null) {
        QuizzerLogger.logMessage('Database access denied, waiting...');
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }
    validateAllModuleQuestions(db, userId!);
    dbMonitor.releaseDatabaseAccess();
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
