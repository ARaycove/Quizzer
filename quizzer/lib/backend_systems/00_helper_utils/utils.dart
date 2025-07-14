import 'dart:io';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';

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