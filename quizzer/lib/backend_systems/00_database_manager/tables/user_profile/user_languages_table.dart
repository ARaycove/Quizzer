import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';

// TODO need to update outbound sync to sync these records

// TODO Need to update inbound sync to pull these records

// TODO Need to create a user_profile page to display these

// TODO Need to update edit question widget to allow for adding/removing of languages (using same list of unique languages from this table )

// ==========================================
//          User Languages Table
// ==========================================
// Stores languages spoken by users and their proficiency.

// Helper function to convert proficiency level integer to string
String _getProficiencyString(int level) {
  switch (level) {
    case 1:
      return 'Native';
    case 2:
      return 'Fluent';
    case 3:
      return 'Conversational';
    case 4:
      return 'Basic';
    default:
      // This case should ideally not be reached if validation is done prior to calling.
      QuizzerLogger.logError('Invalid proficiency level integer: $level encountered in _getProficiencyString.');
      throw ArgumentError('Invalid proficiency level: $level. Must be between 1 and 4.');
  }
}

const String userLanguagesTable = 'user_languages';

// --- Column Names ---
const String colUserLanguagesUserUuid = 'uuid'; // TEXT, Foreign Key to user_profile(uuid)
const String colUserLanguagesLanguage = 'language'; // TEXT, e.g., "English", "Spanish"
const String colUserLanguagesProficiency = 'proficiency'; // TEXT, e.g., "Native", "Fluent" (Stored as TEXT)
const String colUserLanguagesLastModifiedTimestamp = 'last_modified_timestamp'; // TEXT
const String colUserLanguagesHasBeenSynced = 'has_been_synced'; // INTEGER (0 or 1)
const String colUserLanguagesEditsAreSynced = 'edits_are_synced'; // INTEGER (0 or 1)

// --- Valid Proficiency Levels ---
// const List<int> validProficiencyLevels = [1, 2, 3, 4]; // 1:Native, 2:Fluent, 3:Conversational, 4:Basic // No longer used

// --- Table Creation SQL ---
Future<void> createUserLanguagesTable() async {
  final dbMonitor = getDatabaseMonitor();
  final db = await dbMonitor.requestDatabaseAccess();
  try {
    await db!.execute('''
      CREATE TABLE IF NOT EXISTS $userLanguagesTable (
        $colUserLanguagesUserUuid TEXT NOT NULL,
        $colUserLanguagesLanguage TEXT NOT NULL,
        $colUserLanguagesProficiency TEXT NOT NULL,
        $colUserLanguagesLastModifiedTimestamp TEXT NOT NULL,
        $colUserLanguagesHasBeenSynced INTEGER NOT NULL DEFAULT 0,
        $colUserLanguagesEditsAreSynced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY ($colUserLanguagesUserUuid, $colUserLanguagesLanguage),
        FOREIGN KEY ($colUserLanguagesUserUuid) REFERENCES user_profile ($colUserLanguagesUserUuid) ON DELETE CASCADE
      )
    ''');
    QuizzerLogger.logMessage('$userLanguagesTable table created or already exists.');
  } finally {
    dbMonitor.releaseDatabaseAccess();
  }
}

// --- Add a User Language ---
/// Adds or updates a language for a user with a specified proficiency level.
///
/// The [proficiencyLevel] is an integer with the following mapping:
/// - 1: Native
/// - 2: Fluent
/// - 3: Conversational
/// - 4: Basic
/// The proficiency is stored as a descriptive string in the database.
Future<void> addUserLanguage({
  required String userId,
  required String language,
  required int proficiencyLevel,
}) async {
  final dbMonitor = getDatabaseMonitor();
  final db = await dbMonitor.requestDatabaseAccess();
  try {
    await createUserLanguagesTable(); // Ensure table exists

    if (!(proficiencyLevel >= 1 && proficiencyLevel <= 4)) {
      final String errorMsg = 'Invalid proficiencyLevel: $proficiencyLevel for language "$language" for user $userId. Must be an integer between 1 and 4.';
      QuizzerLogger.logError(errorMsg);
      throw ArgumentError(errorMsg);
    }

    final String currentTimestamp = DateTime.now().toUtc().toIso8601String();
    final String proficiencyString = _getProficiencyString(proficiencyLevel);

    final Map<String, dynamic> languageData = {
      colUserLanguagesUserUuid: userId,
      colUserLanguagesLanguage: language,
      colUserLanguagesProficiency: proficiencyString, // Store as string
      colUserLanguagesLastModifiedTimestamp: currentTimestamp,
      colUserLanguagesHasBeenSynced: 0,
      colUserLanguagesEditsAreSynced: 0,
    };

    await insertRawData(
      userLanguagesTable,
      languageData,
      db,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    QuizzerLogger.logMessage('Added/Updated language "$language" (Proficiency: $proficiencyLevel) for user $userId.');
    signalOutboundSyncNeeded();
  } finally {
    dbMonitor.releaseDatabaseAccess();
  }
}

// --- Update User Language Proficiency ---
/// Updates the proficiency level for an existing language for a user.
///
/// The [newProficiencyLevel] is an integer with the following mapping:
/// - 1: Native
/// - 2: Fluent
/// - 3: Conversational
/// - 4: Basic
/// The proficiency is stored as a descriptive string in the database.
Future<void> updateUserLanguageProficiency({
  required String userId,
  required String language,
  required int newProficiencyLevel,
}) async {
  final dbMonitor = getDatabaseMonitor();
  final db = await dbMonitor.requestDatabaseAccess();
  try {
    await createUserLanguagesTable(); // Ensure table exists

    if (!(newProficiencyLevel >= 1 && newProficiencyLevel <= 4)) {
      final String errorMsg = 'Invalid newProficiencyLevel: $newProficiencyLevel for language "$language" for user $userId. Must be an integer between 1 and 4.';
      QuizzerLogger.logError(errorMsg);
      throw ArgumentError(errorMsg);
    }

    final String currentTimestamp = DateTime.now().toUtc().toIso8601String();
    final String proficiencyString = _getProficiencyString(newProficiencyLevel);

    final Map<String, dynamic> updateData = {
      colUserLanguagesProficiency: proficiencyString, // Store as string
      colUserLanguagesLastModifiedTimestamp: currentTimestamp,
      colUserLanguagesEditsAreSynced: 0,
    };

    final int rowsAffected = await updateRawData(
      userLanguagesTable,
      updateData,
      '$colUserLanguagesUserUuid = ? AND $colUserLanguagesLanguage = ?',
      [userId, language], // Raw language for whereArg
      db,
    );

    if (rowsAffected > 0) {
      QuizzerLogger.logMessage('Updated proficiency for language "$language" to level $newProficiencyLevel for user $userId.');
      signalOutboundSyncNeeded();
    } else {
      QuizzerLogger.logWarning('Attempted to update proficiency for non-existent language "$language" for user $userId.');
    }
  } finally {
    dbMonitor.releaseDatabaseAccess();
  }
}

// --- Remove a User Language ---
Future<void> removeUserLanguage({
  required String userId,
  required String language,
}) async {
  final dbMonitor = getDatabaseMonitor();
  final db = await dbMonitor.requestDatabaseAccess();
  try {
    await createUserLanguagesTable(); // Ensure table exists
    await db!.delete(
      userLanguagesTable,
      where: '$colUserLanguagesUserUuid = ? AND $colUserLanguagesLanguage = ?',
      whereArgs: [userId, language], // Raw language for whereArg
    );
    QuizzerLogger.logMessage('Removed language "$language" for user $userId.');
    // Note: Consider SwitchBoard signal if deletions need to be synced for RLS/other reasons.
  } finally {
    dbMonitor.releaseDatabaseAccess();
  }
}

// --- Get All Languages for a User ---
Future<List<Map<String, dynamic>>> getUserLanguages(String userId) async {
  final dbMonitor = getDatabaseMonitor();
  final db = await dbMonitor.requestDatabaseAccess();
  try {
    await createUserLanguagesTable(); // Ensure table exists
    return await queryAndDecodeDatabase(
      userLanguagesTable,
      db,
      where: '$colUserLanguagesUserUuid = ?',
      whereArgs: [userId],
    );
  } finally {
    dbMonitor.releaseDatabaseAccess();
  }
}

// --- Get Unsynced User Languages ---
Future<List<Map<String, dynamic>>> getUnsyncedUserLanguages(String userId) async {
  final dbMonitor = getDatabaseMonitor();
  final db = await dbMonitor.requestDatabaseAccess();
  try {
    await createUserLanguagesTable(); // Ensure table exists
    return await queryAndDecodeDatabase(
      userLanguagesTable,
      db,
      where: '$colUserLanguagesUserUuid = ? AND ($colUserLanguagesHasBeenSynced = 0 OR $colUserLanguagesEditsAreSynced = 0)',
      whereArgs: [userId],
    );
  } finally {
    dbMonitor.releaseDatabaseAccess();
  }
}
