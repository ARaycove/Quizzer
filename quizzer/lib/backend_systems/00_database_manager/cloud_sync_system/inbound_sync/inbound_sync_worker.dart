import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile_table.dart';

/// Syncs question_answer_pairs from the cloud that are newer than last_login
Future<void> syncQuestionAnswerPairsInbound(
  String userId,
  String lastLogin,
  Database db,
  SupabaseClient supabaseClient,
) async {
  QuizzerLogger.logMessage('Syncing inbound question_answer_pairs for user $userId since $lastLogin...');
  final List<dynamic> cloudRecords = await supabaseClient
      .from('question_answer_pairs')
      .select('*')
      .gt('last_modified_timestamp', lastLogin);

  if (cloudRecords.isEmpty) {
    QuizzerLogger.logMessage('No new question_answer_pairs to sync.');
    return;
  }

  QuizzerLogger.logMessage('Found ${cloudRecords.length} new/updated question_answer_pairs to sync.');
  for (final record in cloudRecords) {
    // Insert or update each record
    await insertOrUpdateQuestionAnswerPair(record, db);
  }
  QuizzerLogger.logSuccess('Synced ${cloudRecords.length} question_answer_pairs from cloud.');
}

Future<void> runInboundSync(SessionManager sessionManager) async {
  QuizzerLogger.logMessage('Starting inbound sync aggregator...');
  final String? userId = sessionManager.userId;

  final DatabaseMonitor monitor = getDatabaseMonitor();
  final Database db = (await monitor.requestDatabaseAccess()) as Database;

  // Get last_login timestamp using the imported helper
  // lastLogin is used in the query, inbound sync will fetch all records newer than the last time this device logged in.
  final String? lastLogin = await getLastLoginForUser(userId!, db);
  if (lastLogin == null) throw StateError('No last_login timestamp found for user.');

  // Sync question_answer_pairs
  await syncQuestionAnswerPairsInbound(userId, lastLogin, db, sessionManager.supabase);

  
  // TODO: Add calls to sync other tables (e.g., user_question_answer_pairs)

  QuizzerLogger.logSuccess('Inbound sync completed successfully.');
  monitor.releaseDatabaseAccess();
}
