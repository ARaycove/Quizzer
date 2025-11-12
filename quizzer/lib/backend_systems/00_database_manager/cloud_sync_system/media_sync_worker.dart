import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/10_switch_board/sb_sync_worker_signals.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/media_sync_status_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pair_management/question_answer_pairs_table.dart';
import 'package:supabase/supabase.dart'; // For Supabase storage operations
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/ml_models_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';

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
    final List<String> serverFiles = await _bruteForceDownloadAllSupabaseMedia();
    await _processUploads(serverFiles);
    if (!_isRunning) return; // Check if worker was stopped during uploads
    await _processDownloads();
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
    final supabase = _sessionManager.supabase;
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

    final supabase = _sessionManager.supabase;

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
  Future<void> updateMlModels() async {
    final models = await getAllMlModels();
    
    for (final model in models) {
      final modelName = model['model_name'] as String;
      final lastSynced = model['time_last_received_file'] as String?;
      final lastModified = model['last_modified_timestamp'] as String?;
      
      if (lastModified == null) continue;
      
      final lastModifiedDate = DateTime.parse(lastModified);
      final lastSyncedDate = lastSynced != null ? DateTime.parse(lastSynced) : null;
      
      if (lastSyncedDate != null && !lastModifiedDate.isAfter(lastSyncedDate)) continue;
      
      final supabase = getSessionManager().supabase;
      final fileName = '$modelName.tflite';
      
      final Uint8List modelFileData;      
      try {
        modelFileData = await supabase.storage.from('ml_models').download(fileName);
      } on StorageException catch (e) {
        QuizzerLogger.logWarning('Storage error downloading model $modelName: ${e.message}');
        return;
      } on SocketException catch (e) {
        QuizzerLogger.logWarning('Network error downloading model $modelName: $e');
        return;
      }
      
      final localPath = path.join(await getQuizzerMediaPath(), fileName);
      await Directory(path.dirname(localPath)).create(recursive: true);
      await File(localPath).writeAsBytes(modelFileData);
      
      final db = await getDatabaseMonitor().requestDatabaseAccess();
      await db!.update(
        'ml_models',
        {'time_last_received_file': DateTime.now().toUtc().toIso8601String()},
        where: 'model_name = ?',
        whereArgs: [modelName],
      );
      getDatabaseMonitor().releaseDatabaseAccess();
      
      QuizzerLogger.logSuccess('Updated ML model: $modelName');
    }
  }

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
