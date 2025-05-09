import 'dart:convert';
import 'package:sqflite/sqflite.dart'; // Added for Database type
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Added for logging

// --- Universal Encoding/Decoding Helpers ---

/// Encodes a Dart value into a type suitable for SQLite storage (TEXT, INTEGER, REAL, NULL).
/// Handles Strings, ints, doubles, booleans, Lists, and Maps.
/// Lists and Maps are encoded as JSON TEXT. Booleans are stored as INTEGER (1/0).
/// Throws StateError for unsupported types.
dynamic encodeValueForDB(dynamic value) {
  if (value == null) {
    return null; // Store nulls directly
  } else if (value is String || value is int || value is double) {
    return value; // Store primitives directly
  } else if (value is bool) {
    return value ? 1 : 0; // Store booleans as integers
  } else if (value is List || value is Map) {
    // Encode Lists and Maps as JSON strings
    // json.encode itself can throw if objects are not encodable, which aligns with Fail Fast.
    return json.encode(value);
  } else {
    // Fail Fast for any other type
    throw StateError('Unsupported type for database encoding: ${value.runtimeType}');
  }
}

/// Decodes a value retrieved from SQLite back into its likely Dart type.
/// Assumes that TEXT fields starting with '[' or '{' are JSON strings representing Lists/Maps.
/// Other TEXT fields are returned as Strings. INTEGER, REAL, and NULL are returned directly.
/// Does NOT automatically convert INTEGER back to boolean; callers must handle this based on context.
dynamic decodeValueFromDB(dynamic dbValue) {
  if (dbValue == null || dbValue is int || dbValue is double) {
    return dbValue; // Return nulls, integers, and doubles directly
  } else if (dbValue is String) {
    // Trim whitespace before checking brackets/braces
    final trimmedValue = dbValue.trim();
    if (trimmedValue.startsWith('[') || trimmedValue.startsWith('{')) {
      // Attempt to decode potential JSON strings
      // json.decode will throw FormatException on invalid JSON, aligning with Fail Fast.
      return json.decode(trimmedValue);
    } else {
      // Assume it's a plain string if it doesn't look like JSON
      return dbValue;
    }
  } else {
    // Should not happen with standard SQLite types (TEXT, INTEGER, REAL, NULL, BLOB)
    // BLOBs are not currently handled.
    throw StateError('Unsupported type retrieved from database: ${dbValue.runtimeType}');
  }
}

// --- Universal Database Operation Helpers ---

/// Inserts a row into the specified table after encoding the values in the data map.
///
/// Args:
///   tableName: The name of the table to insert into.
///   data: A map where keys are column names and values are the raw Dart objects to insert.
///   db: The database instance.
///   conflictAlgorithm: Optional conflict resolution algorithm (defaults to none).
///
/// Returns:
///   The row ID of the last inserted row if successful, 0 otherwise (e.g., if ignored).
///   Throws exceptions on database errors (Fail Fast).
Future<int> insertRawData(
  String tableName,
  Map<String, dynamic> data,
  Database db,
  {ConflictAlgorithm? conflictAlgorithm} // Added optional conflictAlgorithm
) async {
  // QuizzerLogger.logValue('Encoding data for insertion into table: $tableName');
  final Map<String, dynamic> encodedData = {};
  
  // Iterate through the input map and encode each value
  for (final entry in data.entries) {
    final key = entry.key;
    final rawValue = entry.value;
    encodedData[key] = encodeValueForDB(rawValue);
  }

  // QuizzerLogger.logValue('Performing insert into $tableName with encoded data: ${encodedData.keys.join(', ')}');
  
  // Perform the actual database insertion with the encoded data
  final result = await db.insert(
    tableName,
    encodedData,
    conflictAlgorithm: conflictAlgorithm, // Pass the algorithm
  );
  
  return result;
}

/// Queries the database and returns a list of fully decoded rows.
///
/// Args:
///   tableName: The table to query.
///   db: The database instance.
///   columns: Optional list of columns to retrieve.
///   where: Optional WHERE clause (e.g., 'id = ?').
///   whereArgs: Optional arguments for the WHERE clause.
///   orderBy: Optional ORDER BY clause.
///   limit: Optional LIMIT clause.
///
/// Returns:
///   A list of maps, where each map represents a row with decoded values.
///   Returns an empty list if no rows match.
Future<List<Map<String, dynamic>>> queryAndDecodeDatabase(
  String tableName,
  Database db,
  {
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit, // Corrected type back to int?
  }
) async {
  // QuizzerLogger.logValue('Querying table $tableName (where: $where, args: $whereArgs, limit: $limit)');
  final List<Map<String, dynamic>> rawResults = await db.query(
    tableName,
    columns: columns,
    where: where,
    whereArgs: whereArgs,
    orderBy: orderBy,
    limit: limit,
  );

  if (rawResults.isEmpty) {
    // QuizzerLogger.logValue('Query on $tableName returned no results.');
    return []; // Return empty list if no results
  }

  // QuizzerLogger.logValue('Decoding ${rawResults.length} rows from $tableName...');
  final List<Map<String, dynamic>> decodedResults = [];
  for (final rawRow in rawResults) {
    final Map<String, dynamic> decodedRow = {};
    for (final entry in rawRow.entries) {
      decodedRow[entry.key] = decodeValueFromDB(entry.value);
    }
    decodedResults.add(decodedRow);
  }

  // QuizzerLogger.logValue('Finished decoding query results from $tableName.');
  return decodedResults;
}

/// Updates rows in the specified table after encoding the values in the data map.
///
/// Args:
///   tableName: The name of the table to update.
///   data: A map where keys are column names and values are the raw Dart objects to update.
///   where: The WHERE clause to filter which rows to update (e.g., 'id = ?').
///   whereArgs: The arguments for the WHERE clause.
///   db: The database instance.
///   conflictAlgorithm: Optional conflict resolution algorithm.
///
/// Returns:
///   The number of rows affected.
///   Throws exceptions on database errors (Fail Fast).
Future<int> updateRawData(
  String tableName,
  Map<String, dynamic> data,
  String? where, // WHERE clause is required for updates usually, but make optional just in case?
  List<dynamic>? whereArgs,
  Database db,
  {ConflictAlgorithm? conflictAlgorithm}
) async {
  // QuizzerLogger.logValue('Encoding data for update on table: $tableName (where: $where, args: $whereArgs)');
  final Map<String, dynamic> encodedData = {};
  
  // Iterate through the input map and encode each value
  for (final entry in data.entries) {
    final key = entry.key;
    final rawValue = entry.value;
    encodedData[key] = encodeValueForDB(rawValue);
  }

  // QuizzerLogger.logValue('Performing update on $tableName with encoded data: ${encodedData.keys.join(', ')}');
  
  // Perform the actual database update with the encoded data
  final result = await db.update(
    tableName,
    encodedData,
    where: where,
    whereArgs: whereArgs,
    conflictAlgorithm: conflictAlgorithm,
  );
  
  // QuizzerLogger.logValue('Update on $tableName affected $result rows.');
  return result;
}
