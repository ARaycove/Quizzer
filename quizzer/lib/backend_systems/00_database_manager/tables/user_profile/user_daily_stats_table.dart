// * [] TODO add attempts_over_last_n_hours feature set with range of hours: [1, 3, 6, 9, 12, 15, 18, 21, 24, 48, 72, (7*24), (14*24), (30*24)]
//    - This feature set would capture the velocity metrics, is the user more active than usual in this last hour?
// * [] TODO accompanying accuracy over last n hours. Making these a paired set of features

// Consolidated daily user statistics table
// All user performance metrics aggregated by date in a single table

import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/avg_daily_questions_learned.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/avg_reaction_time.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/consecutive_correct_streak.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/consecutive_incorrect_streak.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/days_left_until_questions_exhaust.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/global_accuracy.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/global_fitb_accuracy.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/global_mcq_accuracy.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/global_sata_accuracy.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/global_so_accuracy.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/global_tf_accuracy.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/max_correct_streak_achieved.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/revision_streak_sum.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_accuracy_rate.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_correct_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_fitb_accuracy_rate.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_fitb_correct_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_fitb_incorrect_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_fitb_total_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_incorrect_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_mcq_accuracy_rate.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_mcq_correct_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_mcq_incorrect_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_mcq_total_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_sata_accuracy_rate.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_sata_correct_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_sata_incorrect_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_sata_total_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_so_accuracy_rate.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_so_correct_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_so_incorrect_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_so_total_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_tf_accuracy_rate.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_tf_correct_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_tf_incorrect_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_tf_total_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/today_total_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_correct_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_eligible_questions.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_fitb_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_fitb_correct_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_fitb_incorrrect_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_in_circ_questions.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_incorrect_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_mcq_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_mcq_correct_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_mcq_incorrrect_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_non_circ_questions.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_sata_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_sata_correct_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_sata_incorrrect_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_so_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_so_correct_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_so_incorrrect_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_tf_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_tf_correct_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_implementations/total_tf_incorrrect_attempts.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart' as table_helper;
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/sql_table.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

/// A record consists of a series of stats marked by today's date
/// Every field in a record is a different stat with it's own collection mechanism and definition
class UserDailyStatsTable extends SqlTable{
  static final UserDailyStatsTable _instance = UserDailyStatsTable._internal();
  factory UserDailyStatsTable() => _instance;
  UserDailyStatsTable._internal();

  @override
  bool get isTransient => true;

  @override
  bool requiresInboundSync = true;

  @override
  dynamic get additionalFiltersForInboundSync => {'user_id': SessionManager().userId};

  @override
  bool get useLastLoginForInboundSync => false;

  @override
  String get tableName => 'user_daily_stats';

  @override
  List<String> get primaryKeyConstraints => ['user_id', 'record_date'];

  /// statClasses must be listed in a specific order
  /// If the stat calculation is dependent on another stat it should be listed after the stat blocks it is dependent upon
  List<StatField> get _statClasses => [
    TotalCorrectAttempts(),           TotalIncorrectAttempts(),         TotalAttempts(),
    GlobalAccuracy(), // GlobalAccuracy requires TotalCorrectAttempts and TotalAttempts to be calculated first

    TotalFitbCorrectAttempts(),       TotalFitbIncorrrectAttempts(),    TotalFitbAttempts(),
    GlobalFitbAccuracy(),

    TotalMcqCorrectAttempts(),        TotalMcqIncorrrectAttempts(),     TotalMcqAttempts(),
    GlobalMcqAccuracy(),

    TotalSataCorrectAttempts(),       TotalSataIncorrrectAttempts(),    TotalSataAttempts(),
    GlobalSataAccuracy(),

    TotalSoCorrectAttempts(),         TotalSoIncorrrectAttempts(),      TotalSoAttempts(),
    GlobalSoAccuracy(),

    TotalTfCorrectAttempts(),         TotalTfIncorrrectAttempts(),      TotalTfAttempts(),
    GlobalTfAccuracy(),

    ConsecutiveCorrectStreak(),       ConsecutiveIncorrectStreak(),     MaxCorrectStreakAchieved(),

    TotalInCircQuestions(),           TotalNonCircQuestions(),
    
    DaysLeftUntilQuestionsExhaust(),  RevisionStreakSum(), 
    
    TodayCorrectAttempts(),           TodayIncorrectAttempts(),         TodayTotalAttempts(),
    TodayAccuracyRate(),

    TodayFitbCorrectAttempts(),       TodayFitbIncorrectAttempts(),     TodayFitbTotalAttempts(), 
    TodayFitbAccuracyRate(),

    TodayMcqCorrectAttempts(),        TodayMcqIncorrectAttempts(),      TodayMcqTotalAttempts(),   
    TodayMcqAccuracyRate(),

    TodaySataCorrectAttempts(),       TodaySataIncorrectAttempts(),     TodaySataTotalAttempts(),
    TodaySataAccuracyRate(),

    TodaySoCorrectAttempts(),         TodaySoIncorrectAttempts(),       TodaySoTotalAttempts(),
    TodaySoAccuracyRate(),
                    
    TodayTfCorrectAttempts(),         TodayTfIncorrectAttempts(),       TodayTfTotalAttempts(),
    TodayTfAccuracyRate(),                     

    TotalEligibleQuestions(),

    // Calculate all averages last (likely dependent on other stats)
    AvgDailyQuestionsLearned(),       AvgReactionTime(),       
  ];

  List<Map<String, String>> _expectedColumns = [
    // Primary key
    {'name': 'user_id',                           'type': 'TEXT NOT NULL'},
    {'name': 'record_date',                       'type': 'TEXT NOT NULL'},
    // ==================================================
    // Sync fields
    // ==================================================
    {'name': 'has_been_synced',                   'type': 'INTEGER DEFAULT 0'},
    {'name': 'edits_are_synced',                  'type': 'INTEGER DEFAULT 0'},
    {'name': 'last_modified_timestamp',           'type': 'TEXT'},
  ];

  @override
  List<Map<String, String>> get expectedColumns => _expectedColumns;

  set expectedColumns(List<Map<String, String>> value) { _expectedColumns = value; }


  @override
  Future<void> verifyTable(db) async{
    // The verification for the stat table requires some additional validation

    // We dynamically build the expected columns based on the stat field classes rather than try and remember to define them here
    await _buildExpectedColumns();

    // Verify the table now that the expected columns is built
    await table_helper.verifyTable(db: db, tableName: tableName, expectedColumns: expectedColumns, primaryKeyColumns: primaryKeyConstraints);
  }

  /// Updates all daily stats for a user for today (YYYY-MM-DD).
  /// Leverages StatField abstraction for modular, self-contained stat calculations.
  /// Each stat field handles its own recalculation logic based on optional parameters.
  Future<void> updateAllUserDailyStats({bool? isCorrect, double? reactionTime, String? questionId}) async {
    try {
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db == null) {
        throw Exception('Failed to acquire database access for stats update');
      }

      
      final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      Map<String, dynamic>? workingRecord;
      
      await db.transaction((txn) async {
        // Get today's record using proper SqlTable method
        final List<Map<String, dynamic>> existingRecords = await table_helper.queryAndDecodeDatabase(
          tableName,
          txn,
          where: 'user_id = ? AND record_date = ?',
          whereArgs: [SessionManager().userId, today],
          limit: 1,
        );
        
        // Start with existing record or create new base record
        workingRecord = existingRecords.isNotEmpty 
            ? Map<String, dynamic>.from(existingRecords.first)
            : {
                'user_id': SessionManager().userId,
                'record_date': today,
                'has_been_synced': 0,
                'edits_are_synced': 0,
                'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
              };
        
        // Get question type if questionId provided
        String? questionType;
        if (questionId != null && questionId.isNotEmpty) {
          questionType = await _getCurrentQuestionType(questionId, txn);
        }
        
        // Recalculate each stat field and update working record
        for (final statField in _statClasses) {
          // fields would be null if function is called without a question being answered
          workingRecord![statField.name] = await statField.recalculateStat(
            txn: txn,
            isCorrect: isCorrect,
            reactionTime: reactionTime,
            questionId: questionId,
            questionType: questionType,
          );
        }
        
        // Update sync fields and timestamp
        workingRecord!['has_been_synced'] = 0;
        workingRecord!['edits_are_synced'] = 0;
        workingRecord!['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();
      });
      
      // Use the proper upsertRecord method from SqlTable
      getDatabaseMonitor().releaseDatabaseAccess();
      
      if (workingRecord == null) {
        throw Exception('Failed to update daily stats: workingRecord is null after transaction');
      }
      
      await UserDailyStatsTable().upsertRecord(workingRecord!);
      QuizzerLogger.logSuccess('Updated all daily stats for user ${SessionManager().userId} on $today');     
    } catch (e) {
      QuizzerLogger.logError('Daily stats update failed: $e');
      rethrow;
    } finally {
      getDatabaseMonitor().releaseDatabaseAccess();
    }
  }


  // ==================================================
  // Private Utilities
  // ==================================================
  /// Fills missing daily stat records from oldest existing record to today.
  /// Runs only during initialization. Each missing day's stats are calculated using
  /// [StatField.calculateCarryForwardValue] with the previous day's record as input.
  /// 
  /// Algorithm:
  /// 1. Get all existing records sorted by date
  /// 2. If no records exist, create today's record with default values
  /// 3. For each date from oldest to today (inclusive):
  ///    a. If record exists for date → set as previous record for next iteration
  ///    b. If record doesn't exist → fill missing record using stat field carry-forward logic
  ///    c. Move to next date
  Future<void> fillMissingDailyStatRecords() async {
    // Filled stat records are not for syncing, so we bypass the sync mechanism by setting the sync flags to 1
    QuizzerLogger.logMessage('Starting fillMissingDailyStatRecords...');
    
    final Stopwatch stopwatch = Stopwatch()..start();
    int recordsCreated = 0;
    int daysProcessed = 0;
    
    // Define list to hold records that need to be upserted
    List<Map<String, dynamic>> recordsToUpsert = [];
    
    try {
      final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);

      // Get database access ONCE for the entire operation
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db == null) {
        throw Exception('Failed to acquire database access for fillMissingDailyStatRecords');
      }
      QuizzerLogger.logMessage('Today\'s date for stats: $today');
      QuizzerLogger.logMessage('User ID: ${SessionManager().userId}');
      // Step 1: Process all calculations in a single transaction
      await db.transaction((txn) async {
        // Get all existing records sorted chronologically
        QuizzerLogger.logMessage('Fetching existing daily stats records...');
        final existingRecords = await queryAndDecodeDatabase(
          tableName, 
          txn,
          where: 'user_id = ?', 
          whereArgs: [SessionManager().userId],
          orderBy: 'record_date ASC'
        );
        
        QuizzerLogger.logMessage('Found ${existingRecords.length} existing daily stats records');
        
        // Handle case where user is fresh (no prior records)
        if (existingRecords.isEmpty) {
          QuizzerLogger.logMessage('No existing records found - creating initial record for today');
          
          final Map<String, dynamic> newRecord = {
            'user_id': SessionManager().userId,
            'record_date': today,
            'has_been_synced': 1,
            'edits_are_synced': 1,
            'last_modified_timestamp': DateTime.utc(1970, 1, 1).toIso8601String(),
          };
          
          for (final statField in _statClasses) {
            newRecord[statField.name] = statField.defaultValue;
          }
          
          // Add to records to upsert AFTER transaction
          recordsToUpsert.add(newRecord);
          recordsCreated++;
          QuizzerLogger.logMessage('Added initial record for $today to upsert list: $newRecord');
          return;
        }
        
        // Build lookup map for existing records by date
        final existingDates = <String, Map<String, dynamic>>{};
        for (final record in existingRecords) {
          final date = record['record_date'] as String;
          existingDates[date] = record;
        }
        
        final oldestDate = DateTime.parse(existingRecords.first['record_date'] as String);
        final todayDate = DateTime.parse(today);
        
        QuizzerLogger.logMessage('Processing date range: $oldestDate to $todayDate');
        
        // Calculate all missing records within the same transaction
        DateTime currentDate = oldestDate;
        Map<String, dynamic>? previousRecord;
        
        while (currentDate.isBefore(todayDate) || currentDate.isAtSameMomentAs(todayDate)) {
          final currentDateStr = currentDate.toUtc().toIso8601String().substring(0, 10);
          daysProcessed++;
          
          QuizzerLogger.logMessage('Processed $daysProcessed days...'); // no modulo, log every day
          
          // Check if record exists for this date
          if (!existingDates.containsKey(currentDateStr)) {
            QuizzerLogger.logMessage('Missing record detected for $currentDateStr - calculating now');
            
            // Create incomplete record template
            final Map<String, dynamic> incompleteRecord = {
              'user_id': SessionManager().userId,
              'record_date': currentDateStr,
              'has_been_synced': 1,
              'edits_are_synced': 1,
              'last_modified_timestamp': DateTime.utc(1970, 1, 1).toIso8601String(),
            };
            
            // Calculate each stat field using its carry-forward logic
            for (final statField in _statClasses) {
              incompleteRecord[statField.name] = await statField.calculateCarryForwardValue(
                txn: txn,
                previousRecord: previousRecord,
                currentIncompleteRecord: incompleteRecord,
              );
            }
            
            // Add to records to upsert AFTER transaction
            recordsToUpsert.add(incompleteRecord);
            recordsCreated++;
            
            // Set as previous record for next iteration
            previousRecord = incompleteRecord;
            QuizzerLogger.logMessage('Added missing record for $currentDateStr to upsert list: $previousRecord');
          } else {
            // Record exists, set as previous record for next iteration
            previousRecord = existingDates[currentDateStr];
          }
          
          // Move to next date
          currentDate = currentDate.add(const Duration(days: 1));
        }
        
        QuizzerLogger.logMessage('Transaction completed - processed $daysProcessed days, created $recordsCreated records for upsert');
      });
      
      getDatabaseMonitor().releaseDatabaseAccess();
      
      // Step 2: Now upsert all records using the table's upsertRecord method (outside transaction)
      if (recordsToUpsert.isNotEmpty) {
        QuizzerLogger.logMessage('Upserting ${recordsToUpsert.length} records using table upsert method...');
        for (final record in recordsToUpsert) {
          await UserDailyStatsTable().upsertRecord(record);
          QuizzerLogger.logMessage('Successfully upserted record for ${record['record_date']}');
        }
        QuizzerLogger.logSuccess('All records upserted successfully');
      } else {
        QuizzerLogger.logMessage('No records to upsert');
      }
      
      stopwatch.stop();
      QuizzerLogger.logSuccess('fillMissingDailyStatRecords completed successfully');
      QuizzerLogger.logMessage('Total days processed: $daysProcessed');
      QuizzerLogger.logMessage('Records created and upserted: $recordsCreated');
      QuizzerLogger.logMessage('Time elapsed: ${stopwatch.elapsed}');
      
    } catch (e, stackTrace) {
      QuizzerLogger.logError('Failed to fill missing daily stat records: $e');
      QuizzerLogger.logError('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<String?> _getCurrentQuestionType(String? questionId, var db) async {
    if (questionId == null || questionId.isEmpty) {
      return null;
    }
    const questionTypeQuery = '''
      SELECT qap.question_type
      FROM question_answer_pairs qap
      WHERE qap.question_id = ?
      LIMIT 1
    ''';
    final questionTypeResults = await db.rawQuery(questionTypeQuery, [questionId]);
    if (questionTypeResults.isNotEmpty) {return questionTypeResults.first['question_type'] as String?;}
    return null;
  }

  @override
  Future<bool> validateRecord(Map<String, dynamic> dataToInsert) async {
    // Check for required primary keys ONLY
    if (!dataToInsert.containsKey('user_id') || 
        (dataToInsert['user_id'] is! String) || 
        dataToInsert['user_id'].isEmpty) {
      QuizzerLogger.logError('UserDailyStatsTable.validateRecord: Missing or invalid primary key "user_id" in record: $dataToInsert');
      return false;
    }

    if (!dataToInsert.containsKey('record_date') || 
        (dataToInsert['record_date'] is! String) || 
        dataToInsert['record_date'].isEmpty) {
      QuizzerLogger.logError('UserDailyStatsTable.validateRecord: Missing or invalid primary key "record_date" in record: $dataToInsert');
      return false;
    }

    // Validate sync fields (basic type checking only)
    final syncFields = ['has_been_synced', 'edits_are_synced', 'last_modified_timestamp'];
    
    for (final field in syncFields) {
      if (dataToInsert.containsKey(field)) {
        final value = dataToInsert[field];
        
        if (field == 'has_been_synced' || field == 'edits_are_synced') {
          // Should be 0 or 1
          if (value != null && value != 0 && value != 1) {
            QuizzerLogger.logWarning('UserDailyStatsTable.validateRecord: $field should be 0 or 1, got $value. Still allowing.');
            // Don't fail validation for this
          }
        } else if (field == 'last_modified_timestamp') {
          // Should be a string
          if (value != null && value is! String) {
            QuizzerLogger.logWarning('UserDailyStatsTable.validateRecord: $field should be a string, got ${value.runtimeType}. Still allowing.');
            // Don't fail validation for this
          }
        }
      }
    }

    return true;
  }

  Future<void> _buildExpectedColumns() async {
    final List<Map<String, String>> columnsCopy = [...expectedColumns];
    
    for (final statField in _statClasses) {
      final statName = statField.name;
      final statType = statField.type;
      
      final bool exists = columnsCopy.any((col) => col['name'] == statName);
      
      if (!exists) {
        columnsCopy.add({
          'name': statName,
          'type': statType,
        });
      }
    }
    
    expectedColumns = columnsCopy;
  }
}