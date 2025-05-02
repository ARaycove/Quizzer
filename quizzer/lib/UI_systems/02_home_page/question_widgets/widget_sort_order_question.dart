import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:quizzer/UI_systems/global_widgets/question_answer_element.dart';
import 'dart:math'; // For shuffling

// ==========================================
//    Sort Order Question Widget
// ==========================================

class SortOrderQuestionWidget extends StatefulWidget {
  final VoidCallback onNextQuestion;

  const SortOrderQuestionWidget({
    super.key,
    required this.onNextQuestion,
  });

  @override
  State<SortOrderQuestionWidget> createState() =>
      _SortOrderQuestionWidgetState();
}

class _SortOrderQuestionWidgetState extends State<SortOrderQuestionWidget> {
  final SessionManager _session = SessionManager();

  List<Map<String, dynamic>> _currentUserOrderedOptions = [];
  bool _isAnswerSubmitted = false;
  bool? _isOverallCorrect; // Null until submitted
  bool _isLoading = true; // Start as true until initial load
  int? _hoveredIndex; // Index of the item currently hovered

  @override
  void initState() {
    super.initState();
    QuizzerLogger.logMessage("SortOrderQuestionWidget initState (New Instance)");
    _loadAndShuffleOptions();
  }

  void _loadAndShuffleOptions() {
    // No setState for isLoading here, happens synchronously in initState
    _isLoading = true; 

    // Deep copy and shuffle
    List<Map<String, dynamic>> originalOptions = List<Map<String, dynamic>>.from(
        _session.currentQuestionOptions.map((o) => Map<String, dynamic>.from(o))
    );

    if (originalOptions.isEmpty) {
        QuizzerLogger.logWarning("SortOrderQuestionWidget: No options found for question ${_session.currentQuestionId}.");
        // Set state directly
        _currentUserOrderedOptions = [];
        _isAnswerSubmitted = false;
        _isOverallCorrect = null; 
        _isLoading = false;
        return;
    }

    originalOptions.shuffle(Random());
    
    // --- DEBUG: Check for duplicate content keys ---
    final Set<String> contentKeys = {};
    bool duplicatesFound = false;
    for (final option in originalOptions) {
      final content = option['content'] as String?;
      if (content != null) {
        if (!contentKeys.add(content)) {
          QuizzerLogger.logWarning("SortOrderQuestionWidget: Duplicate content found, potentially causing key issues: '$content'");
          duplicatesFound = true;
        }
      } else {
          QuizzerLogger.logWarning("SortOrderQuestionWidget: Null content found in options, cannot use for key.");
          // Consider how to handle null content if it's possible - maybe use a default key or throw?
      }
    }
    if (!duplicatesFound) {
       QuizzerLogger.logMessage("SortOrderQuestionWidget: All option content keys appear unique.");
    }
    // --- END DEBUG ---

    // Set state directly
    _currentUserOrderedOptions = originalOptions;
    _isAnswerSubmitted = false;
    _isOverallCorrect = null; 
    _isLoading = false;
    QuizzerLogger.logValue("SortOrderQuestionWidget: Options shuffled in initState for question ${_session.currentQuestionId}.");
    // Need a setState AFTER potential async operations, but not here.
    // If this involved async calls, we would need a setState(() => _isLoading = false) after await.
    // Since it's sync, the build method will run after initState with _isLoading = false.
  }

  void _handleReorder(int oldIndex, int newIndex) {
    // Adjust index for items moving down
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    // Prevent reordering after submission
    if (_isAnswerSubmitted) return;

    setState(() {
      final Map<String, dynamic> item = _currentUserOrderedOptions.removeAt(oldIndex);
      _currentUserOrderedOptions.insert(newIndex, item);
    });
  }

  void _handleSubmitAnswer() {
    if (_isAnswerSubmitted) return;

    QuizzerLogger.logMessage('Submitting sorted answer...');
    
    // --- Calculate Overall Correctness ---
    final correctOrder = _session.currentQuestionOptions; 
    bool overallCorrect = true;
    if (_currentUserOrderedOptions.length != correctOrder.length) {
      overallCorrect = false; // Should not happen if data is valid
    } else {
      for (int i = 0; i < correctOrder.length; i++) {
        // Compare content for simplicity, assumes content is unique enough
        if (_currentUserOrderedOptions[i]['content'] != correctOrder[i]['content']) {
          overallCorrect = false;
          break;
        }
      }
    }
    QuizzerLogger.logValue("Overall correctness calculated: $overallCorrect");
    // -------------------------------------

    setState(() {
      _isAnswerSubmitted = true;
      _isOverallCorrect = overallCorrect; // Set overall correctness state
    });

    // Submit the current order
    try {
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
    widget.onNextQuestion();
  }

  @override
  Widget build(BuildContext context) {
    final questionElements = _session.currentQuestionElements;
    final answerElements = _session.currentQuestionAnswerElements;
    final correctOrder = _session.currentQuestionOptions; // The original list IS the correct order

    if (_isLoading) {
       return const Center(child: CircularProgressIndicator(color: ColorWheel.accent));
    }
     if (_currentUserOrderedOptions.isEmpty && questionElements.isEmpty) {
        return const Center(child: Text("No question loaded.", style: ColorWheel.secondaryTextStyle));
    }

    return SingleChildScrollView(
      // Wrap with SingleChildScrollView if content might overflow vertically
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

            // --- Reorderable Options List ---
            ReorderableListView.builder(
              shrinkWrap: true,
              itemCount: _currentUserOrderedOptions.length,
              buildDefaultDragHandles: false,
              // Prevent reordering after submission
              onReorder: _isAnswerSubmitted ? (int o, int n) {} : _handleReorder, 
              itemBuilder: (context, index) {
                final option = _currentUserOrderedOptions[index];
                final key = ValueKey(option['content']); 
                bool isCorrectPosition = false;
                if(_isAnswerSubmitted && index < correctOrder.length) {
                   isCorrectPosition = option['content'] == correctOrder[index]['content'];
                }
                
                // Determine if the current item is hovered
                final bool isHovered = index == _hoveredIndex;

                // Build the Card containing the ListTile
                final cardItem = Card(
                   color: (!_isAnswerSubmitted && isHovered) 
                         ? Color.lerp(ColorWheel.secondaryBackground, ColorWheel.accent, 0.1) // Subtle hover color
                         : ColorWheel.secondaryBackground, 
                   margin: const EdgeInsets.symmetric(vertical: 4.0),
                   elevation: _isAnswerSubmitted ? 0 : (isHovered ? 4 : 2), // Increase elevation slightly on hover
                   shape: RoundedRectangleBorder(
                     borderRadius: ColorWheel.buttonBorderRadius,
                     side: _isAnswerSubmitted 
                           ? BorderSide(color: isCorrectPosition ? ColorWheel.buttonSuccess : ColorWheel.buttonError, width: 1.5)
                           : BorderSide.none,
                   ),
                   child: ListTile(
                    title: ElementRenderer(elements: [option]), 
                    // Remove visual drag handle when not submitted (whole card is draggable)
                    trailing: _isAnswerSubmitted
                              ? Icon(isCorrectPosition ? Icons.check : Icons.close, color: isCorrectPosition ? ColorWheel.buttonSuccess : ColorWheel.buttonError)
                              : null, // No explicit handle needed before submission
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                );

                // Conditionally wrap based on submission state
                Widget itemWidget;
                if (!_isAnswerSubmitted) {
                    itemWidget = ReorderableDragStartListener(
                        index: index,
                        child: cardItem,
                    );
                } else {
                    itemWidget = KeyedSubtree(
                       child: cardItem
                    );
                }
                
                // Wrap the item with MouseRegion for hover detection
                return MouseRegion(
                  key: key,
                  onEnter: (_) {
                    if (!_isAnswerSubmitted) {
                       setState(() => _hoveredIndex = index);
                    }
                  },
                  onExit: (_) {
                    // Only clear hover if the mouse is exiting *this* item's region
                    if (_hoveredIndex == index) {
                       setState(() => _hoveredIndex = null);
                    }
                  },
                  child: itemWidget,
                );
              },
               // Modified proxyDecorator for transparent background and elevation
              proxyDecorator: (Widget child, int index, Animation<double> animation) {
                  // Wrap in a Material for elevation and transparency effects.
                  // The 'child' IS the Card from the itemBuilder (or its wrapper).
                  return Material(
                     color: Colors.transparent, // Keep background transparent
                     elevation: 6.0, // Slightly increase elevation while dragging
                     child: child, // Use the child directly, removing ScaleTransition
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

            // --- Answer Elements / Correct Order (Show After Submission) ---
            if (_isAnswerSubmitted)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Container(
                   padding: ColorWheel.standardPadding,
                   decoration: BoxDecoration(color: ColorWheel.secondaryBackground.withOpacity(0.7), borderRadius: ColorWheel.cardBorderRadius),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       const Text("Correct Order:", style: ColorWheel.titleText),
                       const SizedBox(height: ColorWheel.relatedElementSpacing),
                       // Display the CORRECT order using ElementRenderer
                       ListView.builder(
                         shrinkWrap: true,
                         physics: const NeverScrollableScrollPhysics(),
                         itemCount: correctOrder.length,
                         itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                children: [
                                  Text("${index + 1}. ", style: ColorWheel.secondaryTextStyle),
                                  Expanded(child: ElementRenderer(elements: [correctOrder[index]])),
                                ],
                              ),
                            );
                         }),
                       // Optionally display answer explanation if available
                       if (answerElements.isNotEmpty) ...[
                         const SizedBox(height: ColorWheel.standardPaddingValue),
                         const Divider(),
                         const SizedBox(height: ColorWheel.relatedElementSpacing),
                         ElementRenderer(elements: answerElements),
                       ]
                     ],
                   ),
                 ),
              ),

            // --- Submit / Next Question Buttons ---
            if (!_isAnswerSubmitted)
              Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: ElevatedButton(
                   style: ElevatedButton.styleFrom(backgroundColor: ColorWheel.accent), // Use accent for submit?
                   onPressed: _handleSubmitAnswer,
                   child: const Text('Submit Answer', style: ColorWheel.buttonTextBold),
                 ),
              ),
              
            if (_isAnswerSubmitted)
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
