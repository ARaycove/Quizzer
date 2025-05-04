import 'package:flutter/material.dart';
import 'dart:math';
import 'package:collection/collection.dart'; // For ListEquality
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:quizzer/UI_systems/global_widgets/question_answer_element.dart';

// ==========================================
//      Sort Order Question Widget
// ==========================================

class SortOrderQuestionWidget extends StatefulWidget {
  // Data passed in
  final List<Map<String, dynamic>> questionElements;
  final List<Map<String, dynamic>> answerElements;
  final List<Map<String, dynamic>> options; // Correctly ordered options
  final bool isDisabled;

  // Callback
  final VoidCallback onNextQuestion;

  const SortOrderQuestionWidget({
    super.key,
    required this.questionElements,
    required this.answerElements,
    required this.options, // Assume these are the CORRECTLY ordered options
    required this.onNextQuestion,
    this.isDisabled = false,
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
    if (!const ListEquality().equals(widget.options, oldWidget.options) ||
        !const ListEquality().equals(widget.questionElements, oldWidget.questionElements)) {
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

    if (widget.isDisabled) {
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
     bool shouldAutoSubmit = widget.isDisabled;
     if (mounted) {
      setState(() {
         _currentUserOrderedOptions = List<Map<String, dynamic>>.from(initialOptions); 
         _originalIndices = List<int>.from(initialIndexMapping);
         _isAnswerSubmitted = shouldAutoSubmit; // Set submitted if disabled
         // Assume correct for disabled preview, null otherwise
         _isOverallCorrect = shouldAutoSubmit ? true : null; 
         _hoveredIndex = null;
         if (shouldAutoSubmit) {
             QuizzerLogger.logMessage("SortOrderWidget: Disabled state, auto-setting submitted=true, correct=true for preview.");
         }
      });
    } else {
        _currentUserOrderedOptions = List<Map<String, dynamic>>.from(initialOptions);
        _originalIndices = List<int>.from(initialIndexMapping);
        _isAnswerSubmitted = shouldAutoSubmit;
        _isOverallCorrect = shouldAutoSubmit ? true : null;
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
      // Submit the user's order (represented by the list of original indices)
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
            SnackBar(content: Text('Error submitting: ${e.toString()}'), backgroundColor: ColorWheel.buttonError),
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
        return const Center(child: Text("No question data provided.", style: ColorWheel.secondaryTextStyle));
    }
    
    // Determine if interactions should be enabled
    final bool interactionsEnabled = !widget.isDisabled && !_isAnswerSubmitted;

    return SingleChildScrollView(
      child: Padding(
        padding: ColorWheel.standardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Question Elements --- (Uses passed-in data)
            Container(
              padding: ColorWheel.standardPadding,
              decoration: BoxDecoration(color: ColorWheel.secondaryBackground, borderRadius: ColorWheel.cardBorderRadius),
              child: ElementRenderer(elements: questionElements),
            ),
            const SizedBox(height: ColorWheel.majorSectionSpacing),

            // --- Reorderable Options List --- (Uses local state)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), // Prevent nested scrolling
              itemCount: _currentUserOrderedOptions.length,
              buildDefaultDragHandles: false, // Use custom handle logic
              onReorder: interactionsEnabled ? _handleReorder : (int o, int n) {}, // Conditionally enable reorder 
              itemBuilder: (context, index) {
                final optionData = _currentUserOrderedOptions[index];
                final currentOriginalIndex = _originalIndices[index];
                bool isCorrectPosition = false;
                if(_isAnswerSubmitted && index < correctOrderOptions.length) {
                    // Item is in correct final position if its original index matches the current display index
                   isCorrectPosition = currentOriginalIndex == index; 
                }
                
                final bool isHovered = index == _hoveredIndex;
                
                Color tileColor = ColorWheel.secondaryBackground;
                // Use BorderSide for the Card's shape
                BorderSide borderSide = BorderSide.none; 
                IconData? feedbackIcon;
                Color? feedbackColor;

                // Determine feedback based on submitted state and correctness
                if (_isAnswerSubmitted && _isOverallCorrect != null) {
                  bool isItemInCorrectPosition = _originalIndices[index] == index;
            
                  if (_isOverallCorrect!) { // Overall correct
                    feedbackIcon = Icons.check_circle;
                    feedbackColor = ColorWheel.buttonSuccess;
                    tileColor = ColorWheel.buttonSuccess.withAlpha(26); // 0.1 opacity
                    // Set BorderSide for Card shape
                    borderSide = BorderSide(color: feedbackColor, width: 1.5); 
                  } else { // Overall incorrect
                    feedbackIcon = isItemInCorrectPosition
                        ? Icons.check_circle_outline // Correct position, wrong overall
                        : Icons.cancel_outlined; // Wrong position
                        
                    feedbackColor = isItemInCorrectPosition
                        ? ColorWheel.buttonSuccess // Correct item = FULL green
                        : ColorWheel.buttonError;   // Incorrect item = FULL red
                        
                    tileColor = isItemInCorrectPosition
                        ? tileColor 
                        : ColorWheel.buttonError.withAlpha(13); // 0.05 opacity
                        
                    // Set BorderSide for Card shape
                    borderSide = BorderSide( 
                      color: feedbackColor, 
                      width: 1.5
                    );
                  }
                  // Trailing widget uses the determined icon and color
                  feedbackColor = feedbackColor; // Explicitly use feedbackColor for icon
                } else if (interactionsEnabled && isHovered) {
                  // Hover state 
                  tileColor = Color.lerp(ColorWheel.secondaryBackground, ColorWheel.accent, 0.1)!;
                }
                
                // Determine trailing widget AFTER feedback logic
                Widget? trailingWidget = _isAnswerSubmitted
                                  ? (feedbackIcon != null ? Icon(feedbackIcon, color: feedbackColor) : null)
                                  : null; // No explicit drag handle needed

                // Build the Card containing the ListTile
                final cardItem = Card(
                   color: tileColor,
                   margin: const EdgeInsets.symmetric(vertical: 4.0),
                   elevation: _isAnswerSubmitted ? 0 : (interactionsEnabled && isHovered ? 4 : 1), 
                   shape: RoundedRectangleBorder(
                     borderRadius: ColorWheel.buttonBorderRadius,
                     // Use the determined BorderSide here
                     side: borderSide, 
                   ),
                   child: ListTile(
                    title: ElementRenderer(elements: [optionData]), 
                    trailing: trailingWidget, // Assign the final trailing widget
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            const SizedBox(height: ColorWheel.majorSectionSpacing),

            // --- Overall Feedback (Show After Submission) ---
            if (_isAnswerSubmitted && _isOverallCorrect != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  _isOverallCorrect! ? "Correct Order!" : "Incorrect Order",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isOverallCorrect! ? ColorWheel.buttonSuccess : ColorWheel.buttonError,
                    fontSize: 18, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),

            // --- Answer Elements / Correct Order Explanation (Show After Submission) ---
            if (_isAnswerSubmitted)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Container(
                   padding: ColorWheel.standardPadding,
                   decoration: BoxDecoration(color: ColorWheel.secondaryBackground.withAlpha(179), borderRadius: ColorWheel.cardBorderRadius),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       const Text("Correct Order Explanation:", style: ColorWheel.titleText), 
                       const SizedBox(height: ColorWheel.relatedElementSpacing),
                       // Display the Answer Elements 
                       if (answerElements.isNotEmpty)
                          ElementRenderer(elements: answerElements)
                       else // Fallback if no specific answer elements
                       ListView.builder(
                         shrinkWrap: true,
                         physics: const NeverScrollableScrollPhysics(),
                            itemCount: correctOrderOptions.length,
                         itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                children: [
                                  Text("${index + 1}. ", style: ColorWheel.secondaryTextStyle),
                                      Expanded(child: ElementRenderer(elements: [correctOrderOptions[index]])),
                                ],
                              ),
                            );
                         }),
                     ],
                   ),
                 ),
              ),

            // --- Submit / Next Question Buttons ---
            if (interactionsEnabled) // Show Submit only if enabled and not submitted
              Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: ElevatedButton(
                   style: ElevatedButton.styleFrom(backgroundColor: ColorWheel.buttonSuccess),
                   onPressed: _handleSubmitAnswer,
                   child: const Text('Submit Answer', style: ColorWheel.buttonTextBold),
                 ),
              ),
              
            if (_isAnswerSubmitted) // Show Next only after submission
               Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: ElevatedButton(
                   style: ElevatedButton.styleFrom(backgroundColor: ColorWheel.buttonSuccess),
                   onPressed: widget.isDisabled ? null : _handleNextQuestion, // Respect isDisabled
                   child: const Text('Next Question', style: ColorWheel.buttonText),
                 ),
              ),
          ],
        ),
      ),
    );
  }
}
