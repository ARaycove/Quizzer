import 'dart:convert';
import 'package:sqflite/sqflite.dart'; // Added for Database type
import 'dart:io';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:package_info_plus/package_info_plus.dart'; // Import the plugin

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
// Callers must manually interpret integer fields intended as booleans.
dynamic decodeValueFromDB(dynamic dbValue) {
  if (dbValue == null || dbValue is int || dbValue is double || dbValue is bool) {
    return dbValue; // Return nulls, integers, doubles, and booleans directly
  } else if (dbValue is String) {
    // Trim whitespace before checking brackets/braces
    final trimmedValue = dbValue.trim();
    // More robust check for potential JSON: must start AND end with corresponding brackets/braces
    if ((trimmedValue.startsWith('[') && trimmedValue.endsWith(']')) ||
        (trimmedValue.startsWith('{') && trimmedValue.endsWith('}'))) {
      // Attempt to decode potential JSON strings
      // json.decode will throw FormatException on invalid JSON, aligning with Fail Fast.
      return json.decode(trimmedValue);
    } else {
      // Assume it's a plain string if it doesn't meet the stricter JSON structural check
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
  dynamic db, // Accept either Database or Transaction
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
  dynamic result = 0;

  // Perform the actual database insertion with the encoded data
  result = await db.insert(
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
///   customQuery: Optional custom query string.
///
/// Returns:
///   A list of maps, where each map represents a row with decoded values.
///   Returns an empty list if no rows match.
Future<List<Map<String, dynamic>>> queryAndDecodeDatabase(
  String tableName,
  dynamic db, // Accept either Database or Transaction
  {
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    String? customQuery, // Added customQuery parameter
  }
) async {
  // QuizzerLogger.logValue('Querying table $tableName (where: $where, args: $whereArgs, limit: $limit, customQuery: $customQuery)');
  List<Map<String, dynamic>> rawResults;

  if (customQuery != null && customQuery.isNotEmpty) {
    // QuizzerLogger.logValue('Executing custom query: $customQuery with args: $whereArgs');
    rawResults = await db.rawQuery(customQuery, whereArgs);
  } else {
    // QuizzerLogger.logValue('Executing standard query on table: $tableName');
    rawResults = await db.query(
      tableName,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

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
  dynamic db, // Accept either Database or Transaction
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

  // Perform the actual database update with the encoded data
  final result = await db.update(
    tableName,
    encodedData,
    where: where,
    whereArgs: whereArgs,
    conflictAlgorithm: conflictAlgorithm,
  );
  
  return result;
}

/// Upserts data into the specified table using SQLite's INSERT OR REPLACE.
/// This is a true upsert operation that handles conflicts at the database level.
///
/// Args:
///   tableName: The name of the table to upsert into.
///   data: A map where keys are column names and values are the raw Dart objects to upsert.
///   db: The database instance.
///   conflictAlgorithm: Optional conflict resolution algorithm (defaults to REPLACE for true upsert).
///
/// Returns:
///   The row ID of the inserted/updated row.
///   Throws exceptions on database errors (Fail Fast).
Future<int> upsertRawData(
  String tableName,
  Map<String, dynamic> data,
  dynamic db, // Accept either Database or Transaction
  {ConflictAlgorithm? conflictAlgorithm}
) async {
  // Encode the data for database storage
  final Map<String, dynamic> encodedData = {};
  for (final entry in data.entries) {
    final key = entry.key;
    final rawValue = entry.value;
    encodedData[key] = encodeValueForDB(rawValue);
  }

  // Use REPLACE conflict algorithm for true upsert behavior
  final ConflictAlgorithm algorithm = conflictAlgorithm ?? ConflictAlgorithm.replace;
  
  // Perform the upsert operation
  final result = await db.insert(
    tableName,
    encodedData,
    conflictAlgorithm: algorithm,
  );
  
  return result;
}

Future<String> getDeviceInfo() async {
  String deviceData = "";
  
  try {
    // Use Dart's built-in Platform class to get basic platform info
    // without relying on Flutter-specific packages
    if (Platform.isAndroid) {
      deviceData = 'Android ${Platform.operatingSystemVersion}';
    } else if (Platform.isIOS) {
      deviceData = 'iOS ${Platform.operatingSystemVersion}';
    } else if (Platform.isWindows) {
      deviceData = 'Windows ${Platform.operatingSystemVersion}';
    } else if (Platform.isMacOS) {
      deviceData = 'macOS ${Platform.operatingSystemVersion}';
    } else if (Platform.isLinux) {
      deviceData = 'Linux ${Platform.operatingSystemVersion}';
    } else {
      deviceData = 'Unknown device';
    }
    
    // Add some additional system info that's available from dart:io
    deviceData += ' (${Platform.localHostname})';
  } catch (e) {
    // Fallback if any error occurs
    QuizzerLogger.logWarning('Error getting device info: $e');
    deviceData = 'Unknown device';
  }
  
  return deviceData;
}

Future<String> getUserIpAddress() async {
  QuizzerLogger.logMessage('Attempting to get IP address with multiple fallback methods');
  
  // Method 1: Try multiple external IP services with fallbacks
  final List<String> ipServices = [
    'https://api.ipify.org',
    'https://httpbin.org/ip',
    'https://icanhazip.com',
    'https://ident.me',
    'https://ifconfig.me/ip',
  ];
  
  for (final serviceUrl in ipServices) {
    try {
      QuizzerLogger.logMessage('Trying IP service: $serviceUrl');
      
      // Create a custom HttpClient with certificate bypass
      final httpClient = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;
      
      final request = await httpClient.getUrl(Uri.parse(serviceUrl));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      
      if (response.statusCode == 200) {
        // Clean the response - most services return just the IP
        final ip = responseBody.trim();
        
        // Validate it looks like an IPv4 address
        if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(ip)) {
          QuizzerLogger.logSuccess('Successfully retrieved IP address from $serviceUrl: $ip');
          return ip;
        } else {
          QuizzerLogger.logWarning('Invalid IP format from $serviceUrl: $ip');
        }
      } else {
        QuizzerLogger.logWarning('Failed to get IP from $serviceUrl, status code: ${response.statusCode}');
      }
    } catch (e) {
      QuizzerLogger.logWarning('Error getting IP from $serviceUrl: $e');
      continue; // Try next service
    }
  }
  
  // Method 2: Try the original dnsleaktest.com method as last resort
  try {
    QuizzerLogger.logMessage('Trying dnsleaktest.com as last resort');
    
    final httpClient = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;
    
    final request = await httpClient.getUrl(Uri.parse('https://www.dnsleaktest.com/'));
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    if (response.statusCode == 200) {
      // Extract IP from the welcome message
      final ipRegex = RegExp(r'Hello (\d+\.\d+\.\d+\.\d+)');
      final match = ipRegex.firstMatch(responseBody);
      
      if (match != null) {
        final ip = match.group(1)!;
        QuizzerLogger.logSuccess('Successfully retrieved IP address from dnsleaktest.com: $ip');
        return ip;
      }
    }
  } catch (e) {
    QuizzerLogger.logWarning('Error getting IP from dnsleaktest.com: $e');
  }
  
  // All methods failed, return offline indicator
  QuizzerLogger.logWarning('All IP address methods failed, returning offline indicator');
  return "offline_login";
}

// --- Function to get App Version ---
Future<String> getAppVersionInfo() async {
  // This function now assumes package_info_plus is installed and configured.
  // If PackageInfo.fromPlatform() fails (e.g. plugin not setup or platform issue),
  // it will throw an exception, adhering to fail-fast.
  QuizzerLogger.logMessage('Fetching app version using package_info_plus.');
  
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  String version = packageInfo.version;      // e.g., "1.0.0"
  String buildNumber = packageInfo.buildNumber; // e.g., "1"
  
  final String appVersionString = '$version+$buildNumber';
  QuizzerLogger.logSuccess('App version fetched: $appVersionString');
  return appVersionString;
}

/// A generic function to verify the schema of any table.
///
/// Args:
///   db: The database instance (e.g., Sqflite Database or Transaction object).
///   tableName: The name of the table to verify.
///   expectedColumns: A list of maps, where each map defines a column:
///                    `[{'name': 'column_name', 'type': 'SQL_DEFINITION'}, ...]`.
///                    (e.g., 'TEXT NOT NULL', 'INTEGER DEFAULT 0', etc.).
///   primaryKeyColumns: A list of column names that form the primary key. This is used to
///                      construct a table-level 'PRIMARY KEY (colA, colB)' constraint.
///                      Pass an empty list (`[]`) if there is no table-level primary key.
///   indicesToCreate: A list of full SQL CREATE INDEX statements to ensure existence.
Future<void> verifyTable({
  required dynamic db,
  required String tableName,
  required List<Map<String, String>> expectedColumns,
  required List<String> primaryKeyColumns,
  List<String> indicesToCreate = const [],
}) async {
  try {
    // Collect expected column names for comparison
    final Map<String, String> expectedColumnDefinitions = {
      for (var col in expectedColumns) col['name']!: col['type']!,
    };
    final Set<String> expectedColumnNames = expectedColumnDefinitions.keys.toSet();

    // Check if the table exists
    final List<Map<String, dynamic>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );

    bool tableExists = tables.isNotEmpty;
    List<Map<String, dynamic>>? recordsToMigrate;

    // --- Table Rebuild Check (Triggered by column removal) ---
    if (tableExists) {
      final List<Map<String, dynamic>> currentColumns = await db.rawQuery(
        "PRAGMA table_info($tableName)",
      );
      final Set<String> currentColumnNames = currentColumns
          .map((column) => column['name'] as String)
          .toSet();

      final Set<String> columnsToRemove = currentColumnNames.difference(expectedColumnNames);

      if (columnsToRemove.isNotEmpty) {
        // Backup data and flag for recreation if unexpected columns are found
        try {
          // Only query for columns that are still expected to exist
          final String columnsToQuery = expectedColumnNames.intersection(currentColumnNames).join(', ');
          
          if (columnsToQuery.isNotEmpty) {
            recordsToMigrate = await db.rawQuery('SELECT $columnsToQuery FROM $tableName');
          }
        } catch (_) {
          recordsToMigrate = null;
        }

        await db.execute('DROP TABLE IF EXISTS $tableName');
        tableExists = false;
      }
    }

    if (!tableExists) {
      // Create the table
      String createTableSQL = 'CREATE TABLE $tableName(\n';
      List<String> columnDefinitions = expectedColumns
          .map((col) => '  ${col['name']} ${col['type']}')
          .toList();

      // Add table-level primary key constraint
      if (primaryKeyColumns.isNotEmpty) {
        final String compositeKeySql = 'PRIMARY KEY (${primaryKeyColumns.join(', ')})';
        columnDefinitions.add('  $compositeKeySql');
      }

      createTableSQL += columnDefinitions.join(',\n');
      createTableSQL += '\n)';

      await db.execute(createTableSQL);
    } else {
      // Table exists and no rebuild was triggered, only check for column additions
      final List<Map<String, dynamic>> currentColumns = await db.rawQuery(
        "PRAGMA table_info($tableName)",
      );

      final Set<String> currentColumnNames = currentColumns
          .map((column) => column['name'] as String)
          .toSet();

      final Set<String> columnsToAdd = expectedColumnNames.difference(currentColumnNames);

      // Add missing columns
      for (String columnName in columnsToAdd) {
        final columnDef = expectedColumnDefinitions[columnName]!;
        await db.execute('ALTER TABLE $tableName ADD COLUMN $columnName $columnDef');
      }
    }

    // Re-insert backed-up data if a migration (rebuild) occurred
    if (recordsToMigrate != null && recordsToMigrate.isNotEmpty) {
      final List<String> validColumnNames = expectedColumns
          .map((col) => col['name']!)
          .toList();

      for (final record in recordsToMigrate) {
        final Map<String, dynamic> recordToInsert = Map<String, dynamic>.from(record);
        
        // Remove keys that are not valid columns (this is defensive, as the query above should filter)
        recordToInsert.removeWhere((key, value) => !validColumnNames.contains(key));
        
        await db.insert(tableName, recordToInsert);
      }
    }

    // Ensure indices exist
    for (String indexSql in indicesToCreate) {
      await db.execute(indexSql);
    }

  } catch (e) {
    rethrow;
  }
}


/// A generic function to add a record to any table.
///
/// Args:
///   db: The database instance (e.g., Sqflite Database or Transaction object).
///   tableName: The name of the table to insert into.
///   data: The map of key-value pairs representing the record to insert.
///   expectedColumns: The schema definition (used here for data sanitization).
///   primaryKeyColumns: List of primary key columns (retained for consistent signature).
///
/// Returns:
///   A Future resolving to the row ID of the last row inserted (typically INTEGER).
Future<int> addRecord({
  required dynamic db,
  required String tableName,
  required Map<String, dynamic> data,
  required List<Map<String, String>> expectedColumns,
  required List<String> primaryKeyColumns,
}) async {
  final Set<String> validColumnNames = expectedColumns
      .map((col) => col['name']!)
      .toSet();

  final Map<String, dynamic> recordToInsert = encodeValueForDB(
    Map<String, dynamic>.from(data)
    ..removeWhere((key, value) => !validColumnNames.contains(key)));

  try {
    return await insertRawData(tableName, recordToInsert, db);
  } catch (e) {
    rethrow;
  }
}