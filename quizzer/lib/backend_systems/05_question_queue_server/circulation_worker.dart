import 'dart:async';
import 'dart:math';
import 'package:quizzer/backend_systems/05_question_queue_server/user_question_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
// Caches
// Table Access
import 'package:quizzer/backend_systems/00_database_manager/tables/ml_models_table.dart';
// Workers
import 'package:quizzer/backend_systems/09_switch_board/switch_board.dart'; // Import SwitchBoard
import 'package:quizzer/backend_systems/09_switch_board/sb_question_worker_signals.dart'; // Import worker signals
import 'package:quizzer/backend_systems/09_switch_board/sb_other_signals.dart'; // Import other signals

// ==========================================
// Circulation Worker
// ==========================================
/// Determines when and which questions should be moved into active circulation.
class CirculationWorker {
  // FIXME With the removal of the module_name with it the mechanism by which new relationship user question records would be created. CirculationWorker is now responsible for deciding what new questions to introduce to the user. CirculationWorker will need to ensure that all questionId's in the question_answer_pair table have an accompanying user_question_answer_pair record by which the user is given relationship record with the main question.
  // FIXME Since this was established through the module system, removing the module system removes the mechanism by which user quesiton answer pairs are created
  // --- Singleton Setup ---
  static final CirculationWorker _instance = CirculationWorker._internal();
  factory CirculationWorker() => _instance;
  CirculationWorker._internal();

  // --- Worker State ---
  bool                _isRunning = false;
  StreamSubscription? _questionAnsweredSubscription; // Subscription to question answered correctly signal
  // --------------------

  final SessionManager                _sessionManager       = SessionManager();
  final SwitchBoard                   _switchBoard          = SwitchBoard();
  late double idealThreshold;
  static const int    _circulationThreshold = 25;
  static const int    _removalThresholdMultiplier = 2; // DO NOT PROVIDE A VALUE <= 1

  // FIXME Update the mainGraph to include ALL questions regardless of if a user record exists
  // Update initializeDataStructures to include ALL
  // Then when navigating, if the question to be added to circulation does not exist as a user record yet, then create that user record.

  // Data Structures will be filled on init, then updated live in O(2n + 3) time
  // Hashmap table of all links:
  Map<String, Set<String>> mainGraph     = {};
  // {"questionId": ["relatedQuestionID", "relatedQuestionId"]}

  // The following three sets are mutually exclusive:
  Set<String> circulatingQuestions       = {};
  // {"questionId", "questionId"}

  Set<String> nonCirculatingNotConnected = {};
  // {"questionId", "questionId"}

  Set<String> nonCirculatingConnected    = {};
  // {"questionId", "questionId"}

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

      // Initialize data structures before starting main loop
      await _initializeDataStructures();
      idealThreshold = await getAccuracyNetOptimalThreshold();

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
      QuizzerLogger.logMessage('Circulation Worker Stopped');
    } catch (e) {
      QuizzerLogger.logError('Error stopping CirculationWorker - $e');
      rethrow;
    }
  }
  // ----------------------
  /// Main worker loop
  Future<void> _runLoop() async {
    QuizzerLogger.logMessage('Entering CirculationWorker _runLoop()...');
    while (_isRunning) {
      if (!_isRunning) break;
      
      assert(_sessionManager.userId != null, 'Circulation check requires logged-in user.');
      final userId = _sessionManager.userId!;

      final Map<String, dynamic> shouldAdd = await _shouldAddNewQuestion();
      final int currentCount = shouldAdd["count"] as int? ?? 0;

      if (currentCount > _circulationThreshold * _removalThresholdMultiplier) {
        final int excessCount = currentCount - _circulationThreshold;
        QuizzerLogger.logMessage('Count ($currentCount) exceeds threshold * $_removalThresholdMultiplier, removing $excessCount questions');
        
        final List<Map<String, dynamic>> eligibleQuestions = await UserQuestionManager().getActiveQuestionsInCirculation();
        
        eligibleQuestions.sort((a, b) {
          final double aProb = (a['accuracy_probability'] as double?) ?? 0.0;
          final double bProb = (b['accuracy_probability'] as double?) ?? 0.0;
          return aProb.compareTo(bProb);
        });
        
        final List<String> questionsToRemove = eligibleQuestions
            .take(excessCount)
            .map((q) => q['question_id'] as String)
            .toList();
        await _removeQuestionFromCirculation(questionsToRemove);
        if (!_isRunning) break;
      }

      if (shouldAdd["shouldAdd"]) {
        final int questionsToAdd = _circulationThreshold - currentCount;
        QuizzerLogger.logMessage("Need to add $questionsToAdd questions to reach threshold");
        
        await _batchAddQuestionsToCirculation(userId, questionsToAdd);
        
        if (!_isRunning) break;
      } else {
        if (!_isRunning) break;
        QuizzerLogger.logMessage('CirculationWorker: Conditions not met, waiting for question answered correctly signal...');

        signalCirculationWorkerFinished();
        await _switchBoard.onQuestionAnsweredCorrectly.first;
        QuizzerLogger.logMessage('CirculationWorker: Woke up by question answered correctly signal.');
      }
    }
    QuizzerLogger.logMessage('CirculationWorker loop finished.');
  }
  // -----------------

  /// Checks if conditions are met to add a new question to circulation.
  /// Uses cached data structures instead of database queries.
  /// Only counts questions that meet eligibility criteria: not flagged, accuracy_probability < idealThreshold, in active modules.
  Future<Map<String, dynamic>> _shouldAddNewQuestion() async {
    QuizzerLogger.logMessage('Entering CirculationWorker _shouldAddNewQuestion()...');
    // Check if there are questions left to place into circulation
    final bool hasNonCirculatingQuestions = nonCirculatingConnected.isNotEmpty || nonCirculatingNotConnected.isNotEmpty;
    if (!hasNonCirculatingQuestions) {
      QuizzerLogger.logMessage("No non-circulating questions available, shouldAdd -> false");
      return {"shouldAdd": false, "count": null};
    }
    // If there are check our threshold
    final int count = await UserQuestionManager().getCountOfLowProbabilityCirculatingQuestions(idealThreshold);
    final bool shouldAdd = count < _circulationThreshold;
    QuizzerLogger.logMessage("shouldAdd To Circulation-> $shouldAdd (count: $count)/(total: ${circulatingQuestions.length})");
    return {"shouldAdd": shouldAdd, "count": count};
  }

  /// Prioritizes questions from nonCirculatingConnected (selecting highest accuracy_probability),
  /// falls back to nonCirculatingNotConnected (selecting highest accuracy_probability).
  /// Only selects eligible questions: not flagged, in active modules.
  Future<void> _batchAddQuestionsToCirculation(String userId, int numQuestionsToAdd) async {
    QuizzerLogger.logMessage('Entering CirculationWorker _batchAddQuestionsToCirculation() - adding $numQuestionsToAdd questions...');
    
    final List<String> questionIdsToAdd = [];
    
    // Case 1, there are non-circulating questions connected to circulating ones
    if (nonCirculatingConnected.isNotEmpty) {
      // Get the user question records for the connected but non-circulating questions
      final List<Map<String, dynamic>> results = await UserQuestionManager().getAccuracyProbabilityOfQuestions(questionIds: nonCirculatingConnected);
      
      results.sort((a, b) {
        final double aProb = (a['accuracy_probability'] as double?) ?? 0.0;
        final double bProb = (b['accuracy_probability'] as double?) ?? 0.0;
        return bProb.compareTo(aProb);
      });
      
      final int connectedToTake = min(numQuestionsToAdd, results.length);
      questionIdsToAdd.addAll(
        results.take(connectedToTake).map((q) => q['question_id'] as String)
      );
      QuizzerLogger.logMessage('Selected ${questionIdsToAdd.length} connected questions with highest accuracy probability');
    }
    
    // If after queing questions to be added, there are still insufficient questions, select questions to add to circulation that are not directly connected
    // to the user's knowledge base
    if (questionIdsToAdd.length < numQuestionsToAdd && nonCirculatingNotConnected.isNotEmpty) {
      final int remainingNeeded = numQuestionsToAdd - questionIdsToAdd.length;
      final List<Map<String, dynamic>> results = await UserQuestionManager().getAccuracyProbabilityOfQuestions(questionIds: nonCirculatingNotConnected);
      results.sort((a, b) {
        final double aProb = (a['accuracy_probability'] as double?) ?? 0.0;
        final double bProb = (b['accuracy_probability'] as double?) ?? 0.0;
        return bProb.compareTo(aProb);
      });
      final int notConnectedToTake = min(remainingNeeded, results.length);
      questionIdsToAdd.addAll(
        results.take(notConnectedToTake).map((q) => q['question_id'] as String)
      );
      QuizzerLogger.logMessage('Added $notConnectedToTake not connected questions with highest accuracy probability');
    }
    
    // After selecting the questions that should be added, iterate over the selections and call to have them added to circulation
    if (questionIdsToAdd.isNotEmpty) {
      await _addQuestionsToCirculation(questionIdsToAdd);
      signalCirculationWorkerQuestionAdded();
      QuizzerLogger.logSuccess('Batch added ${questionIdsToAdd.length} questions to circulation');
    } else {
      QuizzerLogger.logWarning('No questions were selected for batch add');
    }
  }

  /// Adds a single question to circulation and updates all cached data structures.
  /// 
  /// Process:
  /// 1. Update database to set in_circulation = 1
  /// 2. Remove from nonCirculating sets and add to circulatingQuestions
  /// 3. Convert unidirectional edges to bidirectional in mainGraph
  /// 4. Update neighbors: move any from nonCirculatingNotConnected to nonCirculatingConnected
  Future<void> _addQuestionsToCirculation(List<String> questionIds) async {
    QuizzerLogger.logMessage('Adding questions to circulation: $questionIds');
    await UserQuestionManager().setQuestionsAddToCirculation(questionIds: questionIds);
    
    // Update sets (using Set.from(...) for immutable-style updates)
    nonCirculatingConnected = Set.from(nonCirculatingConnected)..removeAll(questionIds);
    nonCirculatingNotConnected = Set.from(nonCirculatingNotConnected)..removeAll(questionIds);
    circulatingQuestions = Set.from(circulatingQuestions)..addAll(questionIds);
    
    // Store neighbors that need promotion (from NotConnected to Connected)
    final Set<String> newlyConnectedNeighbors = {};
    
    // Convert edges to bidirectional and identify newly connected neighbors
    for (final id in questionIds) {
      for (final neighbor in mainGraph[id]!) {
        // Make edge bidirectional (neighbor -> id)
        if (mainGraph.containsKey(neighbor)) {
          // Use Set.from to respect the immutable style for mainGraph's sets
          mainGraph[neighbor] = Set.from(mainGraph[neighbor]!)..add(id); 
        }
        // Check for neighbors to promote (move from NotConnected to Connected)
        if (nonCirculatingNotConnected.contains(neighbor)) {
          newlyConnectedNeighbors.add(neighbor);
        }
      }
    }

    // Perform the batch move for newly connected neighbors
    nonCirculatingNotConnected = Set.from(nonCirculatingNotConnected)..removeAll(newlyConnectedNeighbors);
    nonCirculatingConnected = Set.from(nonCirculatingConnected)..addAll(newlyConnectedNeighbors);
    
    QuizzerLogger.logSuccess('Successfully added ${questionIds.length} question(s) to circulation.');
  }

  /// Removes a single question from circulation and updates all cached data structures.
  /// 
  /// Process:
  /// 1. Update database to set in_circulation = 0
  /// 2. Remove from circulatingQuestions
  /// 3. Convert bidirectional edges to unidirectional in mainGraph
  /// 4. Determine if question should go to nonCirculatingConnected or nonCirculatingNotConnected
  /// 5. Update neighbors: check if any should move from connected to not connected
  Future<void> _removeQuestionFromCirculation(List<String> questionIds) async {
    QuizzerLogger.logMessage('Removing questions from circulation: $questionIds');
    await UserQuestionManager().setQuestionsRemoveFromCirculation(questionIds: questionIds);
    // Update local circulation set
    circulatingQuestions = Set.from(circulatingQuestions)..removeAll(questionIds);
    
    // Collect neighbors whose connection status might change
    final Set<String> affectedNeighbors = {};
    final Set<String> newlyNotConnected = {};
    final Set<String> newlyConnected = {};
    final Set<String> neighborsToDemote = {};

    // Update mainGraph: remove reverse links from all neighbors
    for (final id in questionIds) {
      for (final neighbor in mainGraph[id]!.toList()) {
        if (mainGraph.containsKey(neighbor)) {
          mainGraph[neighbor]!.remove(id); 
          affectedNeighbors.add(neighbor);
        }
      }
    }


    // Determine the new non-circulating pool status (Connected or NotConnected) for the removed questions
    for (final id in questionIds) {
      bool hasCirculatingLink = false;
      for (final neighbor in mainGraph[id]!) {
        if (circulatingQuestions.contains(neighbor)) {
          hasCirculatingLink = true;
          break;
        }
      }
      if (hasCirculatingLink) {newlyConnected.add(id);} 
      else {newlyNotConnected.add(id);}
    }
    
    // Batch update non-circulating sets
    nonCirculatingConnected = Set.from(nonCirculatingConnected)..addAll(newlyConnected);
    nonCirculatingNotConnected = Set.from(nonCirculatingNotConnected)..addAll(newlyNotConnected);
    
    // Check neighbors for demotion (moving from Connected to NotConnected)
    for (final neighbor in affectedNeighbors) {
      if (nonCirculatingConnected.contains(neighbor)) {
        bool neighborHasCirculatingLink = false;
        
        if (mainGraph.containsKey(neighbor)) {
          for (final neighborOfNeighbor in mainGraph[neighbor]!) {
            // Check if the neighbor is still linked to any question currently in circulation
            if (circulatingQuestions.contains(neighborOfNeighbor)) {
              neighborHasCirculatingLink = true;
              break;
            }
          }
        }
        if (!neighborHasCirculatingLink) {neighborsToDemote.add(neighbor);}
      }
    }
    
    // Perform the batch demotion
    nonCirculatingConnected = Set.from(nonCirculatingConnected)..removeAll(neighborsToDemote);
    nonCirculatingNotConnected = Set.from(nonCirculatingNotConnected)..addAll(neighborsToDemote);
    
    // QuizzerLogger.logSuccess('Question removed from circulation: $questionId');
  }

  /// Builds the initial data structures that the circulation worker will update.
  /// These structures are the cached data to improve the speed of the application.
  /// 
  /// Data structures built:
  /// - mainGraph: Bidirectional adjacency map of all question relationships
  /// - circulatingQuestions: Set of questions currently in circulation
  /// - nonCirculatingConnected: Non-circulating questions linked to circulating ones
  /// - nonCirculatingNotConnected: Non-circulating questions with no links to circulation
  /// 
  /// Process:
  /// 1. Query all circulating questions and build bidirectional graph edges
  /// 2. Query all non-circulating questions and add their edges
  /// 3. Classify non-circulating questions based on connectivity to circulation
  Future<void> _initializeDataStructures() async {
    try {
      QuizzerLogger.logMessage('Entering CirculationWorker _initializeDataStructures()...');

      // Clear all data structures before rebuilding
      mainGraph.clear();
      circulatingQuestions.clear();
      nonCirculatingNotConnected.clear();
      nonCirculatingConnected.clear();
      
      // FIXME We will need to change this to query all questions in the question_answer_pair table rather than what currently exists in the user question answer pair records (include all questions)
      final circulatingResults = await UserQuestionManager().getCirculatingQuestionsWithNeighbors();
      final nonCirculatingResults = await UserQuestionManager().getNonCirculatingQuestionsWithNeighbors();
      // The query will be for all circulating questions, then a second query for all questions that are not circulating (from the question answer pair table not the user question answer pair table)


      // Process circulating questions
      for (final row in circulatingResults) {
        final iQuestionId = row['question_id'] as String;
        final knnMap = row['k_nearest_neighbors'] as Map<String, dynamic>?;
        
        // Skip questions with no k_nearest_neighbors
        if (knnMap == null) continue;
        
        // Add question to mainGraph if not present
        mainGraph.putIfAbsent(iQuestionId, () => {});
        
        // For each neighbor, create bidirectional edges in mainGraph
        for (final jQuestionId in knnMap.keys) {
          // Add neighbor to mainGraph if not present
          mainGraph.putIfAbsent(jQuestionId, () => {});
          
          // Add bidirectional edge: j -> i
          mainGraph[jQuestionId]!.add(iQuestionId);
          
          // Add bidirectional edge: i -> j
          mainGraph[iQuestionId]!.add(jQuestionId);
        }
        
        // Add to circulating questions set
        circulatingQuestions.add(iQuestionId);
      }
      
      // Process non-circulating questions
      for (final row in nonCirculatingResults) {
        final iQuestionId = row['question_id'] as String;
        final knnMap = row['k_nearest_neighbors'] as Map<String, dynamic>?;
        
        // Skip questions with no k_nearest_neighbors
        if (knnMap == null) continue;
        
        // Add question to mainGraph if not present
        mainGraph.putIfAbsent(iQuestionId, () => {});
        
        // For each neighbor, create unidirectional edges (only j -> i, not i -> j)
        for (final jQuestionId in knnMap.keys) {
          // Add neighbor to mainGraph if not present
          mainGraph.putIfAbsent(jQuestionId, () => {});
          
          // Add unidirectional edge: j -> i
          mainGraph[jQuestionId]!.add(iQuestionId);
        }
        
        // Check if this non-circulating question is connected to any circulating question
        bool nonCirculatingNotLinked = true;
        for (final k in mainGraph[iQuestionId]!) {
          if (circulatingQuestions.contains(k)) {
            // Found a link to a circulating question
            nonCirculatingNotLinked = false;
            nonCirculatingConnected.add(iQuestionId);
            break;
          }
        }
        
        // If no links to circulating questions, add to not connected set
        if (nonCirculatingNotLinked) {
          nonCirculatingNotConnected.add(iQuestionId);
        }
      }
      
      QuizzerLogger.logSuccess('Data structures initialized: ${mainGraph.length} nodes, ${circulatingQuestions.length} circulating, ${nonCirculatingConnected.length} connected, ${nonCirculatingNotConnected.length} not connected');
    } catch (e) {
      QuizzerLogger.logError('Error in CirculationWorker _initializeDataStructures - $e');
      rethrow;
    }
  }

  /// Mechanism to create a new user_question_answer_pair record and add it to the mainGraph
  /// This allows us to create new records during operation after the map dataStructure was initialized
  Future<void> _addNewUserQuestionToProfile(List<String> questionIds) async {

  }

}