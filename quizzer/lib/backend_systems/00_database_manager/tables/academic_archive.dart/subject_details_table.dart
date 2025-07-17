import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import '../table_helper.dart'; // Import the helper file
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';

// Table name and field constants
const String subjectDetailsTableName = 'subject_details';
const String subjectField = 'subject';
const String immediateParentField = 'immediate_parent';
const String subjectDescriptionField = 'subject_description';

// Create table SQL
const String createSubjectDetailsTableSQL = '''
  CREATE TABLE IF NOT EXISTS $subjectDetailsTableName (
    $subjectField TEXT PRIMARY KEY,
    $immediateParentField TEXT,
    $subjectDescriptionField TEXT,
    has_been_synced INTEGER DEFAULT 0,
    edits_are_synced INTEGER DEFAULT 0,
    last_modified_timestamp TEXT
  )
''';

// Verify table exists and create if needed
Future<void> verifySubjectDetailsTable(dynamic db) async {
  QuizzerLogger.logMessage('Verifying subject_details table existence');
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='$subjectDetailsTableName'"
  );
  
  if (tables.isEmpty) {
    QuizzerLogger.logMessage('Subject details table does not exist, creating it');
    await db.execute(createSubjectDetailsTableSQL);
    QuizzerLogger.logSuccess('Subject details table created successfully');
  } else {
    QuizzerLogger.logMessage('Subject details table exists');
  }
}

// Insert a new subject detail
Future<void> insertSubjectDetail({
  required String subject,
  String? immediateParent,
  String? subjectDescription,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Inserting new subject detail: $subject');
    await verifySubjectDetailsTable(db);
    
    // Prepare the raw data map
    final Map<String, dynamic> data = {
      subjectField: subject,
      immediateParentField: immediateParent,
      subjectDescriptionField: subjectDescription,
      'has_been_synced': 0,
      'edits_are_synced': 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String()
    };

    // Use the universal insert helper with ConflictAlgorithm.replace
    final int result = await insertRawData(
      subjectDetailsTableName,
      data,
      db,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    if (result > 0) {
      QuizzerLogger.logSuccess('Subject detail $subject inserted/replaced successfully');
    } else {
      QuizzerLogger.logWarning('Insert/replace operation for subject detail $subject returned $result.');
    }
  } catch (e) {
    QuizzerLogger.logError('Error inserting subject detail - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Update a subject detail
Future<void> updateSubjectDetail({
  required String subject,
  String? newSubject,
  String? immediateParent,
  String? subjectDescription,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Updating subject detail: $subject');
    await verifySubjectDetailsTable(db);
    final updates = <String, dynamic>{};
    
    // Handle subject name change if provided
    if (newSubject != null && newSubject != subject) {
      updates[subjectField] = newSubject;
      updates['edits_are_synced'] = 0; // Mark as needing sync when subject changes
      QuizzerLogger.logMessage('Subject name will be changed from "$subject" to "$newSubject"');
    }
    
    if (immediateParent != null) {
      updates[immediateParentField] = immediateParent;
      updates['edits_are_synced'] = 0; // Mark as needing sync
    }
    if (subjectDescription != null) {
      updates[subjectDescriptionField] = subjectDescription;
      updates['edits_are_synced'] = 0; // Mark as needing sync
    }
    
    // Add fields that are always updated
    updates['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();

    // Use the universal update helper
    final int result = await updateRawData(
      subjectDetailsTableName,
      updates,
      '$subjectField = ?', // where clause
      [subject],           // whereArgs
      db,
    );
    
    if (result > 0) {
      if (newSubject != null && newSubject != subject) {
        QuizzerLogger.logSuccess('Subject detail renamed from "$subject" to "$newSubject" successfully ($result row affected).');
      } else {
        QuizzerLogger.logSuccess('Subject detail $subject updated successfully ($result row affected).');
      }
    } else {
      QuizzerLogger.logWarning('Update operation for subject detail $subject affected 0 rows. Subject might not exist or data was unchanged.');
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating subject detail - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Get a subject detail by subject name
Future<Map<String, dynamic>?> getSubjectDetail(String subject) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching subject detail: $subject');
    await verifySubjectDetailsTable(db);
    
    // Use the universal query helper
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      subjectDetailsTableName,
      db,
      where: '$subjectField = ?',
      whereArgs: [subject],
      limit: 2, // Limit to 2 to detect if PK constraint is violated
    );

    if (results.isEmpty) {
      QuizzerLogger.logMessage('Subject detail $subject not found');
      return null;
    } else if (results.length > 1) {
      QuizzerLogger.logError('Found multiple subject details with the same name: $subject. PK constraint violation?');
      throw StateError('Found multiple subject details with the same primary key: $subject');
    }

    // Get the single, already decoded map
    final decodedSubjectDetail = results.first;

    // Manually handle type conversions not covered by the generic decoder
    final Map<String, dynamic> finalResult = {
      subjectField: decodedSubjectDetail[subjectField],
      immediateParentField: decodedSubjectDetail[immediateParentField],
      subjectDescriptionField: decodedSubjectDetail[subjectDescriptionField],
    };
    
    QuizzerLogger.logValue('Retrieved and processed subject detail: $finalResult');
    return finalResult;
  } catch (e) {
    QuizzerLogger.logError('Error getting subject detail - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Get all subject details
Future<List<Map<String, dynamic>>> getAllSubjectDetails() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching all subject details');
    await verifySubjectDetailsTable(db);
    
    // Use the universal query helper
    final List<Map<String, dynamic>> decodedSubjectDetails = await queryAndDecodeDatabase(
      subjectDetailsTableName,
      db,
      // No WHERE clause needed to get all
    );

    QuizzerLogger.logValue('Retrieved ${decodedSubjectDetails.length} subject details');
    return decodedSubjectDetails;
  } catch (e) {
    QuizzerLogger.logError('Error getting all subject details - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Get unsynced subject details
Future<List<Map<String, dynamic>>> getUnsyncedSubjectDetails() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching unsynced subject details');
    await verifySubjectDetailsTable(db);
    
    // Use the universal query helper to get subject details that need syncing
    final List<Map<String, dynamic>> unsyncedSubjectDetails = await queryAndDecodeDatabase(
      subjectDetailsTableName,
      db,
      where: 'edits_are_synced = ?',
      whereArgs: [0],
    );

    QuizzerLogger.logValue('Found ${unsyncedSubjectDetails.length} unsynced subject details');
    return unsyncedSubjectDetails;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced subject details - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Update subject detail sync flags
Future<void> updateSubjectDetailSyncFlags({
  required String subject,
  required bool hasBeenSynced,
  required bool editsAreSynced,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Updating sync flags for subject detail: $subject');
    await verifySubjectDetailsTable(db);
    
    final updates = {
      'has_been_synced': hasBeenSynced ? 1 : 0,
      'edits_are_synced': editsAreSynced ? 1 : 0,
    };

    final int result = await updateRawData(
      subjectDetailsTableName,
      updates,
      '$subjectField = ?',
      [subject],
      db,
    );
    
    if (result > 0) {
      QuizzerLogger.logSuccess('Sync flags updated for subject detail $subject');
    } else {
      QuizzerLogger.logWarning('No rows affected when updating sync flags for subject detail $subject');
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating subject detail sync flags - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Upserts a subject detail from inbound sync and sets sync flags to 1.
/// This function is specifically for handling inbound sync operations.
Future<void> upsertSubjectDetailFromInboundSync({
  required String subject,
  String? immediateParent,
  String? subjectDescription,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Upserting subject detail $subject from inbound sync...');

    await verifySubjectDetailsTable(db);

    // Prepare the data map with only the fields we store in Supabase
    final Map<String, dynamic> data = {
      'subject': subject,
      'immediate_parent': immediateParent,
      'subject_description': subjectDescription,
      'has_been_synced': 1,
      'edits_are_synced': 1,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    // Use upsert to handle both insert and update cases
    await db.insert(
      'subject_details',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    QuizzerLogger.logSuccess('Successfully upserted subject detail $subject from inbound sync.');
  } catch (e) {
    QuizzerLogger.logError('Error upserting subject detail from inbound sync - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Delete a subject detail
Future<void> deleteSubjectDetail(String subject) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Deleting subject detail: $subject');
    await verifySubjectDetailsTable(db);
    
    final int result = await db.delete(
      subjectDetailsTableName,
      where: '$subjectField = ?',
      whereArgs: [subject],
    );
    
    if (result > 0) {
      QuizzerLogger.logSuccess('Subject detail $subject deleted successfully ($result row affected).');
    } else {
      QuizzerLogger.logWarning('Delete operation for subject detail $subject affected 0 rows. Subject might not exist.');
    }
  } catch (e) {
    QuizzerLogger.logError('Error deleting subject detail - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Get subject details by immediate parent
Future<List<Map<String, dynamic>>> getSubjectDetailsByParent(String parentSubject) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching subject details with parent: $parentSubject');
    await verifySubjectDetailsTable(db);
    
    // Use the universal query helper
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      subjectDetailsTableName,
      db,
      where: '$immediateParentField = ?',
      whereArgs: [parentSubject],
    );

    QuizzerLogger.logValue('Retrieved ${results.length} subject details with parent $parentSubject');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting subject details by parent - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Get root subjects (those with no immediate parent)
Future<List<Map<String, dynamic>>> getRootSubjects() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching root subjects (no immediate parent)');
    await verifySubjectDetailsTable(db);
    
    // Use the universal query helper
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      subjectDetailsTableName,
      db,
      where: '$immediateParentField IS NULL OR $immediateParentField = ?',
      whereArgs: [''],
    );

    QuizzerLogger.logValue('Retrieved ${results.length} root subjects');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting root subjects - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Gets the most recent last_modified_timestamp from the subject_details table.
/// Returns null if no records exist.
Future<String?> getMostRecentSubjectDetailTimestamp() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching most recent subject_detail timestamp');
    await verifySubjectDetailsTable(db);
    
    final List<Map<String, dynamic>> results = await db.rawQuery(
      'SELECT last_modified_timestamp FROM $subjectDetailsTableName WHERE last_modified_timestamp IS NOT NULL ORDER BY last_modified_timestamp DESC LIMIT 1'
    );
    
    if (results.isEmpty) {
      QuizzerLogger.logMessage('No subject_details found with timestamp');
      return null;
    }
    
    final String timestamp = results.first['last_modified_timestamp'] as String;
    QuizzerLogger.logValue('Most recent subject_detail timestamp: $timestamp');
    return timestamp;
  } catch (e) {
    QuizzerLogger.logError('Error getting most recent subject_detail timestamp - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// True batch upsert for subject_details using a single SQL statement
Future<void> batchUpsertSubjectDetails({
  required List<Map<String, dynamic>> records,
  int chunkSize = 500,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    if (records.isEmpty) return;
    QuizzerLogger.logMessage('Starting TRUE batch upsert for subject_details: \\${records.length} records');
    await verifySubjectDetailsTable(db);

    // List of all columns in the table
    final columns = [
      'subject',
      'immediate_parent',
      'subject_description',
      'has_been_synced',
      'edits_are_synced',
      'last_modified_timestamp',
    ];

    // Helper to get value or null/default
    dynamic getVal(Map<String, dynamic> r, String k, dynamic def) => r[k] ?? def;

    for (int i = 0; i < records.length; i += chunkSize) {
      final batch = records.sublist(i, i + chunkSize > records.length ? records.length : i + chunkSize);
      final values = <dynamic>[];
      final valuePlaceholders = batch.map((r) {
        for (final col in columns) {
          values.add(getVal(r, col, null));
        }
        return '(${List.filled(columns.length, '?').join(',')})';
      }).join(', ');

      // Use subject as the upsert key since it has a PRIMARY KEY constraint
      final updateSet = columns.where((c) => c != 'subject').map((c) => '$c=excluded.$c').join(', ');
      final sql = 'INSERT INTO subject_details (${columns.join(',')}) VALUES $valuePlaceholders ON CONFLICT(subject) DO UPDATE SET $updateSet;';
      await db.rawInsert(sql, values);
    }
    QuizzerLogger.logSuccess('TRUE batch upsert for subject_details complete.');
  } catch (e) {
    QuizzerLogger.logError('Error batch upserting subject details - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}


