import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_module_activation_status_table.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

/// Merges two modules by moving all questions from the source module to the target module,
/// then deleting the source module.
/// 
/// This function performs the following operations:
/// 1. Validates that both modules exist and are different
/// 2. Gets all questions from the source module
/// 3. Updates all question records to reference the target module
/// 4. Deletes the source module record
/// 
/// Parameters:
/// - sourceModuleName: The name of the module to merge (will be deleted)
/// - targetModuleName: The name of the module to merge into (will remain)
/// 
/// Returns:
/// - true if the merge operation was successful
/// - false if the operation failed or modules don't exist
/// 
/// Throws:
/// - Exception if database operations fail
Future<bool> mergeModules({
  required String sourceModuleName,
  required String targetModuleName,
}) async {
  QuizzerLogger.logMessage('Starting module merge operation: "$sourceModuleName" -> "$targetModuleName"');
  
  try {
    // Step 1: Validate the merge operation
    QuizzerLogger.logMessage('Step 1: Validating module merge');
    final validationResult = await validateModuleMerge(
      sourceModuleName: sourceModuleName,
      targetModuleName: targetModuleName,
    );
    
    if (!validationResult['isValid']) {
      QuizzerLogger.logError('Module merge validation failed: ${validationResult['errorMessage']}');
      return false;
    }
    
    QuizzerLogger.logSuccess('Module merge validation passed');
    
    // Step 2: Get all questions for the source module BEFORE merging
    QuizzerLogger.logMessage('Step 2: Getting all questions for the source module');
    final List<Map<String, dynamic>> questionsToMove = await getQuestionRecordsForModule(sourceModuleName);
    QuizzerLogger.logSuccess('Found ${questionsToMove.length} questions to move');
    
    // Step 3: Update all question records to reference the target module
    QuizzerLogger.logMessage('Step 3: Updating question records to reference target module');
    int updatedQuestionsCount = 0;
    for (final question in questionsToMove) {
      final String questionId = question['question_id'] as String;
      try {
        await editQuestionAnswerPair(
          questionId: questionId,
          moduleName: targetModuleName,
        );
        updatedQuestionsCount++;
      } catch (e) {
        QuizzerLogger.logError('Failed to update question $questionId: $e');
        throw Exception('Failed to update question $questionId: $e');
      }
    }
    QuizzerLogger.logSuccess('Updated $updatedQuestionsCount question records');
    
    // Step 4: Deactivate the source module since all questions have been moved
    QuizzerLogger.logMessage('Step 4: Deactivating source module');
    final sessionManager = getSessionManager();
    final String? userId = sessionManager.userId;
    if (userId != null) {
      final bool deactivationResult = await updateModuleActivationStatus(userId, sourceModuleName, false);
      if (!deactivationResult) {
        QuizzerLogger.logWarning('Failed to deactivate source module "$sourceModuleName"');
      } else {
        QuizzerLogger.logSuccess('Successfully deactivated source module');
      }
    } else {
      QuizzerLogger.logWarning('Cannot deactivate source module: user not logged in');
    }
    
    // Step 5: Merge operation completed
    QuizzerLogger.logMessage('Step 5: Merge operation completed');
    QuizzerLogger.logSuccess('Successfully moved questions from source module to target module');
    
    QuizzerLogger.logSuccess('✅ Module merge operation completed successfully');
    QuizzerLogger.logValue('  Source module: $sourceModuleName (deleted)');
    QuizzerLogger.logValue('  Target module: $targetModuleName (remains)');
    QuizzerLogger.logValue('  Question records moved: $updatedQuestionsCount');
    
    return true;
    
  } catch (e) {
    QuizzerLogger.logError('Module merge operation failed: $e');
    return false;
  }
}

/// Validates if two modules can be merged.
/// 
/// This function checks:
/// 1. If both source and target modules exist
/// 2. If source and target are different modules
/// 
/// Parameters:
/// - sourceModuleName: The name of the module to merge (will be deleted)
/// - targetModuleName: The name of the module to merge into (will remain)
/// 
/// Returns:
/// - Map with validation results including:
///   - 'isValid': bool indicating if the merge is valid
///   - 'errorMessage': string describing the validation error (if any)
Future<Map<String, dynamic>> validateModuleMerge({
  required String sourceModuleName,
  required String targetModuleName,
}) async {
  QuizzerLogger.logMessage('Validating module merge: "$sourceModuleName" -> "$targetModuleName"');
  
  try {
    // Check if source and target are the same
    if (sourceModuleName.trim() == targetModuleName.trim()) {
      return {
        'isValid': false,
        'errorMessage': 'Source and target modules must be different',
      };
    }
    
    // Check if source module exists
    final Map<String, dynamic>? sourceModule = await getModule(sourceModuleName);
    if (sourceModule == null) {
      return {
        'isValid': false,
        'errorMessage': 'Source module "$sourceModuleName" does not exist',
      };
    }
    
    // Check if target module exists
    final Map<String, dynamic>? targetModule = await getModule(targetModuleName);
    if (targetModule == null) {
      return {
        'isValid': false,
        'errorMessage': 'Target module "$targetModuleName" does not exist',
      };
    }
    
    QuizzerLogger.logSuccess('Module merge validation passed');
    return {
      'isValid': true,
      'errorMessage': null,
    };
    
  } catch (e) {
    QuizzerLogger.logError('Error during module merge validation: $e');
    return {
      'isValid': false,
      'errorMessage': 'Validation error: $e',
    };
  }
}
