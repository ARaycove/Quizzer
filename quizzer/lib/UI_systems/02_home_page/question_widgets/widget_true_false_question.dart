import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:quizzer/UI_systems/global_widgets/question_answer_element.dart';
import 'dart:math'; // For shuffling

// ==========================================
//    True/False Question Widget
// ==========================================

class TrueFalseQuestionWidget extends StatefulWidget {
  final VoidCallback onNextQuestion;

  const TrueFalseQuestionWidget({
    super.key,
    required this.onNextQuestion,
  });

  @override
  State<TrueFalseQuestionWidget> createState() =>
      _TrueFalseQuestionWidgetState();
}

class _TrueFalseQuestionWidgetState extends State<TrueFalseQuestionWidget> {
  final SessionManager _session = SessionManager();

  // Fixed value convention for True/False indices used by SessionManager
  static const int _trueIndexValue = 0;
  static const int _falseIndexValue = 1;

  // State variables
  bool _isTrueFirst = true; // Determines shuffled order: True then False, or vice-versa
  int? _selectedOptionIndex; // 0 for the first displayed option, 1 for the second
  bool _isAnswerSubmitted = false;

  @override
  void initState() {
    super.initState();
    QuizzerLogger.logMessage("TrueFalseQuestionWidget initState (New Instance)");
    _shuffleOrderAndResetState();
  }

  // Shuffles the order of True/False and resets the widget state
  void _shuffleOrderAndResetState() {
    _isTrueFirst = Random().nextBool(); 
    _selectedOptionIndex = null;
    _isAnswerSubmitted = false;
    QuizzerLogger.logValue("TrueFalseQuestionWidget: Order shuffled and state reset in initState for question ${_session.currentQuestionId}. True first: $_isTrueFirst");
  }

  // Handles selection of either the first or second displayed button
  void _handleOptionSelected(int displayedIndex) { 
    if (_isAnswerSubmitted) return; 

    // Determine the actual value (0 for True, 1 for False) based on shuffle order
    final int submittedValue = (_isTrueFirst && displayedIndex == 0) || (!_isTrueFirst && displayedIndex == 1)
                             ? _trueIndexValue // Selected the button currently showing "True"
                             : _falseIndexValue; // Selected the button currently showing "False"

    QuizzerLogger.logValue('True/False Answer Submitted (Displayed Index: $displayedIndex, Submitted Value: $submittedValue)');

    setState(() {
      _selectedOptionIndex = displayedIndex; // Store which button was pressed (0 or 1)
      _isAnswerSubmitted = true;
    });

    // Submit the actual value (0 or 1) - No await needed
    try {
      _session.submitAnswer(userAnswer: submittedValue);
      QuizzerLogger.logMessage('Answer submission initiated (True/False).');
    } catch (e) {
       QuizzerLogger.logError('Sync error submitting answer (True/False): $e');
       // Optionally revert state or show error
       setState(() { _isAnswerSubmitted = false; _selectedOptionIndex = null; });
       if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error submitting: ${e.toString()}'), backgroundColor: ColorWheel.buttonError),
          );
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    final questionElements = _session.currentQuestionElements;
    final answerElements = _session.currentQuestionAnswerElements; // Corrected getter
    // Correct index is 0 (True) or 1 (False)
    final int? correctValueIndex = _session.currentCorrectOptionIndex; // Corrected getter

    // Validate data
    if (correctValueIndex == null || (correctValueIndex != _trueIndexValue && correctValueIndex != _falseIndexValue)) {
       QuizzerLogger.logError("TrueFalseWidget build: Invalid or missing correct index ($correctValueIndex) for question ${_session.currentQuestionId}.");
       return const Center(child: Text("Error: Question data is incomplete (Invalid True/False index).", style: TextStyle(color: ColorWheel.warning)));
    }

    // Determine which actual value (0/1) corresponds to the selected button index (0/1)
    int? selectedValue = null;
    if (_selectedOptionIndex != null) {
       selectedValue = (_isTrueFirst && _selectedOptionIndex == 0) || (!_isTrueFirst && _selectedOptionIndex == 1)
                       ? _trueIndexValue 
                       : _falseIndexValue;
    }

    // Define options based on shuffled order
    final option1Text = _isTrueFirst ? "True" : "False";
    final option1Value = _isTrueFirst ? _trueIndexValue : _falseIndexValue;
    
    final option2Text = _isTrueFirst ? "False" : "True";
    final option2Value = _isTrueFirst ? _falseIndexValue : _trueIndexValue;

    return Padding(
      padding: const EdgeInsets.all(16.0), // Use consistent padding
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Question Elements
          if (questionElements.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12.0),
              margin: const EdgeInsets.only(bottom: 20.0),
              decoration: BoxDecoration(
                color: ColorWheel.secondaryBackground,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: ElementRenderer(elements: questionElements),
            ),
          if (questionElements.isEmpty)
            const SizedBox(height: 20), 

          // 2. True/False Buttons (Using Expanded for equal width)
          Row(
            children: [
              Expanded(
                child: _buildOptionButton(
                  text: option1Text,
                  displayedIndex: 0, 
                  actualValue: option1Value,
                  selectedValue: selectedValue,
                  correctValue: correctValueIndex,
                  answerElements: answerElements,
                ),
              ),
              const SizedBox(width: 10), // Spacing
              Expanded(
                child: _buildOptionButton(
                  text: option2Text, 
                  displayedIndex: 1, 
                  actualValue: option2Value,
                  selectedValue: selectedValue,
                  correctValue: correctValueIndex,
                  answerElements: answerElements,
                ),
              ),
            ],
          ),
          
          // 3. Explanation Area (now rendered below the *correct* button via _buildOptionButton)
          // This space intentionally left blank as feedback is inside button helper
          const SizedBox(height: 20), 

          // 4. Next Question Button
          if (_isAnswerSubmitted)
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: ElevatedButton(
                // Corrected style definition
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorWheel.buttonSuccess, // Use a success color
                  foregroundColor: ColorWheel.primaryText, // Text color
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: ColorWheel.buttonBorderRadius),
                  minimumSize: const Size(double.infinity, 50), // Make button wide
                ),
                onPressed: widget.onNextQuestion, // Use callback directly
                child: const Text('Next Question'),
              ),
            ),
        ],
      ),
    );
  }

  // Helper widget to build consistent True/False buttons and show feedback/explanation
  Widget _buildOptionButton({
    required String text,
    required int displayedIndex,
    required int actualValue, // 0 or 1
    required int? selectedValue, // 0 or 1 (or null if nothing selected)
    required int correctValue, // 0 or 1 
    required List<Map<String, dynamic>> answerElements,
  }) {
    final bool isSelected = _selectedOptionIndex == displayedIndex;
    final bool isCorrect = actualValue == correctValue;

    Color buttonColor = ColorWheel.secondaryBackground;
    Color textColor = ColorWheel.primaryText;
    IconData? iconData;
    Color iconColor = Colors.transparent;
    bool showExplanationBelow = false;

    if (_isAnswerSubmitted) {
      if (isSelected) {
        buttonColor = isCorrect ? ColorWheel.buttonSuccess : ColorWheel.buttonError;
        textColor = ColorWheel.primaryText; // Keep text readable on colored background
        iconData = isCorrect ? Icons.check_circle : Icons.cancel;
        iconColor = textColor;
        if (isCorrect) showExplanationBelow = true; // Show explanation under correct selection
      } else {
        // Not selected button
        if (isCorrect) {
          // Highlight the correct answer if it wasn't selected
          buttonColor = ColorWheel.buttonSuccess.withOpacity(0.3); // Subtle highlight
          textColor = ColorWheel.primaryText.withOpacity(0.7);
          iconData = Icons.check_circle_outline;
          iconColor = ColorWheel.buttonSuccess;
          showExplanationBelow = true; // Show explanation under the correct answer even if missed
        } else {
          // Dim the incorrect button that wasn't selected
          buttonColor = ColorWheel.secondaryBackground.withOpacity(0.5);
          textColor = ColorWheel.secondaryText;
          // No icon for incorrect & not selected
        }
      }
    } else if (isSelected) {
      // Optional: Indicate selection before submission (very subtle)
      buttonColor = ColorWheel.accent.withOpacity(0.2);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: () => _handleOptionSelected(displayedIndex),
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: textColor, // Text and icon color
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: ColorWheel.buttonBorderRadius),
            elevation: _isAnswerSubmitted && isSelected ? 4 : 1,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                text, 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor)
              ),
              if (_isAnswerSubmitted && iconData != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(iconData, size: 20, color: iconColor),
                ),
            ],
          ),
        ),
        // Conditionally display explanation below this button if needed
        if (showExplanationBelow && answerElements.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10.0), // Space between button and explanation
            child: Container(
               padding: const EdgeInsets.all(12.0),
               decoration: BoxDecoration(
                 color: ColorWheel.secondaryBackground,
                 borderRadius: BorderRadius.circular(8.0),
                 border: Border.all(color: ColorWheel.buttonSuccess.withOpacity(0.5)) // Subtle border for explanation
               ),
               child: ElementRenderer(elements: answerElements)
            ),
          ),
      ],
    );
  }
} 