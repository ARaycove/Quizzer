import 'package:flutter/material.dart';
import 'dart:math';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/global_widgets/question_answer_element.dart';
import 'package:quizzer/app_theme.dart';

// ==========================================
//     True/False Question Widget
// ==========================================

class TrueFalseQuestionWidget extends StatefulWidget {
  // Data passed in
  final List<Map<String, dynamic>> questionElements;
  final List<Map<String, dynamic>> answerElements;
  final bool isCorrectAnswerTrue; // True if the correct answer is 'True'
  final bool isDisabled;

  // New optional parameters for state control
  final List<int>? customOrderIndices; // If provided, use this order instead of shuffling (for True/False, this controls which comes first)
  final bool autoSubmitAnswer; // If true, automatically submit answer
  final bool? selectedAnswer; // Must be provided if autoSubmitAnswer is true
  
  // Callback
  final VoidCallback onNextQuestion;

  const TrueFalseQuestionWidget({
    super.key,
    required this.questionElements,
    required this.answerElements,
    required this.isCorrectAnswerTrue,
    required this.onNextQuestion,
    this.isDisabled = false,
    this.customOrderIndices, // Optional custom order
    this.autoSubmitAnswer = false, // Default to false
    this.selectedAnswer, // Optional selected answer
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
        widget.isCorrectAnswerTrue != oldWidget.isCorrectAnswerTrue ||
        widget.customOrderIndices != oldWidget.customOrderIndices ||
        widget.autoSubmitAnswer != oldWidget.autoSubmitAnswer ||
        widget.selectedAnswer != oldWidget.selectedAnswer) {
       QuizzerLogger.logMessage("TrueFalseQuestionWidget didUpdateWidget: Data changed, resetting.");
      _shuffleOrderAndResetState();
    } else {
       QuizzerLogger.logMessage("TrueFalseQuestionWidget didUpdateWidget: Data same, no reset.");
    }
  }

  void _shuffleOrderAndResetState() {
    bool shouldShuffle = !widget.isDisabled && widget.customOrderIndices == null;
    bool shouldAutoSubmit = widget.isDisabled || widget.autoSubmitAnswer;
    
    // Determine the order of True/False buttons
    bool isTrueFirst;
    if (widget.autoSubmitAnswer && _session.lastSubmittedUserAnswer != null) {
      // For True/False, we don't need custom order indices, just use default order
      isTrueFirst = true; // Default order for answered state
      QuizzerLogger.logMessage("TrueFalseWidget: Using SessionManager data for auto-submit.");
    } else if (widget.customOrderIndices != null) {
      // Use custom order if provided (for True/False, this determines which comes first)
      // customOrderIndices[0] == 0 means True first, customOrderIndices[0] == 1 means False first
      isTrueFirst = widget.customOrderIndices![0] == 0;
      QuizzerLogger.logMessage("TrueFalseWidget: Using custom order indices: ${widget.customOrderIndices}");
    } else if (widget.isDisabled) {
      isTrueFirst = true; // Default order for disabled state
    } else {
      isTrueFirst = Random().nextBool(); // Random order for enabled state
    }
    
    // Set selected state for disabled preview or auto submit
    bool? defaultSelectedAnswer;
    if (shouldAutoSubmit) {
      if (widget.autoSubmitAnswer && _session.lastSubmittedUserAnswer != null) {
        // Use the submitted answer from SessionManager
        defaultSelectedAnswer = _session.lastSubmittedUserAnswer as bool;
      } else if (widget.selectedAnswer != null) {
        defaultSelectedAnswer = widget.selectedAnswer;
      } else {
        defaultSelectedAnswer = widget.isCorrectAnswerTrue; // Fallback to correct answer
      }
    }
    
    if (mounted) {
       setState(() {
         _selectedAnswer = defaultSelectedAnswer;
         _isAnswerSubmitted = shouldAutoSubmit; // Set submitted if disabled
         _isTrueFirst = isTrueFirst; 
         QuizzerLogger.logValue("TF Widget Reset. ShouldShuffle: $shouldShuffle, IsTrueFirst: $_isTrueFirst, AutoSubmit: $shouldAutoSubmit");
       });
    } else {
         _selectedAnswer = defaultSelectedAnswer;
         _isAnswerSubmitted = shouldAutoSubmit;
         _isTrueFirst = isTrueFirst; 
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
      // Set all submission data in SessionManager BEFORE calling submitAnswer
      // For True/False, we don't need custom order indices, but set empty list for consistency
      _session.setCurrentQuestionCustomOrderIndices([]);
      _session.setCurrentQuestionUserAnswer(selectedValue);
      
      // Determine correctness and set it
      final bool isCorrect = selectedValue == widget.isCorrectAnswerTrue;
      _session.setCurrentQuestionIsCorrect(isCorrect);
      
      // Now call submitAnswer
      _session.submitAnswer(userAnswer: selectedValue); 
      QuizzerLogger.logSuccess('Answer submission initiated (True/False).');
    } catch (e) {
      QuizzerLogger.logError('Sync error submitting answer (True/False): $e');
      setState(() {
        _isAnswerSubmitted = false;
        _selectedAnswer = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting: ${e.toString()}')),
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
        return const Center(child: Text("No question data provided."));
    }

    // Buttons are built by the helper
    final trueButton = _buildOptionButton(context, true, isCorrectAnswerTrue);
    final falseButton = _buildOptionButton(context, false, isCorrectAnswerTrue);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Question Elements --- (Uses passed-in questionElements)
          ElementRenderer(elements: questionElements),
          AppTheme.sizedBoxLrg,

          // --- True/False Buttons --- (Place in a Row)
          Row(
            children: [
              // Use Expanded to make buttons take equal width
              Expanded(child: _isTrueFirst ? trueButton : falseButton),
              AppTheme.sizedBoxSml,
              Expanded(child: _isTrueFirst ? falseButton : trueButton),
            ],
          ),
          
          // --- Answer Elements --- (Uses passed-in answerElements)
          // Display explanation ONLY under the correct answer button after submission
          // We achieve this by adding the explanation conditionally *outside* the Row,
          // checking which button was correct.
          if (_isAnswerSubmitted && answerElements.isNotEmpty)
            ElementRenderer(elements: answerElements),
              
          AppTheme.sizedBoxLrg,

          // --- Next Question Button ---
          if (_isAnswerSubmitted)
            ElevatedButton(
              onPressed: widget.isDisabled ? null : _handleNextQuestion, 
              child: const Text('Next Question'),
            ),
        ],
      ),
    );
  }

  // Helper builds button using InkWell + Container for more control
  Widget _buildOptionButton(BuildContext context, bool value, bool isCorrectValue) {
    final bool isSelected = _selectedAnswer == value;
    final bool isCorrect = value == isCorrectValue;
    
    // PRESERVE functional feedback colors for correctness states
    // These colors communicate correctness to users after submission
    const Color correctColor = Colors.green;
    const Color incorrectColor = Colors.red;
    
    // Determine Styling based on state
    Color bgColor = Colors.transparent; // Default background
    Color fgColor = Colors.transparent; // Default text/icon color
    Color borderColor = Colors.transparent;
    IconData? icon;
    
    // Determine visual feedback state
     if (_isAnswerSubmitted) {
       if (isSelected) {
         bgColor = isCorrect ? correctColor.withValues(alpha: 0.1) : incorrectColor.withValues(alpha: 0.1);
         borderColor = isCorrect ? correctColor : incorrectColor;
         icon = isCorrect ? Icons.check_circle : Icons.cancel;
         fgColor = isCorrect ? correctColor : incorrectColor; // Icon color matches border
       } else if (isCorrect) {
         // Highlight the correct answer if it wasn't selected
         bgColor = correctColor.withValues(alpha: 0.05); // 0.05 opacity
         borderColor = correctColor.withValues(alpha: 0.5); // 0.5 opacity
         icon = Icons.check_circle_outline;
         fgColor = correctColor; // Icon color matches border
       } else {
         // Dim incorrect, unselected option
          bgColor = Colors.transparent;
          fgColor = Colors.transparent;
          borderColor = Colors.transparent;
       }
     } else if (isSelected && !widget.isDisabled) { 
         // Highlight selection before submission (if enabled)
         bgColor = correctColor.withValues(alpha: 0.1);
         borderColor = correctColor;
         fgColor = correctColor; // Icon/text color matches border
     } // Add hover effect potentially via MouseRegion later if needed

    return InkWell(
      onTap: (widget.isDisabled || _isAnswerSubmitted) ? null : () => _handleSelection(value),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: borderColor != Colors.transparent ? Border.all(color: borderColor) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon, color: fgColor), 
            Text(value ? 'True' : 'False'),
          ],
        ),
      ),
    );
  }
} 