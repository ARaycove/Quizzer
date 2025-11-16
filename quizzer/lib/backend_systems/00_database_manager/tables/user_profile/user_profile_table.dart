import 'package:uuid/uuid.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'dart:convert';
import 'package:quizzer/backend_systems/09_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

final List<Map<String, String>> expectedColumns = [
  {'name': 'uuid',                  'type': 'TEXT PRIMARY KEY'},
  {'name': 'email',                 'type': 'TEXT NOT NULL'},
  {'name': 'username',              'type': 'TEXT NOT NULL'},
  // Specific Account information
  {'name': 'role',                  'type': 'TEXT DEFAULT \'base_user\''},
  {'name': 'account_status',        'type': 'TEXT DEFAULT \'active\''},
  {'name': 'account_creation_date', 'type': 'TEXT NOT NULL'},
  {'name': 'last_login',            'type': 'TEXT'},
  // Education level indicators
  {'name': 'highest_level_edu',     'type': 'TEXT'},
  {'name': 'undergrad_major',       'type': 'TEXT'},
  {'name': 'undergrad_minor',       'type': 'TEXT'},
  {'name': 'grad_major',            'type': 'TEXT'},
  {'name': 'years_since_graduation','type': 'INTEGER'},
  {'name': 'education_background',  'type': 'TEXT'},
  {'name': 'teaching_experience',   'type': 'INTEGER'}, // How many years of teaching experience does the user have.

  // socio-cultural indicators
  {'name': 'profile_picture',       'type': 'TEXT'},
  {'name': 'country_of_origin',     'type': 'TEXT'},
  {'name': 'current_country',       'type': 'TEXT'},
  {'name': 'current_state',         'type': 'TEXT'},
  {'name': 'current_city',          'type': 'TEXT'},
  {'name': 'urban_rural',           'type': 'TEXT'}, // Is the address in a rural, suburban, or urban setting?
  {'name': 'religion',              'type': 'TEXT'},
  {'name': 'political_affilition',  'type': 'TEXT'},
  {'name': 'marital_status',        'type': 'TEXT'},
  {'name': 'num_children',          'type': 'INTEGER'},
  {'name': 'veteran_status',        'type': 'INTEGER'},
  {'name': 'native_language',       'type': 'TEXT'},
  {'name': 'secondary_languages',   'type': 'TEXT'},
  {'name': 'num_languages_spoken',  'type': 'INTEGER'},
  {'name': 'birth_date',            'type': 'TEXT'},
  {'name': 'age',                   'type': 'INTEGER'},
  {'name': 'household_income',      'type': 'REAL'},
  {'name': 'learning_disabilities', 'type': 'TEXT'}, // Array of learning disabilities (ADHD, Autism, Aspergers, etc)
  {'name': 'physical_disabilities', 'type': 'TEXT'}, // Array of physical disabilities (amputee, wheel-chair, crippled)
  {'name': 'housing_situation',     'type': 'TEXT'},
  {'name': 'birth_order',           'type': 'TEXT'},


  // Work experience
  {'name': 'current_occupation',    'type': 'TEXT'},
  {'name': 'years_work_experience', 'type': 'INTEGER'},
  {'name': 'hours_worked_per_week', 'type': 'REAL'},
  {'name': 'total_job_changes',     'type': 'INTEGER'},

  {'name': 'interest_data', 'type': 'TEXT'},                //TODO move to settings, the interest data will be a map of ratings, depicting how interested in any given subject or topic a user is, this is used for circulation and selection criteria
  {'name': 'notification_preferences', 'type': 'TEXT'},     //TODO should be a setting, leave here for now
  {'name': 'total_study_time', 'type': 'REAL DEFAULT 0.0'}, //TODO move to stat table
  {'name': 'average_session_length', 'type': 'REAL'},       //TODO move to stat table
  {'name': 'has_been_synced', 'type': 'INTEGER DEFAULT 0'},
  {'name': 'edits_are_synced', 'type': 'INTEGER DEFAULT 0'},
  {'name': 'last_modified_timestamp', 'type': 'TEXT'},
];


/// Gets the user ID for a given email address.
/// Throws a StateError if no user is found.
Future<String> getUserIdByEmail(String emailAddress) async {
  try {
    QuizzerLogger.logMessage('Getting user ID for email: $emailAddress');
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    // Query might fail if table doesn't exist yet, let it crash (Fail Fast)
    final List<Map<String, dynamic>> result = await db!.query(
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
    await db!.insert('user_profile', {
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
  // TODO Deprecated, need to convert UUID system such that UUID for account matches the one generated by SUPABASE
  const uuid = Uuid();
  final generatedUUID = uuid.v4();
  QuizzerLogger.logMessage('Generated new UUID: $generatedUUID');
  return generatedUUID;
}

/// Verifies that the User Profile Table exists in the database
/// Creates the table if it doesn't exist based on the schema in documentation
/// Private function that requires a database parameter to avoid race conditions
Future<void> verifyUserProfileTable(dynamic db) async {
  try {
    QuizzerLogger.logMessage('Verifying user profile table existence');
    
    // Define expected columns with their types and constraints


    // Check if the table exists
    final List<Map<String, dynamic>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      ['user_profile']
    );

    if (tables.isEmpty) {
      // Create the table if it doesn't exist
      QuizzerLogger.logMessage('User profile table does not exist, creating it');
      
      String createTableSQL = 'CREATE TABLE user_profile(\n';
      createTableSQL += expectedColumns.map((col) => '  ${col['name']} ${col['type']}').join(',\n');
      createTableSQL += '\n)';
      
      await db.execute(createTableSQL);
      QuizzerLogger.logSuccess('User Profile table created successfully');
    } else {
      // Table exists, check for column differences
      QuizzerLogger.logMessage('User profile table exists, checking column structure');
      
      // Get current table structure
      final List<Map<String, dynamic>> currentColumns = await db.rawQuery(
        "PRAGMA table_info(user_profile)"
      );
      
      final Set<String> currentColumnNames = currentColumns
          .map((column) => column['name'] as String)
          .toSet();
      
      final Set<String> expectedColumnNames = expectedColumns
          .map((column) => column['name']!)
          .toSet();
      
      // Find columns to add (expected but not current)
      final Set<String> columnsToAdd = expectedColumnNames.difference(currentColumnNames);
      
      // Find columns to remove (current but not expected)
      final Set<String> columnsToRemove = currentColumnNames.difference(expectedColumnNames);
      
      // Add missing columns
      for (String columnName in columnsToAdd) {
        final columnDef = expectedColumns.firstWhere((col) => col['name'] == columnName);
        QuizzerLogger.logMessage('Adding missing column: $columnName');
        await db.execute('ALTER TABLE user_profile ADD COLUMN ${columnDef['name']} ${columnDef['type']}');
      }
      
      // Remove unexpected columns (SQLite doesn't support DROP COLUMN directly)
      if (columnsToRemove.isNotEmpty) {
        QuizzerLogger.logMessage('Removing unexpected columns: ${columnsToRemove.join(', ')}');
        
        // Create temporary table with only expected columns
        String tempTableSQL = 'CREATE TABLE user_profile_temp(\n';
        tempTableSQL += expectedColumns.map((col) => '  ${col['name']} ${col['type']}').join(',\n');
        tempTableSQL += '\n)';
        
        await db.execute(tempTableSQL);
        
        // Copy data from old table to temp table (only expected columns)
        String columnList = expectedColumnNames.join(', ');
        await db.execute('INSERT INTO user_profile_temp ($columnList) SELECT $columnList FROM user_profile');
        
        // Drop old table and rename temp table
        await db.execute('DROP TABLE user_profile');
        await db.execute('ALTER TABLE user_profile_temp RENAME TO user_profile');
        
        QuizzerLogger.logSuccess('Removed unexpected columns and restructured table');
      }
      
      if (columnsToAdd.isEmpty && columnsToRemove.isEmpty) {
        QuizzerLogger.logMessage('Table structure is already up to date');
      } else {
        QuizzerLogger.logSuccess('Table structure updated successfully');
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
    
    final String nowTimestamp = DateTime.now().toUtc().toIso8601String();
    final String lastLoginTimestamp = DateTime.now().subtract(const Duration(minutes: 1)).toUtc().toIso8601String();
    final Map<String, dynamic> updates = {
      'last_login': lastLoginTimestamp,
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

/// Gets the subject interest data for a user
/// If new subjects are found in the question database that aren't in the user profile,
/// they will be added with a default interest value of 10
Future<Map<String, int>> getUserSubjectInterests(String userId) async {
  try {
    // QuizzerLogger.logMessage('Getting subject interests for user: $userId');
    // Since subjects are now handled by separate relationship tables, we'll use a default set
    final Set<String> allSubjects = {'misc'}; // Default subject for handling questions without subjects
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    // Query for the user's interest data column
    final List<Map<String, dynamic>> result = await db!.query(
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
    // Query the database for the email column
    // If query fails (e.g., table structure wrong), let it crash (Fail Fast)
    final List<Map<String, dynamic>> results = await db!.query(
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
    final List<Map<String, dynamic>> results = await db!.query(
      'user_profile',
      where: '(has_been_synced = 0 OR edits_are_synced = 0) AND uuid = ?',
      whereArgs: [userId], // Use the passed userId parameter
    );

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
Future<void> upsertUserProfileFromInboundSync({
  required List<Map<String, dynamic>> profileDataList,
  required dynamic db,
}) async {
  try {
    if (profileDataList.isEmpty) return;
    
    final profileData = profileDataList[0];
    final dataToInsert = <String, dynamic>{};
    
    for (final col in expectedColumns) {
      final name = col['name'] as String;
      if (profileData.containsKey(name)) {
        dataToInsert[name] = profileData[name];
      }
    }
    
    dataToInsert['has_been_synced'] = 1;
    dataToInsert['edits_are_synced'] = 1;
    
    await insertRawData('user_profile', dataToInsert, db, conflictAlgorithm: ConflictAlgorithm.replace);
  } catch (e) {
    QuizzerLogger.logError('Error upserting user profile from inbound sync - $e');
    rethrow;
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
    
    // Ensure last_modified_timestamp is not null by setting it to current time if it's null
    if (profileData['last_modified_timestamp'] == null) {
      QuizzerLogger.logMessage('Supabase profile has null last_modified_timestamp, setting to current time');
      profileData['last_modified_timestamp'] = DateTime.now().toIso8601String();
    }
    
    // Insert the profile into local database using the existing upsert function
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await upsertUserProfileFromInboundSync(profileDataList: [profileData], db: db);
    getDatabaseMonitor().releaseDatabaseAccess();
    
    QuizzerLogger.logSuccess('Successfully inserted user profile from Supabase for email: $email');
  } catch (e) {
    QuizzerLogger.logError('Error fetching and inserting user profile from Supabase for email: $email - $e');
    rethrow;
  }
}

Future<Map<String, dynamic>?> getUserProfileByEmail(String email) async {
  final db = await getDatabaseMonitor().requestDatabaseAccess();
  final List<Map<String, dynamic>> result = await db!.query(
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