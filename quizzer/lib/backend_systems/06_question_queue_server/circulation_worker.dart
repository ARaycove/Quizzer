import 'dart:async';
import 'dart:math';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
// Caches
import 'package:quizzer/backend_systems/09_data_caches/non_circulating_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/unprocessed_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/circulating_questions_cache.dart';
// Table Access
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
// Workers
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart'; // Import SwitchBoard
import 'package:quizzer/backend_systems/10_switch_board/sb_question_worker_signals.dart'; // Import worker signals

// ==========================================
// Circulation Worker
// ==========================================
/// Determines when and which questions should be moved into active circulation.
class CirculationWorker {
  // --- Singleton Setup ---
  static final CirculationWorker _instance = CirculationWorker._internal();
  factory CirculationWorker() => _instance;
  CirculationWorker._internal();

  // --- Worker State ---
  bool                _isRunning = false;
  DateTime?           _lastActivationSignalTime; // Timestamp of the last signal
  StreamSubscription? _activationSubscription; // Subscription to the SwitchBoard stream
  // --------------------

  // --- Dependencies ---
  final NonCirculatingQuestionsCache  _nonCirculatingCache  = NonCirculatingQuestionsCache();
  final UnprocessedCache              _unprocessedCache     = UnprocessedCache();
  final CirculatingQuestionsCache     _circulatingCache     = CirculatingQuestionsCache();
  final SessionManager                _sessionManager       = SessionManager();
  final SwitchBoard                   _switchBoard          = SwitchBoard(); // Get SwitchBoard instance

  // --- Control Methods ---
  /// Starts the worker loop.
  void start() {
    try {
      QuizzerLogger.logMessage('Entering CirculationWorker start()...');
      if (_isRunning) {
        QuizzerLogger.logWarning('CirculationWorker already running.');
        return;
      }
      _isRunning = true;

      // Subscribe to the module activation stream - Uses the activation time from the signal
      _activationSubscription = _switchBoard.onModuleRecentlyActivated.listen((DateTime activationTime) {
        QuizzerLogger.logMessage('CirculationWorker: Received recent activation signal with time: $activationTime.');
        _lastActivationSignalTime = activationTime; // Use the time from the signal
      });
      QuizzerLogger.logMessage('CirculationWorker: Subscribed to onModuleRecentlyActivated stream.');

      _runLoop(); // Start the loop asynchronously
    } catch (e) {
      QuizzerLogger.logError('Error starting CirculationWorker - $e');
      rethrow;
    }
  }

  /// Stops the worker loop.
  Future<void> stop() async {
    try {
      QuizzerLogger.logMessage('Entering CirculationWorker stop()...');
      if (!_isRunning) {
        QuizzerLogger.logWarning('CirculationWorker already stopped.');
        return;
      }
      _isRunning = false;
      await _activationSubscription?.cancel(); // Cancel stream subscription
      _activationSubscription = null;
      QuizzerLogger.logMessage('CirculationWorker: Unsubscribed from onModuleRecentlyActivated stream.');
    } catch (e) {
      QuizzerLogger.logError('Error stopping CirculationWorker - $e');
      rethrow;
    }
  }
  // ----------------------

  // --- Main Loop ---
  Future<void> _runLoop() async {
    try {
      QuizzerLogger.logMessage('Entering CirculationWorker _runLoop()...');
      while (_isRunning) {
        if (!_isRunning) break; // Check if stopped before starting the cycle
        
        assert(_sessionManager.userId != null, 'Circulation check requires logged-in user.');
        final userId = _sessionManager.userId!;

        // 1. Check if we should add a question
        final bool shouldAdd = await _shouldAddNewQuestion();

        if (shouldAdd) {
          QuizzerLogger.logMessage("$shouldAdd : selecting question");
          await _selectAndAddQuestionToCirculation(userId);
          if (!_isRunning) break; // Check after processing
        } else {
          // Conditions not met to add. Determine why and wait appropriately.
          final bool nonCirculatingIsEmpty = await _nonCirculatingCache.isEmpty();
          if (nonCirculatingIsEmpty) {
            // Wait because input is empty
            QuizzerLogger.logMessage('CirculationWorker: Conditions not met & NonCirculating empty, waiting for non-circulating record...');
            if (!_isRunning) break;
            await _switchBoard.onNonCirculatingQuestionsAdded.first;
            QuizzerLogger.logMessage('CirculationWorker: Woke up by NonCirculatingQuestionsCache signal.');
          } else {
            // Wait because eligible cache conditions were not met
            QuizzerLogger.logMessage('CirculationWorker: Conditions not met (Eligible Cache ok), waiting for EligibleCache removal signal...');
            if (!_isRunning) break;
            await _switchBoard.onEligibleQuestionsRemoved.first;
            QuizzerLogger.logMessage('CirculationWorker: Woke up by EligibleQuestionsCache removal signal.');
          }
        }
      }
      QuizzerLogger.logMessage('CirculationWorker loop finished.');
    } catch (e) {
      QuizzerLogger.logError('Error in CirculationWorker _runLoop - $e');
      rethrow;
    }
  }
  // -----------------

    /// Checks if conditions are met to add a new question to circulation.
  /// Includes logic to delay check if a module activation signal was recently received.
  Future<bool> _shouldAddNewQuestion() async {
    try {
      QuizzerLogger.logMessage('Entering CirculationWorker _shouldAddNewQuestion()...');
      
      // 1. Check if the timestamp indicates a recent activation
      DateTime? activationTimeToProcess = _lastActivationSignalTime; // Capture timestamp locally
      if (activationTimeToProcess != null) {
          // Consume the signal timestamp immediately so it's only processed once
          _lastActivationSignalTime = null; 

          final now = DateTime.now();
          final timeSinceSignal = now.difference(activationTimeToProcess);
          // User wants 1 second check
          const requiredDelay = Duration(seconds: 1); 

          if (timeSinceSignal < requiredDelay) {
              // Calculate remaining delay needed to reach 1 second total
              final delayNeeded = requiredDelay - timeSinceSignal; 
              QuizzerLogger.logMessage('CirculationWorker: Recent activation detected. Delaying check by ${delayNeeded.inMilliseconds}ms...');
              await Future.delayed(delayNeeded);
              if (!_isRunning) return false; // Check if stopped during delay
          }
          QuizzerLogger.logMessage('CirculationWorker: Resuming check after handling recent activation signal.');
      }

      // 2. Query database directly for eligible questions data
      assert(_sessionManager.userId != null, 'Circulation check requires logged-in user.');
      final userId = _sessionManager.userId!;
      
      QuizzerLogger.logMessage("Querying database for eligible questions data...");
      
      // Get all eligible questions from database (efficient query with index)
      final eligibleQuestions = await getEligibleUserQuestionAnswerPairs(userId);

      // Condition 1: Less than 20 eligible questions with streak < 3
      final lowStreakCount = eligibleQuestions.where((r) => (r['revision_streak'] as int? ?? 0) < 3).length;
      final bool lowStreakCondition = lowStreakCount < 20;
      QuizzerLogger.logMessage("lowStreakCondition evaluates to -> $lowStreakCondition (count: $lowStreakCount)");

      // Condition 2: Less than 100 total eligible questions
      final totalEligibleCount = eligibleQuestions.length;
      final bool lowTotalCondition = totalEligibleCount < 100;
      QuizzerLogger.logMessage("lowTotalCondition evaluates to -> $lowTotalCondition (count: $totalEligibleCount)");
      
      // --- Proceed only if eligible questions ARE low --- 
      // Condition 3: Non-circulating cache must NOT be empty
      final bool nonCirculatingEmpty = await _nonCirculatingCache.isEmpty();
      QuizzerLogger.logMessage("nonCirculatingNotEmpty evaluates to -> $nonCirculatingEmpty");

      // Return true only if eligible is low AND non-circulating has questions
      final bool shouldAdd = (lowStreakCondition || lowTotalCondition) && !nonCirculatingEmpty;
      QuizzerLogger.logMessage("shouldAdd evaluates to -> $shouldAdd (Eligible low: ${(lowStreakCondition || lowTotalCondition)}, NonCirculatingEmpty: $nonCirculatingEmpty)");
      return shouldAdd;
    } catch (e) {
      QuizzerLogger.logError('Error in CirculationWorker _shouldAddNewQuestion - $e');
      rethrow;
    }
  }

  /// Selects the best non-circulating question and adds it to circulation.
  Future<void> _selectAndAddQuestionToCirculation(String userId) async {
    try {
      QuizzerLogger.logMessage('Entering CirculationWorker _selectAndAddQuestionToCirculation()...');
      final nonCirculatingRecords = await _nonCirculatingCache.peekAllRecords();
      if (nonCirculatingRecords.isEmpty) { return; }

      // --- Database Operations Required for Selection ---
      Map<String, int> currentRatio = {};
      Map<String, int> interestData = {};

      // Calculate ratio using the cache first
      currentRatio = await _calculateCurrentRatio(); // No longer needs db or userId

      // Fetch interest data - table function handles its own database access
      interestData = await getUserSubjectInterests(userId);
      // --- End DB Operations ---

      // Select the prioritized question
      Map<String, dynamic> selectedRecord = _selectPrioritizedQuestion(
        interestData,
        currentRatio,
        nonCirculatingRecords
      );
      // Create mutable copy and update circulation status BEFORE passing down
      await _addQuestionToCirculation(userId, selectedRecord);
    } catch (e) {
      QuizzerLogger.logError('Error in CirculationWorker _selectAndAddQuestionToCirculation - $e');
      rethrow;
    }
  }

  /// Calculates the subject distribution ratio of currently circulating questions
  /// using the CirculatingQuestionsCache.
  Future<Map<String, int>> _calculateCurrentRatio() async {
    try {
      QuizzerLogger.logMessage('Entering CirculationWorker _calculateCurrentRatio()...');
      Map<String, int> ratio = {};
      final circulatingQuestionIds = await _circulatingCache.peekAllQuestionIds();

      if (circulatingQuestionIds.isEmpty) {
        // QuizzerLogger.logMessage('CirculationWorker: No questions currently circulating.');
        return ratio; // Return empty ratio
      }

      // QuizzerLogger.logMessage('CirculationWorker: Calculating ratio for ${circulatingQuestionIds.length} circulating questions...');
      
      // Loop will proceed. If getQuestionAnswerPairById fails, it will throw (Fail Fast).
      for (var questionId in circulatingQuestionIds) {
        final questionDetails = await getQuestionAnswerPairById(questionId);
        // Handle case where question might be in cache but removed from DB? Unlikely but possible.
        if (questionDetails.isNotEmpty) {
          final subjects = (questionDetails['subjects'] as String? ?? '').split(',');
          for (var subject in subjects) {
            if (subject.isNotEmpty) {
              ratio[subject] = (ratio[subject] ?? 0) + 1;
            }
          }
        } else {
          QuizzerLogger.logWarning('CirculationWorker: Circulating QID $questionId not found in DB during ratio calc.');
        }
      }

      // QuizzerLogger.logValue('CirculationWorker: Calculated Current Ratio: $ratio');
      return ratio;
    } catch (e) {
      QuizzerLogger.logError('Error in CirculationWorker _calculateCurrentRatio - $e');
      rethrow;
    }
  }

  /// Selects the best question to add based on interest, ratio, and availability.
  /// Replaces placeholder with logic from question_queue_maintainer.
  Map<String, dynamic> _selectPrioritizedQuestion(
    Map<String, int> interestData,
    Map<String, int> currentRatio,
    List<Map<String, dynamic>> nonCirculatingRecords
  ) {
    try {
      QuizzerLogger.logMessage('Entering CirculationWorker _selectPrioritizedQuestion()...');
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
      } 

      // Create a sorted list of subjects with positive deficits (most needed first)
      final List<MapEntry<String, double>> sortedNeededSubjects = deficits.entries
          .where((entry) => entry.value > 0) // Only consider needed subjects
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value)); // Sort descending by deficit

      Map<String, dynamic>? selectedRecord; // Keep nullable for iteration logic

      // Iterate through needed subjects in order of priority
      if (sortedNeededSubjects.isNotEmpty) {
        for (final entry in sortedNeededSubjects) {
            final neededSubject = entry.key;

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
              final random = Random();
              selectedRecord = potentialMatches[random.nextInt(potentialMatches.length)];
              break; // Found a match based on priority, break the loop
            } 
        }
      } 

      // Fallback to random selection ONLY if no prioritized selection was made
      if (selectedRecord == null) {
        final random = Random();
        // Assumes nonCirculatingRecords is not empty (checked by caller)
        selectedRecord = nonCirculatingRecords[random.nextInt(nonCirculatingRecords.length)];
      }

      // selectedRecord is guaranteed to be non-null here due to fallback
      return selectedRecord;
    } catch (e) {
      QuizzerLogger.logError('Error in CirculationWorker _selectPrioritizedQuestion - $e');
      rethrow;
    }
  }

  /// Updates the DB status and moves the record from NonCirculating to Unprocessed cache.
  Future<void> _addQuestionToCirculation(String userId, Map<String, dynamic> recordToAdd) async {
    try {
      QuizzerLogger.logMessage('Entering CirculationWorker _addQuestionToCirculation()...');
      final questionId = recordToAdd['question_id'] as String;
      
      // Remove from NonCirculating Cache first
      final removedRecord = await _nonCirculatingCache.getAndRemoveRecordByQuestionId(questionId);
      if (removedRecord.isEmpty) {
        QuizzerLogger.logWarning('CirculationWorker: Selected record $questionId not found in NonCirculatingCache during add.');
        return;
      }
      Map<String, dynamic> mutableRecord = Map<String, dynamic>.from(removedRecord);
      mutableRecord['in_circulation'] = 1;
      
      // Add to Unprocessed Cache first
      await _unprocessedCache.addRecord(removedRecord);

      // Set 'inCirculation' to true in the database - table function handles its own database access
      await setCirculationStatus(userId, questionId, true);

      // Add the record (already modified by caller) back to the UnprocessedCache
      await _unprocessedCache.addRecord(mutableRecord);

      // Signal that a question was added to circulation
      signalCirculationWorkerQuestionAdded();
    } catch (e) {
      QuizzerLogger.logError('Error in CirculationWorker _addQuestionToCirculation - $e');
      rethrow;
    }
  }

}
