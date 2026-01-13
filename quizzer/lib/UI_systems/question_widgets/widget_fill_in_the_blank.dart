import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/global_widgets/question_answer_element.dart';
import 'package:quizzer/app_theme.dart';
import 'package:math_keyboard/math_keyboard.dart';

// ==========================================
//    Fill in the Blank Question Widget
// ==========================================

class FillInTheBlankQuestionWidget extends StatefulWidget {
  // Data passed in
  final List<Map<String, dynamic>> questionElements;
  final List<Map<String, dynamic>> answerElements;
  final Map<String, dynamic> questionData; // Full question data for validation
  final bool isDisabled;
  
  // New optional parameters for state control
  final bool autoSubmitAnswer; // If true, automatically submit answer
  final List<String>? customUserAnswers; // Must be provided if autoSubmitAnswer is true
  
  // Callback
  final VoidCallback onNextQuestion;

  const FillInTheBlankQuestionWidget({
    super.key,
    required this.questionElements,
    required this.answerElements,
    required this.questionData,
    required this.onNextQuestion,
    this.isDisabled = false,
    this.autoSubmitAnswer = false,
    this.customUserAnswers,
  });

  @override
  State<FillInTheBlankQuestionWidget> createState() =>
      _FillInTheBlankQuestionWidgetState();
}

class _FillInTheBlankQuestionWidgetState
    extends State<FillInTheBlankQuestionWidget> {
      
  final SessionManager _session = SessionManager();
  
  // State for managing blank inputs
  final Map<int, dynamic> _blankControllers = {};
  List<bool> _individualBlankResults = [];
  final List<bool> _blankIsMathExpression = [];
  bool _isAnswerSubmitted = false;
  bool? _isOverallCorrect;
  Set<String> formattedCorrectAnswers = {};

  @override
  void initState() {
    super.initState();
    QuizzerLogger.logMessage("FillInTheBlankQuestionWidget initState");
    _initializeControllers();
  }

  @override
  void didUpdateWidget(covariant FillInTheBlankQuestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if core data has changed
    if (widget.autoSubmitAnswer != oldWidget.autoSubmitAnswer || widget.customUserAnswers != oldWidget.customUserAnswers) {
      QuizzerLogger.logMessage("FillInTheBlankQuestionWidget didUpdateWidget: Data changed, reinitializing.");
      QuizzerLogger.logMessage("Comparing what triggered change state widget =? oldWidget:");
      QuizzerLogger.logMessage("autoSubmitAnswer : ${widget.autoSubmitAnswer} =? ${oldWidget.autoSubmitAnswer}");
      QuizzerLogger.logMessage("customUserAnswers: ${widget.customUserAnswers} =? ${oldWidget.customUserAnswers}");
      _initializeControllers();
    } else {
      QuizzerLogger.logMessage("FillInTheBlankQuestionWidget didUpdateWidget: Data same, no reinit.");
    }
  }

  void _initializeControllers() {
    // Dispose of existing controllers and clear the map
    for (var controller in _blankControllers.values) {
      if (controller is TextEditingController) {
        controller.dispose();
      } else if (controller is MathFieldEditingController) {
        controller.dispose();
      }
    }
    _blankControllers.clear();
    _blankIsMathExpression.clear(); // Clear the list here

    // Count blank elements and create controllers
    int blankIndex = 0;
    List<String> correctAnswers = []; // Extract correct answers for preview
    
    // Get answers from answers_to_blanks
    final answersToBlanks = widget.questionData['answers_to_blanks'] as List<Map<String, List<String>>>?;
    
    for (int i = 0; i < widget.questionElements.length; i++) {
      final element = widget.questionElements[i];
      if (element['type'] == 'blank') {
        dynamic controller;
        
        // Determine if it's a math expression
        bool isMath = false;
        String correctAnswer = '';
        if (answersToBlanks != null && blankIndex < answersToBlanks.length) {
          correctAnswer = answersToBlanks[blankIndex].keys.first;
          
          String valType = SessionManager().getFillInTheBlankValidationType(correctAnswer);
          if (valType == "math_expression") {
            isMath = true;
            formattedCorrectAnswers.add("\$$correctAnswer\$");
          } else {
            formattedCorrectAnswers.add(correctAnswer);
          }
        }
        _blankIsMathExpression.add(isMath);
        
        // CRITICAL CHANGE: Create the correct controller type
        if (isMath) {
          controller = MathFieldEditingController();
          if (widget.customUserAnswers != null && blankIndex < widget.customUserAnswers!.length) {
            controller.updateValue(TeXParser(widget.customUserAnswers![blankIndex]).parse());
          } else if (widget.isDisabled && correctAnswer.isNotEmpty) {
            controller.updateValue(TeXParser(correctAnswer).parse());
          }
        } else {
          controller = TextEditingController();
          if (widget.customUserAnswers != null && blankIndex < widget.customUserAnswers!.length) {
            controller.text = widget.customUserAnswers![blankIndex];
          } else if (widget.isDisabled && correctAnswer.isNotEmpty) {
            controller.text = correctAnswer;
          }
        }
        
        correctAnswers.add(correctAnswer);
        _blankControllers[i] = controller;
        blankIndex++;
      }
    }

    // Set auto-submit state if needed
    bool shouldAutoSubmit = widget.isDisabled || widget.autoSubmitAnswer;
    if (shouldAutoSubmit) {
      _isAnswerSubmitted = true;
      _isOverallCorrect = widget.isDisabled ? true : null; // Assume correct for disabled preview
      
      if (widget.isDisabled && correctAnswers.isNotEmpty) {
        _individualBlankResults = List<bool>.filled(correctAnswers.length, true); // All correct in preview
        QuizzerLogger.logMessage("FillInTheBlankWidget: Auto-submit state, auto-setting submitted=true for preview with ${correctAnswers.length} correct answers.");
      }
    } else {
      _isAnswerSubmitted = false;
      _isOverallCorrect = null;
      _individualBlankResults = [];
    }
    
    if (widget.isDisabled && mounted) {
      setState(() {});
    }
  }

  Future<void> _handleSubmitAnswer() async {
    // Disable if needed
    if (widget.isDisabled || _isAnswerSubmitted) return;

    QuizzerLogger.logMessage('Submitting fill-in-the-blank answer...');
    
    // Collect user answers in order
    List<String> userAnswers = [];
    for (int i = 0; i < widget.questionElements.length; i++) {
      final element = widget.questionElements[i];
      if (element['type'] == 'blank') {
        final controller = _blankControllers[i];
        if (controller != null) {
          if (controller is MathFieldEditingController) {
            userAnswers.add(controller.currentEditingValue());
          } else if (controller is TextEditingController) {
            userAnswers.add(controller.text);
          }
        }
      }
    }

    setState(() {
      _isAnswerSubmitted = true;
    });

    try {
      final validationResult = await _session.validateFillInTheBlankAnswer(userAnswers);
      
      setState(() {
        _isOverallCorrect = validationResult['isCorrect'];
        _individualBlankResults = List<bool>.from(validationResult['ind_blanks']);
      });

      _session.setCurrentQuestionUserAnswer(userAnswers);
      _session.setCurrentQuestionIsCorrect(validationResult['isCorrect']);
      _session.submitAnswer(userAnswer: userAnswers);
      QuizzerLogger.logSuccess('Answer submission initiated (Fill in the Blank).');
    } catch (e) {
      QuizzerLogger.logError('Sync error submitting answer (Fill in the Blank): $e');
      setState(() {
        _isAnswerSubmitted = false;
        _isOverallCorrect = null;
        _individualBlankResults = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting: ${e.toString()}')),
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
  void dispose() {
    // Dispose all controllers, checking their type first
    for (var controller in _blankControllers.values) {
      if (controller is TextEditingController) {
        controller.dispose();
      } else if (controller is MathFieldEditingController) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    QuizzerLogger.logValue("FillInTheBlank build. Disabled: ${widget.isDisabled}, Submitted: $_isAnswerSubmitted, Overall Correct: $_isOverallCorrect");
    
    if (widget.questionElements.isEmpty) {
      return const Center(child: Text("No question data provided."));
    }

    // Generate correct answer elements from answers_to_blanks
    List<Map<String, dynamic>> correctAnswerElements = [];
    final answersToBlanks = widget.questionData['answers_to_blanks'] as List<Map<String, List<String>>>?;
    if (answersToBlanks != null) {
      for (final answerGroup in answersToBlanks) {
        final correctAnswer = answerGroup.keys.first;
        if (correctAnswer.isNotEmpty) {
          correctAnswerElements.add({
            'type': 'text',
            'content': correctAnswer,
          });
        }
      }
    }

    // Determine if interactions should be enabled
    final bool interactionsEnabled = !widget.isDisabled && !_session.isCurrentQuestionAnswered;

    // PRESERVE functional feedback colors for correctness states
    const Color correctColor = Colors.green;
    const Color incorrectColor = Colors.red;
    const Color lighterCorrectColor = Color.fromRGBO(0, 255, 0, 0.1); // Lighter green background
    const Color lighterIncorrectColor = Color.fromRGBO(255, 0, 0, 0.1); // Lighter red background

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Question Elements with Blank Controllers ---
          // NOTE: ElementRenderer will need to be updated to accept the
          // 'blankIsMathExpression' list and pass the corresponding
          // boolean to each WidgetBlank.
          ElementRenderer(
            elements: widget.questionElements,
            blankControllers: _blankControllers,
            individualBlankResults: _individualBlankResults.isNotEmpty ? _individualBlankResults : null,
            enabled: interactionsEnabled, // Disable blanks after submission
            blankIsMathExpression: _blankIsMathExpression, // NEW: Pass down the list
          ),
          AppTheme.sizedBoxLrg,

          // --- Individual Blank Feedback (Show After Submission) ---
          if (_isAnswerSubmitted && _individualBlankResults.isNotEmpty && !widget.isDisabled)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Individual Blank Results:", style: TextStyle(fontWeight: FontWeight.bold)),
                AppTheme.sizedBoxSml,
                ...List.generate(_individualBlankResults.length, (index) {
                  final isCorrect = _individualBlankResults[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                      decoration: BoxDecoration(
                        color: isCorrect ? lighterCorrectColor : lighterIncorrectColor,
                        border: Border.all(
                          color: isCorrect ? correctColor : incorrectColor,
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCorrect ? Icons.check_circle : Icons.cancel,
                            color: isCorrect ? correctColor : incorrectColor,
                            size: 20,
                          ),
                          AppTheme.sizedBoxSml,
                          Text(
                            "Blank ${index + 1}: ${isCorrect ? 'Correct' : 'Incorrect'}",
                            style: TextStyle(
                              color: isCorrect ? correctColor : incorrectColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                AppTheme.sizedBoxLrg,
              ],
            ),

          // --- Overall Feedback (Show After Submission) ---
          if (_isAnswerSubmitted && _isOverallCorrect != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              decoration: BoxDecoration(
                color: _isOverallCorrect! ? lighterCorrectColor : lighterIncorrectColor,
                border: Border.all(
                  color: _isOverallCorrect! ? correctColor : incorrectColor,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                _isOverallCorrect! ? "All Blanks Correct!" : "Some Blanks Incorrect",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isOverallCorrect! ? correctColor : incorrectColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          // --- Answer Elements / Correct Answers (Show After Submission) ---
          if (_isAnswerSubmitted || widget.isDisabled)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Correct Answers:", style: TextStyle(fontWeight: FontWeight.bold)),
                AppTheme.sizedBoxSml,
                ElementRenderer(
                  // Map the list of strings into the required List<Map<String, dynamic>>
                  // format for the ElementRenderer. Each element will have a 'type' of 'text'
                  // and its 'content' will be the string itself.
                  elements: formattedCorrectAnswers.map((answer) => {
                    'type': 'text',
                    'content': answer,
                  }).toList(),
                ),
                AppTheme.sizedBoxLrg,
              ],
            ),

          // --- Answer Explanation Elements (Show in Preview or After Submission) ---
          if ((_isAnswerSubmitted || widget.isDisabled) && widget.answerElements.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Answer Explanation:", style: TextStyle(fontWeight: FontWeight.bold)),
                AppTheme.sizedBoxSml,
                ElementRenderer(elements: widget.answerElements),
                AppTheme.sizedBoxLrg,
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
