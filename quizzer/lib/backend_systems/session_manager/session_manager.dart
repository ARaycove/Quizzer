import 'package:quizzer/backend_systems/07_user_question_management/functionality/user_question_processes.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart';
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
    _storage = await Hive.openBox('async_prefs', path: 'test');
  }
  
  // Supabase client instance
  late final SupabaseClient supabase;

  // Database monitor instance
  final DatabaseMonitor _dbMonitor = getDatabaseMonitor();

  // Session state variables

  // The active user information (These don't get initialized until we first login with a user)
  bool userLoggedIn = false;
  String? userId;
  String? userEmail;
  String? userRole;

  // Current Question information and booleans
  String? currentQuestionRecord;
  bool    isAnswerDisplayed = false;
  int?    multipleChoiceOptionSelected; // would be null if no option is presently selected


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

    //TODO Finish the question queue process

    //TODO Create data sync process, connecting the local DB to the cloud


    QuizzerLogger.logMessage('SessionManager initialization complete');
  }

  // Reset Complete Session State
  void clearSessionState() {
    // Reset user information
    userLoggedIn = false;       userId = null;                  userEmail = null;
    userRole = null;            currentQuestionRecord = null;   isAnswerDisplayed = false;
    sessionStartTime = null;    multipleChoiceOptionSelected = null;
    _pageHistory.clear();
    
    QuizzerLogger.logMessage('Session state has been reset');
  }

  // Reset Question State
  void clearQuestionState() {
    currentQuestionRecord = null;         isAnswerDisplayed = false;
    multipleChoiceOptionSelected = null;
    
    QuizzerLogger.logMessage('Question state has been reset');
  }
  /// ==================================================================================
  // Private API Calls for testing and internal use (When tests are complete these should all be made private, during testing they will be public so we can use them in our tests)

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

    // Call the backend function
    userPairs = await getUserQuestionAnswerPairsByUser(userId!, db);
    QuizzerLogger.logMessage('Fetched ${userPairs.length} pairs for user $userId');

    // Release DB
    dbMonitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('DB released after fetching user pairs.');

    return userPairs;
  }


  /// ==================================================================================
  // API CALLS
  //  ------------------------------------------------
  // Request Question from Queue
  /// Provides an API endpoint within SessionManager to call the external getNextQuestion function.
  Future<Map<String, dynamic>?> requestNextQuestion() async {
    QuizzerLogger.logMessage('SessionManager API: Requesting next question');
    return await getNextQuestion(); 
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
    if (_pageHistory.length > _maxHistoryLength) {
      QuizzerLogger.logMessage('Removing oldest page: ${_pageHistory[0]}');
      _pageHistory.removeAt(0);
    }
    QuizzerLogger.logMessage('Updated page history: $_pageHistory');
  }

  // Get previous page, skipping '/menu'
  String getPreviousPage() {
    QuizzerLogger.logMessage('Attempting to get previous page. Current history: $_pageHistory');
    // Iterate backwards from the second-to-last entry
    for (int i = _pageHistory.length - 2; i >= 0; i--) {
      final page = _pageHistory[i];
      if (page != '/menu') {
        QuizzerLogger.logMessage('Found valid previous page: $page');
        return page; // Return the first non-menu page found
      }
    }
    // If no suitable page is found (or history is too short) return that home is the previous page
    QuizzerLogger.logMessage('No suitable previous page found (excluding /menu).');
    return '/home';
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
    if (userId == null) {
      QuizzerLogger.logError('Cannot load modules: No user ID in session');
      return {'modules': [], 'activationStatus': {}};
    }
    
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
    if (userId == null) {
      QuizzerLogger.logError('Cannot update module: No user ID in session');
      return false;
    }
    
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

    // Rebuild the module records locally
    buildModuleRecords();
    // Validate the user profile questions (that way if the added question belongs to a module they've added to it will get shown to them)
    Database? db;
    while (db == null) {
      db = await dbMonitor.requestDatabaseAccess();
      if (db == null) {
        QuizzerLogger.logMessage('Database access denied, waiting...');
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }
    await validateAllModuleQuestions(db, userId!);
    dbMonitor.releaseDatabaseAccess();

    // End of function  
  }



  /// Get the database monitor instance
  DatabaseMonitor get dbMonitor => _dbMonitor;

}

// Global instance
final SessionManager _globalSessionManager = SessionManager();

/// Gets the global session manager instance
SessionManager getSessionManager() => _globalSessionManager;
