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
  // final UnprocessedCache        _unprocessedCache = UnprocessedCache();

  // --- Notification Stream (for Initial Loop Completion) ---
  final StreamController<void> _initialLoopCompleteController = StreamController<void>.broadcast();
  /// Stream that fires once when the initial loop processing is complete.
  Stream<void> get onInitialLoopComplete => _initialLoopCompleteController.stream;
  // -------------------------------------------------------

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
    QuizzerLogger.logMessage('PSW: Starting initial loop...');
    await _selectAndQueueQuestion(); // Attempt one selection/queue. Errors will propagate.
    // QuizzerLogger.logMessage('PSW: Initial loop processing complete. Signaling completion.');
    // Signal SessionManager (or other listeners) that initial loop is done.
    if (!_initialLoopCompleteController.isClosed) {
        _initialLoopCompleteController.add(null);
    } else {
        // QuizzerLogger.logWarning("PSW: Tried to signal initial loop complete, but controller was closed.");
    }
    // If an error occurred in _selectAndQueueQuestion, this point might not be reached,
    // and the stream event/error won't be sent, correctly adhering to Fail Fast.
  }

  // --- Subsequent Loop ---
  Future<void> _performSubsequentLoop() async {
    if (!_isRunning) return;
    // QuizzerLogger.logMessage('PSW: Entering _performSubsequentLoop.');

    while (_isRunning) {
        // QuizzerLogger.logMessage('PSW Loop: Top of loop.');
        // Check 1: Is the queue full?
        // QuizzerLogger.logMessage('PSW Loop: Checking if queue is full...');
        final queueLength = await _queueCache.getLength();
        final bool queueIsFull = queueLength >= QuestionQueueCache.queueThreshold;
        // QuizzerLogger.logValue('PSW Loop: Queue length: $queueLength, Is full: $queueIsFull');

        if (queueIsFull) {
            // Queue is full. BEFORE waiting, check for duplicates between Queue and Eligible.
            // QuizzerLogger.logMessage('PSW Loop: Queue full. Checking for Queue/Eligible duplicates...');
            final queueRecords = await _queueCache.peekAllRecords();
            final eligibleRecords = await _eligibleCache.peekAllRecords();
            final Set<String> eligibleIds = eligibleRecords.map((r) => r['question_id'] as String).toSet();
            int duplicatesRemoved = 0;

            for (final queueRecord in queueRecords) {
                final String? queueQuestionId = queueRecord['question_id'] as String?;
                if (queueQuestionId != null && eligibleIds.contains(queueQuestionId)) {
                    // Found a question present in both Queue and Eligible cache. Remove from Eligible.
                    // QuizzerLogger.logWarning('PSW Loop: Found duplicate QID $queueQuestionId in both Queue and Eligible. Removing from Eligible.');
                    await _eligibleCache.getAndRemoveRecordByQuestionId(queueQuestionId);
                    duplicatesRemoved++;
                }
            }
            if (duplicatesRemoved > 0) {
                //  QuizzerLogger.logSuccess('PSW Loop: Removed $duplicatesRemoved duplicate(s) from EligibleCache.');
            }

            // Re-check if queue is STILL full after potential removals from Eligible
            final currentQueueLength = await _queueCache.getLength();
            if (currentQueueLength >= QuestionQueueCache.queueThreshold) {
                // Queue is still full, wait specifically for removal signal.
                // QuizzerLogger.logMessage('PSW Loop: Queue still full after check, waiting for removal signal...');
                await _queueCache.onRecordRemoved.first;
                // QuizzerLogger.logMessage('PSW Loop: Woke up from queueCache wait.');
            } else {
                //  QuizzerLogger.logMessage('PSW Loop: Queue no longer full after duplicate check. Continuing loop.');
            }
            // Whether we waited or not, continue to top of loop to re-evaluate all conditions
            continue; 
        }

        // If queue is NOT full, proceed to check eligible cache.
        // Check 2: Is the eligible cache empty?
        // QuizzerLogger.logMessage('PSW Loop: Queue not full. Checking if eligible cache is empty...');
        final bool eligibleIsEmpty = await _eligibleCache.isEmpty();
        // QuizzerLogger.logValue('PSW Loop: Eligible cache is empty: $eligibleIsEmpty');

        if (eligibleIsEmpty) {
            // Queue has space, but no eligible questions. Wait specifically for eligible questions.
            // QuizzerLogger.logMessage('PSW Loop: Eligible cache empty, waiting for add signal...');
            await _eligibleCache.onRecordAdded.first;
            // QuizzerLogger.logMessage('PSW Loop: Woke up from eligibleCache wait.');
            continue; // After waiting, loop back and re-check everything from the top.
        }

        // If we reach here: Queue is NOT full AND Eligible Cache is NOT empty.
        // Proceed to select and queue one question.
        // QuizzerLogger.logMessage('PSW Loop: Conditions met, proceeding to select question...');
        await _selectAndQueueQuestion();

        // QuizzerLogger.logMessage('PSW Loop: Finished select/queue attempt.');
        // After selecting, the loop naturally iterates to check conditions again,
        // allowing it to potentially fill the queue quickly if possible.

       if (!_isRunning) break; // Check running status at end of loop iteration
    }
    // QuizzerLogger.logMessage('PSW: Exiting _performSubsequentLoop.');
  }

  // --- Core Selection and Queuing Logic ---
  Future<void> _selectAndQueueQuestion() async {
    // QuizzerLogger.logMessage('PSW: Entering _selectAndQueueQuestion.');
    if (!_isRunning) return;

    final List<Map<String, dynamic>> eligibleQuestions = await _eligibleCache.peekAllRecords();
    // QuizzerLogger.logValue('PSW Select: Found ${eligibleQuestions.length} eligible questions.');
    if (eligibleQuestions.isEmpty) {
      // QuizzerLogger.logMessage('PSW Select: Eligible cache empty, returning.');
      return; // Nothing to do
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
      return; // Cannot queue a record we couldn't fetch.
    }
    // QuizzerLogger.logSuccess('PSW Select: Successfully got and removed $questionId from EligibleCache.');

    // 2. Place it in queue
    // QuizzerLogger.logMessage('PSW Select: Adding fetched record $questionId to QueueCache...');
    await _queueCache.addRecord(recordToQueue);
    // QuizzerLogger.logSuccess('PSW Select: Successfully added $questionId to QueueCache.');

  }

  // --- Adapted Selection Logic (Database Access) ---

  Future<Map<String, dynamic>> _selectNextQuestionFromList(List<Map<String, dynamic>> eligibleQuestions) async {
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
    
    // Acquire DB connection
    Database db = await _getDbAccessWithRetry();
    // QuizzerLogger.logMessage('PSW Algo: DB acquired.');

    // Get interests directly from DB
    Map<String, int> userSubjectInterests = await user_profile_table.getUserSubjectInterests(userId, db);
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
    // QuizzerLogger.logValue('PSW Algo: Score calculation complete. Total score: $totalScore');
    
    // --- Release DB Lock BEFORE selection --- 
    // QuizzerLogger.logMessage('PSW Algo: Releasing DB lock...');
    _dbMonitor.releaseDatabaseAccess();
    // QuizzerLogger.logMessage('PSW Algo: DB lock released.');
    // ----------------------------------------

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