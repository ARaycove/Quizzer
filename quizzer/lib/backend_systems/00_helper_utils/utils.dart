import 'dart:io';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart' show decodeValueFromDB;
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

/// Moves an image from the staging directory to the final assets directory
/// Returns just the filename for storage in the database
Future<String> moveImageToFinalLocation(String sourcePath) async {
  try {
    // Create final directory if it doesn't exist
    final finalDir = Directory(await getQuizzerMediaPath());
    if (!await finalDir.exists()) {
      await finalDir.create(recursive: true);
    }

    // Get just the filename from the source path
    final filename = sourcePath.split('/').last;
    final finalPath = '${finalDir.path}/$filename';

    // Move the file
    await File(sourcePath).copy(finalPath);
    await File(sourcePath).delete(); // Clean up staging file

    QuizzerLogger.logMessage('Moved image from $sourcePath to $finalPath');
    return filename; // Return just the filename for storage
  } catch (e) {
    QuizzerLogger.logMessage('Error moving image: $e');
    rethrow;
  }
}

/// Logs the current database monitor lock status
void logDatabaseMonitorStatus() {
  try {
    final monitor = getDatabaseMonitor();
    final isLocked = monitor.isLocked;
    final queueLength = monitor.queueLength;
    final currentHolder = monitor.currentLockHolder;
    
    if (isLocked) {
      QuizzerLogger.logWarning('Database Monitor Status: LOCKED - Queue length: $queueLength - Currently held by: ${currentHolder ?? 'unknown'}');
    } else {
      QuizzerLogger.logSuccess('Database Monitor Status: UNLOCKED - No requests waiting');
    }
  } catch (e) {
    QuizzerLogger.logError('Error checking database monitor status: $e');
  }
}

/// Shared connectivity check function that can be used across the app.
/// Attempts a simple network operation to check for connectivity.
/// Returns true if likely connected, false otherwise.
Future<bool> checkConnectivity() async {
  try {
    // Use a common domain for lookup, less likely to be blocked/down than specific API endpoints.
    final result = await InternetAddress.lookup('google.com'); 
    // Check if the lookup returned any results and if the first result has an address.
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      QuizzerLogger.logMessage('Network check successful.');
      return true;
    }
    // If lookup returned empty or with no address, treat as disconnected.
    QuizzerLogger.logWarning('Network check failed (lookup empty/no address).');
    return false;
  } on SocketException catch (_) {
    // Specifically catch SocketException, typical for network errors (offline, DNS fail).
    QuizzerLogger.logMessage('Network check failed (SocketException): Likely offline.');
    return false;
  } catch (e) {
    // Catch any other unexpected error during the check, log it, return false.
    QuizzerLogger.logError('Unexpected error during network check: $e');
    return false;
  }
}

/// Trims whitespace from content fields in question/answer elements and options
/// Takes either a JSON string or List<Map<String, dynamic>> where each element is {'type': 'text|image|blank', 'content': 'string_value'}
/// Returns the trimmed List<Map<String, dynamic>>
List<Map<String, dynamic>> trimContentFields(dynamic elements) {
  List<Map<String, dynamic>> decodedElements;
  
  if (elements is String) {
    // Use table helper to decode and validate JSON string
    final decoded = decodeValueFromDB(elements);
    if (decoded is! List) {
      throw ArgumentError('JSON string must decode to a List, got ${decoded.runtimeType}');
    }
    decodedElements = List<Map<String, dynamic>>.from(decoded);
  } else if (elements is List) {
    // Already decoded list
    decodedElements = List<Map<String, dynamic>>.from(elements);
  } else {
    throw ArgumentError('Input must be either a JSON string or List<Map<String, dynamic>>');
  }
  
  return decodedElements.map((element) {
    final newElement = Map<String, dynamic>.from(element);
    if (newElement.containsKey('content') && newElement['content'] is String) {
      newElement['content'] = newElement['content'].toString().trim();
    }
    return newElement;
  }).toList();
}

Future<void> logUserSettingsTableContent() async{
  // DEBUG: Check user_settings table contents before getUserSettings
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    final List<Map<String, dynamic>> debugResults = await db!.query('user_settings', where: 'user_id = ?', whereArgs: [getSessionManager().userId]);
    QuizzerLogger.logMessage('Current User Settings Records Are: ${debugResults.length} records: $debugResults');
    getDatabaseMonitor().releaseDatabaseAccess();
}