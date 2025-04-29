import 'dart:async';
import 'dart:math';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
// Caches
import 'package:quizzer/backend_systems/09_data_caches/eligible_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/non_circulating_questions_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/unprocessed_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/circulating_questions_cache.dart';
// Table Access
import 'package:quizzer/backend_systems/00_database_manager/tables/user_question_answer_pairs_table.dart' as uq_pairs_table;
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart' as q_pairs_table;
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile_table.dart' as user_profile_table;
// Workers
import 'package:quizzer/backend_systems/06_question_queue_server/question_selection_worker.dart';
import 'switch_board.dart'; // Import SwitchBoard

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
  Completer<void>?    _stopCompleter;
  bool                _isInitialLoop = true;
  DateTime?           _lastActivationSignalTime; // Timestamp of the last signal
  StreamSubscription? _activationSubscription; // Subscription to the SwitchBoard stream
  // --------------------

  // --- Dependencies ---
  final EligibleQuestionsCache        _eligibleCache        = EligibleQuestionsCache();
  final NonCirculatingQuestionsCache  _nonCirculatingCache  = NonCirculatingQuestionsCache();
  final UnprocessedCache              _unprocessedCache     = UnprocessedCache();
  final CirculatingQuestionsCache     _circulatingCache     = CirculatingQuestionsCache();
  final DatabaseMonitor               _dbMonitor            = getDatabaseMonitor();
  final SessionManager                _sessionManager       = SessionManager();
  final SwitchBoard                   _switchBoard          = SwitchBoard(); // Get SwitchBoard instance

  // --- Control Methods ---
  /// Starts the worker loop.
  void start() {
    QuizzerLogger.logMessage('Entering CirculationWorker start()...');
    if (_isRunning) {
      return; // Already running
    }
    _isRunning = true;
    _isInitialLoop = true;
    _stopCompleter = Completer<void>();

    // Subscribe to the module activation stream - Uses the activation time from the signal
    _activationSubscription = _switchBoard.onModuleRecentlyActivated.listen((DateTime activationTime) { // Correct parameter type
      QuizzerLogger.logMessage('CirculationWorker: Received recent activation signal with time: $activationTime.');
      _lastActivationSignalTime = activationTime; // Use the time from the signal
    });
    QuizzerLogger.logMessage('CirculationWorker: Subscribed to onModuleRecentlyActivated stream.');

    _runLoop(); // Start the loop asynchronously
    // QuizzerLogger.logMessage('CirculationWorker started.');
  }

  /// Stops the worker loop.
  Future<void> stop() async {
    QuizzerLogger.logMessage('Entering CirculationWorker stop()...');
    if (!_isRunning) {
      return; // Already stopped
    }
    _isRunning = false;
    await _activationSubscription?.cancel(); // Cancel stream subscription
    _activationSubscription = null;
    QuizzerLogger.logMessage('CirculationWorker: Unsubscribed from onModuleRecentlyActivated stream.');
    await _stopCompleter?.future; // Wait for loop completion
    // QuizzerLogger.logMessage('CirculationWorker stopped.');
  }
  // ----------------------

  // --- Main Loop ---
  Future<void> _runLoop() async {
    QuizzerLogger.logMessage('Entering CirculationWorker _runLoop()...');
    while (_isRunning) {
      // QuizzerLogger.logMessage('CirculationWorker: Starting cycle...');
      
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
        // --- Start PresentationSelectionWorker after first cycle --- 
        if (_isRunning && _isInitialLoop) {
          QuizzerLogger.logMessage('CirculationWorker: Starting Presentation Selection Worker (first cycle complete)...');
          final selectionWorker = PresentationSelectionWorker();
          selectionWorker.start();
          _isInitialLoop = false; // Set flag so it doesn't start again
          QuizzerLogger.logSuccess('CirculationWorker: Presentation Selection Worker started.');
        }
        // Conditions not met to add. Determine why and wait appropriately.
        final bool nonCirculatingIsEmpty = await _nonCirculatingCache.isEmpty();
        if (nonCirculatingIsEmpty) {
          // Wait because input is empty
          QuizzerLogger.logMessage('CirculationWorker: Conditions not met & NonCirculating empty, waiting for non-circulating record...');
           if (!_isRunning) break;
          await _nonCirculatingCache.onRecordAdded.first;
          QuizzerLogger.logMessage('CirculationWorker: Woke up by NonCirculatingCache notification.');
        } else {
          // Wait because eligible cache conditions were not met
          QuizzerLogger.logMessage('CirculationWorker: Conditions not met (Eligible Cache ok), waiting for EligibleCache low signal...');
           if (!_isRunning) break;
          await _switchBoard.onEligibleCacheLowSignal.first;
          QuizzerLogger.logMessage('CirculationWorker: Woke up by EligibleCache low signal.');
        }
      }
      

    }
    _stopCompleter?.complete(); // Signal loop completion
    // QuizzerLogger.logMessage('CirculationWorker loop finished.');
  }
  // -----------------

  /// Checks if conditions are met to add a new question to circulation.
  /// Includes logic to delay check if a module activation signal was recently received.
  Future<bool> _shouldAddNewQuestion() async {
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
    // 2. Now do the rest
    QuizzerLogger.logMessage("Checking eligible Cache for conditions");
    final eligibleRecords = await _eligibleCache.peekAllRecords();

    // Condition 1: Less than 20 eligible questions with streak < 3
    final lowStreakCount = eligibleRecords.where((r) => (r['revision_streak'] as int? ?? 0) < 3).length;
    final bool lowStreakCondition = lowStreakCount < 20;
    QuizzerLogger.logMessage("lowStreakCondition evaluates to -> $lowStreakCondition");

    // Condition 2: Less than 100 total eligible questions
    final totalEligibleCount = eligibleRecords.length;
    final bool lowTotalCondition = totalEligibleCount < 100;
    QuizzerLogger.logMessage("lowTotalCondition evaluates to -> $lowTotalCondition");
    
    // --- Proceed only if eligible cache IS low --- 
    // Condition 3: Non-circulating cache must NOT be empty
    final bool nonCirculatingEmpty = (await _nonCirculatingCache.isEmpty());
    QuizzerLogger.logMessage("nonCirculatingNotEmpty evaluate to -> $nonCirculatingEmpty");

    // Return true only if eligible is low AND non-circulating has questions
    final bool shouldAdd = (lowStreakCondition || lowTotalCondition) && !nonCirculatingEmpty;
    QuizzerLogger.logMessage("shouldAdd evaluates to -> $shouldAdd (Eligible low: ${(lowStreakCondition || lowTotalCondition)}, NonCirculatingEmpty: $nonCirculatingEmpty)");
    return shouldAdd;
  }

  /// Selects the best non-circulating question and adds it to circulation.
  Future<void> _selectAndAddQuestionToCirculation(String userId) async {
    QuizzerLogger.logMessage('Entering CirculationWorker _selectAndAddQuestionToCirculation()...');
    final nonCirculatingRecords = await _nonCirculatingCache.peekAllRecords();
    if (nonCirculatingRecords.isEmpty) { return; }

    // --- Database Operations Required for Selection ---
    Map<String, int> currentRatio = {};
    Map<String, int> interestData = {};
    Database? db;

    // Calculate ratio using the cache first
    currentRatio = await _calculateCurrentRatio(); // No longer needs db or userId

    // Fetch interest data (still needs DB)
    db = await _getDbAccess();
    if(db == null) return; // Failed to get DB

    interestData = await user_profile_table.getUserSubjectInterests(userId, db);
    
    // Release DB AFTER successful reads
    _dbMonitor.releaseDatabaseAccess();
    db = null; // Ensure db isn't reused accidentally
    // --- End DB Operations ---

    // Select the prioritized question
    Map<String, dynamic> selectedRecord = _selectPrioritizedQuestion(
      interestData,
      currentRatio,
      nonCirculatingRecords
    );
    // Create mutable copy and update circulation status BEFORE passing down
    await _addQuestionToCirculation(userId, selectedRecord);
  }

  /// Calculates the subject distribution ratio of currently circulating questions
  /// using the CirculatingQuestionsCache.
  Future<Map<String, int>> _calculateCurrentRatio() async {
    QuizzerLogger.logMessage('Entering CirculationWorker _calculateCurrentRatio()...');
    Map<String, int> ratio = {};
    final circulatingQuestionIds = await _circulatingCache.peekAllQuestionIds();

    if (circulatingQuestionIds.isEmpty) {
      // QuizzerLogger.logMessage('CirculationWorker: No questions currently circulating.');
      return ratio; // Return empty ratio
    }

    // QuizzerLogger.logMessage('CirculationWorker: Calculating ratio for ${circulatingQuestionIds.length} circulating questions...');
    
    Database? db;
    db = await _getDbAccess();
    if (db == null) {
      // Enforce Fail Fast if DB cannot be acquired
      throw StateError('CirculationWorker: Failed to acquire DB lock to calculate ratio after retries.');
    }

    // Loop will proceed. If getQuestionAnswerPairById fails, it will throw (Fail Fast).
    for (var questionId in circulatingQuestionIds) {
      final questionDetails = await q_pairs_table.getQuestionAnswerPairById(questionId, db);
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
    
    // Release DB lock ONLY AFTER the loop completes successfully.
    _dbMonitor.releaseDatabaseAccess(); 

    // QuizzerLogger.logValue('CirculationWorker: Calculated Current Ratio: $ratio');
    return ratio;
  }

  /// Selects the best question to add based on interest, ratio, and availability.
  /// Replaces placeholder with logic from question_queue_maintainer.
  Map<String, dynamic> _selectPrioritizedQuestion(
    Map<String, int> interestData,
    Map<String, int> currentRatio,
    List<Map<String, dynamic>> nonCirculatingRecords
  ) {
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
  }

  /// Updates the DB status and moves the record from NonCirculating to Unprocessed cache.
  Future<void> _addQuestionToCirculation(String userId, Map<String, dynamic> recordToAdd) async {
     QuizzerLogger.logMessage('Entering CirculationWorker _addQuestionToCirculation()...');
     final questionId = recordToAdd['question_id'] as String;
     Database? db;
     
     // Remove from NonCirculating Cache first
     final removedRecord = await _nonCirculatingCache.getAndRemoveRecordByQuestionId(questionId);
     if (removedRecord.isEmpty) {
       QuizzerLogger.logWarning('CirculationWorker: Selected record $questionId not found in NonCirculatingCache during add.');
       return;
     }
     Map<String, dynamic> mutableRecord = Map<String, dynamic>.from(removedRecord);
     mutableRecord['in_circulation'] = 1;
     
     // REMOVED try-finally
     db = await _getDbAccess();
     if (db == null) {
          QuizzerLogger.logError('CirculationWorker: Failed to get DB lock to set QID $questionId in circulation.');
          await _unprocessedCache.addRecord(removedRecord);
          return;
     }

     // Set 'inCirculation' to true in the database
     await uq_pairs_table.setCirculationStatus(userId, questionId, true, db);
     
     // Release DB lock AFTER successful write
     _dbMonitor.releaseDatabaseAccess();

     // Add the record (already modified by caller) back to the UnprocessedCache
     await _unprocessedCache.addRecord(mutableRecord); 
  }

   // Helper to get DB access (copied from EligibilityCheckWorker, could be utility)
   Future<Database?> _getDbAccess() async {
      QuizzerLogger.logMessage('Entering CirculationWorker _getDbAccess()...');
      Database? db;
      int retries       = 0;
      const maxRetries  = 5;
      // Cannot use _isRunning here if this worker isn't looping
      // Assume if called, it should try to get DB
      while (db == null && retries < maxRetries) {
        db = await _dbMonitor.requestDatabaseAccess();
        if (db == null) {
          await Future.delayed(const Duration(milliseconds: 100));
          retries++;
        }
      }
      if (db == null) {
         QuizzerLogger.logError('CirculationWorker: Failed to acquire DB access after $maxRetries retries.');
      }
      return db;
   }
}
