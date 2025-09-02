import 'package:flutter/material.dart';
import 'dart:math';
import 'package:collection/collection.dart'; // For ListEquality
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/global_widgets/question_answer_element.dart';
import 'package:quizzer/app_theme.dart';

// ==========================================
//      Sort Order Question Widget
// ==========================================

class SortOrderQuestionWidget extends StatefulWidget {
  // Data passed in
  final List<Map<String, dynamic>> questionElements;
  final List<Map<String, dynamic>> answerElements;
  final List<Map<String, dynamic>> options; // Correctly ordered options
  final bool isDisabled;

  // New optional parameters for state control
  final List<int>? customOrderIndices; // If provided, use this order instead of shuffling
  final bool autoSubmitAnswer; // If true, automatically submit answer
  final List<Map<String, dynamic>>? customUserOrder; // Must be provided if autoSubmitAnswer is true
  
  // Callback
  final VoidCallback onNextQuestion;

  const SortOrderQuestionWidget({
    super.key,
    required this.questionElements,
    required this.answerElements,
    required this.options, // Assume these are the CORRECTLY ordered options
    required this.onNextQuestion,
    this.isDisabled = false,
    this.customOrderIndices, // Optional custom order
    this.autoSubmitAnswer = false, // Default to false
    this.customUserOrder, // Optional custom user order
  });

  @override
  State<SortOrderQuestionWidget> createState() =>
      _SortOrderQuestionWidgetState();
}

class _SortOrderQuestionWidgetState extends State<SortOrderQuestionWidget> {
  final SessionManager _session = SessionManager(); // Keep for submitAnswer

  List<Map<String, dynamic>> _currentUserOrderedOptions = [];
  List<int> _originalIndices = []; // Maps current display index to correct original index
  bool _isAnswerSubmitted = false;
  bool? _isOverallCorrect; // Null until submitted
  int? _hoveredIndex; // Index of the item currently hovered (display list)

  @override
  void initState() {
    super.initState();
    QuizzerLogger.logMessage("SortOrderQuestionWidget initState");
    _loadAndPrepareOptions();
  }

  @override
  void didUpdateWidget(covariant SortOrderQuestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if core data has changed
    if (widget.autoSubmitAnswer != oldWidget.autoSubmitAnswer ||
        widget.customUserOrder != oldWidget.customUserOrder) {
      QuizzerLogger.logMessage(
          "SortOrderQuestionWidget didUpdateWidget: Data changed, resetting.");
      _loadAndPrepareOptions();
    } else {
      QuizzerLogger.logMessage(
          "SortOrderQuestionWidget didUpdateWidget: Data same, no reset.");
    }
  }

  void _loadAndPrepareOptions() {
    final correctOrderOptions = widget.options;

    if (correctOrderOptions.isEmpty) {
      QuizzerLogger.logWarning("SortOrderQuestionWidget: Passed empty options.");
      _resetState([], []);
        return;
    }

    List<int> initialIndices =
        List<int>.generate(correctOrderOptions.length, (i) => i);
    List<Map<String, dynamic>> initialDisplayOptions;

    // Check if we should use SessionManager data for answered state
    if (widget.autoSubmitAnswer && _session.lastSubmittedUserAnswer != null) {
      // For sort order, the submitted answer is the custom user order
      final submittedOrder = _session.lastSubmittedUserAnswer as List<Map<String, dynamic>>;
      QuizzerLogger.logMessage("SortOrderWidget: Using SessionManager submitted order for auto-submit.");
      initialDisplayOptions = List<Map<String, dynamic>>.from(submittedOrder);
      // For sort order, we need to determine the index mapping from the submitted order
      initialIndices = [];
      for (var submittedItem in submittedOrder) {
        int originalIndex = correctOrderOptions.indexWhere((option) => 
          const MapEquality().equals(option, submittedItem));
        initialIndices.add(originalIndex != -1 ? originalIndex : 0);
      }
    } else if (widget.customOrderIndices != null) {
      // Use custom order if provided
      QuizzerLogger.logMessage("SortOrderWidget: Using custom order indices: ${widget.customOrderIndices}");
      initialIndices = List<int>.from(widget.customOrderIndices!);
      initialDisplayOptions = initialIndices.map((i) => correctOrderOptions[i]).toList();
    } else if (widget.isDisabled) {
      QuizzerLogger.logMessage("SortOrderWidget: Disabled, not shuffling.");
      initialDisplayOptions = List<Map<String, dynamic>>.from(correctOrderOptions);
      // Indices remain [0, 1, 2...]
      } else {
      QuizzerLogger.logMessage("SortOrderWidget: Enabled, shuffling.");
      initialIndices.shuffle(Random());
      initialDisplayOptions =
          initialIndices.map((i) => correctOrderOptions[i]).toList();
    }

    _resetState(initialDisplayOptions, initialIndices);
    QuizzerLogger.logValue("SortOrder Initial Map (Display Index -> Correct Index): $initialIndices");
  }

  void _resetState(List<Map<String, dynamic>> initialOptions, List<int> initialIndexMapping) {
     bool shouldAutoSubmit = widget.isDisabled || widget.autoSubmitAnswer;
     
     // Determine initial state based on parameters
     List<Map<String, dynamic>> finalOptions;
     List<int> finalIndexMapping;
     bool? finalCorrectness;
     
     if (shouldAutoSubmit && widget.autoSubmitAnswer && _session.lastSubmittedUserAnswer != null) {
       // Use the submitted answer from SessionManager
       final submittedOrder = _session.lastSubmittedUserAnswer as List<Map<String, dynamic>>;
       finalOptions = List<Map<String, dynamic>>.from(submittedOrder);
       finalIndexMapping = List<int>.from(initialIndexMapping);
       finalCorrectness = _session.lastSubmittedIsCorrect;
     } else if (shouldAutoSubmit && widget.customUserOrder != null) {
       // Use the custom user order if provided
       finalOptions = List<Map<String, dynamic>>.from(widget.customUserOrder!);
       // For custom user order, we need to determine the index mapping
       // This assumes the customUserOrder contains the same items as the original options
       finalIndexMapping = [];
       for (var customItem in finalOptions) {
         int originalIndex = widget.options.indexWhere((option) => 
           const MapEquality().equals(option, customItem));
         finalIndexMapping.add(originalIndex != -1 ? originalIndex : 0);
       }
       // Determine correctness based on the custom order
       final List<int> correctOrderOriginalIndices = List<int>.generate(widget.options.length, (i) => i);
       finalCorrectness = const ListEquality().equals(finalIndexMapping, correctOrderOriginalIndices);
     } else {
       // Use the initial options and mapping
       finalOptions = List<Map<String, dynamic>>.from(initialOptions);
       finalIndexMapping = List<int>.from(initialIndexMapping);
       finalCorrectness = shouldAutoSubmit ? true : null; // Assume correct for disabled preview
     }
     
     if (mounted) {
      setState(() {
         _currentUserOrderedOptions = finalOptions; 
         _originalIndices = finalIndexMapping;
         _isAnswerSubmitted = shouldAutoSubmit; // Set submitted if disabled
         _isOverallCorrect = finalCorrectness; 
         _hoveredIndex = null;
         if (shouldAutoSubmit) {
             QuizzerLogger.logMessage("SortOrderWidget: Auto-submit state, auto-setting submitted=true, correctness=$finalCorrectness for preview.");
         }
      });
    } else {
        _currentUserOrderedOptions = finalOptions;
        _originalIndices = finalIndexMapping;
        _isAnswerSubmitted = shouldAutoSubmit;
        _isOverallCorrect = finalCorrectness;
        _hoveredIndex = null;
    }
  }

  void _handleReorder(int oldIndex, int newIndex) {
    // Disable if needed
    if (widget.isDisabled || _isAnswerSubmitted) return;

    // Adjust index for items moving down
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    setState(() {
      final Map<String, dynamic> item = _currentUserOrderedOptions.removeAt(oldIndex);
      _currentUserOrderedOptions.insert(newIndex, item);
      // Also reorder the original index mapping
      final int indexMapping = _originalIndices.removeAt(oldIndex);
      _originalIndices.insert(newIndex, indexMapping);
      QuizzerLogger.logValue("List reordered. New original indices map: $_originalIndices");
    });
  }

  void _handleSubmitAnswer() {
    // Disable if needed
    if (widget.isDisabled || _isAnswerSubmitted) return;

    QuizzerLogger.logMessage('Submitting sorted answer...');
    
    // Determine correctness: user's list of original indices should be [0, 1, 2...]
    final List<int> correctOrderOriginalIndices = List<int>.generate(widget.options.length, (i) => i);
    final bool isCorrect = const ListEquality().equals(_originalIndices, correctOrderOriginalIndices);
    QuizzerLogger.logValue("Correctness Check: User=$_originalIndices, Correct=$correctOrderOriginalIndices, Result=$isCorrect");

    setState(() {
      _isAnswerSubmitted = true;
      _isOverallCorrect = isCorrect; // Set overall correctness state
    });

    try {
      // Set all submission data in SessionManager BEFORE calling submitAnswer
      _session.setCurrentQuestionCustomOrderIndices(_originalIndices);
      _session.setCurrentQuestionUserAnswer(_currentUserOrderedOptions);
      _session.setCurrentQuestionIsCorrect(isCorrect);
      
      // Now call submitAnswer
      _session.submitAnswer(userAnswer: _currentUserOrderedOptions); 
      QuizzerLogger.logSuccess('Answer submission initiated (Sort Order).');
    } catch (e) {
       QuizzerLogger.logError('Sync error submitting answer (Sort Order): $e');
       setState(() { 
         _isAnswerSubmitted = false; 
         _isOverallCorrect = null; // Revert state
       }); 
       if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error submitting: ${e.toString()}')),
          );
       }
    }
  }

  void _handleNextQuestion() {
    // Disable if needed
    if (widget.isDisabled) return;
    widget.onNextQuestion();
  }

  @override
  Widget build(BuildContext context) {
    // Use passed-in data
    final questionElements = widget.questionElements;
    final answerElements = widget.answerElements;
    final correctOrderOptions = widget.options; // Correct order from parameters

    // Removed isLoading check as data is passed in constructor
     if (_currentUserOrderedOptions.isEmpty && questionElements.isEmpty) {
        return const Center(child: Text("No question data provided."));
    }
    
    // Determine if interactions should be enabled
    final bool interactionsEnabled = !widget.isDisabled && !_isAnswerSubmitted;

    // PRESERVE functional feedback colors for correctness states
    const Color correctColor = Colors.green;
    const Color incorrectColor = Colors.red;
    final Color hoverColor = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Question Elements --- (Uses passed-in data)
          ElementRenderer(elements: questionElements),
          AppTheme.sizedBoxLrg,

          // --- Reorderable Options List --- (Uses local state)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), // Prevent nested scrolling
            itemCount: _currentUserOrderedOptions.length,
            buildDefaultDragHandles: false, // Use custom handle logic
            onReorder: interactionsEnabled ? _handleReorder : (int o, int n) {}, // Conditionally enable reorder 
            itemBuilder: (context, index) {
              final optionData = _currentUserOrderedOptions[index];
              final bool isHovered = index == _hoveredIndex;
              
              Color tileColor = Theme.of(context).colorScheme.surface;
              BorderSide borderSide = BorderSide.none; 
              IconData? feedbackIcon;
              Color? feedbackColor;

              // Determine feedback based on submitted state and correctness
              if (_isAnswerSubmitted && _isOverallCorrect != null) {
                bool isItemInCorrectPosition = _originalIndices[index] == index;
          
                if (_isOverallCorrect!) { // Overall correct
                  feedbackIcon = Icons.check_circle;
                  feedbackColor = correctColor;
                  tileColor = correctColor.withValues(alpha: 0.1); // 0.1 opacity
                  borderSide = BorderSide(color: feedbackColor); 
                } else { // Overall incorrect
                  feedbackIcon = isItemInCorrectPosition
                      ? Icons.check_circle_outline // Correct position, wrong overall
                      : Icons.cancel_outlined; // Wrong position
                      
                  feedbackColor = isItemInCorrectPosition
                      ? correctColor // Correct item = FULL green
                      : incorrectColor;   // Incorrect item = FULL red
                      
                  tileColor = isItemInCorrectPosition
                      ? tileColor 
                      : incorrectColor.withValues(alpha: 0.05); // 0.05 opacity
                      
                  borderSide = BorderSide( 
                    color: feedbackColor, 
                    width: 1.5
                  );
                }
                feedbackColor = feedbackColor; // Explicitly use feedbackColor for icon
              } else if (interactionsEnabled && isHovered) {
                // Hover state 
                tileColor = Color.lerp(Theme.of(context).colorScheme.surface, hoverColor, 0.1)!;
              }
              
              // Determine trailing widget AFTER feedback logic
              Widget? trailingWidget = _isAnswerSubmitted
                                ? (feedbackIcon != null ? Icon(feedbackIcon, color: feedbackColor) : null)
                                : null; // No explicit drag handle needed

              // Build the Card containing the ListTile
              final cardItem = Card(
                 color: tileColor,
                 elevation: _isAnswerSubmitted ? 0 : (interactionsEnabled && isHovered ? 4 : 1), 
                 shape: RoundedRectangleBorder(
                   side: borderSide, 
                 ),
                 child: ListTile(
                  title: ElementRenderer(elements: [optionData]), 
                  trailing: trailingWidget, // Assign the final trailing widget
                ),
              );

              // Determine the key (try content first)
              final key = ValueKey(optionData['content']?.toString() ?? 'item_$index'); 

              // Wrap with drag listener only if interactions are enabled
              Widget itemWidget = interactionsEnabled
                  ? ReorderableDragStartListener(index: index, child: cardItem)
                  : cardItem;

              // Wrap the item with MouseRegion for hover detection (only if interactions enabled)
              return MouseRegion(
                key: key,
                onEnter: (_) {
                  if (interactionsEnabled) {
                     setState(() => _hoveredIndex = index);
                  }
                },
                onExit: (_) {
                  if (_hoveredIndex == index) {
                     setState(() => _hoveredIndex = null);
                  }
                },
                child: itemWidget,
              );
            },
             // Modified proxyDecorator for visual feedback during drag
            proxyDecorator: (Widget child, int index, Animation<double> animation) {
                return Material(
                   color: Colors.transparent, 
                   elevation: 6.0, 
                   shadowColor: Colors.black.withAlpha(77),
                   child: child, 
                );
             },
          ),
          AppTheme.sizedBoxLrg,

          // --- Overall Feedback (Show After Submission) ---
          if (_isAnswerSubmitted && _isOverallCorrect != null)
            Text(
              _isOverallCorrect! ? "Correct Order!" : "Incorrect Order",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isOverallCorrect! ? correctColor : incorrectColor,
                fontWeight: FontWeight.bold
              ),
            ),

          // --- Answer Elements / Correct Order Explanation (Show After Submission) ---
          if (_isAnswerSubmitted)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Correct Order Explanation:", style: TextStyle(fontWeight: FontWeight.bold)), 
                AppTheme.sizedBoxSml,
                // Display the Answer Elements 
                if (answerElements.isNotEmpty)
                   ElementRenderer(elements: answerElements)
                else // Fallback if no specific answer elements
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                     itemCount: correctOrderOptions.length,
                  itemBuilder: (context, index) {
                     return Row(
                       children: [
                         Text("${index + 1}. "),
                             Expanded(child: ElementRenderer(elements: [correctOrderOptions[index]])),
                       ],
                     );
                  }),
              ],
            ),

          // --- Submit / Next Question Buttons ---
          if (interactionsEnabled) // Show Submit only if enabled and not submitted
            ElevatedButton(
              onPressed: _handleSubmitAnswer,
              child: const Text('Submit Answer'),
            ),
              
          if (_isAnswerSubmitted) // Show Next only after submission
            Align(
              alignment: Alignment.bottomCenter,
              widthFactor: 1,
              child: ElevatedButton(
                onPressed: widget.isDisabled ? null : _handleNextQuestion,
                child: const Text('Next Question'),
              ),           
            )
        ],
      ),
    );
  }
}