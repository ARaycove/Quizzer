import 'dart:math';
import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/global_error_handler.dart';
import 'package:quizzer/app_theme.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // Added for placeholder logging
import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // Import SessionManager

// ==========================================
// Critical Error Screen Widget
// ==========================================

class CriticalErrorScreen extends StatefulWidget {
  // Changed to StatefulWidget
  final CriticalErrorDetails errorDetails;

  const CriticalErrorScreen({super.key, required this.errorDetails});

  @override
  State<CriticalErrorScreen> createState() =>
      _CriticalErrorScreenState(); // Create state
}

class _CriticalErrorScreenState extends State<CriticalErrorScreen> {
  // State class
  final TextEditingController _feedbackController = TextEditingController();
  bool _feedbackSubmitted = false; // State variable to track submission
  int _pokeCount = 0; // For the Easter egg
  int _emojiOverlayCount = 0; // For the emoji overlay
  final Random _random = Random(); // For selecting random messages

  String? _reportedErrorId;
  bool _isReportingInitialError = false;
  bool _isSubmittingFeedback = false;

  static const List<String> _pokeMessages = [
    "Stop poking me!",
    "I already got the feedback, you can restart now.",
    "What you want?",
    "Hmmmmmm?",
    "Me busy. Leave me alone!!",
    "No time for play.",
    "Me not that kind of orc!",
    "Why you poking me again?",
    "Poke, poke, poke - is that all you do?",
    "Stop poking me!",
    "Seriously though...",
    "Ow, that hurts!",
    "Are you not entertained?",
    "This button has feelings, you know.",
    "Do you always press buttons this much?",
    "Oh, that was kind of nice.",
    "Olé!",
    "What'you bother me for?!"
  ];

  @override
  void initState() {
    super.initState();
    _autoReportInitialError(); // Call the auto-reporting method
  }

  Future<void> _autoReportInitialError() async {
    if (!mounted) return;
    setState(() {
      _isReportingInitialError = true;
    });

    QuizzerLogger.logMessage(
        'CriticalErrorScreen: Auto-reporting initial error.');
    String? errorId;
    // No try-catch as per instructions.
    await SessionManager().reportError(
      errorMessage: widget.errorDetails.message,
    );

    if (!mounted) return;
    setState(() {
      _reportedErrorId = errorId;
      _isReportingInitialError = false;
    });
    QuizzerLogger.logSuccess(
        'CriticalErrorScreen: Initial error auto-reported. ID: $_reportedErrorId');
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _handleButtonPress() async {
    if (!mounted) return;

    if (!_feedbackSubmitted) {
      // Check if initial report ID is available
      if (_reportedErrorId == null) {
        QuizzerLogger.logWarning(
            'CriticalErrorScreen: Feedback submission attempted before initial error ID was received.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Initial error report still processing, please wait...'),
            ),
          );
        }
        return;
      }
      // Check if feedback text is empty
      if (_feedbackController.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter your feedback before submitting.'),
            ),
          );
        }
        return;
      }

      setState(() {
        _isSubmittingFeedback = true;
      });

      final String feedbackText = _feedbackController.text;
      QuizzerLogger.logMessage(
          'CriticalErrorScreen: Submitting user feedback for error ID: $_reportedErrorId');

      await SessionManager().reportError(
        id: _reportedErrorId!, // Use the stored ID
        userFeedback: feedbackText,
        // errorMessage and logFile are not needed for an update
      );

      if (!mounted) return;
      setState(() {
        _feedbackSubmitted = true;
        _isSubmittingFeedback = false;
        _feedbackController.clear();
      });
      QuizzerLogger.logSuccess(
          'CriticalErrorScreen: User feedback submitted for ID: $_reportedErrorId.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback sent. Thank you!'),
          ),
        );
      }
    } else {
      // Easter egg: Subsequent pokes
      final randomMessage = _pokeMessages[
          _random.nextInt(_pokeMessages.length)]; // Get message before setState

      setState(() {
        // Single setState to update both pokeCount and emojiOverlayCount
        _pokeCount++;
        if (_pokeCount > 3) {
          _emojiOverlayCount++;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(randomMessage),
          ),
        );
      }
      QuizzerLogger.logMessage(
          'CriticalErrorScreen: Button poked. Count: $_pokeCount, Emoji Overlay Count: $_emojiOverlayCount, Message: "$randomMessage"');
    }
  }

  Color _getPokeButtonColor() {
    if (!_feedbackSubmitted) {
      return Colors.green; // Green before submission
    }

    // After submission (_feedbackSubmitted is true)
    const int maxPokesForRedEffect = 10;
    const Color neonRed = Color.fromRGBO(255, 0, 0, 1.0); // Bright neon red
    const double hueStepForCycle = 30.0;

    if (_pokeCount == 0) {
      return Colors
          .grey; // Neutral grey immediately after submission, before any pokes
    } else if (_pokeCount > 0 && _pokeCount <= maxPokesForRedEffect) {
      // Transition to Neon Red
      // _pokeCount starts at 1 for the first poke after submission
      final double intensity =
          (_pokeCount.toDouble() / maxPokesForRedEffect.toDouble())
              .clamp(0.0, 1.0);
      return Color.lerp(Colors.grey, neonRed, intensity) ?? neonRed;
    } else {
      // Cycle colors after reaching max red intensity
      final int pokesIntoCycle = _pokeCount - maxPokesForRedEffect;
      final double hue = (pokesIntoCycle * hueStepForCycle) % 360.0;
      return HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
    }
  }

  Widget _buildEmojiOverlay() {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return IgnorePointer(
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Wrap(
                spacing: 2.0,
                runSpacing: 2.0,
                children: List.generate(_emojiOverlayCount, (index) {
                  return const Text('👉');
                }),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Critical Application Error'),
        automaticallyImplyLeading: false, // No back button
      ),
      body: Stack(
        // Changed to Stack
        children: <Widget>[
          // Original content layer
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Center(
                    child: Text(
                      'A CRITICAL ERROR HAS OCCURRED AND THE APPLICATION CANNOT CONTINUE.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  AppTheme.sizedBoxLrg,
                  // --- New Detailed Message ---
                  const Text(
                    'We take errors very seriously. In an effort to create an awesome user experience, we choose to tackle internal errors aggressively. Providing good feedback on these errors helps Quizzer do better, faster. Thank you for your patience.',
                    textAlign: TextAlign.center,
                  ),
                  AppTheme.sizedBoxLrg,
                  const Text('Error Message:'),
                  AppTheme.sizedBoxSml,
                  Text(widget.errorDetails.message),
                  AppTheme.sizedBoxLrg,
                  if (widget.errorDetails.error != null) ...[
                    const Text('Exception:'),
                    AppTheme.sizedBoxSml,
                    Text(widget.errorDetails.error.toString()),
                    AppTheme.sizedBoxLrg,
                  ],
                  if (widget.errorDetails.stackTrace != null) ...[
                    const Text('Stack Trace:'),
                    AppTheme.sizedBoxSml,
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: SingleChildScrollView(
                        child: Text(widget.errorDetails.stackTrace.toString()),
                      ),
                    ),
                  ],
                  AppTheme.sizedBoxLrg,
                  const Text(
                    'We apologize for the inconvenience. To help us fix this, please provide any additional details you can and do your best to describe what you were doing before the error occurred:\n providing this feedback ensures we can provide a quick and targeted fix so this doesn\'t happen again',
                    textAlign: TextAlign.left,
                  ),
                  AppTheme.sizedBoxMed,
                  TextField(
                    controller: _feedbackController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText:
                          'e.g., "I was trying to __________ when the app crashed."',
                    ),
                  ),
                  AppTheme.sizedBoxMed,
                  Center(
                    child: ElevatedButton(
                      onPressed:
                          (_isReportingInitialError || _isSubmittingFeedback)
                              ? null
                              : _handleButtonPress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getPokeButtonColor(),
                      ),
                      child: _isSubmittingFeedback
                          ? const CircularProgressIndicator()
                          : Text(
                              _feedbackSubmitted
                                  ? 'Feedback Sent'
                                  : 'Submit Feedback',
                              style: const TextStyle(
                                  inherit: false,
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  AppTheme.sizedBoxLrg,
                  const Text(
                    'Please restart the application. If the problem persists, contact support or submit a bug report through the menu.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          // Emoji overlay layer
          if (_emojiOverlayCount > 0) _buildEmojiOverlay(),
        ],
      ),
    );
  }
}
