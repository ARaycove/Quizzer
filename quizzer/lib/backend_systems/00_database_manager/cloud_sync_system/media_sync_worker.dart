import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:quizzer/backend_systems/00_helper_utils/utils.dart' as utils;
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/09_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/09_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';
import 'package:supabase/supabase.dart'; // For Supabase storage operations
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';
// ==========================================
// Media Sync Worker (Image Sync)
// ==========================================
/// Manages the synchronization of media files (e.g., images) 
/// between local storage and Supabase storage.
class MediaSyncWorker {
  // --- Singleton Setup ---
  static final MediaSyncWorker _instance = MediaSyncWorker._internal();
  factory MediaSyncWorker() => _instance;
  MediaSyncWorker._internal() {
    QuizzerLogger.logMessage('MediaSyncWorker initialized.');
  }
  // --------------------

  // --- Worker State ---
  bool _isRunning = false;
  // --------------------

  // --- Dependencies ---
  final SwitchBoard _switchBoard = getSwitchBoard();
  final String _supabaseBucketName = 'question-answer-pair-assets';
  // --------------------

  // --- Control Methods ---
  /// Starts the worker loop.
  Future<void> start() async {
    QuizzerLogger.logMessage('Entering MediaSyncWorker start()...');
    
    if (SessionManager().userId == null) {
      QuizzerLogger.logWarning('MediaSyncWorker: Cannot start, no user logged in.');
      return;
    }
    
    _isRunning = true;
    _runLoop();
    QuizzerLogger.logMessage('MediaSyncWorker started.');
  }

  /// Stops the worker loop.
  Future<void> stop() async {
    QuizzerLogger.logMessage('Entering MediaSyncWorker stop()...');

    if (!_isRunning) {
      QuizzerLogger.logMessage('MediaSyncWorker: stop() called but worker is not running.');
      return; 
    }

    _isRunning = false;
    QuizzerLogger.logMessage('MediaSyncWorker stopped.');
  }
  // ----------------------

  // --- Main Loop ---
  Future<void> _runLoop() async {
    QuizzerLogger.logMessage('Entering MediaSyncWorker _runLoop()...');
    
    while (_isRunning) {
      // Check connectivity first
      final bool isConnected = await utils.checkConnectivity();
      if (!isConnected) {
        QuizzerLogger.logMessage('MediaSyncWorker: No network connectivity, waiting 5 minutes before next attempt...');
        await Future.delayed(const Duration(minutes: 5));
        continue;
      }
      
      // Process NULL media status pairs
      QuizzerLogger.logMessage('MediaSyncWorker: Checking for question pairs with NULL has_media status.');
      await QuestionAnswerPairsTable().processNullMediaStatusPairs();
      QuizzerLogger.logMessage('MediaSyncWorker: Database access released after processing NULL has_media records.');
      
      // Run media sync
      QuizzerLogger.logMessage('MediaSyncWorker: Running media sync...');
      await _performSync();
      QuizzerLogger.logMessage('MediaSyncWorker: Media sync completed.');
      
      // Signal that the sync cycle is complete
      signalMediaSyncCycleComplete();
      QuizzerLogger.logMessage('MediaSyncWorker: Sync cycle complete signal sent.');
      
      // Wait for signal that another cycle is needed
      QuizzerLogger.logMessage('MediaSyncWorker: Waiting for sync signal...');
      await _switchBoard.onMediaSyncNeeded.first;
      QuizzerLogger.logMessage('MediaSyncWorker: Woke up by sync signal.');
    }
    
    QuizzerLogger.logMessage('MediaSyncWorker loop finished.');
  }
  // -----------------

  // --- Core Sync Logic --- 
  Future<void> _performSync() async {
    QuizzerLogger.logMessage('MediaSyncWorker: _performSync() called.');
    // Brute-force download all Supabase media files before selective sync
    final List<String> serverFiles = await _bruteForceDownloadAllSupabaseMedia();
    await _processUploads(serverFiles);
    if (!_isRunning) return;
    
    QuizzerLogger.logMessage('MediaSyncWorker: _performSync() finished.');
  }


  /// Brute-force download: Download every file in the Supabase bucket if not present locally
  /// Returns the list of server file names
  Future<List<String>> _bruteForceDownloadAllSupabaseMedia() async {
    QuizzerLogger.logMessage('MediaSyncWorker: Starting brute-force download of all Supabase media files.');
    if (!_isRunning) {
      QuizzerLogger.logMessage('MediaSyncWorker (_bruteForceDownloadAllSupabaseMedia): Worker stopped before starting.');
      return [];
    }
    final supabase = SessionManager().supabase;
    const String bucketName = 'question-answer-pair-assets';
    final String localAssetBasePath = await getQuizzerMediaPath();

    List<FileObject> files = [];
    try {
      files = await supabase.storage.from(bucketName).list();
    } catch (e) {
      QuizzerLogger.logError('MediaSyncWorker: Failed to list files in Supabase bucket: $e');
      return [];
    }

    final List<String> serverFileNames = files.map((obj) => obj.name).toList();

    for (final fileObj in files) {
      if (!_isRunning) {
        QuizzerLogger.logMessage('MediaSyncWorker (_bruteForceDownloadAllSupabaseMedia): Worker stopped during file loop.');
        break; 
      }
      final String fileName = fileObj.name;
      final String localFilePath = path.join(localAssetBasePath, fileName);
      final File localFile = File(localFilePath);

      if (!await localFile.exists()) {
        try {
          QuizzerLogger.logMessage('MediaSyncWorker: Downloading $fileName from Supabase.');
          final Uint8List bytes = await supabase.storage.from(bucketName).download(fileName);
          await Directory(path.dirname(localFilePath)).create(recursive: true);
          await localFile.writeAsBytes(bytes);
          QuizzerLogger.logSuccess('MediaSyncWorker: Downloaded and saved $fileName.');
        } catch (e) {
          QuizzerLogger.logError('MediaSyncWorker: Failed to download $fileName: $e');
        }
      } else {
        QuizzerLogger.logMessage('MediaSyncWorker: $fileName already exists locally, skipping.');
      }
    }
    QuizzerLogger.logMessage('MediaSyncWorker: Brute-force download complete.');
    return serverFileNames;
  }

  Future<void> _processUploads(List<String> serverFiles) async {
    QuizzerLogger.logMessage('MediaSyncWorker: Starting brute force _processUploads using provided server file list.');

    final supabase = SessionManager().supabase;

    // Get list of files in local media directory
    final String localAssetBasePath = await getQuizzerMediaPath();
    final Directory localDir = Directory(localAssetBasePath);
    List<String> localFiles = [];
    
    if (await localDir.exists()) {
      try {
        final List<FileSystemEntity> localEntities = await localDir.list().toList();
        localFiles = localEntities
            .whereType<File>()
            .map((entity) => path.basename(entity.path))
            .toList();
        QuizzerLogger.logMessage('MediaSyncWorker: Found ${localFiles.length} files locally.');
      } catch (e) {
        QuizzerLogger.logError('MediaSyncWorker: Failed to list local files: $e');
        return;
      }
    } else {
      QuizzerLogger.logMessage('MediaSyncWorker: Local media directory does not exist, no files to upload.');
      return;
    }

    // Find files that exist locally but not on server
    final Set<String> serverFileSet = serverFiles.toSet();
    final List<String> filesToUpload = localFiles.where((fileName) => !serverFileSet.contains(fileName)).toList();

    if (filesToUpload.isEmpty) {
      QuizzerLogger.logMessage('MediaSyncWorker: No files found to upload (all local files exist on server).');
      return;
    }
    QuizzerLogger.logValue('MediaSyncWorker: Found ${filesToUpload.length} files to upload: ${filesToUpload.join(', ')}');

    // Upload each file that exists locally but not on server
    for (final fileName in filesToUpload) {
      if (!_isRunning) break;
      final String localFilePath = path.join(localAssetBasePath, fileName);

      try {
        final File localFile = File(localFilePath);
        if (!await localFile.exists()) {
            QuizzerLogger.logWarning('MediaSyncWorker: Local file $localFilePath for upload does not exist, skipping.');
            continue; 
        }
        final Uint8List bytes = await localFile.readAsBytes();
        
        QuizzerLogger.logMessage('MediaSyncWorker: Uploading $fileName to Supabase bucket $_supabaseBucketName.');
        await supabase.storage
            .from(_supabaseBucketName)
            .uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));
        
        QuizzerLogger.logSuccess('MediaSyncWorker: Successfully uploaded $fileName.');

      } on StorageException catch (e) {
        QuizzerLogger.logError('MediaSyncWorker: Supabase StorageException during upload of $fileName: ${e.message} (Code: ${e.statusCode})');
      } catch (e) {
        QuizzerLogger.logError('MediaSyncWorker: Unexpected error during upload of $fileName: $e');
        if (e is! IOException) rethrow;
      }
    }
    QuizzerLogger.logMessage('MediaSyncWorker: Finished brute force _processUploads.');
  }
}
