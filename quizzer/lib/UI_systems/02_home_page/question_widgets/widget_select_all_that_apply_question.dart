import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'dart:math';
import 'package:quizzer/UI_systems/global_widgets/question_answer_element.dart';

// ==========================================
//  Select All That Apply Question Widget
// ==========================================

class SelectAllThatApplyQuestionWidget extends StatefulWidget {
  final VoidCallback onNextQuestion;

  const SelectAllThatApplyQuestionWidget({
    super.key,
    required this.onNextQuestion,
  });

  @override
  State<SelectAllThatApplyQuestionWidget> createState() =>
      _SelectAllThatApplyQuestionWidgetState();
}

class _SelectAllThatApplyQuestionWidgetState
    extends State<SelectAllThatApplyQuestionWidget> {
  final SessionManager _session = SessionManager();
  
  List<Map<String, dynamic>> _shuffledOptions = [];
  List<int> _originalIndices = []; // Map shuffled index back to original index
  Set<int> _selectedShuffledIndices = {}; // Indices *in the shuffled list*
  bool _isAnswerSubmitted = false;

  @override
  void initState() {
    super.initState();
    QuizzerLogger.logMessage("SelectAllThatApplyQuestionWidget initState (New Instance)");
    _loadAndShuffleOptions();
  }

  void _loadAndShuffleOptions() {
    final originalOptions = _session.currentQuestionOptions;

    if (originalOptions.isEmpty) {
      QuizzerLogger.logWarning("SelectAllThatApplyQuestionWidget: No options found for question ${_session.currentQuestionId}.");
      // Set state to empty
       _shuffledOptions = [];
       _originalIndices = [];
       _selectedShuffledIndices = {};
       _isAnswerSubmitted = false;
       return;
    }

    final List<int> indices = List<int>.generate(originalOptions.length, (i) => i);
    final random = Random();
    indices.shuffle(random);

    // Directly set state variables in initState
    _shuffledOptions = indices.map((i) => originalOptions[i]).toList();
    _originalIndices = indices;
    _selectedShuffledIndices = {}; // Reset selections
    _isAnswerSubmitted = false;   // Reset submission status
    QuizzerLogger.logValue("SelectAllThatApplyQuestionWidget: Options shuffled in initState for question ${_session.currentQuestionId}. Original indices order: $_originalIndices");
  }

  void _handleOptionToggled(int toggledShuffledIndex) { 
    if (_isAnswerSubmitted) return; // Don't allow changes after submission

    setState(() {
      if (_selectedShuffledIndices.contains(toggledShuffledIndex)) {
        _selectedShuffledIndices.remove(toggledShuffledIndex);
      } else {
        _selectedShuffledIndices.add(toggledShuffledIndex);
      }
    });
  }

  void _handleSubmitAnswer() {
    if (_isAnswerSubmitted || _selectedShuffledIndices.isEmpty) return; 

    // Convert selected *shuffled* indices back to *original* indices
    final List<int> selectedOriginalIndices = _selectedShuffledIndices
        .map((shuffledIndex) => _originalIndices[shuffledIndex])
        .toList();
    selectedOriginalIndices.sort(); // Ensure consistent order for comparison/logging

    QuizzerLogger.logMessage('Submitting answer. Selected original indices: $selectedOriginalIndices');
    
    setState(() {
      _isAnswerSubmitted = true; // Lock selections, show feedback/next button
    });

    // Submit the list of original indices (fire-and-forget)
    try {
      _session.submitAnswer(userAnswer: selectedOriginalIndices); 
      QuizzerLogger.logSuccess('Answer submission initiated (Select All).');
    } catch (e) {
       QuizzerLogger.logError('Sync error submitting answer (Select All): $e');
       // Revert state on sync error during the call itself
       setState(() {
         _isAnswerSubmitted = false; 
       });
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting: ${e.toString()}'), backgroundColor: ColorWheel.buttonError),
        );
    }
  }

  void _handleNextQuestion() {
    widget.onNextQuestion(); 
  }

  @override
  Widget build(BuildContext context) {
    final questionElements = _session.currentQuestionElements;
    final answerElements = _session.currentQuestionAnswerElements;
    // Correct indices are the *original* indices
    final Set<int> correctOriginalIndices = _session.currentCorrectIndices.toSet();

    if (questionElements.isEmpty && _shuffledOptions.isEmpty) {
        return const Center(child: Text("No question loaded.", style: ColorWheel.secondaryTextStyle));
    }

    final bool canSubmit = _selectedShuffledIndices.isNotEmpty && !_isAnswerSubmitted;

    return SingleChildScrollView(
      child: Padding(
        padding: ColorWheel.standardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Question Elements ---
            Container(
              padding: ColorWheel.standardPadding,
              decoration: BoxDecoration(color: ColorWheel.secondaryBackground, borderRadius: ColorWheel.cardBorderRadius),
              child: ElementRenderer(elements: questionElements),
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
                final bool isSelected = _selectedShuffledIndices.contains(index);
                final bool isCorrect = correctOriginalIndices.contains(currentOriginalIndex);
                
                // Declare variables outside the if blocks for broader scope
                IconData? icon;
                Color iconColor = Colors.transparent; // Default to transparent
                Color borderColor = Colors.transparent;
                Color? checkboxColor; // Color for the check mark itself

                if (_isAnswerSubmitted) {
                   // Feedback phase
                   if (isSelected) {
                      // Correct & Selected: Green border, green check icon
                      borderColor = ColorWheel.buttonSuccess;
                      checkboxColor = ColorWheel.buttonSuccess;
                   } else if (isCorrect) {
                      // Correct & NOT Selected: Mark with RED border as an error
                      borderColor = ColorWheel.buttonError; 
                   } else {
                      // Incorrect & NOT Selected: Keep neutral
                      borderColor = Colors.transparent;
                   }
                   // Separate logic for the trailing icon based on all states
                   if (isCorrect && isSelected) {
                     icon = Icons.check_circle; 
                     iconColor = ColorWheel.buttonSuccess;
                   } else if (isCorrect && !isSelected) {
                     // Correct but not selected - User Error - Show something? Maybe outline?
                     icon = Icons.check_circle_outline; // Keep outline check to show it *was* correct
                     iconColor = ColorWheel.buttonError; // But make the icon RED
                   } else if (!isCorrect && isSelected) {
                     icon = Icons.cancel; 
                     iconColor = ColorWheel.buttonError;
                   }
                   // else: !isCorrect && !isSelected -> icon = null, iconColor = transparent (handled by default)
                } else if (isSelected) {
                   // Selection phase (before submit)
                   borderColor = ColorWheel.accent;
                   checkboxColor = ColorWheel.accent;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: InkWell(
                    onTap: () => _handleOptionToggled(index),
                    borderRadius: ColorWheel.buttonBorderRadius,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: ColorWheel.secondaryBackground, 
                        borderRadius: ColorWheel.buttonBorderRadius,
                        border: Border.all(color: borderColor, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: _isAnswerSubmitted ? null : (bool? value) => _handleOptionToggled(index),
                            activeColor: checkboxColor ?? ColorWheel.accent, 
                            checkColor: ColorWheel.primaryText, 
                            // Use the border color logic for the checkbox side when submitted
                            side: BorderSide(color: _isAnswerSubmitted ? borderColor : ColorWheel.secondaryText), 
                          ),
                          const SizedBox(width: ColorWheel.relatedElementSpacing / 2),
                          Expanded(child: ElementRenderer(elements: [optionData])), 
                          // Use the icon determined by the logic above
                           if (_isAnswerSubmitted && icon != null)
                             Icon(icon, color: iconColor, size: 20)
                           else if (_isAnswerSubmitted) // Ensure alignment if no icon is shown
                             const SizedBox(width: 20), 
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: ColorWheel.majorSectionSpacing / 2),
            
            // --- Answer Elements (Show After Submission) ---
            if (_isAnswerSubmitted)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Container(
                   padding: ColorWheel.standardPadding,
                   decoration: BoxDecoration(color: ColorWheel.secondaryBackground.withOpacity(0.5), borderRadius: ColorWheel.cardBorderRadius),
                   child: ElementRenderer(elements: answerElements),
                 ),
              ),

            // --- Submit / Next Question Buttons ---
            if (canSubmit) // Show Submit button if options are selected and not yet submitted
              Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: ElevatedButton(
                   style: ElevatedButton.styleFrom(backgroundColor: ColorWheel.buttonSuccess), // Use accent or success?
                   onPressed: _handleSubmitAnswer,
                   child: const Text('Submit Answer', style: ColorWheel.buttonTextBold),
                 ),
              ),
              
            if (_isAnswerSubmitted) // Show Next button after submission
               Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: ElevatedButton(
                   style: ElevatedButton.styleFrom(backgroundColor: ColorWheel.buttonSuccess),
                   onPressed: _handleNextQuestion,
                   child: const Text('Next Question', style: ColorWheel.buttonText),
                 ),
              ),
          ],
        ),
      ),
    );
  }
}
