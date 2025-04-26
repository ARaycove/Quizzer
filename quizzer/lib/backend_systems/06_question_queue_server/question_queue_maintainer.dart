import 'dart:async';
import 'dart:math'; // For random selection
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:sqflite/sqflite.dart'; // Add this import


/// Starts the question queue maintenance process
/// This function runs continuously in the background to maintain the queue
Future<void> startQuestionQueueMaintenance() async {
  // TODO Update so loop wait time is dynamic
  // Intention, that dynamic loop wait time would reduce the time the worker is using system resources
  // Option 1:
  // 1. get average reaction time out of all items in the queue
  // 2. set the duration wait time to this value
  // Option 2:
  // 1. Run without a timer, until the queue fills (very rapid filling)
  // 2. If we check and it is 10 items, set sleep time to 75% of sum of average reaction time of items in the queue (Would result in a very long sleep duration, if the avg per item is 3 seconds, we would have a sum of 30 seconds, then tell the program to sleep for .75 * 22.5 seconds)
  // Option 3:
  // 1. Add one item per loop iteration
  // 2. Set sleep time to next item in queue's average reaction time

  // Considerations
  // If queue is empty and nothing to add, we already have to check to switch to 60 second timeout
  // We'd only execute the dynamic adjustment if their are presently items in the queue

  // Functions needed to implement
  // helper function -> getAverage TODO
  // - takes in list of doubles or ints
  // - removes outliers of dataset (if anything is way outside standard deviation then don't include it)
  // - returns the mean value
  // helper function -> getReactionTimeOfUserQuestionRecord TODO
  // - takes userQuestionRecord as input
  // - returns the list of reaction times
  // helper function -> getAvgReactionTimeOfUserQuestionRecord TODO
  // - compiles the previous two helper function together
  // - takes a userQuestionRecord map as input
  // - calls the getReactionTimeOfUserQuestionRecord
  // - calls the getAverage 
  // - returns the result

  QuizzerLogger.logMessage('Queue Maintainer: Starting question queue maintenance');
  final queueMonitor      = getQuestionQueueMonitor();
  final dbMonitor         = getDatabaseMonitor();
  SessionManager session  = getSessionManager();

  
  while (true) {
    QuizzerLogger.logMessage('Queue Maintainer: Checking. . .');
    bool? questionsAvailableToPutIntoCirculation = false;
    int queueSize = queueMonitor.queueSize; // Get current queue size

    // 1. Check if we need to add questions to circulation
    if (await _shouldAddToCirculation(dbMonitor)) {
      questionsAvailableToPutIntoCirculation = await _addQuestionsToCirculation(dbMonitor);
    }

    // 2. Check if queue needs new items
    if (queueSize < 10) { // Check against current size
      // _selectNextQuestion returns the selected question map directly
      Map<String, dynamic> selectedQuestion = await _selectNextQuestion(dbMonitor);
      



      // Check if a valid question was selected (not an empty map)
      if (selectedQuestion.isNotEmpty) {
          // Make sure we get the actual question answer pair not the userRecord
          String questionId = selectedQuestion['question_id'];
          Database? db;
          // Acquire DB Access
          while (db == null) {
            db = await dbMonitor.requestDatabaseAccess();
            if (db == null) {
              QuizzerLogger.logMessage('DB access denied for fetching user pairs, waiting...');
              await Future.delayed(const Duration(milliseconds: 100));
            }
          }
          selectedQuestion = await getQuestionAnswerPairById(questionId, db);
          dbMonitor.releaseDatabaseAccess();

         // Call the monitor's addQuestion method directly
         bool added = await queueMonitor.addQuestion(selectedQuestion); 
         if (added) {
            QuizzerLogger.logMessage('Queue Maintainer: Successfully added question ${selectedQuestion['question_id']} via monitor.addQuestion.');
            // Update queue size ONLY if successfully added
            queueSize = queueMonitor.queueSize; 
         } else {
            QuizzerLogger.logWarning('Queue Maintainer: Monitor refused to add selected question ${selectedQuestion['question_id']} (duplicate/recent).');
         }
      } else {
          QuizzerLogger.logMessage('Queue Maintainer: _selectNextQuestion returned no eligible question this cycle.');
      }
    }

    // Get number of eligible questions *after* potential queue addition attempts
    int numEligibleQuestions = (await session.getEligibleQuestions()).length;
    // 3. Check return statuses to determine how long worker should sleep
    // 3a. determine if NoRest
    // if queue is less than 10 and there are eligible questions
    if (numEligibleQuestions != 0 && queueSize != 10) {
      bool shouldNotRest = true;
    } 
    // 3b. determine if ShortRest
    // there are questions still to put in circulation, but queue is full
    else if (questionsAvailableToPutIntoCirculation!) {
      bool shouldShortRest = true;
      QuizzerLogger.logMessage('Queue Maintainer: Queue is full, but questions available to circulate. Short rest.');
      await Future.delayed(const Duration(seconds: 3));
    }
    // 3c. determine if LongRest
    // No eligible questions and nothing to put into circulation
    else if (numEligibleQuestions == 0 && !questionsAvailableToPutIntoCirculation) {
      bool shouldLongRest = true;
      QuizzerLogger.logMessage('Queue Maintainer: Queue full or no eligible questions/circulation needed. Long rest.');
      await Future.delayed(const Duration(seconds: 60));
    }
    else {
      QuizzerLogger.logError('Queue Maintainer: NO CASE DECIDED - short rest');
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  // Commented out old logic:
  //   // Delay ensures we don't gum up the system and CPU
  //   if (shouldImmediatelySelectNewQuestion) {}
  //   else if (isAvailableQuestions) {
  //   await Future.delayed(const Duration(seconds: 3));
  //     QuizzerLogger.logMessage('Queue Maintainer: There are still available questions. short rest');
  //   }
  //   else {
  //     QuizzerLogger.logMessage('Queue Maintainer: No Questions Available to Select, taking long rest. . .');
  //     await Future.delayed(const Duration(seconds:60));}
  // }
}

/// Determines if new questions should be added to circulation
Future<bool> _shouldAddToCirculation(DatabaseMonitor dbMonitor) async {
  late bool shouldAdd;
  SessionManager session = getSessionManager();
  // Criteria
  // First get the userQuestionAnswerPairs so we can loop over them:
  List<Map<String, dynamic>>  eligibleQuestions     = await session.getEligibleQuestions();
  int numEarlyReviewQuestions = 0;
  int numEligibleQuestions = eligibleQuestions.length;

  for (final questionRecord in eligibleQuestions) {
    if (questionRecord['revision_streak'] <= 3) {
      numEarlyReviewQuestions++;
    }
  }
  QuizzerLogger.logMessage('numEarlyReviewQuestions: $numEarlyReviewQuestions');
  QuizzerLogger.logMessage('numEligibleQuestion    : $numEligibleQuestions');
  // If below 100 eligible questions then shouldAdd = true;
  if (numEligibleQuestions <= 100) {shouldAdd = true;}
  // If below 20 early review questions when done counting shouldAdd = true;
  else if (numEarlyReviewQuestions < 20) {shouldAdd = true;}
  // If neither we shouldn't add anything
  else {shouldAdd = false;}

  if (shouldAdd) {QuizzerLogger.logMessage("Queue Maintainer: Should add questions to circulation");}
  else {QuizzerLogger.logMessage("Queue Maintainer: No need to add questions to circulation right now");}
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
Future<bool?> _addQuestionsToCirculation(DatabaseMonitor dbMonitor) async {
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
    QuizzerLogger.logMessage('Queue Maintainer: No non-circulating questions available to add.');
    return false;
  }

  // Select the next question to add based on priorities
  Map<String, dynamic> selectedRecord = _selectPrioritizedQuestion(
    interestData,
    currentRatio,
    nonCirculatingRecords
  );

  final String questionId = selectedRecord['question_id'];
  await session.addQuestionToCirculation(questionId); // while we don't need to await this operation, it will force the maintainer to slow down by a small amount
  QuizzerLogger.logMessage("Queue Maintainer: Selected QA pair to add to circulation: $selectedRecord");
  return true;
}


double _selectionAlgorithm(
  double subInterestWeight, 
  double revisionStreakWeight,
  double timeDaysWeight,
  double revisionStreak, 
  double timePastDueInDays,
  double subjectInterestHighest,
  double bias) {
    revisionStreak.toDouble();

    return (
    (subInterestWeight * subjectInterestHighest) + 
    (revisionStreakWeight * revisionStreak) + 
    (timeDaysWeight * timePastDueInDays) + 
    bias);
  }

/// Selects the next question to add to the queue
Future<Map<String, dynamic>> _selectNextQuestion(DatabaseMonitor dbMonitor) async {
  // Should return empty map, if no question can be found. But we need to avoid this at all costs
  SessionManager session = getSessionManager();
  // --- Configuration ---
  const double subInterestWeight    = 0.4; // Importance of subject interest
  const double revisionStreakWeight = 0.3; // Importance of revision streak
  const double timeDaysWeight       = 0.3; // Importance of time past due
  const double bias                 = 0.01; // Small bias to ensure non-zero scores
  // const double maxRelevantOverdueDays = 30.0; // Removed: Will calculate dynamically
  // ---------------------

  Map<String, double> scoreMap = {}; //format {question_id: selectionAlgoScore}
  
  Map<String, int>            userSubjectInterests  = await session.getUserSubjectInterests();
  List<Map<String, dynamic>>  eligibleQuestions     = await session.getEligibleQuestions();
  QuizzerLogger.logMessage("$eligibleQuestions");
  QuizzerLogger.logMessage("Total eligible questions: ${eligibleQuestions.length}");

  // --- Preprocessing: Calculate overdue days and find max ---
  double actualMaxOverdueDays = 0.0;
  final Map<String, double> overdueDaysMap = {}; // Store calculated days
  for (final question in eligibleQuestions) {
      final String questionId = question['question_id'];
      final String nextRevisionDueStr = question['next_revision_due'];
      final DateTime nextRevisionDue = DateTime.parse(nextRevisionDueStr);
      final Duration timeDifference = DateTime.now().difference(nextRevisionDue);
      final double timePastDueInDays = timeDifference.isNegative ? 0.0 : timeDifference.inDays.toDouble();
      
      overdueDaysMap[questionId] = timePastDueInDays;
      if (timePastDueInDays > actualMaxOverdueDays) {
          actualMaxOverdueDays = timePastDueInDays;
      }
  }
  // ---------------------------------------------------------
  // Calculate overall max interest - No longer needed for normalization
  final double overallMaxInterest = userSubjectInterests.values.fold(0.0, (max, current) => current > max ? current.toDouble() : max);

  // Loop over eligible questions to calculate scores
  double totalScore = 0.0;
  for (final question in eligibleQuestions) {
    // Extract necessary data from the question record
    final String questionId = question['question_id'];
    final int revisionStreak = question['revision_streak'];
    // Fetch full pair first, then access subjects
    final Map<String, dynamic> questionDetails = await session.getQuestionAnswerPair(questionId);
    final String? subjectsCsv = questionDetails['subjects'] as String?; 

    // --- Calculate Raw Values (Retrieve precalculated time) ---
    // 1. Absolute Highest Interest (Calculated below)
    // 2. Time Past Due (Retrieved from map)
    final double timePastDueInDays = overdueDaysMap[questionId]!; // Non-null assertion okay here
    // 3. Adjusted Streak (Treat 0 as 1)
    final int adjustedStreak = (revisionStreak == 0) ? 1 : revisionStreak;
    // ---------------------------------------------------------

    // --- Calculate Normalized Scores (0-1 range ideally) ---
    // 1. Normalized Interest Score (S_interest)
    double subjectInterestHighest = 0.0;
    if (subjectsCsv != null && subjectsCsv.isNotEmpty) {
      final List<String> subjects = subjectsCsv.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      for (final subject in subjects) {
        final double currentInterest = (userSubjectInterests[subject] ?? 0).toDouble();
        if (currentInterest > subjectInterestHighest) {
          subjectInterestHighest = currentInterest;
        }
      }
    } else { 
        subjectInterestHighest = (userSubjectInterests['misc'] ?? 0).toDouble();
    }
    
    final double normalizedInterest = (overallMaxInterest > 0) ? (subjectInterestHighest / overallMaxInterest) : 0.0;

    // 2. Normalized Streak Score (S_streak)
    final double normalizedStreak = 1.0 / adjustedStreak; 

    // 3. Normalized Time Score (S_time) - Use dynamic max
    final double normalizedTime = (actualMaxOverdueDays > 0) ? (timePastDueInDays / actualMaxOverdueDays) : 0.0;
    // -----------------------------------------------

    // Calculate final score using normalized components + weights + bias
    final double score = _selectionAlgorithm(subInterestWeight, revisionStreakWeight, timeDaysWeight, normalizedStreak, normalizedTime, normalizedInterest, bias);

    // Ensure score is non-negative 
    final double finalScore = max(0.0, score); // Safeguard (bias should prevent 0)

    scoreMap[questionId] = finalScore;
    totalScore += finalScore;
  }

  // Handle Zero Total Score (Should be rare with bias)
  // if (totalScore <= 0.0) {
  //   QuizzerLogger.logWarning("Total score is zero. This should not happen with the current implementation.");
  // }

  // Weighted Random Selection
  final random = Random();
  double randomThreshold = random.nextDouble() * totalScore;
  double cumulativeScore = 0.0;

  for (final question in eligibleQuestions) {
    final String questionId = question['question_id'];
    final double score = scoreMap[questionId]!; // Non-null assertion ok due to loop logic
    cumulativeScore += score;
    if (cumulativeScore >= randomThreshold) {
      QuizzerLogger.logMessage("Queue Maintainer: Selected question $questionId with score $score (Cumulative: $cumulativeScore, Threshold: $randomThreshold)");
      return question; // Return the selected question map
    }
  }

  // If all else fails return an empty map
  return {};
  
}