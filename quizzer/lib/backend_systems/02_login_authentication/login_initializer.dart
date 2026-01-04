import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/02_login_authentication/user_auth.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/inbound_sync/inbound_sync_worker.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/outbound_sync/outbound_sync_worker.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/media_sync_worker.dart';
import 'package:quizzer/backend_systems/09_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_helper_utils/utils.dart' as utils;
import 'package:quizzer/backend_systems/04_ml_modeling/accuracy_net_worker.dart';
import 'package:quizzer/backend_systems/05_question_queue_server/circulation_worker.dart';
import 'package:quizzer/backend_systems/05_question_queue_server/question_selection_worker.dart';
import 'package:quizzer/backend_systems/08_data_caches/question_queue_cache.dart';
import 'package:quizzer/backend_systems/05_question_queue_server/user_questions/user_question_manager.dart';
import 'dart:async';
import 'package:quizzer/backend_systems/09_switch_board/sb_other_signals.dart';
import 'package:supabase/supabase.dart';
import 'package:hive/hive.dart';
import 'package:email_validator/email_validator.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/initialization_table_verification.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/system_data/login_attempts_table.dart';
import 'package:quizzer/backend_systems/01_account_creation_and_management/account_manager.dart';
import 'package:quizzer/backend_systems/04_ml_modeling/ml_model_manager.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';


class LoginInitializer {

  // ======================================================================
  // ----- API For Login Initializer -----
  // ======================================================================
  // authType is for telling the initializer which login auth process to use (whether a social login or email and password)
  // Valid authType arguments ["google_login", "email_login"]
  Future<Map<String,dynamic>?> loginUserAuthenticateAndInitializeCoreQuizzerSystem({
    required SupabaseClient supabase,
    required Box storage,
    required String authType,
    required String email,
    required String password,
    bool testRun = false,
    bool noQueueServer = false
  }) async{
    // Return immediately if not connected
    QuizzerLogger.logMessage('Entering loginUserAuthenticateAndInitializeCoreQuizzerSystem()...');
    // First attempt to login our user using whichever authentication option they chose
    late final Map<String,dynamic> loginResult;
    if (authType == "email_login") {
      // If the email is not provided for email login this process should fail and return naturally
      loginResult = await _performLoginProcess(
        email: email,
        password: password,
        supabase: supabase,
        storage: storage,
      );
    } else if (authType == "google_login") {
      loginResult = await _performGoogleLoginProcess(supabase: supabase, storage: storage);
    } else {
      QuizzerLogger.logError("Invalid AuthType provided, must be either, 'email_login' or 'google_login'");
      return null;
    }

    // If login failed, return early
    if (!loginResult['success']) {return loginResult;} else {
      // Otherwise:
      await _storeOfflineLoginData(email, storage, loginResult);
    }


    // After we validate the user we will ensure that all the tables needed for Quizzer are present and in correct form:
    // Login Process should have initialized the SessionManager() which is required for the validation to pass
    await InitializationTableVerification().verifyOnLogin();

    // Get whether we are still connected to the internet or not, this will be used to decide if sync mechanisms and other sub-systems are started
    bool isConnected = await utils.checkConnectivity();
    if (!isConnected) {return {
      'success': false,
      'message': 'No internetConnection'
    };}

    // Initialize the Sync Workers (this function call shall fail if no connection)
    signalLoginProgress("Checking your data...");
    // Check if database is fresh and handle sync workers accordingly
    if (!testRun) {
      await _initializeSyncWorkers();
    } else {
      QuizzerLogger.logMessage('Skipping sync workers for test run');
    }

    await InitializationTableVerification().verifyAfterSync();

    // Initialize question queue server (circulation and selection workers)
    if (!noQueueServer) {
    signalLoginProgress("Starting question queue server...");
    QuizzerLogger.logMessage('Initializing question queue server...');
    await _startQuestionQueueServer();
    } else {
      QuizzerLogger.logMessage('Skipping question queue server initialization for test run');
    }

    // Return results
    // await _logAuthResults(loginResult, email)
    signalLoginProgress("Welcome back! You're all set.");
    QuizzerLogger.logMessage('Login initialization completed for email: $email');
    return loginResult;
  }


  // ======================================================================
  // ----- Sub-System Initialization Sequence -----
  // ======================================================================
  /// Starts all question queue server workers in the correct order
  /// This function should be called after data caches are initialized
  /// Waits for a question to be added to the queue cache before returning
  Future<void> _startQuestionQueueServer() async {
    try {
      QuizzerLogger.logMessage('Starting question queue server workers...');
      // Start CirculationWorker first
      QuizzerLogger.logMessage('Starting CirculationWorker...');
      final circulationWorker = CirculationWorker();
      circulationWorker.start(); // Don't await - start in rapid succession
      
      // Start PresentationSelectionWorker second
      QuizzerLogger.logMessage('Starting PresentationSelectionWorker...');
      final presentationSelectionWorker = PresentationSelectionWorker();
      presentationSelectionWorker.start(); // Don't await - start in rapid succession
      
      QuizzerLogger.logMessage('Starting AccuracyNetWorker...');
      final accuracyNetWorker = AccuracyNetWorker();
      await accuracyNetWorker.start();

      QuizzerLogger.logMessage('Question queue server worker startup initiated');
      
      // Check if there are eligible questions for the user
      if (SessionManager().userId != null) {
        final eligibleQuestions = await UserQuestionManager().getEligibleUserQuestionAnswerPairs();
        
        if (eligibleQuestions.isNotEmpty) {
          QuizzerLogger.logMessage('Found ${eligibleQuestions.length} eligible questions - waiting for questions to be added to cache...');
          
          // Wait for at least one question to be added to the cache
          final questionQueueCache = QuestionQueueCache();
          while (await questionQueueCache.getLength() == 0) {
            await Future.delayed(const Duration(milliseconds: 100)); // Small delay to avoid busy waiting
          }
          
          QuizzerLogger.logSuccess('Questions are now available in cache');
        } else {
          QuizzerLogger.logMessage('No eligible questions found - proceeding without waiting');
        }
      } else {
        QuizzerLogger.logMessage('No user logged in - proceeding without waiting for questions');
      }
      
    } catch (e) {
      QuizzerLogger.logError('Error starting question queue server workers - $e');
      rethrow;
    }
  }

  /// Initializes the sync workers for online login.
  /// Starts inbound sync worker, waits for first cycle completion,
  /// then starts outbound and media sync workers.
  Future<bool> _initializeSyncWorkers() async {
    try {
      // check connection, If the user has no internet do not attempt to sync data, do not start the sync mechanism
      bool isConnected = await utils.checkConnectivity();
      if (!isConnected) {
        QuizzerLogger.logMessage("No Internet Connection, Sync Workers have not been started");
        return false;}


      QuizzerLogger.logMessage('Initializing sync workers...');
      
      // Start inbound sync worker
      QuizzerLogger.logMessage('Starting inbound sync worker...');
      final inboundSyncWorker = InboundSyncWorker();
      inboundSyncWorker.start();
      
      // Wait for inbound sync cycle to complete before starting other workers
      QuizzerLogger.logMessage('Waiting for inbound sync cycle to complete...');
      final switchBoard = SwitchBoard();
      await switchBoard.onInboundSyncCycleComplete.first;
      QuizzerLogger.logSuccess('Inbound sync cycle completed');
      
      // Update lastLogin after inbound sync completes it's cycle
      QuizzerLogger.logMessage('Updating last login timestamp after successful inbound sync...');
      if (SessionManager().userId != null) {
        await AccountManager().updateLastLogin();
        QuizzerLogger.logSuccess('Last login timestamp updated successfully');
      } else {
        QuizzerLogger.logError('Cannot update last login: userId is null');
      }

      // Start outbound sync worker
      QuizzerLogger.logMessage('Starting outbound sync worker...');
      final outboundSyncWorker = OutboundSyncWorker();
      outboundSyncWorker.start();
      
      // Start media sync worker
      QuizzerLogger.logMessage('Starting media sync worker...');
      final mediaSyncWorker = MediaSyncWorker();
      // before main start, check and update ml_models are up to date, then start main image sync
      await MlModelManager().updateMlModels();
      mediaSyncWorker.start();
      
      QuizzerLogger.logSuccess('Sync workers initialized successfully');
      return true;
    } catch (e) {
      QuizzerLogger.logError('Error initializing sync workers: $e');
      rethrow;
    }
  }

  // ======================================================================
  // ----- Login Sequence -----
  // ======================================================================
  // The login sequence handles exclusively the process to authenticate the user session, these do NOT
  // handle the initialization of subsystems
  /// Performs the core login process including validation, authentication, offline login handling,
  /// profile management, and SessionManager initialization.
  /// 
  /// Steps: (each encapsulated in private functions)
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
  Future<Map<String, dynamic>> _performLoginProcess({
    required String email,
    required String password,
    required SupabaseClient supabase,
    required Box storage,
  }) async {
    QuizzerLogger.logMessage('Entering performLoginProcess()...');
    signalLoginProgress("Starting login process...");

    // ======================================================================
    // We must first validate that the form fields are correct
    final validationResult = await _validateFormFields(email, password);
    if (!validationResult['valid']) {
      QuizzerLogger.logWarning('Form validation failed: ${validationResult['message']}');
      return {
        'success': false,
        'message': validationResult['message']
      };
    }

    // ======================================================================
    // check for internet connection

    bool isConnected = await _isUserConnected();
    // ======================================================================


    // ======================================================================
    // Attempt Login and log the results
    Map<String, dynamic> authResult   = await _attemptSupabaseLoginAuth(isConnected, email, password, supabase, storage);
    Map<String, dynamic> loginResult  = await _determineLoginResult(authResult, email, storage);
    if (!loginResult['success']) {
      signalLoginProgress("Login failed. Please check your credentials.");
      QuizzerLogger.logWarning('Login failed, terminating login process');
      return loginResult;
    }
    // ======================================================================




    // ======================================================================
    // Login was successful, proceed to initialize the session and user profile

    // Ensure that the user profile record in the db exists in both the supabase and local databases,
    // Sync if necessary
    await AccountManager().syncUserProfileOnLogin(email, supabase);

    // Initialize the SessionManager with user profile info
    await _initializeSessionManager(loginResult, email);
    return loginResult;
    // ======================================================================
  }

  Future<Map<String, dynamic>> _performGoogleLoginProcess({
    required SupabaseClient supabase,
    required Box storage,
  }) async {
    try {
      QuizzerLogger.logMessage('Entering performLoginProcess()...');

      signalLoginProgress("Starting login process...");

      // Step 1: Check connectivity and attempt user authentication
      signalLoginProgress("Checking connection...");
      final bool isConnected = await utils.checkConnectivity();

      Map<String, dynamic> authResult;
      if (isConnected) {
        signalLoginProgress("Connecting to your account...");
        authResult = await _attemptSupabaseGoogleLogin(
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
        final offlineResult = _checkOfflineLogin(email, storage, authResult);
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
      await LoginAttemptsTable().upsertRecord({
        'email': email,
        'status_code': loginResult['message'], // Assuming the column name is 'status_code'
      });

      // If login failed outright, return after recording the attempt
      if (!loginResult['success']) {
        signalLoginProgress("Login failed. Please check your credentials.");
        QuizzerLogger.logWarning('Login failed, terminating login process');
        return loginResult;
      }

      // Step 6: Ensure local profile exists
      await AccountManager().syncUserProfileOnLogin(email, supabase);

      // Step 7: Initialize SessionManager
      await _initializeSessionManager(loginResult, email);

      QuizzerLogger.logSuccess('Login process completed successfully for email: $email');
      return loginResult;
    } catch (e) {
      QuizzerLogger.logError('Error in performGoogleLoginProcess - $e');
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> _attemptSupabaseGoogleLogin(SupabaseClient supabase, Box storage) async {
    try {
      QuizzerLogger.logMessage('Supabase authentication via Google Sign-In starts....');

      const iosClientId = '840944709865-uqouqdi16cvpm624n3eacufuuk8grpqp.apps.googleusercontent.com';
      const androidClientId = '840944709865-krhsd92b2ph6k670q1j872c8m5pcqhnk.apps.googleusercontent.com';

      // ✅ Generate a random nonce and SHA256 it
      final rawNonce = utils.generateNonce();
      final hashedNonce = utils.sha256ofString(rawNonce);

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: Platform.isIOS
            ? iosClientId
            : androidClientId,
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) throw 'Google sign-in canceled';

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null || accessToken == null) {
        throw 'Missing Google token(s)';
      }

      // Pass the nonce to Supabase
      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
        nonce: hashedNonce,
      );

      QuizzerLogger.logMessage('Google Sign-In response: $response');
      QuizzerLogger.logMessage('Attempting Supabase authentication via Google Sign-In, Response: $response');

      final String email = response.user?.email ?? 'unknown_email';


      // Success Case
      QuizzerLogger.logSuccess('Supabase authentication successful for $email');
      final authResult = {
        'success': true,
        'message': 'Login successful',
        'user': response.user, // <-- Keep as Supabase User object
        'session': response.session, // <-- Keep session as object
        'user_role': SessionManager().userRole,
      };
      return authResult;
    } on AuthException catch (e) {
      QuizzerLogger.logWarning('Supabase authentication failed via Google: ${e.message}');
      return {
        'success': false,
        'message': e.message,
        'user_role': 'public_user_unverified',
        // Default on failure
      };
    } catch (e) {
      QuizzerLogger.logError('Error during Supabase Google Sign-In: $e');
      return {
        'success': false,
        'message': e.toString(),
        'user_role': 'public_user_unverified',
        // Default on failure
      };
    }
  }

  // ======================================================================
  // ----- Utility calls, Form Validation & Logging-----
  // ======================================================================
  /// First step of Initialization
  /// Validates login form fields using email_validator package
  /// Returns a map with 'valid' boolean and 'message' string
  Future<Map<String, dynamic>> _validateFormFields(String email, String password) async {
    signalLoginProgress("Validating your information...");
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

  /// Checks if the user is connected to the internet
  Future<bool> _isUserConnected() async{
    // Step Check connectivity and attempt user authentication
    signalLoginProgress("Checking connection...");
    return await utils.checkConnectivity();
  }


  // ======================================================================
  // ----- Hive Storage, CRUD -----
  // ======================================================================
  /// Stores offline login data in Hive storage
  /// 
  /// Stores a structured JSON object containing:
  /// - last_sign_in_at: timestamp of last successful login
  /// - user_id: user's unique identifier (from local profile)
  /// - user_role: user's role/permissions
  /// - offline_login_count: number of offline logins (starts at 0)
  /// - last_online_sync: timestamp of last online sync
  ///
  /// Note: Access tokens are NOT stored for security reasons
  Future<void> _storeOfflineLoginData(
      String email,
      Box storage,
      Map<String, dynamic> authResult,
      ) async {
    try {
      QuizzerLogger.logMessage('Storing offline login data for $email');

      final user = authResult['user'];
      final userRole = authResult['user_role'];

      // Get the local user profile UUID, not the Supabase user ID
      final localUserId = await AccountManager().getUserIdByEmail(email);

      // Safely extract last_sign_in_at from both User or Map types
      dynamic lastSignInAt;
      if (user is User) {
        lastSignInAt = user.lastSignInAt;
      } else if (user is Map<String, dynamic>) {
        lastSignInAt = user['last_sign_in_at'];
      } else {
        lastSignInAt = DateTime.now().toIso8601String();
      }

      final loginData = {
        'last_sign_in_at': lastSignInAt,
        'user_id': localUserId,
        'user_role': userRole,
        'offline_login_count': 0,
        'last_online_sync': DateTime.now().toIso8601String(),
      };

      await storage.put(email, loginData);
      QuizzerLogger.logSuccess('Offline login data stored for $email');
    } catch (e) {
      QuizzerLogger.logError('Error storing offline login data for $email - $e');
      rethrow;
    }
  }

  /// Retrieves offline login data from Hive storage
  /// 
  /// Returns the structured JSON object or null if not found/invalid
  Map<String, dynamic>? _getOfflineLoginData(String email, Box storage) {
    try {
      QuizzerLogger.logMessage('Retrieving offline login data for $email');
      
      final data = storage.get(email);
      if (data is Map<String, dynamic>) {
        QuizzerLogger.logMessage('Offline login data found for $email');
        return data;
      }
      
      QuizzerLogger.logMessage('No valid offline login data found for $email');
      return null;
    } catch (e) {
      QuizzerLogger.logError('Error retrieving offline login data for $email - $e');
      return null;
    }
  }

  /// Clears offline login data for a specific user
  /// 
  /// Removes all stored login data for the given email
  Future<void> clearOfflineLoginData(String email, Box storage) async {
    // TODO Currently Not called anywhere, decide what to do with this functionality
    try {
      QuizzerLogger.logMessage('Clearing offline login data for $email');
      await storage.delete(email);
      QuizzerLogger.logSuccess('Offline login data cleared for $email');
    } catch (e) {
      QuizzerLogger.logError('Error clearing offline login data for $email - $e');
      rethrow;
    }
  }

  // ======================================================================
  // ----- User Authentication -----
  // ======================================================================
  /// Returns the result of the attempted supabased Authentication
  Future<Map<String, dynamic>> _attemptSupabaseLoginAuth(
    bool isConnected, 
    String email, 
    String password,
    SupabaseClient supabase,
    Box storage
    ) async {
    Map<String, dynamic> authResult;
    if (isConnected) {
      signalLoginProgress("Connecting to your account...");
      authResult = await UserAuth().attemptSupabaseLogin(
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
    return authResult;
  }

  /// Determine whether offline_mode is active or not
  /// If the authorization was not successful, will decide whether the user is authorized to login offline
  /// If the authorization was successful, passes back the authResult Map unaltered
  Future<Map<String, dynamic>> _determineLoginResult(Map<String, dynamic> authResult, String email, Box storage) async {
    // Unified variable for login results throughout the process
    // Ensure offline_mode is always present (default to false for online login)
    Map<String, dynamic> loginResult = authResult;
    loginResult['offline_mode'] = false;

    if (!loginResult['success']) {
      signalLoginProgress("Checking for offline access...");
      QuizzerLogger.logMessage('Supabase login failed, checking for offline login...');
      final offlineResult = _checkOfflineLogin(email, storage, authResult);
      if (offlineResult['success']) {
        signalLoginProgress("Offline access granted...");
        QuizzerLogger.logSuccess('Offline login successful for $email');
        loginResult = offlineResult; // Replace with offline result but continue
      } else {
        QuizzerLogger.logWarning('Both online and offline login failed for $email');
        // Continue to step 5 to record the failed attempt
      }
    }
    return loginResult;
  }

  Future<void> _logAuthResults(Map<String, dynamic> loginResult, String email) async {
    // FIXME appears to be causing issues, review later (removed from flow)
    if (loginResult['success'] && !loginResult['offline_mode']) {
      signalLoginProgress("Login successful...");
      QuizzerLogger.logMessage('Supabase login successful, offline login data already stored');
    }

    QuizzerLogger.logMessage('Recording login attempt...');
    await LoginAttemptsTable().upsertRecord({
      'email': email,
      'status_code': loginResult['message'],
    });
  }

  /// Checks Hive storage for a recent offline login and updates results accordingly
  /// 
  /// Validates if the last login was within 30 days and returns appropriate results
  /// Note: Offline login does NOT provide Supabase access - user must re-authenticate for online features
  Map<String, dynamic> _checkOfflineLogin(String email, Box storage, Map<String, dynamic> currentResults) {
    try {
      QuizzerLogger.logMessage('Checking for offline login data for $email');
      Map<String, dynamic> updatedResults = Map.from(currentResults);
      
      // Always initialize offline_mode to false
      updatedResults['offline_mode'] = false;

      final loginData = _getOfflineLoginData(email, storage);
      if (loginData != null) {
        final lastSignInAt = loginData['last_sign_in_at'] as String;
        final lastLogin = DateTime.parse(lastSignInAt);
        final today = DateTime.now();
        final difference = today.difference(lastLogin).inDays;

        QuizzerLogger.logMessage('Last login for $email was $difference days ago');
        
        if (difference <= 30) {
          QuizzerLogger.logMessage('Recent offline login detected for $email');
          
          // Increment offline login count
          final currentCount = loginData['offline_login_count'] as int? ?? 0;
          loginData['offline_login_count'] = currentCount + 1;
          storage.put(email, loginData);
          
          updatedResults = {
            'success': true,
            'message': 'offline_login',
            'user_id': loginData['user_id'],
            'user_role': loginData['user_role'],
            'offline_login_count': loginData['offline_login_count'],
            'offline_mode': true, // Flag to indicate offline mode
          };
        } else {
          QuizzerLogger.logMessage('Offline login data found but expired for $email');
          updatedResults['message'] = 'Offline login expired. Please connect and log in online.';
          // offline_mode remains false
        }
      } else {
        QuizzerLogger.logMessage('No valid offline login data found for $email');
        // Keep the original error message from the Supabase failure
        // offline_mode remains false
      }
      
      return updatedResults;
    } catch (e) {
      QuizzerLogger.logError('Error checking offline login for $email - $e');
      rethrow;
    }
  }



  // ======================================================================
  // ----- Session Manager Initialization -----
  // ======================================================================
  // Spin up necessary processes and get userID from local profile, effectively intialize any session specific variables that should only be brought after successful login
  Future<void> _initializeSessionManager(Map<String, dynamic> loginResult, String email) async {
    try {
      QuizzerLogger.logMessage("Recorded email to log in. . .: $email");
      // --------------------------------------------------
      // Set SessionManager user state for offline login
      // --------------------------------------------------
      // Ensure SessionManager is marked as logged in (boolean)
      SessionManager().userLoggedIn = true;
      // --------------------------------------------------
      // Ensure the SessionManager is storing the user id for this account
      SessionManager().userId = await AccountManager().getUserIdByEmail(email);
      // --------------------------------------------------
      // Ensure the SessionManager is storing the email that was retrieved
      SessionManager().userEmail = email;
      // --------------------------------------------------
      // Ensure the SessionManager is given the sessionStartTime for purpose of recording user activity
      SessionManager().sessionStartTime = DateTime.now();
      QuizzerLogger.logSuccess('SessionManager initialized with user ID: ${SessionManager().userId} for offline login');
      QuizzerLogger.logSuccess('Login process completed successfully for email: $email');
    } catch (e) {
      QuizzerLogger.logError('Error initializing session - $e');
      rethrow;
    }
  }

}