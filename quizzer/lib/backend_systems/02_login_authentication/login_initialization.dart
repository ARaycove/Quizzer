import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
import 'package:quizzer/backend_systems/02_login_authentication/user_auth.dart';
import 'package:quizzer/backend_systems/02_login_authentication/offline_login.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_attempts_record.dart';
import 'package:quizzer/backend_systems/02_login_authentication/fill_data_caches.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/inbound_sync/inbound_sync_worker.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/outbound_sync/outbound_sync_worker.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/media_sync_worker.dart';
import 'package:quizzer/backend_systems/02_login_authentication/queue_server_init.dart';
import 'dart:async';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_other_signals.dart';
import 'package:supabase/supabase.dart';
import 'package:hive/hive.dart';
// TODO Move login initialization (currently defined in the session manager) to this file
// SessionManager should be left with only a login function that is called when the user hits the login button, so this would include functionality like email validation as well.



// TODO, question queue server needs to be updated such that we have a file with a function that defines the order in which each worker in the system is started

// TODO, the same concept goes for data-caches, with a singlue function that defines and fills the cache with the data that is needed for the session.



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

/// Validates login form fields
/// Returns a map with 'valid' boolean and 'message' string
Map<String, dynamic> _validateLoginForm(String email, String password) {
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
    
    // Basic email format validation
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) {
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

/// Single function that handles the login initialization process. Called directly by the attemptLogin function api call of the SessionManager Class.
/// Steps:
/// 1. Validate form fields (email, password)
/// 2. If validation passes, run userAuth (terminate early if auth fails)
/// 3. If auth succeeds, ensure the local user profile exists
/// 4. Once user profile is validated and exists, initialize Session
/// 5. Once we initialize the session, run the inbound sync worker
/// 6. Return authentication results, which allow the UI to navigate to the home page
Future<Map<String, dynamic>> loginInitialization({
  required String email,
  required String password,
  required SupabaseClient supabase,
  required Box storage,
}) async {
  try {
    QuizzerLogger.logMessage('Entering loginInitialization()...');
    
    signalLoginProgress("Starting login process...");
    
    // Step 1: Validate form fields
    signalLoginProgress("Validating your information...");
    final validationResult = _validateLoginForm(email, password);
    if (!validationResult['valid']) {
      QuizzerLogger.logWarning('Form validation failed: ${validationResult['message']}');
      return {
        'success': false,
        'message': validationResult['message']
      };
    }
    
    // Step 2: Attempt user authentication
    signalLoginProgress("Connecting to your account...");
    final authResult = await attemptSupabaseLogin(
      email,
      password,
      supabase,
    );

    // Unified variable for login results throughout the process
    Map<String, dynamic> loginResult = authResult;

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

    // Step 4: Handle successful login (store token for future offline login)
    if (loginResult['success'] && !loginResult['offline_mode']) {
      signalLoginProgress("Securing your login for offline use...");
      QuizzerLogger.logMessage('Supabase login successful, storing offline login data...');
      await storeOfflineLoginData(email, storage, loginResult);
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
      QuizzerLogger.logWarning('Login failed, terminating initialization');
      return loginResult;
    }

    // Step 6: Ensure local profile exists
    if (loginResult['offline_mode']) {
      // Offline login - check if we have a local profile
      signalLoginProgress("Checking your local profile...");
      QuizzerLogger.logMessage('Checking local profile for offline login...');
      final emailList = await getAllUserEmails();
      final hasLocalProfile = emailList.contains(email);
      
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
    }

    // Step 7: Run the inbound sync worker
    if (!loginResult['offline_mode']) {
      signalLoginProgress("Syncing your data from the cloud...");
      QuizzerLogger.logMessage('Starting inbound sync worker for online login...');
      final inboundSyncWorker = InboundSyncWorker();
      await inboundSyncWorker.start();
      QuizzerLogger.logSuccess('Inbound sync worker started successfully');
      
      // Wait for the initial inbound sync to complete
      signalLoginProgress("Downloading your latest data...");
      QuizzerLogger.logMessage('Waiting for initial inbound sync to complete...');
      final switchBoard = getSwitchBoard();
      await switchBoard.onInboundSyncCycleComplete.first;
      QuizzerLogger.logSuccess('Initial inbound sync completed');
    } else {
      QuizzerLogger.logMessage('Skipping inbound sync worker for offline login');
    }

    // Step 8: Run the outbound sync worker
    if (!loginResult['offline_mode']) {
      signalLoginProgress("Setting up data synchronization...");
      QuizzerLogger.logMessage('Starting outbound sync worker for online login...');
      final outboundSyncWorker = OutboundSyncWorker();
      outboundSyncWorker.start();
    } else {
      QuizzerLogger.logMessage('Skipping outbound sync worker for offline login');
    }

    // Step 9: Run the media sync worker
    if (!loginResult['offline_mode']) {
      signalLoginProgress("Setting up media synchronization...");
      QuizzerLogger.logMessage('Starting media sync worker for online login...');
      final mediaSyncWorker = MediaSyncWorker();
      mediaSyncWorker.start();
    } else {
      QuizzerLogger.logMessage('Skipping media sync worker for offline login');
    }

    // Step 10: Initialize data caches
    signalLoginProgress("Loading your data...");
    QuizzerLogger.logMessage('Initializing data caches...');
    await fillDataCaches();
    QuizzerLogger.logSuccess('Data caches initialized successfully');

    // Step 11: Initialize question queue server
    signalLoginProgress("Preparing your study queue...");
    QuizzerLogger.logMessage('Starting question queue server...');
    await startQuestionQueueServerWorkers();

    // Step 12: Wait for at least one question to be added to the queue
    signalLoginProgress("Finding questions for you to study...");
    QuizzerLogger.logMessage('Waiting for question queue to be populated...');
    await _waitForQuestionQueuePopulation();

    // Step 13: Return results
    signalLoginProgress("Welcome back! You're all set.");
    
    QuizzerLogger.logMessage('Login initialization completed for email: $email');
    return loginResult;
  } catch (e) {
    QuizzerLogger.logError('Error in loginInitialization - $e');
    return {
      'success': false,
      'message': 'Login initialization failed: $e'
    };
  }
}

/// Waits for at least one question to be added to the QuestionQueueCache
/// Uses a timeout fallback in case the user has no questions to answer
Future<void> _waitForQuestionQueuePopulation() async {
  try {
    QuizzerLogger.logMessage('Entering _waitForQuestionQueuePopulation()...');
    
    final switchBoard = getSwitchBoard();
    
    // Wait for the QuestionQueueAdded signal with a timeout
    try {
      QuizzerLogger.logMessage('Waiting for question to be added to queue...');
      await switchBoard.onQuestionQueueAdded.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          QuizzerLogger.logWarning('Timeout waiting for question queue population. User may have no questions to answer.');
          throw TimeoutException('Question queue population timeout', const Duration(seconds: 5));
        },
      );
      QuizzerLogger.logSuccess('Question added to queue successfully');
    } on TimeoutException {
      // TODO: Develop a better method for handling users with no questions to answer
      // For now, we'll just log and continue after the timeout
      QuizzerLogger.logMessage('User appears to have no questions to answer right now. Continuing with login...');
    } catch (e) {
      QuizzerLogger.logError('Error waiting for question queue population - $e');
      rethrow;
    }
  } catch (e) {
    QuizzerLogger.logError('Error in _waitForQuestionQueuePopulation - $e');
    rethrow;
  }
}