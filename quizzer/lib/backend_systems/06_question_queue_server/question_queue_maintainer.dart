import 'dart:async';
import 'dart:math'; // For random selection
import 'package:quizzer/backend_systems/06_question_queue_server/question_queue_monitor.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';


/// Starts the question queue maintenance process
/// This function runs continuously in the background to maintain the queue
Future<void> startQuestionQueueMaintenance() async {
  QuizzerLogger.logMessage('Starting question queue maintenance');
  final queueMonitor = getQuestionQueueMonitor();
  final dbMonitor = getDatabaseMonitor();
  
  while (true) {
    // 1. Check if we need to add questions to circulation
    if (await _shouldAddToCirculation(dbMonitor)) {
      QuizzerLogger.logMessage("Should add questions to circulation");
      await _addQuestionsToCirculation(dbMonitor);
    }

    // // 2. Check if queue needs new items
    // if (await _shouldAddToQueue(queueMonitor)) {
    //   // FIXME Do a very quick read operation to get required data for the _selectNextQuestion function
    //   // this ensure the dbMonitor is released sooner for other processes to use

    //   // selectNextQuestion won't be modifying the db at all so it should only need to take raw data for processing
    //   final question = await _selectNextQuestion(dbMonitor);
    //   if (question != null) {
    //     await _addToQueue(question, queueMonitor);
    //   }
    // }

    // Delay ensures we don't gum up the system and CPU
    await Future.delayed(const Duration(seconds: 3));
  }
}

/// Determines if new questions should be added to circulation
Future<bool> _shouldAddToCirculation(DatabaseMonitor dbMonitor) async {
  late bool shouldAdd;
  SessionManager session = getSessionManager();
  // Criteria
  // First get the userQuestionAnswerPairs so we can loop over them:
  List<Map<String, dynamic>> userQuestionRecords = await session.getAllUserQuestionPairs();
  int numEligibleQuestions = 0;
  int numEarlyReviewQuestions = 0;
  // When we loop over we are counting for two things, the number of early review questions and the number of eligible questions
  for (final userRecord in userQuestionRecords) {
    String questionId = userRecord['question_id'];
    int revisionStreak = userRecord['revision_streak'];
    if (await session.checkQuestionEligibility(questionId)) {numEligibleQuestions++;}
    if (revisionStreak <= 5) {numEarlyReviewQuestions++;}
    if (numEligibleQuestions >= 100) {break;}
  }
  // If below 100 eligible questions then shouldAdd = true;
  if (numEligibleQuestions >= 100) {shouldAdd = true;}
  // If below 20 early review questions when done counting shouldAdd = true;
  else if (numEarlyReviewQuestions < 20) {shouldAdd = true;}
  // If neither we shouldn't add anything
  else {shouldAdd = false;}

  

  return shouldAdd;
}

/// ======================================================================
Future<List<dynamic>> _calculateCurrentRatio(DatabaseMonitor dbMonitor, List<Map<String, dynamic>> userQuestionRecords) async {
  int totalQuestionsAvailableToBePutInCirculation = 0;
  List<Map<String, dynamic>>  nonCirculatingRecords = [];
  final Map<String, int>      currentRatio = {};
  SessionManager              session = getSessionManager();

  for (final Map<String, dynamic> questionRecord in userQuestionRecords) {
    Map<String, dynamic>? questionAnswerPair = await session.getQuestionAnswerPair(questionRecord['question_id']);
    if (questionRecord['in_circulation'] == 0) {
      totalQuestionsAvailableToBePutInCirculation++;
      nonCirculatingRecords.add(questionRecord);      
      }
    else if (questionAnswerPair['subjects'] != null) {
      String csvString = questionAnswerPair['subjects'];
      List<String> subjects = csvString.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      for (final String subject in subjects) {
        if (currentRatio[subject] == null) {
          currentRatio[subject] = 1;
        } else {
           int currentValue = currentRatio[subject]!; // Read non-null value
           currentRatio[subject] = currentValue + 1; // Assign incremented value
        }
      }
    }
    else {
      if (currentRatio['misc'] == null) {currentRatio['misc'] = 1;}
      else {int c = currentRatio['misc']!; currentRatio['misc'] = c + 1;}
    }
  }

  return [totalQuestionsAvailableToBePutInCirculation, nonCirculatingRecords, currentRatio];
}

/// Selects a single question to add to circulation, prioritizing under-represented subjects.
Map<String, dynamic> _selectPrioritizedQuestion(
  Map<String, int> interestData,
  Map<String, int> currentRatio,
  List<Map<String, dynamic>> nonCirculatingRecords
) {
  // Calculate deficit scores
  final Map<String, double> deficits = {};
  final int totalInterestWeight =
      interestData.values.fold(0, (sum, item) => sum + item);
  final int totalCurrentCount =
      currentRatio.values.fold(0, (sum, item) => sum + item);

  if (totalInterestWeight > 0) { // Only calculate if interests are set
    interestData.forEach((subject, desiredWeight) {
      final double desiredProportion = desiredWeight / totalInterestWeight;
      final double currentProportion = (totalCurrentCount == 0)
          ? 0.0
          : (currentRatio[subject] ?? 0) / totalCurrentCount;
      deficits[subject] = desiredProportion - currentProportion;
    });
  } // Logging for deficits removed

  // Create a sorted list of subjects with positive deficits (most needed first)
  final List<MapEntry<String, double>> sortedNeededSubjects = deficits.entries
      .where((entry) => entry.value > 0) // Only consider needed subjects
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value)); // Sort descending by deficit

  Map<String, dynamic>? selectedRecord;

  // Iterate through needed subjects in order of priority
  if (sortedNeededSubjects.isNotEmpty) {
    // Logging for attempt removed
     for (final entry in sortedNeededSubjects) {
        final neededSubject = entry.key;
        // Logging for checking subject removed

        // Filter non-circulating questions for the current needed subject
        final List<Map<String, dynamic>> potentialMatches =
            nonCirculatingRecords.where((record) {
          final String? subjectsCsv = record['subjects'] as String?;
          if (subjectsCsv != null && subjectsCsv.isNotEmpty) {
            return subjectsCsv
                .split(',')
                .map((s) => s.trim())
                .contains(neededSubject);
          }
          // Handle 'misc' case
          else if (neededSubject == 'misc' && (subjectsCsv == null || subjectsCsv.isEmpty)) {
              return true;
          }
          return false;
        }).toList();

        if (potentialMatches.isNotEmpty) {
          // Logging for found match removed
          final random = Random();
          selectedRecord = potentialMatches[random.nextInt(potentialMatches.length)];
          break; // Found a match based on priority, break the loop
        } // Logging for not found removed
     }
  } // Logging for balanced/no deficit removed

  // Fallback to random selection ONLY if no prioritized selection was made
  if (selectedRecord == null) {
     // Logging for fallback removed
     final random = Random();
     // Assumes nonCirculatingRecords is not empty (checked by caller)
     selectedRecord = nonCirculatingRecords[random.nextInt(nonCirculatingRecords.length)];
  }

  return selectedRecord;
}

/// Adds new questions to circulation based on subject ratios
Future<void> _addQuestionsToCirculation(DatabaseMonitor dbMonitor) async {
  // Should take raw data and the monitor
  SessionManager session = getSessionManager();
  // We're going to need a separate list of records for just those records that aren't in circulation
  Map<String, int> interestData = await session.getUserSubjectInterests();
  List<Map<String, dynamic>> userQuestionRecords = await session.getAllUserQuestionPairs();
  // We need to calcualte the current ratio of subjects
  List<dynamic> calcRatio = await _calculateCurrentRatio(dbMonitor, userQuestionRecords);
  int totalQuestionsAvailableToBePutInCirculation   = calcRatio[0];
  List<Map<String, dynamic>> nonCirculatingRecords  = calcRatio[1];
  Map<String, int> currentRatio                     = calcRatio[2];

  // If there are no available questions to put into circulation we just return at this point in the function
  if (totalQuestionsAvailableToBePutInCirculation == 0) {
    QuizzerLogger.logMessage('No non-circulating questions available to add.');
    return;
  }

  // Select the next question to add based on priorities
  Map<String, dynamic> selectedRecord = _selectPrioritizedQuestion(
    interestData,
    currentRatio,
    nonCirculatingRecords
  );

  final String questionId = selectedRecord['question_id'];
  await session.addQuestionToCirculation(questionId); // while we don't need to await this operation, it will force the maintainer to slow down by a small amount
  QuizzerLogger.logMessage("Selected Question Answer pair to be added: $selectedRecord");
}



/// Determines if the queue needs new items
Future<bool> _shouldAddToQueue(QuestionQueueMonitor queueMonitor) async {
  return queueMonitor.queueSize < 10;
}

/// Selects the next question to add to the queue
Future<Map<String, dynamic>?> _selectNextQuestion(DatabaseMonitor dbMonitor) async {
  final db = await dbMonitor.requestDatabaseAccess();
  if (db == null) {
    QuizzerLogger.logError('Failed to get database access');
    return null;
  }

  // TODO: Implement question selection logic
  // - Consider subject ratios
  // - Account for question history
  // - Ensure even distribution
  dbMonitor.releaseDatabaseAccess();
  return null;
}

/// Adds a question to the queue
Future<void> _addToQueue(Map<String, dynamic> question, QuestionQueueMonitor queueMonitor) async {
  // TODO: Implement queue addition logic
  // - Get queue access
  // - Add question
  // - Release queue access
}