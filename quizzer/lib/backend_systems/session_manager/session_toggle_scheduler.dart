import 'dart:async';
import 'dart:collection'; // Needed for Queue
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

// ==========================================
// Toggle Scheduler (Simple Throttle)
// ==========================================

/// Manages sequential execution of toggle module activation requests,
/// ensuring only one runs at a time and enforcing a small delay between them.
/// Implements the singleton pattern.
class ToggleScheduler {
  // --- Singleton Setup ---
  static final ToggleScheduler _instance = ToggleScheduler._internal();
  factory ToggleScheduler() => _instance;
  ToggleScheduler._internal(); // Private constructor
  // --------------------

  // --- State ---
  bool _isLocked = false;
  final _requestQueue = Queue<Completer<void>>(); // Simple queue of completers
  // REMOVED: _ToggleRequest? _currentlyProcessing;
  // --------------------

  /// Requests permission to start a toggle operation.
  ///
  /// Queues the request if busy, or grants the slot immediately if free.
  Future<void> requestToggleSlot() { // Parameters removed
    final completer = Completer<void>();

    if (_isLocked) {
      // Slot busy, queue the completer
      _requestQueue.add(completer);
      QuizzerLogger.logMessage("ToggleScheduler: Slot busy, request queued. Queue size: ${_requestQueue.length}");
    } else {
      // Slot free, grant immediately
      _isLocked = true;
      QuizzerLogger.logMessage("ToggleScheduler: Slot acquired immediately.");
      completer.complete(); // Complete immediately
    }
    return completer.future;
  }

  /// Releases the toggle slot after the mandatory delay.
  /// If there are waiting requests, the next one is signaled to proceed.
  Future<void> releaseToggleSlot() async {
    // Introduce mandatory delay BEFORE releasing the slot or signaling next
    const int delayMilliseconds = 1; // Reverted delay
    await Future.delayed(const Duration(milliseconds: delayMilliseconds));

    if (!_isLocked) {
      QuizzerLogger.logWarning('ToggleScheduler: Attempted to release an already unlocked slot.');
      return;
    }

    // REMOVED: final _ToggleRequest? justProcessed = _currentlyProcessing;

    if (_requestQueue.isNotEmpty) {
      // If queue has waiting requests, signal the next one.
      final nextCompleter = _requestQueue.removeFirst(); // Dequeue completer
      // Lock remains held (_isLocked = true). No need to track _currentlyProcessing
      QuizzerLogger.logMessage("ToggleScheduler: Slot released after ${delayMilliseconds}ms delay. Passing to next in queue. Queue size: ${_requestQueue.length}");
      nextCompleter.complete(); // Signal the waiting caller
    } else {
      // If queue is empty, release the lock.
      _isLocked = false;
      QuizzerLogger.logMessage("ToggleScheduler: Slot released after ${delayMilliseconds}ms delay. No requests waiting.");
    }
  }
}

// Global getter remains the same
final ToggleScheduler _toggleScheduler = ToggleScheduler();
ToggleScheduler getToggleScheduler() => _toggleScheduler;
