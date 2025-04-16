import 'package:quizzer/features/modules/database/modules_table.dart';
import 'package:quizzer/features/question_management/database/question_answer_pairs_table.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';

/// Validates and builds module records based on question-answer pairs
/// This function:
/// 1. Gathers unique module names from question-answer pairs
/// 2. Validates existence of module records
/// 3. Ensures module names are lowercase
/// 4. Builds subject field from question subjects
/// 5. Builds concept field from question concepts
/// 6. Builds question_ids field from module questions
/// 7. Determines primary subject based on most common subject
/// 
Future<List<Map<String, dynamic>>> validateAndBuildModules() async {  
  QuizzerLogger.logMessage('Starting module validation and build process');
  
  // Get all questions and extract module information
  final questions = await _getAllQuestions();
  final moduleNames = _extractUniqueModuleNames(questions);
  
  // Build module data structures
  final List<Map<String, dynamic>> moduleDataList = [];
  
  for (final moduleName in moduleNames) {
    QuizzerLogger.printSubheader('Processing module: $moduleName');
    try {
      final moduleData = await _buildModuleData(moduleName, questions);
      moduleDataList.add(moduleData);
    } catch (e) {
      QuizzerLogger.logError('Failed to process module $moduleName: $e');
      // Continue processing other modules even if one fails
      continue;
    }
  }
  
  QuizzerLogger.logSuccess('Module validation and build process completed successfully');
  QuizzerLogger.printDivider();
  return moduleDataList;
}

/// Fetches all question-answer pairs and logs the result
Future<List<Map<String, dynamic>>> _getAllQuestions() async {
  QuizzerLogger.logValue('Fetching all question-answer pairs');
  final questions = await getAllQuestionAnswerPairs();
  QuizzerLogger.logMessage('Retrieved ${questions.length} question-answer pairs');
  return questions;
}

/// Extracts unique, non-empty, lowercase module names from questions
Set<String> _extractUniqueModuleNames(List<Map<String, dynamic>> questions) {
  QuizzerLogger.logValue('Extracting unique module names');
  final moduleNames = questions
      .map((q) => (q['module_name'] as String?)?.toLowerCase() ?? '')
      .where((name) => name.isNotEmpty)
      .toSet();
  QuizzerLogger.logMessage('Found ${moduleNames.length} unique modules: ${moduleNames.join(", ")}');
  return moduleNames;
}

/// Extracts subjects and concepts from a list of questions for a specific module
Map<String, Set<String>> _extractModuleMetadata(List<Map<String, dynamic>> moduleQuestions) {
  final Set<String> subjects = {};
  final Set<String> concepts = {};
  final Set<String> questionIds = {};
  
  for (var question in moduleQuestions) {
    // Add subjects
    final questionSubjects = (question['subjects'] as String?)?.split(',') ?? [];
    subjects.addAll(questionSubjects.where((s) => s.isNotEmpty));
    
    // Add concepts
    final questionConcepts = (question['concepts'] as String?)?.split(',') ?? [];
    concepts.addAll(questionConcepts.where((c) => c.isNotEmpty));
    
    // Add question ID
    final questionId = '${question['time_stamp']}_${question['qst_contrib']}';
    questionIds.add(questionId);
  }
  
  return {
    'subjects': subjects,
    'concepts': concepts,
    'questionIds': questionIds,
  };
}

/// Determines the primary subject based on frequency in questions
String _determinePrimarySubject(List<Map<String, dynamic>> moduleQuestions) {
  final Map<String, int> subjectCounts = {};
  
  for (var question in moduleQuestions) {
    final questionSubjects = (question['subjects'] as String?)?.split(',') ?? [];
    for (var subject in questionSubjects.where((s) => s.isNotEmpty)) {
      subjectCounts[subject] = (subjectCounts[subject] ?? 0) + 1;
    }
  }
  
  return subjectCounts.isEmpty 
      ? '' 
      : subjectCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
}

/// Builds the complete module data structure for a given module name
Future<Map<String, dynamic>> _buildModuleData(
  String moduleName,
  List<Map<String, dynamic>> allQuestions,
) async {
  // Get questions for this module
  final moduleQuestions = allQuestions.where(
    (q) => (q['module_name'] as String?)?.toLowerCase() == moduleName
  ).toList();
  QuizzerLogger.logValue('Found ${moduleQuestions.length} questions for module $moduleName');
  
  // Extract metadata
  final metadata = _extractModuleMetadata(moduleQuestions);
  final primarySubject = _determinePrimarySubject(moduleQuestions);
  
  QuizzerLogger.logValue(
    'Module $moduleName metadata:'
    '\n  - Subjects: ${metadata['subjects']!.length}'
    '\n  - Concepts: ${metadata['concepts']!.length}'
    '\n  - Questions: ${metadata['questionIds']!.length}'
    '\n  - Primary Subject: $primarySubject'
  );

  // Check if module exists and update/insert accordingly
  final existingModule = await getModule(moduleName);
  final moduleData = {
    'name': moduleName,
    'description': 'Module containing questions about $primarySubject',
    'primarySubject': primarySubject,
    'subjects': metadata['subjects']!.toList(),
    'relatedConcepts': metadata['concepts']!.toList(),
    'questionIds': metadata['questionIds']!.toList(),
    'creatorId': 'system',
  };

  if (existingModule == null) {
    QuizzerLogger.logMessage('Creating new module: $moduleName');
    await insertModule(
      name: moduleName,
      description: moduleData['description'] as String,
      primarySubject: primarySubject,
      subjects: moduleData['subjects'] as List<String>,
      relatedConcepts: moduleData['relatedConcepts'] as List<String>,
      questionIds: moduleData['questionIds'] as List<String>,
      creatorId: 'system',
    );
    QuizzerLogger.logSuccess('Successfully created new module: $moduleName');
  } else {
    QuizzerLogger.logMessage('Updating existing module: $moduleName');
    await updateModule(
      name: moduleName,
      primarySubject: primarySubject,
      subjects: moduleData['subjects'] as List<String>,
      relatedConcepts: moduleData['relatedConcepts'] as List<String>,
      questionIds: moduleData['questionIds'] as List<String>,
    );
    QuizzerLogger.logSuccess('Successfully updated module: $moduleName');
  }
  
  return moduleData;
}
