import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'dart:convert';
import 'package:quizzer/backend_systems/12_switch_board/switch_board.dart';
import '00_table_helper.dart'; // Import the helper file

// TODO Enforce and introduce primary and secondary languages
// This will be used to determine whether questions should be synced based on language
// User's should be able to opt into new languages by updating secondary languages

/// Gets the user ID for a given email address.
/// Throws a StateError if no user is found.
Future<String> getUserIdByEmail(String emailAddress, Database db) async {
    QuizzerLogger.logMessage('Getting user ID for email: $emailAddress');
    // First verify the table exists
    await verifyUserProfileTable(db);
    
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
}

Future<bool> createNewUserProfile(String email, String username, Database db) async {
  QuizzerLogger.logMessage('Creating new user profile for email: $email, username: $username');
  
  // First verify that the User Profile Table exists
  await verifyUserProfileTable(db);

  // Send data to authentication service to store password field with auth service
  QuizzerLogger.logSuccess('User registered with Supabase');

  // Next Verify that the profile doesn't already exist in that Table
  final duplicateCheck = await verifyNonDuplicateProfile(email, username, db);
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
    // Initialize sync fields
    'has_been_synced': 0,
    'edits_are_synced': 0, // Edits are synced by definition on creation (or rather, no edits yet)
    'last_modified_timestamp': creationTimestamp, 
  });
  
  QuizzerLogger.logSuccess('New user profile created successfully: $userUUID');
  // Signal SwitchBoard after successful insert
  final SwitchBoard switchBoard = getSwitchBoard();
  switchBoard.signalOutboundSyncNeeded();
  return true;
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
Future<void> verifyUserProfileTable(Database db) async {
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
    // Check if tutorial_progress column exists, add it if not
    await verifyTutorialProgressColumn(db);

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
}

/// Verifies that the tutorial_progress column exists in the user_profile table
/// Adds the column if it doesn't exist
Future<void> verifyTutorialProgressColumn(Database db) async {
  QuizzerLogger.logMessage('Verifying tutorial_progress column existence');
  
  // Check if the column exists in the table
  final List<Map<String, dynamic>> columns = await db.rawQuery(
    "PRAGMA table_info(user_profile)"
  );
  
  bool columnExists = false;
  for (var column in columns) {
    if (column['name'] == 'tutorial_progress') {
      columnExists = true;
      break;
    }
  }
  
  if (!columnExists) {
    QuizzerLogger.logMessage('Adding tutorial_progress column to user_profile table');
    await db.execute('ALTER TABLE user_profile ADD COLUMN tutorial_progress INTEGER DEFAULT 0');
    QuizzerLogger.logSuccess('Added tutorial_progress column to user_profile table');
  } else {
    QuizzerLogger.logMessage('tutorial_progress column already exists');
  }
}

/// Verifies that the email and username don't already exist in the user profile table
/// Returns a map with 'isValid' (bool) indicating if the profile is non-duplicate
/// and 'message' (String) containing any error message if there's a duplicate
Future<Map<String, dynamic>> verifyNonDuplicateProfile(String email, String username, Database db) async {
  QuizzerLogger.logMessage('Verifying non-duplicate profile for email: $email, username: $username');
  verifyUserProfileTable(db);
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
  
  // Check if username already exists
  final List<Map<String, dynamic>> usernameCheck = await db.query(
    'user_profile',
    where: 'username = ?',
    whereArgs: [username],
  );
  
  // TODO Implement proper username uniqueness (maybe?)
  // if (usernameCheck.isNotEmpty) {
  //   QuizzerLogger.logError('Username already taken: $username');
  //   return {
  //     'isValid': false,
  //     'message': 'This username is already taken'
  //   };
  // }
  
  // If we get here, both email and username are unique
  QuizzerLogger.logSuccess('Email and username are available');
  return {
    'isValid': true,
    'message': 'Email and username are available'
  };
}

Future<bool> updateLastLogin(String userId, Database db) async {
  QuizzerLogger.logMessage('Updating last login for userId: $userId');
  await verifyUserProfileTable(db);
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
  final SwitchBoard switchBoard = getSwitchBoard();
  switchBoard.signalOutboundSyncNeeded();
  return true;
}

/// Gets the tutorial progress for a user
/// Returns the current tutorial question number (0-5)
Future<int> getTutorialProgress(String userId, Database db) async {
  QuizzerLogger.logMessage('Getting tutorial progress for user: $userId');
  // First verify the table structure
  await verifyUserProfileTable(db);
  await verifyTutorialProgressColumn(db);
  
  final List<Map<String, dynamic>> result = await db.query(
    'user_profile',
    columns: ['tutorial_progress'],
    where: 'uuid = ?',
    whereArgs: [userId],
  );
  
  if (result.isEmpty) {
    QuizzerLogger.logMessage('No tutorial progress found for user: $userId, defaulting to 0');
    return 0;
  }
  final progress = result.first['tutorial_progress'] as int;
  QuizzerLogger.logSuccess('Retrieved tutorial progress: $progress');
  return progress;
}

/// Updates the tutorial progress for a user
/// Returns true if the update was successful, false otherwise
Future<bool> updateTutorialProgress(String userId, int progress, Database db) async {
  QuizzerLogger.logMessage('Updating tutorial progress for user: $userId to $progress');
  await verifyUserProfileTable(db);
  await verifyTutorialProgressColumn(db);
  await db.update(
      'user_profile',
      {
        'tutorial_progress': progress,
        'edits_are_synced': 0,
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'uuid = ?',
      whereArgs: [userId],
  );
  QuizzerLogger.logSuccess('Tutorial progress updated successfully');
  // Signal SwitchBoard
  final SwitchBoard switchBoard = getSwitchBoard();
  switchBoard.signalOutboundSyncNeeded();
  return true;
}

/// Gets the activation status of modules for a user
/// Returns a Map<String, bool> where keys are module names and values are activation status
Future<Map<String, bool>> getModuleActivationStatus(String userId, Database db) async {
  QuizzerLogger.logMessage('Getting module activation status for user: $userId');
  await verifyUserProfileTable(db);
  
  final List<Map<String, dynamic>> result = await db.query(
    'user_profile',
    columns: ['activation_status_of_modules'],
    where: 'uuid = ?',
    whereArgs: [userId],
  );
  
  if (result.isEmpty || result.first['activation_status_of_modules'] == null) {
    QuizzerLogger.logMessage('No module activation status found for user: $userId, returning empty map');
    return {};
  }
  
  final String statusJson = result.first['activation_status_of_modules'] as String;
  final Map<String, dynamic> statusMap = Map<String, dynamic>.from(json.decode(statusJson));
  final Map<String, bool> activationStatus = statusMap.map(
    (key, value) => MapEntry(key, value as bool)
  );
  return activationStatus;
}

/// Updates the activation status of a specific module for a user
/// Takes a module name and boolean value to set its activation status
Future<bool> updateModuleActivationStatus(String userId, String moduleName, bool isActive, Database db) async {
  QuizzerLogger.logMessage('Updating activation status for module: $moduleName, user: $userId, status: $isActive');
  await verifyUserProfileTable(db);
  
  // First get the current activation status
  final Map<String, bool> currentStatus = await getModuleActivationStatus(userId, db);
  
  // Update the status for the specified module
  currentStatus[moduleName] = isActive;
  
  // Convert the map to a JSON string
  final String statusJson = json.encode(currentStatus);
  
  // Update the database
  await db.update(
    'user_profile',
    {
      'activation_status_of_modules': statusJson,
      'edits_are_synced': 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    },
    where: 'uuid = ?',
    whereArgs: [userId],
  );
  
  // Signal SwitchBoard
  final SwitchBoard switchBoard = getSwitchBoard();
  switchBoard.signalOutboundSyncNeeded();
  return true;
}

/// Gets the subject interest data for a user
/// If new subjects are found in the question database that aren't in the user profile,
/// they will be added with a default interest value of 10
Future<Map<String, int>> getUserSubjectInterests(String userId, Database db) async {
  // QuizzerLogger.logMessage('Getting subject interests for user: $userId');
  await verifyUserProfileTable(db);
  
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
      QuizzerLogger.logMessage('Parsed existing interests: $interestData');
    } catch (e) {
       QuizzerLogger.logError('Failed to parse interest_data JSON for user $userId: $e');
       throw FormatException('Failed to parse interest_data JSON for user $userId: $e');
    }
  } else {
     QuizzerLogger.logMessage('No existing interest_data found for user $userId.');
     interestData = {};
  }

  // Get all unique subjects from question database
  final Set<String> allSubjects = await getUniqueSubjects(db);
  allSubjects.add('misc'); // hidden misc subject for handling questions without subjects
  QuizzerLogger.logMessage('Unique subjects from questions table: $allSubjects');

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
      final SwitchBoard switchBoard = getSwitchBoard();
      switchBoard.signalOutboundSyncNeeded();
    }
  }

  QuizzerLogger.logSuccess('Returning final subject interests for user $userId: $interestData');
  return interestData;
}

// --- Helper Functions ---

/// Updates the total_study_time for a user by adding the specified amount of hours.
/// The time is converted to days before adding to the total_study_time column.
///
/// [userUuid]: The UUID of the user whose study time needs updating.
/// [hoursToAdd]: The duration in hours (double) to add to the total study time.
/// [db]: The database instance.
Future<void> updateTotalStudyTime(String userUuid, double hoursToAdd, Database db) async {
  QuizzerLogger.logMessage('Updating total_study_time for User: $userUuid, adding: $hoursToAdd hours');

  // Convert hours to days for storage
  final double daysToAdd = hoursToAdd / 24.0;
  QuizzerLogger.logValue('Converted hours to days: $daysToAdd');

  // We assume verifyUserProfileTable has been called before or during DB initialization.

  final int rowsAffected = await db.rawUpdate(
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
    final SwitchBoard switchBoard = getSwitchBoard();
    switchBoard.signalOutboundSyncNeeded();
  }
}

/// Increments the total_questions_answered count for a specific user.
Future<void> incrementTotalQuestionsAnswered(String userUuid, Database db) async {
  QuizzerLogger.logMessage('Incrementing total_questions_answered for User: $userUuid');
  
  // Ensure the table and column exist (verification happens elsewhere, but good practice)
  // We assume verifyUserProfileTable is called prior to DB operations usually.

  final int rowsAffected = await db.rawUpdate(
    'UPDATE user_profile SET total_questions_answered = total_questions_answered + 1, edits_are_synced = 0, last_modified_timestamp = ? WHERE uuid = ?',
    [DateTime.now().toUtc().toIso8601String(), userUuid]
  );

  if (rowsAffected == 0) {
    QuizzerLogger.logWarning('Failed to increment total_questions_answered: No matching record found for User: $userUuid');
    // Consider if this should throw an error if the user *must* exist at this point.
  } else {
    QuizzerLogger.logSuccess('Successfully incremented total_questions_answered for User: $userUuid');
    // Signal SwitchBoard
    final SwitchBoard switchBoard = getSwitchBoard();
    switchBoard.signalOutboundSyncNeeded();
  }
}

/// Retrieves a list of all email addresses from the user_profile table.
Future<List<String>> getAllUserEmails(Database db) async {
  QuizzerLogger.logMessage('Fetching all emails from user_profile table.');
  // Ensure table exists (Fail Fast if verifyUserProfileTable fails)
  await verifyUserProfileTable(db);

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
}

// --- Get Unsynced Records ---

/// Fetches all user profiles that need outbound synchronization for a specific user.
/// This includes records that have never been synced (`has_been_synced = 0`)
/// or records that have local edits pending sync (`edits_are_synced = 0`).
/// Does NOT decode the records.
Future<List<Map<String, dynamic>>> getUnsyncedUserProfiles(Database db, String userId) async {
  QuizzerLogger.logMessage('Fetching unsynced user profile for user ID: $userId...');
  await verifyUserProfileTable(db); // Ensure table and sync columns exist

  final List<Map<String, dynamic>> results = await db.query(
    'user_profile',
    where: '(has_been_synced = 0 OR edits_are_synced = 0) AND uuid = ?',
    whereArgs: [userId], // Use the passed userId parameter
  );

  QuizzerLogger.logSuccess('Fetched ${results.length} unsynced user profiles for user $userId.');
  return results;
}

// --- Update Sync Flags ---

/// Updates the synchronization flags for a specific user profile.
/// Does NOT trigger a new sync signal.
Future<void> updateUserProfileSyncFlags({
  required String userId,
  required bool hasBeenSynced,
  required bool editsAreSynced,
  required Database db,
}) async {
  QuizzerLogger.logMessage('Updating sync flags for User Profile: $userId -> Synced: $hasBeenSynced, Edits Synced: $editsAreSynced');
  await verifyUserProfileTable(db); // Ensure table/columns exist

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
}

/// Gets the last_login timestamp for a user by userId. Returns null if not found.
Future<String?> getLastLoginForUser(String userId, Database db) async {
  final List<Map<String, dynamic>> result = await db.query(
    'user_profile',
    columns: ['last_login'],
    where: 'uuid = ?',
    whereArgs: [userId],
  );
  if (result.isEmpty) return null;
  return result.first['last_login'] as String?;
}

// TODO: FIXME Add in functionality for loginThreshold preference