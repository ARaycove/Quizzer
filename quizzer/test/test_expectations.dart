import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';

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
