import 'package:quizzer/backend_systems/08_memory_retention_algo/memory_retention_algorithm.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Import logger for initialization

/// Tests the memory retention algorithm by calculating and printing results
/// for revision streaks from 0 to 100.
void main() {
  // No async init needed for logger, just call static methods
  QuizzerLogger.logMessage("--- Starting Memory Retention Algorithm Test (Streaks 0-100) ---");

  const String status = 'correct'; // Assume correct answer for testing the curve
  const double initialTimeBetweenRevisions = 0.30; // Default starting value

  // Log table header
  QuizzerLogger.logMessage("Streak | Next Revision Due                    | Days Until Due | Increase | Avg Times Shown/Day");
  QuizzerLogger.logMessage("-------|--------------------------------------|----------------|----------|---------------------");

  final DateTime testStartTime = DateTime.now(); // Use a fixed start time for consistent day calculation
  double previousDaysUntilDue = 0.0; // To track the increase

  for (int streak = 0; streak <= 100; streak++) {
    // Call the function with current streak and default timeBetweenRevisions
    // The called function uses QuizzerLogger internally
    final Map<String, dynamic> results = calculateNextRevisionDate(
      status,
      streak,
      initialTimeBetweenRevisions, 
    );

    // Extract results
    final String nextDueDateStr = results['next_revision_due'] as String;
    final double avgShown = results['average_times_shown_per_day'] as double;
    
    // Calculate days until due
    final DateTime nextDueDate = DateTime.parse(nextDueDateStr);
    final Duration difference = nextDueDate.difference(testStartTime);
    final double daysUntilDue = difference.inMicroseconds / Duration.microsecondsPerDay;

    // Calculate increase from previous iteration
    final double increaseInDays = daysUntilDue - previousDaysUntilDue;

    // Format and print results
    final String streakStr = streak.toString().padLeft(6);
    final String paddedDateStr = nextDueDateStr.padRight(36);
    final String daysUntilDueStr = daysUntilDue.toStringAsFixed(2).padLeft(14);
    final String increaseStr = increaseInDays.toStringAsFixed(2).padLeft(8); // Format increase
    final String avgShownStr = avgShown.toStringAsFixed(6).padLeft(19);
    // Log the data rows
    QuizzerLogger.logMessage("$streakStr | $paddedDateStr | $daysUntilDueStr | $increaseStr | $avgShownStr");

    // Update previous value for next iteration
    previousDaysUntilDue = daysUntilDue;
  }

  QuizzerLogger.logMessage("--- Memory Retention Algorithm Test Complete ---");
} 