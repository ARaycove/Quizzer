import 'dart:async';
import 'dart:math';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/09_data_caches/eligible_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/question_queue_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/temp_question_details.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_question_worker_signals.dart';
// Table Imports
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart' as user_profile_table;
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart' as q_pairs_table;

// ==========================================
// Presentation Selection Worker
// ==========================================

/// Worker responsible for selecting the next question to present from the eligible pool
/// and placing it into the QuestionQueueCache.
class PresentationSelectionWorker {
  // --- Singleton Setup ---
  static final PresentationSelectionWorker _instance = PresentationSelectionWorker._internal();
  factory PresentationSelectionWorker() => _instance;
  PresentationSelectionWorker._internal();

  // --- Worker State ---
  bool _isRunning = false;
  Completer<void>? _stopCompleter;
  
  // --- Dependencies ---
  final SwitchBoard _switchBoard = SwitchBoard();

  // --- Dependencies ---
  final SessionManager            _sessionManager = SessionManager();
  final EligibleQuestionsCache    _eligibleCache = EligibleQuestionsCache();
  final QuestionQueueCache        _queueCache = QuestionQueueCache();
  final TempQuestionDetailsCache  _tempDetailsCache = TempQuestionDetailsCache();
  // final UnprocessedCache        _unprocessedCache = UnprocessedCache();

  // --- Control Methods ---
  void start() {
    try {
      QuizzerLogger.logMessage('Entering PresentationSelectionWorker start()...');
      if (_isRunning) {
        QuizzerLogger.logWarning('PresentationSelectionWorker is already running.');
        return;
      }
      _isRunning = true;
      _stopCompleter = Completer<void>();
      QuizzerLogger.logMessage('PresentationSelectionWorker started.');
      _runLoop();
    } catch (e) {
      QuizzerLogger.logError('Error starting PresentationSelectionWorker - $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      QuizzerLogger.logMessage('Entering PresentationSelectionWorker stop()...');
      if (!_isRunning) {
        QuizzerLogger.logWarning('PresentationSelectionWorker is not running.');
        return Future.value();
      }
      QuizzerLogger.logMessage('PresentationSelectionWorker stopping...');
      _isRunning = false;
      // Wait for the current loop iteration to finish
      QuizzerLogger.logMessage('PresentationSelectionWorker stopped.');
    } catch (e) {
      QuizzerLogger.logError('Error stopping PresentationSelectionWorker - $e');
      rethrow;
    }
  }

  // --- Main Loop Logic ---
  Future<void> _runLoop() async {
    try {
      QuizzerLogger.logMessage('Entering PresentationSelectionWorker _runLoop()...');
      while (_isRunning) {
        await _performLoopLogic();
      }
      _stopCompleter?.complete();
      QuizzerLogger.logMessage('PresentationSelectionWorker loop finished.');
    } catch (e) {
      QuizzerLogger.logError('Error in PresentationSelectionWorker _runLoop - $e');
      rethrow;
    }
  }

  // --- Main Loop Logic ---
  Future<void> _performLoopLogic() async {
    try {
      QuizzerLogger.logMessage('Entering PresentationSelectionWorker _performLoopLogic()...');
      if (!_isRunning) return;

      // Check 1: Is the queue full?
      final queueLength = await _queueCache.getLength();
      final bool queueIsFull = queueLength >= QuestionQueueCache.queueThreshold;

      if (queueIsFull) {
          // Queue is full. BEFORE waiting, check for duplicates between Queue and Eligible.
          QuizzerLogger.logMessage('PresentationSelectionWorker Loop: Queue full. Checking for duplicates between Queue and Eligible.');
          final queueRecords = await _queueCache.peekAllRecords();
          final eligibleRecords = await _eligibleCache.peekAllRecords();
          final Set<String> eligibleIds = eligibleRecords.map((r) => r['question_id'] as String).toSet();
          int duplicatesRemoved = 0;

          for (final queueRecord in queueRecords) {
              final String? queueQuestionId = queueRecord['question_id'] as String?;
              if (queueQuestionId != null && eligibleIds.contains(queueQuestionId)) {
                  // Found a question present in both Queue and Eligible cache. Remove from Eligible.
                  await _eligibleCache.getAndRemoveRecordByQuestionId(queueQuestionId);
                  duplicatesRemoved++;
              }
          }
          if (duplicatesRemoved > 0) {
              QuizzerLogger.logSuccess('PresentationSelectionWorker Loop: Removed $duplicatesRemoved duplicate(s) from EligibleCache.');
          }

          // Re-check if queue is STILL full after potential removals from Eligible
          final currentQueueLength = await _queueCache.getLength();
          if (currentQueueLength >= QuestionQueueCache.queueThreshold) {
              // Queue is still full, wait specifically for removal signal.
              QuizzerLogger.logMessage('PSW Loop: Queue still full after check, waiting for removal signal...');
              await _switchBoard.onQuestionQueueRemoved.first;
              QuizzerLogger.logMessage('PSW Loop: Woke up from queueCache wait.');
          } else {
              QuizzerLogger.logMessage('PSW Loop: Queue no longer full after duplicate check. Continuing loop.');
          }
          // Whether we waited or not, continue to top of loop to re-evaluate all conditions
          return; 
      }

      // If queue is NOT full, proceed to check eligible cache.
      // Check 2: Is the eligible cache empty?
      final bool eligibleIsEmpty = await _eligibleCache.isEmpty();

      if (eligibleIsEmpty) {
          // Queue has space, but no eligible questions. Wait specifically for eligible questions.
          QuizzerLogger.logMessage('PSW Loop: Eligible cache empty, waiting for add signal...');
          await _switchBoard.onEligibleQuestionsAdded.first;
          QuizzerLogger.logMessage('PSW Loop: Woke up from eligibleCache wait.');
          return; // After waiting, loop back and re-check everything from the top.
      }

      // If we reach here: Queue is NOT full AND Eligible Cache is NOT empty.
      // Proceed to select and queue one question.
      await _selectAndQueueQuestion();

      // Signal cycle completion
      signalPresentationSelectionWorkerCycleComplete();
    } catch (e) {
      QuizzerLogger.logError('Error in PresentationSelectionWorker _performLoopLogic - $e');
      rethrow;
    }
  }

  // --- Core Selection and Queuing Logic ---
  Future<bool> _selectAndQueueQuestion() async {
    try {
      QuizzerLogger.logMessage('Entering PresentationSelectionWorker _selectAndQueueQuestion()...');
      // QuizzerLogger.logMessage('PSW: Entering _selectAndQueueQuestion.');
      if (!_isRunning) return false;

      final List<Map<String, dynamic>> eligibleQuestions = await _eligibleCache.peekAllRecords();
      // QuizzerLogger.logValue('PSW Select: Found ${eligibleQuestions.length} eligible questions.');
      if (eligibleQuestions.isEmpty) {
        // QuizzerLogger.logMessage('PSW Select: Eligible cache empty, returning.');
        return false; // Nothing to do
      }

      // Call the adapted selection logic
      final Map<String, dynamic> selectedQuestion = await _selectNextQuestionFromList(eligibleQuestions);
      String questionId = selectedQuestion['question_id'];

      // 1. Grab the selected question by its id from the eligible cache
      // QuizzerLogger.logMessage('PSW Select: Attempting to get and remove $questionId from EligibleCache...');
      final Map<String, dynamic> recordToQueue = await _eligibleCache.getAndRemoveRecordByQuestionId(questionId);

      // 1a. handle case where that selected question is no longer in there (I believe this is handled by the cache??)
      if (recordToQueue.isEmpty) {
        // This means the record was removed from EligibleCache between selection and this fetch.
        // Could be due to module deactivation flush, concurrent processing, etc.
        QuizzerLogger.logWarning('PSW Select: Record $questionId was not found in EligibleCache during get/remove (likely removed concurrently).');
        return false; // Cannot queue a record we couldn't fetch.
      }
      // QuizzerLogger.logSuccess('PSW Select: Successfully got and removed $questionId from EligibleCache.');

      // 2. Get static question details from question_answer_pairs table and place that record into the temp Cache
      // Table functions handle their own database access
      // QuizzerLogger.logMessage('PSW Select: Fetching static details for $questionId from q_pairs_table...');
      final Map<String, dynamic> staticQuestionDetails = await q_pairs_table.getQuestionAnswerPairById(questionId);

      if (staticQuestionDetails.isEmpty) {
        QuizzerLogger.logError('PSW Select: CRITICAL - Fetched empty static details for $questionId from DB. This should not happen if question_id is valid.');
        // If static details are missing, we probably shouldn't queue the user record either.
        // Returning to avoid putting potentially orphaned user record in queue without its details.
        return false;
      }
      
      // QuizzerLogger.logMessage('PSW Select: Adding static details for $questionId to TempQuestionDetailsCache...');
      await _tempDetailsCache.addRecord(questionId, staticQuestionDetails);
      // QuizzerLogger.logSuccess('PSW Select: Successfully added $questionId static details to TempQuestionDetailsCache.');

      // 3. Place it in queue
      // QuizzerLogger.logMessage('PSW Select: Adding fetched record $questionId to QueueCache...');
      final bool added = await _queueCache.addRecord(recordToQueue);
      // QuizzerLogger.logSuccess('PSW Select: Successfully added $questionId to QueueCache.');
      return added;
    } catch (e) {
      QuizzerLogger.logError('Error in PresentationSelectionWorker _selectAndQueueQuestion - $e');
      rethrow;
    }
  }

  // --- Adapted Selection Logic (Table functions handle their own database access) ---

  Future<Map<String, dynamic>> _selectNextQuestionFromList(List<Map<String, dynamic>> eligibleQuestions) async {
    try {
      QuizzerLogger.logMessage('Entering PresentationSelectionWorker _selectNextQuestionFromList()...');
      // QuizzerLogger.logMessage('PSW Algo: Entering _selectNextQuestionFromList with ${eligibleQuestions.length} items.');
      // Assumes eligibleQuestions is not empty (checked by caller)
      assert(_sessionManager.userId != null, "User ID must be set for selection.");
      final userId = _sessionManager.userId!;

      // --- Configuration --- (Keep as is)
      const double subInterestWeight    = 0.4;
      const double revisionStreakWeight = 0.3;
      const double timeDaysWeight       = 0.3;
      const double bias                 = 0.01;
      // ---------------------

      Map<String, double> scoreMap = {}; // format {question_id: selectionAlgoScore} (do not unccomment or modify)
      
      // Table functions handle their own database access
      // Get interests directly from DB
      Map<String, int> userSubjectInterests = await user_profile_table.getUserSubjectInterests(userId);
      // QuizzerLogger.logValue('PSW Algo: User interests fetched.');

      // Preprocessing: Calculate overdue days and find max
      double actualMaxOverdueDays = 0.0;
      final Map<String, double> overdueDaysMap = {}; 
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
      // QuizzerLogger.logValue('PSW Algo: Preprocessing complete. Max overdue: $actualMaxOverdueDays');

      final double overallMaxInterest = userSubjectInterests.values.fold(0.0, (max, current) => current > max ? current.toDouble() : max);

      // Loop over eligible questions to calculate scores
      double totalScore = 0.0;
      // QuizzerLogger.logMessage('PSW Algo: Calculating scores...');
      for (final question in eligibleQuestions) {
        final String questionId = question['question_id'];
        final int revisionStreak = question['revision_streak'] ?? 0;
        
        // Fetch full pair directly from DB - table function handles its own database access
        final Map<String, dynamic> questionDetails = await q_pairs_table.getQuestionAnswerPairById(questionId);
        final String? subjectsCsv = questionDetails['subjects'] as String?;

        final double timePastDueInDays = overdueDaysMap[questionId]!;
        final int adjustedStreak = (revisionStreak == 0) ? 1 : revisionStreak;

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
        final double normalizedStreak = 1.0 / adjustedStreak;
        final double normalizedTime = (actualMaxOverdueDays > 0) ? (timePastDueInDays / actualMaxOverdueDays) : 0.0;

        final double score = _selectionAlgorithm(subInterestWeight, revisionStreakWeight, timeDaysWeight, normalizedStreak, normalizedTime, normalizedInterest, bias);
        final double finalScore = max(0.0, score);

        scoreMap[questionId] = finalScore;
        totalScore += finalScore;
      }
      // QuizzerLogger.logValue('PSW Algo: Score calculation complete. Total score: $totalScore');

      if (totalScore <= 0.0) {
          QuizzerLogger.logWarning("PSW Algo: Total score zero/negative. Selecting randomly."); // Keep this warning
          final random = Random();
          return eligibleQuestions[random.nextInt(eligibleQuestions.length)];
      }

      // Weighted Random Selection
      // QuizzerLogger.logMessage('PSW Algo: Performing weighted random selection...');
      final random = Random();
      double randomThreshold = random.nextDouble() * totalScore;
      double cumulativeScore = 0.0;

      for (final question in eligibleQuestions) {
        final String questionId = question['question_id'];
        final double score = scoreMap[questionId]!;
        cumulativeScore += score;
        if (cumulativeScore >= randomThreshold) {
          // QuizzerLogger.logValue("PSW Algo: Selected $questionId (Score: $score, Cumulative: $cumulativeScore, Threshold: $randomThreshold)");
          return question;
        }
      }

      // Fallback
      // QuizzerLogger.logError('PSW Algo: Weighted random selection failed! Returning first eligible.'); // Keep this error
      if (eligibleQuestions.isNotEmpty) {
         return eligibleQuestions.first;
      }
      return {};
    } catch (e) {
      QuizzerLogger.logError('Error in PresentationSelectionWorker _selectNextQuestionFromList - $e');
      rethrow;
    }
  }

  // --- Helper for the selection algorithm formula ---
  double _selectionAlgorithm(
    double subInterestWeight, 
    double revisionStreakWeight,
    double timeDaysWeight,
    double normalizedStreak, 
    double normalizedTime,
    double normalizedInterest,
    double bias
  ) {
    try {
      QuizzerLogger.logMessage('Entering PresentationSelectionWorker _selectionAlgorithm()...');
      return (
        (subInterestWeight * normalizedInterest) + 
        (revisionStreakWeight * normalizedStreak) + 
        (timeDaysWeight * normalizedTime) + 
        bias
      );
    } catch (e) {
      QuizzerLogger.logError('Error in PresentationSelectionWorker _selectionAlgorithm - $e');
      rethrow;
    }
  }
}