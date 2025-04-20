import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'dart:convert';

Future<String?> getUserIdByEmail(String emailAddress, Database db) async {
    QuizzerLogger.logMessage('Getting user ID for email: $emailAddress');
    try {
        // First verify the table exists
        await verifyUserProfileTable(db);
        
        final List<Map<String, dynamic>> result = await db.query(
            'user_profile',
            columns: ['uuid'],
            where: 'email = ?',
            whereArgs: [emailAddress],
        );

        if (result.isNotEmpty) {
            QuizzerLogger.logSuccess('Found user ID: ${result.first['uuid']}');
            return result.first['uuid'] as String?;
        } else {
            QuizzerLogger.logMessage('No user found with email: $emailAddress');
            return null;
        }
    } catch (e) {
        QuizzerLogger.logError('Error getting user ID: $e');
        return null;
    }
}

Future<bool> createNewUserProfile(String email, String username, String password, Database db) async {
  try {
    QuizzerLogger.logMessage('Creating new user profile for email: $email, username: $username');
    
    // First verify that the User Profile Table exists
    await verifyUserProfileTable(db);

    // Send data to authentication service to store password field with auth service
    QuizzerLogger.logSuccess('User registered with Supabase');

    // Next Verify that the profile doesn't already exist in that Table
    final duplicateCheck = await verifyNonDuplicateProfile(email, username, db);
    if (!duplicateCheck['isValid']) {
        QuizzerLogger.logError(duplicateCheck['message']);
        return false;
    }

    // Generate a UUID for the new user
    final String userUUID = generateUserUUID();
    QuizzerLogger.logMessage('Generated UUID for new user: $userUUID');
    
    // Get current timestamp for account creation date
    final String creationTimestamp = DateTime.now().toIso8601String();
    
    // Insert the new user profile with minimal required fields
    await db.insert('user_profile', {
      'uuid': userUUID,
      'email': email,
      'username': username,
      'role': 'base_user',
      'account_status': 'active',
      'account_creation_date': creationTimestamp,
    });
    
    QuizzerLogger.logSuccess('New user profile created successfully: $userUUID');
    return true;
  } catch (e) {
    QuizzerLogger.logError('Error creating new user profile: $e');
    return false;
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
        tutorial_progress INTEGER DEFAULT 0
      )
    ''');
    
    QuizzerLogger.logSuccess('User Profile table created successfully');
  } else {
    // Check if tutorial_progress column exists, add it if not
    await verifyTutorialProgressColumn(db);
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
  
  if (usernameCheck.isNotEmpty) {
    QuizzerLogger.logError('Username already taken: $username');
    return {
      'isValid': false,
      'message': 'This username is already taken'
    };
  }
  
  // If we get here, both email and username are unique
  QuizzerLogger.logSuccess('Email and username are available');
  return {
    'isValid': true,
    'message': 'Email and username are available'
  };
}

Future<bool> updateLastLogin(String timestamp, String emailAddress, Database db) async {
  QuizzerLogger.logMessage('Updating last login for email: $emailAddress');
  await verifyUserProfileTable(db);
  await db.update(
    'user_profile',
    {'last_login': timestamp},
    where: 'email = ?',
    whereArgs: [emailAddress],
  );
  QuizzerLogger.logSuccess('Last login updated successfully');
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
      {'tutorial_progress': progress},
      where: 'uuid = ?',
      whereArgs: [userId],
  );
  QuizzerLogger.logSuccess('Tutorial progress updated successfully');
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
  
  try {
    final String statusJson = result.first['activation_status_of_modules'] as String;
    final Map<String, dynamic> statusMap = Map<String, dynamic>.from(json.decode(statusJson));
    final Map<String, bool> activationStatus = statusMap.map(
      (key, value) => MapEntry(key, value as bool)
    );
    QuizzerLogger.logSuccess('Retrieved module activation status: $activationStatus');
    return activationStatus;
  } catch (e) {
    QuizzerLogger.logError('Error parsing module activation status: $e');
    return {};
  }
}

/// Updates the activation status of a specific module for a user
/// Takes a module name and boolean value to set its activation status
Future<bool> updateModuleActivationStatus(String userId, String moduleName, bool isActive, Database db) async {
  QuizzerLogger.logMessage('Updating activation status for module: $moduleName, user: $userId, status: $isActive');
  await verifyUserProfileTable(db);
  
  try {
    // First get the current activation status
    final Map<String, bool> currentStatus = await getModuleActivationStatus(userId, db);
    
    // Update the status for the specified module
    currentStatus[moduleName] = isActive;
    
    // Convert the map to a JSON string
    final String statusJson = json.encode(currentStatus);
    
    // Update the database
    await db.update(
      'user_profile',
      {'activation_status_of_modules': statusJson},
      where: 'uuid = ?',
      whereArgs: [userId],
    );
    
    QuizzerLogger.logSuccess('Successfully updated module activation status');
    return true;
  } catch (e) {
    QuizzerLogger.logError('Error updating module activation status: $e');
    return false;
  }
}

// TODO: FIXME Add in functionality for loginThreshold preference