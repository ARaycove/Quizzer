import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/session_manager/answer_validation/text_analysis_tools.dart';

// Table name and field constants
const String synonymsTableName = 'synonyms_table';
const String stemmedPhraseField = 'stemmed_phrase';
const String synonymListField = 'synonym_list';

// Create table SQL
const String createSynonymsTableSQL = '''
  CREATE TABLE IF NOT EXISTS $synonymsTableName (
    $stemmedPhraseField TEXT PRIMARY KEY,
    $synonymListField TEXT,
    has_been_synced INTEGER DEFAULT 0,
    edits_are_synced INTEGER DEFAULT 0,
    last_modified_timestamp TEXT
  )
''';

// Verify table exists and create if needed
Future<void> verifySynonymsTable(dynamic db) async {
  QuizzerLogger.logMessage('Verifying synonyms table existence');
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='$synonymsTableName'"
  );
  
  if (tables.isEmpty) {
    QuizzerLogger.logMessage('Synonyms table does not exist, creating it');
    await db.execute(createSynonymsTableSQL);
    QuizzerLogger.logSuccess('Synonyms table created successfully');
  } else {
    QuizzerLogger.logMessage('Synonyms table exists');
    QuizzerLogger.logSuccess('Synonyms table structure verified');
  }
}

// Insert a new synonym entry with just the stemmed phrase (initial entry)
Future<void> insertSynonymPhrase(String phrase) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    
    // Trim and lowercase the input phrase
    final String normalizedPhrase = phrase.trim().toLowerCase();
    
    // Stem the phrase using tokenizeAndReconstruct
    final String stemmedPhrase = await tokenizeAndReconstruct(normalizedPhrase);
    
    QuizzerLogger.logMessage('Inserting new synonym phrase entry: $normalizedPhrase (stemmed: $stemmedPhrase)');
    await verifySynonymsTable(db);
    
    final Map<String, dynamic> data = {
      stemmedPhraseField: stemmedPhrase,
      'has_been_synced': 0,
      'edits_are_synced': 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String()
    };

    final int result = await insertRawData(
      synonymsTableName,
      data,
      db,
      conflictAlgorithm: ConflictAlgorithm.ignore, // Ignore if phrase already exists
    );
    
    if (result > 0) {
      QuizzerLogger.logSuccess('Synonym phrase entry $stemmedPhrase inserted successfully');
    } else {
      QuizzerLogger.logMessage('Synonym phrase $stemmedPhrase already exists or insert was ignored');
    }
  } catch (e) {
    QuizzerLogger.logError('Error inserting synonym phrase - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Insert a complete synonym entry (for bulk operations)
Future<void> insertSynonym({
  required String stemmedPhrase,
  required List<String> synonyms,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Inserting complete synonym entry: $stemmedPhrase');
    await verifySynonymsTable(db);
    
    final Map<String, dynamic> data = {
      stemmedPhraseField: stemmedPhrase,
      synonymListField: synonyms,
      'has_been_synced': 0,
      'edits_are_synced': 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String()
    };

    final int result = await insertRawData(
      synonymsTableName,
      data,
      db,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    if (result > 0) {
      QuizzerLogger.logSuccess('Complete synonym entry $stemmedPhrase inserted/replaced successfully');
    } else {
      QuizzerLogger.logWarning('Insert/replace operation for synonym $stemmedPhrase returned $result.');
    }
  } catch (e) {
    QuizzerLogger.logError('Error inserting complete synonym - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Update synonym sync flags
Future<void> updateSynonymSyncFlags({
  required String word,
  required bool hasBeenSynced,
  required bool editsAreSynced,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Updating sync flags for synonym: $word');
    await verifySynonymsTable(db);
    
    final updates = {
      'has_been_synced': hasBeenSynced ? 1 : 0,
      'edits_are_synced': editsAreSynced ? 1 : 0,
    };

    final int result = await updateRawData(
      synonymsTableName,
      updates,
      '$stemmedPhraseField = ?',
      [word],
      db,
    );
    
    if (result > 0) {
      QuizzerLogger.logSuccess('Sync flags updated for synonym $word');
    } else {
      QuizzerLogger.logWarning('No rows affected when updating sync flags for synonym $word');
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating synonym sync flags - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}
