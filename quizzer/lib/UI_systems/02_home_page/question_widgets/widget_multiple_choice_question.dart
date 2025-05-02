import 'dart:io'; // Keep for potential future use if ElementRenderer needs it
import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'dart:math'; // For shuffling
// Import the shared ElementRenderer
import 'package:quizzer/UI_systems/global_widgets/question_answer_element.dart'; 

// ==========================================
//    Multiple Choice Question Widget
// ==========================================
//  Local ElementRenderer definition REMOVED 

class MultipleChoiceQuestionWidget extends StatefulWidget {
  // Callback to inform HomePage to request the next question
  final VoidCallback onNextQuestion; 

  const MultipleChoiceQuestionWidget({
    super.key,
    required this.onNextQuestion, // Add callback requirement
  });

  @override
  State<MultipleChoiceQuestionWidget> createState() =>
      _MultipleChoiceQuestionWidgetState();
}

// --- State ---

class _MultipleChoiceQuestionWidgetState
    extends State<MultipleChoiceQuestionWidget> {
      
  final SessionManager _session = SessionManager();
  
  // State variables for the widget
  List<Map<String, dynamic>> _shuffledOptions = [];
  List<int> _originalIndices = []; // Map shuffled index back to original index
  int? _selectedOptionIndex; // Index *in the shuffled list* that was selected
  bool _isAnswerSubmitted = false;

  @override
  void initState() {
    super.initState();
    QuizzerLogger.logMessage("MultipleChoiceQuestionWidget initState (New Instance)");
    _loadAndShuffleOptions();
  }

  void _loadAndShuffleOptions() {
    final originalOptions = _session.currentQuestionOptions;

    if (originalOptions.isEmpty) {
       QuizzerLogger.logWarning("MultipleChoiceQuestionWidget: No options found for question ${_session.currentQuestionId}.");
       setState(() {
         _shuffledOptions = [];
         _originalIndices = [];
         _selectedOptionIndex = null;
         _isAnswerSubmitted = false;
       });
       return;
    }

    final List<int> indices = List<int>.generate(originalOptions.length, (i) => i);
    final random = Random();
    indices.shuffle(random);
    final newShuffledOptions = indices.map((i) => originalOptions[i]).toList();
    
    _shuffledOptions = newShuffledOptions;
    _originalIndices = indices; 
    _selectedOptionIndex = null; 
    _isAnswerSubmitted = false;  
    QuizzerLogger.logValue("MultipleChoiceQuestionWidget: Options shuffled in initState for question ${_session.currentQuestionId}. Original indices order: $_originalIndices");
  }

  Future<void> _handleOptionSelected(int selectedShuffledIndex) async { 
    if (_isAnswerSubmitted) return; // Prevent re-submission

    // Map the selected shuffled index back to its original index
    final int originalIndex = _originalIndices[selectedShuffledIndex];

    QuizzerLogger.logMessage('Option selected (shuffled index: $selectedShuffledIndex, original index: $originalIndex). Submitting answer...');
    
    setState(() {
      _selectedOptionIndex = selectedShuffledIndex; // Store the index *from the shuffled list*
      _isAnswerSubmitted = true;
    });

    // Submit the *original* index to the session manager without awaiting
    try {
      /*await*/ _session.submitAnswer(userAnswer: originalIndex); // Removed await
      QuizzerLogger.logSuccess('Answer submission initiated to SessionManager.'); 
    } catch (e) {
       QuizzerLogger.logError('Synchronous error during submitAnswer call: $e'); 
       // Optionally revert state or show error to user if the *initiation* fails
       setState(() {
         _isAnswerSubmitted = false; 
         _selectedOptionIndex = null;
       });
       if(mounted) { // Check if widget is still in the tree
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error initiating answer submission: ${e.toString()}'), 
              backgroundColor: ColorWheel.buttonError,
            ),
          );
       }
    }
  }

  void _handleNextQuestion() {
    QuizzerLogger.logMessage("Next Question button tapped.");
    widget.onNextQuestion(); 
  }


  @override
  Widget build(BuildContext context) {
    QuizzerLogger.logValue("MultipleChoiceQuestionWidget building. Submitted: $_isAnswerSubmitted, Selected Shuffled Index: $_selectedOptionIndex");

    final questionElements = _session.currentQuestionElements;
    final answerElements = _session.currentQuestionAnswerElements;
    final int? correctOriginalIndex = _session.currentCorrectOptionIndex; 
    
    if (_shuffledOptions.isEmpty && questionElements.isEmpty) {
       QuizzerLogger.logWarning("MultipleChoiceQuestionWidget build: No elements or options available. Displaying error/empty state.");
       return const Center(child: Text("No question loaded or question data is empty.", style: TextStyle(color: ColorWheel.secondaryText)));
    }

    if (correctOriginalIndex == null) {
        QuizzerLogger.logError("MultipleChoiceQuestionWidget build: correctOriginalIndex is null for question ${_session.currentQuestionId}. Cannot determine correctness.");
        return const Center(child: Text("Error: Question data is incomplete (missing correct index).", style: TextStyle(color: ColorWheel.warning)));
    }

    // --- Render UI ---
    const Color correctColor = ColorWheel.buttonSuccess;
    const Color incorrectColor = ColorWheel.buttonError;
    const Color defaultOptionBgColor = ColorWheel.secondaryBackground;
    const Color selectedOptionBorderColor = ColorWheel.accent;

    return SingleChildScrollView(
      child: Padding(
        padding: ColorWheel.standardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Question Elements ---
            Container(
              padding: ColorWheel.standardPadding,
              decoration: BoxDecoration(
                color: ColorWheel.secondaryBackground,
                borderRadius: ColorWheel.cardBorderRadius,
              ),
              child: ElementRenderer(elements: questionElements), // Uses the global renderer
            ),
            const SizedBox(height: ColorWheel.majorSectionSpacing),

            // --- Options ---
            ListView.builder(
              shrinkWrap: true, 
              physics: const NeverScrollableScrollPhysics(), 
              itemCount: _shuffledOptions.length,
              itemBuilder: (context, index) {
                final optionData = _shuffledOptions[index]; 
                final int currentOriginalIndex = _originalIndices[index]; 
                
                final bool isSelected = _selectedOptionIndex == index;
                final bool isCorrect = currentOriginalIndex == correctOriginalIndex;
                
                Color optionBgColor = defaultOptionBgColor;
                Color borderColor = Colors.transparent;
                IconData? trailingIcon;
                bool showAnswerForThisOption = false;

                if (_isAnswerSubmitted) {
                  if (isSelected) {
                    borderColor = isCorrect ? correctColor : incorrectColor;
                    optionBgColor = isCorrect ? correctColor.withOpacity(0.1) : incorrectColor.withOpacity(0.1);
                    trailingIcon = isCorrect ? Icons.check_circle : Icons.cancel;
                    if(isCorrect) showAnswerForThisOption = true; 
                  } else if (isCorrect) {
                     optionBgColor = correctColor.withOpacity(0.1);
                     trailingIcon = Icons.check_circle_outline;
                     showAnswerForThisOption = true; 
                  }
                } else if (isSelected) {
                  // This case might not be visually needed anymore if selection instantly triggers submission state
                  borderColor = selectedOptionBorderColor;
                  optionBgColor = selectedOptionBorderColor.withOpacity(0.1);
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: InkWell(
                    onTap: () => _handleOptionSelected(index), 
                    borderRadius: ColorWheel.buttonBorderRadius,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        color: optionBgColor,
                        borderRadius: ColorWheel.buttonBorderRadius,
                        border: Border.all(color: borderColor, width: 1.5),
                      ),
                      child: Column( 
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: _isAnswerSubmitted 
                                       ? (isCorrect ? correctColor : (isSelected ? incorrectColor : ColorWheel.secondaryText)) 
                                       : (isSelected ? selectedOptionBorderColor : ColorWheel.primaryText),
                                size: 20,
                              ),
                              const SizedBox(width: ColorWheel.relatedElementSpacing),
                              // Use ElementRenderer for the option content itself
                              Expanded(child: ElementRenderer(elements: [optionData])), // Use global renderer
                              if (_isAnswerSubmitted && trailingIcon != null)
                                Icon(trailingIcon, color: isCorrect ? correctColor : (isSelected ? incorrectColor : ColorWheel.secondaryText)),
                            ],
                          ),
                          // --- Display Answer Elements ---
                          if (_isAnswerSubmitted && showAnswerForThisOption)
                            Padding(
                              padding: const EdgeInsets.only(top: ColorWheel.relatedElementSpacing, left: 32.0), 
                              child: ElementRenderer(elements: answerElements), // Use global renderer
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: ColorWheel.majorSectionSpacing),

            // --- Next Question Button ---
            if (_isAnswerSubmitted)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorWheel.buttonSuccess,
                  padding: const EdgeInsets.symmetric(vertical: ColorWheel.standardPaddingValue),
                  shape: RoundedRectangleBorder(
                    borderRadius: ColorWheel.buttonBorderRadius,
                  ),
                ),
                onPressed: _handleNextQuestion,
                child: const Text('Next Question', style: ColorWheel.buttonText),
              ),
          ],
        ),
      ),
    );
  }
}
