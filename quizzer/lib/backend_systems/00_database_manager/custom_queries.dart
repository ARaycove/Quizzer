import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_module_activation_status_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';
import 'dart:convert';

/// Optimized query to fetch all module data, questions, and activation status in a single operation.
/// Returns a Map where keys are module names and values are complete module data objects.
Future<Map<String, Map<String, dynamic>>> getOptimizedModuleData(String userId) async {
  try {
    // Ensure all modules have activation status records before querying
    await ensureAllModulesHaveActivationStatus(userId);
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Executing optimized module data query for user: $userId');



    // Ensure tables exist
    await verifyModulesTable(db);
    await verifyUserModuleActivationStatusTable(db, userId);
    await verifyQuestionAnswerPairTable(db);

    // Single optimized query that aggregates all data by module using GROUP_CONCAT
    const String sql = '''
      SELECT 
        modules.module_name,
        modules.description,
        modules.primary_subject,
        modules.subjects,
        modules.related_concepts,
        modules.creation_date,
        modules.creator_id,
        user_module_activation_status.is_active,
        COUNT(question_answer_pairs.question_id) as total_questions,
        json_group_array(
          json_object(
            'question_id', question_answer_pairs.question_id,
            'question_type', question_answer_pairs.question_type,
            'question_elements', question_answer_pairs.question_elements,
            'answer_elements', question_answer_pairs.answer_elements,
            'options', question_answer_pairs.options,
            'correct_option_index', question_answer_pairs.correct_option_index,
            'correct_order', question_answer_pairs.correct_order,
            'index_options_that_apply', question_answer_pairs.index_options_that_apply
          )
        ) as questions_json
      FROM modules
      LEFT JOIN user_module_activation_status 
        ON modules.module_name = user_module_activation_status.module_name 
        AND user_module_activation_status.user_id = ?
      LEFT JOIN question_answer_pairs 
        ON modules.module_name = question_answer_pairs.module_name
      GROUP BY modules.module_name, modules.description, modules.primary_subject, 
               modules.subjects, modules.related_concepts, modules.creation_date, 
               modules.creator_id, user_module_activation_status.is_active
      ORDER BY modules.module_name
    ''';
    
    final List<Map<String, dynamic>> results = await db.rawQuery(sql, [userId]);

    // Process results - no iteration over individual questions
    final Map<String, Map<String, dynamic>> result = {};
    int totalQuestions = 0;
    
    for (final row in results) {
      final String moduleName = row['module_name'] as String;
      final int totalQuestionsForModule = row['total_questions'] as int? ?? 0;
      final String? questionsJson = row['questions_json'] as String?;
      
      // Parse questions JSON if it exists
      List<Map<String, dynamic>> questions = [];
      if (questionsJson != null && questionsJson.isNotEmpty) {
        try {
          // Parse the JSON array directly - no iteration over individual questions
          final List<dynamic> questionList = jsonDecode(questionsJson);
          // Filter out NULL values (questions with null question_id)
          questions = questionList
              .where((question) => question is Map<String, dynamic> && question['question_id'] != null)
              .cast<Map<String, dynamic>>()
              .toList();
          // Decode fields for each question
          for (final q in questions) {
            for (final field in ['question_elements', 'answer_elements', 'options']) {
              if (q[field] != null && q[field] is String && (q[field] as String).isNotEmpty) {
                try {
                  q[field] = jsonDecode(q[field]);
                } catch (e) {
                  QuizzerLogger.logError('Error decoding field $field for question ${q['question_id']}: $e');
                }
              }
            }
          }
        } catch (e) {
          QuizzerLogger.logError('Error parsing questions JSON for module $moduleName: $e');
        }
      }
      
      final Map<String, dynamic> module = {
        'module_name': moduleName,
        'description': row['description'],
        'primary_subject': row['primary_subject'],
        'subjects': row['subjects'],
        'related_concepts': row['related_concepts'],
        'creation_date': row['creation_date'],
        'creator_id': row['creator_id'],
        'is_active': (row['is_active'] as int? ?? 0) == 1,
        'total_questions': totalQuestionsForModule,
        'questions': questions,
      };
      
      result[moduleName] = module;
      totalQuestions += totalQuestionsForModule;
    }
    
    QuizzerLogger.logSuccess('Optimized module data query completed. Found ${result.length} modules with $totalQuestions total questions for user: $userId');
    return result;
  } catch (e) {
    QuizzerLogger.logError('Error in getOptimizedModuleData - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Optimized query to fetch data for a single module, including questions and activation status.
/// Returns a complete module data object for the specified module.
Future<Map<String, dynamic>?> getIndividualModuleData(String userId, String moduleName) async {
  try {
    // Ensure all modules have activation status records before querying
    await ensureAllModulesHaveActivationStatus(userId);
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Executing individual module data query for user: $userId, module: $moduleName');

    // Ensure tables exist
    await verifyModulesTable(db);
    await verifyUserModuleActivationStatusTable(db, userId);
    await verifyQuestionAnswerPairTable(db);

    // Single optimized query for the specific module
    const String sql = '''
      SELECT 
        modules.module_name,
        modules.description,
        modules.primary_subject,
        modules.subjects,
        modules.related_concepts,
        modules.creation_date,
        modules.creator_id,
        user_module_activation_status.is_active,
        COUNT(question_answer_pairs.question_id) as total_questions,
        json_group_array(
          json_object(
            'question_id', question_answer_pairs.question_id,
            'question_type', question_answer_pairs.question_type,
            'question_elements', question_answer_pairs.question_elements,
            'answer_elements', question_answer_pairs.answer_elements,
            'options', question_answer_pairs.options,
            'correct_option_index', question_answer_pairs.correct_option_index,
            'correct_order', question_answer_pairs.correct_order,
            'index_options_that_apply', question_answer_pairs.index_options_that_apply
          )
        ) as questions_json
      FROM modules
      LEFT JOIN user_module_activation_status 
        ON modules.module_name = user_module_activation_status.module_name 
        AND user_module_activation_status.user_id = ?
      LEFT JOIN question_answer_pairs 
        ON modules.module_name = question_answer_pairs.module_name
      WHERE modules.module_name = ?
      GROUP BY modules.module_name, modules.description, modules.primary_subject, 
               modules.subjects, modules.related_concepts, modules.creation_date, 
               modules.creator_id, user_module_activation_status.is_active
    ''';
    
    final List<Map<String, dynamic>> results = await db.rawQuery(sql, [userId, moduleName]);

    if (results.isEmpty) {
      QuizzerLogger.logWarning('No module found with name: $moduleName');
      return null;
    }

    final row = results.first;
    final int totalQuestionsForModule = row['total_questions'] as int? ?? 0;
    final String? questionsJson = row['questions_json'] as String?;
    
    // Parse questions JSON if it exists
    List<Map<String, dynamic>> questions = [];
    if (questionsJson != null && questionsJson.isNotEmpty) {
      try {
        // Parse the JSON array directly - no iteration over individual questions
        final List<dynamic> questionList = jsonDecode(questionsJson);
        // Filter out NULL values (questions with null question_id)
        questions = questionList
            .where((question) => question is Map<String, dynamic> && question['question_id'] != null)
            .cast<Map<String, dynamic>>()
            .toList();
        // Decode fields for each question
        for (final q in questions) {
          for (final field in ['question_elements', 'answer_elements', 'options']) {
            if (q[field] != null && q[field] is String && (q[field] as String).isNotEmpty) {
              try {
                q[field] = jsonDecode(q[field]);
              } catch (e) {
                QuizzerLogger.logError('Error decoding field $field for question ${q['question_id']}: $e');
              }
            }
          }
        }
      } catch (e) {
        QuizzerLogger.logError('Error parsing questions JSON for module $moduleName: $e');
      }
    }
    
    final Map<String, dynamic> module = {
      'module_name': moduleName,
      'description': row['description'],
      'primary_subject': row['primary_subject'],
      'subjects': row['subjects'],
      'related_concepts': row['related_concepts'],
      'creation_date': row['creation_date'],
      'creator_id': row['creator_id'],
      'is_active': (row['is_active'] as int? ?? 0) == 1,
      'total_questions': totalQuestionsForModule,
      'questions': questions,
    };
    
    QuizzerLogger.logSuccess('Individual module data query completed for module: $moduleName with $totalQuestionsForModule questions for user: $userId');
    return module;
  } catch (e) {
    QuizzerLogger.logError('Error in getIndividualModuleData - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}
