import 'package:quizzer/database/tables/modules.dart';
import 'package:quizzer/database/tables/question_answer_pairs.dart';

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
Future<void> validateAndBuildModules() async {  
  // Get all question-answer pairs
  final List<Map<String, dynamic>> questions = await getAllQuestionAnswerPairs();
  
  // Group questions by module name
  final Map<String, List<Map<String, dynamic>>> questionsByModule = {};
  for (var question in questions) {
    final moduleName = question['module_name']?.toString().toLowerCase() ?? '';
    if (moduleName.isNotEmpty) {
      questionsByModule.putIfAbsent(moduleName, () => []).add(question);
    }
  }
  
  // Process each module
  for (var entry in questionsByModule.entries) {
    final moduleName = entry.key;
    final moduleQuestions = entry.value;
    
    // Get existing module or create new one
    var module = await getModuleByName(moduleName);
    
    // Extract unique subjects and concepts from questions
    final Set<String> subjects = {};
    final Set<String> concepts = {};
    final Set<String> questionIds = {};
    
    for (var question in moduleQuestions) {
      // Add subjects
      final questionSubjects = question['subjects']?.toString().split(',') ?? [];
      subjects.addAll(questionSubjects.where((s) => s.isNotEmpty));
      
      // Add concepts
      final questionConcepts = question['concepts']?.toString().split(',') ?? [];
      concepts.addAll(questionConcepts.where((c) => c.isNotEmpty));
      
      // Add question ID (using timestamp and contributor as unique identifier)
      final questionId = '${question['time_stamp']}_${question['qst_contrib']}';
      questionIds.add(questionId);
    }
    
    // Determine primary subject (most common subject in questions)
    final Map<String, int> subjectCounts = {};
    for (var question in moduleQuestions) {
      final questionSubjects = question['subjects']?.toString().split(',') ?? [];
      for (var subject in questionSubjects) {
        if (subject.isNotEmpty) {
          subjectCounts[subject] = (subjectCounts[subject] ?? 0) + 1;
        }
      }
    }
    
    final primarySubject = subjectCounts.isEmpty 
        ? '' 
        : subjectCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    
    if (module == null) {
      // Create new module
      await addModule(
        moduleName: moduleName,
        description: 'Module containing questions about $primarySubject',
        primarySubject: primarySubject,
        subjects: subjects.toList(),
        relatedConcepts: concepts.toList(),
        questionIds: questionIds.toList(),
        creatorId: 'system', // Using 'system' as creator for auto-generated modules
      );
    } else {
      // Update existing module
      await editModule(
        moduleName: moduleName,
        primarySubject: primarySubject,
        subjects: subjects.toList(),
        relatedConcepts: concepts.toList(),
        questionIds: questionIds.toList(),
      );
    }
  }
}
