import 'package:uuid/uuid.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'dart:convert';
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

/// Gets the user ID for a given email address.
/// Throws a StateError if no user is found.
Future<String> getUserIdByEmail(String emailAddress) async {
  try {
    QuizzerLogger.logMessage('Getting user ID for email: $emailAddress');
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await _verifyUserProfileTable(db!);
    // First verify the table exists
    
    // Query might fail if table doesn't exist yet, let it crash (Fail Fast)
    final List<Map<String, dynamic>> result = await db.query(
        'user_profile',
        columns: ['uuid'],
        where: 'email = ?',
        whereArgs: [emailAddress],
    );
    if (result.isNotEmpty) {
        QuizzerLogger.logSuccess('Found user ID: ${result.first['uuid']}');
        // Cast should be safe due to query structure, but assert for paranoia
        final String? userId = result.first['uuid'] as String?;
        assert(userId != null, 'Database returned null UUID for user $emailAddress');
        return userId!;
    } else {
        QuizzerLogger.logError('No user found with email:');
        throw StateError("INVALID, NO USERID WITH THAT EMAIL. . .");
    }
  } catch (e) {
    QuizzerLogger.logError('Error getting user ID for email: $emailAddress - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

Future<bool> createNewUserProfile(String email, String username) async {
  try {
    QuizzerLogger.logMessage('Creating new user profile for email: $email, username: $username');
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await _verifyUserProfileTable(db!);
    
    // First verify that the User Profile Table exists
    

    // Send data to authentication service to store password field with auth service
    QuizzerLogger.logSuccess('User registered with Supabase');

    // Next Verify that the profile doesn't already exist in that Table
    final duplicateCheck = await _verifyNonDuplicateProfile(email, username, db);
    if (!duplicateCheck['isValid']) {
        QuizzerLogger.logError(duplicateCheck['message']);
        // If validation fails, returning false is acceptable as it's a known flow,
        // not an unexpected error like a DB failure.
        return false;
    }

    // Generate a UUID for the new user
    final String userUUID = generateUserUUID();
    QuizzerLogger.logMessage('Generated UUID for new user: $userUUID');
    
    // Get current timestamp for account creation date
    final String creationTimestamp = DateTime.now().toUtc().toIso8601String();
    
    // Insert the new user profile with minimal required fields
    // If db.insert fails, it should throw an exception (Fail Fast)
    await db.insert('user_profile', {
      'uuid': userUUID,
      'email': email,
      'username': username,
      'role': 'base_user',
      'account_status': 'active',
      'account_creation_date': creationTimestamp,
      'last_login': null,
      // Initialize sync fields
      'has_been_synced': 0,
      'edits_are_synced': 0,
      'last_modified_timestamp': null, 
    });
    
    QuizzerLogger.logSuccess('New user profile created successfully: $userUUID');
    // Signal SwitchBoard after successful insert
    signalOutboundSyncNeeded();
    return true;
  } catch (e) {
    QuizzerLogger.logError('Error creating new user profile for email: $email, username: $username - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Generates a unique UUID for a new user
String generateUserUUID() {
  // Using the uuid package to generate a v4 (random) UUID
  const uuid = Uuid();
  final generatedUUID = uuid.v4();
  QuizzerLogger.logMessage('Generated new UUID: $generatedUUID');
  return generatedUUID;
}

/// Verifies that the User Profile Table exists in the database
/// Creates the table if it doesn't exist based on the schema in documentation
/// Private function that requires a database parameter to avoid race conditions
Future<void> _verifyUserProfileTable(Database db) async {
  try {
    QuizzerLogger.logMessage('Verifying user profile table existence');
    
    // Check if the table exists
    final List<Map<String, dynamic>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      ['user_profile']
    );
    
    if (tables.isEmpty) {
      QuizzerLogger.logMessage('User profile table does not exist, creating it');
      await db.execute('''
        CREATE TABLE user_profile(
          uuid TEXT PRIMARY KEY,
          email TEXT NOT NULL,
          username TEXT NOT NULL,
          role TEXT DEFAULT 'base_user',
          account_status TEXT DEFAULT 'active',
          account_creation_date TEXT NOT NULL,
          last_login TEXT,
          profile_picture TEXT,
          birth_date TEXT,
          address TEXT,
          job_title TEXT,
          education_level TEXT,
          specialization TEXT,
          teaching_experience INTEGER,
          primary_language TEXT,
          secondary_languages TEXT,
          study_schedule TEXT,
          social_links TEXT,
          achievement_sharing INTEGER,
          interest_data TEXT,
          settings TEXT,
          notification_preferences TEXT,
          learning_streak INTEGER DEFAULT 0,
          total_study_time REAL DEFAULT 0.0,
          total_questions_answered INTEGER DEFAULT 0,
          average_session_length REAL,
          peak_cognitive_hours TEXT,
          health_data TEXT,
          recall_accuracy_trends TEXT,
          content_portfolio TEXT,
          activation_status_of_modules TEXT,
          completion_status_of_modules TEXT,
          tutorial_progress INTEGER DEFAULT 0,
          has_been_synced INTEGER DEFAULT 0,
          edits_are_synced INTEGER DEFAULT 0,
          last_modified_timestamp TEXT
        )
      ''');
      
      QuizzerLogger.logSuccess('User Profile table created successfully');
    } else {

      // Add checks for new sync columns
      final List<Map<String, dynamic>> columns = await db.rawQuery(
        "PRAGMA table_info(user_profile)"
      );
      final Set<String> columnNames = columns.map((column) => column['name'] as String).toSet();

      if (!columnNames.contains('has_been_synced')) {
        QuizzerLogger.logMessage('Adding has_been_synced column to user_profile table.');
        await db.execute('ALTER TABLE user_profile ADD COLUMN has_been_synced INTEGER DEFAULT 0');
      }
      if (!columnNames.contains('edits_are_synced')) {
        QuizzerLogger.logMessage('Adding edits_are_synced column to user_profile table.');
        await db.execute('ALTER TABLE user_profile ADD COLUMN edits_are_synced INTEGER DEFAULT 0');
      }
      if (!columnNames.contains('last_modified_timestamp')) {
        QuizzerLogger.logMessage('Adding last_modified_timestamp column to user_profile table.');
        await db.execute('ALTER TABLE user_profile ADD COLUMN last_modified_timestamp TEXT');
        // Optionally backfill last_modified_timestamp with account_creation_date for existing rows
        // await db.rawUpdate('UPDATE user_profile SET last_modified_timestamp = account_creation_date WHERE last_modified_timestamp IS NULL');
      }
    }
  } catch (e) {
    QuizzerLogger.logError('Error verifying user profile table - $e');
    rethrow;
  }
}

/// Verifies that the email and username don't already exist in the user profile table
/// Returns a map with 'isValid' (bool) indicating if the profile is non-duplicate
/// and 'message' (String) containing any error message if there's a duplicate
Future<Map<String, dynamic>> _verifyNonDuplicateProfile(String email, String username, dynamic db) async {
  QuizzerLogger.logMessage('Verifying non-duplicate profile for email: $email, username: $username');
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

Future<bool> updateLastLogin(String userId) async {
  try {
    QuizzerLogger.logMessage('Updating last login for userId: $userId');
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await _verifyUserProfileTable(db!);
    
    final String nowTimestamp = DateTime.now().toUtc().toIso8601String();
    final Map<String, dynamic> updates = {
      'last_login': nowTimestamp,
      'edits_are_synced': 0,
      'last_modified_timestamp': nowTimestamp,
    };
    await updateRawData(
      'user_profile',
      updates,
      'uuid = ?',
      [userId],
      db,
    );
    QuizzerLogger.logSuccess('Last login updated successfully for userId: $userId');
    // Signal SwitchBoard
    signalOutboundSyncNeeded();
    return true;
  } catch (e) {
    QuizzerLogger.logError('Error updating last login for userId: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Gets the activation status of modules for a user
/// Returns a Map<String, bool> where keys are module names and values are activation status
Future<Map<String, bool>> getModuleActivationStatus(String userId) async {
  try {
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await _verifyUserProfileTable(db!);
    
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      'user_profile',
      db,
      columns: ['activation_status_of_modules'],
      where: 'uuid = ?',
      whereArgs: [userId],
    );
    
    if (results.isEmpty) {
      QuizzerLogger.logError('No activation status found for user ID: $userId');
      return {};
    }
    
    final dynamic activationStatus = results.first['activation_status_of_modules'];
    if (activationStatus == null) {
      return {};
    }
    
    // If it's already a Map, convert it to the correct type
    if (activationStatus is Map) {
      return activationStatus.map((key, value) => MapEntry(key.toString(), value as bool));
    }
    
    // If it's a String, try to decode it
    if (activationStatus is String) {
      try {
        final Map<String, dynamic> decoded = json.decode(activationStatus);
        return decoded.map((key, value) => MapEntry(key, value as bool));
      } catch (e) {
        QuizzerLogger.logError('Failed to decode activation status for user ID: $userId');
        return {};
      }
    }
    
    QuizzerLogger.logError('Unexpected type for activation_status_of_modules: ${activationStatus.runtimeType}');
    return {};
  } catch (e) {
    QuizzerLogger.logError('Error getting module activation status for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Gets the subject interest data for a user
/// If new subjects are found in the question database that aren't in the user profile,
/// they will be added with a default interest value of 10
Future<Map<String, int>> getUserSubjectInterests(String userId) async {
  try {
    // QuizzerLogger.logMessage('Getting subject interests for user: $userId');
    // Get all unique subjects from question database
    final List<String> allSubjectsList = await getUniqueSubjects();
    final Set<String> allSubjects = allSubjectsList.toSet();
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await _verifyUserProfileTable(db!);
    // Query for the user's interest data column
    final List<Map<String, dynamic>> result = await db.query(
      'user_profile',
      columns: ['interest_data'],
      where: 'uuid = ?',
      whereArgs: [userId],
    );
    // Initialize empty map
    Map<String, int> interestData = {};


    // Get the JSON string from the correct column
    final String? interestsJson = result.first['interest_data'] as String?;

    // Parse existing interest data if present
    if (interestsJson != null && interestsJson.isNotEmpty) {
      try {
        final Map<String, dynamic> interestsMap = Map<String, dynamic>.from(json.decode(interestsJson));
        // Ensure values are integers during conversion
        interestData = interestsMap.map(
          (key, value) {
            if (value is int) {
              return MapEntry(key, value);
            } else {
              QuizzerLogger.logWarning('Non-integer value found for key "$key" in interest_data for user $userId. Attempting conversion or defaulting.');
              return MapEntry(key, int.tryParse(value.toString()) ?? 0);
            }
          }
        );
      } catch (e) {
         QuizzerLogger.logError('Failed to parse interest_data JSON for user $userId: $e');
         throw FormatException('Failed to parse interest_data JSON for user $userId: $e');
      }
    } else {
       QuizzerLogger.logMessage('No existing interest_data found for user $userId.');
       interestData = {};
    }


    allSubjects.add('misc'); // hidden misc subject for handling questions without subjects

    // Check for new subjects and add them with default value
    bool hasNewSubjects = false;
    for (final subject in allSubjects) {
      if (!interestData.containsKey(subject)) {
        if (subject == 'misc') {interestData[subject] = 1;} 
        else {interestData[subject] = 10;}
        hasNewSubjects = true;
        QuizzerLogger.logMessage('Adding new subject "$subject" with default interest for user $userId.');
      }
    }

    // If we found new subjects, update the user profile in the correct column
    if (hasNewSubjects) {
      final String updatedInterestsJson = json.encode(interestData);
      final int rowsAffected = await db.update(
        'user_profile',
        {
          'interest_data': updatedInterestsJson,
          'edits_are_synced': 0,
          'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'uuid = ?',
        whereArgs: [userId],
      );
      if (rowsAffected == 0) {
         QuizzerLogger.logError('Failed to update interest_data for user $userId - user might no longer exist.');
      } else {
        QuizzerLogger.logSuccess('Updated user profile interest_data with new subject interests for user $userId.');
        // Signal SwitchBoard only if update was successful
        signalOutboundSyncNeeded();
      }
    }

    QuizzerLogger.logSuccess('Returning final subject interests for user');
    return interestData;
  } catch (e) {
    QuizzerLogger.logError('Error getting user subject interests for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// --- Helper Functions ---

/// Updates the total_study_time for a user by adding the specified amount of hours.
/// The time is converted to days before adding to the total_study_time column.
///
/// [userUuid]: The UUID of the user whose study time needs updating.
/// [hoursToAdd]: The duration in hours (double) to add to the total study time.
Future<void> updateTotalStudyTime(String userUuid, double hoursToAdd) async {
  try {
    QuizzerLogger.logMessage('Updating total_study_time for User: $userUuid, adding: $hoursToAdd hours');
    final db = await getDatabaseMonitor().requestDatabaseAccess();

    // Convert hours to days for storage
    final double daysToAdd = hoursToAdd / 24.0;
    QuizzerLogger.logValue('Converted hours to days: $daysToAdd');

    // We assume verifyUserProfileTable has been called before or during DB initialization.

    final int rowsAffected = await db!.rawUpdate(
      // Use COALESCE to handle potential NULL values, treating them as 0.0
      'UPDATE user_profile SET total_study_time = COALESCE(total_study_time, 0.0) + ?, edits_are_synced = 0, last_modified_timestamp = ? WHERE uuid = ?',
      [daysToAdd, DateTime.now().toUtc().toIso8601String(), userUuid]
    );

    if (rowsAffected == 0) {
      QuizzerLogger.logWarning('Failed to update total_study_time: No matching record found for User: $userUuid');
      // Consider if this should throw an error if the user *must* exist. For now, just a warning.
    } else {
      QuizzerLogger.logSuccess('Successfully updated total_study_time for User: $userUuid (added $daysToAdd days)');
      // Signal SwitchBoard
      signalOutboundSyncNeeded();
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating total study time for user: $userUuid - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Retrieves a list of all email addresses from the user_profile table.
Future<List<String>> getAllUserEmails() async {
  try {
    QuizzerLogger.logMessage('Fetching all emails from user_profile table.');
    // Ensure table exists (Fail Fast if verifyUserProfileTable fails)
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await _verifyUserProfileTable(db!);
    // Query the database for the email column
    // If query fails (e.g., table structure wrong), let it crash (Fail Fast)
    final List<Map<String, dynamic>> results = await db.query(
      'user_profile',
      columns: ['email'],
    );

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
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// --- Get Unsynced Records ---

/// Fetches all user profiles that need outbound synchronization for a specific user.
/// This includes records that have never been synced (`has_been_synced = 0`)
/// or records that have local edits pending sync (`edits_are_synced = 0`).
/// Does NOT decode the records.
Future<List<Map<String, dynamic>>> getUnsyncedUserProfiles(String userId) async {
  try {
    QuizzerLogger.logMessage('Fetching unsynced user profile for user ID: $userId...');
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await _verifyUserProfileTable(db!);
    final List<Map<String, dynamic>> results = await db.query(
      'user_profile',
      where: '(has_been_synced = 0 OR edits_are_synced = 0) AND uuid = ?',
      whereArgs: [userId], // Use the passed userId parameter
    );

    QuizzerLogger.logSuccess('Fetched ${results.length} unsynced user profiles for user $userId.');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error fetching unsynced user profiles for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// --- Update Sync Flags ---

/// Updates the synchronization flags for a specific user profile.
/// Does NOT trigger a new sync signal.
Future<void> updateUserProfileSyncFlags({
  required String userId,
  required bool hasBeenSynced,
  required bool editsAreSynced,
}) async {
  try {
    QuizzerLogger.logMessage('Updating sync flags for User Profile: $userId -> Synced: $hasBeenSynced, Edits Synced: $editsAreSynced');
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await _verifyUserProfileTable(db!);
    final Map<String, dynamic> updates = {
      'has_been_synced': hasBeenSynced ? 1 : 0,
      'edits_are_synced': editsAreSynced ? 1 : 0,
    };

    final int rowsAffected = await updateRawData(
      'user_profile',
      updates,
      'uuid = ?', // Where clause using primary key
      [userId],   // Where args
      db,
    );

    if (rowsAffected == 0) {
      QuizzerLogger.logWarning('updateUserProfileSyncFlags affected 0 rows for User: $userId. Record might not exist?');
    } else {
      QuizzerLogger.logSuccess('Successfully updated sync flags for User Profile: $userId.');
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating sync flags for User Profile: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Gets the last_login timestamp for a user by userId. Returns null if not found.
Future<String?> getLastLoginForUser(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    final List<Map<String, dynamic>> result = await db!.query(
      'user_profile',
      columns: ['last_login'],
      where: 'uuid = ?',
      whereArgs: [userId],
    );
    if (result.isEmpty) return null;
    return result.first['last_login'] as String?;
  } catch (e) {
    QuizzerLogger.logError('Error getting last login for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Gets just the last_modified_timestamp for a user by userId. Returns null if not found.
Future<String?> getLastModifiedTimestampForUser(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    final List<Map<String, dynamic>> result = await db!.query(
      'user_profile',
      columns: ['last_modified_timestamp'],
      where: 'uuid = ?',
      whereArgs: [userId],
    );
    if (result.isEmpty) return null;
    return result.first['last_modified_timestamp'] as String?;
  } catch (e) {
    QuizzerLogger.logError('Error getting last modified timestamp for user ID: $userId - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Inserts a new user profile or updates an existing one from data fetched from the cloud.
/// Sets sync flags to indicate the record is synced and edits are synced.
Future<void> upsertUserProfileFromInboundSync(Map<String, dynamic> profileData) async {
  try {
    // Ensure all required fields are present in the incoming data
    final String? userId = profileData['uuid'] as String?;
    final String? email = profileData['email'] as String?;
    final String? username = profileData['username'] as String?;
    final String? lastModifiedTimestamp = profileData['last_modified_timestamp'] as String?;

    assert(userId != null, 'upsertUserProfileFromInboundSync: uuid cannot be null. Data: $profileData');
    assert(email != null, 'upsertUserProfileFromInboundSync: email cannot be null. Data: $profileData');
    assert(username != null, 'upsertUserProfileFromInboundSync: username cannot be null. Data: $profileData');
    assert(lastModifiedTimestamp != null, 'upsertUserProfileFromInboundSync: last_modified_timestamp cannot be null. Data: $profileData');

    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    
    // Ensure the table exists
    await _verifyUserProfileTable(db);

    final Map<String, dynamic> dataToInsertOrUpdate = {
      'uuid': userId,
      'email': email,
      'username': username,
      'role': profileData['role'],
      'account_status': profileData['account_status'],
      'account_creation_date': profileData['account_creation_date'],
      'last_login': profileData['last_login'],
      'profile_picture': profileData['profile_picture'],
      'birth_date': profileData['birth_date'],
      'address': profileData['address'],
      'job_title': profileData['job_title'],
      'education_level': profileData['education_level'],
      'specialization': profileData['specialization'],
      'teaching_experience': profileData['teaching_experience'],
      'primary_language': profileData['primary_language'],
      'secondary_languages': profileData['secondary_languages'],
      'study_schedule': profileData['study_schedule'],
      'social_links': profileData['social_links'],
      'achievement_sharing': profileData['achievement_sharing'],
      'interest_data': profileData['interest_data'],
      'settings': profileData['settings'],
      'notification_preferences': profileData['notification_preferences'],
      'learning_streak': profileData['learning_streak'],
      'total_study_time': profileData['total_study_time'],
      'total_questions_answered': profileData['total_questions_answered'],
      'average_session_length': profileData['average_session_length'],
      'peak_cognitive_hours': profileData['peak_cognitive_hours'],
      'health_data': profileData['health_data'],
      'recall_accuracy_trends': profileData['recall_accuracy_trends'],
      'content_portfolio': profileData['content_portfolio'],
      'activation_status_of_modules': profileData['activation_status_of_modules'],
      'completion_status_of_modules': profileData['completion_status_of_modules'],
      'tutorial_progress': profileData['tutorial_progress'],
      'has_been_synced': 1, // Mark as synced from cloud
      'edits_are_synced': 1, // Mark edits as synced (as it's from cloud)
      'last_modified_timestamp': lastModifiedTimestamp,
    };

    // Use ConflictAlgorithm.replace to handle both insert and update scenarios.
    // The primary key is uuid.
    final int rowId = await insertRawData(
      'user_profile',
      dataToInsertOrUpdate,
      db,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (rowId > 0) {
      QuizzerLogger.logSuccess('Successfully inserted/updated user profile for user $userId from cloud.');
    } else {
      // This case should ideally not happen with ConflictAlgorithm.replace unless there's a deeper issue.
      QuizzerLogger.logWarning('upsertUserProfileFromInboundSync: insertRawData with replace returned 0 for user $userId. Data: $dataToInsertOrUpdate');
    }
  } catch (e) {
    QuizzerLogger.logError('Error upserting user profile from inbound sync - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Fetches a user profile from Supabase and inserts it into the local database.
/// This is used when a user logs in but doesn't have a local profile yet.
Future<void> fetchAndInsertUserProfileFromSupabase(String email) async {
  try {
    QuizzerLogger.logMessage('Fetching user profile from Supabase for email: $email');
    
    final supabase = getSessionManager().supabase;
    
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
    
    // Insert the profile into local database using the existing upsert function
    await upsertUserProfileFromInboundSync(profileData);
    
    QuizzerLogger.logSuccess('Successfully inserted user profile from Supabase for email: $email');
  } catch (e) {
    QuizzerLogger.logError('Error fetching and inserting user profile from Supabase for email: $email - $e');
    rethrow;
  }
}

Future<Map<String, dynamic>?> getUserProfileByEmail(String email) async {
  final db = await getDatabaseMonitor().requestDatabaseAccess();
  await _verifyUserProfileTable(db!);
  final List<Map<String, dynamic>> result = await db.query(
    'user_profile',
    where: 'email = ?',
    whereArgs: [email],
  );
  getDatabaseMonitor().releaseDatabaseAccess();
  if (result.isNotEmpty) {
    return result.first;
  }
  return null;
}