import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart' show getModuleNameForQuestionId;
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart' as user_q_pairs_table;
import 'package:quizzer/backend_systems/07_user_question_management/user_question_processes.dart' as user_question_processor;
import 'package:quizzer/backend_systems/09_data_caches/non_circulating_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/due_date_beyond_24hrs_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/due_date_within_24hrs_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/circulating_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/module_inactive_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/past_due_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/eligible_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/unprocessed_cache.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

/// Fills all data caches with user question records based on their cache locations.
/// This function extracts the cache filling logic from PreProcessWorker for use during login initialization.
Future<void> fillDataCaches() async {
  try {
    QuizzerLogger.logMessage('Starting data cache initialization...');
    
    final sessionManager = getSessionManager();
    final userId = sessionManager.userId;
    
    if (userId == null) {
      QuizzerLogger.logWarning('Cannot fill data caches: no user logged in.');
      return;
    }
    
    // Validate User Questions vs Modules first
    QuizzerLogger.logMessage('Validating User Questions vs Modules...');
    await user_question_processor.validateAllModuleQuestions(userId);
    
    // Initialize cache instances
    final unprocessedCache = UnprocessedCache();
    final nonCirculatingCache = NonCirculatingQuestionsCache();
    final moduleInactiveCache = ModuleInactiveCache();
    final dueDateBeyondCache = DueDateBeyond24hrsCache();
    final dueDateWithinCache = DueDateWithin24hrsCache();
    final pastDueCache = PastDueCache();
    final eligibleQuestionsCache = EligibleQuestionsCache();
    final circulatingCache = CirculatingQuestionsCache();
    
    // FIRST: Collect all records by cache location
    QuizzerLogger.logMessage('Collecting all records by cache location...');
    Map<int, List<Map<String, dynamic>>> recordsByCacheLocation = {};
    
    for (int cacheLocation = 0; cacheLocation <= 7; cacheLocation++) {
      QuizzerLogger.logMessage('Fetching records for cache_location: $cacheLocation...');
      
      final List<Map<String, dynamic>> recordsForCache = 
          await user_q_pairs_table.getUserQuestionAnswerPairsByCacheLocation(cacheLocation);
      
      if (recordsForCache.isNotEmpty) {
        recordsByCacheLocation[cacheLocation] = recordsForCache;
        QuizzerLogger.logMessage('Found ${recordsForCache.length} records for cache_location: $cacheLocation');
      } else {
        QuizzerLogger.logMessage('No records found for cache_location: $cacheLocation');
      }
    }
    
    // SECOND: Fetch module names for ModuleInactiveCache records (cache_location 4)
    Map<String, String> questionIdToModuleName = {};
    final moduleInactiveRecords = recordsByCacheLocation[4];
    if (moduleInactiveRecords != null && moduleInactiveRecords.isNotEmpty) {
      QuizzerLogger.logMessage('Fetching module names for ${moduleInactiveRecords.length} ModuleInactiveCache records...');
      for (final record in moduleInactiveRecords) {
        final String questionId = record['question_id'] as String;
        try {
          final String moduleName = await getModuleNameForQuestionId(questionId);
          questionIdToModuleName[questionId] = moduleName;
        } catch (e) {
          QuizzerLogger.logWarning('Failed to get module name for QID $questionId, skipping: $e');
        }
      }
      QuizzerLogger.logMessage('Successfully fetched module names for ${questionIdToModuleName.length} records');
    }
    
    // THIRD: Bulk populate caches based on cache locations
    QuizzerLogger.logMessage('Bulk populating caches based on cache locations...');
    
    for (int cacheLocation = 0; cacheLocation <= 7; cacheLocation++) {
      final recordsForCache = recordsByCacheLocation[cacheLocation];
      if (recordsForCache == null || recordsForCache.isEmpty) {
        continue;
      }
      
      QuizzerLogger.logMessage('Processing ${recordsForCache.length} records for cache_location: $cacheLocation...');
      
      // Handle different cache locations
      if (cacheLocation == 0) {
        // UnprocessedCache - bulk add for processing
        QuizzerLogger.logMessage('Bulk adding ${recordsForCache.length} records to UnprocessedCache...');
        await unprocessedCache.addRecords(recordsForCache, updateDatabaseLocation: false);
      } else if (cacheLocation == 1) {
        // QuestionQueueCache - bulk add to UnprocessedCache for re-evaluation
        QuizzerLogger.logMessage('Bulk adding ${recordsForCache.length} QuestionQueueCache records to UnprocessedCache for re-evaluation...');
        await unprocessedCache.addRecords(recordsForCache, updateDatabaseLocation: false);
      } else {
        // All other caches (2-7) - directly populate the respective cache
        await _directlyPopulateCache(
          cacheLocation, 
          recordsForCache, 
          questionIdToModuleName: questionIdToModuleName,
          nonCirculatingCache: nonCirculatingCache,
          moduleInactiveCache: moduleInactiveCache,
          dueDateBeyondCache: dueDateBeyondCache,
          dueDateWithinCache: dueDateWithinCache,
          pastDueCache: pastDueCache,
          eligibleQuestionsCache: eligibleQuestionsCache,
          circulatingCache: circulatingCache,
        );
      }
    }
    
    QuizzerLogger.logSuccess('Data cache initialization completed successfully.');
  } catch (e) {
    QuizzerLogger.logError('Error in fillDataCaches - $e');
    rethrow;
  }
}

/// Helper method to directly populate caches
Future<void> _directlyPopulateCache(
  int cacheLocation, 
  List<Map<String, dynamic>> records, 
  {
    Map<String, String>? questionIdToModuleName,
    required NonCirculatingQuestionsCache nonCirculatingCache,
    required ModuleInactiveCache moduleInactiveCache,
    required DueDateBeyond24hrsCache dueDateBeyondCache,
    required DueDateWithin24hrsCache dueDateWithinCache,
    required PastDueCache pastDueCache,
    required EligibleQuestionsCache eligibleQuestionsCache,
    required CirculatingQuestionsCache circulatingCache,
  }
) async {
  try {
    QuizzerLogger.logMessage('Directly populating cache location $cacheLocation with ${records.length} records...');
    
    switch (cacheLocation) {
      case 2: // PastDueCache
        await pastDueCache.addRecords(records, updateDatabaseLocation: false);
        break;
      case 3: // NonCirculatingQuestionsCache
        for (final record in records) {
          await nonCirculatingCache.addRecord(record, updateDatabaseLocation: false);
        }
        break;
      case 4: // ModuleInactiveCache
        // Use pre-fetched module names to avoid database access during initialization
        for (final record in records) {
          final String questionId = record['question_id'] as String;
          final String? moduleName = questionIdToModuleName?[questionId];
          if (moduleName != null) {
            await moduleInactiveCache.addRecord(record, updateDatabaseLocation: false, moduleName: moduleName);
          } else {
            QuizzerLogger.logWarning('No module name found for QID $questionId, skipping ModuleInactiveCache addition');
          }
        }
        break;
      case 5: // EligibleQuestionsCache
        for (final record in records) {
          await eligibleQuestionsCache.addRecord(record, updateDatabaseLocation: false);
        }
        break;
      case 6: // DueDateWithin24hrsCache
        for (final record in records) {
          await dueDateWithinCache.addRecord(record, updateDatabaseLocation: false);
        }
        break;
      case 7: // DueDateBeyond24hrsCache
        for (final record in records) {
          await dueDateBeyondCache.addRecord(record, updateDatabaseLocation: false);
        }
        break;
      default:
        QuizzerLogger.logWarning('Unknown cache location $cacheLocation, skipping');
    }
    
    QuizzerLogger.logSuccess('Successfully populated cache location $cacheLocation');
  } catch (e) {
    QuizzerLogger.logError('Error in _directlyPopulateCache - $e');
    rethrow;
  }
}
