import 'dart:async';
import 'dart:math';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/09_data_caches/eligible_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/question_queue_cache.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// Table Imports
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile_table.dart' as user_profile_table;
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
  bool _isInitialLoop = true;

  // --- Dependencies ---
  final SessionManager          _sessionManager = SessionManager();
  final EligibleQuestionsCache  _eligibleCache = EligibleQuestionsCache();
  final QuestionQueueCache      _queueCache = QuestionQueueCache();
  final DatabaseMonitor         _dbMonitor = getDatabaseMonitor();

  // --- Control Methods ---
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _isInitialLoop = true;
    _stopCompleter = Completer<void>();
    QuizzerLogger.logMessage('PresentationSelectionWorker started.');
    _runLoop();
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    QuizzerLogger.logMessage('PresentationSelectionWorker stopping...');
    _isRunning = false;
    await _stopCompleter?.future;
    QuizzerLogger.logMessage('PresentationSelectionWorker stopped.');
  }

  // --- Main Loop Logic ---
  Future<void> _runLoop() async {
    while (_isRunning) {
      if (_isInitialLoop) {
        await _performInitialLoop();
        _isInitialLoop = false;
      } else {
        await _performSubsequentLoop();
      }
    }
    _stopCompleter?.complete();
  }

  // --- Initial Loop ---
  Future<void> _performInitialLoop() async {
    QuizzerLogger.logMessage('PresentationSelectionWorker: Starting initial loop...');
    await _selectAndQueueQuestion(); // Attempt one selection/queue
    QuizzerLogger.logMessage('PresentationSelectionWorker: Initial loop processing complete. Signaling SessionManager.');
    // Signal SessionManager that initial selection attempt is done
    // This assumes SessionManager has a method to receive this signal.
    // _sessionManager.signalInitialSelectionComplete(); // FIXME: Keep commented until SM is updated
  }

  // --- Subsequent Loop ---
  Future<void> _performSubsequentLoop() async {
    if (!_isRunning) return;

    // Loop to re-check conditions after waiting
    while (_isRunning) {
      final bool eligibleIsEmpty = await _eligibleCache.isEmpty();
      final bool queueIsFull = await _queueCache.getLength() >= QuestionQueueCache.queueThreshold;

      // Condition to Proceed: Eligible cache has items AND Queue cache is not full
      if (!eligibleIsEmpty && !queueIsFull) {
        // QuizzerLogger.logMessage('PresentationSelectionWorker: Conditions met, selecting question...');
        await _selectAndQueueQuestion();
        // After selecting, immediately loop back to check conditions again 
        // in case we can add another one right away.
        continue; 
      } 
      
      // Condition to Wait: Either eligible is empty or queue is full (or both)
      // QuizzerLogger.logMessage('PresentationSelectionWorker: Conditions not met (EligibleEmpty: $eligibleIsEmpty, QueueFull: $queueIsFull). Waiting...');
      
      // Build the list of futures to wait for based on why we are blocked
      final List<Future<void>> futuresToWaitFor = [];
      if (eligibleIsEmpty) {
        futuresToWaitFor.add(_eligibleCache.onRecordAdded.first);
      }
      if (queueIsFull) {
        futuresToWaitFor.add(_queueCache.onRecordRemoved.first);
      }

      // Only wait if there's actually something to wait for 
      // (Should always be true if the first if condition failed)
      if (futuresToWaitFor.isNotEmpty) {
         // Wait for *any* of the blocking conditions to potentially resolve
         await Future.any(futuresToWaitFor);
         // QuizzerLogger.logMessage('PresentationSelectionWorker: Woke up from wait.');
         // Loop continues, conditions will be re-evaluated at the top.
      } else {
         // This case should theoretically not be reached if the first 'if' failed.
         // Add a small safety delay just in case, or log an error.
         QuizzerLogger.logError('PresentationSelectionWorker: In wait block but no condition to wait for!');
         await Future.delayed(const Duration(seconds: 1)); // Safety delay
      }

      // Check running status again after waiting before looping
      if (!_isRunning) break;
    }
  }

  // --- Core Selection and Queuing Logic ---
  Future<void> _selectAndQueueQuestion() async {
    if (!_isRunning) return;

    final List<Map<String, dynamic>> eligibleQuestions = await _eligibleCache.peekAllRecords();
    if (eligibleQuestions.isEmpty) {
      // QuizzerLogger.logMessage('SelectAndQueue: Eligible cache is empty, nothing to select.');
      return; // Nothing to do
    }

    // Call the adapted selection logic
    final Map<String, dynamic> selectedQuestion = await _selectNextQuestionFromList(eligibleQuestions);

    if (selectedQuestion.isNotEmpty) {
      final questionId = selectedQuestion['question_id'] as String;
      QuizzerLogger.logMessage('Selected question $questionId to queue.');

      // 1. Add to Queue Cache
      await _queueCache.addRecord(selectedQuestion);
      QuizzerLogger.logSuccess('Added $questionId to QuestionQueueCache.');

      // 2. Remove from Eligible Cache
      final removedRecord = await _eligibleCache.getAndRemoveRecordByQuestionId(questionId);
      if (removedRecord.isEmpty) {
         // This is unexpected if selection logic worked correctly
         QuizzerLogger.logError('Failed to remove selected question $questionId from EligibleQuestionsCache!');
         // Fail Fast - indicates inconsistency
         throw StateError('Selected question $questionId could not be removed from EligibleCache.');
      } else {
         QuizzerLogger.logMessage('Removed $questionId from EligibleQuestionsCache.');
      }
    } else {
      QuizzerLogger.logWarning('Selection algorithm did not return a question from non-empty eligible list.');
      // This case might indicate an issue with the selection algorithm or edge case handling
    }
  }

  // --- Adapted Selection Logic (Database Access) ---

  Future<Map<String, dynamic>> _selectNextQuestionFromList(List<Map<String, dynamic>> eligibleQuestions) async {
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
    
    // Acquire DB connection
    Database db = await _getDbAccessWithRetry();

    // Get interests directly from DB
    Map<String, int> userSubjectInterests = await user_profile_table.getUserSubjectInterests(userId, db);

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

    final double overallMaxInterest = userSubjectInterests.values.fold(0.0, (max, current) => current > max ? current.toDouble() : max);

    // Loop over eligible questions to calculate scores
    double totalScore = 0.0;
    for (final question in eligibleQuestions) {
      final String questionId = question['question_id'];
      final int revisionStreak = question['revision_streak'] ?? 0;
      
      // Fetch full pair directly from DB
      final Map<String, dynamic> questionDetails = await q_pairs_table.getQuestionAnswerPairById(questionId, db);
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
    
    // --- Release DB Lock BEFORE selection --- 
    // Selection logic below doesn't need DB access anymore
    _dbMonitor.releaseDatabaseAccess();
    // ----------------------------------------

    if (totalScore <= 0.0) {
        QuizzerLogger.logWarning("Total score is zero or negative during selection. Selecting randomly from eligible list.");
        final random = Random();
        return eligibleQuestions[random.nextInt(eligibleQuestions.length)];
    }

    // Weighted Random Selection
    final random = Random();
    double randomThreshold = random.nextDouble() * totalScore;
    double cumulativeScore = 0.0;

    for (final question in eligibleQuestions) {
      final String questionId = question['question_id'];
      final double score = scoreMap[questionId]!;
      cumulativeScore += score;
      if (cumulativeScore >= randomThreshold) {
        return question;
      }
    }

    // Fallback
    QuizzerLogger.logError('Weighted random selection failed to select a question despite positive total score! Returning first eligible.');
    if (eligibleQuestions.isNotEmpty) {
       return eligibleQuestions.first;
    }
    return {};
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
    return (
      (subInterestWeight * normalizedInterest) + 
      (revisionStreakWeight * normalizedStreak) + 
      (timeDaysWeight * normalizedTime) + 
      bias
    );
  }

  // --- Helper for DB Access ---
  Future<Database> _getDbAccessWithRetry() async {
     Database? db;
     int retries = 0;
     while (db == null && _isRunning && retries < 5) {
       db = await _dbMonitor.requestDatabaseAccess();
       if (db == null) await Future.delayed(const Duration(milliseconds: 100));
       retries++;
     }
     if (db == null) {
       QuizzerLogger.logError('PresentationSelectionWorker: Failed to acquire database access after retries.');
       // Fail fast if DB cannot be acquired
       throw StateError('PresentationSelectionWorker: Failed to acquire database access after retries.');
     }
     return db;
  }
}
