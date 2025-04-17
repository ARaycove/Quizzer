/*
TODO: Module Building Process Optimization
Current Implementation:
- Module building runs in a separate isolate to prevent UI blocking
- This is a temporary solution to maintain UI responsiveness
- Process runs after each question addition and during app initialization
TODO: Develop a plan to optimize the module building process
*/

import 'package:quizzer/features/modules/database/modules_table.dart';
import 'package:quizzer/features/question_management/database/question_answer_pairs_table.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';
import 'dart:isolate';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Validates and builds module records based on question-answer pairs
/// This function:
/// 1. Gathers unique module names from question-answer pairs
/// 2. Validates existence of module records
/// 3. Ensures module names are lowercase
/// 4. Builds subject field from question subjects
/// 5. Builds concept field from question concepts
/// 6. Builds question_ids field from module questions
/// 7. Determines primary subject based on most common subject

/// Gets a unique set of module names from the question-answer pairs table
/// Returns a Set<String> containing all unique module names found in the table
Future<Set<String>> getUniqueModuleNames(List<Map<String, dynamic>> pairs) async {
  QuizzerLogger.logMessage('Starting to gather unique module names from question-answer pairs');
  
  // Extract unique module names
  final Set<String> uniqueModuleNames = pairs
      .map((pair) => pair['module_name'] as String)
      .where((name) => name.isNotEmpty)
      .toSet();
  
  QuizzerLogger.logMessage('Found ${uniqueModuleNames.length} unique module names');
  QuizzerLogger.logSuccess('Successfully gathered unique module names');
  
  return uniqueModuleNames;
}

// ==========================================

/// Gets a unique set of subjects for a specific module and determines the primary subject
/// Returns a Map containing:
/// - 'subjects': Set<String> of unique subjects
/// - 'primary_subject': String of the most common subject or "no_primary_subject"
Map<String, dynamic> getUniqueSubjectsForModule(List<Map<String, dynamic>> pairs, String moduleName) {
  QuizzerLogger.logMessage('Getting unique subjects for module: $moduleName');
  
  // Get all subjects for this module
  final List<String> allSubjects = pairs
      .where((pair) => pair['module_name'] == moduleName && pair['subjects'] != null)
      .map((pair) => pair['subjects'] as String)
      .where((subjects) => subjects.isNotEmpty)
      .expand((subjects) => subjects.split(','))
      .toList();
  
  // Get unique subjects
  final Set<String> uniqueSubjects = allSubjects.toSet();
  
  // Count occurrences of each subject
  final Map<String, int> subjectCounts = {};
  for (var subject in allSubjects) {
    subjectCounts[subject] = (subjectCounts[subject] ?? 0) + 1;
  }
  
  // Determine primary subject
  String primarySubject = "no_primary_subject";
  if (subjectCounts.isNotEmpty) {
    primarySubject = subjectCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
  
  QuizzerLogger.logMessage('Found ${uniqueSubjects.length} unique subjects for module: $moduleName');
  QuizzerLogger.logMessage('Primary subject determined to be: $primarySubject');
  QuizzerLogger.logSuccess('Successfully gathered subjects and determined primary subject');
  
  return {
    'subjects': uniqueSubjects,
    'primary_subject': primarySubject,
  };
}

// ==========================================

/// Gets a unique set of concepts for a specific module
/// Returns a Set<String> containing all unique concepts for the given module
Set<String> getUniqueConceptsForModule(List<Map<String, dynamic>> pairs, String moduleName) {
  QuizzerLogger.logMessage('Getting unique concepts for module: $moduleName');
  
  final Set<String> uniqueConcepts = pairs
      .where((pair) => pair['module_name'] == moduleName && pair['concept'] != null)
      .map((pair) => pair['concept'] as String)
      .where((concept) => concept.isNotEmpty)
      .toSet();
  
  QuizzerLogger.logMessage('Found ${uniqueConcepts.length} unique concepts for module: $moduleName');
  QuizzerLogger.logSuccess('Successfully gathered unique concepts');
  
  return uniqueConcepts;
}

// ==========================================

/// Gets a list of question IDs for a specific module and determines the module contributor
/// Returns a Map containing:
/// - 'question_ids': List<String> of question IDs
/// - 'module_contributor': String of the most frequent question contributor or "no_contributor"
Map<String, dynamic> getQuestionIdsForModule(List<Map<String, dynamic>> pairs, String moduleName) {
  QuizzerLogger.logMessage('Getting question IDs and determining contributor for module: $moduleName');
  
  // Get all questions for this module
  final List<Map<String, dynamic>> moduleQuestions = pairs
      .where((pair) => pair['module_name'] == moduleName)
      .toList();
  
  // Extract question IDs
  final List<String> questionIds = moduleQuestions
      .where((pair) => pair['question_id'] != null)
      .map((pair) => pair['question_id'] as String)
      .toList();
  
  // Count occurrences of each contributor
  final Map<String, int> contributorCounts = {};
  for (var question in moduleQuestions) {
    if (question['qst_contrib'] != null) {
      final String contributor = question['qst_contrib'] as String;
      contributorCounts[contributor] = (contributorCounts[contributor] ?? 0) + 1;
    }
  }
  
  // Determine module contributor
  String moduleContributor = "no_contributor";
  if (contributorCounts.isNotEmpty) {
    moduleContributor = contributorCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
  
  QuizzerLogger.logMessage('Found ${questionIds.length} question IDs for module: $moduleName');
  QuizzerLogger.logMessage('Module contributor determined to be: $moduleContributor');
  QuizzerLogger.logSuccess('Successfully gathered question IDs and determined contributor');
  
  return {
    'question_ids': questionIds,
    'module_contributor': moduleContributor,
  };
}

// ==========================================

/// Builds module records from question-answer pairs and updates the modules table
/// This function:
/// 1. Gathers all question-answer pairs
/// 2. Builds module records with subjects, concepts, and question IDs
/// 3. Checks if each module exists in the modules table
/// 4. Creates new modules or updates existing ones accordingly
/// Returns a Future<bool> indicating if the process completed successfully
Future<bool> buildModuleRecords() async {
  QuizzerLogger.logMessage('Starting module build process');
  
  try {
    // Spawn a new isolate to handle the module building process
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(_buildModuleRecordsInIsolate, receivePort.sendPort);
    
    // Wait for the isolate to complete
    final bool success = await receivePort.first as bool;
    
    // Clean up
    receivePort.close();
    isolate.kill();
    
    QuizzerLogger.logSuccess('Module build process completed successfully');
    return success;
  } catch (e) {
    QuizzerLogger.logError('Error in module build process: $e');
    return false;
  }
}

// This function runs in a separate isolate
Future<void> _buildModuleRecordsInIsolate(SendPort sendPort) async {
  try {
    // Initialize database factory for the isolate
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    QuizzerLogger.logMessage('Starting to build module records in isolate');
    
    // Step 1: Get all question-answer pairs
    final List<Map<String, dynamic>> pairs = await getAllQuestionAnswerPairs();
    QuizzerLogger.logMessage('Retrieved ${pairs.length} question-answer pairs');
    
    // Step 2: Get unique module names
    final Set<String> uniqueModuleNames = await getUniqueModuleNames(pairs);
    QuizzerLogger.logMessage('Found ${uniqueModuleNames.length} unique module names');
    
    // Step 3: Process each module
    for (final moduleName in uniqueModuleNames) {
      QuizzerLogger.logMessage('Processing module: $moduleName');
      
      // Get module data
      final Map<String, dynamic> subjectsData = getUniqueSubjectsForModule(pairs, moduleName);
      final Set<String> concepts = getUniqueConceptsForModule(pairs, moduleName);
      final Map<String, dynamic> questionsData = getQuestionIdsForModule(pairs, moduleName);
      
      // Check if module exists
      final Map<String, dynamic>? existingModule = await getModule(moduleName);
      
      if (existingModule == null) {
        // Create new module
        QuizzerLogger.logMessage('Creating new module: $moduleName');
        await insertModule(
          name: moduleName,
          description: "no_description",
          primarySubject: subjectsData['primary_subject'],
          subjects: subjectsData['subjects'].toList(),
          relatedConcepts: concepts.toList(),
          questionIds: questionsData['question_ids'],
          creatorId: questionsData['module_contributor'],
        );
        QuizzerLogger.logSuccess('Successfully created new module: $moduleName');
      } else {
        // Update existing module
        QuizzerLogger.logMessage('Updating existing module: $moduleName');
        await updateModule(
          name: moduleName,
          primarySubject: subjectsData['primary_subject'],
          subjects: subjectsData['subjects'].toList(),
          relatedConcepts: concepts.toList(),
          questionIds: questionsData['question_ids'],
        );
        QuizzerLogger.logSuccess('Successfully updated module: $moduleName');
      }
    }
    
    QuizzerLogger.logSuccess('Successfully processed all modules');
    sendPort.send(true); // Signal completion
  } catch (e) {
    QuizzerLogger.logError('Error in module build isolate: $e');
    sendPort.send(false); // Signal failure
  }
}