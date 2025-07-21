import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'dart:math';
import 'package:quizzer/UI_systems/global_widgets/question_answer_element.dart';
import 'package:collection/collection.dart';
import 'package:quizzer/app_theme.dart';

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
  
  // New optional parameters for state control
  final List<int>? customOrderIndices; // If provided, use this order instead of shuffling
  final bool autoSubmitAnswer; // If true, automatically submit answer
  final List<int>? selectedIndices; // Must be provided if autoSubmitAnswer is true
  
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
    this.customOrderIndices, // Optional custom order
    this.autoSubmitAnswer = false, // Default to false
    this.selectedIndices, // Optional selected indices
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
    if (widget.options != oldWidget.options || 
        widget.correctIndices != oldWidget.correctIndices ||
        widget.customOrderIndices != oldWidget.customOrderIndices ||
        widget.autoSubmitAnswer != oldWidget.autoSubmitAnswer ||
        widget.selectedIndices != oldWidget.selectedIndices) {
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

    // Check if we should use SessionManager data for answered state
    if (widget.autoSubmitAnswer && _session.lastSubmittedUserAnswer != null) {
      // Use the custom order from SessionManager if available
      if (_session.lastSubmittedCustomOrderIndices != null) {
        QuizzerLogger.logMessage("SelectAllThatApplyQuestionWidget: Using SessionManager custom order indices: ${_session.lastSubmittedCustomOrderIndices}");
        newOriginalIndices = List<int>.from(_session.lastSubmittedCustomOrderIndices!);
        newShuffledOptions = newOriginalIndices.map((i) => originalOptions[i]).toList();
      } else {
        // Fallback to original order if no custom order stored
        QuizzerLogger.logMessage("SelectAllThatApplyQuestionWidget: No custom order in SessionManager, using original order.");
        newShuffledOptions = List<Map<String, dynamic>>.from(originalOptions);
        newOriginalIndices = List<int>.generate(originalOptions.length, (i) => i);
      }
    } else if (widget.customOrderIndices != null) {
      // Use custom order if provided
      QuizzerLogger.logMessage("SelectAllThatApplyQuestionWidget: Using custom order indices: ${widget.customOrderIndices}");
      newOriginalIndices = List<int>.from(widget.customOrderIndices!);
      newShuffledOptions = newOriginalIndices.map((i) => originalOptions[i]).toList();
    } else if (widget.isDisabled) {
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
    
    // Determine default selections for disabled preview or auto submit
    bool shouldAutoSubmit = widget.isDisabled || widget.autoSubmitAnswer;
    Set<int> defaultSelectedIndices = {};
    if (shouldAutoSubmit) {
      if (widget.autoSubmitAnswer && _session.lastSubmittedUserAnswer != null) {
        // Use the submitted answer from SessionManager
        final submittedAnswers = _session.lastSubmittedUserAnswer as List<int>;
        for (int selectedOriginalIndex in submittedAnswers) {
          int shuffledIndex = newOriginalIndices.indexOf(selectedOriginalIndex);
          if (shuffledIndex != -1) {
            defaultSelectedIndices.add(shuffledIndex);
          }
        }
      } else if (widget.selectedIndices != null) {
        // Use the provided selected indices (find their positions in the current order)
        for (int selectedOriginalIndex in widget.selectedIndices!) {
          int shuffledIndex = newOriginalIndices.indexOf(selectedOriginalIndex);
          if (shuffledIndex != -1) {
            defaultSelectedIndices.add(shuffledIndex);
          }
        }
      } else {
        // Fallback to correct indices if no selected indices provided
        for (int i = 0; i < newOriginalIndices.length; i++) {
           // newOriginalIndices[i] gives the original index for the item at shuffled position i
           if (widget.correctIndices.contains(newOriginalIndices[i])) {
               defaultSelectedIndices.add(i); // Add the shuffled index `i`
           }
        }
      }
      QuizzerLogger.logMessage("SATA: Auto-submit state, auto-setting submitted=true, selectedIndices(shuffled)=$defaultSelectedIndices for preview.");
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
      // Set all submission data in SessionManager BEFORE calling submitAnswer
      _session.setCurrentQuestionCustomOrderIndices(_originalIndices);
      _session.setCurrentQuestionUserAnswer(selectedOriginalIndices);
      
      // Determine correctness and set it
      final bool isCorrect = const ListEquality().equals(selectedOriginalIndices, widget.correctIndices);
      _session.setCurrentQuestionIsCorrect(isCorrect);
      
      // Now call submitAnswer
      _session.submitAnswer(userAnswer: selectedOriginalIndices); 
      QuizzerLogger.logSuccess('Answer submission initiated (Select All).');
    } catch (e) {
       QuizzerLogger.logError('Sync error submitting answer (Select All): $e');
       setState(() { _isAnswerSubmitted = false; }); // Revert only submission flag
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
    final Set<int> correctOriginalIndices = widget.correctIndices.toSet();

    if (questionElements.isEmpty && _shuffledOptions.isEmpty) {
        return const Center(child: Text("No question data provided."));
    }

    // Determine if submit button should be shown (only when enabled)
    final bool canSubmit = !widget.isDisabled && _selectedShuffledIndices.isNotEmpty && !_isAnswerSubmitted;

    // PRESERVE four-color functional feedback system for complex multiple-answer states
    const Color correctColor = Colors.green;
    const Color incorrectColor = Colors.red;
    const Color lighterCorrectColor = Color.fromRGBO(0, 255, 0, 0.1); // Lighter green background
    const Color lighterIncorrectColor = Color.fromRGBO(255, 0, 0, 0.1); // Lighter red background
    final Color selectedOptionBorderColor = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Question Elements --- (Uses passed-in questionElements)
          ElementRenderer(elements: questionElements),
          AppTheme.sizedBoxLrg,

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
              Color? backgroundColor;
              Color? checkboxColor; // Color for the check mark itself

              if (_isAnswerSubmitted) {
                 // Feedback phase - PRESERVE four-color functional feedback system
                 if (isSelected) {
                    // Correct & Selected: Green border, lighter green background, green check icon
                    borderColor = correctColor;
                    backgroundColor = lighterCorrectColor;
                    checkboxColor = correctColor;
                 } else if (isCorrect) {
                    // Correct & NOT Selected: Mark with RED border as an error (no background)
                    borderColor = incorrectColor; 
                 } else if (isSelected) {
                    // Incorrect & Selected: Red border, lighter red background, red cancel icon
                    borderColor = incorrectColor;
                    backgroundColor = lighterIncorrectColor;
                    checkboxColor = incorrectColor;
                 } else {
                    // Incorrect & NOT Selected: Keep neutral
                    borderColor = Colors.transparent;
                 }
                 // Separate logic for the trailing icon based on all states
                 if (isCorrect && isSelected) {
                   icon = Icons.check_circle; 
                   iconColor = correctColor;
                 } else if (isCorrect && !isSelected) {
                   // Correct but not selected - User Error - Show something? Maybe outline?
                   icon = Icons.check_circle_outline; // Keep outline check to show it *was* correct
                   iconColor = incorrectColor; // But make the icon RED
                 } else if (!isCorrect && isSelected) {
                   icon = Icons.cancel; 
                   iconColor = incorrectColor;
                 }
                 // else: !isCorrect && !isSelected -> icon = null, iconColor = transparent (handled by default)
              } else if (isSelected && !widget.isDisabled) {
                 // Selection phase (before submit)
                 borderColor = selectedOptionBorderColor;
                 backgroundColor = selectedOptionBorderColor.withValues(alpha: 0.1);
                 checkboxColor = selectedOptionBorderColor;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: InkWell(
                  // Disable onTap if isDisabled or submitted
                  onTap: (widget.isDisabled || _isAnswerSubmitted) ? null : () => _handleOptionToggled(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      border: borderColor != Colors.transparent ? Border.all(color: borderColor, width: 1.5) : null,
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          // Disable onChanged if isDisabled or submitted
                          onChanged: (widget.isDisabled || _isAnswerSubmitted) ? null : (bool? value) => _handleOptionToggled(index),
                          activeColor: checkboxColor ?? Theme.of(context).colorScheme.primary, 
                          side: BorderSide(color: _isAnswerSubmitted ? (borderColor != Colors.transparent ? borderColor : Theme.of(context).colorScheme.outline) : Theme.of(context).colorScheme.outline), 
                        ),
                        AppTheme.sizedBoxSml,
                        Expanded(child: ElementRenderer(elements: [optionData])), 
                        // Use the icon determined by the logic above
                         if (_isAnswerSubmitted && icon != null)
                           Icon(icon, color: iconColor)
                         else if (_isAnswerSubmitted) // Ensure alignment if no icon is shown
                           const SizedBox(width: 24), 
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          AppTheme.sizedBoxMed,
          
          // --- Answer Elements --- (Uses passed-in answerElements)
          if (_isAnswerSubmitted)
            ElementRenderer(elements: widget.answerElements),

          // --- Submit / Next Question Buttons --- 
          // Only show Submit if it *can* be submitted (enabled, options selected, not submitted)
          if (canSubmit) 
            Padding(
               padding: const EdgeInsets.only(top: 8.0),
               child: ElevatedButton(
                 // onPressed is implicitly enabled because `canSubmit` is true
                 onPressed: _handleSubmitAnswer, 
                 child: const Text('Submit Answer'),
               ),
             ),
              
          // Only show Next if submitted (isDisabled doesn't affect Next button display, only onPressed)
          if (_isAnswerSubmitted) 
             Padding(
               padding: const EdgeInsets.only(top: 8.0),
               child: ElevatedButton(
                 // Disable onPressed if isDisabled
                 onPressed: widget.isDisabled ? null : _handleNextQuestion,
                 child: const Text('Next Question'),
               ),
             ),
        ],
      ),
    );
  }
}