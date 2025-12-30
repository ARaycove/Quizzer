import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart' as table_helper;
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/media_sync_status_table.dart';
import 'package:path/path.dart' as path;
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/06_question_answer_pair_management/question_validator.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/sql_table.dart';

class QuestionAnswerPairsTable extends SqlTable {
  // ==================================================
  // ----- Singleton and Constants -----
  // ==================================================
  static final QuestionAnswerPairsTable _instance = QuestionAnswerPairsTable._internal();
  factory QuestionAnswerPairsTable() => _instance;
  QuestionAnswerPairsTable._internal();

  @override
  bool get isTransient => false;

  @override
  bool requiresInboundSync = true;

  @override
  dynamic get additionalFiltersForInboundSync => null;

  @override
  bool get useLastLoginForInboundSync => false;
  // ==================================================
  // ----- Schema Definition Implementation -----
  // ==================================================
  @override
  String get tableName => 'question_answer_pairs';

  @override
  List<String> get primaryKeyConstraints => ['question_id'];
  
  @override
  List<Map<String, String>> get expectedColumns => [
    {'name': 'question_id',              'type': 'TEXT KEY'},
    {'name': 'time_stamp',               'type': 'TEXT'},
    {'name': 'question_elements',        'type': 'TEXT'},
    {'name': 'answer_elements',          'type': 'TEXT'},
    {'name': 'ans_flagged',              'type': 'INTEGER'},
    {'name': 'ans_contrib',              'type': 'TEXT'},
    {'name': 'qst_contrib',              'type': 'TEXT'},
    {'name': 'qst_reviewer',             'type': 'TEXT'},
    {'name': 'has_been_reviewed',        'type': 'INTEGER'},
    {'name': 'flag_for_removal',         'type': 'INTEGER'},
    {'name': 'topics',                   'type': 'TEXT'}, // TODO: Implement topics handling will be formatted as: {topic_id: probability}
    {'name': 'question_type',            'type': 'TEXT'},
    {'name': 'options',                  'type': 'TEXT'},
    {'name': 'correct_option_index',     'type': 'INTEGER'},
    {'name': 'correct_order',            'type': 'TEXT'},
    {'name': 'index_options_that_apply', 'type': 'TEXT'},
    {'name': 'answers_to_blanks',        'type': 'TEXT'},
    {'name': 'has_been_synced',          'type': 'INTEGER DEFAULT 0'},
    {'name': 'edits_are_synced',         'type': 'INTEGER DEFAULT 0'},
    {'name': 'last_modified_timestamp',  'type': 'TEXT'},
    {'name': 'has_media',                'type': 'INTEGER DEFAULT NULL'},
    {'name': 'question_vector',          'type': 'TEXT DEFAULT NULL'},
    {'name': 'k_nearest_neighbors',      'type': 'TEXT DEFAULT NULL'}
  ];

  // ==================================================
  // ----- CRUD operations -----
  // The generic CRUD methods (upsertRecord, deleteRecord, getRecord) are inherited.
  // ==================================================

  // ==================================================
  // ----- Validation Logic For Records (Abstract Implementation) -----
  // ==================================================
  @override
  Future<bool> validateRecord(Map<String, dynamic> dataToInsert) async {
    final String? questionId = dataToInsert['question_id'] as String?;
    final String? questionType = dataToInsert['question_type'] as String?;
    
    // Get the raw values - they could be either decoded (List/Map) or encoded (String)
    final dynamic questionElementsRaw = dataToInsert['question_elements'];
    final dynamic answerElementsRaw = dataToInsert['answer_elements'];

    if (questionId == null || questionType == null || 
        questionElementsRaw == null || answerElementsRaw == null) {
      QuizzerLogger.logError('Validation failed for question $questionId: Missing critical fields.');
      return false;
    }
    
    try {
      // Step 1: Convert to strings for checkCompletionStatus using the helper method
      String questionElementsJson;
      String answerElementsJson;
      
      if (questionElementsRaw is String) {
        questionElementsJson = questionElementsRaw;
      } else {
        // Already decoded - encode back to string using the fucking helper method
        questionElementsJson = table_helper.encodeValueForDB(questionElementsRaw) as String;
      }
      
      if (answerElementsRaw is String) {
        answerElementsJson = answerElementsRaw;
      } else {
        // Already decoded - encode back to string using the fucking helper method
        answerElementsJson = table_helper.encodeValueForDB(answerElementsRaw) as String;
      }
      
      // Step 2: Check for basic completion and non-empty content using the dedicated validator
      if (QuestionValidator.checkCompletionStatus(questionElementsJson, answerElementsJson) != 1) {
        return false;
      }

      // Step 3: Get decoded elements for structural validation
      List<Map<String, dynamic>> questionElements;
      List<Map<String, dynamic>> answerElements;
      
      if (questionElementsRaw is String) {
        questionElements = List<Map<String, dynamic>>.from(table_helper.decodeValueFromDB(questionElementsRaw));
      } else {
        questionElements = List<Map<String, dynamic>>.from(questionElementsRaw);
      }
      
      if (answerElementsRaw is String) {
        answerElements = List<Map<String, dynamic>>.from(table_helper.decodeValueFromDB(answerElementsRaw));
      } else {
        answerElements = List<Map<String, dynamic>>.from(answerElementsRaw);
      }
      
      QuestionValidator.validateQuestionEntry(
        questionElements: questionElements,
        answerElements: answerElements,
      );

      // Handle options - they could be decoded List<Map> or encoded String
      final dynamic optionsRaw = dataToInsert['options'];
      List<Map<String, dynamic>> options = [];
      
      if (optionsRaw != null) {
        if (optionsRaw is String) {
          options = List<Map<String, dynamic>>.from(table_helper.decodeValueFromDB(optionsRaw));
        } else if (optionsRaw is List) {
          options = List<Map<String, dynamic>>.from(optionsRaw);
        }
      }

      // Step 4: Validate options if present (for question types that use them)
      if (questionType == 'multiple_choice' || 
          questionType == 'select_all_that_apply' || 
          questionType == 'sort_order') {
        if (options.isNotEmpty) {
          QuestionValidator.validateQuestionOptions(options);
        }
      }
      
      // ---------------------------------
      // Question Type specific Validation
      // ---------------------------------
      switch (questionType) {
        case 'multiple_choice':
          final dynamic correctOptionIndexRaw = dataToInsert['correct_option_index'];
          final int correctOptionIndex = (correctOptionIndexRaw is int) 
              ? correctOptionIndexRaw 
              : int.tryParse(correctOptionIndexRaw.toString()) ?? -1;
              
          if (correctOptionIndex < 0) {
            throw Exception('Correct option index cannot be negative.');
          }
          if (correctOptionIndex >= options.length) {
            throw Exception('Correct option index $correctOptionIndex is out of range. Options list has ${options.length} elements.');
          }
          break;
          
        case 'select_all_that_apply':
          final dynamic indexOptionsThatApplyRaw = dataToInsert['index_options_that_apply'];
          List<int> indexOptionsThatApply = [];
          
          if (indexOptionsThatApplyRaw != null) {
            if (indexOptionsThatApplyRaw is String) {
              indexOptionsThatApply = List<int>.from(table_helper.decodeValueFromDB(indexOptionsThatApplyRaw));
            } else if (indexOptionsThatApplyRaw is List) {
              indexOptionsThatApply = List<int>.from(indexOptionsThatApplyRaw);
            }
          }
          
          if (indexOptionsThatApply.isEmpty) {
            throw Exception('At least one option must be selected for select all that apply questions.');
          }
          
          for (int i = 0; i < indexOptionsThatApply.length; i++) {
            final index = indexOptionsThatApply[i];
            if (index < 0) {
              throw Exception('Option index at position $i cannot be negative.');
            }
            if (index >= options.length) {
              throw Exception('Option index $index at position $i is out of range. Options list has ${options.length} elements.');
            }
          }
          break;

        case 'true_false':
          final dynamic correctOptionIndexRaw = dataToInsert['correct_option_index'];
          final int correctOptionIndex = (correctOptionIndexRaw is int) 
              ? correctOptionIndexRaw 
              : int.tryParse(correctOptionIndexRaw.toString()) ?? -1;
              
          if (correctOptionIndex < 0 || correctOptionIndex > 1) {
            throw Exception('Correct option index must be 0 (True) or 1 (False), got: $correctOptionIndex');
          }
          break;

        case 'sort_order':
          if (options.length < 2) {
            throw Exception('Sort order questions must have at least 2 options to sort.');
          }
          break;

        case 'fill_in_the_blank':
          final dynamic answersToBlanksRaw = dataToInsert['answers_to_blanks'];
          List<Map<String, List<String>>> answersToBlanks = [];
          
          if (answersToBlanksRaw != null) {
            if (answersToBlanksRaw is String) {
              answersToBlanks = List<Map<String, List<String>>>.from(table_helper.decodeValueFromDB(answersToBlanksRaw));
            } else if (answersToBlanksRaw is List) {
              answersToBlanks = List<Map<String, List<String>>>.from(answersToBlanksRaw);
            }
          }
          
          // Fill in the blank specific validation
          if (answersToBlanks.isEmpty) {
            throw Exception('Fill in the blank questions must have at least one answer group.');
          }

          // Ensure question_elements has n blank elements where n is the length of answers_to_blanks
          final int blankCount = questionElements.where((element) => element['type'] == 'blank').length;
          if (blankCount != answersToBlanks.length) {
            throw Exception('Number of blank elements ($blankCount) does not match number of answer groups (${answersToBlanks.length})');
          }

          // Validate each answer group has at least one answer
          for (int i = 0; i < answersToBlanks.length; i++) {
            final answerGroup = answersToBlanks[i];
            if (answerGroup.isEmpty) {
              throw Exception('Answer group at index $i cannot be empty.');
            }
          }
          break;
          
        default:
          break;
      }
      return true;
    } catch (e) {
      // This catch block handles exceptions thrown by structural validation
      QuizzerLogger.logError('Structural validation failed for question $questionId: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> finishRecord(Map<String, dynamic> dataToInsert) async{
    final bool recordHasMedia = await QuestionValidator.hasMediaCheck(dataToInsert);
    dataToInsert['has_media'] = recordHasMedia ? 1 : 0;
    return dataToInsert;
  }


  // ==================================================
  // ----- Sync Operations Overrides/Wrappers -----
  // The generic getUnsyncedRecords and batchUpsertRecord are inherited.

  // The previous updateQuestionSyncFlags wrapper has been removed to rely on 
  // the abstract class's updateSyncFlags, improving abstraction purity.

  // ==================================================
  // ----- Media Related (Specialized Logic) -----
  // ==================================================

  /// Takes a set of filenames and attempts to register each in the media_sync_status table.
  Future<void> registerMediaFiles(Set<String> filenames, {String? qidForLogging}) async {
    final String logCtx = qidForLogging != null ? '(Associated QID: $qidForLogging)' : '';
    QuizzerLogger.logMessage('Attempting to register ${filenames.length} media files $logCtx');

    if (filenames.isEmpty) {
      QuizzerLogger.logMessage('No filenames provided to register $logCtx.');
      return;
    }

    for (final filename in filenames) {
      if (filename.trim().isEmpty) {
        QuizzerLogger.logWarning('Skipping empty media filename during registration $logCtx.');
        continue;
      }
      
      String fileExtension = path.extension(filename);
      if (fileExtension.startsWith('.')) {
        fileExtension = fileExtension.substring(1);
      }

      QuizzerLogger.logMessage('Attempting to ensure media sync status for: $filename $logCtx');
      try {
        // Assume insertMediaSyncStatus is a method provided by the imported media_sync_status_table.dart
        await MediaSyncStatusTable().upsertRecord({
          'file_name': filename,
          'file_extension': fileExtension,
          // Other fields like exists_locally and exists_externally will use their DEFAULT NULL/0 values
        });
        QuizzerLogger.logSuccess('Successfully ensured media sync status for: $filename $logCtx.');
      } on DatabaseException catch (e) {
        if (e.isUniqueConstraintError() || 
            (e.toString().toLowerCase().contains('unique constraint failed')) ||
            (e.toString().contains('code 1555')) ||
            (e.toString().contains('code 2067'))) {
          QuizzerLogger.logMessage('Media sync status for $filename $logCtx already exists or was concurrently inserted. Skipping.');
        } else {
          QuizzerLogger.logError('DatabaseException while ensuring media sync status for $filename $logCtx: $e');
          rethrow;
        }
      } catch (e) {
        QuizzerLogger.logError('Unexpected error while ensuring media sync status for $filename $logCtx: $e');
        rethrow;
      }
    }
    QuizzerLogger.logMessage('Finished attempting to register media files $logCtx.');
  }

  /// Fetches all question-answer pairs where the 'has_media' status is NULL.
  Future<List<Map<String, dynamic>>> getPairsWithNullMediaStatus() async {
    var db = await DatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access for getPairsWithNullMediaStatus.');
    }
    try {
      QuizzerLogger.logMessage('Fetching question-answer pairs with NULL has_media status...');
      final List<Map<String, dynamic>> results = await table_helper.queryAndDecodeDatabase(
        tableName,
        db,
        where: 'has_media IS NULL',
      );
      return results;
    } catch (e) {
      QuizzerLogger.logError('Error getting pairs with null media status - $e');
      rethrow;
    } finally {
      DatabaseMonitor().releaseDatabaseAccess();
    }
  }

  /// Processes question-answer pairs with NULL 'has_media' status.
  Future<void> processNullMediaStatusPairs() async {
    try {
      final List<Map<String, dynamic>> pairsToProcess = await getPairsWithNullMediaStatus();
      final db = await DatabaseMonitor().requestDatabaseAccess();
      if (db == null) {
        throw Exception('Failed to acquire database access');
      }
      QuizzerLogger.logMessage('Starting to process pairs with NULL has_media status for direct update.');
      
      if (pairsToProcess.isEmpty) {
        QuizzerLogger.logMessage('No pairs found with NULL has_media status to process.');
        return;
      }

      QuizzerLogger.logValue('Found ${pairsToProcess.length} pairs to process for has_media flag.');

      for (final record in pairsToProcess) {
        final String? questionId = record['question_id'] as String?;
        if (questionId == null || questionId.isEmpty) {
          QuizzerLogger.logWarning('Skipping record with NULL or empty question_id during NULL media status processing: $record');
          continue;
        }

        final bool mediaFound = await QuestionValidator.hasMediaCheck(record);
        QuizzerLogger.logValue('Processing QID $questionId for has_media flag update. Media found by hasMediaCheck: $mediaFound');

        final int rowsAffected = await table_helper.updateRawData(
          tableName,
          {'has_media': mediaFound ? 1 : 0},
          'question_id = ?',
          [questionId],
          db,
        );

      if (rowsAffected > 0) {
        QuizzerLogger.logMessage('Successfully updated has_media flag for QID $questionId to ${mediaFound ? 1 : 0}.');
      } else {
        QuizzerLogger.logWarning('Failed to update has_media flag for QID $questionId. Record might have been deleted or question_id changed.');
      }
    }
    QuizzerLogger.logMessage('Finished processing pairs with NULL has_media status.');
    } catch (e) {
      QuizzerLogger.logError('Error processing null media status pairs - $e');
      rethrow;
    } finally {
      DatabaseMonitor().releaseDatabaseAccess();
    }
  }
}