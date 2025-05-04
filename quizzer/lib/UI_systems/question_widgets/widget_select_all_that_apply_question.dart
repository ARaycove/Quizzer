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
  // Data passed in
  final List<Map<String, dynamic>> questionElements;
  final List<Map<String, dynamic>> answerElements;
  final List<Map<String, dynamic>> options;
  final List<int> correctIndices; // Original correct indices
  final bool isDisabled;
  
  // Callback
  final VoidCallback onNextQuestion;

  const SelectAllThatApplyQuestionWidget({
    super.key,
    required this.questionElements,
    required this.answerElements,
    required this.options,
    required this.correctIndices,
    required this.onNextQuestion,
    this.isDisabled = false,
  });

  @override
  State<SelectAllThatApplyQuestionWidget> createState() =>
      _SelectAllThatApplyQuestionWidgetState();
}

class _SelectAllThatApplyQuestionWidgetState
    extends State<SelectAllThatApplyQuestionWidget> {
      
  final SessionManager _session = SessionManager(); // Keep for submitAnswer
  
  // Internal state
  List<Map<String, dynamic>> _shuffledOptions = [];
  List<int> _originalIndices = []; 
  Set<int> _selectedShuffledIndices = {}; 
  bool _isAnswerSubmitted = false;

  @override
  void initState() {
    super.initState();
    QuizzerLogger.logMessage("SelectAllThatApplyQuestionWidget initState");
    _loadAndShuffleOptions();
  }

  @override
  void didUpdateWidget(covariant SelectAllThatApplyQuestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.options != oldWidget.options || widget.correctIndices != oldWidget.correctIndices) {
        QuizzerLogger.logMessage("SelectAllThatApplyQuestionWidget didUpdateWidget: Data changed, shuffling.");
        _loadAndShuffleOptions();
    } else {
        QuizzerLogger.logMessage("SelectAllThatApplyQuestionWidget didUpdateWidget: Data same, no shuffle.");
    }
  }

  void _loadAndShuffleOptions() {
    final originalOptions = widget.options;

    if (originalOptions.isEmpty) {
      QuizzerLogger.logWarning("SelectAllThatApplyQuestionWidget: Passed empty options.");
      if (mounted) {
          setState(() { 
             _shuffledOptions = []; _originalIndices = []; 
             _selectedShuffledIndices = {}; _isAnswerSubmitted = false; 
          });
      } else {
             _shuffledOptions = []; _originalIndices = []; 
             _selectedShuffledIndices = {}; _isAnswerSubmitted = false; 
      }
      return;
    }

    List<Map<String, dynamic>> newShuffledOptions;
    List<int> newOriginalIndices;

    if (widget.isDisabled) {
      // If disabled, do not shuffle.
      QuizzerLogger.logMessage("SelectAllThatApplyQuestionWidget: Disabled state, not shuffling.");
      newShuffledOptions = List<Map<String, dynamic>>.from(originalOptions);
      newOriginalIndices = List<int>.generate(originalOptions.length, (i) => i);
    } else {
      // If enabled, shuffle.
      QuizzerLogger.logMessage("SelectAllThatApplyQuestionWidget: Enabled state, shuffling.");
      final List<int> indices = List<int>.generate(originalOptions.length, (i) => i);
      indices.shuffle(Random());
      newShuffledOptions = indices.map((i) => originalOptions[i]).toList();
      newOriginalIndices = indices;
    }
    
    // Determine default selections for disabled preview
    bool shouldAutoSubmit = widget.isDisabled;
    Set<int> defaultSelectedIndices = {};
    if (shouldAutoSubmit) {
      // Find the *shuffled* indices that correspond to the correct *original* indices
      for (int i = 0; i < newOriginalIndices.length; i++) {
         // newOriginalIndices[i] gives the original index for the item at shuffled position i
         if (widget.correctIndices.contains(newOriginalIndices[i])) {
             defaultSelectedIndices.add(i); // Add the shuffled index `i`
         }
      }
      QuizzerLogger.logMessage("SATA: Disabled state, auto-setting submitted=true, selectedIndices(shuffled)=$defaultSelectedIndices for preview.");
    }

    if (mounted) {
      setState(() {
        _shuffledOptions = newShuffledOptions;
        _originalIndices = newOriginalIndices;
        _selectedShuffledIndices = defaultSelectedIndices; // Set selections if disabled
        _isAnswerSubmitted = shouldAutoSubmit; // Set submitted if disabled
      });
    } else {
        _shuffledOptions = newShuffledOptions;
        _originalIndices = newOriginalIndices;
        _selectedShuffledIndices = defaultSelectedIndices;
        _isAnswerSubmitted = shouldAutoSubmit;  
    }
     QuizzerLogger.logValue("SelectAllThatApplyQuestionWidget: Options loaded. Original indices mapping: $_originalIndices"); 
  }

  void _handleOptionToggled(int toggledShuffledIndex) { 
    // Disable interaction if widget is disabled or submitted
    if (widget.isDisabled || _isAnswerSubmitted) return; 

    setState(() {
      if (_selectedShuffledIndices.contains(toggledShuffledIndex)) {
        _selectedShuffledIndices.remove(toggledShuffledIndex);
      } else {
        _selectedShuffledIndices.add(toggledShuffledIndex);
      }
    });
  }

  void _handleSubmitAnswer() {
    // Disable if widget is disabled, already submitted, or nothing selected
    if (widget.isDisabled || _isAnswerSubmitted || _selectedShuffledIndices.isEmpty) return; 

    final List<int> selectedOriginalIndices = _selectedShuffledIndices
        .map((shuffledIndex) => _originalIndices[shuffledIndex])
        .toList();
    selectedOriginalIndices.sort();

    QuizzerLogger.logMessage('Submitting answer. Selected original indices: $selectedOriginalIndices');
    
    setState(() {
      _isAnswerSubmitted = true; 
    });

    try {
      _session.submitAnswer(userAnswer: selectedOriginalIndices); 
      QuizzerLogger.logSuccess('Answer submission initiated (Select All).');
    } catch (e) {
       QuizzerLogger.logError('Sync error submitting answer (Select All): $e');
       setState(() { _isAnswerSubmitted = false; }); // Revert only submission flag
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
    final Set<int> correctOriginalIndices = widget.correctIndices.toSet();

    if (questionElements.isEmpty && _shuffledOptions.isEmpty) {
        return const Center(child: Text("No question data provided.", style: ColorWheel.secondaryTextStyle));
    }

    // Determine if submit button should be shown (only when enabled)
    final bool canSubmit = !widget.isDisabled && _selectedShuffledIndices.isNotEmpty && !_isAnswerSubmitted;

    return SingleChildScrollView(
      child: Padding(
        padding: ColorWheel.standardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Question Elements --- (Uses passed-in questionElements)
            Container(
              padding: ColorWheel.standardPadding,
              decoration: BoxDecoration(color: ColorWheel.secondaryBackground, borderRadius: ColorWheel.cardBorderRadius),
              child: ElementRenderer(elements: questionElements),
            ),
            const SizedBox(height: ColorWheel.majorSectionSpacing),

            // --- Options --- (Uses internal state, but takes correctIndices from widget)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _shuffledOptions.length,
              itemBuilder: (context, index) {
                final optionData = _shuffledOptions[index];
                final int currentOriginalIndex = _originalIndices[index];
                final bool isSelected = _selectedShuffledIndices.contains(index);
                // Use passed-in correctOriginalIndices
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
                } else if (isSelected && !widget.isDisabled) {
                   // Selection phase (before submit)
                   borderColor = ColorWheel.accent;
                   checkboxColor = ColorWheel.accent;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: InkWell(
                    // Disable onTap if isDisabled or submitted
                    onTap: (widget.isDisabled || _isAnswerSubmitted) ? null : () => _handleOptionToggled(index),
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
                            // Disable onChanged if isDisabled or submitted
                            onChanged: (widget.isDisabled || _isAnswerSubmitted) ? null : (bool? value) => _handleOptionToggled(index),
                            activeColor: checkboxColor ?? ColorWheel.accent, 
                            checkColor: ColorWheel.primaryText, 
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
            
            // --- Answer Elements --- (Uses passed-in answerElements)
            if (_isAnswerSubmitted)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Container(
                   padding: ColorWheel.standardPadding,
                   decoration: BoxDecoration(color: ColorWheel.secondaryBackground.withOpacity(0.5), borderRadius: ColorWheel.cardBorderRadius),
                   child: ElementRenderer(elements: widget.answerElements),
                 ),
              ),

            // --- Submit / Next Question Buttons --- 
            // Only show Submit if it *can* be submitted (enabled, options selected, not submitted)
            if (canSubmit) 
              Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: ElevatedButton(
                   style: ElevatedButton.styleFrom(backgroundColor: ColorWheel.buttonSuccess), 
                   // onPressed is implicitly enabled because `canSubmit` is true
                   onPressed: _handleSubmitAnswer, 
                   child: const Text('Submit Answer', style: ColorWheel.buttonTextBold),
                 ),
              ),
              
            // Only show Next if submitted (isDisabled doesn't affect Next button display, only onPressed)
            if (_isAnswerSubmitted) 
               Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: ElevatedButton(
                   style: ElevatedButton.styleFrom(backgroundColor: ColorWheel.buttonSuccess),
                   // Disable onPressed if isDisabled
                   onPressed: widget.isDisabled ? null : _handleNextQuestion,
                   child: const Text('Next Question', style: ColorWheel.buttonText),
                 ),
              ),
          ],
        ),
      ),
    );
  }
}
