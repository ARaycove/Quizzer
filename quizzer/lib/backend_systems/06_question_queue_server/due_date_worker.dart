import 'dart:async';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/09_data_caches/due_date_beyond_24hrs_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/due_date_within_24hrs_cache.dart';
import 'package:quizzer/backend_systems/09_data_caches/past_due_cache.dart';

// ==========================================
// Due Date Worker
// ==========================================

class DueDateWorker {
  // --- Singleton Setup ---
  static final DueDateWorker _instance = DueDateWorker._internal();
  factory DueDateWorker() => _instance;
  DueDateWorker._internal();

  // --- State ---
  bool _isRunning = false;
  Completer<void>? _stopCompleter;
  DateTime? _lastWithinScanTime;
  DateTime? _lastBeyondScanTime;

  // --- Cache Dependencies ---
  final DueDateBeyond24hrsCache _dueDateBeyondCache = DueDateBeyond24hrsCache();
  final DueDateWithin24hrsCache _dueDateWithinCache = DueDateWithin24hrsCache();
  final PastDueCache            _pastDueCache       = PastDueCache();

  // --- Constants ---
  // Scan intervals (adjust as needed)
  final Duration _withinScanInterval = const Duration(minutes: 5);
  final Duration _beyondScanInterval = const Duration(hours: 1);
  final Duration _loopSleepInterval  = const Duration(minutes: 1); // How often the loop wakes up

  // --- Control Methods ---
  /// Starts the worker loop.
  void start() {
    try {
      QuizzerLogger.logMessage('Entering DueDateWorker start()...');
      if (_isRunning) {
        QuizzerLogger.logWarning('DueDateWorker already running.');
        return;
      }
      QuizzerLogger.logMessage('Starting DueDateWorker...');
      _isRunning = true;
      _stopCompleter = Completer<void>();
      _lastWithinScanTime = DateTime.now(); // Initialize scan times
      _lastBeyondScanTime = DateTime.now();
      _runLoop();
    } catch (e) {
      QuizzerLogger.logError('Error starting DueDateWorker - $e');
      rethrow;
    }
  }

  /// Stops the worker loop.
  /// Returns a Future that completes when the loop has fully stopped.
  Future<void> stop() async {
    try {
      QuizzerLogger.logMessage('Entering DueDateWorker stop()...');
      if (!_isRunning) {
        QuizzerLogger.logWarning('DueDateWorker is not running.');
        return Future.value();
      }
      QuizzerLogger.logMessage('DueDateWorker stopping...');
      _isRunning = false;
      QuizzerLogger.logMessage('DueDateWorker stopped.');
    } catch (e) {
      QuizzerLogger.logError('Error stopping DueDateWorker - $e');
      rethrow;
    }
  }

  // --- Main Loop ---
  Future<void> _runLoop() async {
    try {
      QuizzerLogger.logMessage('Entering DueDateWorker _runLoop()...');
      QuizzerLogger.logMessage('DueDateWorker loop started.');
      while (_isRunning) {
        final now = DateTime.now();

        // Check if it's time to scan the 'Beyond 24hrs' cache
        if (_lastBeyondScanTime == null || now.difference(_lastBeyondScanTime!) >= _beyondScanInterval) {
          QuizzerLogger.logMessage('DueDateWorker: Scanning DueDateBeyond24hrsCache...');
          await _scanBeyond24HrsCache();
          _lastBeyondScanTime = now;
          if (!_isRunning) break; // Exit loop if stopped during scan
        }

        // Check if it's time to scan the 'Within 24hrs' cache
        if (_lastWithinScanTime == null || now.difference(_lastWithinScanTime!) >= _withinScanInterval) {
          QuizzerLogger.logMessage('DueDateWorker: Scanning DueDateWithin24hrsCache...');
          await _scanWithin24HrsCache();
          _lastWithinScanTime = now;
          if (!_isRunning) break; // Exit loop if stopped during scan
        }

        // Sleep until the next check cycle
        if (_isRunning) {
          // Log only if no scan was performed to avoid spamming logs
          // if (!didScan) {
          //   QuizzerLogger.logMessage('DueDateWorker: Sleeping...');
          // }
          await Future.delayed(_loopSleepInterval);
        }
      }
      _stopCompleter?.complete();
      QuizzerLogger.logMessage('DueDateWorker loop finished.');
    } catch (e) {
      QuizzerLogger.logError('Error in DueDateWorker _runLoop - $e');
      rethrow;
    }
  }

  // --- Scan Logic ---

  /// Scans the DueDateWithin24hrsCache and moves past-due items to PastDueCache.
  Future<void> _scanWithin24HrsCache() async {
    try {
      QuizzerLogger.logMessage('Entering DueDateWorker _scanWithin24HrsCache()...');
      
      // Check if worker should stop before starting scan
      if (!_isRunning) {
        QuizzerLogger.logMessage('DueDateWorker: Stopping scan due to stop command.');
        return;
      }
      
      final List<Map<String, dynamic>> records = await _dueDateWithinCache.peekAllRecords();
      if (!_isRunning || records.isEmpty) {
        QuizzerLogger.logMessage('DueDateWorker: Scan cancelled or no records to process.');
        return;
      }

      final now = DateTime.now();
      final List<String> idsToMove = [];

      for (final record in records) {
        // Check for stop command before processing each record
        if (!_isRunning) {
          QuizzerLogger.logMessage('DueDateWorker: Stopping scan during record processing due to stop command.');
          return;
        }
        
        final dueDateString = record['next_revision_due'] as String?;
        final questionId = record['question_id'] as String?;

        if (dueDateString == null || questionId == null) {
          QuizzerLogger.logWarning('DueDateWorker: Record in DueDateWithin24hrsCache missing required fields: $record');
          continue;
        }

        final parsedDueDate = DateTime.parse(dueDateString);
        if (parsedDueDate.isBefore(now)) {
          idsToMove.add(questionId);
        }
      }

      if (idsToMove.isNotEmpty) {
        QuizzerLogger.logMessage('DueDateWorker: Moving ${idsToMove.length} past-due records from Within24hrs to PastDue...');
        for (final id in idsToMove) {
          // Check for stop command before processing each move operation
          if (!_isRunning) {
            QuizzerLogger.logMessage('DueDateWorker: Stopping scan during move operations due to stop command.');
            return;
          }
          
          // Use the new method to get and remove
          final movedRecord = await _dueDateWithinCache.getAndRemoveRecordByQuestionId(id);
          if (movedRecord.isNotEmpty) {
            await _pastDueCache.addRecord(movedRecord); // Add to destination
          } else {
             // Log if removal failed unexpectedly (record might have been removed by another process)
             QuizzerLogger.logWarning('DueDateWorker: Failed to remove QID $id from DueDateWithin24hrsCache during move to PastDue.');
          }
        }
      }
    } catch (e) {
      QuizzerLogger.logError('Error in DueDateWorker _scanWithin24HrsCache - $e');
      rethrow;
    }
  }

  /// Scans the DueDateBeyond24hrsCache and moves items now within 24hrs to DueDateWithin24hrsCache.
  Future<void> _scanBeyond24HrsCache() async {
    try {
      QuizzerLogger.logMessage('Entering DueDateWorker _scanBeyond24HrsCache()...');
      
      // Check if worker should stop before starting scan
      if (!_isRunning) {
        QuizzerLogger.logMessage('DueDateWorker: Stopping scan due to stop command.');
        return;
      }
      
      final List<Map<String, dynamic>> records = await _dueDateBeyondCache.peekAllRecords();
      if (!_isRunning || records.isEmpty) {
        QuizzerLogger.logMessage('DueDateWorker: Scan cancelled or no records to process.');
        return;
      }

      final twentyFourHoursFromNow = DateTime.now().add(const Duration(hours: 24));
      final List<String> idsToMove = [];

      for (final record in records) {
        // Check for stop command before processing each record
        if (!_isRunning) {
          QuizzerLogger.logMessage('DueDateWorker: Stopping scan during record processing due to stop command.');
          return;
        }
        
        final dueDateString = record['next_revision_due'] as String?;
        final questionId = record['question_id'] as String?;

        if (dueDateString == null || questionId == null) {
          QuizzerLogger.logWarning('DueDateWorker: Record in DueDateBeyond24hrsCache missing required fields: $record');
          continue;
        }

        final parsedDueDate = DateTime.parse(dueDateString);
        // Check if the due date is BEFORE 24 hours from now (meaning it's now within 24 hours)
        if (parsedDueDate.isBefore(twentyFourHoursFromNow)) {
          idsToMove.add(questionId);
        }
      }

      if (idsToMove.isNotEmpty) {
        QuizzerLogger.logMessage('DueDateWorker: Moving ${idsToMove.length} newly near-due records from Beyond24hrs to Within24hrs...');
        for (final id in idsToMove) {
          // Check for stop command before processing each move operation
          if (!_isRunning) {
            QuizzerLogger.logMessage('DueDateWorker: Stopping scan during move operations due to stop command.');
            return;
          }
          
          // Use the new method to get and remove
          final movedRecord = await _dueDateBeyondCache.getAndRemoveRecordByQuestionId(id);
          if (movedRecord.isNotEmpty) {
            await _dueDateWithinCache.addRecord(movedRecord); // Add to destination
          } else {
            // Log if removal failed unexpectedly
            QuizzerLogger.logWarning('DueDateWorker: Failed to remove QID $id from DueDateBeyond24hrsCache during move to Within24hrs.');
          }
        }
      }
    } catch (e) {
      QuizzerLogger.logError('Error in DueDateWorker _scanBeyond24HrsCache - $e');
      rethrow;
    }
  }
}
