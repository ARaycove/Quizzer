import 'dart:io';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';

// TODO This function needs to be tied into the InboundSync mechanism since this functionality is directly related to ensuring that local question answer pair records match the server

/// Compares local and cloud question records.
/// Returns a map with 'updated' (bool) and 'message' (String).
Future<Map<String, dynamic>> compareAndUpdateQuestionRecord(String questionId) async {
  try {
    // Get local record with raw query
    final List<Map<String, Object?>> localResult = await QuestionAnswerPairsTable().getRecord(
      'SELECT * FROM question_answer_pairs WHERE question_id = \'$questionId\''
      );
    
    if (localResult.isEmpty) {
      return {
        'updated': false,
        'message': 'Question not found locally'
      };
    }
    // Convert Object? to dynamic and normalize types
    final Map<String, dynamic> localRecord = _normalizeRecord(localResult.first);
    
    // Check if this question was created by the current user
    final String? qstContrib = localRecord['qst_contrib'] as String?;
    final String currentUserId = SessionManager().userId ?? '';
    final bool isUserCreated = qstContrib == currentUserId;
    
    // Get cloud record with raw query
    final supabase = SessionManager().supabase;
    final List<dynamic> cloudResponse = await supabase
        .from('question_answer_pairs')
        .select()
        .eq('question_id', questionId)
        .limit(1);
    
    // Question doesn't exist in Supabase - delete local record ONLY if not user-created
    if (cloudResponse.isEmpty) {
      if (isUserCreated) {
        return {
          'updated': false,
          'message': 'Question not found in cloud database but was created by current user - preserving local record'
        };
      } else {
        int i = await QuestionAnswerPairsTable().deleteRecord({'question_id': questionId});
        return {
          'updated': i > 0,
          'message': 'Question not found in cloud database - deleted local record'
        };
      }
    }
    
    // Convert cloud record and normalize types
    final Map<String, dynamic> cloudRecord = _normalizeRecord(Map<String, dynamic>.from(cloudResponse.first));
    
    // Simple comparison - are they exactly the same?
    final bool recordsMatch = _simpleCompare(localRecord, cloudRecord);
    
    if (recordsMatch) {
      return {
        'updated': false,
        'message': 'Records are identical'
      };
    } else {
      await QuestionAnswerPairsTable().batchUpsertRecords(records: [cloudRecord]);
      return {
        'updated': true,
        'message': 'Local record updated with cloud data'
      };
    }
    
  } on SocketException catch (e) {
    QuizzerLogger.logError('Network Error: Failed to connect. Please check your internet connection. $e');
    return {
      'updated': false,
      'message': 'Network Error occurred'
    };
  } catch (e) {
    // This is a catch-all block for any other type of exception.
    // We log it and rethrow it to preserve the original stack trace.
    QuizzerLogger.logError('Error comparing question $questionId: $e');
    rethrow;
  }
}

/// Normalize record types for consistent comparison
Map<String, dynamic> _normalizeRecord(Map<String, dynamic> record) {
  final Map<String, dynamic> normalized = {};
  
  for (final entry in record.entries) {
    final key = entry.key;
    final value = entry.value;
    
    // Handle null values
    if (value == null) {
      normalized[key] = null;
      continue;
    }
    
    // Normalize common types
    if (value is int) {
      normalized[key] = value;
    } else if (value is double) {
      normalized[key] = value;
    } else if (value is bool) {
      normalized[key] = value;
    } else if (value is String) {
      normalized[key] = value;
    } else {
      // Convert everything else to string for comparison
      normalized[key] = value.toString();
    }
  }
  
  return normalized;
}

/// Simple comparison of two records
bool _simpleCompare(Map<String, dynamic> local, Map<String, dynamic> cloud) {
  if (local.length != cloud.length) return false;
  
  for (final key in local.keys) {
    final localValue = local[key];
    final cloudValue = cloud[key];
    
    if (localValue != cloudValue) return false;
  }
  
  return true;
}
