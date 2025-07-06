import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/modules_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

Future<Map<String, dynamic>> handleLoadModules(Map<String, dynamic> data) async {
  try {
    final userId = data['userId'] as String;
    Map<String, dynamic> result = {
      'modules': [],
      'activationStatus': {},
    };
    
    // Get all modules first - table function handles its own database access
    final List<Map<String, dynamic>> modules = await getAllModules();
    QuizzerLogger.logMessage('handleLoadModules: Found ${modules.length} modules');
    
    // Add questions data to each module dynamically
    final List<Map<String, dynamic>> modulesWithQuestions = [];
    for (final module in modules) {
      final String moduleName = module['module_name'] as String;
      QuizzerLogger.logMessage('handleLoadModules: Processing module: $moduleName');
      
      // Get full question records for this module using indexed query - table function handles its own database access
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
    
    // TODO: Module activation status is currently stored as a JSON string in the user profile table,
    // which is inefficient and not best practice. This should be refactored to use a dedicated
    // user_module_activation_status_table.dart with the following structure:
    // - module_name (TEXT)
    // - user_id (TEXT) 
    // - is_activated (INTEGER)
    // This will improve performance and follow proper database normalization practices.
    
    return result;
  } catch (e) {
    QuizzerLogger.logError('Error in handleLoadModules - $e');
    rethrow;
  }
}

Future<bool> handleModuleActivation(Map<String, dynamic> data) async {
  try {
    final userId = data['userId'] as String;
    final moduleName = data['moduleName'] as String;
    final isActive = data['isActive'] as bool;
    
    QuizzerLogger.logMessage('Starting module activation process for user $userId, module $moduleName, isActive: $isActive');
    
    // TODO: This function will need to be updated once we implement the new user_module_activation_status_table.dart.
    // Instead of updating a JSON string in the user profile, we'll insert/update records in the dedicated table
    // with fields: module_name, user_id, is_activated. This will improve performance and follow proper database design.
    
    QuizzerLogger.logMessage('Updating module activation status');
    final bool success = await updateModuleActivationStatus(userId, moduleName, isActive);
    QuizzerLogger.logMessage('Module activation status update ${success ? 'succeeded' : 'failed'}');
    
    return success;
  } catch (e) {
    QuizzerLogger.logError('Error in module activation: $e');
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