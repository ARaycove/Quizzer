import 'dart:io'; // Added for File operations
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:path/path.dart' as path; // Changed alias to path
import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // For Supabase client
import 'package:supabase/supabase.dart'; // Changed to base supabase package for FileObject and SearchOptions
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart'; // Added import for SwitchBoard
import 'package:path_provider/path_provider.dart'; // Added for getApplicationDocumentsDirectory

// ==========================================
// Media Sync Status Table
// ==========================================
// This table is local-only and tracks the sync status of media files.

const String _tableName = 'media_sync_status';
const String _colFileName = 'file_name'; // TEXT, PRIMARY KEY
const String _colFileExtension = 'file_extension'; // TEXT
const String _colExistsLocally = 'exists_locally'; // INTEGER, NULLABLE
const String _colExistsExternally = 'exists_externally'; // INTEGER, NULLABLE

/// Verifies and creates the media_sync_status table if it doesn't exist.
Future<void> verifyMediaSyncStatusTable(Database db) async {
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='$_tableName'"
  );
  
  if (tables.isEmpty) {
    QuizzerLogger.logMessage('Creating $_tableName table.');
    await db.execute('''
      CREATE TABLE $_tableName (
        $_colFileName TEXT PRIMARY KEY,
        $_colFileExtension TEXT NOT NULL,
        $_colExistsLocally INTEGER DEFAULT NULL,
        $_colExistsExternally INTEGER DEFAULT NULL
      )
    ''');
  } else {
    QuizzerLogger.logMessage('$_tableName table already exists.');
    // Add alter table logic here if schema changes in the future.
  }
}

// --- Interaction Functions ---

// Helper function to check if a file exists locally in the designated path
Future<bool> _checkFileExistsLocally(String fileNameWithExtension) async {
  final dir = await getApplicationDocumentsDirectory();
  final String localPath = path.join(dir.path, 'question_answer_pair_assets', fileNameWithExtension);
  final File file = File(localPath);
  final bool exists = await file.exists();
  QuizzerLogger.logMessage('Local file check for $localPath: ${exists ? "Exists" : "Does not exist"}');
  return exists;
}

// Helper function to check if a file exists in the Supabase storage bucket
Future<bool> _checkFileExistsInSupabase(String fileNameWithExtension) async {
  QuizzerLogger.logMessage('Checking Supabase storage for file: $fileNameWithExtension in bucket: question-answer-pair-assets using list().');
  final supabase = getSessionManager().supabase;
  const String bucketName = 'question-answer-pair-assets';

  // List the root of the bucket, not the file itself
  final List<FileObject> files = await supabase.storage
      .from(bucketName)
      .list(); // List all files at the root

  // Log all file names returned by the list operation
  if (files.isNotEmpty) {
    QuizzerLogger.logMessage('Supabase list() returned the following files: '
      '${files.map((f) => f.name).join(', ')}');
  } else {
    QuizzerLogger.logMessage('Supabase list() returned no files in the bucket root');
  }

  // Search for an exact match in the returned files
  final found = files.any((f) => f.name == fileNameWithExtension);
  if (found) {
    QuizzerLogger.logSuccess('File $fileNameWithExtension FOUND in Supabase bucket $bucketName (exact match in list).');
    return true;
  } else {
    QuizzerLogger.logMessage('File $fileNameWithExtension NOT FOUND in Supabase bucket $bucketName (not present in list).');
    return false;
  }
}

/// Inserts a new media sync status record.
/// `exists_locally` and `exists_externally` are determined by checks.
/// Throws an error if a record with the same file_name already exists.
Future<void> insertMediaSyncStatus({
  required Database db,
  required String fileName,
  required String fileExtension,
}) async {
  await verifyMediaSyncStatusTable(db);
  
  // Determine local existence
  final bool localFileExists = await _checkFileExistsLocally(fileName);
  // Determine external (Supabase) existence
  final bool supabaseFileExists = await _checkFileExistsInSupabase(fileName);

  QuizzerLogger.logMessage('Attempting to insert into $_tableName: $fileName (exists_locally: $localFileExists, exists_externally: $supabaseFileExists)');
  
  final Map<String, dynamic> row = {
    _colFileName: fileName,
    _colFileExtension: fileExtension,
    _colExistsLocally: localFileExists, 
    _colExistsExternally: supabaseFileExists, 
  };
  
  QuizzerLogger.logValue('Inserting row into $_tableName for $fileName. Data: $row');
  await insertRawData(
    _tableName,
    row,
    db,
    conflictAlgorithm: ConflictAlgorithm.fail, // Fail if already exists
  );
  QuizzerLogger.logSuccess('Inserted $fileName into $_tableName.');
  
  // Signal that a media sync status has been processed
  getSwitchBoard().signalMediaSyncStatusProcessed();

  // If the insert fails due to a conflict, a DatabaseException will be thrown
  // by insertRawData (ultimately by db.insert) and propagate up.
}

/// Updates an existing media sync status record.
/// If the record does not exist, this operation will do nothing.
Future<int> updateMediaSyncStatus({
  required Database db,
  required String fileName,
  String? fileExtension,
  bool? existsLocally,
  bool? existsExternally,
}) async {
  await verifyMediaSyncStatusTable(db);
  QuizzerLogger.logMessage('Updating $_tableName for: $fileName');
  
  final Map<String, dynamic> row = {};
  if (fileExtension != null) row[_colFileExtension] = fileExtension;
  if (existsLocally != null) row[_colExistsLocally] = existsLocally;
  if (existsExternally != null) row[_colExistsExternally] = existsExternally;
  
  if (row.isEmpty) {
    QuizzerLogger.logWarning('Update called for $fileName in $_tableName with no values to change.');
    return 0;
  }
  
  final int rowsAffected = await updateRawData(
    _tableName,
    row,
    '$_colFileName = ?', // where clause
    [fileName],          // whereArgs
    db,
  );
  
  if (rowsAffected == 0) {
    QuizzerLogger.logWarning('Update for $fileName in $_tableName affected 0 rows. Record might not exist.');
  } else {
    QuizzerLogger.logSuccess('Updated $fileName in $_tableName. Rows affected: $rowsAffected');
  }
  return rowsAffected;
}

/// Retrieves a single media sync status record by file_name.
/// Returns null if no record is found.
/// Note: The boolean values will be returned as integers (0 or 1) by queryAndDecodeDatabase.
Future<Map<String, dynamic>?> getMediaSyncStatus(Database db, String fileName) async {
  await verifyMediaSyncStatusTable(db);
  QuizzerLogger.logMessage('Fetching record from $_tableName for $fileName.');
  
  final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
    _tableName,
    db,
    where: '$_colFileName = ?',
    whereArgs: [fileName],
    limit: 1,
  );
  
  if (results.isEmpty) {
    QuizzerLogger.logMessage('No record found in $_tableName for $fileName.');
    return null;
  }
  
  QuizzerLogger.logSuccess('Fetched record from $_tableName for $fileName.');
  return results.first;
}

/// Retrieves all media sync status records where exists_locally is 1 (true)
/// AND exists_externally is 0 (false).
/// These are files that are on the local device but not yet in Supabase.
Future<List<Map<String, dynamic>>> getExistingLocallyNotExternally(Database db) async {
  await verifyMediaSyncStatusTable(db);
  QuizzerLogger.logMessage('Fetching records from $_tableName where $_colExistsLocally = 1 AND $_colExistsExternally = 0.');
  
  final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
    _tableName,
    db,
    where: '$_colExistsLocally = ? AND $_colExistsExternally = ?',
    whereArgs: [1, 0], // true for local, false for external
  );
  
  QuizzerLogger.logSuccess('Fetched ${results.length} records from $_tableName that exist locally but not externally.');
  return results;
}

/// Retrieves all media sync status records where exists_externally is 1 (true)
/// AND (exists_locally is 0 (false) OR exists_locally IS NULL).
/// These are files that are in Supabase but not on the local device or their local status is unknown.
Future<List<Map<String, dynamic>>> getExistingExternallyNotLocally(Database db) async {
  await verifyMediaSyncStatusTable(db);
  QuizzerLogger.logMessage('Fetching records from $_tableName where $_colExistsExternally = 1 AND ($_colExistsLocally = 0 OR $_colExistsLocally IS NULL).');
  
  final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
    _tableName,
    db,
    where: '$_colExistsExternally = ? AND ($_colExistsLocally = ? OR $_colExistsLocally IS NULL)',
    whereArgs: [1, 0], // true for external, false for local check in OR condition
  );
  
  QuizzerLogger.logSuccess('Fetched ${results.length} records from $_tableName that exist externally but not locally (or local status unknown).');
  return results;
}
