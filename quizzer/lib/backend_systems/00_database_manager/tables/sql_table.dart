import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart' as table_helper;
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/09_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite/sqflite.dart';
// import 'package:quizzer/backend_systems/00_helper_utils/utils.dart' as utils;

abstract class SqlTable {
  // FIXME need some way to properly fetch and store supabase schema
  // static final SqlTable _instance = SqlTable._internal();
  // factory SqlTable() => _instance;
  // SqlTable._internal();
  // ==================================================
  // ----- Constants -----
  // ==================================================

  /// isTransient determines whether the SqlTable will be stored locally, or is strictly here to collect and transmit data
  /// Quizzer is designed to run locally without a connection, so if the application is offline, records may accumulate in a transient table until
  /// a connection is restored, at which time the OutboundSync mechanism can sync and remove the records from local device
  bool get isTransient;

  bool get requiresInboundSync;
  dynamic get additionalFiltersForInboundSync;
  bool get useLastLoginForInboundSync;
  // ==================================================
  // ----- Schema Definition Validation -----
  // ==================================================
  /// Define the name of the table given in the SQL Database
  String get tableName;
  /// Define the primary key constraints as a list of keys
  /// If single primary key then input only one item to List<String>
  /// If composite key input multiple items to List<String>
  List<String> get primaryKeyConstraints;
  /// Define the fields and types for this table
  /// Use the following pattern:
  ///   [
  ///     {'name': 'field_name',         'type': 'DATETYPE CONSTRAINTS'},
  ///     {'name': 'field_name_2',       'type': 'DATETYPE CONSTRAINTS'},
  ///   ]
  List<Map<String, String>> get expectedColumns;

  /// Define the Supabase schema for this table (columns that exist in Supabase)
  /// Use the same format as expectedColumns:
  ///   [
  ///     {'name': 'field_name',         'type': 'DATETYPE CONSTRAINTS'},
  ///     {'name': 'field_name_2',       'type': 'DATETYPE CONSTRAINTS'},
  ///   ]
  List<Map<String, String>> get supabaseColumns => []; //Temp assign a blank list, all tables must be initialized with "verifyTable" before use
  set supabaseColumns(List<Map<String, String>> value) {
    supabaseColumns = value;
  }

  /// Need only define _expectedColumns, _primaryKeyConstraints, and _table_name, helper function is universal for all tables
  Future<void> verifyTable(db) async{
    // First verify the Table exists and is set accordingly
    await table_helper.verifyTable(db: db, tableName: tableName, expectedColumns: expectedColumns, primaryKeyColumns: primaryKeyConstraints);
  }

  // Future<void> _setSupabaseSchema() async{
  //   supabaseColumns = await utils.getSupabaseSchema(tableName);
  // }

  // ==================================================
  // ----- CRUD operations -----
  // ==================================================
  /// Private helper, adds a new record after finishing and validating it.
  /// Returns the row ID of the newly inserted record.
  /// Throws an exception if validation fails.
  /// If a database instance is provided, it will be used; otherwise, a new database access will be requested.
  Future<int> _addRecord(Map<String, dynamic> dataToInsert, {dynamic db}) async {
    // First finish the record (add any required fields like timestamps)
    Map<String, dynamic> finishedRecord = await finishRecord(dataToInsert);
    
    // Then validate the complete record
    final bool isValid = await validateRecord(finishedRecord);
    if (!isValid) {
      throw Exception("Record failed table-specific validation before add.");
    }

    bool shouldReleaseDb = false;
    dynamic database = db;
    
    // If no db was passed, request database access
    if (database == null) {
      database = await getDatabaseMonitor().requestDatabaseAccess();
      shouldReleaseDb = true;
    }

    int i = await table_helper.insertRawData(
      tableName,
      finishedRecord,
      database,
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
    
    if (shouldReleaseDb) {
      getDatabaseMonitor().releaseDatabaseAccess();
    }
    
    signalOutboundSyncNeeded();
    return i;
  }

  /// Deletes records based on the provided map of field names and values.
  /// The map is used to construct the WHERE clause for deletion.
  /// Returns the number of rows affected (0 if no records matched).
  Future<int> deleteRecord(Map<String, dynamic> whereConditions, {dynamic db}) async {
    if (whereConditions.isEmpty) {
      throw ArgumentError('The whereConditions map cannot be empty for deleteRecord.');
    }
    
    final List<String> conditionKeys = whereConditions.keys.toList();
    final String whereClause = conditionKeys.map((key) => '$key = ?').join(' AND ');
    final List<dynamic> whereArgs = conditionKeys.map((key) => whereConditions[key]).toList();

    bool shouldReleaseDb = false;
    dynamic database = db;
    
    if (database == null) {
      database = await getDatabaseMonitor().requestDatabaseAccess();
      shouldReleaseDb = true;
    }

    try {
      int i = await database.delete(
        tableName,
        where: whereClause,
        whereArgs: whereArgs,
      );
      return i;
    } finally {
      if (shouldReleaseDb) {
        getDatabaseMonitor().releaseDatabaseAccess();
      }
    }
  }

  /// Private helper, edits an existing record based on primary key constraints.
  /// Returns the number of rows affected.
  /// If a database instance is provided, it will be used; otherwise, a new database access will be requested.
  /// Throws an exception if database access cannot be acquired.
  Future<int> _editRecord(Map<String, dynamic> dataToEdit, {dynamic db}) async {
    // Extract primary keys for WHERE clause
    final String whereClause = primaryKeyConstraints.map((key) => '$key = ?').join(' AND ');
    final List<dynamic> whereArgs = primaryKeyConstraints.map((key) => dataToEdit[key]).toList();
    
    // Remove primary keys from update data (they're in WHERE clause)
    final Map<String, dynamic> updateData = Map<String, dynamic>.from(dataToEdit)
      ..removeWhere((key, value) => primaryKeyConstraints.contains(key));
    
    bool shouldReleaseDb = false;
    dynamic database = db;
    
    // If no db was passed, request database access
    if (database == null) {
      database = await getDatabaseMonitor().requestDatabaseAccess();
      shouldReleaseDb = true;
    }

    if (database == null) {
      throw Exception('Failed to acquire database access for editRecord.');
    }

    int i = await table_helper.updateRawData(
      tableName,
      updateData,
      whereClause,
      whereArgs,
      database,
    );
    
    if (shouldReleaseDb) {
      getDatabaseMonitor().releaseDatabaseAccess();
    }
    
    signalOutboundSyncNeeded();
    return i;
  }

  /// The sole public entry point for saving data, handles validation, INSERT, or UPDATE.
  Future<int> upsertRecord(Map<String, dynamic> dataToUpsert, {dynamic db}) async {
    QuizzerLogger.logMessage("Upserting Record, $dataToUpsert");
    
    // Clean/reshape first
    final Map<String, dynamic> cleanedRecord = await _cleanReshapeRecordLocal(dataToUpsert);
    
    // Check if the record already exists using its primary key
    final String whereClause = primaryKeyConstraints.map((key) => '$key = ?').join(' AND ');
    final List<dynamic> whereArgs = primaryKeyConstraints.map((key) => cleanedRecord[key]).toList();
    
    bool shouldReleaseDb = false;
    dynamic database = db;
    
    // If no db was passed, request database access
    if (database == null) {
      database = await getDatabaseMonitor().requestDatabaseAccess();
      shouldReleaseDb = true;
    }
    
    if (database == null) {
      throw Exception('Failed to acquire database access for upsertRecord.');
    }

    try {
      // Check existence
      List<Map<String, dynamic>> existingRecords = await database.query(
        tableName,
        columns: ['COUNT(*)'],
        where: whereClause,
        whereArgs: whereArgs,
      );

      int count = Sqflite.firstIntValue(existingRecords) ?? 0;

      if (count > 0) {
        // Record exists, UPDATE - only update provided fields, no full validation
        return await _editRecord(cleanedRecord, db: database);
      } else {
        // Record does not exist, INSERT - do full finish + validation flow
        return await _addRecord(cleanedRecord, db: database);
      }
    } finally {
      // Only release if we requested the database access ourselves
      if (shouldReleaseDb) {
        getDatabaseMonitor().releaseDatabaseAccess();
      }
    }
  }

  Future<List<Map<String, dynamic>>> getRecord(String sqlQuery, {dynamic db}) async {
    bool shouldReleaseDb = false;
    dynamic database = db;
    
    if (database == null) {
      database = await getDatabaseMonitor().requestDatabaseAccess();
      shouldReleaseDb = true;
    }
    
    try {
      List<Map<String, dynamic>> results = await table_helper.queryAndDecodeDatabase(
        tableName,
        database,
        customQuery: sqlQuery,
      );
      return results;
    } finally {
      if (shouldReleaseDb) {
        getDatabaseMonitor().releaseDatabaseAccess();
      }
    }
  }

  // ==================================================
  // ----- Sync Operations -----
  // ==================================================
  /// Inserts or updates multiple records in a batch, with error handling for chunk size limits.
  Future<void> batchUpsertRecords({
    required List<Map<String, dynamic>> records,
    int initialChunkSize = 500,
    dynamic db
  }) async {
    if (records.isEmpty) return;
    bool isTransaction = true;
    if (db == null) {
      db = await getDatabaseMonitor().requestDatabaseAccess();
      isTransaction = false;
    }

    try {
      // Get valid local column names
      final validColumnNames = expectedColumns.map((col) => col['name']!).toSet();
      
      // Filter out server-only fields that don't exist in local schema
      final List<Map<String, dynamic>> processedRecords = [];
      
      for (final record in records) {
        final Map<String, dynamic> processedRecord = <String, dynamic>{};
        
        // Only include columns that exist locally
        for (final colName in validColumnNames) {
          if (record.containsKey(colName)) {
            processedRecord[colName] = record[colName];
          }
        }
        
        // Set sync flags for server-sourced data
        if (validColumnNames.contains('has_been_synced')) {
          processedRecord['has_been_synced'] = 1;
        }
        if (validColumnNames.contains('edits_are_synced')) {
          processedRecord['edits_are_synced'] = 1;
        }
        
        processedRecords.add(processedRecord);
      }

      if (processedRecords.isEmpty) return;
      
      // Use existing conflictKey approach but handle composite keys properly
      final conflictKey = primaryKeyConstraints.first; // Keep existing assumption
      
      int currentChunkSize = initialChunkSize;
      int i = 0;
      
      while (i < processedRecords.length) {
        final endIndex = (i + currentChunkSize > processedRecords.length) ? processedRecords.length : i + currentChunkSize;
        final batch = processedRecords.sublist(i, endIndex);
        
        try {
          // Attempt the batch upsert with current chunk
          await _insertOrUpdateBatch(
            records: batch,
            db: db,
            conflictKey: conflictKey,
          );
          i += currentChunkSize;
          if (currentChunkSize < initialChunkSize) {
            currentChunkSize = initialChunkSize;
          }
        } on DatabaseException catch (e) {
          // Handle SQL limits by reducing chunk size
          if (e.toString().contains('variable number') || e.isDatabaseClosedError() || e.toString().contains('2067')) {
            if (currentChunkSize > 1) {
              currentChunkSize = currentChunkSize ~/ 2;
              continue;
            } else {
              rethrow;
            }
          } else if (e.toString().contains('UNIQUE constraint failed')) {
            // Fallback to individual upserts for composite key issues
            for (final record in batch) {
              await table_helper.upsertRawData(tableName, record, db);
            }
            i += currentChunkSize;
          } else {
            rethrow;
          }
        } catch (e) {
          // For any other error, fall back to individual upserts
          for (final record in batch) {
            try {
              await table_helper.upsertRawData(tableName, record, db);
            } catch (_) {
              // Skip individual record if it fails
            }
          }
          i += currentChunkSize;
        }
      }
    } finally {
      if (!isTransaction) {
        getDatabaseMonitor().releaseDatabaseAccess();
      }
    }
  }

  /// Fetches all records from the table where either 'has_been_synced' or 'edits_are_synced' is 0.
  Future<List<Map<String, dynamic>>> getUnsyncedRecords() async {
    // Check if expectedColumns contains the sync field definitions and handle accordingly
    bool hasSyncFields = false;
    
    for (final column in expectedColumns) {
      if (column['name'] == 'has_been_synced' || column['name'] == 'edits_are_synced') {hasSyncFields = true;break;}
    }
    
    if (!hasSyncFields) {return [];}
    
    var db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access for getUnsyncedRecords.');
    }

    try {
      final List<Map<String, dynamic>> results = await db.query(
        tableName,
        where: 'has_been_synced = 0 OR edits_are_synced = 0',
      );
      
      return results;
    } finally {
      getDatabaseMonitor().releaseDatabaseAccess();
    }
  }

  /// Updates the synchronization flags for a specific record identified by its primary key(s).
  /// 
  /// The function automatically updates the `last_modified_timestamp` to the current
  /// UTC time whenever sync flags are changed, ensuring proper change tracking.
  /// 
  /// Parameters:
  /// - `primaryKeyConditions`: A map containing the primary key field names and values 
  ///   (e.g., {'question_id': 'uuid-123'}).
  /// - `hasBeenSynced`: Whether the record has been synchronized to the remote database (true = 1, false = 0).
  /// - `editsAreSynced`: Whether all local edits have been synchronized (true = 1, false = 0).
  Future<void> updateSyncFlags({
    required Map<String, dynamic> primaryKeyConditions,
    required bool hasBeenSynced,
    required bool editsAreSynced,
  }) async {
    var db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access for updateSyncFlags.');
    }

    try {
      final Map<String, dynamic> updates = {
        'has_been_synced': hasBeenSynced ? 1 : 0,
        'edits_are_synced': editsAreSynced ? 1 : 0,
        // Using a timestamp string from the table helper for consistency
        'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(), 
      };

      // 1. Construct WHERE clause and arguments from primaryKeyConditions map
      final List<String> conditionKeys = primaryKeyConditions.keys.toList();
      final String whereClause = conditionKeys.map((key) => '$key = ?').join(' AND ');
      final List<dynamic> whereArgs = conditionKeys.map((key) => primaryKeyConditions[key]).toList();

      // 2. Perform the update
      final int rowsAffected = await table_helper.updateRawData(
        tableName,
        updates,
        whereClause,
        whereArgs,
        db,
      );

      // Error handling (removed specific logger/warning as it's an abstract class)
      if (rowsAffected == 0) {
        // You can handle this in the concrete class, or just rethrow/return if no rows were affected.
        // For an abstract class, we just return silently if 0 rows were affected.
      }
      
    } catch (e) {
      rethrow;
    } finally {
      getDatabaseMonitor().releaseDatabaseAccess();
    }
  }

  // ==================================================
  // ----- Validation and Helper Logic For Records -----
  // ==================================================
  /// validateRecord is not meant to be called, DO NOT CALL THIS METHOD DIRECTLY
  Future<bool> validateRecord(Map<String, dynamic> dataToInsert);

  /// Private helper to add required information before upsert
  /// finishRecord is not meant to be called, DO NOT CALL THIS METHOD DIRECTLY
  Future<Map<String, dynamic>> finishRecord(Map<String, dynamic> dataToInsert) async{
    return dataToInsert;
  }


  /// Private helper to execute the raw SQL INSERT...ON CONFLICT statement
  /// Updated to filter out non-local columns
  /// Private helper to execute the raw SQL INSERT...ON CONFLICT statement
  /// Updated to filter out non-local columns and handle type conversions
  Future<void> _insertOrUpdateBatch({
    required List<Map<String, dynamic>> records,
    required dynamic db,
    required String conflictKey,
  }) async {
    if (records.isEmpty) return;
    
    // Only use columns that exist in local schema
    final validColumnNames = expectedColumns.map((col) => col['name']!).toSet();
    
    // Filter each record to only include valid columns and prepare values
    final filteredRecords = records.map((record) {
      final Map<String, dynamic> preparedRecord = {};
      
      for (final entry in record.entries) {
        final key = entry.key;
        final value = entry.value;
        
        if (validColumnNames.contains(key)) {
          preparedRecord[key] = _prepareValueForSql(value);
        }
      }
      
      return preparedRecord;
    }).toList();
    
    // Use filtered records for column extraction
    final columns = filteredRecords.first.keys
        .where((key) => validColumnNames.contains(key))
        .toList();
    
    if (columns.isEmpty) {
      QuizzerLogger.logWarning('No valid columns found for batch upsert to table: $tableName');
      return;
    }
    
    final values = <dynamic>[];
    final valuePlaceholders = filteredRecords.map((r) {
      for (final col in columns) {
        values.add(r[col]);
      }
      return '(${List.filled(columns.length, '?').join(',')})';
    }).join(', ');
    
    // Handle composite primary keys - use all primary key constraints
    final conflictClause = primaryKeyConstraints.join(', ');
    
    // For update, exclude all primary key columns
    final updateSet = columns
        .where((c) => !primaryKeyConstraints.contains(c))
        .map((c) => '$c=excluded.$c')
        .join(', ');
    
    final sql = 'INSERT INTO $tableName (${columns.join(',')}) '
                'VALUES $valuePlaceholders '
                'ON CONFLICT($conflictClause) DO UPDATE SET $updateSet;';
    
    try {
      await db.rawInsert(sql, values);
      QuizzerLogger.logMessage('Batch upsert completed for ${records.length} records in table: $tableName');
    } catch (e) {
      QuizzerLogger.logError('Failed batch upsert for table $tableName: $e');
      rethrow;
    }
  }

  // Helper function to prepare values for SQLite
  dynamic _prepareValueForSql(dynamic value) {
    if (value == null) return null;
    
    // Convert boolean to integer for SQLite
    if (value is bool) {return value ? 1 : 0;}
    
    // Convert DateTime to ISO string
    if (value is DateTime) {return value.toUtc().toIso8601String();}
    
    // Keep other types as-is
    return value;
  }

  /// Cleans and reshapes a record by removing any fields that don't exist in the local schema.
  /// This ensures that server-only fields or extra fields are filtered out before database operations.
  Future<Map<String, dynamic>> _cleanReshapeRecordLocal(Map<String, dynamic> record) async {
    QuizzerLogger.logMessage("Cleaning record for upsert $tableName");
    
    // Get all valid column names from expectedColumns
    final validColumnNames = expectedColumns.map((col) => col['name']!).toSet();
    
    // Create a new map with only valid columns
    final Map<String, dynamic> cleanedRecord = {};
    
    // Filter out any fields that aren't in validColumnNames
    for (final entry in record.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (validColumnNames.contains(key)) {
        cleanedRecord[key] = value;
      }
    }
    
    return cleanedRecord;
  }

  // /// Cleans and reshapes a record fetched from the local database to match the
  // /// Supabase table schema before synchronization.
  // /// 
  // /// This function:
  // /// 1. Filters out any columns in the local record that don't exist in the
  // ///    Supabase schema for this table
  // /// 2. Logs each column that is dropped for debugging purposes
  // /// 3. Returns a cleaned record with only valid Supabase columns
  // /// 
  // /// This ensures that during synchronization, we only send data that matches
  // /// the remote schema, preventing schema mismatch errors during sync operations.
  // /// 
  // /// Parameters:
  // /// - `record`: The raw record fetched from the local SQLite database
  // /// 
  // /// Returns:
  // /// A `Map<String, dynamic>` containing only columns that exist in the
  // /// Supabase schema for this table
  // Future<Map<String, dynamic>> _cleanReshapeRecordSupabase(Map<String, dynamic> record) async {
  //   if (supabaseColumns.isEmpty) {
  //     _setSupabaseSchema();
  //   }
  //   // If this is called while offline the program will crash, thus handling in the sync mechanism ensures it does not attempt to sync while offline.
  //   // Assert: Verify that supabaseColumns has been properly initialized before sync
  //   assert(
  //     supabaseColumns.isNotEmpty, 
  //     'Supabase schema for table "$tableName" is empty. Ensure verifyTable() was called to initialize the schema before syncing.'
  //   );
    
  //   final Map<String, dynamic> cleanedRecord = {};
  //   final Set<String> supabaseColumnNames = supabaseColumns.map((col) => col['name']!).toSet();
    
  //   // Assert: Verify we successfully extracted column names from the schema
  //   assert(
  //     supabaseColumnNames.isNotEmpty,
  //     'Failed to extract column names from Supabase schema for table "$tableName". Schema format may be incorrect.'
  //   );
    
  //   for (final entry in record.entries) {
  //     final String key = entry.key;
  //     final dynamic value = entry.value;
      
  //     if (supabaseColumnNames.contains(key)) {
  //       cleanedRecord[key] = value;
  //     } else {
  //       QuizzerLogger.logMessage('Dropping column "$key" from table "$tableName" during Supabase sync: Column does not exist in remote schema');
  //     }
  //   }
    
  //   // Assert: Verify the cleaning process preserved at least the primary key constraints
  //   // (Note: This assert may need adjustment for tables without explicit primary keys)
  //   if (primaryKeyConstraints.isNotEmpty) {
  //     for (final primaryKey in primaryKeyConstraints) {
  //       assert(
  //         cleanedRecord.containsKey(primaryKey) || !record.containsKey(primaryKey),
  //         'Primary key constraint "$primaryKey" was unexpectedly dropped from table "$tableName". '
  //         'This indicates a mismatch between local and Supabase schemas that requires investigation.'
  //       );
  //     }
  //   }
    
  //   return cleanedRecord;
  // }
}