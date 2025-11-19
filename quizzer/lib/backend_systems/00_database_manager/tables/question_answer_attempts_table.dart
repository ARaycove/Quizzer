import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'table_helper.dart'; // Import the helper file
import 'package:quizzer/backend_systems/09_switch_board/sb_sync_worker_signals.dart'; // Import sync signals
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'dart:convert'; 


final List<Map<String, String>> expectedColumns = [
  // ===================================
  // Meta Data
  // ===================================
  // When was this entered?
  {'name': 'time_stamp',                'type': 'TEXT NOT NULL'},
  // What question was answered
  {'name': 'question_id',               'type': 'TEXT NOT NULL'},
  // The uuid of the user in question
  {'name': 'participant_id',            'type': 'TEXT NOT NULL'},
  // ===================================
  // Question_Metrics (not performance related, what is the question?)
  // ===================================
  {'name': "question_vector",           'type': 'TEXT NOT NULL'}, // What does the transformer say?
  {'name': "question_type",             'type': 'TEXT NOT NULL'}, // What is the question type?
  {'name': "num_mcq_options",           'type': 'INTEGER NULL DEFAULT 0'}, // How many mcq options does this have (should be 0 if the type is not mcq)
  {'name': "num_so_options",            'type': 'INTEGER NULL DEFAULT 0'},
  {'name': "num_sata_options",          'type': 'INTEGER NULL DEFAULT 0'},
  {'name': "num_blanks",                'type': 'INTEGER NULL DEFAULT 0'},
  // ===================================
  // Individual Question Performance
  // ===================================
  {'name': 'avg_react_time',             'type': 'REAL NOT NULL'}, // FIXME
  {'name': 'response_result',           'type': 'INTEGER NOT NULL'}, // Did the user get this question correct after presentation 0 or 1
  {'name': 'was_first_attempt',         'type': 'INTEGER NOT NULL'}, // At time of presentation, had user attempted this before? 0 or 1
  {'name': 'total_correct_attempts',    'type': 'INTEGER NOT NULL'},
  {'name': 'total_incorrect_attempts',  'type': 'INTEGER NOT NULL'},
  {'name': 'total_attempts',            'type': 'INTEGER NOT NULL'},
  {'name': 'accuracy_rate',             'type': 'REAL NOT NULL'},
  {'name': 'revision_streak',           'type': 'INTEGER NOT NULL'},

  // Temporal metrics
  {'name': 'time_of_presentation',      'type': 'TEXT NULL'},
  {'name': 'last_revised_date',         'type': 'TEXT NULL'},
  {'name': 'days_since_last_revision',  'type': 'REAL NULL'},
  {'name': 'days_since_first_introduced','type':'REAL NULL'},
  {'name': 'attempt_day_ratio',         'type': 'REAL NULL'}, // total_attempts/days_since_introduced
  

  // User Stats metrics Vector
  // The current state of global statistics at time of answer, array of maps
  {'name': 'user_stats_vector',         'type': 'TEXT'},
  // K nearest performance (from closest to further ordered)
  // TODO update record attempt to collect and store this information
  {'name': 'knn_performance_vector',           'type': 'TEXT NULL'},
  // User Profile at time of presentation -> Vector (Fixed)
  {'name': 'user_profile_record',              'type': 'TEXT NULL'},
  // Sync tracking metrics
  {'name': 'has_been_synced',           'type': 'INTEGER DEFAULT 0'},
  {'name': 'edits_are_synced',          'type': 'INTEGER DEFAULT 0'},
  {'name': 'last_modified_timestamp',   'type': 'TEXT'},
];

/// Verifies the existence and schema of the question_answer_attempts table.
Future<void> verifyQuestionAnswerAttemptTable(dynamic db) async {
  try {
    QuizzerLogger.logMessage('Verifying question_answer_attempts table existence');
    
    // Check if the table exists
    final List<Map<String, dynamic>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      ['question_answer_attempts']
    );

    if (tables.isEmpty) {
      // Create the table if it doesn't exist
      QuizzerLogger.logMessage('question_answer_attempts table not found, creating...');
      
      String createTableSQL = 'CREATE TABLE question_answer_attempts(\n';
      createTableSQL += expectedColumns.map((col) => '  ${col['name']} ${col['type']}').join(',\n');
      createTableSQL += ',\n  PRIMARY KEY (participant_id, question_id, time_stamp)\n)';
      
      await db.execute(createTableSQL);
      QuizzerLogger.logSuccess('question_answer_attempts table created successfully.');
    } else {
      // Table exists, check for column differences
      QuizzerLogger.logMessage('question_answer_attempts table already exists. Checking column structure...');
      
      // Get current table structure
      final List<Map<String, dynamic>> currentColumns = await db.rawQuery(
        "PRAGMA table_info(question_answer_attempts)"
      );
      
      final Set<String> currentColumnNames = currentColumns
          .map((column) => column['name'] as String)
          .toSet();
      
      final Set<String> expectedColumnNames = expectedColumns
          .map((column) => column['name']!)
          .toSet();
      
      // Find columns to add (expected but not current)
      final Set<String> columnsToAdd = expectedColumnNames.difference(currentColumnNames);
      
      // Find columns to remove (current but not expected)
      final Set<String> columnsToRemove = currentColumnNames.difference(expectedColumnNames);
      
      // Add missing columns
      for (String columnName in columnsToAdd) {
        final columnDef = expectedColumns.firstWhere((col) => col['name'] == columnName);
        QuizzerLogger.logMessage('Adding missing column: $columnName');
        await db.execute('ALTER TABLE question_answer_attempts ADD COLUMN ${columnDef['name']} ${columnDef['type']}');
      }
      
      // Remove unexpected columns (SQLite doesn't support DROP COLUMN directly)
      if (columnsToRemove.isNotEmpty) {
        QuizzerLogger.logMessage('Removing unexpected columns: ${columnsToRemove.join(', ')}');
        
        // Create temporary table with only expected columns
        String tempTableSQL = 'CREATE TABLE question_answer_attempts_temp(\n';
        tempTableSQL += expectedColumns.map((col) => '  ${col['name']} ${col['type']}').join(',\n');
        tempTableSQL += ',\n  PRIMARY KEY (participant_id, question_id, time_stamp)\n)';
        
        await db.execute(tempTableSQL);
        
        // Copy data from old table to temp table (only expected columns)
        String columnList = expectedColumnNames.join(', ');
        await db.execute('INSERT INTO question_answer_attempts_temp ($columnList) SELECT $columnList FROM question_answer_attempts');
        
        // Drop old table and rename temp table
        await db.execute('DROP TABLE question_answer_attempts');
        await db.execute('ALTER TABLE question_answer_attempts_temp RENAME TO question_answer_attempts');
        
        QuizzerLogger.logSuccess('Removed unexpected columns and restructured table');
      }
      
      if (columnsToAdd.isEmpty && columnsToRemove.isEmpty) {
        QuizzerLogger.logMessage('Table structure is already up to date');
      } else {
        QuizzerLogger.logSuccess('Table structure updated successfully');
      }
    }
  } catch (e) {
    QuizzerLogger.logError('Error verifying question_answer_attempts table - $e');
    rethrow;
  }
}

// --- Public Database Operations ---

/// Adds a new question answer attempt record to the database.
/// Accepts any dynamic field data and validates against the schema.
/// Logs warnings for any fields that don't exist in the expected schema.
Future<int> addQuestionAnswerAttempt({
  required String participantId,
  required String questionId, 
  required String timeStamp,
  Map<String, dynamic>? additionalFields,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Adding question attempt for Q: $questionId, User: $participantId');
    
    // Create set of valid column names for validation
    final Set<String> validColumnNames = expectedColumns
        .map((col) => col['name']!)
        .toSet();
    
    // Start with primary key fields
    final Map<String, dynamic> attemptData = {
      'participant_id': participantId,
      'question_id': questionId,
      'time_stamp': timeStamp,
    };
    
    // Process additional fields if provided
    if (additionalFields != null) {
      for (final entry in additionalFields.entries) {
        final String fieldName = entry.key;
        final dynamic fieldValue = entry.value;
        
        // Validate field exists in schema
        if (validColumnNames.contains(fieldName)) {
          attemptData[fieldName] = fieldValue;
        } else {
          // Log warning for invalid field names
          QuizzerLogger.logWarning('Attempted to insert invalid field "$fieldName" with value "$fieldValue" into question_answer_attempts table. Field not found in expected schema. Skipping field.');
        }
      }
    }

    QuizzerLogger.logMessage('Prepared attempt data with ${attemptData.length} fields: ${attemptData.keys.join(', ')}');

    // Use the universal insert helper
    final int resultId = await insertRawData(
      'question_answer_attempts',
      attemptData,
      db,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    if (resultId > 0) {
      QuizzerLogger.logSuccess('Successfully added question attempt record with result ID: $resultId for Q: $questionId, User: $participantId');
      // Signal the SwitchBoard that new data might need syncing
      signalOutboundSyncNeeded();
    } else {
      QuizzerLogger.logWarning('Insert operation for attempt (Q: $questionId, User: $participantId) returned $resultId. Might be ignored duplicate.');
    }
    return resultId;
  } catch (e) {
    QuizzerLogger.logError('Error adding question answer attempt - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Deletes a question answer attempt record by its composite primary key.
Future<int> deleteQuestionAnswerAttemptRecord(String participantId, String questionId, String timeStamp) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Deleting question answer attempt (PID: $participantId, QID: $questionId, TS: $timeStamp)');
    final int rowsDeleted = await db.delete(
      'question_answer_attempts',
      where: 'participant_id = ? AND question_id = ? AND time_stamp = ?',
      whereArgs: [participantId, questionId, timeStamp],
    );
    if (rowsDeleted == 0) {
      QuizzerLogger.logWarning('No question answer attempt found to delete for (PID: $participantId, QID: $questionId, TS: $timeStamp)');
    } else {
      QuizzerLogger.logSuccess('Deleted $rowsDeleted question answer attempt(s) for (PID: $participantId, QID: $questionId, TS: $timeStamp)');
    }
    return rowsDeleted;
  } catch (e) {
    QuizzerLogger.logError('Error deleting question answer attempt record - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// --- Optional Getter Functions ---

/// Retrieves all attempts for a specific question by a specific user.
Future<List<Map<String, dynamic>>> getAttemptsByQuestionAndUser(String questionId, String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching attempts for Q: $questionId, User: $userId');
    // Use the universal query helper
    return await queryAndDecodeDatabase(
      'question_answer_attempts',
      db,
      where: 'participant_id = ? AND question_id = ?',
      whereArgs: [userId, questionId],
      orderBy: 'time_stamp DESC', // Order by most recent first
    );
  } catch (e) {
    QuizzerLogger.logError('Error getting attempts by question and user - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Retrieves all attempts made by a specific user.
Future<List<Map<String, dynamic>>> getAttemptsByUser(String userId) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching all attempts for User: $userId');
    // Use the universal query helper
    return await queryAndDecodeDatabase(
      'question_answer_attempts',
      db,
      where: 'participant_id = ?',
      whereArgs: [userId],
      orderBy: 'time_stamp DESC', // Order by most recent first
    );
  } catch (e) {
    QuizzerLogger.logError('Error getting attempts by user - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// --- Get Unsynced Records ---

/// Fetches all question answer attempts that need outbound synchronization.
/// This includes records that have never been synced (`has_been_synced = 0`)
/// or records that have local edits pending sync (`edits_are_synced = 0`).
/// Does NOT decode the records.
Future<List<Map<String, dynamic>>> getUnsyncedQuestionAnswerAttempts() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching unsynced question answer attempts...');
    final List<Map<String, dynamic>> results = await db.query(
      'question_answer_attempts',
      where: 'has_been_synced = 0 OR edits_are_synced = 0',
    );

    QuizzerLogger.logSuccess('Fetched ${results.length} unsynced question answer attempts.');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced question answer attempts - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}


/*
=================================================================
Utility Queries for attempt data
=================================================================
-----
All of these are transaction functions and do not handle db access themselves
-----
*/ 

// Gather metadata for collection process
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
    throw Exception('Question not found: $questionId');
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

// Gather individual performance record
Future<Map<String, dynamic>> fetchUserQuestionPerformance({
  required dynamic db,
  required String userId,
  required String questionId,
  required String timeStamp,
}) async {
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

// Gather KNN performance vector
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
    
    final Map<String, dynamic> neighborPerformance = await fetchUserQuestionPerformance(
      db: db,
      userId: userId,
      questionId: neighborQuestionId,
      timeStamp: timeStamp,
    );
    
    final Map<String, dynamic> neighborMetadata = await fetchQuestionMetadata(
      db: db,
      questionId: neighborQuestionId,
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
// Gather User Profile vector
Future<String?> fetchUserProfileRecord({
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
// Gather User Stats vector
Future<String?> fetchUserStatsVector({
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