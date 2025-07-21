import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'dart:math'; // For shuffling
// Import the shared ElementRenderer
import 'package:quizzer/UI_systems/global_widgets/question_answer_element.dart'; 
import 'package:quizzer/app_theme.dart';

// ==========================================
//    Multiple Choice Question Widget
// ==========================================
//  Local ElementRenderer definition REMOVED 

class MultipleChoiceQuestionWidget extends StatefulWidget {
  // Data passed in
  final List<Map<String, dynamic>> questionElements;
  final List<Map<String, dynamic>> answerElements;
  final List<Map<String, dynamic>> options;
  final int? correctOptionIndex; // Original correct index
  final bool isDisabled;
  
  // New optional parameters for state control
  final List<int>? customOrderIndices; // If provided, use this order instead of shuffling
  final bool autoSubmitAnswer; // If true, automatically submit answer
  final int? selectedIndex; // Must be provided if autoSubmitAnswer is true
  
  // Callback
  final VoidCallback onNextQuestion; 

  const MultipleChoiceQuestionWidget({
    super.key, // Keep key for state management
    required this.questionElements,
    required this.answerElements,
    required this.options,
    required this.correctOptionIndex,
    required this.onNextQuestion,
    this.isDisabled = false, // Default to false
    this.customOrderIndices, // Optional custom order
    this.autoSubmitAnswer = false, // Default to false
    this.selectedIndex, // Optional selected index
  });

  @override
  State<MultipleChoiceQuestionWidget> createState() =>
      _MultipleChoiceQuestionWidgetState();
}

// --- State ---

class _MultipleChoiceQuestionWidgetState
    extends State<MultipleChoiceQuestionWidget> {
      
  // Session manager might still be needed for submitAnswer ONLY
  final SessionManager _session = SessionManager(); 
  
  // State remains internal to the widget's presentation logic
  List<Map<String, dynamic>> _shuffledOptions = [];
  List<int> _originalIndices = []; // Map shuffled index back to original index
  int? _selectedOptionIndex; // Index *in the shuffled list* that was selected
  bool _isAnswerSubmitted = false;

  @override
  void initState() {
    super.initState();
    QuizzerLogger.logMessage("MultipleChoiceQuestionWidget initState");
    _loadAndShuffleOptions();
  }

  // Called when widget receives new data (e.g., HomePage rebuilds with new question)
  @override
  void didUpdateWidget(covariant MultipleChoiceQuestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if the core data has actually changed before resetting state
    // Basic check: if options list instance changes, reload.
    // More robust checks might compare question content if needed.
    if (widget.options != oldWidget.options || 
        widget.correctOptionIndex != oldWidget.correctOptionIndex ||
        widget.customOrderIndices != oldWidget.customOrderIndices ||
        widget.autoSubmitAnswer != oldWidget.autoSubmitAnswer ||
        widget.selectedIndex != oldWidget.selectedIndex) {
        QuizzerLogger.logMessage("MultipleChoiceQuestionWidget didUpdateWidget: Data changed, shuffling.");
        _loadAndShuffleOptions();
    } else {
        QuizzerLogger.logMessage("MultipleChoiceQuestionWidget didUpdateWidget: Data same, no shuffle.");
    }
  }

  void _loadAndShuffleOptions() {
    // Use data from widget parameters
    final originalOptions = widget.options; 

    if (originalOptions.isEmpty) {
       QuizzerLogger.logWarning("MultipleChoiceQuestionWidget: Passed empty options.");
       if (mounted) {
         setState(() {
           _shuffledOptions = [];
           _originalIndices = [];
           _selectedOptionIndex = null;
           _isAnswerSubmitted = false;
         });
       }
       return;
    }

    List<Map<String, dynamic>> newShuffledOptions;
    List<int> newOriginalIndices;

    // Check if we should use SessionManager data for answered state
    if (widget.autoSubmitAnswer && _session.lastSubmittedUserAnswer != null) {
      // Use the custom order from SessionManager if available
      if (_session.lastSubmittedCustomOrderIndices != null) {
        QuizzerLogger.logMessage("MultipleChoiceQuestionWidget: Using SessionManager custom order indices: ${_session.lastSubmittedCustomOrderIndices}");
        newOriginalIndices = List<int>.from(_session.lastSubmittedCustomOrderIndices!);
        newShuffledOptions = newOriginalIndices.map((i) => originalOptions[i]).toList();
      } else {
        // Fallback to original order if no custom order stored
        QuizzerLogger.logMessage("MultipleChoiceQuestionWidget: No custom order in SessionManager, using original order.");
        newShuffledOptions = List<Map<String, dynamic>>.from(originalOptions);
        newOriginalIndices = List<int>.generate(originalOptions.length, (i) => i);
      }
    } else if (widget.customOrderIndices != null) {
      // Use custom order if provided
      QuizzerLogger.logMessage("MultipleChoiceQuestionWidget: Using custom order indices: ${widget.customOrderIndices}");
      newOriginalIndices = List<int>.from(widget.customOrderIndices!);
      newShuffledOptions = newOriginalIndices.map((i) => originalOptions[i]).toList();
    } else if (widget.isDisabled) {
      // If disabled, do not shuffle. Use the original order.
      QuizzerLogger.logMessage("MultipleChoiceQuestionWidget: Disabled state, not shuffling options.");
      newShuffledOptions = List<Map<String, dynamic>>.from(originalOptions); // Create a copy
      newOriginalIndices = List<int>.generate(originalOptions.length, (i) => i);
    } else {
      // If enabled, shuffle the options.
      QuizzerLogger.logMessage("MultipleChoiceQuestionWidget: Enabled state, shuffling options.");
      final List<int> indices = List<int>.generate(originalOptions.length, (i) => i);
      indices.shuffle(Random());
      newShuffledOptions = indices.map((i) => originalOptions[i]).toList();
      newOriginalIndices = indices;
    }
    
    // Reset internal state
    bool shouldAutoSubmit = widget.isDisabled || widget.autoSubmitAnswer;
    // Determine default selected index for disabled preview or auto submit
    int? defaultSelectedIndex;
    if (shouldAutoSubmit) {
      if (widget.autoSubmitAnswer && _session.lastSubmittedUserAnswer != null) {
        // Use the submitted answer from SessionManager
        final submittedAnswer = _session.lastSubmittedUserAnswer as int;
        defaultSelectedIndex = newOriginalIndices.indexOf(submittedAnswer);
        if (defaultSelectedIndex == -1) {
          defaultSelectedIndex = 0;
        }
      } else if (widget.selectedIndex != null) {
        // Use the provided selected index (find its position in the current order)
        defaultSelectedIndex = newOriginalIndices.indexOf(widget.selectedIndex!);
        if (defaultSelectedIndex == -1) {
          // If the selected index is not found in the current order, default to 0
          defaultSelectedIndex = 0;
        }
      } else if (widget.correctOptionIndex != null) {
        // Fallback to correct index if no selected index provided
        defaultSelectedIndex = newOriginalIndices.indexOf(widget.correctOptionIndex!);
        if (defaultSelectedIndex == -1) {
          defaultSelectedIndex = 0;
        }
      } else {
        defaultSelectedIndex = 0;
      }
      QuizzerLogger.logMessage("MCQ: Auto-submit state, auto-setting submitted=true, selectedIndex=$defaultSelectedIndex for preview.");
    }
                                
    if (mounted) {
        setState(() {
          _shuffledOptions = newShuffledOptions;
          _originalIndices = newOriginalIndices; 
          _selectedOptionIndex = defaultSelectedIndex; // Set selection for disabled view
          _isAnswerSubmitted = shouldAutoSubmit; // Set submitted if disabled 
        });
    } else {
         _shuffledOptions = newShuffledOptions;
         _originalIndices = newOriginalIndices; 
         _selectedOptionIndex = defaultSelectedIndex;
         _isAnswerSubmitted = shouldAutoSubmit;
    }
    QuizzerLogger.logValue("MultipleChoiceQuestionWidget: Options loaded. Original indices mapping: $_originalIndices"); 
  }

  Future<void> _handleOptionSelected(int selectedShuffledIndex) async { 
    // Disable interaction if widget is disabled or already submitted
    if (widget.isDisabled || _isAnswerSubmitted) return; 

    final int originalIndex = _originalIndices[selectedShuffledIndex];
    QuizzerLogger.logMessage('Option selected (shuffled index: $selectedShuffledIndex, original index: $originalIndex). Submitting answer...');
    
    setState(() {
      _selectedOptionIndex = selectedShuffledIndex; 
      _isAnswerSubmitted = true;
    });

    try {
      // Set all submission data in SessionManager BEFORE calling submitAnswer
      _session.setCurrentQuestionCustomOrderIndices(_originalIndices);
      _session.setCurrentQuestionUserAnswer(originalIndex);
      
      // Determine correctness and set it
      final bool isCorrect = originalIndex == widget.correctOptionIndex;
      _session.setCurrentQuestionIsCorrect(isCorrect);
      
      // Now call submitAnswer
      _session.submitAnswer(userAnswer: originalIndex); 
      QuizzerLogger.logSuccess('Answer submission initiated to SessionManager.'); 
    } catch (e) {
       QuizzerLogger.logError('Synchronous error during submitAnswer call: $e'); 
       setState(() {
         _isAnswerSubmitted = false; 
         _selectedOptionIndex = null;
       });
       if(mounted) { 
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error initiating answer submission: ${e.toString()}'), 
            ),
          );
       }
    }
  }

  void _handleNextQuestion() {
    // Disable if needed
    if (widget.isDisabled) return; 
    QuizzerLogger.logMessage("Next Question button tapped.");
    widget.onNextQuestion(); 
  }

  @override
  Widget build(BuildContext context) {
    QuizzerLogger.logValue("MCQ build. Disabled: ${widget.isDisabled}, Submitted: $_isAnswerSubmitted, Selected Shuffled: $_selectedOptionIndex");
    
    // Use passed-in data
    final questionElements = widget.questionElements;
    final answerElements = widget.answerElements;
    final int? correctOriginalIndex = widget.correctOptionIndex; 
    
    if (_shuffledOptions.isEmpty && questionElements.isEmpty) {
       return const Center(child: Text("No question data provided."));
    }

    if (correctOriginalIndex == null && !widget.isDisabled) {
        // Only error out if *not* disabled; disabled preview might not have correct index yet
        QuizzerLogger.logError("MultipleChoiceQuestionWidget build: correctOriginalIndex is null. Cannot determine correctness.");
        return const Center(child: Text("Error: Question data is incomplete (missing correct index)."));
    }

    // --- Render UI --- 
    // PRESERVE functional feedback colors for correct/incorrect states
    const Color correctColor = Colors.green;
    const Color incorrectColor = Colors.red;
    final Color selectedOptionBorderColor = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Question Elements --- (Uses passed-in questionElements)
          ElementRenderer(elements: questionElements), 
          AppTheme.sizedBoxLrg,

          // --- Options --- 
          ListView.builder(
            shrinkWrap: true, 
            physics: const NeverScrollableScrollPhysics(), 
            itemCount: _shuffledOptions.length,
            itemBuilder: (context, index) {
              final optionData = _shuffledOptions[index]; 
              final int currentOriginalIndex = _originalIndices.length > index ? _originalIndices[index] : -1; // Safety check
              
              final bool isSelected = _selectedOptionIndex == index;
              // Use passed-in correctOriginalIndex
              final bool isCorrect = currentOriginalIndex == correctOriginalIndex; 
              
              Color? optionBgColor;
              Color? borderColor;
              IconData? trailingIcon;
              bool showAnswerForThisOption = false;

              if (_isAnswerSubmitted) {
                if (isSelected) {
                  borderColor = isCorrect ? correctColor : incorrectColor;
                  optionBgColor = isCorrect ? correctColor.withValues(alpha: 0.1) : incorrectColor.withValues(alpha: 0.1);
                  trailingIcon = isCorrect ? Icons.check_circle : Icons.cancel;
                  if(isCorrect) showAnswerForThisOption = true; 
                } else if (isCorrect) {
                   optionBgColor = correctColor.withValues(alpha: 0.1);
                   trailingIcon = Icons.check_circle_outline;
                   showAnswerForThisOption = true; 
                }
              } else if (isSelected && !widget.isDisabled) {
                // Only show selection border if enabled and not submitted
                borderColor = selectedOptionBorderColor;
                optionBgColor = selectedOptionBorderColor.withValues(alpha: 0.1);
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: InkWell(
                  // Disable onTap if isDisabled or submitted
                  onTap: (widget.isDisabled || _isAnswerSubmitted) ? null : () => _handleOptionSelected(index), 
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: optionBgColor,
                      border: borderColor != null ? Border.all(color: borderColor, width: 1.5) : null,
                    ),
                    child: Column( 
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              color: _isAnswerSubmitted 
                                     ? (isCorrect ? correctColor : (isSelected ? incorrectColor : null)) 
                                     : (isSelected && !widget.isDisabled ? selectedOptionBorderColor : null),
                            ),
                            AppTheme.sizedBoxMed,
                            Expanded(child: ElementRenderer(elements: [optionData])), 
                            if (_isAnswerSubmitted && trailingIcon != null)
                              Icon(trailingIcon, color: isCorrect ? correctColor : (isSelected ? incorrectColor : null)),
                          ],
                        ),
                        // --- Display Answer Elements --- (Uses passed-in answerElements)
                        if (_isAnswerSubmitted && showAnswerForThisOption)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, left: 32.0), 
                            child: ElementRenderer(elements: answerElements), 
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          AppTheme.sizedBoxLrg,

          // --- Next Question Button --- 
          if (_isAnswerSubmitted)
            ElevatedButton(
              // Disable onPressed if isDisabled
              onPressed: widget.isDisabled ? null : _handleNextQuestion,
              child: const Text('Next Question'),
            ),
        ],
      ),
    );
  }
}