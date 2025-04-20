import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/account_creation/new_user_signup.dart' as account_creation;
import 'package:quizzer/backend_systems/login_authentication/user_auth.dart';
import 'package:quizzer/backend_systems/module_management/module_updates_process.dart';
import 'package:quizzer/backend_systems/module_management/module_isolates.dart';
import 'package:quizzer/backend_systems/session_manager/session_isolates.dart';
import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/database_manager/database_monitor.dart';
import 'package:hive/hive.dart';

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
  String? currentQuestionId;

  // MetaData
  DateTime? sessionStartTime;
  
  // Page history tracking
  final List<String> _pageHistory = [];
  static const int _maxHistoryLength = 12;

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
  Future<void> _initialize(String email) async {
    userLoggedIn = true;
    userEmail = email;
    userId = await initializeSession({'email': email});
    sessionStartTime = DateTime.now();
    // Initial process spin up
    buildModuleRecords();
    QuizzerLogger.logMessage('SessionManager initialization complete');
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
    QuizzerLogger.logMessage('Session Manager: Attempting login for $email');
    final response = await userAuth(
      email: email,
      password: password,
      supabase: supabase,
      storage: _storage,
    );

    if (response['success'] == true) {
      await _initialize(email); // initialize function spins up necessary background processes
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

  // Get previous page
  String? getPreviousPage() {
    QuizzerLogger.logMessage('Current page history: $_pageHistory');
    if (_pageHistory.length < 2) {
      QuizzerLogger.logMessage('Not enough pages for previous page');
      return null;
    }
    final previousPage = _pageHistory[_pageHistory.length - 2];
    QuizzerLogger.logMessage('Previous page: $previousPage');
    return previousPage;
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
  void toggleModuleActivation(String moduleName, bool activate) async {
    /*
    does not need to be awaited, UI will have to accomodate
    */
    assert(userId != null);
    
    QuizzerLogger.logMessage('Toggling module activation for user: $userId, module: $moduleName, activate: $activate');
    handleModuleActivation({
      'userId': userId,
      'moduleName': moduleName,
      'isActive': activate,
    });
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



  /// Get the database monitor instance
  DatabaseMonitor get dbMonitor => _dbMonitor;

}

// Global instance
final SessionManager _globalSessionManager = SessionManager();

/// Gets the global session manager instance
SessionManager getSessionManager() => _globalSessionManager;
