import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:quizzer/database/quizzer_database.dart';

Future<bool> createNewUserProfile(String email, String username) async {
  try {
    // First verify that the User Profile Table exists
    await verifyUserProfileTable();
    
    // Next Verify that the profile doesn't already exist in that Table
    await verifyNonDuplicateProfile(email, username);

    // Generate a UUID for the new user
    final String userUUID = generateUserUUID();
    
    // Get current timestamp for account creation date
    final String creationTimestamp = DateTime.now().toIso8601String();
    
    // Get database instance
    final Database db = await getDatabase();
    
    // Insert the new user profile with minimal required fields
    await db.insert('user_profile', {
      'uuid': userUUID,
      'email': email,
      'username': username,
      'role': 'base_user',
      'account_status': 'active',
      'account_creation_date': creationTimestamp,
      // All other fields will be initialized to NULL by default
      // Fields like settings and notification preferences will be initialized when first used
    });
    
    print('New user profile created successfully: $userUUID');
    return true;
  } catch (e) {
    print('Error creating new user profile: $e');
    return false;
  }
}

/// Generates a unique UUID for a new user
String generateUserUUID() {
  // Using the uuid package to generate a v4 (random) UUID
  const uuid = Uuid();
  return uuid.v4();
}

/// Verifies that the User Profile Table exists in the database
/// Creates the table if it doesn't exist based on the schema in documentation
Future<void> verifyUserProfileTable() async {
  final Database db = await getDatabase();
  
  // Check if the table exists
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='user_profile'"
  );
  
  if (tables.isEmpty) {
    // Create user_profile table according to the schema in documentation
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
      completion_status_of_modules TEXT
    )
    ''');
    
    print('User Profile table created successfully');
  } else {
    print('User Profile table already exists');
  }
}

/// Verifies that the email and username don't already exist in the user profile table
/// Returns a map with 'isValid' (bool) indicating if the profile is non-duplicate
/// and 'message' (String) containing any error message if there's a duplicate
Future<Map<String, dynamic>> verifyNonDuplicateProfile(String email, String username) async {
  final Database db = await getDatabase();
  
  // Check if email already exists
  final List<Map<String, dynamic>> emailCheck = await db.query(
    'user_profile',
    where: 'email = ?',
    whereArgs: [email],
  );
  
  if (emailCheck.isNotEmpty) {
    return {
      'isValid': false,
      'message': 'This email address is already registered'
    };
  }
  
  // Check if username already exists
  final List<Map<String, dynamic>> usernameCheck = await db.query(
    'user_profile',
    where: 'username = ?',
    whereArgs: [username],
  );
  
  if (usernameCheck.isNotEmpty) {
    return {
      'isValid': false,
      'message': 'This username is already taken'
    };
  }
  
  // If we get here, both email and username are unique
  return {
    'isValid': true,
    'message': 'Email and username are available'
  };
}