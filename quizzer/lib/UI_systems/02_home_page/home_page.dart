import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'widget_home_page_top_bar.dart'; // Import the refactored Top Bar
// Corrected package imports for MOVED question widgets
import 'package:quizzer/UI_systems/question_widgets/widget_multiple_choice_question.dart'; 
import 'package:quizzer/UI_systems/question_widgets/widget_select_all_that_apply_question.dart'; 
import 'package:quizzer/UI_systems/question_widgets/widget_true_false_question.dart'; 
import 'package:quizzer/UI_systems/question_widgets/widget_sort_order_question.dart'; 
// TODO: Add in Edit Question option next to Flag Icon, should give a pop-up dialog that allows the user to edit the currently active quesiton -> changing it in the DB and signalling a sync(handled at low level)


// TODO: Import other actual question widgets as they are implemented. 6 left

/// HomePage acts as the main container, displaying the appropriate question widget.
class HomePage extends StatefulWidget { // Change to StatefulWidget
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState(); // Create state
}

class _HomePageState extends State<HomePage> { // State class
  final SessionManager session = SessionManager(); // Get session instance once

  // Method to handle requesting the next question and triggering rebuild
  Future<void> _requestNextQuestion() async {
    await session.requestNextQuestion();
    // Ensure widget is still mounted before calling setState
    if (mounted) { 
      setState(() {}); // Trigger rebuild to show the new question
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorWheel.primaryBackground,
      appBar: HomePageTopBar( 
        onMenuPressed: () {
          session.addPageToHistory('/menu'); 
          Navigator.pushNamed(context, '/menu');
        },
      ),
      // Directly build the body, assuming SessionManager handles its initialization
      body: _buildQuestionBody(), 
    );
  }

  // TODO Add in "read question" button, that reads the question and it's answer, first need to build that service into the API.
  /// Selects and returns the appropriate widget based on the current question type.
  Widget _buildQuestionBody() {
    // Use ValueKey with currentQuestionId to ensure widget state resets for new questions
    final key = ValueKey(session.currentQuestionId);
    
    // Fetch data DIRECTLY from session manager when needed
    QuizzerLogger.logValue("HomePage building question type: ${session.currentQuestionType} with key: $key");

    switch (session.currentQuestionType) {
      case 'multiple_choice':
        final correctIndex = session.currentCorrectOptionIndex;
        if (correctIndex == null) {
             return _buildErrorWidget('Missing correct index for multiple_choice', key);
        }
        return MultipleChoiceQuestionWidget(
          key: key, 
          onNextQuestion: _requestNextQuestion,
          questionElements: session.currentQuestionElements,
          answerElements: session.currentQuestionAnswerElements,
          options: session.currentQuestionOptions,
          correctOptionIndex: correctIndex,
        );

      case 'select_all_that_apply': 
        return SelectAllThatApplyQuestionWidget(
          key: key, 
          onNextQuestion: _requestNextQuestion,
          questionElements: session.currentQuestionElements,
          answerElements: session.currentQuestionAnswerElements,
          options: session.currentQuestionOptions,
          correctIndices: session.currentCorrectIndices,
        );

      case 'true_false': 
        final correctIndex = session.currentCorrectOptionIndex;
        if (correctIndex == null || (correctIndex != 0 && correctIndex != 1)) {
             return _buildErrorWidget('Invalid correct index ($correctIndex) for true_false', key);
        }
        return TrueFalseQuestionWidget(
          key: key, 
          onNextQuestion: _requestNextQuestion,
          questionElements: session.currentQuestionElements,
          answerElements: session.currentQuestionAnswerElements,
          isCorrectAnswerTrue: correctIndex == 0, // 0 is convention for True
        );
        
      case 'sort_order': 
        return SortOrderQuestionWidget(
          key: key, 
          onNextQuestion: _requestNextQuestion,
          questionElements: session.currentQuestionElements,
          answerElements: session.currentQuestionAnswerElements,
          options: session.currentQuestionOptions, // Pass the correctly ordered options
        );

      // --- Add placeholders for other known types ---
      // case 'matching':
      //   return MatchingWidget(key: key, onNextQuestion: _requestNextQuestion);

      default:
        return _buildErrorWidget('Unsupported or missing question type (${session.currentQuestionType})', key);
    }
  }
  
  // Helper widget to display errors consistently
  Widget _buildErrorWidget(String message, Key key) {
      QuizzerLogger.logError("HomePage - Building Error Widget: $message");
      return Center(
         key: key, 
         child: Padding(
           padding: const EdgeInsets.all(16.0),
           child: Text(
             'Error: $message',
             style: const TextStyle(color: ColorWheel.warning, fontSize: 16),
             textAlign: TextAlign.center,
           ),
         ),
       );
  }
}