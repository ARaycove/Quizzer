import 'dart:async';
import 'dart:math';
import 'package:synchronized/synchronized.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_cache_signals.dart'; // Import cache signals
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Import for logging
// Import for checking if record exists
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';

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
  static const int queueThreshold = 5; // Threshold for signalling removal

  // --- Add Record (with duplicate check within this cache only) ---

  /// Adds a single question record to the end of the queue, only if a record
  /// with the same question_id does not already exist in this cache.
  /// Asserts that the record contains a 'question_id'.
  /// Ensures thread safety using a lock.
  Future<bool> addRecord(Map<String, dynamic> record, {bool updateDatabaseLocation = true}) async {
    try {
      QuizzerLogger.logMessage('Entering QuestionQueueCache addRecord()...');
      // Assert required key exists
      assert(record.containsKey('question_id'), 'Record added to QuestionQueueCache must contain question_id');

      return await _lock.synchronized(() async {
        final bool wasEmpty = _cache.isEmpty;
        final String questionId = record['question_id'];
        final bool alreadyExists = _cache.any((r) => r['question_id'] == questionId);
        if (alreadyExists) return false;
        _cache.add(record);
        if (wasEmpty && _cache.isNotEmpty) {
          QuizzerLogger.logMessage("QuestionQueueCache: Added record $questionId to empty queue.");
          signalQuestionQueueAdded(); // Use unified signal
        }
        return true;
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
          {'type': 'text', 'content': 'Add new modules'},
          {'type': 'text', 'content': 'Check Back Later!'},
        ], 
        'correct_option_index': 0, // Index of the 'Okay' option (or -1 if no default correct)
        'module_name': 'System', // Placeholder module
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
       QuizzerLogger.logMessage('Entering QuestionQueueCache getAndRemoveRecord()...');
       return await _lock.synchronized(() async {
         if (_cache.isNotEmpty) {
           final int lengthBeforeRemove = _cache.length;
           
           // Try to find a valid record (one that still exists in the database)
           Map<String, dynamic>? validRecord;
           int attempts = 0;
           const int maxAttempts = 3; // Limit attempts to avoid infinite loop
           
           while (attempts < maxAttempts && _cache.isNotEmpty) {
             // Select a random index
             final random = Random();
             final int randomIndex = random.nextInt(_cache.length);
             final record = _cache.removeAt(randomIndex);
             final String questionId = record['question_id'] as String;
             
             // Check if this record still exists in the database
             try {
               final Map<String, dynamic>? existingRecord = await getQuestionAnswerPairById(questionId);
               if (existingRecord != null && existingRecord.isNotEmpty) {
                 // Record still exists, use it
                 validRecord = record;
                 QuizzerLogger.logMessage('QuestionQueueCache: Found valid record $questionId after $attempts attempts');
                 break;
               } else {
                 // Record was deleted, try another one
                 QuizzerLogger.logMessage('QuestionQueueCache: Record $questionId was deleted, trying another...');
                 attempts++;
               }
             } catch (e) {
               // Error checking record, assume it's invalid and try another
               QuizzerLogger.logWarning('QuestionQueueCache: Error checking record $questionId: $e. Trying another...');
               attempts++;
             }
           }
           
           // If we found a valid record, return it
           if (validRecord != null) {
             final int lengthAfterRemove = _cache.length;
             
             // Signal that a record was removed
             signalQuestionQueueRemoved();
             // Notify if length dropped below the threshold
             if (lengthBeforeRemove >= queueThreshold && lengthAfterRemove < queueThreshold) {
                QuizzerLogger.logMessage('QuestionQueueCache: Notifying record removed, length now $lengthAfterRemove.');
             }
             return validRecord;
           } else {
             // All records in cache were invalid, clear cache and return dummy
             QuizzerLogger.logWarning('QuestionQueueCache: All records in cache were invalid/deleted. Clearing cache and returning dummy.');
             _cache.clear();
             signalQuestionQueueRemoved();
             return _buildDummyNoQuestionsRecord();
           }
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
      QuizzerLogger.logMessage('Entering QuestionQueueCache getLength()...');
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
