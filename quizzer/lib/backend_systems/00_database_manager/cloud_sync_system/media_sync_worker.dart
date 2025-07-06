import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/media_sync_status_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';
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
  final SessionManager _sessionManager = getSessionManager();
  final String _supabaseBucketName = 'question-answer-pair-assets';
  // --------------------

  // --- Control Methods ---
  /// Starts the worker loop.
  Future<void> start() async {
    QuizzerLogger.logMessage('Entering MediaSyncWorker start()...');
    
    if (_sessionManager.userId == null) {
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
      final bool isConnected = await _checkConnectivity();
      if (!isConnected) {
        QuizzerLogger.logMessage('MediaSyncWorker: No network connectivity, waiting 5 minutes before next attempt...');
        await Future.delayed(const Duration(minutes: 5));
        continue;
      }
      
      // Process NULL media status pairs
      QuizzerLogger.logMessage('MediaSyncWorker: Checking for question pairs with NULL has_media status.');
      await processNullMediaStatusPairs();
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
    await _bruteForceDownloadAllSupabaseMedia();
    await _processUploads();
    if (!_isRunning) return; // Check if worker was stopped during uploads
    await _processDownloads();
    
    QuizzerLogger.logMessage('MediaSyncWorker: _performSync() finished.');
  }

  /// Brute-force download: Download every file in the Supabase bucket if not present locally
  Future<void> _bruteForceDownloadAllSupabaseMedia() async {
    QuizzerLogger.logMessage('MediaSyncWorker: Starting brute-force download of all Supabase media files.');
    if (!_isRunning) {
      QuizzerLogger.logMessage('MediaSyncWorker (_bruteForceDownloadAllSupabaseMedia): Worker stopped before starting.');
      return;
    }
    final supabase = _sessionManager.supabase;
    const String bucketName = 'question-answer-pair-assets';
    final String localAssetBasePath = await getQuizzerMediaPath();

    List<FileObject> files = [];
    try {
      files = await supabase.storage.from(bucketName).list();
    } catch (e) {
      QuizzerLogger.logError('MediaSyncWorker: Failed to list files in Supabase bucket: $e');
      return;
    }

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
  }

  Future<void> _processUploads() async {
    QuizzerLogger.logMessage('MediaSyncWorker: Starting _processUploads.');

    List<Map<String, dynamic>> filesToUpload = await getExistingLocallyNotExternally(); 
    QuizzerLogger.logMessage('MediaSyncWorker (_processUploads): Database access released after reading files to upload.');

    if (filesToUpload.isEmpty) {
      QuizzerLogger.logMessage('MediaSyncWorker: No files found to upload.');
      return;
    }
    QuizzerLogger.logValue('MediaSyncWorker: Found ${filesToUpload.length} files to upload.');

    final supabase = _sessionManager.supabase;

    for (final record in filesToUpload) {
      if (!_isRunning) break;
      final String fileName = record['file_name'] as String;
      final String localAssetBasePath = await getQuizzerMediaPath();
      final String localFilePath = path.join(localAssetBasePath, fileName);

      try {
        final File localFile = File(localFilePath);
        if (!await localFile.exists()) {
            QuizzerLogger.logWarning('MediaSyncWorker: Local file $localFilePath for upload does not exist. Attempting to update DB status.');
            // Rely on db! for fail-fast if db is null.
            await updateMediaSyncStatus(fileName: fileName, existsLocally: false);
            QuizzerLogger.logMessage('MediaSyncWorker (_processUploads): DB access released after updating status for non-existent local file $fileName.');
            continue; 
        }
        final Uint8List bytes = await localFile.readAsBytes();
        
        QuizzerLogger.logMessage('MediaSyncWorker: Uploading $fileName to Supabase bucket $_supabaseBucketName.');
        await supabase.storage
            .from(_supabaseBucketName)
            .uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));
        
        QuizzerLogger.logSuccess('MediaSyncWorker: Successfully uploaded $fileName. Attempting to update DB status.');
        // Rely on db! for fail-fast if db is null.
        await updateMediaSyncStatus(fileName: fileName, existsExternally: true);
        QuizzerLogger.logMessage('MediaSyncWorker (_processUploads): DB access released after updating status for uploaded file $fileName.');

      } on StorageException catch (e) {
        QuizzerLogger.logError('MediaSyncWorker: Supabase StorageException during upload of $fileName: ${e.message} (Code: ${e.statusCode})');
      } catch (e) {
        QuizzerLogger.logError('MediaSyncWorker: Unexpected error during upload of $fileName: $e');
        if (e is! IOException) rethrow;
      }
    }
    QuizzerLogger.logMessage('MediaSyncWorker: Finished _processUploads.');
  }

  Future<void> _processDownloads() async {
    QuizzerLogger.logMessage('MediaSyncWorker: Starting _processDownloads.');

    List<Map<String, dynamic>> filesToDownload = await getExistingExternallyNotLocally(); 
    QuizzerLogger.logMessage('MediaSyncWorker (_processDownloads): Database access released after reading files to download.');

    if (filesToDownload.isEmpty) {
      QuizzerLogger.logMessage('MediaSyncWorker: No files found to download.');
      return;
    }
    QuizzerLogger.logValue('MediaSyncWorker: Found \u001b[1m[0m\u001b[1m[0m\u001b[1m${filesToDownload.length}\u001b[0m files to download.');

    final supabase = _sessionManager.supabase;
    final String localAssetBasePath = await getQuizzerMediaPath();

    for (final record in filesToDownload) {
      if (!_isRunning) break;
      final String fileName = record['file_name'] as String;
      final String localFilePath = path.join(localAssetBasePath, fileName);

      try {
        QuizzerLogger.logMessage('MediaSyncWorker: Downloading $fileName from Supabase bucket $_supabaseBucketName.');
        final Uint8List bytes = await supabase.storage
            .from(_supabaseBucketName)
            .download(fileName);

        final File localFile = File(localFilePath);
        await Directory(path.dirname(localFilePath)).create(recursive: true);
        await localFile.writeAsBytes(bytes);
        
        QuizzerLogger.logSuccess('MediaSyncWorker: Successfully downloaded and saved $fileName. Attempting to update DB status.');
        // Rely on db! for fail-fast if db is null.
        await updateMediaSyncStatus(fileName: fileName, existsLocally: true);
        QuizzerLogger.logMessage('MediaSyncWorker (_processDownloads): DB access released after updating status for downloaded file $fileName.');

      } on StorageException catch (e) {
        if (e.statusCode == '404' || (e.statusCode == '400' && e.message.toLowerCase().contains('not found')) || e.message.toLowerCase().contains('object not found')){
            QuizzerLogger.logWarning('MediaSyncWorker: File $fileName not found in Supabase for download (StorageException: ${e.message}). Attempting to update DB status.');
            // Rely on db! for fail-fast if db is null.
            await updateMediaSyncStatus(fileName: fileName, existsExternally: false);
            QuizzerLogger.logMessage('MediaSyncWorker (_processDownloads): DB access released after updating status for non-existent Supabase file $fileName.');
        } else {
            QuizzerLogger.logError('MediaSyncWorker: Supabase StorageException during download of $fileName: ${e.message} (Code: ${e.statusCode})');
        }
      } catch (e) {
        QuizzerLogger.logError('MediaSyncWorker: Unexpected error during download of $fileName: $e');
        if (e is! IOException) rethrow;
      }
    }
    QuizzerLogger.logMessage('MediaSyncWorker: Finished _processDownloads.');
  }
  // ----------------------

  // --- Network Connectivity Check ---
  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
      QuizzerLogger.logWarning('MediaSyncWorker: Network check failed (lookup empty/no address).');
      return false;
    } on SocketException catch (_) {
      QuizzerLogger.logMessage('MediaSyncWorker: Network check failed (SocketException): Likely offline.');
      return false;
    } catch (e) {
      QuizzerLogger.logError('MediaSyncWorker: Unexpected error during network check: $e');
      return false;
    }
  }
}
