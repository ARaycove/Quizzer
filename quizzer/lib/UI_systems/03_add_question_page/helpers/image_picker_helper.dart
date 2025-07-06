import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p; // Use alias
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:uuid/uuid.dart'; // To generate unique filenames
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';

/// Allows the user to pick an image, copies it to the staging directory
/// with a unique name, and returns the relative path within the staging directory.
/// Returns null if picking is cancelled or fails.
Future<String?> pickAndStageImage() async {
  QuizzerLogger.logMessage("Attempting to pick and stage image...");

  // 1. Pick Image File
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.image, // Limit to image types
  );

  if (result == null) {
    QuizzerLogger.logMessage('Image picking cancelled.');
    return null; // User cancelled picker
  }

  final pickedFile = result.files.single;
  final originalFileName = pickedFile.name;
  QuizzerLogger.logValue("Image picked: $originalFileName");

  // 2. Generate Unique Filename
  final String fileExtension = p.extension(originalFileName); // Includes '.'
  final String uniqueFileName = '${const Uuid().v4()}$fileExtension';

  // 3. Define Paths
  final String stagingDirPath = await getInputStagingPath();
  final String destinationStagedPath = p.join(stagingDirPath, uniqueFileName);

  // Ensure staging directory exists
  await Directory(stagingDirPath).create(recursive: true);

  // 4. Copy to Staging (handle Web vs Native)
  try {
    if (kIsWeb) {
      // On web, we have bytes. Write them to the logical destination path.
      // Note: This saves relative to where the web server runs, might need adjustment
      // depending on server setup and how assets are served. For local dev,
      // writing to the project structure might work but isn't typical for web deployment.
      // A dedicated upload mechanism is usually needed for web persistence.
      // THIS IS A PLACEHOLDER for web - Needs proper web storage/upload handling.
      final bytes = pickedFile.bytes;
      if (bytes == null) {
        QuizzerLogger.logError("Web image picking returned null bytes.");
        return null;
      }
      await File(destinationStagedPath).writeAsBytes(bytes);
      QuizzerLogger.logMessage("Web image bytes written to staging path (Placeholder logic): $destinationStagedPath");
    } else {
      // Native platforms: Copy the file
      final sourcePath = pickedFile.path;
      if (sourcePath == null) {
        QuizzerLogger.logError("Native image picking returned null path.");
        return null;
      }
      await File(sourcePath).copy(destinationStagedPath);
      QuizzerLogger.logMessage("Native image copied from $sourcePath to $destinationStagedPath");
    }

    QuizzerLogger.logSuccess("Image successfully staged with filename: $uniqueFileName");
    return uniqueFileName;

  } catch (e) {
    QuizzerLogger.logError("Error staging image '$originalFileName': $e");
    return null;
  }
}


/// Iterates through question and answer elements, moves staged images
/// to the final assets directory, and updates the element content paths in place.
///
/// Args:
///   questionElements: The list of question element maps.
///   answerElements: The list of answer element maps.
///
/// Returns:
///   A Future<void> that completes when all processing is done.
///   Throws errors if file operations fail (Fail Fast).
Future<void> finalizeStagedImages(
  List<Map<String, dynamic>> questionElements,
  List<Map<String, dynamic>> answerElements,
) async {
  QuizzerLogger.logMessage("Finalizing staged images...");
  final List<Map<String, dynamic>> allElements = [...questionElements, ...answerElements];
  int movedCount = 0;

  // Ensure assets directory exists
  await Directory(await getQuizzerMediaPath()).create(recursive: true);

  for (final element in allElements) {
    if (element['type'] == 'image' && element['content'] is String) {
      // CORRECTED: Assume content is just the filename
      final String filename = element['content'] as String;

      // Construct full paths based on filename and known directories
      final String sourcePath = p.join(await getInputStagingPath(), filename);
      final String destinationPath = p.join(await getQuizzerMediaPath(), filename);

      // Check if the source file actually exists in staging
      final sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        try {
          // Use copy and delete for robustness across filesystems/volumes
          await sourceFile.copy(destinationPath);
          await sourceFile.delete();
          QuizzerLogger.logMessage("Moved image $filename from staging to assets: $destinationPath");
          movedCount++;

          // *** REMOVED: Do NOT update element content, it already holds the correct filename ***
          // element['content'] = newRelativePath;

        } catch (e) {
          QuizzerLogger.logError("Error moving image $filename from staging to assets: $e");
          // Rethrow to signal failure in the submission process (Fail Fast for file ops)
          rethrow;
        }
      } else {
         // File not in staging. Either already moved, never existed, or content is not just a filename.
         // Log this, but don't treat as an error unless strict checking is needed.
         QuizzerLogger.logWarning("Image '$filename' mentioned in element content not found in staging directory: $sourcePath. Skipping move.");
      }
    }
  }
  QuizzerLogger.logSuccess("Image finalization complete. Attempted to move $movedCount images.");
}

/// Deletes files from the staging directory that are not in the provided list of used filenames.
/// Use this after successful submission to clean up unused staged images.
///
/// Args:
///   usedFilenames: A Set of filenames that were part of the successful submission.
Future<void> cleanupStagingDirectory(Set<String> usedFilenames) async {
  QuizzerLogger.logMessage("Cleaning up staging directory. Keeping: ${usedFilenames.join(', ')}");
  int deletedCount = 0;
  final String stagingDirPath = await getInputStagingPath();
  final stagingDir = Directory(stagingDirPath);

  try {
    if (await stagingDir.exists()) {
      final Stream<FileSystemEntity> files = stagingDir.list();
      await for (final FileSystemEntity entity in files) {
        if (entity is File) {
          final filename = p.basename(entity.path);
          // Check if the filename is NOT in the set of files we want to keep
          if (!usedFilenames.contains(filename)) {
            try {
              await entity.delete();
              QuizzerLogger.logValue("Deleted unused staged file: $filename");
              deletedCount++;
            } catch (e) {
              QuizzerLogger.logError("Failed to delete unused staged file $filename: $e");
              // Continue trying to delete others
            }
          }
        }
      }
      QuizzerLogger.logSuccess("Staging directory cleanup complete. Deleted $deletedCount unused files.");
    } else {
      QuizzerLogger.logMessage("Staging directory does not exist, skipping cleanup.");
    }
  } catch (e) {
    QuizzerLogger.logError("Error during staging directory cleanup: $e");
    // Don't rethrow, cleanup failure shouldn't block main flow usually
  }
} 