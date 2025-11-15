import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/07_user_question_management/user_question_processes.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
import 'package:quizzer/backend_systems/02_login_authentication/user_auth.dart';
import 'package:quizzer/backend_systems/02_login_authentication/offline_login.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_attempts_record.dart';
import 'package:quizzer/backend_systems/02_login_authentication/sync_worker_init.dart';
import 'package:quizzer/backend_systems/02_login_authentication/queue_server_init.dart';
import 'dart:async';
import 'package:quizzer/backend_systems/10_switch_board/sb_other_signals.dart';
import 'package:supabase/supabase.dart';
import 'package:hive/hive.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_daily_stats_table.dart';
import 'package:email_validator/email_validator.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/outbound_sync/outbound_sync_functions.dart';
import 'package:quizzer/backend_systems/00_helper_utils/utils.dart';
import 'package:quizzer/backend_systems/02_login_authentication/verify_all_tables.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/system_data/login_attempts_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';


// Spin up necessary processes and get userID from local profile, effectively intialize any session specific variables that should only be brought after successful login
Future<String?> initializeSession(Map<String, dynamic> data) async {
  try {
    final email = data['email'] as String;
    QuizzerLogger.logMessage("Recorded email to log in. . .: $email");

    final userId = await getUserIdByEmail(email);

    QuizzerLogger.logSuccess('Session initialized with userId: $userId');
    return userId;
  } catch (e) {
    QuizzerLogger.logError('Error initializing session - $e');
    rethrow;
  }
}

/// Validates login form fields using email_validator package
/// Returns a map with 'valid' boolean and 'message' string
Map<String, dynamic> validateLoginForm(String email, String password) {
  try {
    QuizzerLogger.logMessage('Entering _validateLoginForm()...');
    
    // Check for empty email
    if (email.isEmpty) {
      return {
        'valid': false,
        'message': 'Please enter your email address'
      };
    }
    
    // Check for empty password
    if (password.isEmpty) {
      return {
        'valid': false,
        'message': 'Please enter your password'
      };
    }
    
    // Use email_validator package for robust email validation
    if (!EmailValidator.validate(email)) {
      return {
        'valid': false,
        'message': 'Please enter a valid email address'
      };
    }
    
    QuizzerLogger.logMessage('Form validation passed for email: $email');
    return {
      'valid': true,
      'message': 'Validation successful'
    };
  } catch (e) {
    QuizzerLogger.logError('Error in _validateLoginForm - $e');
    return {
      'valid': false,
      'message': 'Validation error occurred'
    };
  }
}

/// Performs the core login process including validation, authentication, offline login handling,
/// profile management, and SessionManager initialization.
/// 
/// Steps:
/// 1. Validate form fields (email, password)
/// 2. Attempt user authentication
/// 3. Handle unsuccessful login (potential offline login)
/// 4. Handle successful login
/// 5. Record login attempt
/// 6. Ensure local profile exists
/// 7. Initialize SessionManager
/// 
/// Returns the login result which can be used to determine if login was successful
/// and whether it was online or offline mode.
Future<Map<String, dynamic>> performLoginProcess({
  required String email,
  required String password,
  required SupabaseClient supabase,
  required Box storage,
}) async {
  try {
    QuizzerLogger.logMessage('Entering performLoginProcess()...');
    
    signalLoginProgress("Starting login process...");
    
    // Step 1: Validate form fields
    signalLoginProgress("Validating your information...");
    final validationResult = validateLoginForm(email, password);
    if (!validationResult['valid']) {
      QuizzerLogger.logWarning('Form validation failed: ${validationResult['message']}');
      return {
        'success': false,
        'message': validationResult['message']
      };
    }
    
    // Step 2: Check connectivity and attempt user authentication
    signalLoginProgress("Checking connection...");
    final bool isConnected = await checkConnectivity();
    
    Map<String, dynamic> authResult;
    if (isConnected) {
      signalLoginProgress("Connecting to your account...");
      authResult = await attemptSupabaseLogin(
        email,
        password,
        supabase,
        storage,
      );
    } else {
      QuizzerLogger.logMessage('No network connectivity detected, defaulting to offline login');
      signalLoginProgress("No internet connection detected...");
      authResult = {
        'success': false,
        'message': 'No internet connection available',
        'user_role': 'public_user_unverified',
      };
    }

    // Unified variable for login results throughout the process
    // Ensure offline_mode is always present (default to false for online login)
    Map<String, dynamic> loginResult = Map<String, dynamic>.from(authResult);
    loginResult['offline_mode'] = false; // Default to online mode

    // Step 3: Handle unsuccessful login (potential offline login)  
    if (!loginResult['success']) {
      signalLoginProgress("Checking for offline access...");
      QuizzerLogger.logMessage('Supabase login failed, checking for offline login...');
      final offlineResult = checkOfflineLogin(email, storage, authResult);
      if (offlineResult['success']) {
        signalLoginProgress("Offline access granted...");
        QuizzerLogger.logSuccess('Offline login successful for $email');
        loginResult = offlineResult; // Replace with offline result but continue
      } else {
        QuizzerLogger.logWarning('Both online and offline login failed for $email');
        // Continue to step 5 to record the failed attempt
      }
    }

    // Step 4: Handle successful login (offline login data already stored by attemptSupabaseLogin)
    if (loginResult['success'] && !loginResult['offline_mode']) {
      signalLoginProgress("Login successful...");
      QuizzerLogger.logMessage('Supabase login successful, offline login data already stored');
    }

    // Step 5: Record login attempt
    QuizzerLogger.logMessage('Recording login attempt...');
    await recordLoginAttempt(
      email: email,
      statusCode: loginResult['message'],
    );

    // If login failed outright, return after recording the attempt
    if (!loginResult['success']) {
      signalLoginProgress("Login failed. Please check your credentials.");
      QuizzerLogger.logWarning('Login failed, terminating login process');
      return loginResult;
    }

    // Step 6: Ensure local profile exists

    bool hasLocalProfile = false; // Track if local profile exists
    
    if (loginResult['offline_mode']) {
      // Offline login - check if we have a local profile
      signalLoginProgress("Checking your local profile...");
      QuizzerLogger.logMessage('Checking local profile for offline login...');
      final emailList = await getAllUserEmails();
      hasLocalProfile = emailList.contains(email);
      
      if (!hasLocalProfile) {
        signalLoginProgress("Offline access requires online login first.");
        QuizzerLogger.logWarning('Offline login attempted but no local profile found for $email');
        return {
          'success': false,
          'message': 'Offline login requires local profile. Please connect and log in online.'
        };
      }
      signalLoginProgress("Local profile found...");
      QuizzerLogger.logSuccess('Local profile found for offline login: $email');
    } else {
      // Online login - ensure profile exists or fetch/create it
      signalLoginProgress("Setting up your profile...");
      QuizzerLogger.logMessage('Ensuring local profile exists for online login...');
      await ensureLocalProfileExists(email);

      // Ensure profile exists in Supabase as well
      signalLoginProgress("Syncing your profile...");
      QuizzerLogger.logMessage('Ensuring profile exists in Supabase for online login...');
      await ensureUserProfileExistsInSupabase(email, supabase);
    }

    // Step 7: Initialize SessionManager
    if (loginResult['offline_mode']) {
      signalLoginProgress("Initializing your session...");
      QuizzerLogger.logMessage('Initializing SessionManager for offline login...');
      final sessionManager = getSessionManager();
      final userId = await getUserIdByEmail(email);
      
      // Set SessionManager user state for offline login
      sessionManager.userLoggedIn = true;
      sessionManager.userId = userId;
      sessionManager.userEmail = email;
      sessionManager.sessionStartTime = DateTime.now();
      
      QuizzerLogger.logSuccess('SessionManager initialized with user ID: $userId for offline login');
    } else {
      QuizzerLogger.logMessage('SessionManager already initialized by attemptSupabaseLogin for online login');
    }

    QuizzerLogger.logSuccess('Login process completed successfully for email: $email');
    return loginResult;
  } catch (e) {
    QuizzerLogger.logError('Error in performLoginProcess - $e');
    rethrow;
  }
}

Future<Map<String, dynamic>> performGoogleLoginProcess({
  required SupabaseClient supabase,
  required Box storage,
}) async {
  try {
    QuizzerLogger.logMessage('Entering performLoginProcess()...');

    signalLoginProgress("Starting login process...");

    // Step 1: Check connectivity and attempt user authentication
    signalLoginProgress("Checking connection...");
    final bool isConnected = await checkConnectivity();

    Map<String, dynamic> authResult;
    if (isConnected) {
      signalLoginProgress("Connecting to your account...");
      authResult = await attemptSupabaseGoogleLogin(
        supabase,
        storage,
      );
    } else {
      QuizzerLogger.logMessage('No network connectivity detected, defaulting to offline login');
      signalLoginProgress("No internet connection detected...");
      authResult = {
        'success': false,
        'message': 'No internet connection available',
        'user_role': 'public_user_unverified',
      };
    }



    User? user = authResult['user'];
    String email = user?.email ?? '';


    // Unified variable for login results throughout the process
    // Ensure offline_mode is always present (default to false for online login)
    Map<String, dynamic> loginResult = Map<String, dynamic>.from(authResult);
    loginResult['offline_mode'] = false; // Default to online mode

    // Step 3: Handle unsuccessful login (potential offline login)
    if (!loginResult['success']) {
      signalLoginProgress("Checking for offline access...");
      QuizzerLogger.logMessage('Supabase login failed, checking for offline login...');
      final offlineResult = checkOfflineLogin(email, storage, authResult);
      if (offlineResult['success']) {
        signalLoginProgress("Offline access granted...");
        QuizzerLogger.logSuccess('Offline login successful for $email');
        loginResult = offlineResult; // Replace with offline result but continue
      } else {
        QuizzerLogger.logWarning('Both online and offline login failed for $email');
        // Continue to step 5 to record the failed attempt
      }
    }

    // Step 4: Handle successful login (offline login data already stored by attemptSupabaseLogin)
    if (loginResult['success'] && !loginResult['offline_mode']) {
      signalLoginProgress("Login successful...");
      QuizzerLogger.logMessage('Supabase login successful, offline login data already stored');
    }

    // Step 5: Record login attempt
    QuizzerLogger.logMessage('Recording login attempt...');
    await recordLoginAttempt(
      email: email,
      statusCode: loginResult['message'],
    );

    // If login failed outright, return after recording the attempt
    if (!loginResult['success']) {
      signalLoginProgress("Login failed. Please check your credentials.");
      QuizzerLogger.logWarning('Login failed, terminating login process');
      return loginResult;
    }

    // Step 6: Ensure local profile exists

    bool hasLocalProfile = false; // Track if local profile exists

    if (loginResult['offline_mode']) {
      // Offline login - check if we have a local profile
      signalLoginProgress("Checking your local profile...");
      QuizzerLogger.logMessage('Checking local profile for offline login...');
      final emailList = await getAllUserEmails();
      hasLocalProfile = emailList.contains(email);

      if (!hasLocalProfile) {
        signalLoginProgress("Offline access requires online login first.");
        QuizzerLogger.logWarning('Offline login attempted but no local profile found for $email');
        return {
          'success': false,
          'message': 'Offline login requires local profile. Please connect and log in online.'
        };
      }
      signalLoginProgress("Local profile found...");
      QuizzerLogger.logSuccess('Local profile found for offline login: $email');
    } else {
      // Online login - ensure profile exists or fetch/create it
      signalLoginProgress("Setting up your profile...");
      QuizzerLogger.logMessage('Ensuring local profile exists for online login...');
      await ensureLocalProfileExists(email);

      // Ensure profile exists in Supabase as well
      signalLoginProgress("Syncing your profile...");
      QuizzerLogger.logMessage('Ensuring profile exists in Supabase for online login...');
      await ensureUserProfileExistsInSupabase(email, supabase);
    }

    // Step 7: Initialize SessionManager
    if (loginResult['offline_mode']) {
      signalLoginProgress("Initializing your session...");
      QuizzerLogger.logMessage('Initializing SessionManager for offline login...');
      final sessionManager = getSessionManager();
      final userId = await getUserIdByEmail(email);

      // Set SessionManager user state for offline login
      sessionManager.userLoggedIn = true;
      sessionManager.userId = userId;
      sessionManager.userEmail = email;
      sessionManager.sessionStartTime = DateTime.now();

      QuizzerLogger.logSuccess('SessionManager initialized with user ID: $userId for offline login');
    } else {
      QuizzerLogger.logMessage('SessionManager already initialized by attemptSupabaseLogin for online login');
    }

    QuizzerLogger.logSuccess('Login process completed successfully for email: $email');
    return loginResult;
  } catch (e) {
    QuizzerLogger.logError('Error in performGoogleLoginProcess - $e');
    rethrow;
  }
}

/// Single function that handles the login initialization process. Called directly by the attemptLogin function api call of the SessionManager Class.
/// Steps:
/// 1. Perform core login process (validation, authentication, profile management, SessionManager initialization)
/// 2. Check if database is fresh (only user_profile and login_attempts tables exist)
/// 3. If fresh: await sync workers to populate database with initial data
/// 4. If not fresh: start sync workers in background (don't await)
/// 5. Initialize question queue server
/// 6. Return authentication results, which allow the UI to navigate to the home page
/// 
/// [testRun] - When true, bypasses sync worker initialization for testing purposes
/// [noQueueServer] - When true, skips queue server initialization for testing purposes
Future<Map<String, dynamic>> loginInitialization({
  required String email,
  required String password,
  required SupabaseClient supabase,
  required Box storage,
  bool testRun = false,
  bool noQueueServer = false,
}) async {
  try {
    QuizzerLogger.logMessage('Entering loginInitialization()...');
    // Make sure the table exists (only during setup and right before its first needed)
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    // Wrap in transaction to ensure it commits
    await db!.transaction((txn) async {
    await verifyUserProfileTable(txn);
    await verifyLoginAttemptsTable(txn);
    });

    getDatabaseMonitor().releaseDatabaseAccess();
    // Step 1: Perform core login process
    final loginResult = await performLoginProcess(
      email: email,
      password: password,
      supabase: supabase,
      storage: storage,
    );

    // If login failed, return early
    if (!loginResult['success']) {
      return loginResult;
    }

    // After we validate the user we will ensure that all the tables needed for Quizzer are present and in correct form:
    SessionManager session = getSessionManager();
    verifyAllTablesExist(session.userId);

    // Step 2: Check if database is fresh and handle sync workers accordingly
    if (!loginResult['offline_mode'] && !testRun) {
      signalLoginProgress("Checking your data...");
      QuizzerLogger.logMessage('Checking database state for sync worker initialization...');
      
      // Initialize sync workers
      await initializeSyncWorkers();
      
      QuizzerLogger.logSuccess('Sync workers started in background for existing database');
    } else {
      if (testRun) {
        QuizzerLogger.logMessage('Skipping sync workers for test run');
      } else {
        QuizzerLogger.logMessage('Skipping sync workers for offline login');
      }
    }

    // Step 3: Initialize question queue server (circulation and selection workers)
    if (!noQueueServer) {
    signalLoginProgress("Starting question queue server...");
    QuizzerLogger.logMessage('Initializing question queue server...');
    await startQuestionQueueServer();
    } else {
      QuizzerLogger.logMessage('Skipping question queue server initialization for test run');
    }

    // Step 4: Update settings cache and stats before returning
    if (!loginResult['offline_mode'] && !testRun) {
      signalLoginProgress("Updating your data...");
      QuizzerLogger.logMessage('Updating settings cache and stats before returning...');
      
      final sessionManager = getSessionManager();
      
      // // DEBUG: Check user_settings table contents before getUserSettings
      // QuizzerLogger.logMessage("Get Settings BEFORE first get user settings call");
      // logUserSettingsTableContent();
      
      final allSettings = await sessionManager.getUserSettings(getAll: true);
      QuizzerLogger.logMessage("When updating the cache we get these list of settings $allSettings");
      
      // // DEBUG: Check user_settings table contents after getUserSettings
      // QuizzerLogger.logMessage("Get Settings AFTER first get user settings call");
      // logUserSettingsTableContent();
      
      sessionManager.setCachedUserSettings(allSettings);
      
      // Update stats using the stat update aggregator - this creates daily records
      await updateAllUserDailyStats(sessionManager.userId!);

      // Ensure no missing modules
      await ensureAllQuestionModuleNamesHaveCorrespondingModuleRecords();

      // Ensure no missing user question records
      await validateAllModuleQuestions(session.userId!);
      
      QuizzerLogger.logSuccess('Settings cache and stats updated successfully');
    }

    // Step 5: Return results
    signalLoginProgress("Welcome back! You're all set.");
    
    QuizzerLogger.logMessage('Login initialization completed for email: $email');
    return loginResult;
  } catch (e) {
    QuizzerLogger.logError('Error in loginInitialization - $e');
    rethrow;
  }
}

Future<Map<String, dynamic>> googleLoginInitialization({
  required SupabaseClient supabase,
  required Box storage,
  bool testRun = false,
  bool noQueueServer = false,
}) async {
  try {
    QuizzerLogger.logMessage('Entering loginInitialization()...');
    // Make sure the table exists (only during setup and right before its first needed)
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    // Wrap in transaction to ensure it commits
    await db!.transaction((txn) async {
      await verifyUserProfileTable(txn);
      await verifyLoginAttemptsTable(txn);
    });

    getDatabaseMonitor().releaseDatabaseAccess();
    // Step 1: Perform core login process
    final loginResult = await performGoogleLoginProcess(
      supabase: supabase,
      storage: storage,
    );

    User? user = loginResult['user'];
    String email = user?.email ?? '';

    // If login failed, return early
    if (!loginResult['success']) {
      return loginResult;
    }

    // After we validate the user we will ensure that all the tables needed for Quizzer are present and in correct form:
    SessionManager session = getSessionManager();
    verifyAllTablesExist(session.userId);

    // Step 2: Check if database is fresh and handle sync workers accordingly
    if (!loginResult['offline_mode'] && !testRun) {
      signalLoginProgress("Checking your data...");
      QuizzerLogger.logMessage('Checking database state for sync worker initialization...');

      // Initialize sync workers
      await initializeSyncWorkers();

      QuizzerLogger.logSuccess('Sync workers started in background for existing database');
    } else {
      if (testRun) {
        QuizzerLogger.logMessage('Skipping sync workers for test run');
      } else {
        QuizzerLogger.logMessage('Skipping sync workers for offline login');
      }
    }

    // Step 3: Initialize question queue server (circulation and selection workers)
    if (!noQueueServer) {
      signalLoginProgress("Starting question queue server...");
      QuizzerLogger.logMessage('Initializing question queue server...');
      await startQuestionQueueServer();
    } else {
      QuizzerLogger.logMessage('Skipping question queue server initialization for test run');
    }

    // Step 4: Update settings cache and stats before returning
    if (!loginResult['offline_mode'] && !testRun) {
      signalLoginProgress("Updating your data...");
      QuizzerLogger.logMessage('Updating settings cache and stats before returning...');

      final sessionManager = getSessionManager();

      // // DEBUG: Check user_settings table contents before getUserSettings
      // QuizzerLogger.logMessage("Get Settings BEFORE first get user settings call");
      // logUserSettingsTableContent();

      final allSettings = await sessionManager.getUserSettings(getAll: true);
      QuizzerLogger.logMessage("When updating the cache we get these list of settings $allSettings");

      // // DEBUG: Check user_settings table contents after getUserSettings
      // QuizzerLogger.logMessage("Get Settings AFTER first get user settings call");
      // logUserSettingsTableContent();

      sessionManager.setCachedUserSettings(allSettings);

      // Update stats using the stat update aggregator - this creates daily records
      await updateAllUserDailyStats(sessionManager.userId!);

      // Ensure no missing modules
      await ensureAllQuestionModuleNamesHaveCorrespondingModuleRecords();

      // Ensure no missing user question records
      await validateAllModuleQuestions(session.userId!);

      QuizzerLogger.logSuccess('Settings cache and stats updated successfully');
    }

    // Step 5: Return results
    signalLoginProgress("Welcome back! You're all set.");

    QuizzerLogger.logMessage('Login initialization completed for email: $email');
    return loginResult;
  } catch (e) {
    QuizzerLogger.logError('Error in googleLoginInitialization - $e');
    rethrow;
  }
}

Future<void> ensureUserProfileExistsInSupabase(String email, SupabaseClient supabase) async {
  try {
    // 1. Try to fetch the profile from Supabase
    final response = await supabase
        .from('user_profile')
        .select()
        .eq('email', email)
        .maybeSingle();

    if (response == null) {
      // 2. If not found, get the local profile
      final localProfile = await getUserProfileByEmail(email);
      if (localProfile == null) {
        throw Exception('No local profile found for $email');
      }

      // 3. Insert the local profile into Supabase using the universal sync function
      final bool pushSuccess = await pushRecordToSupabase('user_profile', localProfile);
      if (!pushSuccess) {
        throw Exception('Failed to insert user profile into Supabase using pushRecordToSupabase');
      }
    }
  } catch (e) {
    QuizzerLogger.logError('Error in ensureUserProfileExistsInSupabase - $e');
    rethrow;
  }
}