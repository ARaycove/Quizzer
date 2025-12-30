import 'dart:math';
import 'dart:convert'; 
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_attempts_table.dart';
import 'package:quizzer/backend_systems/05_question_queue_server/user_questions/user_question_manager.dart';
import 'package:quizzer/backend_systems/06_question_answer_pair_management/question_answer_pair_manager.dart';

/// embedded within the UserQuestionManager
/// encapsulates all functionality related to updating a user question record after 
/// each time it is answered
class UserAnswerSubmitter {
  static final UserAnswerSubmitter _instance = UserAnswerSubmitter._internal();
  factory UserAnswerSubmitter() => _instance;
  UserAnswerSubmitter._internal();
  // ==================================================
  // ----- Submission Functionality -----
  // ==================================================
  /// Updates the user-specific question record based on the answer correctness.
  /// All updates happen in a single atomic operation.
  Future<void> updateUserQuestionRecordOnAnswer({
    required bool isCorrect,
    required String questionId,
    required double reactionTime,
  }) async {
    try {
      // QuizzerLogger.logMessage('Entering updateUserQuestionRecordOnAnswer()...');
      
      // --- 1. Get current user record from database ---
      final Map<String, dynamic> currentUserRecord = await UserQuestionManager().getUserQuestionAnswerPairById(questionId);
      
      // --- 2. Extract necessary current values ---
      final int currentRevisionStreak = currentUserRecord['revision_streak'] as int;
      final int currentTotalAttempts = currentUserRecord['total_attempts'] as int;
      final double currentAvgReactionTime = (currentUserRecord['avg_reaction_time'] as double?) ?? 0.0;
      final DateTime now = DateTime.now();
          
      // --- 3. Calculate Updates ---
      // Calculate correct/incorrect attempt counters
      final int currentTotalCorrectAttempts = (currentUserRecord['total_correct_attempts'] as int?) ?? 0;
      final int currentTotalIncorrectAttempts = (currentUserRecord['total_incorect_attempts'] as int?) ?? 0;
      
      final int newTotalCorrectAttempts = isCorrect ? currentTotalCorrectAttempts + 1 : currentTotalCorrectAttempts;
      final int newTotalIncorrectAttempts = !isCorrect ? currentTotalIncorrectAttempts + 1 : currentTotalIncorrectAttempts;
      
      // Calculate new total attempts as sum of correct and incorrect attempts
      final int newTotalAttempts = newTotalCorrectAttempts + newTotalIncorrectAttempts;
      
      // Calculate new avg_reaction_time using the derived total attempts:
      final double newAvgReactionTime = ((currentAvgReactionTime * currentTotalAttempts) + reactionTime) / newTotalAttempts;
      
      // Calculate accuracy rates
      final double newQuestionAccuracyRate = newTotalCorrectAttempts / newTotalAttempts;
      final double newQuestionInaccuracyRate = newTotalIncorrectAttempts / newTotalAttempts;
      
      final int streakAdjustment = _calculateStreakAdjustment(isCorrect: isCorrect);
      
      // Calculate new streak (ensure >= 0)
      final int newRevisionStreak = max(0, currentRevisionStreak + streakAdjustment);
      
      // Calculate last_revised
      final String newLastRevised = now.toIso8601String();
      
      // Calculate day_time_introduced if it doesn't exist
      final String? dayTimeIntroduced = currentUserRecord['day_time_introduced'] as String?;
      final String finalDayTimeIntroduced = dayTimeIntroduced ?? DateTime.now().toUtc().toIso8601String();
      
      QuizzerLogger.logMessage('Final for updated question values - streak: $newRevisionStreak, avgReactionTime: $newAvgReactionTime, correctAttempts: $newTotalCorrectAttempts, incorrectAttempts: $newTotalIncorrectAttempts, accuracyRate: $newQuestionAccuracyRate');
      
      Map<String, dynamic> updateData = {
          'revision_streak': newRevisionStreak,
          'last_revised': newLastRevised,
          'avg_reaction_time': newAvgReactionTime,
          'day_time_introduced': finalDayTimeIntroduced,
          'total_correct_attempts': newTotalCorrectAttempts,
          'total_incorect_attempts': newTotalIncorrectAttempts,
          'question_accuracy_rate': newQuestionAccuracyRate,
          'question_inaccuracy_rate': newQuestionInaccuracyRate,
          'last_prob_calc': DateTime.utc(1970, 1, 1).toIso8601String() // Immediately trigger this question to be re-evaluated by the accuracy net
        };

      // --- 5. Update Database in Single Atomic Operation ---
      await UserQuestionManager().editUserQuestionAnswerPair(
        questionId: questionId,
        updates: updateData,
      );
      
      // QuizzerLogger.logMessage('Successfully updated user question record in database');
      
      // --- 6. Update k_nearest_neighbors to trigger re-evaluation ---
      final Map<String, dynamic> questionRecord 
      = await QuestionAnswerPairManager().getQuestionAnswerPairById(questionId);

      final dynamic kNearestNeighborsData = questionRecord['k_nearest_neighbors'];
      
      if (kNearestNeighborsData != null) {
        final Map<String, dynamic> kNearestMap 
        = kNearestNeighborsData as Map<String, dynamic>;

        final List<String> neighborQuestionIds = kNearestMap.keys.toList();
        
        if (neighborQuestionIds.isNotEmpty) {
          // QuizzerLogger.logMessage('Triggering re-evaluation for ${neighborQuestionIds.length} nearest neighbors');
          
          final db = await getDatabaseMonitor().requestDatabaseAccess();
          if (db == null) {
            throw Exception('Failed to acquire database access');
          }
          
          try {
            final String resetDate = DateTime.utc(1970, 1, 1).toIso8601String();
            final String placeholders = List.filled(neighborQuestionIds.length, '?').join(',');
            
            await db.rawUpdate(
              'UPDATE user_question_answer_pairs SET last_prob_calc = ? WHERE user_uuid = ? AND question_id IN ($placeholders)',
              [resetDate, SessionManager().userId, ...neighborQuestionIds],
            );
            
            // QuizzerLogger.logSuccess('Triggered re-evaluation for ${neighborQuestionIds.length} nearest neighbor questions');
          } finally {
            getDatabaseMonitor().releaseDatabaseAccess();
          }
        }
      }
    } catch (e) {
      QuizzerLogger.logError('Error in updateUserQuestionRecordOnAnswer - $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> recordQuestionAnswerAttempt({
    required String userId,
    required String questionId,
    bool? isCorrect,
    bool forInference = false,
  }) async {
    if (!forInference && isCorrect == null) {
      throw ArgumentError('isCorrect is required when forInference is false');
    }
    
    try {
      QuizzerLogger.logMessage('Entering recordQuestionAnswerAttempt()...');
      
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      if (db == null) {
        throw Exception('Failed to acquire database access');
      }
      
      final String timeStamp = DateTime.now().toUtc().toIso8601String();
      
      // ===================================
      // Query 1: Question Metadata
      // ===================================
      final Map<String, dynamic> questionMetadata = await fetchQuestionMetadata(
        db: db,
        questionId: questionId,
      );
      
      final String? questionVector = questionMetadata['question_vector'] as String?;
      final String questionType = questionMetadata['question_type'] as String;
      final int numMcqOptions = questionMetadata['num_mcq_options'] as int;
      final int numSoOptions = questionMetadata['num_so_options'] as int;
      final int numSataOptions = questionMetadata['num_sata_options'] as int;
      final int numBlanks = questionMetadata['num_blanks'] as int;
      final String? kNearestNeighbors = questionMetadata['k_nearest_neighbors'] as String?;
      
      // ===================================
      // Query 2: Individual Question Performance
      // ===================================
      final Map<String, dynamic> userQuestionPerformance = await fetchUserQuestionPerformance(
        db: db,
        userId: userId,
        questionId: questionId,
        timeStamp: timeStamp,
      );
      
      final double avgReactTime = userQuestionPerformance['avg_react_time'] as double;
      final bool wasFirstAttempt = userQuestionPerformance['was_first_attempt'] as bool;
      final int totalCorrectAttempts = userQuestionPerformance['total_correct_attempts'] as int;
      final int totalIncorrectAttempts = userQuestionPerformance['total_incorrect_attempts'] as int;
      final int totalAttempts = userQuestionPerformance['total_attempts'] as int;
      final double accuracyRate = userQuestionPerformance['accuracy_rate'] as double;
      final int revisionStreak = userQuestionPerformance['revision_streak'] as int;
      final String timeOfPresentation = userQuestionPerformance['time_of_presentation'] as String;
      final String? lastRevisedDate = userQuestionPerformance['last_revised_date'] as String?;
      final double daysSinceLastRevision = userQuestionPerformance['days_since_last_revision'] as double;
      final double daysSinceFirstIntroduced = userQuestionPerformance['days_since_first_introduced'] as double;
      final double attemptDayRatio = userQuestionPerformance['attempt_day_ratio'] as double;
      
      
      // ===================================
      // Query 3: User Stats Vector
      // ===================================
      final String? userStatsVector = await fetchUserStatsVector(
        db: db,
        userId: userId,
      );
      
      // ===================================
      // Query 4: User Profile Record
      // ===================================
      final String? userProfileRecord = await fetchUserProfileRecord(
        db: db,
        userId: userId,
      );

      // ===================================
      // Query 5: K Nearest Performance Vector
      // ===================================
      final String? kNearestPerformanceVector = await fetchKNearestPerformanceVector(
        db: db,
        userId: userId,
        kNearestNeighbors: kNearestNeighbors,
        timeStamp: timeStamp,
      );

      // ===================================
      // Prepare Data for Insert/Return
      // ===================================
      final Map<String, dynamic> sampleData = {
        'question_type': questionType,
        'num_mcq_options': numMcqOptions,
        'num_so_options': numSoOptions,
        'num_sata_options': numSataOptions,
        'num_blanks': numBlanks,
        // Individual question performance
        'avg_react_time': avgReactTime,
        'was_first_attempt': wasFirstAttempt ? 1 : 0,
        'total_correct_attempts': totalCorrectAttempts,
        'total_incorrect_attempts': totalIncorrectAttempts,
        'total_attempts': totalAttempts,
        'accuracy_rate': accuracyRate,
        'revision_streak': revisionStreak,
        // Temporal metrics
        'time_of_presentation': timeOfPresentation,
        'last_revised_date': lastRevisedDate,
        'days_since_last_revision': daysSinceLastRevision,
        'days_since_first_introduced': daysSinceFirstIntroduced,
        'attempt_day_ratio': attemptDayRatio,
      };
      
      // Add response_result only if not for inference
      if (!forInference) {
        sampleData['response_result'] = isCorrect! ? 1 : 0;
      }
      
      // Add question_vector if it exists
      if (questionVector != null) {
        sampleData['question_vector'] = questionVector;
      }
      
      // Add k_nearest_neighbors if it exists
      if (kNearestNeighbors != null) {
        sampleData['k_nearest_neighbors'] = kNearestNeighbors;
      }
      
      // Add user_stats_vector if it exists
      if (userStatsVector != null) {
        sampleData['user_stats_vector'] = userStatsVector;
      }
      
      // Add user_profile_record if it exists
      if (userProfileRecord != null) {
        sampleData['user_profile_record'] = userProfileRecord;
      }
      
      // Add k_nearest_performance_vector if it exists
      if (kNearestPerformanceVector != null) {
        sampleData['knn_performance_vector'] = kNearestPerformanceVector;
      }
      
      // Release database access before proceeding
      getDatabaseMonitor().releaseDatabaseAccess();
      
      if (forInference) {
        // Return the sample for inference
        return sampleData;
      } else {
        // Insert the training sample using upsertRecord
        final attemptData = {
          'question_id': questionId,
          'participant_id': userId, 
          'time_stamp': timeStamp,
          ...sampleData, // Spread all the calculated fields
        };
        await QuestionAnswerAttemptsTable().upsertRecord(attemptData);
        
        QuizzerLogger.logMessage('Successfully recorded question answer attempt for QID: $questionId');
        return null;
      }
    } catch (e) {
      QuizzerLogger.logError('Error in recordQuestionAnswerAttempt - $e');
      // Make sure we release the connection even if there's an error
      getDatabaseMonitor().releaseDatabaseAccess();
      rethrow;
    }
  }


  // ==================================================
  // ----- PRIVATE HELPERS-----
  // ==================================================
  /// Calculates the adjustment (+1 or -1) for the revision streak.
  int _calculateStreakAdjustment({required bool isCorrect}) {return isCorrect ? 1 : -1;}

  // ==================================================
  // ----- Collection for Answer Attempt Records -----
  // ==================================================
  // Transaction Functions DO NOT handle db access themselves
  // These functions are used for recording attempts records and for use by ML models to generate samples for live inference.
  /// Gather metadata for collection process
  Future<Map<String, dynamic>> fetchQuestionMetadata({
    required dynamic db,
    required String questionId,
  }) async {
    const query = '''
      SELECT 
        question_vector,
        question_type,
        options,
        question_elements,
        k_nearest_neighbors
      FROM question_answer_pairs
      WHERE question_id = ?
      LIMIT 1
    ''';
    
    final List<Map<String, dynamic>> results = await db.rawQuery(query, [questionId]);
    
    if (results.isEmpty) {
      // Return empty map instead of throwing - let caller handle missing questions
      QuizzerLogger.logWarning('Question not found: $questionId - returning empty metadata');
      return {};
    }
    
    final Map<String, dynamic> questionData = results.first;
    final String? questionVector = questionData['question_vector'] as String?;
    final String questionType = questionData['question_type'] as String;
    final String? kNearestNeighbors = questionData['k_nearest_neighbors'] as String?;
    
    int numMcqOptions = 0;
    int numSoOptions = 0;
    int numSataOptions = 0;
    int numBlanks = 0;
    
    if (questionType == 'multiple_choice' || questionType == 'select_all_that_apply' || questionType == 'sort_order') {
      final String? optionsJson = questionData['options'] as String?;
      if (optionsJson != null) {
        final List<dynamic> options = decodeValueFromDB(optionsJson);
        final int optionCount = options.length;
        
        switch (questionType) {
          case 'multiple_choice':
            numMcqOptions = optionCount;
            break;
          case 'select_all_that_apply':
            numSataOptions = optionCount;
            break;
          case 'sort_order':
            numSoOptions = optionCount;
            break;
        }
      }
    } else if (questionType == 'fill_in_the_blank') {
      final String? questionElementsJson = questionData['question_elements'] as String?;
      if (questionElementsJson != null) {
        final List<dynamic> questionElements = decodeValueFromDB(questionElementsJson);
        numBlanks = questionElements.where((element) => 
          element is Map && element['type'] == 'blank'
        ).length;
      }
    }
    
    return {
      'question_vector': questionVector,
      'question_type': questionType,
      'num_mcq_options': numMcqOptions,
      'num_so_options': numSoOptions,
      'num_sata_options': numSataOptions,
      'num_blanks': numBlanks,
      'k_nearest_neighbors': kNearestNeighbors,
    };
  }

  /// Gather individual performance record
  Future<Map<String, dynamic>>  fetchUserQuestionPerformance({
    required dynamic db,
    required String userId,
    required String questionId,
    required String timeStamp,
  }) async {
    UserQuestionManager().ensureUserQuestionRecordExists(questionId, db: db);

    const query = '''
      SELECT 
        avg_reaction_time,
        total_correct_attempts,
        total_incorect_attempts,
        total_attempts,
        question_accuracy_rate,
        revision_streak,
        last_revised,
        day_time_introduced
      FROM user_question_answer_pairs
      WHERE user_uuid = ? AND question_id = ?
      LIMIT 1
    ''';
    
    final List<Map<String, dynamic>> results = await db.rawQuery(query, [userId, questionId]);
    
    // If no record we return all 0's
    if (results.isEmpty) {
      return {
        'avg_react_time': 0.0,
        'was_first_attempt': 1,
        'total_correct_attempts': 0,
        'total_incorrect_attempts': 0,
        'total_attempts': 0,
        'accuracy_rate': 0.0,
        'revision_streak': 0,
        'time_of_presentation': timeStamp,
        'last_revised_date': null,
        'days_since_last_revision': null,
        'days_since_first_introduced': null,
        'attempt_day_ratio': null,
      };
    }
    
    final Map<String, dynamic> userQuestionData = results.first;
    
    final double avgReactTime = userQuestionData['avg_reaction_time'] as double? ?? 0.0;
    final int totalCorrectAttempts = userQuestionData['total_correct_attempts'] as int? ?? 0;
    final int totalIncorrectAttempts = userQuestionData['total_incorect_attempts'] as int? ?? 0;
    final int totalAttempts = userQuestionData['total_attempts'] as int? ?? 0;
    final double accuracyRate = userQuestionData['question_accuracy_rate'] as double? ?? 0.0;
    final int revisionStreak = userQuestionData['revision_streak'] as int? ?? 0;
    final String? lastRevisedDate = userQuestionData['last_revised'] as String?;
    final String? dayTimeIntroduced = userQuestionData['day_time_introduced'] as String?;
    
    final String timeOfPresentation = timeStamp;
    final bool wasFirstAttempt = totalAttempts == 0;
    
    double daysSinceLastRevision = 0.0;
    if (lastRevisedDate != null) {
      final DateTime lastRevised = DateTime.parse(lastRevisedDate);
      final DateTime now = DateTime.parse(timeStamp);
      daysSinceLastRevision = now.difference(lastRevised).inMicroseconds / Duration.microsecondsPerDay;
    }
    
    double daysSinceFirstIntroduced = 0.0;
    double attemptDayRatio = 0.0;
    if (dayTimeIntroduced != null) {
      final DateTime firstIntroduced = DateTime.parse(dayTimeIntroduced);
      final DateTime now = DateTime.parse(timeStamp);
      daysSinceFirstIntroduced = now.difference(firstIntroduced).inMicroseconds / Duration.microsecondsPerDay;
      
      if (daysSinceFirstIntroduced > 0) {
        attemptDayRatio = totalAttempts / daysSinceFirstIntroduced;
      }
    }
    
    return {
      'avg_react_time': avgReactTime,
      'was_first_attempt': wasFirstAttempt,
      'total_correct_attempts': totalCorrectAttempts,
      'total_incorrect_attempts': totalIncorrectAttempts,
      'total_attempts': totalAttempts,
      'accuracy_rate': accuracyRate,
      'revision_streak': revisionStreak,
      'time_of_presentation': timeOfPresentation,
      'last_revised_date': lastRevisedDate,
      'days_since_last_revision': daysSinceLastRevision,
      'days_since_first_introduced': daysSinceFirstIntroduced,
      'attempt_day_ratio': attemptDayRatio,
    };
  }

  /// Gather KNN performance vector
  /// Generates a JSON-encoded string representing the performance metrics of the k-nearest neighbor questions.
  /// Each entry includes distance and various performance metrics.
  Future<String?> fetchKNearestPerformanceVector({
    required dynamic db,
    required String userId,
    required String? kNearestNeighbors,
    required String timeStamp,
  }) async {
    
    if (kNearestNeighbors == null) {
      return null;
    }
    
    final Map<String, dynamic> kNearestMap = jsonDecode(kNearestNeighbors);
    
    if (kNearestMap.isEmpty) {
      return null;
    }
    
    final List<Map<String, dynamic>> kNearestRecords = [];
    
    for (final entry in kNearestMap.entries) {
      final String neighborQuestionId = entry.key;
      final double distance = entry.value as double;
      
      // 1. FIRST: Fetch metadata to check if question exists
      final Map<String, dynamic> neighborMetadata = await fetchQuestionMetadata(
        db: db,
        questionId: neighborQuestionId,
      );
      
      // Check if metadata is empty (question might not exist or was deleted)
      if (neighborMetadata.isEmpty) {
        QuizzerLogger.logWarning(
          'Skipping neighbor question $neighborQuestionId: question not found or deleted'
        );
        continue; // Skip to the next neighbor
      }
      
      // 2. ONLY IF QUESTION EXISTS: Ensure user question record exists
      await UserQuestionManager().ensureUserQuestionRecordExists(neighborQuestionId, db: db);
      
      // 3. THEN: Fetch performance data
      final Map<String, dynamic> neighborPerformance = await fetchUserQuestionPerformance(
        db: db,
        userId: userId,
        questionId: neighborQuestionId,
        timeStamp: timeStamp,
      );
      
      final Map<String, dynamic> knnRecord = {
        'distance': distance,
        'question_type': neighborMetadata['question_type'],
        'num_mcq_options': neighborMetadata['num_mcq_options'],
        'num_so_options': neighborMetadata['num_so_options'],
        'num_sata_options': neighborMetadata['num_sata_options'],
        'num_blanks': neighborMetadata['num_blanks'],
        'avg_react_time': neighborPerformance['avg_react_time'],
        'was_first_attempt': neighborPerformance['was_first_attempt'],
        'total_correct_attempts': neighborPerformance['total_correct_attempts'],
        'total_incorrect_attempts': neighborPerformance['total_incorrect_attempts'],
        'total_attempts': neighborPerformance['total_attempts'],
        'accuracy_rate': neighborPerformance['accuracy_rate'],
        'revision_streak': neighborPerformance['revision_streak'],
        'days_since_last_revision': neighborPerformance['days_since_last_revision'],
        'days_since_first_introduced': neighborPerformance['days_since_first_introduced'],
        'attempt_day_ratio': neighborPerformance['attempt_day_ratio'],
      };
      
      kNearestRecords.add(knnRecord);
    }
    
    if (kNearestRecords.isEmpty) {
      return null;
    }
    
    // Sort by distance (ascending - closest first)
    kNearestRecords.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    
    return jsonEncode(kNearestRecords);
  }

  /// Gather User Profile vector
  Future<String?>               fetchUserProfileRecord({
    required dynamic db,
    required String userId,
  }) async {
    const query = '''
      SELECT 
        highest_level_edu,
        undergrad_major,
        undergrad_minor,
        grad_major,
        years_since_graduation,
        education_background,
        teaching_experience,
        profile_picture,
        country_of_origin,
        current_country,
        current_state,
        current_city,
        urban_rural,
        religion,
        political_affilition,
        marital_status,
        num_children,
        veteran_status,
        native_language,
        secondary_languages,
        num_languages_spoken,
        birth_date,
        age,
        household_income,
        learning_disabilities,
        physical_disabilities,
        housing_situation,
        birth_order,
        current_occupation,
        years_work_experience,
        hours_worked_per_week,
        total_job_changes
      FROM user_profile
      WHERE uuid = ?
      LIMIT 1
    ''';
    
    final List<Map<String, dynamic>> results = await db.rawQuery(query, [userId]);
    
    if (results.isEmpty) {
      return null;
    }
    
    return jsonEncode(results.first);
  }

  /// Gather User Stats vector
  Future<String?>               fetchUserStatsVector({
    required dynamic db,
    required String userId,
  }) async {
    final String today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    
    const query = '''
      SELECT *
      FROM user_daily_stats
      WHERE user_id = ? AND record_date = ?
      LIMIT 1
    ''';
    
    final List<Map<String, dynamic>> results = await db.rawQuery(query, [userId, today]);
    
    if (results.isEmpty) {
      return null;
    }
    
    return jsonEncode(results.first);
  }

}