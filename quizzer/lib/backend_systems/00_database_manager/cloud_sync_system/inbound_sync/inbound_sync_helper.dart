import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';

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
    String effectiveLastLogin;
    
    if (useLastLogin && userId != null) {
      // Get the last login timestamp for the user
      final String? lastLogin = await getLastLoginForUser(userId);
      
      // If lastLogin is null, set it to 20 years ago to ensure we get all records
      effectiveLastLogin = lastLogin ?? DateTime.now().subtract(const Duration(days: 365 * 20)).toUtc().toIso8601String();
    } else {
      // For global tables or when not using last login, use a very old timestamp
      effectiveLastLogin = DateTime.now().subtract(const Duration(days: 365 * 20)).toUtc().toIso8601String();
    }
    
    QuizzerLogger.logMessage('Using effective last login timestamp: $effectiveLastLogin');
    
    final List<Map<String, dynamic>> allRecords = [];
    int offset = 0;
    bool hasMoreRecords = true;
    
    while (hasMoreRecords) {
      QuizzerLogger.logMessage('Fetching page starting at offset: $offset from $tableName');
      
      // Build the query with timestamp filter
      var query = supabase
          .from(tableName)
          .select('*')
          .gt(timestampColumn, effectiveLastLogin);
      
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
