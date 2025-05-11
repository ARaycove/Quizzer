import 'dart:math';

// ==========================================

// --- Public Functions ---

/// Calculates the next revision date and average times shown per day based on 
/// answer status, revision streak, and time between revisions.
/// 
/// Returns a map containing:
///   - 'next_revision_due': String (ISO8601 DateTime)
///   - 'average_times_shown_per_day': double
Map<String, dynamic> calculateNextRevisionDate(String status, int revisionStreak, double timeBetweenRevisions) {
  // --- Start Inlined Calculation Logic ---
  // Assertions for input validity
  assert(status.toLowerCase() == 'correct' || status.toLowerCase() == 'incorrect', 'Status must be correct or incorrect');
  assert(revisionStreak >= 0, 'Revision streak cannot be negative');

  // Apply bounds to time_between_revisions
  double k = timeBetweenRevisions; // Use 'k' consistent with formula
  if (k >= 1.0) {
    k = 1.0;
  } else if (k <= 0) {
    k = 0.05; // Value must be above 0
  }

  // Constants from the algorithm
  final int    x = revisionStreak;  // number of repetitions
  const double h = 0;               // horizontal shift
  const double t = 1825.0;         // Maximum length of human memory in days

  // Intermediate calculation for 'g'
  // Note: Original Python implementation had a potential issue in 'g's denominator.
  // This uses the denominator derived directly from 'g's numerator.
  double calcG(double h, double k, double t) {
    final double numG = pow(e, (k * (0 - h))) as double; 
    final double correctDenG = 1 + (numG / t); 
    final double fractionG = numG / correctDenG;
    return -fractionG;
  }

  // Main calculation
  final double numerator = pow(e, (k * (x - h))) as double; 
  final double denominator = 1 + (numerator / t);
  final double fraction = numerator / denominator;

  final double g = calcG(h, k, t);
  final double numberOfDays = fraction + g;
  
  // Average shown calculation
  const double epsilon = 1e-9; // Small value to prevent division by zero
  final double averageShown = (numberOfDays.abs() > epsilon) ? (1.0 / numberOfDays) : 1; 

  // --- End Inlined Calculation Logic ---

  // Determine next_revision_due based on status
  final DateTime now = DateTime.now();
  DateTime nextRevisionDue;

  if (status.toLowerCase() == 'correct') {
    // Calculate duration in microseconds for precision
    final int durationMicroseconds = (numberOfDays * Duration.microsecondsPerDay).round();
    nextRevisionDue = now.add(Duration(microseconds: durationMicroseconds));
  } else { // Handles 'incorrect' case due to assertion above
    // If incorrect, set due immediately
    nextRevisionDue = now;
  }

  final String nextRevisionDueString = nextRevisionDue.toIso8601String();

  // Return the results in a map
  return {
    'next_revision_due': nextRevisionDueString,
    'average_times_shown_per_day': averageShown,
  };
}


