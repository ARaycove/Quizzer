import 'dart:async';
import 'dart:collection'; // Keep for potential Queue usage if List proves inefficient
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Optional for logging

// ==========================================
// Toggle Scheduler (Corrected - Mirrors DatabaseMonitor)
// ==========================================

/// Manages sequential execution of toggle module activation requests,
/// ensuring only one runs at a time and enforcing a delay between them.
/// Implements the singleton pattern.
/// Logic mirrors DatabaseMonitor.
class ToggleScheduler {
  // --- Singleton Setup ---
  static final ToggleScheduler _instance = ToggleScheduler._internal();
  factory ToggleScheduler() => _instance;
  ToggleScheduler._internal(); // Private constructor
  // --------------------

  // --- State (Mirrors DatabaseMonitor) ---
  bool _isLocked = false;
  final _accessQueue = <Completer<void>>[]; // Using List as FIFO queue
  // --------------------

  /// Requests permission to start a toggle operation.
  ///
  /// If the slot is free, it's granted immediately (returns completed Future).
  /// If busy, the request is queued, and the returned Future completes when the slot becomes available.
  Future<void> requestToggleSlot() {
    if (_isLocked) {
      // Slot is busy, queue the request
      final completer = Completer<void>();
      _accessQueue.add(completer);
      QuizzerLogger.logMessage("ToggleScheduler: Slot busy, request queued.");
      return completer.future; // Caller awaits this
    } else {
      // Slot is free, grant it immediately
      _isLocked = true;
      QuizzerLogger.logMessage("ToggleScheduler: Slot acquired immediately.");
      return Future.value(); // Return an already completed future
    }
  }

  /// Releases the toggle slot after the mandatory delay.
  /// If there are waiting requests, the next one is signaled to proceed.
  Future<void> releaseToggleSlot() async {
    // Introduce mandatory delay BEFORE releasing the slot or signaling next
    await Future.delayed(const Duration(milliseconds: 150)); // Using 90ms as per last version

    if (!_isLocked) {
      QuizzerLogger.logWarning('ToggleScheduler: Attempted to release an already unlocked slot.');
      return;
    }

    if (_accessQueue.isNotEmpty) {
      // If queue has waiting requests, signal the next one by completing its completer.
      // The lock remains held (_isLocked = true).
      final nextCompleter = _accessQueue.removeAt(0); // FIFO removal
      QuizzerLogger.logMessage("ToggleScheduler: Slot released after 100ms delay. Passing to next in queue.");
      nextCompleter.complete(); // Signal the waiting caller
    } else {
      // If queue is empty, release the lock.
      _isLocked = false;
      QuizzerLogger.logMessage("ToggleScheduler: Slot released after 100ms delay. No requests waiting.");
    }
  }
}

// Optional: Global getter function
final ToggleScheduler _toggleScheduler = ToggleScheduler();
ToggleScheduler getToggleScheduler() => _toggleScheduler;
