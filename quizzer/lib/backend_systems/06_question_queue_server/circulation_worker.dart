import 'dart:async';
import 'dart:math';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_module_activation_status_table.dart';
// Caches
// Table Access
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/user_question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
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
  static const int    _circulationThreshold = 25;
  static const int    _removalThresholdMultiplier = 2; // DO NOT PROVIDE A VALUE <= 1

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
        
        final List<Map<String, dynamic>> eligibleQuestions = await getActiveQuestionsInCirculation(userId);
        
        eligibleQuestions.sort((a, b) {
          final double aProb = (a['accuracy_probability'] as double?) ?? 0.0;
          final double bProb = (b['accuracy_probability'] as double?) ?? 0.0;
          return aProb.compareTo(bProb);
        });
        
        final List<String> questionsToRemove = eligibleQuestions
            .take(excessCount)
            .map((q) => q['question_id'] as String)
            .toList();
        
        for (final questionId in questionsToRemove) {
          await _removeQuestionFromCirculation(userId, questionId);
        }
        
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
  /// Only counts questions that meet eligibility criteria: not flagged, accuracy_probability < 0.90, in active modules.
  Future<Map<String, dynamic>> _shouldAddNewQuestion() async {
    QuizzerLogger.logMessage('Entering CirculationWorker _shouldAddNewQuestion()...');
    
    final userId = _sessionManager.userId!;
    
    final bool hasNonCirculatingQuestions = nonCirculatingConnected.isNotEmpty || nonCirculatingNotConnected.isNotEmpty;
    
    if (!hasNonCirculatingQuestions) {
      QuizzerLogger.logMessage("No non-circulating questions available, shouldAdd -> false");
      return {"shouldAdd": false, "count": null};
    }
    
    // Get active module names
    final List<String> activeModuleNames = await getActiveModuleNames(userId);
    
    // Query to count eligible circulating questions
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) throw Exception('Failed to acquire database access');
    
    List<dynamic> whereArgs = [userId];
    String sql;
    
    if (activeModuleNames.isNotEmpty) {
      final placeholders = List.filled(activeModuleNames.length, '?').join(',');
      whereArgs.addAll(activeModuleNames);
      sql = '''
        SELECT COUNT(*) as count
        FROM user_question_answer_pairs
        INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
        WHERE user_question_answer_pairs.user_uuid = ?
          AND user_question_answer_pairs.in_circulation = 1
          AND user_question_answer_pairs.flagged = 0
          AND user_question_answer_pairs.accuracy_probability < 0.90
          AND question_answer_pairs.module_name IN ($placeholders)
        LIMIT 101
      ''';
    } else {
      sql = '''
        SELECT COUNT(*) as count
        FROM user_question_answer_pairs
        INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
        WHERE user_question_answer_pairs.user_uuid = ?
          AND user_question_answer_pairs.in_circulation = 1
          AND user_question_answer_pairs.flagged = 0
          AND user_question_answer_pairs.accuracy_probability < 0.90
        LIMIT 101
      ''';
    }
    
    final result = await db.rawQuery(sql, whereArgs);
    getDatabaseMonitor().releaseDatabaseAccess();
    
    final int count = result.first['count'] as int;
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
    
    final List<String> activeModuleNames = await getActiveModuleNames(userId);
    
    if (nonCirculatingConnected.isNotEmpty) {
      final List<String> connectedList = nonCirculatingConnected.toList();
      
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db == null) throw Exception('Failed to acquire database access');
      
      final placeholders = List.filled(connectedList.length, '?').join(',');
      List<dynamic> whereArgs = [userId, ...connectedList];
      String sql = '''
        SELECT user_question_answer_pairs.question_id, user_question_answer_pairs.accuracy_probability
        FROM user_question_answer_pairs
        INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
        WHERE user_question_answer_pairs.user_uuid = ?
          AND user_question_answer_pairs.question_id IN ($placeholders)
          AND user_question_answer_pairs.flagged = 0
      ''';
      
      if (activeModuleNames.isNotEmpty) {
        final modulePlaceholders = List.filled(activeModuleNames.length, '?').join(',');
        sql += ' AND question_answer_pairs.module_name IN ($modulePlaceholders)';
        whereArgs.addAll(activeModuleNames);
      }
      
      final queryResults = await db.rawQuery(sql, whereArgs);
      getDatabaseMonitor().releaseDatabaseAccess();
      
      // Convert to mutable list before sorting
      final List<Map<String, dynamic>> results = List.from(queryResults);
      
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
    
    if (questionIdsToAdd.length < numQuestionsToAdd && nonCirculatingNotConnected.isNotEmpty) {
      final int remainingNeeded = numQuestionsToAdd - questionIdsToAdd.length;
      final List<String> notConnectedList = nonCirculatingNotConnected.toList();
      
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db == null) throw Exception('Failed to acquire database access');
      
      final placeholders = List.filled(notConnectedList.length, '?').join(',');
      List<dynamic> whereArgs = [userId, ...notConnectedList];
      String sql = '''
        SELECT user_question_answer_pairs.question_id, user_question_answer_pairs.accuracy_probability
        FROM user_question_answer_pairs
        INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
        WHERE user_question_answer_pairs.user_uuid = ?
          AND user_question_answer_pairs.question_id IN ($placeholders)
          AND user_question_answer_pairs.flagged = 0
      ''';
      
      if (activeModuleNames.isNotEmpty) {
        final modulePlaceholders = List.filled(activeModuleNames.length, '?').join(',');
        sql += ' AND question_answer_pairs.module_name IN ($modulePlaceholders)';
        whereArgs.addAll(activeModuleNames);
      }
      
      final queryResults = await db.rawQuery(sql, whereArgs);
      getDatabaseMonitor().releaseDatabaseAccess();
      
      // Convert to mutable list before sorting
      final List<Map<String, dynamic>> results = List.from(queryResults);
      
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
    
    if (questionIdsToAdd.isNotEmpty) {
      for (final questionId in questionIdsToAdd) {
        await _addQuestionToCirculation(userId, questionId);
      }
      
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
  Future<void> _addQuestionToCirculation(String userId, String questionId) async {
    QuizzerLogger.logMessage('Adding question to circulation: $questionId');
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) throw Exception('Failed to acquire database access');
    
    await db.rawUpdate(
      'UPDATE user_question_answer_pairs SET in_circulation = 1 WHERE user_uuid = ? AND question_id = ?',
      [userId, questionId],
    );
    getDatabaseMonitor().releaseDatabaseAccess();
    
    // Create new sets instead of modifying existing ones
    nonCirculatingConnected = Set.from(nonCirculatingConnected)..remove(questionId);
    nonCirculatingNotConnected = Set.from(nonCirculatingNotConnected)..remove(questionId);
    circulatingQuestions = Set.from(circulatingQuestions)..add(questionId);
    
    if (mainGraph.containsKey(questionId)) {
      for (final neighbor in mainGraph[questionId]!.toList()) {
        mainGraph[neighbor]!.add(questionId);
      }
    }
    
    if (mainGraph.containsKey(questionId)) {
      for (final neighbor in mainGraph[questionId]!) {
        if (nonCirculatingNotConnected.contains(neighbor)) {
          nonCirculatingNotConnected = Set.from(nonCirculatingNotConnected)..remove(neighbor);
          nonCirculatingConnected = Set.from(nonCirculatingConnected)..add(neighbor);
        }
      }
    }
    
    QuizzerLogger.logSuccess('Question added to circulation: $questionId');
  }

  /// Removes a single question from circulation and updates all cached data structures.
  /// 
  /// Process:
  /// 1. Update database to set in_circulation = 0
  /// 2. Remove from circulatingQuestions
  /// 3. Convert bidirectional edges to unidirectional in mainGraph
  /// 4. Determine if question should go to nonCirculatingConnected or nonCirculatingNotConnected
  /// 5. Update neighbors: check if any should move from connected to not connected
  Future<void> _removeQuestionFromCirculation(String userId, String questionId) async {
    // QuizzerLogger.logMessage('Removing question from circulation: $questionId');
    
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) throw Exception('Failed to acquire database access');
    
    await db.rawUpdate(
      'UPDATE user_question_answer_pairs SET in_circulation = 0 WHERE user_uuid = ? AND question_id = ?',
      [userId, questionId],
    );
    getDatabaseMonitor().releaseDatabaseAccess();
    
    circulatingQuestions = Set.from(circulatingQuestions)..remove(questionId);
    
    if (mainGraph.containsKey(questionId)) {
      for (final neighbor in mainGraph[questionId]!.toList()) {
        mainGraph[neighbor]!.remove(questionId);
      }
    }
    
    bool hasCirculatingLink = false;
    if (mainGraph.containsKey(questionId)) {
      for (final neighbor in mainGraph[questionId]!) {
        if (circulatingQuestions.contains(neighbor)) {
          hasCirculatingLink = true;
          break;
        }
      }
    }
    
    if (hasCirculatingLink) {
      nonCirculatingConnected = Set.from(nonCirculatingConnected)..add(questionId);
    } else {
      nonCirculatingNotConnected = Set.from(nonCirculatingNotConnected)..add(questionId);
    }
    
    if (mainGraph.containsKey(questionId)) {
      for (final neighbor in mainGraph[questionId]!) {
        if (nonCirculatingConnected.contains(neighbor)) {
          bool neighborHasCirculatingLink = false;
          if (mainGraph.containsKey(neighbor)) {
            for (final neighborOfNeighbor in mainGraph[neighbor]!) {
              if (circulatingQuestions.contains(neighborOfNeighbor)) {
                neighborHasCirculatingLink = true;
                break;
              }
            }
          }
          
          if (!neighborHasCirculatingLink) {
            nonCirculatingConnected = Set.from(nonCirculatingConnected)..remove(neighbor);
            nonCirculatingNotConnected = Set.from(nonCirculatingNotConnected)..add(neighbor);
          }
        }
      }
    }
    
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
      
      final userId = _sessionManager.userId!;
      
      // Clear all data structures before rebuilding
      mainGraph.clear();
      circulatingQuestions.clear();
      nonCirculatingNotConnected.clear();
      nonCirculatingConnected.clear();
      
      // Request database access for first query
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db == null) throw Exception('Failed to acquire database access');
      
      // Query all circulating questions with their k_nearest_neighbors
      const circulatingQuery = '''
        SELECT 
          user_question_answer_pairs.question_id,
          question_answer_pairs.k_nearest_neighbors
        FROM user_question_answer_pairs
        INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
        WHERE user_question_answer_pairs.user_uuid = ?
          AND user_question_answer_pairs.in_circulation = 1
      ''';
      
      final circulatingResults = await queryAndDecodeDatabase(
        'user_question_answer_pairs',
        db,
        customQuery: circulatingQuery,
        whereArgs: [userId],
      );
      
      // Release database access immediately after query completes
      getDatabaseMonitor().releaseDatabaseAccess();
      
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
      
      // Request database access for second query
      final db2 = await getDatabaseMonitor().requestDatabaseAccess();
      if (db2 == null) throw Exception('Failed to acquire database access');
      
      // Query all non-circulating questions with their k_nearest_neighbors
      const nonCirculatingQuery = '''
        SELECT 
          user_question_answer_pairs.question_id,
          question_answer_pairs.k_nearest_neighbors
        FROM user_question_answer_pairs
        INNER JOIN question_answer_pairs ON user_question_answer_pairs.question_id = question_answer_pairs.question_id
        WHERE user_question_answer_pairs.user_uuid = ?
          AND user_question_answer_pairs.in_circulation = 0
      ''';
      
      final nonCirculatingResults = await queryAndDecodeDatabase(
        'user_question_answer_pairs',
        db2,
        customQuery: nonCirculatingQuery,
        whereArgs: [userId],
      );
      
      // Release database access immediately after query completes
      getDatabaseMonitor().releaseDatabaseAccess();
      
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
}