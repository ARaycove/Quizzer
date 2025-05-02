import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'widget_home_page_top_bar.dart'; // Import the refactored Top Bar
// Import the question widget from its new location
import 'question_widgets/widget_multiple_choice_question.dart'; 
import 'question_widgets/widget_select_all_that_apply_question.dart'; // Added import
import 'question_widgets/widget_true_false_question.dart'; // Added import
import 'question_widgets/widget_sort_order_question.dart'; // Added import
// TODO: Import other actual question widgets as they are implemented.

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
      body: _buildQuestionBody(), // Pass session implicitly via state field
    );
  }

  /// Selects and returns the appropriate widget based on the current question type.
  Widget _buildQuestionBody() {
    // Use ValueKey with currentQuestionId to ensure widget state resets for new questions
    final key = ValueKey(session.currentQuestionId);
    
    switch (session.currentQuestionType) {
      case 'multiple_choice':
        return MultipleChoiceQuestionWidget(key: key, onNextQuestion: _requestNextQuestion);

      case 'select_all_that_apply': 
        return SelectAllThatApplyQuestionWidget(key: key, onNextQuestion: _requestNextQuestion);

      case 'true_false': 
        return TrueFalseQuestionWidget(key: key, onNextQuestion: _requestNextQuestion);
        
      case 'sort_order': 
        return SortOrderQuestionWidget(key: key, onNextQuestion: _requestNextQuestion);

      // --- Add placeholders for other known types ---
      // case 'matching':
      //   return MatchingWidget(key: key, onNextQuestion: _requestNextQuestion);

      default:
        // Also give error display a key in case it needs to update
        return Center(
          key: key, 
          child: Text(
            'Error: Unsupported or missing question type (${session.currentQuestionType})',
            style: const TextStyle(color: ColorWheel.warning),
          ),
        );
    }
  }
}