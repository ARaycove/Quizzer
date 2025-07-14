import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';

/// Renames a module by updating both the module record and all associated question records.
/// 
/// This function performs the following operations:
/// 1. Verifies the old module name exists
/// 2. Updates the module record with the new name
/// 3. Updates all question records that reference the old module name
/// 
/// Parameters:
/// - oldModuleName: The current name of the module to rename
/// - newModuleName: The new name for the module
/// 
/// Returns:
/// - true if the rename operation was successful
/// - false if the operation failed or the old module doesn't exist
/// 
/// Throws:
/// - Exception if database operations fail
Future<bool> renameModule({
  required String oldModuleName,
  required String newModuleName,
}) async {
  QuizzerLogger.logMessage('Starting module rename operation: "$oldModuleName" -> "$newModuleName"');
  
  try {
    // Step 1: Verify the old module exists
    QuizzerLogger.logMessage('Step 1: Verifying old module exists');
    final Map<String, dynamic>? existingModule = await getModule(oldModuleName);
    if (existingModule == null) {
      QuizzerLogger.logError('Cannot rename module: Module "$oldModuleName" does not exist');
      return false;
    }
    QuizzerLogger.logSuccess('Verified old module exists: $oldModuleName');
    
    // Step 2: Check if new module name already exists
    QuizzerLogger.logMessage('Step 2: Checking if new module name already exists');
    final Map<String, dynamic>? conflictingModule = await getModule(newModuleName);
    if (conflictingModule != null) {
      QuizzerLogger.logError('Cannot rename module: Module "$newModuleName" already exists');
      return false;
    }
    QuizzerLogger.logSuccess('Verified new module name is available: $newModuleName');
    
    // Step 3: Get all questions for the old module BEFORE renaming
    QuizzerLogger.logMessage('Step 3: Getting all questions for the old module');
    final List<Map<String, dynamic>> questionsToUpdate = await getQuestionRecordsForModule(oldModuleName);
    QuizzerLogger.logSuccess('Found ${questionsToUpdate.length} questions to update');
    
    // Step 4: Update the module record with new name
    QuizzerLogger.logMessage('Step 4: Updating module record with new name');
    await updateModule(
      name: oldModuleName,
      newName: newModuleName,
      description: existingModule['description'] as String?,
      primarySubject: existingModule['primary_subject'] as String?,
      subjects: (existingModule['subjects'] as List<dynamic>?)?.cast<String>(),
      relatedConcepts: (existingModule['related_concepts'] as List<dynamic>?)?.cast<String>(),
    );
    
    // Step 5: Update all question records with the new module name
    QuizzerLogger.logMessage('Step 5: Updating question records with new module name');
    int updatedQuestionsCount = 0;
    for (final question in questionsToUpdate) {
      final String questionId = question['question_id'] as String;
      try {
        await editQuestionAnswerPair(
          questionId: questionId,
          moduleName: newModuleName,
        );
        updatedQuestionsCount++;
      } catch (e) {
        QuizzerLogger.logError('Failed to update question $questionId: $e');
        throw Exception('Failed to update question $questionId: $e');
      }
    }
    QuizzerLogger.logSuccess('Updated $updatedQuestionsCount question records');
    
    QuizzerLogger.logMessage('Step 6: Module rename completed');
    
    QuizzerLogger.logSuccess('✅ Module rename operation completed successfully');
    QuizzerLogger.logValue('  Old module name: $oldModuleName');
    QuizzerLogger.logValue('  New module name: $newModuleName');
    QuizzerLogger.logValue('  Question records updated: $updatedQuestionsCount');
    
    return true;
    
  } catch (e) {
    QuizzerLogger.logError('Module rename operation failed: $e');
    return false;
  }
}

/// Validates if a module can be renamed to the specified new name.
/// 
/// This function checks:
/// 1. If the old module name exists
/// 2. If the new module name is different from the old one
/// 3. If the new module name doesn't already exist
/// 4. If the new module name is valid (not empty, reasonable length, etc.)
/// 
/// Parameters:
/// - oldModuleName: The current name of the module to rename
/// - newModuleName: The proposed new name for the module
/// 
/// Returns:
/// - Map with validation results including:
///   - 'isValid': bool indicating if the rename is valid
///   - 'errorMessage': string describing the validation error (if any)
Future<Map<String, dynamic>> validateModuleRename({
  required String oldModuleName,
  required String newModuleName,
}) async {
  QuizzerLogger.logMessage('Validating module rename: "$oldModuleName" -> "$newModuleName"');
  
  try {
    // Check if new module name is empty
    if (newModuleName.trim().isEmpty) {
      return {
        'isValid': false,
        'errorMessage': 'New module name cannot be empty',
      };
    }
    
    // Check if new module name is too long (reasonable limit)
    if (newModuleName.length > 100) {
      return {
        'isValid': false,
        'errorMessage': 'New module name is too long (maximum 100 characters)',
      };
    }
    
    // Check if old and new names are the same
    if (oldModuleName.trim() == newModuleName.trim()) {
      return {
        'isValid': false,
        'errorMessage': 'New module name must be different from the current name',
      };
    }
    
    // Check if old module exists
    final Map<String, dynamic>? existingModule = await getModule(oldModuleName);
    if (existingModule == null) {
      return {
        'isValid': false,
        'errorMessage': 'Module "$oldModuleName" does not exist',
      };
    }
    
    // Check if new module name already exists
    final Map<String, dynamic>? conflictingModule = await getModule(newModuleName);
    if (conflictingModule != null) {
      return {
        'isValid': false,
        'errorMessage': 'Module "$newModuleName" already exists',
      };
    }
    
    QuizzerLogger.logSuccess('Module rename validation passed');
    return {
      'isValid': true,
      'errorMessage': null,
    };
    
  } catch (e) {
    QuizzerLogger.logError('Error during module rename validation: $e');
    return {
      'isValid': false,
      'errorMessage': 'Validation error: $e',
    };
  }
}
