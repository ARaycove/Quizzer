import 'dart:async';
import 'dart:math';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/09_switch_board/sb_cache_signals.dart'; // Import cache signals
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Import for logging
import 'package:quizzer/backend_systems/06_question_answer_pair_management/question_answer_pair_manager.dart';

// ==========================================

/// Cache holding questions selected and ready for presentation to the user.
/// Populated by the Presentation Selection Worker, consumed by the Session API/UI.
/// Implements the singleton pattern.
class QuestionQueueCache {
  // Singleton pattern setup
  static final QuestionQueueCache _instance = QuestionQueueCache._internal();
  factory QuestionQueueCache() => _instance;
  QuestionQueueCache._internal(); // Private constructor

  final Lock _lock = Lock();
  final List<Map<String, dynamic>> _cache = [];
  static const int queueThreshold = 5; // Threshold for number of questions to be stored in the queueCache

  // --- Add Record (with duplicate check within this cache only) ---

  /// Adds a single question record to the end of the queue, only if a record
  /// with the same question_id does not already exist in this cache.
  /// Asserts that the record contains a 'question_id'.
  /// Ensures thread safety using a lock.
  Future<bool> addRecord(Map<String, dynamic> record, {bool updateDatabaseLocation = true}) async {
    try {
      assert(record.containsKey('question_id'), 'Record added to QuestionQueueCache must contain question_id');
      
      return await _lock.synchronized(() async {
        final bool wasEmpty = _cache.isEmpty;
        final String questionId = record['question_id'];
        final bool alreadyExists = _cache.any((r) => r['question_id'] == questionId);
        if (alreadyExists) return false;
        
        // FETCH FULL QUESTION DETAILS BEFORE ADDING TO CACHE
        try {
          final Map<String, dynamic> fullQuestion = await QuestionAnswerPairManager().getQuestionAnswerPairById(questionId);
          if (fullQuestion.isEmpty) {
            QuizzerLogger.logWarning('Question $questionId not found in database, skipping cache addition');
            return false;
          }
          
          _cache.add(fullQuestion); // Store the full question record
          QuizzerLogger.logMessage("QuestionQueueCache: Added FULL record $questionId to queue. Current length: ${_cache.length}");
          
          if (wasEmpty && _cache.isNotEmpty) {
            signalQuestionQueueAdded(); // Use unified signal
          }
          return true;
        } catch (e) {
          QuizzerLogger.logError('Error fetching full question for cache: $e');
          return false;
        }
      });
    } catch (e) {
      QuizzerLogger.logError('Error in QuestionQueueCache addRecord - $e');
      rethrow;
    }
  }

  // --- Get and Remove Record (FIFO) ---

  /// Builds placeholder records for display when the question queue is empty.
  Map<String, dynamic> _buildDummyNoQuestionsRecord() {
    try {
      QuizzerLogger.logMessage('Entering QuestionQueueCache _buildDummyNoQuestionsRecord()...');
      
      const String dummyId = "dummy_no_questions";
      
      // Return a complete dummy question record
      final Map<String, dynamic> dummyRecord = {
        'question_id': dummyId,
        'question_type': 'multiple_choice', // Use multiple choice as requested
        // Format follows the parsed structure from getQuestionAnswerPairById
        'question_elements': [{'type': 'text', 'content': 'No new questions available right now. Check back later!'}], 
        'answer_elements': [{'type': 'text', 'content': ''}], // Empty answer
        'options': [
          {'type': 'text', 'content': 'Okay'},
          {'type': 'text', 'content': 'Check Back Later!'},
        ], 
        'correct_option_index': 0, // Index of the 'Okay' option (or -1 if no default correct)
        'subjects': '', // Placeholder subjects
        'concepts': '', // Placeholder concepts
        // Add other QPair fields with default/placeholder values if required by UI
        'time_stamp': DateTime.now().millisecondsSinceEpoch.toString(),
        'qst_contrib': 'system',
        'ans_contrib': 'system',
        'citation': '',
        'ans_flagged': false,
        'has_been_reviewed': true,
        'flag_for_removal': false,
        'completed': true, 
        'correct_order': '', // Empty for non-sort_order
      };
      
      QuizzerLogger.logMessage('Successfully built dummy no questions record with ID: $dummyId');
      
      return dummyRecord;
    } catch (e) {
      QuizzerLogger.logError('Error in QuestionQueueCache _buildDummyNoQuestionsRecord - $e');
      rethrow;
    }
  }

  /// Removes and returns a random record from the cache.
  /// Used to get the next question for presentation.
  /// Ensures thread safety using a lock.
  /// Returns a dummy record if the cache is empty.
  /// Handles cases where records may have been deleted by the compare function.
  Future<Map<String, dynamic>> getAndRemoveRecord() async {
    try {
      return await _lock.synchronized(() async {
        if (_cache.isNotEmpty) {
          // Select a random record from cache
          final random = Random();
          final int randomIndex = random.nextInt(_cache.length);
          final record = _cache.removeAt(randomIndex);
          final String questionId = record['question_id'] as String;
          
          QuizzerLogger.logMessage("QuestionQueueCache: Instantly returning cached record $questionId from index $randomIndex");
          
          // Signal that a record was removed
          signalQuestionQueueRemoved();
          return record; // Return immediately, no database check
        } else {
          // Return a dummy record if the cache is empty
          QuizzerLogger.logWarning('QuestionQueueCache: Cache is empty, returning dummy record');
          return _buildDummyNoQuestionsRecord();
        }
      });
    } catch (e) {
      QuizzerLogger.logError('Error in QuestionQueueCache getAndRemoveRecord - $e');
      rethrow;
    }
  }

  // --- Get Length ---
  /// Returns the current number of records in the queue.
  /// Ensures thread safety using a lock.
  Future<int> getLength() async {
    try {
      // QuizzerLogger.logMessage('Entering QuestionQueueCache getLength()...');
      return await _lock.synchronized(() {
        return _cache.length;
      });
    } catch (e) {
      QuizzerLogger.logError('Error in QuestionQueueCache getLength - $e');
      rethrow;
    }
  }

  // --- Peek All Records (Read-Only) ---

  /// Returns a read-only copy of all records currently in the queue.
  /// Ensures thread safety using a lock.
  Future<List<Map<String, dynamic>>> peekAllRecords() async {
    try {
      QuizzerLogger.logMessage('Entering QuestionQueueCache peekAllRecords()...');
      return await _lock.synchronized(() {
        // Return a copy to prevent external modification
        return List<Map<String, dynamic>>.from(_cache);
      });
    } catch (e) {
      QuizzerLogger.logError('Error in QuestionQueueCache peekAllRecords - $e');
      rethrow;
    }
  }

  // --- Check if Contains Question ID ---
  /// Checks if a record with the specified questionId exists in the cache.
  /// Ensures thread safety using a lock.
  Future<bool> containsQuestionId(String questionId) async {
    try {
      QuizzerLogger.logMessage('Entering QuestionQueueCache containsQuestionId()...');
      return await _lock.synchronized(() {
        return _cache.any((record) => record['question_id'] == questionId);
      });
    } catch (e) {
      QuizzerLogger.logError('Error in QuestionQueueCache containsQuestionId - $e');
      rethrow;
    }
  }

  // --- Check if Empty ---
  /// Checks if the cache is currently empty.
  Future<bool> isEmpty() async {
    try {
      QuizzerLogger.logMessage('Entering QuestionQueueCache isEmpty()...');
      return await _lock.synchronized(() {
        return _cache.isEmpty;
      });
    } catch (e) {
      QuizzerLogger.logError('Error in QuestionQueueCache isEmpty - $e');
      rethrow;
    }
  }

  Future<void> clear() async {
    try {
      QuizzerLogger.logMessage('Entering QuestionQueueCache clear()...');
      await _lock.synchronized(() {
        if (_cache.isNotEmpty) {
          // Signal that records were removed (single signal for clear operation)
          signalQuestionQueueRemoved();
          _cache.clear();
          QuizzerLogger.logMessage('QuestionQueueCache cleared.');
        }
      });
    } catch (e) {
      QuizzerLogger.logError('Error in QuestionQueueCache clear - $e');
      rethrow;
    }
  }
}
