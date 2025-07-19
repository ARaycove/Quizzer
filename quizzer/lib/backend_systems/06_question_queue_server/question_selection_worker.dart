import 'dart:async';
import 'dart:math';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/09_data_caches/question_queue_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/answer_history_cache.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_question_worker_signals.dart';
// Table Imports
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart' as user_profile_table;
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart' as q_pairs_table;
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';

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
  final QuestionQueueCache        _queueCache = QuestionQueueCache();
  // final UnprocessedCache        _unprocessedCache = UnprocessedCache();
  
  // --- Internal tracking of recently selected questions ---
  final List<String> _recentlySelectedQuestionIds = [];
  static const int _maxRecentlySelectedCount = 5;

  // --- Control Methods ---
  void start() {
    try {
      QuizzerLogger.logMessage('Entering PresentationSelectionWorker start()...');
      if (_isRunning) {
        QuizzerLogger.logWarning('PresentationSelectionWorker is already running.');
        return;
      }
      
      // Clear both caches to ensure clean state
      QuizzerLogger.logMessage('Clearing QuestionQueueCache and AnswerHistoryCache...');
      _queueCache.clear();
      final AnswerHistoryCache historyCache = AnswerHistoryCache();
      historyCache.clear();
      
      QuizzerLogger.logSuccess('✅ QuestionQueueCache and AnswerHistoryCache cleared');
      
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
        return;
      }
      QuizzerLogger.logMessage('PresentationSelectionWorker stopping...');
      _isRunning = false;
      
      // Clear both caches when stopping to ensure clean state
      QuizzerLogger.logMessage('Clearing QuestionQueueCache and AnswerHistoryCache on stop...');
      _queueCache.clear();
      final AnswerHistoryCache historyCache = AnswerHistoryCache();
      historyCache.clear();
      QuizzerLogger.logSuccess('Both caches cleared');
      
      // Wait for the loop to finish if there's a completer
      if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
        await _stopCompleter!.future;
      }
      
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
        // Step 1: Check if the length of the questionQueueCache is below the threshold
        final int currentLength = await _queueCache.getLength();
        const int threshold = QuestionQueueCache.queueThreshold;
        
        if (currentLength < threshold) {
          // Step 2: Get eligible questions
          final List<Map<String, dynamic>> eligibleQuestions = await getEligibleUserQuestionAnswerPairs(_sessionManager.userId!);
          
          // Step 3: Filter out recently answered questions and questions already in queue cache
          List<Map<String, dynamic>> filteredEligibleQuestions = List<Map<String, dynamic>>.from(eligibleQuestions);
          
          if (filteredEligibleQuestions.isNotEmpty) {
            // Get the last 5 questions from answer history cache
            final List<String> recentQuestionIds = await AnswerHistoryCache().getLastFiveAnsweredQuestions();
            
            // Get questions already in the queue cache
            final List<Map<String, dynamic>> queueCacheQuestions = await _queueCache.peekAllRecords();
            final List<String> queueCacheQuestionIds = queueCacheQuestions.map((q) => q['question_id'] as String).toList();
            
            // Remove any questions that were recently answered, recently selected by this worker, or are already in the queue cache
            filteredEligibleQuestions = filteredEligibleQuestions.where((question) {
              final String questionId = question['question_id'] as String;
              final bool notRecentlyAnswered = recentQuestionIds.isEmpty || !recentQuestionIds.contains(questionId);
              final bool notRecentlySelected = !_recentlySelectedQuestionIds.contains(questionId);
              final bool notInQueueCache = !queueCacheQuestionIds.contains(questionId);
              return notRecentlyAnswered && notRecentlySelected && notInQueueCache;
            }).toList();
            
            final int removedCount = eligibleQuestions.length - filteredEligibleQuestions.length;
            if (removedCount > 0) {
              // Calculate how many were removed due to each reason
              final int recentlyAnsweredCount = eligibleQuestions.where((q) => 
                recentQuestionIds.contains(q['question_id'] as String)).length;
              final int recentlySelectedCount = eligibleQuestions.where((q) => 
                _recentlySelectedQuestionIds.contains(q['question_id'] as String)).length;
              final int inQueueCacheCount = removedCount - recentlyAnsweredCount - recentlySelectedCount;
              QuizzerLogger.logMessage('Removed $removedCount questions from eligible list ($recentlyAnsweredCount recently answered, $recentlySelectedCount recently selected, $inQueueCacheCount already in queue cache).');
            }
          }
          
          // Step 4: Handle different scenarios based on filtered eligible questions count
          if (!_isRunning) break; // Abort if worker was stopped
          
          if (filteredEligibleQuestions.isEmpty) {
            // If 0 eligible questions then we do nothing at all
            QuizzerLogger.logMessage('No eligible questions available after filtering recently answered questions. Waiting for question answered signal.');
          } else {
            final int cyclesNeeded = threshold - currentLength;
            final int availableQuestions = eligibleQuestions.length;
            
            if (availableQuestions < cyclesNeeded) {
              // If num eligible questions not enough to bring the queueCache up to the threshold, 
              // then we skip the advanced selection logic and just directly add the remaining questions
              final int filteredQuestionsCount = filteredEligibleQuestions.length;
              QuizzerLogger.logMessage('Only $filteredQuestionsCount filtered eligible questions available (need $cyclesNeeded). Adding all directly to queue cache.');
              
              for (int i = 0; i < filteredQuestionsCount && _isRunning; i++) {
                final Map<String, dynamic> questionRecord = filteredEligibleQuestions[i];
                if (!_isRunning) break; // Abort if worker was stopped
                await _queueCache.addRecord(questionRecord);
                
              }
            } else {
              // Use advanced selection logic for the needed cycles
              QuizzerLogger.logMessage('Queue length $currentLength is below threshold $threshold. Running $cyclesNeeded cycles of _selectAndQueueQuestion');
              
              for (int i = 0; i < cyclesNeeded && _isRunning; i++) {
                if (!_isRunning) break; // Abort if worker was stopped
                await _selectAndQueueQuestion(filteredEligibleQuestions);
                
              }
            }
          }
        }
        
        // Step 4: Signal that the selection cycle is complete
        signalPresentationSelectionWorkerCycleComplete();
        
        // Step 5: Wait for either the submitAnswer signal or circulation worker question added signal
        if (_isRunning) {
          await Future.any([
            _switchBoard.onQuestionAnsweredCorrectly.first,
            _switchBoard.onCirculationWorkerQuestionAdded.first,
            _switchBoard.onQuestionQueueRemoved.first,
          ]);
        }
      }
      
      // Only complete the completer if it hasn't been completed yet
      if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
        _stopCompleter!.complete();
      }
      QuizzerLogger.logMessage('PresentationSelectionWorker loop finished.');
    } catch (e) {
      QuizzerLogger.logError('Error in PresentationSelectionWorker _runLoop - $e');
      
      // Only complete the completer if it hasn't been completed yet
      if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
        _stopCompleter!.completeError(e);
      }
      rethrow;
    }
  }

  // --- Core Selection and Queuing Logic ---
  Future<bool> _selectAndQueueQuestion(List<Map<String, dynamic>> eligibleQuestions) async {
    try {
      QuizzerLogger.logMessage('Entering PresentationSelectionWorker _selectAndQueueQuestion()...');
      if (!_isRunning) return false;

      // 1. Call _selectNextQuestionFromList to get the selected question
      final Map<String, dynamic> selectedQuestion = await _selectNextQuestionFromList(eligibleQuestions);
      
      // 2. Check if selection was successful
      if (selectedQuestion.isEmpty) {
        QuizzerLogger.logWarning('PSW Select: No question was selected from eligible questions.');
        return false;
      }

      // 3. Check if worker was stopped before adding to queue
      if (!_isRunning) return false;

      // 4. Add the selected question to the queue cache
      final bool added = await _queueCache.addRecord(selectedQuestion);
      
      if (added) {
        // 5. Track the selected question in our internal list
        _trackSelectedQuestion(selectedQuestion['question_id'] as String);
        QuizzerLogger.logSuccess('PSW Select: Successfully added question ${selectedQuestion['question_id']} to QueueCache.');
      } else {
        QuizzerLogger.logWarning('PSW Select: Failed to add question ${selectedQuestion['question_id']} to QueueCache.');
      }
      
      return added;
    } catch (e) {
      QuizzerLogger.logError('Error in PresentationSelectionWorker _selectAndQueueQuestion - $e');
      rethrow;
    }
  }
  
  // --- Internal tracking method ---
  void _trackSelectedQuestion(String questionId) {
    // Remove if already exists (to move to front)
    _recentlySelectedQuestionIds.remove(questionId);
    // Add to the front (most recent first)
    _recentlySelectedQuestionIds.insert(0, questionId);
    // Keep only the last 5
    if (_recentlySelectedQuestionIds.length > _maxRecentlySelectedCount) {
      _recentlySelectedQuestionIds.removeRange(_maxRecentlySelectedCount, _recentlySelectedQuestionIds.length);
    }
    QuizzerLogger.logMessage('PSW Tracking: Added $questionId to recently selected list (${_recentlySelectedQuestionIds.length} total)');
  }

  // --- Adapted Selection Logic (Table functions handle their own database access) ---

  Future<Map<String, dynamic>> _selectNextQuestionFromList(List<Map<String, dynamic>> eligibleQuestions) async {
    try {
      QuizzerLogger.logMessage('Entering PresentationSelectionWorker _selectNextQuestionFromList()...');
      if (!_isRunning) return {}; // Abort if worker was stopped
      
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
        if (!_isRunning) return {}; // Abort if worker was stopped
        
        final String questionId = question['question_id'];
        final int revisionStreak = question['revision_streak'] ?? 0;
        
        // Fetch full pair directly from DB - table function handles its own database access
        final Map<String, dynamic> questionDetails = await q_pairs_table.getQuestionAnswerPairById(questionId);
        if (!_isRunning) return {}; // Abort if worker was stopped after DB call
        
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
      if (!_isRunning) return {}; // Abort if worker was stopped
      
      final random = Random();
      double randomThreshold = random.nextDouble() * totalScore;
      double cumulativeScore = 0.0;

      for (final question in eligibleQuestions) {
        if (!_isRunning) return {}; // Abort if worker was stopped
        
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
      if (!_isRunning) return {}; // Abort if worker was stopped
      
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