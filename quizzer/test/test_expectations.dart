import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_settings_table.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

/// Expects a table to have 0 records in it
/// 
/// Parameters:
/// - tableName: The name of the table to check
/// 
/// Throws:
/// - TestFailure if the table has any records
Future<void> expectTableIsEmpty(String tableName) async {
  QuizzerLogger.logMessage('Checking if table $tableName is empty');
  
  final db = await getDatabaseMonitor().requestDatabaseAccess();
  if (db == null) {
    throw Exception('Failed to acquire database access');
  }
  
  try {
    final List<Map<String, dynamic>> records = await db.query(tableName);
    expect(records.length, equals(0), reason: 'Table $tableName should be empty but has ${records.length} records');
    QuizzerLogger.logSuccess('✅ Table $tableName is empty');
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Expects a table to not exist in the database
/// 
/// Parameters:
/// - tableName: The name of the table to check
/// 
/// Throws:
/// - TestFailure if the table exists
Future<void> expectTableIsMissing(String tableName) async {
  QuizzerLogger.logMessage('Checking if table $tableName is missing');
  
  final db = await getDatabaseMonitor().requestDatabaseAccess();
  if (db == null) {
    throw Exception('Failed to acquire database access');
  }
  
  try {
    final List<Map<String, dynamic>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'"
    );
    expect(tables.isEmpty, isTrue, reason: 'Table $tableName should not exist but was found');
    QuizzerLogger.logSuccess('✅ Table $tableName is missing');
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Expects a table to have exactly N number of records
/// 
/// Parameters:
/// - tableName: The name of the table to check
/// - expectedCount: The expected number of records
/// 
/// Throws:
/// - TestFailure if the table doesn't have exactly N records
Future<void> expectNRecords(String tableName, int expectedCount) async {
  QuizzerLogger.logMessage('Checking if table $tableName has exactly $expectedCount records');
  
  final db = await getDatabaseMonitor().requestDatabaseAccess();
  if (db == null) {
    throw Exception('Failed to acquire database access');
  }
  
  try {
    final List<Map<String, dynamic>> records = await db.query(tableName);
    expect(records.length, equals(expectedCount), reason: 'Table $tableName should have $expectedCount records but has ${records.length}');
    QuizzerLogger.logSuccess('✅ Table $tableName has exactly $expectedCount records');
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Expects a specific field in a table to have an expected value for a given primary key
/// 
/// Parameters:
/// - tableName: The name of the table to check
/// - primaryKey: The primary key field name
/// - primaryKeyValue: The primary key value to search for
/// - expectedField: The field name to check
/// - expectedValue: The expected value for the field
/// 
/// Throws:
/// - TestFailure if the record doesn't exist or the field doesn't match the expected value
Future<void> expectValueInTable(String tableName, String primaryKey, dynamic primaryKeyValue, String expectedField, dynamic expectedValue) async {
  QuizzerLogger.logMessage('Checking if table $tableName has $expectedField = $expectedValue for $primaryKey = $primaryKeyValue');
  
  final db = await getDatabaseMonitor().requestDatabaseAccess();
  if (db == null) {
    throw Exception('Failed to acquire database access');
  }
  
  try {
    final List<Map<String, dynamic>> records = await db.query(
      tableName,
      where: '$primaryKey = ?',
      whereArgs: [primaryKeyValue],
    );
    
    expect(records.isNotEmpty, isTrue, reason: 'No record found in table $tableName with $primaryKey = $primaryKeyValue');
    expect(records.length, equals(1), reason: 'Multiple records found in table $tableName with $primaryKey = $primaryKeyValue');
    
    final record = records.first;
    expect(record.containsKey(expectedField), isTrue, reason: 'Field $expectedField not found in table $tableName');
    expect(record[expectedField], equals(expectedValue), reason: 'Field $expectedField in table $tableName should be $expectedValue but was ${record[expectedField]}');
    
    QuizzerLogger.logSuccess('✅ Table $tableName has $expectedField = $expectedValue for $primaryKey = $primaryKeyValue');
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Expects that the user settings in the database match a given list of non-default mock settings.
///
/// This function fetches all settings for a user and verifies that each setting provided in the
/// `mockSettings` list has the expected value and admin status.
///
/// Parameters:
/// - userId: The user ID whose settings are to be checked.
/// - mockSettings: A list of maps, where each map represents a setting with its expected non-default state.
///
/// Throws:
/// - TestFailure if any setting does not match the expected value or admin status.
Future<void> expectNonDefaultSettings(String userId, List<Map<String, dynamic>> mockSettings) async {
  QuizzerLogger.logMessage('Verifying non-default user settings for user $userId');

  final allSettings = await getAllUserSettings(userId);

  // Verify that the values match the mock data we upserted
  for (final mockSetting in mockSettings) {
    final String settingName = mockSetting['setting_name'] as String;
    final dynamic expectedValue = mockSetting['setting_value'];
    // is_admin_setting in mock data is a bool, but in the DB it's an int (0 or 1).
    final bool isAdmin = mockSetting['is_admin_setting'] as bool;

    expect(allSettings.containsKey(settingName), isTrue, reason: 'Setting "$settingName" should exist');
    
    final fetchedSetting = allSettings[settingName]!;
    expect(fetchedSetting['setting_value'].toString(), equals(expectedValue.toString()), reason: 'Setting "$settingName" should have the correct value from mock data');
    expect(fetchedSetting['is_admin_setting'], equals(isAdmin ? 1 : 0), reason: 'Setting "$settingName" should have the correct admin flag');
  }

  QuizzerLogger.logSuccess('✅ Verified ${mockSettings.length} non-default settings successfully.');
}

/// Expects that all of a user's settings are set to their default values.
///
/// This function fetches the application's default settings specification and compares it
/// against the user's current settings stored in the database.
///
/// Parameters:
/// - userId: The user ID whose settings are to be checked.
///
/// Throws:
/// - TestFailure if any setting does not match its default value.
Future<void> expectDefaultSettings(String userId) async {
  QuizzerLogger.logMessage('Verifying user settings are at default for user $userId');

  final allSettings = await getAllUserSettings(userId);
  final expectedSettings = getApplicationUserSettings();

  expect(allSettings.length, equals(expectedSettings.length), reason: 'Should have the same number of settings as defined in the application spec');

  for (final settingSpec in expectedSettings) {
    final String settingName = settingSpec['name'] as String;
    final dynamic expectedDefaultValue = settingSpec['default_value'];

    expect(allSettings.containsKey(settingName), isTrue, reason: 'Setting "$settingName" should exist');

    final Map<String, dynamic> settingDetails = allSettings[settingName]!;

    final String storedValue = (settingDetails['setting_value'] ?? 'null').toString();
    final String expectedValueStr = (expectedDefaultValue ?? 'null').toString();

    expect(storedValue, equals(expectedValueStr), reason: 'Setting "$settingName" should have correct default value');
  }

  QuizzerLogger.logSuccess('✅ Verified all user settings are at their default values.');
}

/// Expects that the user profile table exists and the local user ID matches the Supabase user ID
Future<void> expectUserProfileTableExistsAndUserIdsMatch(SessionManager sessionManager) async {
  QuizzerLogger.logMessage('Verifying user profile table exists and user IDs match');
  
  // Check if user_profile table exists
  final db = await getDatabaseMonitor().requestDatabaseAccess();
  if (db == null) {
    throw Exception('Failed to acquire database access');
  }
  
  try {
    final List<Map<String, dynamic>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='user_profile'"
    );
    expect(tables.isNotEmpty, isTrue, reason: 'user_profile table should exist but was not found');
    QuizzerLogger.logSuccess('✅ user_profile table exists');
    
    // Get the current user ID from session manager
    final String? localUserId = sessionManager.userId;
    expect(localUserId, isNotNull, reason: 'Local user ID should not be null');
    
    // Query local database to get the user's email
    final List<Map<String, dynamic>> localProfiles = await db.query(
      'user_profile',
      where: 'uuid = ?',
      whereArgs: [localUserId],
    );
    
    expect(localProfiles.isNotEmpty, isTrue, reason: 'User profile should exist locally');
    final String userEmail = localProfiles.first['email'] as String;
    
    // Query Supabase to get the user profile for this specific email
    final List<Map<String, dynamic>> supabaseProfiles = await sessionManager.supabase
        .from('user_profile')
        .select('uuid')
        .eq('email', userEmail);
    
    expect(supabaseProfiles.isNotEmpty, isTrue, reason: 'User profile should exist in Supabase for email: $userEmail');
    
    // Verify the profile that matches our local user ID exists
    supabaseProfiles.firstWhere(
      (profile) => profile['uuid'] == localUserId,
      orElse: () => throw Exception('No matching profile found in Supabase'),
    );
    
    QuizzerLogger.logSuccess('✅ Local user ID matches Supabase user ID');
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Expects that all local settings starting with "home_display" have the value "1"
/// 
/// This function verifies that all home display settings in the local database
/// have been updated to the value "1" as expected after user modifications.
/// 
/// Parameters:
/// - userId: The user ID whose settings are to be checked
/// 
/// Throws:
/// - TestFailure if any home_display setting does not equal "1"
Future<void> expectAllLocalHomeDisplaySettingsEqualOne(String userId) async {
  QuizzerLogger.logMessage('Verifying all home_display settings equal "1" for user $userId');
  
  final db = await getDatabaseMonitor().requestDatabaseAccess();
  if (db == null) {
    throw Exception('Failed to acquire database access');
  }
  
  try {
    // Query all user settings for this user
    final List<Map<String, dynamic>> userSettings = await db.query(
      'user_settings',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    
    expect(userSettings.isNotEmpty, isTrue, reason: 'User should have settings in the database');
    
    // Filter for home_display settings and verify they all equal "1"
    final homeDisplaySettings = userSettings.where((setting) => 
      (setting['setting_name'] as String).startsWith('home_display')
    ).toList();
    
    expect(homeDisplaySettings.isNotEmpty, isTrue, reason: 'Should have at least one home_display setting');
    
    for (final setting in homeDisplaySettings) {
      final String settingName = setting['setting_name'] as String;
      final String settingValue = setting['setting_value'] as String;
      
      expect(settingValue, equals('1'), reason: 'Setting "$settingName" should equal "1" but was "$settingValue"');
    }
    
    QuizzerLogger.logSuccess('✅ All ${homeDisplaySettings.length} home_display settings equal "1"');
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Expects that all Supabase server settings starting with "home_display" have the value "1"
/// 
/// This function verifies that all home display settings in the Supabase server database
/// have been updated to the value "1" as expected after outbound sync operations.
/// 
/// Parameters:
/// - userId: The user ID whose settings are to be checked
/// 
/// Throws:
/// - TestFailure if any home_display setting on the server does not equal "1"
Future<void> expectAllSupabaseHomeDisplaySettingsEqualOne(String userId) async {
  final sessionManager = getSessionManager();
  QuizzerLogger.logMessage('Verifying all Supabase server home_display settings equal "1" for user $userId');
  
  try {
    // Get all user settings for this user from Supabase
    final List<Map<String, dynamic>> allSettings = await sessionManager.supabase
        .from('user_settings')
        .select('*')
        .eq('user_id', userId);
    QuizzerLogger.logMessage("Found these settings for user: $userId \n $allSettings");
    
    expect(allSettings.isNotEmpty, isTrue, reason: 'User should have settings on the Supabase server');
    
    // Check each setting
    for (final setting in allSettings) {
      final String settingName = setting['setting_name'] as String;
      final String settingValue = setting['setting_value'] as String;
      
      if (settingName.startsWith('home_display')) {
        expect(settingValue, equals('1'), reason: 'Server setting "$settingName" should equal "1" but was "$settingValue"');
      }
    }
    
    QuizzerLogger.logSuccess('✅ All Supabase server home_display settings equal "1"');
  } catch (e) {
    QuizzerLogger.logError('Error checking Supabase server home_display settings: $e');
    rethrow;
  }
}
