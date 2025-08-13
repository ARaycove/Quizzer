import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';

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

/// Fetches ALL records from a Supabase table that are newer than the last login date
/// using proper pagination to ensure we get everything.
/// 
/// Parameters:
/// - supabase: The Supabase client instance
/// - tableName: The name of the table to fetch records from
/// - userId: The user ID to get the last login date for (or null for global tables)
/// - timestampColumn: The column name that contains the timestamp to compare against (default: 'last_modified_timestamp')
/// - pageSize: Number of records per page (default: 500)
/// - additionalFilters: Map of column names to filter values (e.g., {'user_uuid': '123'})
/// - useLastLogin: Whether to use last login date for filtering (default: true, set to false for global tables)
/// 
/// Returns:
/// - List<Map<String, dynamic>> containing ALL records newer than the last login date
Future<List<Map<String, dynamic>>> fetchAllRecordsOlderThanLastLogin({
  required SupabaseClient supabase,
  required String tableName,
  String? userId,
  String timestampColumn = 'last_modified_timestamp',
  int pageSize = 500,
  Map<String, dynamic>? additionalFilters,
  bool useLastLogin = true,
}) async {
  QuizzerLogger.logMessage('Fetching ALL records from $tableName newer than last login for user: $userId');
  
  try {
    // Calculate the effective initial timestamp using the internal function
    final String finalEffectiveLastLogin = await calculateEffectiveInitialTimestamp(
      supabase: supabase,
      tableName: tableName,
      userId: userId,
      useLastLogin: useLastLogin,
    );
    
    QuizzerLogger.logMessage('Using effective last login timestamp: $finalEffectiveLastLogin');
    
    final List<Map<String, dynamic>> allRecords = [];
    int offset = 0;
    bool hasMoreRecords = true;
    
    while (hasMoreRecords) {
      QuizzerLogger.logMessage('Fetching page starting at offset: $offset from $tableName');
      
      // Build the query with timestamp filter
      var query = supabase
          .from(tableName)
          .select('*')
          .gt(timestampColumn, finalEffectiveLastLogin);
      
      // Apply additional filters if provided
      if (additionalFilters != null) {
        for (final entry in additionalFilters.entries) {
          query = query.eq(entry.key, entry.value);
        }
      }
      
      // Execute the query with range
      final List<Map<String, dynamic>> pageData = await query
          .range(offset, offset + pageSize - 1);
      
      QuizzerLogger.logMessage('Fetched ${pageData.length} records from $tableName');
      
      // Add the page data to our accumulated results
      allRecords.addAll(pageData);
      
      // Move to next page
      offset += pageSize;
      
      // If we got less than pageSize records, we've reached the end
      if (pageData.length < pageSize) {
        hasMoreRecords = false;
      }
    }
    
    QuizzerLogger.logSuccess('Successfully fetched ALL ${allRecords.length} records from $tableName newer than last login');
    return allRecords;
    
  } catch (e) {
    QuizzerLogger.logError('Error fetching records from $tableName newer than last login: $e');
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
/// syncData[4]   == modules \n
/// syncData[5]   == user_stats_eligible_questions \n
/// syncData[6]   == user_stats_non_circulating_questions \n
/// syncData[7]   == user_stats_in_circulation_questions \n
/// syncData[8]   == user_stats_revision_streak_sum \n
/// syncData[9]   == user_stats_total_user_question_answer_pairs \n
/// syncData[10]  == user_stats_average_questions_shown_per_day \n
/// syncData[11]  == user_stats_total_questions_answered \n
/// syncData[12]  == user_stats_daily_questions_answered \n
/// syncData[13]  == user_stats_days_left_until_questions_exhaust \n
/// syncData[14]  == user_stats_average_daily_questions_learned \n
/// syncData[15]  == user_module_activation_status \n
/// syncData[16]  == subject_details \n
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

    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'modules',                       
    userId: null, useLastLogin: false), //Get all modules regardless

    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'user_stats_eligible_questions', 
    userId: userId, additionalFilters: {'user_id': userId}),

    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'user_stats_non_circulating_questions',
    userId: userId, additionalFilters: {'user_id': userId}),

    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'user_stats_in_circulation_questions',
    userId: userId, additionalFilters: {'user_id': userId}),

    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'user_stats_revision_streak_sum',
    userId: userId, additionalFilters: {'user_id': userId}),

    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'user_stats_total_user_question_answer_pairs',
    userId: userId, additionalFilters: {'user_id': userId}),

    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'user_stats_average_questions_shown_per_day',
    userId: userId, additionalFilters: {'user_id': userId}),

    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'user_stats_total_questions_answered',
    userId: userId, additionalFilters: {'user_id': userId}),

    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'user_stats_daily_questions_answered',
    userId: userId, additionalFilters: {'user_id': userId}),

    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'user_stats_days_left_until_questions_exhaust',
    userId: userId, additionalFilters: {'user_id': userId}),

    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'user_stats_average_daily_questions_learned',
    userId: userId, additionalFilters: {'user_id': userId}),

    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'user_module_activation_status',
    userId: userId, additionalFilters: {'user_id': userId}),

    fetchAllRecordsOlderThanLastLogin(supabase: supabase, tableName: 'subject_details',
    userId: null),


  ]);
  return allResults;
}