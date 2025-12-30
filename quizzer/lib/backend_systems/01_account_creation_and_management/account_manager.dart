// TODO create a new singleton object that encapsulates and is solely responsible for updating all things relating to creating user profile records and
// new user accounts in supabase. Anything related to a user's profile and the information contained therein will be handled by this object.
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
import 'dart:async';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/09_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/outbound_sync/outbound_sync_worker.dart';

/// Handles management of a user's account
/// A user's account or profile, is stored locally and on the supabase server
/// separate calls exist for the external server creation and local creation
class AccountManager {
  static final AccountManager _instance = AccountManager._internal();
  factory AccountManager() => _instance;
  AccountManager._internal();
  
  // ================================================================================
  // Main API Calls for AccountManager()
  // ================================================================================
  // Public calls are restricted to:
  // 1. handling of new profile creation
  // 2. resetting a user's password
  // 3. resetting a user's username (once implemented)
  // 4. transferring a user's account to a new email (once implemented)
  // 5. Utility check to ensure profile existence
  // 6. Update Call for last_login time

  Future<Map<String, dynamic>> handleNewUserProfileCreation(Map<String, dynamic> message, SupabaseClient supabase) async {
      try {
        final email = message['email'] as String;
        final password = message['password'] as String;

        // If the user already exists cancel the account creation process
        bool userExists = await _doesAccountExistInSupabase(email, password, supabase);
        if (userExists) {
          QuizzerLogger.logMessage("Existing User attempted to create duplicate account");
          return {
            'success': false,
            'message': "User already exists, can't create account when account already exists"
          };
        }

        // Log startup message
        QuizzerLogger.logMessage('Starting new user profile creation process');
        QuizzerLogger.logMessage('Email: $email');
        QuizzerLogger.logMessage('Received message map: $message');

        try {
          // If Supabase signup is successful, create local user profile and sync to Supabase
          bool success = await _createSupabaseAccount(email, password, supabase);
          if (success) {
            await _createLocalUserProfile({'email': email});
            return {
              'success': true,
              'message': 'Account Creation Successful'
            };
          } else {
            return {
                'success': false,
                'message': 'Supabase signup failed - no user returned',
            };
          }
        } on AuthException catch (e) {
          // If Supabase returns an authentication error, capture it.
          QuizzerLogger.logError('Supabase AuthException during signup: ${e.message}');
          return {
              'success': false,
              'message': e.message // Return the specific error from Supabase
          };
        } // End of allowed try-catch block
    } catch (e) {
      QuizzerLogger.logError('Error in handleNewUserProfileCreation - $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> handleResetPssword(Map<String, dynamic> message, SupabaseClient supabase) async {
      try {
          final email = message['email'] as String;
          final password = message['password'] as String;

          QuizzerLogger.logMessage('Starting reset password process');
          QuizzerLogger.logMessage('Email: $email');
          QuizzerLogger.logMessage('Received message map: $message');

          Map<String, dynamic> results = {};

          try {
              QuizzerLogger.logMessage('Attempting Supabase password reset with email: $email');
              final response = await supabase.auth.updateUser(
                  UserAttributes(
                      password: password,
                  ),
              );
              QuizzerLogger.logMessage('Supabase password reset response received: ${response.user != null ? 'User updated' : 'No user returned'}');
          } on AuthException catch (e) {
              // If Supabase returns an authentication error, capture it.
              QuizzerLogger.logError('Supabase AuthException during password reset: ${e.message}');
              results = {
                  'success': false,
                  'message': e.message // Return the specific error from Supabase
              };
              // Return immediately as signup failed.
              return results;
          } // End of allowed try-catch block

          return results;
      } catch (e) {
          QuizzerLogger.logError('Error in handleResetPssword - $e');
          rethrow;
      }
  }

  /// High-level utility to sync user profile after successful login.
  /// 
  /// This ensures the local profile is synchronized with Supabase after authentication.
  /// Handles cases where:
  /// - User is logging in on a new device
  /// - User has a Supabase account but no local profile
  /// - Local and Supabase profiles are out of sync
  /// 
  /// Should be called immediately after successful Supabase authentication.
  Future<void> syncUserProfileOnLogin(String email, SupabaseClient supabase) async {
    try {
      QuizzerLogger.logMessage('Starting user profile sync for login: $email');

      // Ensure the local profile exists (fetch from Supabase if needed)
      await _ensureLocalProfileExists(email);
      QuizzerLogger.logSuccess('Local profile verified for $email');

      // Ensure the Supabase profile record (not account) exists (push local if needed)
      await _ensureUserProfileExistsInSupabase(email, supabase);
      QuizzerLogger.logSuccess('Supabase profile verified for $email');

      QuizzerLogger.logSuccess('User profile sync completed successfully for $email');
    } catch (e) {
      QuizzerLogger.logError('Error syncing user profile on login for $email: $e');
      rethrow;
    }
  }

  Future<bool> updateLastLogin() async {
    try {
      
      QuizzerLogger.logMessage('Updating last login for userId: ${SessionManager().userId}');
      final lastLoginTimestamp = DateTime.now().subtract(const Duration(minutes: 1)).toUtc().toIso8601String();
      // First get the existing user profile
      final existingProfile = await UserProfileTable().getRecord(
        "SELECT * FROM user_profile WHERE uuid = '${SessionManager().userId}' LIMIT 1"
      );

      if (existingProfile.isNotEmpty) {
        // Use upsertRecord with the existing account_creation_date
        await UserProfileTable().upsertRecord({
          'uuid': SessionManager().userId,
          'last_login': lastLoginTimestamp,
          'email': SessionManager().userEmail,
          'account_creation_date': existingProfile.first['account_creation_date'],
        });
      }
      
      QuizzerLogger.logSuccess('Last login updated successfully for userId: ${SessionManager().userId}');
      return true;
    } catch (e) {
      QuizzerLogger.logError('Error updating last login for userId: ${SessionManager().userId} - $e');
      rethrow;
    }
  }
  // ================================================================================
  // Get Data API
  // ================================================================================
  /// Retrieves a list of all email addresses from the user_profile table.
  Future<List<String>> getAllUserEmails() async {
    try {
      QuizzerLogger.logMessage('Fetching all emails from user_profile table.');
      
      // Query the database for the email column
      // If query fails (e.g., table structure wrong), let it crash (Fail Fast)
      final List<Map<String, dynamic>> results = 
          await UserProfileTable().getRecord('SELECT email FROM user_profile');
      
      // Extract emails into a list of strings
      final List<String> emails = results.map((row) {
        final String? email = row['email'] as String?;
        // Assert non-null as email is NOT NULL in schema
        assert(email != null, 'Database returned null email from user_profile table.');
        return email!;
      }).toList();
      
      QuizzerLogger.logSuccess('Successfully fetched ${emails.length} emails.');
      return emails;
    } catch (e) {
      QuizzerLogger.logError('Error fetching all user emails - $e');
      rethrow;
    }
  }

  /// Gets the user ID for a given email address.
  /// Throws a StateError if no user is found.
  Future<String> getUserIdByEmail(String emailAddress) async {
    try {
      QuizzerLogger.logMessage('Getting user ID for email: $emailAddress');
      
      // Query the database for the UUID where email matches
      // If query fails (e.g., table doesn't exist), let it crash (Fail Fast)
      final List<Map<String, dynamic>> result = 
          await UserProfileTable().getRecord(
            "SELECT uuid FROM user_profile WHERE email = '$emailAddress'",
          );
      
      if (result.isNotEmpty) {
        QuizzerLogger.logSuccess('Found user ID: ${result.first['uuid']}');
        
        // Cast should be safe due to query structure, but assert for paranoia
        final String? userId = result.first['uuid'] as String?;
        assert(userId != null, 'Database returned null UUID for user $emailAddress');
        return userId!;
      } else {
        QuizzerLogger.logError('No user found with email: $emailAddress');
        throw StateError('No user found with email: $emailAddress');
      }
    } catch (e) {
      QuizzerLogger.logError('Error getting user ID for email: $emailAddress - $e');
      rethrow;
    }
  }

  /// Get User Profile Record using email field
  Future<Map<String, dynamic>?> getUserProfileByEmail(String email) async {
    try {
      QuizzerLogger.logMessage('Fetching user profile for email: $email');
      
      // Query the database for all columns where email matches
      final List<Map<String, dynamic>> result = 
          await UserProfileTable().getRecord(
            "SELECT * FROM user_profile WHERE email = '$email'",
          );
      
      if (result.isNotEmpty) {
        QuizzerLogger.logSuccess('Found user profile for email: $email');
        return result.first;
      }
      
      QuizzerLogger.logMessage('No user profile found for email: $email');
      return null;
    } catch (e) {
      QuizzerLogger.logError('Error fetching user profile for email: $email - $e');
      rethrow;
    }
  }

  /// Gets the last_login timestamp for a user by userId. Returns null if not found.
  Future<String?> getLastLoginForUser(String userId) async {
    try {
      final List<Map<String, dynamic>> result = 
          await UserProfileTable().getRecord(
            "SELECT last_login FROM user_profile WHERE uuid = '$userId'",
          );
      
      if (result.isEmpty) return null;
      return result.first['last_login'] as String?;
    } catch (e) {
      QuizzerLogger.logError('Error getting last login for user ID: $userId - $e');
      rethrow;
    }
  }

  // ================================================================================
  // Account Creation Calls
  // ================================================================================
  Future<bool> _createLocalUserProfile(Map<String, dynamic> message) async {
      try {
          final email = message['email'] as String;
          final username = message['username'] as String;

          QuizzerLogger.logMessage('Starting local user profile creation');
          QuizzerLogger.logMessage('Email: $email, Username: $username');
          
          // Delegate creation logic (including duplicate check) to createNewUserProfile
          // The table function handles its own database access internally
          // If it fails unexpectedly, it will throw (Fail Fast)
          // If user exists, it returns false.
          // If creation succeeds, it returns true.
          final bool creationResult = await _createNewUserProfile(email);
          
          QuizzerLogger.logMessage('Local user profile creation completed with result: $creationResult');
          return creationResult;
      } catch (e) {
          QuizzerLogger.logError('Error creating local user profile - $e');
          rethrow;
      }
  }

  Future<bool> _createNewUserProfile(String email) async {
    try {
      QuizzerLogger.logMessage('Creating new user profile for email: $email');
      final db = await getDatabaseMonitor().requestDatabaseAccess();

      // Send data to authentication service to store password field with auth service
      QuizzerLogger.logSuccess('User registered with Supabase');

      // Next Verify that the profile doesn't already exist in that Table
      final duplicateCheck = await _verifyNonDuplicateProfile(email, db);
      if (!duplicateCheck['isValid']) {
          QuizzerLogger.logError(duplicateCheck['message']);
          // If validation fails, returning false is acceptable as it's a known flow,
          // not an unexpected error like a DB failure.
          return false;
      }
      
      // Get current timestamp for account creation date
      final String creationTimestamp = DateTime.now().toUtc().toIso8601String();
      
      // Insert the new user profile with minimal required fields
      UserProfileTable().upsertRecord(
        {
          'email': email,
          'role': 'base_user',
          'account_status': 'active',
          'account_creation_date': creationTimestamp,
          'last_login': null,
          // Initialize sync fields
          'has_been_synced': 0,
          'edits_are_synced': 0,
          'last_modified_timestamp': null, 
        }
      );

      String userUUID = await getUserIdByEmail(email);
      QuizzerLogger.logSuccess('New user profile created successfully: $userUUID');
      // Signal SwitchBoard after successful insert
      signalOutboundSyncNeeded();
      return true;
    } catch (e) {
      QuizzerLogger.logError('Error creating new user profile for email: $email, - $e');
      rethrow;
    } finally {
      getDatabaseMonitor().releaseDatabaseAccess();
    }
  }

  Future<bool> _createSupabaseAccount(String email, String password, SupabaseClient supabase) async {
    try {
      QuizzerLogger.logMessage('Attempting Supabase signup with email: $email');
      
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );
      
      final success = response.user != null;
      QuizzerLogger.logMessage('Supabase signup response received: ${success ? 'User created' : 'No user returned'}');
      return success;

    } on AuthException catch (error) {
      QuizzerLogger.logMessage('Auth error during signup: ${error.message}');
      return false;
    } catch (error) {
      QuizzerLogger.logMessage('Unexpected error during signup: $error');
      return false;
    }
  }
  // ================================================================================
  // Account Status Checks
  // ================================================================================
  Future<bool> _doesAccountExistInSupabase(String email, String password, SupabaseClient supabase) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // If we reach here, the user exists and credentials are valid
      return response.user != null;
    } on AuthException catch (error) {
      // Handle auth-specific errors
      // Common errors: invalid_credentials, user_not_found, etc.
      QuizzerLogger.logError('Auth error: ${error.message}');
      return false;
    } catch (error) {
      QuizzerLogger.logError('Unexpected error: $error');
      rethrow;
    }
  }

  // ================================================================================
  // Data Validation
  // ================================================================================
  Future<void> _ensureUserProfileExistsInSupabase(String email, SupabaseClient supabase) async {
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
        final bool pushSuccess = await OutboundSyncWorker().pushRecordToSupabase('user_profile', localProfile);
        if (!pushSuccess) {
          throw Exception('Failed to insert user profile into Supabase using pushRecordToSupabase');
        }
      }
    } catch (e) {
      QuizzerLogger.logError('Error in ensureUserProfileExistsInSupabase - $e');
      rethrow;
    }
  }

  /// Ensures a local user profile exists for the given email after successful Supabase auth.
  /// If not found locally, fetches the profile from Supabase. If not found on server either,
  /// creates a new profile as fallback for users with Supabase auth but no profile.
  Future<void> _ensureLocalProfileExists(String email) async {
    try {
      QuizzerLogger.logMessage("Ensuring local profile exists for $email");

      // Get list of emails currently in profile table
      List<String> emailList = await getAllUserEmails();
      // Check if email is in the list
      bool isEmailInList = emailList.contains(email);
      QuizzerLogger.logMessage("Is user in local profile list -> $isEmailInList");

      if (!isEmailInList) {
        QuizzerLogger.logMessage(
            "User profile not found locally, attempting to fetch from Supabase for $email");
        try {
          await _fetchAndInsertUserProfileFromSupabase(email);
          QuizzerLogger.logSuccess(
              "Successfully fetched and inserted user profile from Supabase for $email");
        } catch (e) {
          QuizzerLogger.logWarning(
              "Failed to fetch user profile from Supabase for $email: $e");
          QuizzerLogger.logMessage(
              "Creating new local profile for user with Supabase auth but no profile for $email");

          // TODO implement usernames

          // Create a new profile for users who have Supabase authentication but no profile
          final bool profileCreated = await _createNewUserProfile(email);
          if (profileCreated) {
            QuizzerLogger.logSuccess(
                "Successfully created new local profile for $email");
          } else {
            QuizzerLogger.logError(
                "Failed to create new local profile for $email");
            throw StateError("Failed to create local profile for $email");
          }
        }
      }

      // Verify the profile now exists
      emailList = await getAllUserEmails();
      isEmailInList = emailList.contains(email);
      QuizzerLogger.logMessage(
          "Final check - is user in local profile list -> $isEmailInList");

      if (!isEmailInList) {
        throw StateError("Failed to ensure local profile exists for $email");
      }

      // FINAL VERIFICATION: Ensure local user ID matches Supabase user ID
      QuizzerLogger.logMessage(
          "Verifying local user ID matches Supabase user ID for $email");
      try {
        // Get the local user ID
        final String localUserId = await getUserIdByEmail(email);

        // Get the Supabase user profile UUID (not the auth user ID)
        final sessionManager = SessionManager();
        final List<dynamic> supabaseProfile = await sessionManager.supabase
            .from('user_profile')
            .select('uuid')
            .eq('email', email)
            .limit(1);

        if (supabaseProfile.isEmpty) {
          QuizzerLogger.logWarning(
              "No Supabase user profile found for $email, skipping user ID verification");
          return;
        }

        final String supabaseUserId = supabaseProfile.first['uuid'] as String;

        QuizzerLogger.logMessage(
            "Local user ID: $localUserId, Supabase user profile UUID: $supabaseUserId");

        // If they don't match, update the local profile to use the Supabase user profile UUID
        if (localUserId != supabaseUserId) {
          QuizzerLogger.logWarning(
              "User ID mismatch detected! Local: $localUserId, Supabase: $supabaseUserId");
          QuizzerLogger.logMessage(
              "Updating local profile to use Supabase user profile UUID for $email");

          // Fetch the profile from Supabase again to ensure we have the correct data
          await _fetchAndInsertUserProfileFromSupabase(email);

          // Verify the update was successful
          final String updatedLocalUserId =
              await getUserIdByEmail(email);
          if (updatedLocalUserId != supabaseUserId) {
            throw StateError(
                "Failed to update local profile to match Supabase user profile UUID for $email");
          }

          QuizzerLogger.logSuccess(
              "Successfully updated local profile to match Supabase user profile UUID: $supabaseUserId");
        } else {
          QuizzerLogger.logSuccess(
              "User ID verification passed - local and Supabase user profile UUIDs match: $localUserId");
        }
      } catch (e) {
        QuizzerLogger.logError(
            "Error during user ID verification for $email: $e");
        // Don't rethrow here - the profile exists, we just couldn't verify the ID match
        // This is a warning, not a critical failure
      }
    } catch (e) {
      QuizzerLogger.logError(
          'Error ensuring local profile exists for $email - $e');
      rethrow;
    }
  }

  /// Updates the total_study_time for a user by adding the specified amount of hours.
  /// The time is converted to days before adding to the total_study_time column.
  ///
  /// [userUuid]: The UUID of the user whose study time needs updating.
  /// [hoursToAdd]: The duration in hours (double) to add to the total study time.
  Future<void> updateTotalStudyTime(double hoursToAdd) async {
    try {
      QuizzerLogger.logMessage('Updating total_study_time for User: ${SessionManager().userId}, adding: $hoursToAdd hours');
      final db = await getDatabaseMonitor().requestDatabaseAccess();

      // Convert hours to days for storage
      final double daysToAdd = hoursToAdd / 24.0;
      QuizzerLogger.logValue('Converted hours to days: $daysToAdd');

      // We assume verifyUserProfileTable has been called before or during DB initialization.

      final int rowsAffected = await db!.rawUpdate(
        // Use COALESCE to handle potential NULL values, treating them as 0.0
        'UPDATE user_profile SET total_study_time = COALESCE(total_study_time, 0.0) + ?, edits_are_synced = 0, last_modified_timestamp = ? WHERE uuid = ?',
        [daysToAdd, DateTime.now().toUtc().toIso8601String(), SessionManager().userId]
      );

      if (rowsAffected == 0) {
        QuizzerLogger.logWarning('Failed to update total_study_time: No matching record found for User: ${SessionManager().userId}');
        // Consider if this should throw an error if the user *must* exist. For now, just a warning.
      } else {
        QuizzerLogger.logSuccess('Successfully updated total_study_time for User: ${SessionManager().userId} (added $daysToAdd days)');
        // Signal SwitchBoard
        signalOutboundSyncNeeded();
      }
    } catch (e) {
      QuizzerLogger.logError('Error updating total study time for user: ${SessionManager().userId} - $e');
      rethrow;
    } finally {
      getDatabaseMonitor().releaseDatabaseAccess();
    }
  }


  // ================================================================================
  // Utility Logic
  // ================================================================================
  /// Fetches a user profile from Supabase and inserts it into the local database.
  /// This is used when a user logs in but doesn't have a local profile yet.
  Future<void> _fetchAndInsertUserProfileFromSupabase(String email) async {
    try {
      QuizzerLogger.logMessage('Fetching user profile from Supabase for email: $email');
      
      final supabase = SessionManager().supabase;
      
      // Fetch the user profile from Supabase
      final List<dynamic> results = await supabase
          .from('user_profile')
          .select('*')
          .eq('email', email)
          .limit(1);
      
      if (results.isEmpty) {
        QuizzerLogger.logError('No user profile found in Supabase for email: $email');
        throw StateError('No user profile found in Supabase for email: $email');
      }
      
      final Map<String, dynamic> profileData = Map<String, dynamic>.from(results.first);
      QuizzerLogger.logSuccess('Successfully fetched user profile from Supabase for email: $email');
      
      // Ensure last_modified_timestamp is not null by setting it to current time if it's null
      // TODO update finishRecord call with the below to abstract this away
      if (profileData['last_modified_timestamp'] == null) {
        QuizzerLogger.logMessage('Supabase profile has null last_modified_timestamp, setting to current time');
        profileData['last_modified_timestamp'] = DateTime.now().toIso8601String();
      }

      // directly batch upsert the records instead of upsert, since we don't want to trigger the sync mechanism for this.
      await UserProfileTable().batchUpsertRecords(records: [profileData]);

      // Final check: verify the record was inserted
      final String uuid = profileData['uuid'];
      final List<Map<String, dynamic>> localRecords = await UserProfileTable().getRecord('SELECT * FROM user_profile WHERE uuid = "$uuid"');
      
      if (localRecords.isEmpty) {
        throw StateError('User profile record was not committed to local database');
      }

      QuizzerLogger.logSuccess('Successfully inserted user profile from Supabase for email: $email');
    } catch (e) {
      QuizzerLogger.logError('Error fetching and inserting user profile from Supabase for email: $email - $e');
      rethrow;
    }
  }

  /// Verifies that the email and username don't already exist in the user profile table
  /// Returns a map with 'isValid' (bool) indicating if the profile is non-duplicate
  /// and 'message' (String) containing any error message if there's a duplicate
  Future<Map<String, dynamic>> _verifyNonDuplicateProfile(String email, dynamic db) async {
    QuizzerLogger.logMessage('Verifying non-duplicate profile for email: $email');
    // Check if email already exists
    final List<Map<String, dynamic>> emailCheck = await db.query(
      'user_profile',
      where: 'email = ?',
      whereArgs: [email],
    );
    
    if (emailCheck.isNotEmpty) {
      QuizzerLogger.logError('Email already registered: $email');
      return {'isValid': false, 'message': 'This email address is already registered'};
    }
    
    // If we get here, both email and username are unique
    QuizzerLogger.logSuccess('Email and username are available');
    return {
      'isValid': true,
      'message': 'Email and username are available'
    };
  }
}