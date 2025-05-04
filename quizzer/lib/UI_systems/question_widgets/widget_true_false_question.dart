import 'package:flutter/material.dart';
import 'dart:math';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:quizzer/UI_systems/global_widgets/question_answer_element.dart';

// ==========================================
//     True/False Question Widget
// ==========================================

class TrueFalseQuestionWidget extends StatefulWidget {
  // Data passed in
  final List<Map<String, dynamic>> questionElements;
  final List<Map<String, dynamic>> answerElements;
  final bool isCorrectAnswerTrue; // True if the correct answer is 'True'
  final bool isDisabled;

  // Callback
  final VoidCallback onNextQuestion;

  const TrueFalseQuestionWidget({
    super.key,
    required this.questionElements,
    required this.answerElements,
    required this.isCorrectAnswerTrue,
    required this.onNextQuestion,
    this.isDisabled = false,
  });

  @override
  State<TrueFalseQuestionWidget> createState() => _TrueFalseQuestionWidgetState();
}

class _TrueFalseQuestionWidgetState extends State<TrueFalseQuestionWidget> {
  final SessionManager _session = SessionManager(); // Keep for submitAnswer

  // Internal state
  bool? _selectedAnswer; // null = not selected, true = True, false = False
  bool _isAnswerSubmitted = false;
  bool _isTrueFirst = true; // Controls display order, maybe affected by isDisabled

  @override
  void initState() {
    super.initState();
    QuizzerLogger.logMessage("TrueFalseQuestionWidget initState");
    _shuffleOrderAndResetState();
  }

  @override
  void didUpdateWidget(covariant TrueFalseQuestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.questionElements != oldWidget.questionElements ||
        widget.isCorrectAnswerTrue != oldWidget.isCorrectAnswerTrue) {
       QuizzerLogger.logMessage("TrueFalseQuestionWidget didUpdateWidget: Data changed, resetting.");
      _shuffleOrderAndResetState();
    } else {
       QuizzerLogger.logMessage("TrueFalseQuestionWidget didUpdateWidget: Data same, no reset.");
    }
  }

  void _shuffleOrderAndResetState() {
    bool shouldShuffle = !widget.isDisabled;
    bool shouldAutoSubmit = widget.isDisabled;
    // Set selected state for disabled preview
    bool? defaultSelectedAnswer = shouldAutoSubmit ? widget.isCorrectAnswerTrue : null;
    
    if (mounted) {
       setState(() {
         _selectedAnswer = defaultSelectedAnswer;
         _isAnswerSubmitted = shouldAutoSubmit; // Set submitted if disabled
         _isTrueFirst = widget.isDisabled ? true : Random().nextBool(); 
         QuizzerLogger.logValue("TF Widget Reset. ShouldShuffle: $shouldShuffle, IsTrueFirst: $_isTrueFirst, AutoSubmit: $shouldAutoSubmit");
       });
    } else {
         _selectedAnswer = defaultSelectedAnswer;
         _isAnswerSubmitted = shouldAutoSubmit;
         _isTrueFirst = widget.isDisabled ? true : Random().nextBool(); 
         QuizzerLogger.logValue("TF Widget Init. ShouldShuffle: $shouldShuffle, IsTrueFirst: $_isTrueFirst, AutoSubmit: $shouldAutoSubmit");
    }
  }

  Future<void> _handleSelection(bool selectedValue) async {
    if (widget.isDisabled || _isAnswerSubmitted) return;

    QuizzerLogger.logMessage('Selection made: $selectedValue. Submitting answer...');
    setState(() {
      _selectedAnswer = selectedValue;
      _isAnswerSubmitted = true;
    });

    try {
      // Pass boolean directly to session manager
      _session.submitAnswer(userAnswer: selectedValue); 
      QuizzerLogger.logSuccess('Answer submission initiated (True/False).');
    } catch (e) {
      QuizzerLogger.logError('Sync error submitting answer (True/False): $e');
      setState(() {
        _isAnswerSubmitted = false;
        _selectedAnswer = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting: ${e.toString()}'), backgroundColor: ColorWheel.buttonError),
      );
    }
  }

  void _handleNextQuestion() {
    if (widget.isDisabled) return;
    widget.onNextQuestion();
  }

  @override
  Widget build(BuildContext context) {
    // Use passed-in data
    final questionElements = widget.questionElements;
    final answerElements = widget.answerElements;
    final bool isCorrectAnswerTrue = widget.isCorrectAnswerTrue;
    
    if (questionElements.isEmpty) {
        return const Center(child: Text("No question data provided.", style: ColorWheel.secondaryTextStyle));
    }

    // Buttons are built by the helper
    final trueButton = _buildOptionButton(context, true, isCorrectAnswerTrue);
    final falseButton = _buildOptionButton(context, false, isCorrectAnswerTrue);

    return SingleChildScrollView(
      child: Padding(
        padding: ColorWheel.standardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Question Elements --- (Uses passed-in questionElements)
            Container(
              padding: ColorWheel.standardPadding,
              decoration: BoxDecoration(
                color: ColorWheel.secondaryBackground,
                borderRadius: ColorWheel.cardBorderRadius,
              ),
              child: ElementRenderer(elements: questionElements),
            ),
            const SizedBox(height: ColorWheel.majorSectionSpacing),

            // --- True/False Buttons --- (Place in a Row)
            Row(
              children: [
                // Use Expanded to make buttons take equal width
                Expanded(child: _isTrueFirst ? trueButton : falseButton),
                const SizedBox(width: 16.0), // Spacing between buttons
                Expanded(child: _isTrueFirst ? falseButton : trueButton),
              ],
            ),
            
            // --- Answer Elements --- (Uses passed-in answerElements)
            // Display explanation ONLY under the correct answer button after submission
            // We achieve this by adding the explanation conditionally *outside* the Row,
            // checking which button was correct.
            if (_isAnswerSubmitted && answerElements.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: ColorWheel.relatedElementSpacing),
                  child: Container(
                    padding: ColorWheel.standardPadding,
                    decoration: BoxDecoration(
                      color: ColorWheel.secondaryBackground.withOpacity(0.5),
                      borderRadius: ColorWheel.cardBorderRadius,
                    ),
                    child: ElementRenderer(elements: answerElements),
                  ),
              ),
              
            const SizedBox(height: ColorWheel.majorSectionSpacing),

            // --- Next Question Button ---
            if (_isAnswerSubmitted)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorWheel.buttonSuccess,
                  padding: const EdgeInsets.symmetric(vertical: ColorWheel.standardPaddingValue),
                  shape: RoundedRectangleBorder(borderRadius: ColorWheel.buttonBorderRadius),
                ),
                onPressed: widget.isDisabled ? null : _handleNextQuestion, 
                child: const Text('Next Question', style: ColorWheel.buttonText),
              ),
          ],
        ),
      ),
    );
  }

  // Helper builds button using InkWell + Container for more control
  Widget _buildOptionButton(BuildContext context, bool value, bool isCorrectValue) {
    final bool isSelected = _selectedAnswer == value;
    final bool isCorrect = value == isCorrectValue;
    
    // Determine Styling based on state
    Color bgColor = ColorWheel.secondaryBackground; // Default background
    Color fgColor = ColorWheel.primaryText; // Default text/icon color
    Color borderColor = Colors.transparent;
    double elevation = 0; // Use BoxShadow instead for InkWell/Container
    IconData? icon;
    
    // Determine visual feedback state
     if (_isAnswerSubmitted) {
       if (isSelected) {
         bgColor = isCorrect ? ColorWheel.buttonSuccess.withOpacity(0.1) : ColorWheel.buttonError.withOpacity(0.1);
         borderColor = isCorrect ? ColorWheel.buttonSuccess : ColorWheel.buttonError;
         icon = isCorrect ? Icons.check_circle : Icons.cancel;
         fgColor = isCorrect ? ColorWheel.buttonSuccess : ColorWheel.buttonError; // Icon color matches border
       } else if (isCorrect) {
         // Highlight the correct answer if it wasn't selected
         bgColor = ColorWheel.buttonSuccess.withOpacity(0.05);
         borderColor = ColorWheel.buttonSuccess.withOpacity(0.5);
         icon = Icons.check_circle_outline;
         fgColor = ColorWheel.buttonSuccess; // Icon color matches border
       } else {
         // Dim incorrect, unselected option
          bgColor = ColorWheel.secondaryBackground.withOpacity(0.6);
          fgColor = ColorWheel.secondaryText;
          borderColor = Colors.transparent;
       }
     } else if (isSelected && !widget.isDisabled) { 
         // Highlight selection before submission (if enabled)
         bgColor = ColorWheel.accent.withOpacity(0.1);
         borderColor = ColorWheel.accent;
         fgColor = ColorWheel.accent; // Icon/text color matches border
     } // Add hover effect potentially via MouseRegion later if needed

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0), // Keep vertical padding
      child: InkWell(
        onTap: (widget.isDisabled || _isAnswerSubmitted) ? null : () => _handleSelection(value),
        borderRadius: ColorWheel.buttonBorderRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0), // Consistent padding
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: ColorWheel.buttonBorderRadius,
            border: Border.all(color: borderColor, width: 1.5),
            // boxShadow: elevation > 0 ? [BoxShadow(...)] : null, // Optional shadow
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  // Use fgColor for icon color as it's determined by state
                  child: Icon(icon, size: 20, color: fgColor), 
                ),
              Text(
                value ? 'True' : 'False',
                // Text color should generally remain readable, not change drastically with feedback
                style: const TextStyle( 
                   fontSize: 16,
                   fontWeight: FontWeight.w500,
                   color: ColorWheel.primaryText, // Keep text primarily white
                 ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 