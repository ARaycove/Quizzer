import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/00_database_manager/cloud_sync_system/inbound_sync/inbound_sync_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/initialization_table_verification.dart';
import 'dart:io'; // For SocketException
import 'dart:async'; // For Future.delayed
import 'package:quizzer/backend_systems/00_database_manager/tables/sql_table.dart';


Future<T> executeSupabaseCallWithRetry<T>(
  Future<T> Function() supabaseCall, {
  int maxRetries = 3,
  Duration initialDelay = const Duration(seconds: 2), // Increased initial delay
  String? logContext,
}) async {
  try {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt < maxRetries) {
      try {
        return await supabaseCall();
      } on SocketException catch (e, s) {
        attempt++;
        String context = logContext ?? 'Supabase call';
        QuizzerLogger.logWarning('$context: SocketException (Attempt $attempt/$maxRetries). Retrying in ${delay.inSeconds}s... Error: $e');
        if (attempt >= maxRetries) {
          QuizzerLogger.logError('$context: SocketException after $maxRetries attempts. Error: $e, Stack: $s');
          rethrow;
        }
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      } on PostgrestException catch (e, s) {
        attempt++;
        String context = logContext ?? 'Supabase call';
        // Only retry on network-related or server-side issues (e.g., 5xx errors or connection errors)
        // Do not retry on 4xx client errors like RLS violations, not found, bad request etc.
        bool isRetriable = e.code == null || // Some connection errors might not have a code
                           (e.code != null && e.code!.startsWith('5')) || // Server errors
                           e.message.toLowerCase().contains('failed host lookup') ||
                           e.message.toLowerCase().contains('connection timed out') ||
                           e.message.toLowerCase().contains('connection closed') ||
                           e.message.toLowerCase().contains('network is unreachable');

        if (isRetriable) {
          QuizzerLogger.logWarning('$context: Retriable PostgrestException (Attempt $attempt/$maxRetries). Code: ${e.code}, Message: ${e.message}. Retrying in ${delay.inSeconds}s...');
          if (attempt >= maxRetries) {
            QuizzerLogger.logError('$context: PostgrestException after $maxRetries attempts. Error: ${e.message}, Code: ${e.code}, Stack: $s');
            rethrow;
          }
          await Future.delayed(delay);
          delay *= 2;
        } else {
          QuizzerLogger.logError('$context: Non-retriable PostgrestException. Code: ${e.code}, Message: ${e.message}, Stack: $s');
          rethrow; // Do not retry for non-retriable errors
        }
      } catch (e, s) {
        // For other unexpected errors, log and rethrow immediately without retrying.
        String context = logContext ?? 'Supabase call';
        QuizzerLogger.logError('$context: Unexpected error during Supabase call. Error: $e, Stack: $s');
        rethrow;
      }
    }
    // This should be unreachable if maxRetries > 0
    throw StateError('${logContext ?? "executeSupabaseCallWithRetry"}: Max retries reached, but no error was rethrown.');
  } catch (e) {
    QuizzerLogger.logError('executeSupabaseCallWithRetry: Error - $e');
    rethrow;
  }
}

Future<void> runInboundSync() async {
  QuizzerLogger.logMessage('Starting inbound sync aggregator...');

  if (SessionManager().userId == null) {
    QuizzerLogger.logError('Cannot run inbound sync: userId is null');
    throw StateError('Cannot run inbound sync: userId is null');
  }

  try {
    QuizzerLogger.logMessage('Starting inbound sync for user ${SessionManager().userId}...');
    
    // Get all tables that require inbound sync
    final List<SqlTable> allTables = InitializationTableVerification.allTables;
    final List<SqlTable> tablesRequiringSync = allTables.where((table) => table.requiresInboundSync).toList();
    
    QuizzerLogger.logMessage('Found ${tablesRequiringSync.length} tables requiring inbound sync');
    
    // Fetch data for all tables requiring sync
    List<List<Map<String,dynamic>>> tableDataForSync = await fetchDataForAllTables(tablesRequiringSync);

    // Now batch upsert all records as a single database transaction
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await db!.transaction((txn) async {
      for (int i = 0; i < tablesRequiringSync.length; i++) {
        final table = tablesRequiringSync[i];
        final data = tableDataForSync[i];
        await table.batchUpsertRecords(records: data, db: txn);
        QuizzerLogger.logMessage('Upserted ${data.length} records for table ${table.tableName}');
        // This is properly inserting the records
      }
    });
    getDatabaseMonitor().releaseDatabaseAccess();
    
    QuizzerLogger.logSuccess('Inbound sync completed successfully for ${tablesRequiringSync.length} tables.');
  } catch (e) {
    QuizzerLogger.logError('Error during inbound sync: $e');
    rethrow;
  }
}