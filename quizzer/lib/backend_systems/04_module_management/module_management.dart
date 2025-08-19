import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/answer_validation/text_analysis_tools.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';

Future<Map<String, dynamic>> handleLoadModules(Map<String, dynamic> data) async {
  try {
    final userId = data['userId'] as String;
    Map<String, dynamic> result = {
      'modules': [],
      'activationStatus': {},
    };
    
    // Get all modules first
    final db = getDatabaseMonitor().requestDatabaseAccess();
    final List<Map<String, dynamic>> modules = await getAllModules(db);
    getDatabaseMonitor().releaseDatabaseAccess();

    QuizzerLogger.logMessage('handleLoadModules: Found ${modules.length} modules');
    
    // Add questions data to each module dynamically
    final List<Map<String, dynamic>> modulesWithQuestions = [];
    for (final module in modules) {
      final String moduleName = module['module_name'] as String;
      QuizzerLogger.logMessage('handleLoadModules: Processing module: $moduleName');
      
      // Get full question records for this module using indexed query
      final List<Map<String, dynamic>> questionRecords = await getQuestionRecordsForModule(moduleName);
      QuizzerLogger.logMessage('handleLoadModules: Found ${questionRecords.length} questions for module: $moduleName');
      
      // Create enhanced module data with questions
      final Map<String, dynamic> enhancedModule = Map<String, dynamic>.from(module);
      enhancedModule['questions'] = questionRecords;
      enhancedModule['total_questions'] = questionRecords.length; // Calculate count from list length
      
      modulesWithQuestions.add(enhancedModule);
    }
    
    QuizzerLogger.logMessage('handleLoadModules: Returning ${modulesWithQuestions.length} modules with questions');
    
    result['modules'] = modulesWithQuestions;
    result['activationStatus'] = await getModuleActivationStatus(userId);
    
    return result;
  } catch (e) {
    QuizzerLogger.logError('Error in handleLoadModules - $e');
    rethrow;
  }
}

Future<bool> handleUpdateModuleDescription(Map<String, dynamic> data) async {
  try {
    final moduleName = data['moduleName'] as String;
    final newDescription = data['description'] as String;
    
    QuizzerLogger.logMessage('Starting module description update for module: $moduleName');
    
    QuizzerLogger.logMessage('Updating module description in database');
    await updateModule(name: moduleName, description: newDescription);
    QuizzerLogger.logMessage('Module description update successful');
    
    return true;
  } catch (e) {
    QuizzerLogger.logError('Error updating module description: $e');
    rethrow;
  }
}

/// Validates that a module exists, creating it if it doesn't.
/// This function ensures that a module with the given name exists in the database.
/// If the module doesn't exist, it creates a new module with default values.
/// 
/// Parameters:
/// - moduleName: The name of the module to validate/create
/// - creatorId: The ID of the user creating the module (optional, defaults to 'system')
/// 
/// Returns:
/// - true if the module exists or was successfully created, false otherwise
Future<bool> validateModuleExists(String moduleName, {String? creatorId}) async {
  try {
    QuizzerLogger.logMessage('Validating module exists: $moduleName');
    
    // Normalize the module name before checking if it exists
    final String normalizedModuleName = await normalizeString(moduleName);
    QuizzerLogger.logMessage('Normalized module name: $normalizedModuleName');
    
    // First, try to get the module using the normalized name
    final Map<String, dynamic>? existingModule = await getModule(normalizedModuleName);
    
    if (existingModule != null) {
      QuizzerLogger.logMessage('Module $normalizedModuleName already exists');
      return true;
    }
    
    // Module doesn't exist, create it with default values using normalized name
    QuizzerLogger.logMessage('Module $normalizedModuleName does not exist, creating it...');
    
    final String defaultDescription = 'Module for $normalizedModuleName';
    const String defaultPrimarySubject = 'General';
    final List<String> defaultSubjects = ['General'];
    final List<String> defaultRelatedConcepts = ['General'];
    final String moduleCreatorId = creatorId ?? 'system';
    
    await insertModule(
      name: normalizedModuleName,
      description: defaultDescription,
      primarySubject: defaultPrimarySubject,
      subjects: defaultSubjects,
      relatedConcepts: defaultRelatedConcepts,
      creatorId: moduleCreatorId,
    );
    
    QuizzerLogger.logSuccess('Successfully created module: $normalizedModuleName');
    return true;
  } catch (e) {
    QuizzerLogger.logError('Error validating/creating module $moduleName: $e');
    return false;
  }
} 