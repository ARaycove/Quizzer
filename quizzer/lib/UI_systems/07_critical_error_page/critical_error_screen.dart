import 'dart:math'; // For Random
import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/global_error_handler.dart'; 
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Added for placeholder logging

// ==========================================
// Critical Error Screen Widget
// ==========================================

class CriticalErrorScreen extends StatefulWidget { // Changed to StatefulWidget
  final CriticalErrorDetails errorDetails;

  const CriticalErrorScreen({super.key, required this.errorDetails});

  @override
  State<CriticalErrorScreen> createState() => _CriticalErrorScreenState(); // Create state
}

class _CriticalErrorScreenState extends State<CriticalErrorScreen> { // State class
  final TextEditingController _feedbackController = TextEditingController();
  bool _feedbackSubmitted = false; // State variable to track submission
  int _pokeCount = 0; // For the Easter egg
  final Random _random = Random(); // For selecting random messages

  static const List<String> _pokeMessages = [
    "Stop poking me!",
    "I already got the feedback, you can restart now.",
    "Seriously though...",
    "Ow, that hurts!",
    "Are you not entertained?",
    "This button has feelings, you know.",
    "Okay, one more poke and I'm calling HR.",
    "Do you always poke buttons this much?",
    "Don't poke the button anymore!!"
  ];

  @override
  void initState() {
    super.initState();
    // Placeholder: Simulate sending logs to server
    QuizzerLogger.logMessage('CriticalErrorScreen: Initialized. Placeholder: Attempting to send quizzer_log.txt to server.');
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _handleButtonPress() {
    if (!_feedbackSubmitted) {
      // Initial feedback submission
      setState(() {
        _feedbackSubmitted = true; 
      });

      final feedbackText = _feedbackController.text;
      QuizzerLogger.logMessage('CriticalErrorScreen: User feedback submitted: "$feedbackText"');
      // Placeholder: Actual logic to send feedback to the server will go here.
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: ColorWheel.buttonSuccess,
          ),
        );
      }
    } else {
      // Easter egg: Subsequent pokes
      setState(() {
        _pokeCount++;
      });
      final randomMessage = _pokeMessages[_random.nextInt(_pokeMessages.length)];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(randomMessage),
            backgroundColor: ColorWheel.secondaryBackground, // More neutral SnackBar color for pokes
          ),
        );
      }
      QuizzerLogger.logMessage('CriticalErrorScreen: Button poked. Count: $_pokeCount, Message: "$randomMessage"');
    }
  }

  Color _getPokeButtonColor() {
    if (!_feedbackSubmitted) {
      return ColorWheel.buttonSuccess; // Green before submission
    }
    // After submission (_feedbackSubmitted is true)
    if (_pokeCount == 0) {
      return ColorWheel.secondaryText; // Neutral grey after first submission, before any pokes
    }
    // Easter egg: Color intensifies with pokes
    const int maxPokesForColorEffect = 10;
    final double baseIntensity = (_pokeCount / maxPokesForColorEffect).clamp(0.0, 1.0);
    // Start from grey and lerp towards red
    return Color.lerp(ColorWheel.secondaryText, ColorWheel.buttonError, baseIntensity) ?? ColorWheel.buttonError;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorWheel.primaryBackground,
      appBar: AppBar(
        title: const Text('Critical Application Error'),
        backgroundColor: ColorWheel.buttonError,
        automaticallyImplyLeading: false, // No back button
      ),
      body: Center( // Wrapped with Center to help with alignment if content overflows
        child: SingleChildScrollView( // Added SingleChildScrollView for smaller screens
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding( // Add padding to ensure centering and space around the main title
                padding: EdgeInsets.only(bottom: 20.0), // Space below the title
                child: Center( // Center the main title
                  child: Text(
                    'A CRITICAL ERROR HAS OCCURRED AND THE APPLICATION CANNOT CONTINUE.', // ALL CAPS
                    style: TextStyle(
                      color: ColorWheel.primaryText,
                      fontSize: 22, // Increased font size
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              // --- New Detailed Message --- 
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0), // Space below this new message
                child: Text(
                  'We take errors very seriously. In an effort to create an awesome user experience, we choose to tackle internal errors aggressively. Providing good feedback on these errors helps Quizzer do better, faster. Thank you for your patience.',
                  style: TextStyle(
                    color: ColorWheel.primaryText.withAlpha((0.85 * 255).round()), // Corrected use of withAlpha
                    fontSize: 16, 
                  ),
                  textAlign: TextAlign.center, // Center this message as well
                ),
              ),
              // --- End New Detailed Message ---
              const Text(
                'Error Message:',
                style: TextStyle(
                  color: ColorWheel.secondaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.errorDetails.message, // Use widget.errorDetails
                style: const TextStyle(color: ColorWheel.primaryText, fontSize: 16),
              ),
              const SizedBox(height: 20),
              if (widget.errorDetails.error != null) ...[ // Use widget.errorDetails
                const Text(
                  'Exception:',
                  style: TextStyle(
                    color: ColorWheel.secondaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.errorDetails.error.toString(), // Use widget.errorDetails
                  style: const TextStyle(color: ColorWheel.primaryText, fontSize: 14),
                ),
                const SizedBox(height: 20),
              ],
              if (widget.errorDetails.stackTrace != null) ...[ // Use widget.errorDetails
                const Text(
                  'Stack Trace:',
                  style: TextStyle(
                    color: ColorWheel.secondaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                // Allow stack trace to take up available space but be scrollable
                // If other content is minimal, this could be large. Consider a maxHeight.
                ConstrainedBox( // Wrap with ConstrainedBox
                  constraints: const BoxConstraints(
                    maxHeight: 150, // Set maxHeight here
                  ),
                  child: SizedBox( // SizedBox can still be useful for width or if other constraints are needed
                    child: SingleChildScrollView(
                      child: Text(
                        widget.errorDetails.stackTrace.toString(), // Use widget.errorDetails
                        style: const TextStyle(color: ColorWheel.secondaryText, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'We apologize for the inconvenience. To help us fix this, please provide any additional details you can and do your best to describe what you were doing before the error occurred:\n providing this feedback ensures we can provide a quick and targeted fix so this doesn\'t happen again',
                style: TextStyle(color: ColorWheel.primaryText, fontSize: 16),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _feedbackController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g., "I was trying to log out when the app crashed."',
                  hintStyle: TextStyle(color: ColorWheel.hintText.withOpacity(0.7)),
                  filled: true,
                  fillColor: ColorWheel.textInputBackground,
                  border: OutlineInputBorder(
                    borderRadius: ColorWheel.buttonBorderRadius,
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: ColorWheel.inputText),
              ),
              const SizedBox(height: 15),
              Center( // Center the button
                child: ElevatedButton(
                  onPressed: _handleButtonPress, // Unified handler
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getPokeButtonColor(), // Dynamic color
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: ColorWheel.buttonBorderRadius,
                    ),
                  ),
                  child: Text(
                    _feedbackSubmitted ? 'Feedback Sent' : 'Submit Feedback', // Subtle text
                    style: ColorWheel.buttonText
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Please restart the application. If the problem persists, contact support.',
                style: TextStyle(color: ColorWheel.warning, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 