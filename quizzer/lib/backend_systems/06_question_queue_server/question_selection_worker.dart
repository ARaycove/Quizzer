import 'dart:async';
import 'dart:math';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/09_data_caches/question_queue_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/answer_history_cache.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_question_worker_signals.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/ml_models_table.dart';
// Table Imports
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
// Data Consistency Import
import 'package:quizzer/backend_systems/00_database_manager/data_consistency/compare_question.dart';

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
      await _queueCache.clear();
      final AnswerHistoryCache historyCache = AnswerHistoryCache();
      await historyCache.clear();
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
            
            // Remove any questions that were recently answered or are already in the queue cache
            filteredEligibleQuestions = filteredEligibleQuestions.where((question) {
              final String questionId = question['question_id'] as String;
              final bool notRecentlyAnswered = recentQuestionIds.isEmpty || !recentQuestionIds.contains(questionId);
              final bool notInQueueCache = !queueCacheQuestionIds.contains(questionId);
              return notRecentlyAnswered && notInQueueCache;
            }).toList();
            
            final int removedCount = eligibleQuestions.length - filteredEligibleQuestions.length;
            if (removedCount > 0) {
              // Calculate how many were removed due to each reason
              final int recentlyAnsweredCount = eligibleQuestions.where((q) => 
                recentQuestionIds.contains(q['question_id'] as String)).length;
              final int inQueueCacheCount = removedCount - recentlyAnsweredCount;
              QuizzerLogger.logMessage('Removed $removedCount questions from eligible list ($recentlyAnsweredCount recently answered, $inQueueCacheCount already in queue cache).');
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
                if (filteredEligibleQuestions.isEmpty) break; // No more questions to select
                
                final String? selectedId = await _selectAndQueueQuestion(filteredEligibleQuestions);
                
                // Remove the just-selected question from the list to prevent immediate re-selection
                if (selectedId != null) {
                  filteredEligibleQuestions.removeWhere((q) => q['question_id'] == selectedId);
                }
              }
            }
          }
        }
        
        // Step 4: Signal that the selection cycle is complete
        signalPresentationSelectionWorkerCycleComplete();
        
        // Step 5: Wait for either the submitAnswer signal or circulation worker question added signal
        if (_isRunning) {
          // Use a timeout-based approach to allow checking stop condition
          bool signalReceived = false;
          while (_isRunning && !signalReceived) {
            try {
              await Future.any([
                _switchBoard.onQuestionAnsweredCorrectly.first,
                _switchBoard.onCirculationWorkerQuestionAdded.first,
                _switchBoard.onQuestionQueueRemoved.first,
              ]).timeout(const Duration(milliseconds: 100));
              signalReceived = true;
            } on TimeoutException {
              // Check if we should stop
              if (!_isRunning) {
                QuizzerLogger.logMessage('PresentationSelectionWorker was stopped during signal wait.');
                break;
              }
              // Continue waiting
            }
          }
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
  Future<String?> _selectAndQueueQuestion(List<Map<String, dynamic>> eligibleQuestions) async {
    try {
      QuizzerLogger.logMessage('Entering PresentationSelectionWorker _selectAndQueueQuestion()...');
      if (!_isRunning) return null;

      // 1. Call _selectNextQuestionFromList to get the selected question
      // selection logic works on a router, for AB testing. Selection logic is now such that we can easily assign users to different selection logic for testing
      final Map<String, dynamic> selectedQuestion = await _selectNextQuestionFromList(eligibleQuestions, selectionLogic: 5);
      
      // 2. Check if selection was successful
      if (selectedQuestion.isEmpty) {
        QuizzerLogger.logWarning('PSW Select: No question was selected from eligible questions.');
        return null;
      }

      // 3. Check if worker was stopped before adding to queue
      if (!_isRunning) return null;

      // 4. Call compare function to clean up bad records (non-blocking)
      final String questionId = selectedQuestion['question_id'] as String;
      compareAndUpdateQuestionRecord(questionId).then((result) {
        if (result['updated']) {
          QuizzerLogger.logMessage('PSW Data Cleanup: ${result['message']} for question $questionId');
        }
      }).catchError((error) {
        QuizzerLogger.logError('PSW Data Cleanup: Error comparing question $questionId: $error');
      });

      // 5. Add the selected question to the queue cache
      bool added = false;
      try {
        added = await _queueCache.addRecord(selectedQuestion);
      } catch (e) {
        // Question was likely deleted by cleanup function between selection and queue addition
        QuizzerLogger.logWarning('PSW Select: Question ${selectedQuestion['question_id']} was deleted during processing, skipping.');
        return null;
      }
      
      if (added) {
        QuizzerLogger.logSuccess('PSW Select: Successfully added question ${selectedQuestion['question_id']} to QueueCache.');
        return questionId;
      } else {
        QuizzerLogger.logWarning('PSW Select: Failed to add question ${selectedQuestion['question_id']} to QueueCache.');
        return null;
      }
    } catch (e) {
      QuizzerLogger.logError('Error in PresentationSelectionWorker _selectAndQueueQuestion - $e');
      rethrow;
    }
  }
  
  /// Main router function
  /// Determines which selection logic is used from possibilities. This is useful for AB testing
  /// Selection logic itself is written in _selectionLogic* functions
  Future<Map<String, dynamic>> _selectNextQuestionFromList(List<Map<String, dynamic>> eligibleQuestions, {int selectionLogic = 1}) async {
    try {
      // FIXME Upward threshold is hardcoded (should add a user setting from which this information is pulled)
      // FIXME This change will allow us to change what the upward threshold is without needing to update this value in multiple places
      QuizzerLogger.logMessage('Entering PresentationSelectionWorker _selectNextQuestionFromList()...');
      if (!_isRunning) return {};
      if (eligibleQuestions.isEmpty) return {};
      
      switch (selectionLogic) {
        case 0:
          // Selects questions with the lowest revision streak, sorted by lowest probability.
          return await _selectionLogicZero(eligibleQuestions);
        case 1:
          // Selects questions that have a accuracy probability around the ideal threshold of the prediction model
          return await _selectionLogicOne(eligibleQuestions);
        case 2:
          // Selects questions at random out of all possible questions
          return await _selectionLogicTwo(eligibleQuestions);
        case 3:
          // Semi-Random Selection, prioritize new questions over old questions
          return await _selectionLogicThree(eligibleQuestions,
          nullRevisedPercent: 0.8, allQuestionsPercent: 0.15, nonNullRevisedPercent: 0.05);
        case 4:
          // 50/50 seen/unseen selection
          return await _selectionLogicFour(eligibleQuestions);
        case 5:
          // High probability focus with exploration
          return await _selectionLogicFive(eligibleQuestions);
        case 6:
          // Push all questions toward 90%+ probability
          return await _selectionLogicSix(eligibleQuestions);
        default:
          QuizzerLogger.logWarning('Invalid selectionLogic value: $selectionLogic. Defaulting to logic 1.');
          return await _selectionLogicOne(eligibleQuestions);
      }
    } catch (e) {
      QuizzerLogger.logError('Error in PresentationSelectionWorker _selectNextQuestionFromList - $e');
      rethrow;
    }
  }

  // Logic 0: Lowest revision streak, then lowest probability
  Future<Map<String, dynamic>> _selectionLogicZero(List<Map<String, dynamic>> eligibleQuestions) async {
    QuizzerLogger.logMessage("Selection Logic 0: Lowest revision streak and lowest probability");
    
    int lowestStreak = eligibleQuestions.first['revision_streak'] ?? 0;
    for (final q in eligibleQuestions) {
      final streak = q['revision_streak'] ?? 0;
      if (streak < lowestStreak) lowestStreak = streak;
    }
    
    final lowestStreakQuestions = eligibleQuestions.where((q) => (q['revision_streak'] ?? 0) == lowestStreak).toList();
    
    final selected = lowestStreakQuestions.reduce((a, b) => 
      ((a['accuracy_probability'] ?? 0.0) < (b['accuracy_probability'] ?? 0.0)) ? a : b
    );
    
    final prob = selected['accuracy_probability'] ?? 0.0;
    final attempts = selected['total_attempts'] ?? 0;
    QuizzerLogger.logMessage("Selected question - revision_streak: $lowestStreak, accuracy_probability: $prob, total_attempts: $attempts");
    return selected;
  }

  // Logic 1: Probabilistic selection with ML threshold
  Future<Map<String, dynamic>> _selectionLogicOne(
    List<Map<String, dynamic>> eligibleQuestions, {
    double highProbThreshold = 0.95,
    double thresholdSelectionChance = 0.10,
    double lowestProbSelectionChance = 0.85,
  }) async {
    QuizzerLogger.logMessage("Selection Logic 1: Probabilistic with ML threshold");
    
    final random = Random();
    final double roll = random.nextDouble();
    final double threshold = await getAccuracyNetOptimalThreshold();
    
    final lowProbQuestions = eligibleQuestions.where((q) => (q['accuracy_probability'] ?? 0.0) < highProbThreshold).toList();
    
    final int selectionMode;
    if (roll < thresholdSelectionChance) {
      selectionMode = 0;
    } else if (roll < thresholdSelectionChance + lowestProbSelectionChance) {
      selectionMode = 1;
    } else {
      selectionMode = 2;
    }
    
    Map<String, dynamic> selectedQuestion;
    
    switch (selectionMode) {
      case 0:
        if (lowProbQuestions.isEmpty) {
          selectedQuestion = eligibleQuestions[random.nextInt(eligibleQuestions.length)];
        } else {
          double minDistance = double.infinity;
          List<Map<String, dynamic>> closestQuestions = [];
          
          for (final q in lowProbQuestions) {
            final double prob = q['accuracy_probability'] ?? 0.0;
            final double distance = (prob - threshold).abs();
            
            if (distance < minDistance) {
              minDistance = distance;
              closestQuestions = [q];
            } else if (distance == minDistance) {
              closestQuestions.add(q);
            }
          }
          
          selectedQuestion = closestQuestions[random.nextInt(closestQuestions.length)];
        }
        break;
      
      case 1:
        selectedQuestion = eligibleQuestions.reduce((a, b) => 
          ((a['accuracy_probability'] ?? 0.0) < (b['accuracy_probability'] ?? 0.0)) ? a : b
        );
        break;
      
      case 2:
        selectedQuestion = eligibleQuestions[random.nextInt(eligibleQuestions.length)];
        break;
      
      default:
        selectedQuestion = eligibleQuestions[random.nextInt(eligibleQuestions.length)];
        break;
    }
    
    final String questionId = selectedQuestion['question_id']?.toString() ?? 'unknown';
    final int totalAttempts = selectedQuestion['total_attempts'] ?? 0;
    final double probability = selectedQuestion['accuracy_probability'] ?? 0.0;
    final String? lastRevised = selectedQuestion['last_revised']?.toString();
    
    QuizzerLogger.logMessage("Selected question:$questionId | Attempts: $totalAttempts | Prob: ${probability.toStringAsFixed(5)} | Last revised: $lastRevised");
    
    return selectedQuestion;
  }

  // Logic 2: Completely random selection
  Future<Map<String, dynamic>> _selectionLogicTwo(List<Map<String, dynamic>> eligibleQuestions) async {
    QuizzerLogger.logMessage("Selection Logic 2: Completely random selection");
    final random = Random();
    final selected = eligibleQuestions[random.nextInt(eligibleQuestions.length)];
    QuizzerLogger.logMessage("Selected question: $selected");
    return selected;
  }

  // Semi-Random selection Exploratory
  Future<Map<String, dynamic>> _selectionLogicThree(
    List<Map<String, dynamic>> eligibleQuestions, {
    double nullRevisedPercent = 0.60,
    double allQuestionsPercent = 0.39,
    double nonNullRevisedPercent = 0.01,
  }) async {
    final random = Random();
    final roll = random.nextDouble();
    
    List<Map<String, dynamic>> targetPool;
    
    if (roll < nullRevisedPercent) {
      targetPool = eligibleQuestions.where((q) => q['last_revised'] == null).toList();
      if (targetPool.isEmpty) targetPool = eligibleQuestions;
    } else if (roll < nullRevisedPercent + allQuestionsPercent) {
      targetPool = eligibleQuestions;
    } else if (roll < nullRevisedPercent + allQuestionsPercent + nonNullRevisedPercent) {
      targetPool = eligibleQuestions.where((q) => q['last_revised'] != null).toList();
      if (targetPool.isEmpty) targetPool = eligibleQuestions;
    } else {
      targetPool = eligibleQuestions;
    }
    
    final selected = targetPool[random.nextInt(targetPool.length)];
    QuizzerLogger.logMessage("Selected question: $selected");
    return selected;
  }

  // Logic 4: 50/50 split between unseen and seen questions
  Future<Map<String, dynamic>> _selectionLogicFour(List<Map<String, dynamic>> eligibleQuestions) async {
    QuizzerLogger.logMessage("Selection Logic 3: 50/50 unseen/seen split");
    
    final random = Random();
    
    // Split questions into unseen (last_revised is null) and seen (last_revised is not null)
    final unseenQuestions = eligibleQuestions.where((q) => q['last_revised'] == null).toList();
    final seenQuestions = eligibleQuestions.where((q) => q['last_revised'] != null).toList();
    
    // Determine which pool to select from
    List<Map<String, dynamic>> selectedPool;
    
    if (unseenQuestions.isEmpty && seenQuestions.isEmpty) {
      // No questions available (shouldn't happen but handle it)
      QuizzerLogger.logWarning("No questions available in either pool");
      return {};
    } else if (unseenQuestions.isEmpty) {
      // Only seen questions available, select from seen
      QuizzerLogger.logMessage("No unseen questions available, selecting from seen pool (${seenQuestions.length} questions)");
      selectedPool = seenQuestions;
    } else if (seenQuestions.isEmpty) {
      // Only unseen questions available, select from unseen
      QuizzerLogger.logMessage("No seen questions available, selecting from unseen pool (${unseenQuestions.length} questions)");
      selectedPool = unseenQuestions;
    } else {
      // Both pools have questions, 50/50 choice
      final bool selectUnseen = random.nextDouble() < 0.5;
      selectedPool = selectUnseen ? unseenQuestions : seenQuestions;
      QuizzerLogger.logMessage("Selected ${selectUnseen ? 'unseen' : 'seen'} pool (${selectedPool.length} questions)");
    }
    
    // Randomly select from chosen pool
    final selected = selectedPool[random.nextInt(selectedPool.length)];
    final lastRevised = selected['last_revised'];
    final prob = selected['accuracy_probability'] ?? 0.0;
    QuizzerLogger.logMessage("Selected question - last_revised: ${lastRevised ?? 'null'}, accuracy_probability: $prob");
    
    return selected;
  }

  // Logic 5: High probability focus with exploration
  Future<Map<String, dynamic>> _selectionLogicFive(List<Map<String, dynamic>> eligibleQuestions) async {
    QuizzerLogger.logMessage("Selection Logic 5: High probability focus with exploration");
    
    // Configurable probability thresholds
    const double veryHighThreshold = 0.90;
    const double highLower = 0.85;
    const double highUpper = 0.90;
    const double mediumLower = 0.50;
    const double mediumUpper = 0.85;
    const double lowUpper = 0.50;
    
    // Configurable selection probabilities (must sum to 1.0)
    const double veryHighSelectionRate = 0.50;  // 50%: 90%+ probability
    const double highSelectionRate = 0.40;      // 40%: 85%-90% probability
    const double mediumSelectionRate = 0.05;    // 5%: 50%-85% probability
    // const double lowSelectionRate = 0.05;       // 5%: 0%-50% probability
    
    final random = Random();
    final roll = random.nextDouble();
    
    List<Map<String, dynamic>> targetPool;
    
    if (roll < veryHighSelectionRate) {
      // Select from 90%+ probability
      targetPool = eligibleQuestions.where((q) => (q['accuracy_probability'] ?? 0.0) >= veryHighThreshold).toList();
      if (targetPool.isEmpty) targetPool = eligibleQuestions;
    } else if (roll < veryHighSelectionRate + highSelectionRate) {
      // Select from 85%-90% probability
      targetPool = eligibleQuestions.where((q) {
        final prob = q['accuracy_probability'] ?? 0.0;
        return prob >= highLower && prob < highUpper;
      }).toList();
      if (targetPool.isEmpty) targetPool = eligibleQuestions;
    } else if (roll < veryHighSelectionRate + highSelectionRate + mediumSelectionRate) {
      // Select from 50%-85% probability
      targetPool = eligibleQuestions.where((q) {
        final prob = q['accuracy_probability'] ?? 0.0;
        return prob >= mediumLower && prob < mediumUpper;
      }).toList();
      if (targetPool.isEmpty) targetPool = eligibleQuestions;
    } else {
      // Select from 0%-50% probability
      targetPool = eligibleQuestions.where((q) => (q['accuracy_probability'] ?? 0.0) < lowUpper).toList();
      if (targetPool.isEmpty) targetPool = eligibleQuestions;
    }
    
    final selected = targetPool[random.nextInt(targetPool.length)];
    final String questionId = selected['question_id']?.toString() ?? 'unknown';
    final int totalAttempts = selected['total_attempts'] ?? 0;
    final double probability = selected['accuracy_probability'] ?? 0.0;
    final String? lastRevised = selected['last_revised']?.toString();
    
    QuizzerLogger.logMessage("Selected question:$questionId | Attempts: $totalAttempts | Prob: ${probability.toStringAsFixed(5)} | Last revised: $lastRevised");
    
    return selected;
  }

  // Logic 6: Push all questions toward 95%+ probability
  Future<Map<String, dynamic>> _selectionLogicSix(List<Map<String, dynamic>> eligibleQuestions) async {
    QuizzerLogger.logMessage("Selection Logic 6: Push toward 90%+ probability");
    
    final random = Random();
    final roll = random.nextDouble();
    
    Map<String, dynamic> selected;
    
    if (roll < 0.95) {
      // 95%: Select closest to 90% but not above
      final belowThreshold = eligibleQuestions.where((q) => (q['accuracy_probability'] ?? 0.0) < 0.90).toList();
      
      if (belowThreshold.isEmpty) {
        // No questions below 95%, select randomly from all
        selected = eligibleQuestions[random.nextInt(eligibleQuestions.length)];
      } else {
        // Find questions closest to 90% from below
        double closestProb = 0.0;
        for (final q in belowThreshold) {
          final prob = q['accuracy_probability'] ?? 0.0;
          if (prob > closestProb) closestProb = prob;
        }
        
        // Get all questions at that closest probability
        final closestQuestions = belowThreshold.where((q) => (q['accuracy_probability'] ?? 0.0) == closestProb).toList();
        selected = closestQuestions[random.nextInt(closestQuestions.length)];
      }
    } else {
      // 5%: Random selection from above 90%
      final aboveThreshold = eligibleQuestions.where((q) => (q['accuracy_probability'] ?? 0.0) >= 0.90).toList();
      
      if (aboveThreshold.isEmpty) {
        // No questions above 95%, select randomly from all
        selected = eligibleQuestions[random.nextInt(eligibleQuestions.length)];
      } else {
        selected = aboveThreshold[random.nextInt(aboveThreshold.length)];
      }
    }
    
    final String questionId = selected['question_id']?.toString() ?? 'unknown';
    final int totalAttempts = selected['total_attempts'] ?? 0;
    final double probability = selected['accuracy_probability'] ?? 0.0;
    final String? lastRevised = selected['last_revised']?.toString();
    
    QuizzerLogger.logMessage("Selected question:$questionId | Attempts: $totalAttempts | Prob: ${probability.toStringAsFixed(5)} | Last revised: $lastRevised");
    
    return selected;
  }

}