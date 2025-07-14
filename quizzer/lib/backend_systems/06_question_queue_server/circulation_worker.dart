import 'dart:async';
import 'dart:math';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
// Caches
// Table Access
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';
// Workers
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart'; // Import SwitchBoard
import 'package:quizzer/backend_systems/10_switch_board/sb_question_worker_signals.dart'; // Import worker signals
import 'package:quizzer/backend_systems/10_switch_board/sb_other_signals.dart'; // Import other signals

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
  StreamSubscription? _questionAnsweredSubscription; // Subscription to question answered correctly signal
  // --------------------

  final SessionManager                _sessionManager       = SessionManager();
  final SwitchBoard                   _switchBoard          = SwitchBoard(); // Get SwitchBoard instance

  // --- Control Methods ---
  /// Starts the worker loop.
  Future<void> start() async {
    try {
      QuizzerLogger.logMessage('Entering CirculationWorker start()...');
      if (_isRunning) {
        QuizzerLogger.logWarning('CirculationWorker already running.');
        return;
      }
      _isRunning = true;

      // Subscribe to the question answered correctly stream
      _questionAnsweredSubscription = _switchBoard.onQuestionAnsweredCorrectly.listen((String questionId) {
        QuizzerLogger.logMessage('CirculationWorker: Received question answered correctly signal for question: $questionId.');
      });
      QuizzerLogger.logMessage('CirculationWorker: Subscribed to onQuestionAnsweredCorrectly stream.');

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
      await _questionAnsweredSubscription?.cancel();
      QuizzerLogger.logMessage('CirculationWorker: Unsubscribed from all streams.');
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
          try {
            await _selectAndAddQuestionToCirculation(userId);
          } catch (e) {
            QuizzerLogger.logWarning('Error in _selectAndAddQuestionToCirculation: $e');
            // Continue the loop even if selection fails
          }
          if (!_isRunning) break; // Check after processing
        } else {
          // Conditions not met to add. Wait for question answered correctly signal.
          if (!_isRunning) break;
          QuizzerLogger.logMessage('CirculationWorker: Conditions not met, waiting for question answered correctly signal...');

          // Signal that circulation worker is done adding questions
          signalCirculationWorkerFinished();
          await _switchBoard.onQuestionAnsweredCorrectly.first;
          QuizzerLogger.logMessage('CirculationWorker: Woke up by question answered correctly signal.');
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
  /// Uses direct database queries instead of caches for determination.
  Future<bool> _shouldAddNewQuestion() async {
    try {
      QuizzerLogger.logMessage('Entering CirculationWorker _shouldAddNewQuestion()...');
      
      assert(_sessionManager.userId != null, 'Circulation check requires logged-in user.');
      final userId = _sessionManager.userId!;
      
      QuizzerLogger.logMessage("Querying database for eligible questions data...");

      // Check if there are any non-circulating questions available first
      final List<Map<String, dynamic>> nonCirculatingQuestions = await getNonCirculatingQuestionsWithDetails(userId);
      if (nonCirculatingQuestions.isEmpty) {
        QuizzerLogger.logMessage("No non-circulating questions available, shouldAdd evaluates to -> false");
        return false;
      }

      // Use the two optimized database queries
      final int lowStreakCount = await getLowRevisionStreakEligibleCount(userId);
      final int totalEligibleCount = await getTotalEligibleCount(userId);

      // Condition 1: Less than 20 eligible questions with revision streak ≤ 2
      final bool lowStreakCondition = lowStreakCount < 20;
      QuizzerLogger.logMessage("lowStreakCondition evaluates to -> $lowStreakCondition (count: $lowStreakCount)");

      // Condition 2: Less than 100 total eligible questions
      final bool lowTotalCondition = totalEligibleCount < 100;
      QuizzerLogger.logMessage("lowTotalCondition evaluates to -> $lowTotalCondition (count: $totalEligibleCount)");
      
      // Return true if either condition is met (we need more questions in circulation)
      final bool shouldAdd = lowStreakCondition || lowTotalCondition;
      QuizzerLogger.logMessage("shouldAdd evaluates to -> $shouldAdd");
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

      // --- Database Operations Required for Selection ---
      Map<String, int> currentRatio = {};
      Map<String, int> interestData = {};

      // Calculate ratio using the cache first
      currentRatio = await _calculateCurrentRatio(); // No longer needs db or userId

      // Fetch interest data - table function handles its own database access
      interestData = await getUserSubjectInterests(userId);
      // --- End DB Operations ---

      // Select the prioritized question - it will fetch its own data
      Map<String, dynamic> selectedRecord = await _selectPrioritizedQuestion(
        interestData,
        currentRatio
      );
      
      // Check if a question was selected
      if (selectedRecord.isEmpty) {
        QuizzerLogger.logWarning('No question selected for circulation - no non-circulating questions available');
        return; // Exit early without adding any question
      }
      
      // Create mutable copy and update circulation status BEFORE passing down
      await _addQuestionToCirculation(userId, selectedRecord['question_id'] as String);
    } catch (e) {
      QuizzerLogger.logError('Error in CirculationWorker _selectAndAddQuestionToCirculation - $e');
      rethrow;
    }
  }

  /// Calculates the subject distribution ratio of currently circulating questions
  /// by querying the database directly.
  Future<Map<String, int>> _calculateCurrentRatio() async {
    try {
      QuizzerLogger.logMessage('Entering CirculationWorker _calculateCurrentRatio()...');
      Map<String, int> ratio = {};

      assert(_sessionManager.userId != null, 'Circulation check requires logged-in user.');
      final userId = _sessionManager.userId!;

      // Get all questions currently in circulation for this user
      final List<Map<String, dynamic>> circulatingQuestions = await getQuestionsInCirculation(userId);

      if (circulatingQuestions.isEmpty) {
        QuizzerLogger.logMessage('CirculationWorker: No questions currently circulating.');
        return ratio; // Return empty ratio
      }

      QuizzerLogger.logMessage('CirculationWorker: Calculating ratio for ${circulatingQuestions.length} circulating questions...');
      
      // Loop through circulating questions and calculate subject distribution
      for (final questionRecord in circulatingQuestions) {
        final String questionId = questionRecord['question_id'] as String;
        final questionDetails = await getQuestionAnswerPairById(questionId);
        
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

      QuizzerLogger.logValue('CirculationWorker: Calculated Current Ratio: $ratio');
      return ratio;
    } catch (e) {
      QuizzerLogger.logError('Error in CirculationWorker _calculateCurrentRatio - $e');
      rethrow;
    }
  }

  /// Selects the best question to add based on interest, ratio, and availability.
  /// Fetches its own non-circulating questions data from the database.
  Future<Map<String, dynamic>> _selectPrioritizedQuestion(
    Map<String, int> interestData,
    Map<String, int> currentRatio,
  ) async {
    try {
      QuizzerLogger.logMessage('Entering CirculationWorker _selectPrioritizedQuestion()...');
      
      // Fetch non-circulating questions with details from the database
      final List<Map<String, dynamic>> nonCirculatingRecords = await getNonCirculatingQuestionsWithDetails(_sessionManager.userId!);
      
      if (nonCirculatingRecords.isEmpty) {
        QuizzerLogger.logWarning('No non-circulating questions available for selection');
        return {}; // Return empty map to indicate no selection possible
      }
      
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

  /// Updates the DB status to put a question into circulation.
  Future<void> _addQuestionToCirculation(String userId, String questionId) async {
    try {
      QuizzerLogger.logMessage('Entering CirculationWorker _addQuestionToCirculation()...');
      
      // Set 'inCirculation' to true in the database
      await setCirculationStatus(userId, questionId, true);

      // Signal that a question was added to circulation
      signalCirculationWorkerQuestionAdded();
      
      QuizzerLogger.logSuccess('Question $questionId added to circulation');
    } catch (e) {
      QuizzerLogger.logError('Error in CirculationWorker _addQuestionToCirculation - $e');
      rethrow;
    }
  }
}
