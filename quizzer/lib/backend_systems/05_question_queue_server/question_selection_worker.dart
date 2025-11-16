import 'dart:async';
import 'dart:math';
import 'package:quizzer/backend_systems/05_question_queue_server/circulation_worker.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/08_data_caches/question_queue_cache.dart';
import 'package:quizzer/backend_systems/08_data_caches/answer_history_cache.dart';
import 'package:quizzer/backend_systems/09_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/09_switch_board/sb_question_worker_signals.dart';
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
  final SessionManager _sessionManager = SessionManager();
  final QuestionQueueCache _queueCache = QuestionQueueCache();
  // final UnprocessedCache _unprocessedCache = UnprocessedCache();

  // --- Control Methods ---

  /// Starts the PresentationSelectionWorker.
  /// Clears both QuestionQueueCache and AnswerHistoryCache to ensure clean state,
  /// then begins the main selection loop that monitors queue levels and adds questions as needed.
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

  /// Stops the PresentationSelectionWorker.
  /// Sets the running flag to false, clears both caches, and waits for the main loop to complete.
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
  
  /// Main worker loop that continuously monitors the question queue and adds questions as needed.
  /// Checks if queue is below threshold, fetches eligible questions, filters out recently answered
  /// and already queued questions, then either adds all remaining questions directly (if insufficient)
  /// or uses advanced selection logic to fill the queue to threshold. Waits for answer/circulation
  /// signals between cycles.
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
  
  /// Selects a single question from eligible questions and adds it to the queue cache.
  /// Uses the configured selection logic (currently logic 7) to pick the best question,
  /// performs data consistency checks via compareAndUpdateQuestionRecord, then adds
  /// the selected question to the queue cache.
  /// Returns the question_id if successful, null otherwise.
  Future<String?> _selectAndQueueQuestion(List<Map<String, dynamic>> eligibleQuestions) async {
    try {
      QuizzerLogger.logMessage('Entering PresentationSelectionWorker _selectAndQueueQuestion()...');
      if (!_isRunning) return null;

      // 1. Call _selectNextQuestionFromList to get the selected question
      // Selection logic #any# is used for AB testing. Selection logic can be changed to assign users different algorithms.
      final Map<String, dynamic> selectedQuestion = await _selectNextQuestionFromList(eligibleQuestions, selectionLogic: 0);
      
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
  
  /// Router function that determines which selection logic to use.
  /// Routes to one of the _selectionLogic* functions based on the selectionLogic parameter.
  /// This architecture enables A/B testing different selection algorithms by assigning different
  /// logic values to different users. Default is logic 1 if invalid value provided.
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
        case 7:
          // Revision streak prioritization with probability filtering
          return await _selectionLogicSeven(eligibleQuestions);
        default:
          QuizzerLogger.logWarning('Invalid selectionLogic value: $selectionLogic. Defaulting to logic 1.');
          return await _selectionLogicOne(eligibleQuestions);
      }
    } catch (e) {
      QuizzerLogger.logError('Error in PresentationSelectionWorker _selectNextQuestionFromList - $e');
      rethrow;
    }
  }

  /// Selection Logic 0: Lowest revision streak, then lowest probability.
  /// Finds all questions with the lowest revision_streak value, then among those
  /// selects the one with the lowest accuracy_probability. Prioritizes questions
  /// that need the most review attention.
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
    
    _logSelection(selected);
    return selected;
  }

  /// Selection Logic 1: Probabilistic selection with ML threshold.
  /// Uses weighted random selection with three modes:
  /// - 10% chance: Select questions closest to the ML model's optimal threshold
  /// - 85% chance: Select question with lowest probability (needs most practice)
  /// - 5% chance: Random selection for exploration
  /// Only considers questions below highProbThreshold (default 0.95) for targeted modes.
  Future<Map<String, dynamic>> _selectionLogicOne(
    List<Map<String, dynamic>> eligibleQuestions, {
    double highProbThreshold = 0.95,
    double thresholdSelectionChance = 0.10,
    double lowestProbSelectionChance = 0.85,
  }) async {
    QuizzerLogger.logMessage("Selection Logic 1: Probabilistic with ML threshold");
    
    final random = Random();
    final double roll = random.nextDouble();
    final double threshold = CirculationWorker().idealThreshold;
    
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
    
    _logSelection(selectedQuestion);
    return selectedQuestion;
  }

  /// Selection Logic 2: Completely random selection.
  /// Selects a random question from all eligible questions with equal probability.
  /// Provides baseline for comparing other selection strategies.
  Future<Map<String, dynamic>> _selectionLogicTwo(List<Map<String, dynamic>> eligibleQuestions) async {
    QuizzerLogger.logMessage("Selection Logic 2: Completely random selection");
    final random = Random();
    final selected = eligibleQuestions[random.nextInt(eligibleQuestions.length)];
    _logSelection(selected);
    return selected;
  }

  /// Selection Logic 3: Semi-random exploratory selection.
  /// Weighted random selection across three pools:
  /// - 60% (default): Unseen questions (last_revised is null)
  /// - 39% (default): All questions
  /// - 1% (default): Previously seen questions (last_revised is not null)
  /// Percentages are configurable parameters. Falls back to all questions if selected pool is empty.
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
    _logSelection(selected);
    return selected;
  }

  /// Selection Logic 4: 50/50 split between unseen and seen questions.
  /// Randomly selects from either unseen (last_revised is null) or seen (last_revised is not null)
  /// pools with equal 50% probability. If one pool is empty, selects from the other pool.
  /// Balances exploration of new material with reinforcement of learned material.
  Future<Map<String, dynamic>> _selectionLogicFour(List<Map<String, dynamic>> eligibleQuestions) async {
    QuizzerLogger.logMessage("Selection Logic 4: 50/50 unseen/seen split");
    
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
    _logSelection(selected);
    return selected;
  }

  /// Selection Logic 5: High probability focus with exploration.
  /// Weighted random selection targeting different probability ranges:
  /// - 50%: Very high probability (>= 0.90) - reinforce well-learned material
  /// - 40%: High probability (0.85-0.90) - maintain strong knowledge
  /// - 5%: Medium probability (0.50-0.85) - some reinforcement
  /// - 5%: Low probability (< 0.50) - minimal exploration of weak areas
  /// Falls back to all questions if selected range is empty.
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
    _logSelection(selected);
    return selected;
  }

  /// Selection Logic 6: Push all questions toward 90%+ probability.
  /// Focuses on getting questions to mastery level:
  /// - 95%: Select question closest to (but below) 0.90 probability - push toward threshold
  /// - 5%: Random selection from questions >= 0.90 - maintain mastery
  /// Strategy emphasizes moving lower-probability questions up to the 90% mastery threshold.
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
    
    _logSelection(selected);
    return selected;
  }

  /// Selection Logic 7: Revision streak prioritization with probability filtering.
  /// Three-tiered selection strategy focusing on review frequency and accuracy:
  /// 1. FIRST PRIORITY: All questions with revision_streak = 0 (never successfully reviewed)
  ///    - Randomly selects from this pool if any exist
  /// 2. SECOND PRIORITY: Questions with revision_streak > 0 AND probability < 0.90
  ///    - Finds minimum revision_streak among these questions
  ///    - Within that streak, finds minimum probability
  ///    - Selects from questions matching both criteria
  /// 3. FALLBACK: If no questions < 0.90 probability exist
  ///    - Selects question with lowest overall probability
  /// This strategy ensures questions needing review get priority while respecting mastery levels.
  Future<Map<String, dynamic>> _selectionLogicSeven(List<Map<String, dynamic>> eligibleQuestions) async {
    // TODO Update Logic seven to randomly select 5% of the time some question below the current revision streak we are working with
    QuizzerLogger.logMessage("Selection Logic 7: Revision streak prioritization");
    
    final streak0 = eligibleQuestions.where((q) => (q['revision_streak'] ?? 0) == 0).toList();

    if (streak0.isNotEmpty) {
      final selected = streak0[Random().nextInt(streak0.length)];
      _logSelection(selected);
      return selected;
    }
    
    final nonZeroBelowIdealThreshold = eligibleQuestions.where((q) => 
      (q['revision_streak'] ?? 0) > 0 && (q['accuracy_probability'] ?? 0.0) < CirculationWorker().idealThreshold
    ).toList();
    

    if (nonZeroBelowIdealThreshold.isNotEmpty) {
      int minStreak = nonZeroBelowIdealThreshold.map((q) => q['revision_streak'] as int? ?? 0).reduce((a, b) => a < b ? a : b);
      final minStreakQuestions = nonZeroBelowIdealThreshold.where((q) => (q['revision_streak'] ?? 0) == minStreak).toList();
      double minProb = minStreakQuestions.map((q) => q['accuracy_probability'] as double? ?? 0.0).reduce((a, b) => a < b ? a : b);
      final candidates = minStreakQuestions.where((q) => (q['accuracy_probability'] ?? 0.0) == minProb).toList();
      
      final selected = candidates[Random().nextInt(candidates.length)];
      _logSelection(selected);
      return selected;
    }
    
    double minProb = eligibleQuestions.map((q) => q['accuracy_probability'] as double? ?? 0.0).reduce((a, b) => a < b ? a : b);
    final lowestProb = eligibleQuestions.where((q) => (q['accuracy_probability'] ?? 0.0) == minProb).toList();
    
    final selected = lowestProb[Random().nextInt(lowestProb.length)];
    _logSelection(selected);
    return selected;
  }

  /// Logs the selected question details including ID, attempts, probability, last revised date, and revision streak.
  /// Used by all selection logic functions for consistent logging format.
  void _logSelection(Map<String, dynamic> question) {
    QuizzerLogger.logMessage("Selected question:${question['question_id'] ?? 'unknown'} | Attempts: ${question['total_attempts'] ?? 0} | Prob: ${(question['accuracy_probability'] ?? 0.0).toStringAsFixed(5)} | Last revised: ${question['last_revised'] ?? 'null'} | Revision streak: ${question['revision_streak'] ?? 0}");
  }
}