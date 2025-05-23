import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';
import 'package:quizzer/backend_systems/10_switch_board/switch_board.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/media_sync_status_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/question_answer_pairs_table.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // For Supabase client
import 'package:supabase/supabase.dart'; // For Supabase storage operations
import 'package:sqflite/sqflite.dart'; // Added for Database type
import 'package:path_provider/path_provider.dart'; // Add this import

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
  Completer<void>? _stopCompleter;
  StreamSubscription? _processingSubscription; // Subscription to SwitchBoard stream
  late Completer<void> _initialSyncCompleter; 

  Future<void> get onInitialSyncComplete => _initialSyncCompleter.future;
  // --------------------

  // --- Dependencies ---
  final DatabaseMonitor _dbMonitor = getDatabaseMonitor();
  final SwitchBoard _switchBoard = SwitchBoard();
  final String _supabaseBucketName = 'question-answer-pair-assets';
  // --------------------

  // --- Control Methods ---
  /// Starts the worker loop.
  Future<void> start() async {
    QuizzerLogger.logMessage('Entering MediaSyncWorker start()...');
    _initialSyncCompleter = Completer<void>(); // Always create a new completer

    if (_isRunning) {
      QuizzerLogger.logWarning('MediaSyncWorker start() called but _isRunning is already true. Proceeding with re-initialization.');
    }

    // Unlike InboundSyncWorker, MediaSyncWorker might not strictly need a userId to perform some initial tasks (e.g. setup local paths)
    // However, most of its useful work (_performSync) will likely depend on SessionManager.supabase being ready.
    // For now, we don't add a userId check here but rely on downstream checks or SessionManager readiness.

    _isRunning = true;
    _stopCompleter = Completer<void>();

    QuizzerLogger.logMessage('MediaSyncWorker: Subscribing to onMediaSyncStatusProcessed stream.');
    _processingSubscription = _switchBoard.onMediaSyncStatusProcessed.listen((_) {
      // Listener body intentionally empty - _runLoop handles the wake-up via .first.
    }, onError: (error) {
       QuizzerLogger.logError('MediaSyncWorker: Error on onMediaSyncStatusProcessed stream: $error');
    });

    _runLoop(); // Start the main loop
    QuizzerLogger.logMessage('MediaSyncWorker started and initial sync performed.');
  }

  /// Stops the worker loop.
  Future<void> stop() async {
    QuizzerLogger.logMessage('Entering MediaSyncWorker stop()...');
    if (!_isRunning) {
      QuizzerLogger.logMessage('MediaSyncWorker: stop() called but worker is not running (or already stopped).');
      // If start() was never fully completed or stop() was already called,
      // _initialSyncCompleter might be null or already completed.
      // Attempt to complete it only if it exists and is not yet completed.
      if (_initialSyncCompleter != null && !_initialSyncCompleter!.isCompleted) {
        // Changed from completeError to complete to avoid unhandled exceptions if not caught by caller.
        _initialSyncCompleter!.complete(); 
        QuizzerLogger.logMessage('MediaSyncWorker: _initialSyncCompleter force-completed (normally) as worker was stopped before fully running.');
      }
      return;
    }

    _isRunning = false; // Signal loop to stop FIRST

    QuizzerLogger.logMessage('MediaSyncWorker: Unsubscribing from onMediaSyncStatusProcessed stream.');
    await _processingSubscription?.cancel();
    _processingSubscription = null;

    // To ensure the loop wakes up if it's currently awaiting .first, and then sees _isRunning = false
    _switchBoard.signalMediaSyncStatusProcessed(); 
    
    // Wait for the loop to fully exit by awaiting the _stopCompleter that _runLoop completes.
    if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
        QuizzerLogger.logMessage('MediaSyncWorker: stop() waiting for _runLoop to complete _stopCompleter...');
        await _stopCompleter!.future; 
    }

    // At this point, the loop has exited.
    // _initialSyncCompleter is guaranteed to be non-null here because _isRunning was true when stop() was entered.
    // If the initial sync (or any part of it that _initialSyncCompleter represents) was ongoing 
    // and not completed, signal that it was gracefully concluded due to worker stop.
    if (!_initialSyncCompleter!.isCompleted) {
        // Changed from completeError to complete.
        _initialSyncCompleter!.complete(); 
        QuizzerLogger.logMessage('MediaSyncWorker: _initialSyncCompleter force-completed (normally) because worker was stopped.');
    }
    
    QuizzerLogger.logMessage('MediaSyncWorker: stop() processing complete, loop finished.');
  }
  // ----------------------

  // --- Main Loop ---
  Future<void> _runLoop() async {
    QuizzerLogger.logMessage('Entering MediaSyncWorker _runLoop()...');
    while (_isRunning) {
      

      if (!_isRunning) break; // Check if stopped while waiting


      QuizzerLogger.logMessage('MediaSyncWorker: Checking for question pairs with NULL has_media status.');
      Database? db = await _dbMonitor.requestDatabaseAccess();
      
      // Call the new centralized function from question_answer_pairs_table.dart
      // The db! is safe here due to the Fail Fast nature if db acquisition fails.
      // processNullMediaStatusPairs itself handles logging and the loop.
      await processNullMediaStatusPairs(db!);
      
      _dbMonitor.releaseDatabaseAccess();
      QuizzerLogger.logMessage('MediaSyncWorker: Database access released after processing NULL has_media records.');
      

      if (!_isRunning) break; // Check if stopped during NULL media processing

      QuizzerLogger.logMessage('MediaSyncWorker: Signal received, performing sync actions...');
      await _performSync(); // Call the main sync logic

      // Optional: Add a small delay if signals can come in rapid succession 
      // and you want to batch or prevent tight loops, though .first handles distinct events.
      // await Future.delayed(const Duration(milliseconds: 100)); 

      if (!_isRunning) break; // Check if stopped during sync
      
      QuizzerLogger.logMessage('MediaSyncWorker: Waiting for media sync status processed signal...');
      // Wait indefinitely for the next signal from the onMediaSyncStatusProcessed stream
      await _switchBoard.onMediaSyncStatusProcessed.first;
    }

    if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
      _stopCompleter!.complete();
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

  // Helper to get the writable asset base path
  Future<String> _getLocalAssetBasePath() async {
    Directory dir;
    if (Platform.isIOS || Platform.isAndroid) {
      dir = await getApplicationDocumentsDirectory();
      QuizzerLogger.logMessage('MediaSyncWorker: Using Documents directory for media assets (Mobile).');
    } else { // Desktop platforms (Windows, Linux, macOS)
      dir = await getApplicationSupportDirectory();
      QuizzerLogger.logMessage('MediaSyncWorker: Using Application Support directory for media assets (Desktop).');
    }
    final String fullPath = path.join(dir.path, 'QuizzerAppMedia', 'question_answer_pair_assets');
    QuizzerLogger.logMessage('MediaSyncWorker: Local media asset base path set to: $fullPath');
    return fullPath;
  }

  /// Brute-force download: Download every file in the Supabase bucket if not present locally
  Future<void> _bruteForceDownloadAllSupabaseMedia() async {
    QuizzerLogger.logMessage('MediaSyncWorker: Starting brute-force download of all Supabase media files.');
    if (!_isRunning) {
      QuizzerLogger.logMessage('MediaSyncWorker (_bruteForceDownloadAllSupabaseMedia): Worker stopped before starting.');
      return;
    }
    final supabase = getSessionManager().supabase;
    const String bucketName = 'question-answer-pair-assets';
    final String localAssetBasePath = await _getLocalAssetBasePath();

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
    
    Database? db = await _dbMonitor.requestDatabaseAccess();
    // Rely on db! for fail-fast if db is null, as per user's expectation.

    List<Map<String, dynamic>> filesToUpload = await getExistingLocallyNotExternally(db!); 
    _dbMonitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('MediaSyncWorker (_processUploads): Database access released after reading files to upload.');

    if (filesToUpload.isEmpty) {
      QuizzerLogger.logMessage('MediaSyncWorker: No files found to upload.');
      return;
    }
    QuizzerLogger.logValue('MediaSyncWorker: Found ${filesToUpload.length} files to upload.');

    final supabase = getSessionManager().supabase;

    for (final record in filesToUpload) {
      if (!_isRunning) break;
      final String fileName = record['file_name'] as String;
      final String localAssetBasePath = await _getLocalAssetBasePath();
      final String localFilePath = path.join(localAssetBasePath, fileName);

      try {
        final File localFile = File(localFilePath);
        if (!await localFile.exists()) {
            QuizzerLogger.logWarning('MediaSyncWorker: Local file $localFilePath for upload does not exist. Attempting to update DB status.');
            db = await _dbMonitor.requestDatabaseAccess();
            // Rely on db! for fail-fast if db is null.
            await updateMediaSyncStatus(db: db!, fileName: fileName, existsLocally: false);
            _dbMonitor.releaseDatabaseAccess();
            QuizzerLogger.logMessage('MediaSyncWorker (_processUploads): DB access released after updating status for non-existent local file $fileName.');
            continue; 
        }
        final Uint8List bytes = await localFile.readAsBytes();
        
        QuizzerLogger.logMessage('MediaSyncWorker: Uploading $fileName to Supabase bucket $_supabaseBucketName.');
        await supabase.storage
            .from(_supabaseBucketName)
            .uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));
        
        QuizzerLogger.logSuccess('MediaSyncWorker: Successfully uploaded $fileName. Attempting to update DB status.');
        db = await _dbMonitor.requestDatabaseAccess();
        // Rely on db! for fail-fast if db is null.
        await updateMediaSyncStatus(db: db!, fileName: fileName, existsExternally: true);
        _dbMonitor.releaseDatabaseAccess();
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

    Database? db = await _dbMonitor.requestDatabaseAccess();
    // Rely on db! for fail-fast if db is null.

    List<Map<String, dynamic>> filesToDownload = await getExistingExternallyNotLocally(db!); 
    _dbMonitor.releaseDatabaseAccess();
    QuizzerLogger.logMessage('MediaSyncWorker (_processDownloads): Database access released after reading files to download.');

    if (filesToDownload.isEmpty) {
      QuizzerLogger.logMessage('MediaSyncWorker: No files found to download.');
      return;
    }
    QuizzerLogger.logValue('MediaSyncWorker: Found \u001b[1m[0m[1m[0m[1m${filesToDownload.length}\u001b[0m files to download.');

    final supabase = getSessionManager().supabase;
    final String localAssetBasePath = await _getLocalAssetBasePath();

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
        db = await _dbMonitor.requestDatabaseAccess();
        // Rely on db! for fail-fast if db is null.
        await updateMediaSyncStatus(db: db!, fileName: fileName, existsLocally: true);
        _dbMonitor.releaseDatabaseAccess();
        QuizzerLogger.logMessage('MediaSyncWorker (_processDownloads): DB access released after updating status for downloaded file $fileName.');

      } on StorageException catch (e) {
        if (e.statusCode == '404' || (e.statusCode == '400' && e.message.toLowerCase().contains('not found')) || e.message.toLowerCase().contains('object not found')){
            QuizzerLogger.logWarning('MediaSyncWorker: File $fileName not found in Supabase for download (StorageException: ${e.message}). Attempting to update DB status.');
            db = await _dbMonitor.requestDatabaseAccess();
            // Rely on db! for fail-fast if db is null.
            await updateMediaSyncStatus(db: db!, fileName: fileName, existsExternally: false);
            _dbMonitor.releaseDatabaseAccess();
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
}
