import 'dart:async'; // Added for Timer
import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/app_theme.dart';
import 'widget_home_page_top_bar.dart'; // Import the refactored Top Bar
// Corrected package imports for MOVED question widgets
import 'package:quizzer/UI_systems/question_widgets/widget_multiple_choice_question.dart'; 
import 'package:quizzer/UI_systems/question_widgets/widget_select_all_that_apply_question.dart'; 
import 'package:quizzer/UI_systems/question_widgets/widget_true_false_question.dart'; 
import 'package:quizzer/UI_systems/question_widgets/widget_sort_order_question.dart';
import 'package:quizzer/UI_systems/question_widgets/widget_fill_in_the_blank.dart'; 
import 'package:quizzer/UI_systems/global_widgets/widget_quizzer_background.dart';
import 'package:math_expressions/math_expressions.dart';
/// HomePage acts as the main container, displaying the appropriate question widget.
class HomePage extends StatefulWidget { // Change to StatefulWidget
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState(); // Create state
}

class _HomePageState extends State<HomePage> { // State class
  final SessionManager session = SessionManager();
  Map<String, dynamic>? _editedQuestionData; // <-- ADDED State variable for callback data
  ExpressionParser p = GrammarParser();

  @override
  void initState() {
    super.initState();
    // Call requestNextQuestion after the first frame to ensure session is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNextQuestion();
    });
  }

  // Method to handle requesting the next question and triggering rebuild
  Future<void> _requestNextQuestion() async {
    _editedQuestionData = null; // Clear any edited data when requesting next
    
    // Clear submission data when requesting next question
    // This ensures the new question starts in unsubmitted state
    session.clearCurrentQuestionSubmissionData();
    
    await session.requestNextQuestion();
    // Ensure widget is still mounted before calling setState
    if (mounted) { 
      setState(() {}); // Trigger rebuild to show the new question and updated stats
    }
  }

  // --- ADDED: Method to handle data returned from EditQuestionDialog ---
  Future<void> _handleQuestionEdited(Map<String, dynamic> updatedData) async {
    QuizzerLogger.logMessage('HomePage: Question edited, storing data and triggering rebuild.');
    // Store the edited data locally in the state
    _editedQuestionData = updatedData;
    
    if (mounted) {
      setState(() {}); // Trigger rebuild to reflect edited question data
    }
  }

  // --- ADDED: Method to handle question flagging ---
  void _handleQuestionFlagged(Map<String, dynamic> flagResult) {
    QuizzerLogger.logMessage('HomePage: Question flagged - ${flagResult['message']}');
    
    // Check if the flag was successful
    final bool success = flagResult['success'] as bool? ?? false;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(flagResult['message']),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    
    // Only request next question if the flag was successful
    if (success) {
      _requestNextQuestion();
    }
  }



  @override
  Widget build(BuildContext context) {
    final FocusNode backgroundFocusNode = FocusNode();

    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!backgroundFocusNode.hasFocus) {
          currentFocus.requestFocus(backgroundFocusNode);
        }
      },
      child: Scaffold(
        appBar: HomePageTopBar( 
          onMenuPressed: () {
            Navigator.pushNamed(context, '/menu');
          },
          onQuestionEdited: _handleQuestionEdited,
          onQuestionFlagged: _handleQuestionFlagged,
        ),
        body: Stack(
          children: [
            Focus(
              focusNode: backgroundFocusNode,
              child: const QuizzerBackground(),
            ),
            Column(
              children: [
                AppTheme.sizedBoxMed,
                Expanded(child: _buildQuestionBody()),
              ],
            ),
          ],
        ), 
      ),
    );
  }

  /// Selects and returns the appropriate widget based on the current question type.
  Widget _buildQuestionBody() {
    // Check if there's a current question loaded
    if (session.currentQuestionStaticData == null) {
      return const Center(
        child: Text('No question loaded. Please wait...'),
      );
    }
    
    // Use ValueKey with currentQuestionId to ensure widget state resets for new questions
    final String currentQuestionId = session.currentQuestionId;
    final key = ValueKey(currentQuestionId);

    // Determine data source: edited data if available, otherwise session
    final Map<String, dynamic>? dataSource = _editedQuestionData;
    final String questionType = dataSource?['question_type'] as String? ?? session.currentQuestionType;
    final List<Map<String, dynamic>> questionElements = (dataSource?['question_elements'] as List<dynamic>? ?? session.currentQuestionElements).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final List<Map<String, dynamic>> answerElements = (dataSource?['answer_elements'] as List<dynamic>? ?? session.currentQuestionAnswerElements).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final List<Map<String, dynamic>> options = (dataSource?['options'] as List<dynamic>? ?? session.currentQuestionOptions).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final int? correctOptionIndex = dataSource?['correct_option_index'] as int? ?? session.currentCorrectOptionIndex;
    final List<int> correctIndices = (dataSource?['index_options_that_apply'] as List<dynamic>? ?? session.currentCorrectIndices).map((e) => e as int).toList();
    final List<Map<String, List<String>>> answersToBlanks = (dataSource?['answers_to_blanks'] as List<dynamic>? ?? session.currentAnswersToBlanks).map((e) => Map<String, List<String>>.from(e as Map)).toList();

    // Check if we have submission data for answered state reconstruction
    final bool hasSubmissionData = session.lastSubmittedUserAnswer != null;
    final bool shouldAutoSubmit = hasSubmissionData;

    // Extract submission data for passing to widgets
    final List<int>? customOrderIndices = session.lastSubmittedCustomOrderIndices;
    final dynamic submittedUserAnswer = session.lastSubmittedUserAnswer;

    // IMPORTANT: No longer clearing _editedQuestionData here. It's cleared in _requestNextQuestion.

    QuizzerLogger.logValue("HomePage building question type: $questionType with key: $key (using ${dataSource != null ? 'edited data' : 'session data'}) - AutoSubmit: $shouldAutoSubmit");

    switch (questionType) {
      case 'multiple_choice':
        return MultipleChoiceQuestionWidget(
          key: key, 
          onNextQuestion: _requestNextQuestion,
          questionElements: questionElements, // Use local variable
          answerElements: answerElements, // Use local variable
          options: options, // Use local variable
          correctOptionIndex: correctOptionIndex ?? -1, // Handle null, though validation should prevent it
          autoSubmitAnswer: shouldAutoSubmit, // Pass auto-submit flag
          customOrderIndices: customOrderIndices, // Pass custom order indices
          selectedIndex: submittedUserAnswer as int?, // Pass selected index
        );

      case 'select_all_that_apply': 
        return SelectAllThatApplyQuestionWidget(
          key: key, 
          onNextQuestion: _requestNextQuestion,
          questionElements: questionElements, // Use local variable
          answerElements: answerElements, // Use local variable
          options: options, // Use local variable
          correctIndices: correctIndices, // Use local variable
          autoSubmitAnswer: shouldAutoSubmit, // Pass auto-submit flag
          customOrderIndices: customOrderIndices, // Pass custom order indices
          selectedIndices: submittedUserAnswer as List<int>?, // Pass selected indices
        );

      case 'true_false': 
        if (correctOptionIndex == null || (correctOptionIndex != 0 && correctOptionIndex != 1)) {
             return _buildErrorWidget('Invalid correct index ($correctOptionIndex) for true_false', key);
        }
        return TrueFalseQuestionWidget(
          key: key, 
          onNextQuestion: _requestNextQuestion,
          questionElements: questionElements, // Use local variable
          answerElements: answerElements, // Use local variable
          isCorrectAnswerTrue: correctOptionIndex == 0, // 0 is convention for True
          autoSubmitAnswer: shouldAutoSubmit, // Pass auto-submit flag
          customOrderIndices: customOrderIndices, // Pass custom order indices (for True/False order)
          selectedAnswer: submittedUserAnswer as bool?, // Pass selected answer
        );
        
      case 'sort_order': 
        return SortOrderQuestionWidget(
          key: key, 
          onNextQuestion: _requestNextQuestion,
          questionElements: questionElements, // Use local variable
          answerElements: answerElements, // Use local variable
          options: options, // Use the correctly ordered options from edited data or session
          autoSubmitAnswer: shouldAutoSubmit, // Pass auto-submit flag
          customOrderIndices: customOrderIndices, // Pass custom order indices
          customUserOrder: submittedUserAnswer as List<Map<String, dynamic>>?, // Pass custom user order
        );

      case 'fill_in_the_blank':
        return FillInTheBlankQuestionWidget(
          key: key,
          onNextQuestion: _requestNextQuestion,
          questionElements: questionElements, // Use local variable
          answerElements: answerElements, // Use local variable
          questionData: dataSource ?? {
            'question_type': questionType,
            'answers_to_blanks': answersToBlanks,
          }, // Pass full question data for validation
          autoSubmitAnswer: shouldAutoSubmit, // Pass auto-submit flag
          customUserAnswers: submittedUserAnswer as List<String>?, // Pass custom user answers
        );

      // --- Add placeholders for other known types ---
      // case 'matching':
      //   return MatchingWidget(key: key, onNextQuestion: _requestNextQuestion);

      default:
        // Use session's type if dataSource is null, otherwise use the type from dataSource
        final displayType = dataSource?['question_type'] as String? ?? session.currentQuestionType;
        return _buildErrorWidget('Unsupported or missing question type ($displayType)', key);
    }
  }
  
  // Helper widget to display errors consistently
  Widget _buildErrorWidget(String message, Key key) {
      QuizzerLogger.logError("HomePage - Building Error Widget: $message");
      return Center(
         key: key, 
         child: Text(
           'Error: $message',
           textAlign: TextAlign.center,
         ),
       );
  }
}