import 'package:quizzer/global/database/tables/question_answer_pairs_table.dart';
import 'package:quizzer/global/database/database_monitor.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> handleAddQuestionAnswerPair(Map<String, dynamic> data) async {
  final timeStamp = data['timeStamp'] as String;
  final questionElements = data['questionElements'] as List<Map<String, dynamic>>;
  final answerElements = data['answerElements'] as List<Map<String, dynamic>>;
  final ansFlagged = data['ansFlagged'] as bool;
  final ansContrib = data['ansContrib'] as String;
  final qstContrib = data['qstContrib'] as String;
  final hasBeenReviewed = data['hasBeenReviewed'] as bool;
  final flagForRemoval = data['flagForRemoval'] as bool;
  final moduleName = data['moduleName'] as String;
  final questionType = data['questionType'] as String;
  final options = data['options'] as List<String>?;
  final correctOptionIndex = data['correctOptionIndex'] as int?;
  
  QuizzerLogger.logMessage('Starting question-answer pair addition process');
  QuizzerLogger.logMessage('Module: $moduleName, Type: $questionType, Contributor: $qstContrib');
  QuizzerLogger.logMessage('Question elements: ${questionElements.length}, Answer elements: ${answerElements.length}');
  
  final monitor = getDatabaseMonitor();
  Database? db;
  
  try {
    while (db == null) {
      db = await monitor.requestDatabaseAccess();
      if (db == null) {
        QuizzerLogger.logMessage('Database access denied, waiting...');
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    QuizzerLogger.logMessage('Database access granted');
    
    QuizzerLogger.logMessage('Adding question-answer pair to database');
    await addQuestionAnswerPair(
      timeStamp: timeStamp,
      questionElements: questionElements,
      answerElements: answerElements,
      ansFlagged: ansFlagged,
      ansContrib: ansContrib,
      qstContrib: qstContrib,
      hasBeenReviewed: hasBeenReviewed,
      flagForRemoval: flagForRemoval,
      moduleName: moduleName,
      questionType: questionType,
      options: options,
      correctOptionIndex: correctOptionIndex,
      db: db
    );
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logSuccess('Question-answer pair added successfully');
  } catch (e) {
    monitor.releaseDatabaseAccess();
    QuizzerLogger.logError('Error adding question-answer pair: $e');
  } finally {
    monitor.releaseDatabaseAccess();
  }
} 