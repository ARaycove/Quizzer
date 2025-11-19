import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:sqflite/sqflite.dart';

/// Calculates the effective initial timestamp for inbound sync filtering.
/// This is a complex decision that balances data completeness vs performance.
/// 
/// Parameters:
/// - supabase: The Supabase client instance
/// - tableName: The name of the table to sync
/// - userId: The user ID (or null for global tables)
/// - useLastLogin: Whether to use last login date for filtering (default: true, set to false for global tables)
/// 
/// Returns:
/// - String timestamp in ISO8601 format to use as the effective initial timestamp
Future<String> calculateEffectiveInitialTimestamp({
  required SupabaseClient supabase,
  required String tableName,
  String? userId,
  bool useLastLogin = true,
}) async {
  QuizzerLogger.logMessage('Calculating effective initial timestamp for $tableName (user: $userId)');
  
  try {
    // Check if the specific table is empty for this user/context
    bool isTableEmpty = await _isTableEmpty(tableName, userId);
    
    if (isTableEmpty) {
      // Table is empty - use 1970 to get all records for this specific table
      final timestamp = DateTime(1970, 1, 1).toUtc().toIso8601String();
      QuizzerLogger.logMessage('Table $tableName is empty - using 1970 timestamp: $timestamp');
      return timestamp;
    }
    
    // Table has data - use lastLogin timestamp for incremental sync
    if (useLastLogin && userId != null) {
      final String? lastLogin = await getLastLoginForUser(userId);
      final timestamp = lastLogin ?? DateTime(1970, 1, 1).toUtc().toIso8601String();
      QuizzerLogger.logMessage('Table $tableName has data - using last login timestamp: $timestamp');
      return timestamp;
    } else {
      // For global tables or when not using last login, use 1970 to ensure we get all records
      final timestamp = DateTime(1970, 1, 1).toUtc().toIso8601String();
      QuizzerLogger.logMessage('Global table or no last login - using 1970 timestamp: $timestamp');
      return timestamp;
    }
    
  } catch (e) {
    QuizzerLogger.logError('Error calculating effective initial timestamp for $tableName: $e');
    // Fallback to 1970 timestamp to ensure we don't miss data
    final fallbackTimestamp = DateTime(1970, 1, 1).toUtc().toIso8601String();
    QuizzerLogger.logMessage('Using fallback timestamp: $fallbackTimestamp');
    return fallbackTimestamp;
  }
}

/// Fetches ALL new and updated records from a Supabase table.
///
/// This function now includes a fallback mechanism: if the local record count
/// for a specific table is below a hardcoded threshold, it will perform a full
/// server sync to retrieve all records. Otherwise, it uses a timestamp-based
/// sync to minimize server traffic by only pulling necessary records.
///
/// Parameters:
/// - supabase: The Supabase client instance
/// - tableName: The name of the table to fetch records from
/// - userId: The user ID (not used by this function's logic)
/// - timestampColumn: The column name with the timestamp
/// - pageSize: Number of records per page (default: 500)
/// - additionalFilters: Map of column names to filter values (e.g., {'user_uuid': '123'})
/// - useLastLogin: Whether to use last login date for filtering (not used by this function's logic)
///
/// Returns:
/// - List<Map<String, dynamic>> containing ALL new and updated records from the table.
Future<List<Map<String, dynamic>>> fetchAllRecordsOlderThanLastLogin({
  required SupabaseClient supabase,
  required String tableName,
  String? userId,
  String timestampColumn = 'last_modified_timestamp',
  int pageSize = 500,
  Map<String, dynamic>? additionalFilters,
  bool useLastLogin = true,
}) async {
  QuizzerLogger.logMessage('Fetching new records from $tableName using robust sync logic');

  try {
    // Hardcoded map to force a full sync for specific tables if local count is low.
    final Map<String, int> forceSyncCounts = {
      'question_answer_pairs': 2200,
    };

    bool performFullSync = false;
    if (forceSyncCounts.containsKey(tableName)) {
      Database? db = await getDatabaseMonitor().requestDatabaseAccess();
      String localCountQuery = 'SELECT COUNT(*) AS count FROM "$tableName"';
      if (tableName == 'question_answer_pairs') {
        localCountQuery += ' WHERE qst_reviewer IS NOT NULL';
      }
      final localCountResult = await db!.rawQuery(localCountQuery);
      getDatabaseMonitor().releaseDatabaseAccess();
      final int localCount = localCountResult.first['count'] as int;

      if (localCount < forceSyncCounts[tableName]!) {
        performFullSync = true;
        QuizzerLogger.logMessage('Forcing full sync for $tableName based on hardcoded map. Local count: $localCount, Required: ${forceSyncCounts[tableName]}');
      }
    }

    String lastLocalTimestamp = '';
    if (!performFullSync) {
      Database? db = await getDatabaseMonitor().requestDatabaseAccess();
      String lastTimestampQuery = 'SELECT MAX($timestampColumn) AS last_ts FROM "$tableName"';
      if (tableName == 'question_answer_pairs') {
        lastTimestampQuery += ' WHERE qst_reviewer IS NOT NULL';
      }
      final localTimestampResult = await db!.rawQuery(lastTimestampQuery);
      getDatabaseMonitor().releaseDatabaseAccess();
      lastLocalTimestamp = localTimestampResult.first['last_ts'] as String? ?? '1970-01-01T00:00:00Z';
      
      QuizzerLogger.logMessage('Using last local timestamp: $lastLocalTimestamp');
    }

    final List<Map<String, dynamic>> allRecords = [];
    int offset = 0;
    bool hasMoreRecords = true;

    while (hasMoreRecords) {
      QuizzerLogger.logMessage('Fetching page starting at offset: $offset from $tableName');

      var query = supabase.from(tableName).select('*');

      if (!performFullSync) {
        query = query.gte(timestampColumn, lastLocalTimestamp);
      }

      // Apply additional filters
      if (additionalFilters != null) {
        for (final entry in additionalFilters.entries) {
          query = query.eq(entry.key, entry.value);
        }
      }

      // Add the ordering and range after all filters have been applied
      final List<Map<String, dynamic>> pageData = await query
          .order(timestampColumn, ascending: true)
          .range(offset, offset + pageSize - 1);

      QuizzerLogger.logMessage('Fetched ${pageData.length} records from $tableName');

      allRecords.addAll(pageData);

      offset += pageSize;

      if (pageData.length < pageSize) {
        hasMoreRecords = false;
      }
    }

    // Post-fetch filtering to remove duplicates caused by `gte`
    final List<Map<String, dynamic>> uniqueRecords = [];
    final Set<String> seenIds = {};

    for (final record in allRecords) {
      final String questionId = record['question_id'].toString();
      if (!seenIds.contains(questionId)) {
        uniqueRecords.add(record);
        seenIds.add(questionId);
      }
    }

    QuizzerLogger.logSuccess('Successfully fetched ALL ${uniqueRecords.length} new records from $tableName');
    return uniqueRecords;

  } catch (e) {
    QuizzerLogger.logError('Error fetching records from $tableName: $e');
    rethrow;
  }
}

/// Helper function to check if a specific table is empty
Future<bool> _isTableEmpty(String tableName, String? userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      QuizzerLogger.logError('Cannot check if table is empty: database access denied');
      return true;
    }
    
    try {
      // Check if table exists first
      final List<Map<String, dynamic>> tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName]
      );
      
      if (tables.isEmpty) {
        QuizzerLogger.logMessage('Table $tableName does not exist - treating as empty');
        return true;
      }
      
      final List<Map<String, dynamic>> results = await db.query(
        tableName,
        limit: 1,
      );
      
      final bool isEmpty = results.isEmpty;
      QuizzerLogger.logMessage('Table $tableName is ${isEmpty ? 'empty' : 'not empty'}');
      return isEmpty;
      
    } finally {
      getDatabaseMonitor().releaseDatabaseAccess();
    }
  } catch (e) {
    QuizzerLogger.logError('Error checking if table $tableName is empty: $e');
    return true;
  }
}


/// Fetches all data from supabase all at once, in a single batched operations
/// Tables are indexed as follows: \n
/// syncData[0]   == question_answer_pairs /n
/// syncData[1]   == user_question_answer_pairs \n
/// syncData[2]   == user_profile \n
/// syncData[3]   == user_settings \n
/// syncData[4]   == subject_details \n
/// syncData[5]   == ml_models \n
/// syncData[6]   == user_daily_stats \n
Future<List<List<Map<String,dynamic>>>> fetchDataForAllTables(SupabaseClient supabase, String? userId) async {
  // Let's assume you have a SupabaseClient instance named `supabaseClient`.
  // SupabaseClient supabaseClient = SupabaseClient('url', 'key');
  
  // Create a list of Futures to be executed concurrently.
  final List<List<Map<String, dynamic>>> allResults = await Future.wait([
    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'question_answer_pairs',         
    userId: userId),

    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'user_question_answer_pairs',    
    userId: userId, additionalFilters: {'user_uuid': userId}),

    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'user_profile',                  
    userId: userId, additionalFilters: {'uuid': userId}),

    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'user_settings',               
    userId: userId, additionalFilters: {'user_id': userId}),

    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'subject_details',
    userId: null),

    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'ml_models'),

    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'user_daily_stats'),
  ]);
  return allResults;
}