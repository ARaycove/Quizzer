import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/09_switch_board/switch_board.dart'; // Import SwitchBoard
import 'package:quizzer/backend_systems/09_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'dart:io'; // Import for InternetAddress lookup
import 'package:supabase/supabase.dart'; // Import for PostgrestException & SupabaseClient
import 'package:quizzer/backend_systems/00_helper_utils/utils.dart' as utils;
import 'package:quizzer/backend_systems/00_database_manager/tables/initialization_table_verification.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/sql_table.dart';
// ==========================================
// Outbound Sync Worker
// ==========================================
/// Pushes local data changes (marked for sync) to the cloud backend.
class OutboundSyncWorker {
  // --- Singleton Setup ---
  static final OutboundSyncWorker _instance = OutboundSyncWorker._internal();
  factory OutboundSyncWorker() => _instance;
  OutboundSyncWorker._internal() {
    QuizzerLogger.logMessage('OutboundSyncWorker initialized.');
  }
  // --------------------

  // --- Worker State ---
  bool _isRunning = false;
  bool _syncNeeded = false;
  bool _inWaitingCycle = false;
  StreamSubscription? _signalSubscription;
  // --------------------

  // --- Dependencies ---
  final SwitchBoard _switchBoard = SwitchBoard();
  // --------------------

  // --- Control Methods ---
  /// Starts the worker loop.
  Future<void> start() async {
    QuizzerLogger.logMessage('Entering OutboundSyncWorker start()...');
    
    if (SessionManager().userId == null) {
      QuizzerLogger.logWarning('OutboundSyncWorker: Cannot start, no user logged in.');
      return;
    }
    
    _isRunning = true;
    
    // Start listening for sync signals
    _signalSubscription = _switchBoard.onOutboundSyncNeeded.listen((_) {
      _syncNeeded = true;
    });
    
    _runLoop();
    QuizzerLogger.logMessage('OutboundSyncWorker started.');
  }

  /// Stops the worker loop.
  Future<void> stop() async {
    QuizzerLogger.logMessage('Entering OutboundSyncWorker stop()...');

    if (!_isRunning) {
      QuizzerLogger.logMessage('OutboundSyncWorker: stop() called but worker is not running.');
      return; 
    }

    _isRunning = false;
    
    // Wait for current sync cycle to complete before returning
    QuizzerLogger.logMessage('OutboundSyncWorker: Waiting for current sync cycle to complete...');
    // Trigger it to cycle at least one more time, just in case it's waiting for a signal
    _inWaitingCycle = false; // Force the worker to leave the waiting loop
    signalOutboundSyncNeeded();
    await _switchBoard.onOutboundSyncCycleComplete.first;
    QuizzerLogger.logMessage('OutboundSyncWorker: Current sync cycle completed.');
    
    await _signalSubscription?.cancel();
    QuizzerLogger.logMessage('OutboundSyncWorker stopped.');
  }
  // ----------------------
  Future<void> _doWaitingcycle() async {
    _inWaitingCycle = true;
    await Future.delayed(const Duration(seconds: 30));
    _inWaitingCycle = false;
  }


  // --- Main Loop ---
  Future<void> _runLoop() async {
    QuizzerLogger.logMessage('Entering OutboundSyncWorker _runLoop()...');
    
    while (_isRunning) {
      // Check connectivity first
      final bool isConnected = await utils.checkConnectivity();
      if (!isConnected) {
        QuizzerLogger.logMessage('OutboundSyncWorker: No network connectivity, waiting 5 minutes before next attempt...');
        _inWaitingCycle = true;
        while (_inWaitingCycle) {
          await Future.delayed(const Duration(minutes: 5));
          _inWaitingCycle = false;
        }
        continue;
      }
      
      // Run outbound sync
      QuizzerLogger.logMessage('OutboundSyncWorker: Running outbound sync...');
      await _performSync();
      QuizzerLogger.logMessage('OutboundSyncWorker: Outbound sync completed.');
      
      // Signal that the sync cycle is complete
      signalOutboundSyncCycleComplete();
      QuizzerLogger.logMessage('OutboundSyncWorker: Sync cycle complete signal sent.');
      
      // Add cooldown period to prevent infinite loops from self-signaling
      QuizzerLogger.logMessage('OutboundSyncWorker: Sync completed, entering 30-second cooldown...');
      // FIXME wait logic interferes with prompt shutting down of the worker on logout
      await _doWaitingcycle(); // Don't care if this returns, just trigger the boolean to true, and flip back to false after 30 seconds      
      
      // Check if sync is needed after cooldown
      if (_syncNeeded) {
        QuizzerLogger.logMessage('OutboundSyncWorker: Sync needed after cooldown, continuing to next cycle.');
        _syncNeeded = false;
      } else {
        // Wait for signal that another cycle is needed
        QuizzerLogger.logMessage('OutboundSyncWorker: Waiting for sync signal...');
        await _switchBoard.onOutboundSyncNeeded.first;
        QuizzerLogger.logMessage('OutboundSyncWorker: Woke up by sync signal.');
      }
    }
    QuizzerLogger.logMessage('OutboundSyncWorker loop finished.');
    signalOutboundSyncCycleComplete();
  }
  // -----------------

  // --- Core Sync Logic (Refactored) ---
  /// The core synchronization logic using the generic sync function
  Future<void> _performSync() async {
    QuizzerLogger.logMessage('OutboundSyncWorker: Starting sync cycle.');

    // 1. Check connectivity
    final bool isConnected = await utils.checkConnectivity();
    if (!isConnected) {
      QuizzerLogger.logMessage('OutboundSyncWorker: No network connectivity detected, skipping sync cycle.');
      return;
    }

    // Sync all tables using the generic function
    for (final table in InitializationTableVerification.allTables) {
      try {
        await _syncTable(table);
      } on AssertionError catch (e) {
        // Check if this is specifically a schema initialization issue
        final bool isSchemaError = table.supabaseColumns.isEmpty;
        
        if (isSchemaError) {
          // Schema initialization error - this could be due to no connection during init
          // or spotty connection. Log as warning and skip this table, don't crash.
          QuizzerLogger.logMessage('Table ${table.tableName}: Supabase schema not initialized, skipping sync for this cycle.');
          QuizzerLogger.logMessage('This may be due to network issues during schema fetch.');
          // Don't crash - just skip this table for now
        } else {
          // Any other AssertionError is a programming error - crash fast
          QuizzerLogger.logError('FATAL: Assertion failed in table ${table.tableName}: $e');
          rethrow; // This IS a programming error - crash
        }
      } on SocketException catch (e) {
        // Network connectivity lost after initial check
        QuizzerLogger.logMessage('Lost network connectivity during sync of ${table.tableName}: $e');
        // Break the entire sync cycle, not just this table
        break;
      } on HttpException catch (e) {
        // HTTP errors from Supabase
        QuizzerLogger.logMessage('HTTP error syncing ${table.tableName}: $e');
        // Continue with next table
      } on Exception catch (e) {
        // Check if it's a timeout by string matching
        if (e.toString().contains('timeout') || 
            e.toString().contains('timed out')) {
          QuizzerLogger.logMessage('Timeout syncing ${table.tableName}: $e');
        } else {
          // Handle other runtime exceptions
          QuizzerLogger.logError('Failed to sync table ${table.tableName}: $e');
        }
        // Continue with other tables
      } catch (e, s) {
        // Any other Error types (not Exception) are programming errors - crash
        QuizzerLogger.logError('FATAL: Critical programming error syncing table ${table.tableName}: $e\nStack trace: $s');
        rethrow;
      }
    }

    QuizzerLogger.logMessage('All outbound sync functions completed.');
  }
  // ================================================================================
  // ----- Generic Sync Table Function -----
  // ================================================================================
  // A third type of table exists solely to sync data inbound for local use we list these off below, and skip them since they don't use
  // the outbound sync
  List<String> tableToSkip = [
    'ml_models',
    'media_sync_status'
  ];

  /// Generic function to sync any table implementing SqlTable
  /// Handles both transient (sync-and-delete) and persistent (sync-and-keep) tables
  Future<void> _syncTable(SqlTable table) async {
    try {
      if (tableToSkip.contains(table.tableName)) {return;}
      QuizzerLogger.logMessage('Starting sync for table: ${table.tableName}');
      
      // Fetch unsynced records
      final List<Map<String, dynamic>> unsyncedRecords = await table.getUnsyncedRecords();
      if (unsyncedRecords.isEmpty) {
        QuizzerLogger.logMessage('No unsynced records for table: ${table.tableName}');
        return;
      }

      QuizzerLogger.logMessage('Found ${unsyncedRecords.length} unsynced records for ${table.tableName}');

      // Process records based on table type (transient vs persistent)
      if (table.isTransient) {
        await _syncTransientTable(table, unsyncedRecords);
      } else {
        await _syncPersistentTable(table, unsyncedRecords);
      }

      QuizzerLogger.logSuccess('Completed sync for table: ${table.tableName}');
    } catch (e) {
      QuizzerLogger.logError('_syncTable for ${table.tableName}: Error - $e');
      rethrow;
    }
  }

  /// Sync transient tables (sync-and-delete workflow)
  Future<void> _syncTransientTable(SqlTable table, List<Map<String, dynamic>> unsyncedRecords) async {
    final List<String> successfullySyncedIds = [];

    for (final record in unsyncedRecords) {
      try {
        // Prepare record for sync (remove local-only fields)
        final Map<String, dynamic> cleanRecord = _prepareRecordForSync(record, table.tableName);
        
        // Push to Supabase
        final bool pushSuccess = await pushRecordToSupabase(table.tableName, cleanRecord);
        
        if (pushSuccess) {
          // For transient tables, delete the successfully synced record
          final Map<String, dynamic> deleteConditions = _extractPrimaryKeyConditions(table, record);
          await table.deleteRecord(deleteConditions);
          successfullySyncedIds.add(_getRecordIdentifier(table, record));
        } else {
          QuizzerLogger.logWarning('Push FAILED for ${table.tableName} record: ${_getRecordIdentifier(table, record)}');
        }
      } on PostgrestException catch (e) {
        // Check if this is a duplicate key error (record already exists in Supabase)
        if (e.code == '23505') {
          // For transient tables, treat duplicate key as success - record already exists in cloud
          QuizzerLogger.logMessage('Record already exists in Supabase for ${table.tableName}, deleting local copy');
          
          // Delete the local record since it's already in Supabase
          final Map<String, dynamic> deleteConditions = _extractPrimaryKeyConditions(table, record);
          await table.deleteRecord(deleteConditions);
          successfullySyncedIds.add(_getRecordIdentifier(table, record));
        } else {
          // Re-throw other PostgrestExceptions
          rethrow;
        }
      } catch (e) {
        QuizzerLogger.logError('Error syncing transient record in ${table.tableName}: $e');
        // Continue with other records
      }
    }

    if (successfullySyncedIds.isNotEmpty) {
      QuizzerLogger.logSuccess('Successfully synced and deleted ${successfullySyncedIds.length} records from ${table.tableName}');
    }
  }

  /// Sync persistent tables (sync-and-update-flags workflow)
  Future<void> _syncPersistentTable(SqlTable table, List<Map<String, dynamic>> unsyncedRecords) async {
    for (final record in unsyncedRecords) {
      try {
        final Map<String, dynamic> primaryKeyConditions = _extractPrimaryKeyConditions(table, record);
        final int hasBeenSynced = record['has_been_synced'] as int? ?? 0;
        final int editsAreSynced = record['edits_are_synced'] as int? ?? 0;
        
        // Prepare record for sync
        final Map<String, dynamic> cleanRecord = _prepareRecordForSync(record, table.tableName);
        
        bool operationSuccess = false;
        
        if (hasBeenSynced == 0) {
          // New record
          if (table.tableName == 'question_answer_pairs') {
            // Special handling for question_answer_pairs table
            final String userRole = SessionManager().userRole;
            
            // Always push to new_review table
            bool reviewTableSuccess = await pushRecordToSupabase(
              'question_answer_pair_new_review', 
              cleanRecord
            );
            
            // For admin/contributor users, also push to main table
            if (userRole == 'admin' || userRole == 'contributor') {
              bool mainTableSuccess = await pushRecordToSupabase(
                'question_answer_pairs', 
                cleanRecord
              );
              operationSuccess = reviewTableSuccess && mainTableSuccess;
            } else {
              operationSuccess = reviewTableSuccess;
            }
          } else {
            // Standard new record push for other tables
            operationSuccess = await pushRecordToSupabase(table.tableName, cleanRecord);
          }
        } else if (editsAreSynced == 0) {
          // Existing record with edits
          if (table.tableName == 'question_answer_pairs') {
            // Special handling for question_answer_pairs table
            final String userRole = SessionManager().userRole;
            
            // Always push to edits_review table
            bool reviewTableSuccess = await pushRecordToSupabase(
              'question_answer_pair_edits_review', 
              cleanRecord
            );
            
            // For admin/contributor users, also update main table
            if (userRole == 'admin' || userRole == 'contributor') {
              bool mainTableSuccess;
              if (table.primaryKeyConstraints.length == 1) {
                // Single primary key
                final String primaryKeyColumn = table.primaryKeyConstraints.first;
                final dynamic primaryKeyValue = record[primaryKeyColumn];
                mainTableSuccess = await updateRecordInSupabase(
                  'question_answer_pairs',
                  cleanRecord,
                  primaryKeyColumn: primaryKeyColumn,
                  primaryKeyValue: primaryKeyValue,
                );
              } else {
                // Composite primary key
                final Map<String, dynamic> compositeKeyFilters = {};
                for (final key in table.primaryKeyConstraints) {
                  compositeKeyFilters[key] = record[key];
                }
                mainTableSuccess = await updateRecordWithCompositeKeyInSupabase(
                  'question_answer_pairs',
                  cleanRecord,
                  compositeKeyFilters: compositeKeyFilters,
                );
              }
              operationSuccess = reviewTableSuccess && mainTableSuccess;
            } else {
              operationSuccess = reviewTableSuccess;
            }
          } else {
            // Standard update for other tables
            if (table.primaryKeyConstraints.length == 1) {
              // Single primary key
              final String primaryKeyColumn = table.primaryKeyConstraints.first;
              final dynamic primaryKeyValue = record[primaryKeyColumn];
              operationSuccess = await updateRecordInSupabase(
                table.tableName,
                cleanRecord,
                primaryKeyColumn: primaryKeyColumn,
                primaryKeyValue: primaryKeyValue,
              );
            } else {
              // Composite primary key
              final Map<String, dynamic> compositeKeyFilters = {};
              for (final key in table.primaryKeyConstraints) {
                compositeKeyFilters[key] = record[key];
              }
              
              operationSuccess = await updateRecordWithCompositeKeyInSupabase(
                table.tableName,
                cleanRecord,
                compositeKeyFilters: compositeKeyFilters,
              );
            }
          }
        }
        
        if (operationSuccess) {
          // Update local sync flags
          await table.updateSyncFlags(
            primaryKeyConditions: primaryKeyConditions,
            hasBeenSynced: true,
            editsAreSynced: true,
          );
        } else {
          final operation = (hasBeenSynced == 0) ? 'Insert' : 'Update';
          QuizzerLogger.logWarning('$operation FAILED for ${table.tableName} record: ${_getRecordIdentifier(table, record)}');
        }
      } catch (e) {
        QuizzerLogger.logError('Error syncing persistent record in ${table.tableName}: $e');
        // Continue with other records
      }
    }
  }

  // ================================================================================
  // ----- Helper Functions -----
  // ================================================================================

  /// Prepares a record for sync by removing local-only fields and handling special cases
  /// All synced records pass through here before getting pushed to the server
  Map<String, dynamic> _prepareRecordForSync(Map<String, dynamic> record, String tableName) {
    final Map<String, dynamic> cleanRecord = Map<String, dynamic>.from(record);
    
    // Remove local-only sync tracking fields
    cleanRecord.remove('has_been_synced');
    cleanRecord.remove('edits_are_synced');
    
    // Handle Infinity values in doubles
    cleanRecord.forEach((key, value) {
      if (value is double && value.isInfinite) {
        cleanRecord[key] = 1.0;
      }
    });
    
    // Ensure last_modified_timestamp is present
    if (cleanRecord['last_modified_timestamp'] == null || 
        (cleanRecord['last_modified_timestamp'] is String && 
        (cleanRecord['last_modified_timestamp'] as String).isEmpty)) {
      cleanRecord['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();
    }

    // Switch Statements: Remove local-only fields
    switch (tableName) {
      case 'user_question_answer_pairs':
        cleanRecord.remove('accuracy_probability');
        cleanRecord.remove('last_prob_calc');
        break;
      case 'question_answer_attempts':
        cleanRecord.remove('last_modified_timestamp');
        break;
      case 'question_answer_pairs':
        cleanRecord.remove('topics');
        break;
    }

    return cleanRecord;
  }

  /// Extracts primary key conditions from a record for update/delete operations
  Map<String, dynamic> _extractPrimaryKeyConditions(SqlTable table, Map<String, dynamic> record) {
    final Map<String, dynamic> conditions = {};
    for (final key in table.primaryKeyConstraints) {
      if (record.containsKey(key)) {
        conditions[key] = record[key];
      } else {
        QuizzerLogger.logWarning('Missing primary key $key in record for table ${table.tableName}');
      }
    }
    return conditions;
  }

  /// Gets a human-readable identifier for a record (for logging)
  String _getRecordIdentifier(SqlTable table, Map<String, dynamic> record) {
    if (table.primaryKeyConstraints.length == 1) {
      final String key = table.primaryKeyConstraints.first;
      return '$key: ${record[key]}';
    } else {
      return table.primaryKeyConstraints.map((key) => '$key: ${record[key]}').join(', ');
    }
  }
  // ================================================================================
  // ----- Push/Pull Helper For Supabase -----
  // ================================================================================
  /// Attempts to push a single record to a specified Supabase table using upsert.
  /// Returns true if the upsert operation completes without error, false otherwise.
  Future<bool> pushRecordToSupabase(String tableName, Map<String, dynamic> recordData) async {
    try {
      Map<String, dynamic> payload = Map.from(recordData);
      payload.remove('has_been_synced');
      payload.remove('edits_are_synced');
      payload.forEach((key, value) {
        if (value is double && value.isInfinite) {
          payload[key] = 1.0;
        }
      });
      await SessionManager().supabase.from(tableName).upsert(payload);
      return true;
    } on PostgrestException catch (e) {
      // Handle Supabase-specific errors (network, policy violations, etc.)
      QuizzerLogger.logWarning('Supabase upsert FAILED for record to $tableName: ${e.message} (Code: ${e.code})');
      try {
        Map<String, dynamic> payload = Map.from(recordData);
        payload.remove('has_been_synced');
        payload.remove('edits_are_synced');
        payload.forEach((key, value) {
          if (value is double && value.isInfinite) {
            payload[key] = 1.0;
          }
        });
        await SessionManager().supabase.from(tableName).insert(payload);
        return true;
      } on PostgrestException catch (e2) {
        QuizzerLogger.logError('Supabase insert FAILED for record to $tableName: ${e2.message} (Code: ${e2.code})');
        return false; // Return false for network/external errors
      } catch (e2) {
        QuizzerLogger.logError('Unexpected error during Supabase insert fallback for record to $tableName: $e2');
        rethrow; // Rethrow unexpected errors (logic errors)
      }
    } on SocketException catch (e) {
      // Handle network connectivity errors
      QuizzerLogger.logWarning('Network error during Supabase upsert for record to $tableName: $e');
      return false; // Return false for network errors
    } catch (e) {
      // Handle other unexpected errors (logic errors, etc.)
      QuizzerLogger.logError('Unexpected error during Supabase upsert for record to $tableName: $e');
      rethrow; // Rethrow unexpected errors (logic errors)
    }
  }

  /// Attempts to update a single existing record in a specified Supabase table.
  /// Matches the record based on the provided primary key column and value.
  /// Returns true if the update operation completes without error, false otherwise.
  Future<bool> updateRecordInSupabase(String tableName, Map<String, dynamic> recordData, {required String primaryKeyColumn, required dynamic primaryKeyValue}) async {
    try {
      // Prepare payload (remove local-only fields and the primary key itself, as it's used in the filter)
      Map<String, dynamic> payload = Map.from(recordData);
      payload.remove('has_been_synced');
      payload.remove('edits_are_synced');
      payload.remove(primaryKeyColumn); // Don't try to update the primary key

      // Ensure there's something left to update besides sync flags/PK
      if (payload.isEmpty) {
          QuizzerLogger.logWarning('updateRecordInSupabase: No fields to update for ID $primaryKeyValue in $tableName after removing sync flags and PK.');
          return true; // Consider this a success, as there are no actual changes to push for this edit.
      }

      // Perform Update based on the primary key column and value
      await SessionManager().supabase
        .from(tableName)
        .update(payload)
        .eq(primaryKeyColumn, primaryKeyValue); // Use .eq() to specify the row to update
      return true; // Assume success if no exception is thrown

    } on PostgrestException catch (e) {
      // Handle Supabase-specific errors (network, policy violations, etc.)
      QuizzerLogger.logError('Supabase PostgrestException during update for ID $primaryKeyValue in $tableName: ${e.message} (Code: ${e.code})');
      QuizzerLogger.logMessage("Payload that failed to push: $recordData");
      return false; // Return false for network/external errors
    } on SocketException catch (e) {
      // Handle network connectivity errors
      QuizzerLogger.logWarning('Network error during Supabase update for ID $primaryKeyValue in $tableName: $e');
      return false; // Return false for network errors
    } catch (e) {
      // Handle other unexpected errors (logic errors, etc.)
      QuizzerLogger.logError('Unexpected error during Supabase update for ID $primaryKeyValue in $tableName: $e');
      rethrow; // Rethrow unexpected errors (logic errors)
    }
  }

  /// Attempts to update a single existing record in a specified Supabase table using multiple filter conditions.
  /// Matches the record based on the provided compositeKeyFilters.
  /// Returns true if the update operation completes without error, false otherwise.
  Future<bool> updateRecordWithCompositeKeyInSupabase(
    String tableName, 
    Map<String, dynamic> recordData, 
    {required Map<String, dynamic> compositeKeyFilters}
  ) async {
    try {
      final String filterLog = compositeKeyFilters.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      Map<String, dynamic> payload = Map.from(recordData);
      payload.remove('has_been_synced');
      payload.remove('edits_are_synced');
      // Also remove the keys used in the filter from the payload, as they identify the row and shouldn't be updated themselves.
      for (var key in compositeKeyFilters.keys) {
        payload.remove(key);
      }

      // Check for Infinity values and replace with 1
      payload.forEach((key, value) {
        if (value is double && value.isInfinite) {
          payload[key] = 1.0;
        }
      });

      if (payload.isEmpty) {
        QuizzerLogger.logWarning('updateRecordWithCompositeKeyInSupabase: No fields to update for ($filterLog) in $tableName after removing sync/filter keys.');
        return true; // No actual changes to push
      }

      var query = SessionManager().supabase.from(tableName).update(payload);
      for (var entry in compositeKeyFilters.entries) {
        query = query.eq(entry.key, entry.value);
      }
      await query; // Executes the update query

      return true;
    } on PostgrestException catch (e) {
      // Handle Supabase-specific errors (network, policy violations, etc.)
      final String filterLog = compositeKeyFilters.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      QuizzerLogger.logError('Supabase PostgrestException during composite key update for ($filterLog) in $tableName: ${e.message} (Code: ${e.code})');
      return false; // Return false for network/external errors
    } on SocketException catch (e) {
      // Handle network connectivity errors
      final String filterLog = compositeKeyFilters.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      QuizzerLogger.logWarning('Network error during Supabase composite key update for ($filterLog) in $tableName: $e');
      return false; // Return false for network errors
    } catch (e) {
      // Handle other unexpected errors (logic errors, etc.)
      final String filterLog = compositeKeyFilters.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      QuizzerLogger.logError('Unexpected error during Supabase composite key update for ($filterLog) in $tableName: $e');
      rethrow; // Rethrow unexpected errors (logic errors)
    }
  }
}

