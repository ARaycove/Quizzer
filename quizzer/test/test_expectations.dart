import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_settings_table.dart';

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
  final expectedSettings = getApplicationUserSettingsSpec();

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
