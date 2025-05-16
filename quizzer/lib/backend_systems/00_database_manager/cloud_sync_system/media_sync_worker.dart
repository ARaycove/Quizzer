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
  // --------------------

  // --- Dependencies ---
  final DatabaseMonitor _dbMonitor = getDatabaseMonitor();
  final SwitchBoard _switchBoard = SwitchBoard();
  final String _supabaseBucketName = 'question-answer-pair-assets';
  final String _localAssetBasePath = path.join('images', 'question_answer_pair_assets');
  // --------------------

  // --- Control Methods ---
  /// Starts the worker loop.
  Future<void> start() async {
    QuizzerLogger.logMessage('Entering MediaSyncWorker start()...');
    if (_isRunning) {
      QuizzerLogger.logMessage('MediaSyncWorker already running.');
      return;
    }
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
    if (!_isRunning || _stopCompleter == null) {
      QuizzerLogger.logMessage('MediaSyncWorker already stopped or stopCompleter is null.');
      return;
    }
    _isRunning = false;

    QuizzerLogger.logMessage('MediaSyncWorker: Unsubscribing from onMediaSyncStatusProcessed stream.');
    await _processingSubscription?.cancel();
    _processingSubscription = null;

    // Signal the loop to stop and wait for it to complete.
    // The loop itself will complete the _stopCompleter.
    if (!_stopCompleter!.isCompleted) {
        // The loop will complete this when it exits.
        QuizzerLogger.logMessage('MediaSyncWorker: Stop signal sent. Waiting for loop to finish...');
    }
     // To ensure the loop wakes up if it's currently awaiting .first
    _switchBoard.signalMediaSyncStatusProcessed(); 
    await _stopCompleter!.future; // Wait for the loop to fully exit
    QuizzerLogger.logMessage('MediaSyncWorker stopped and loop finished.');
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
    // No try-catch here. Errors from _processUploads and _processDownloads will propagate.
    
    await _processUploads();
    if (!_isRunning) return; // Check if worker was stopped during uploads
    await _processDownloads();
    
    QuizzerLogger.logMessage('MediaSyncWorker: _performSync() finished.');
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
      final String localFilePath = path.join(_localAssetBasePath, fileName);

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
    QuizzerLogger.logValue('MediaSyncWorker: Found ${filesToDownload.length} files to download.');

    final supabase = getSessionManager().supabase;

    for (final record in filesToDownload) {
      if (!_isRunning) break;
      final String fileName = record['file_name'] as String;
      final String localFilePath = path.join(_localAssetBasePath, fileName);

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
