import 'dart:io';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';

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

