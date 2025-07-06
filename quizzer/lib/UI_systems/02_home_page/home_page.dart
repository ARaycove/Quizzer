import 'dart:async'; // Added for Timer
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
/// HomePage acts as the main container, displaying the appropriate question widget.
class HomePage extends StatefulWidget { // Change to StatefulWidget
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState(); // Create state
}

class _HomePageState extends State<HomePage> { // State class
  final SessionManager session = SessionManager(); // Get session instance once
  Map<String, dynamic>? _editedQuestionData; // <-- ADDED State variable for callback data
  Timer? _retryTimer; // Added for retry mechanism
  static const String _dummyQuestionId = "dummy_no_questions"; // Corrected ID for the dummy/placeholder question

  @override
  void initState() {
    super.initState();
    // Initial check and start retry if needed
    // Call _checkAndRetryFetchingQuestion after the first frame to ensure session is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRetryFetchingQuestion();
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _checkAndRetryFetchingQuestion() {
    if (!mounted) return; // Don't do anything if the widget is disposed

    if (session.currentQuestionId == _dummyQuestionId) {
      QuizzerLogger.logMessage('HomePage: Current question is dummy ($_dummyQuestionId). Starting/Continuing retry timer.');
      if (_retryTimer == null || !_retryTimer!.isActive) {
        _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          QuizzerLogger.logMessage('HomePage: Retry timer triggered. Requesting next question.');
          if (session.currentQuestionId != _dummyQuestionId) { // Double check before requesting, in case it changed
            timer.cancel();
            QuizzerLogger.logMessage('HomePage: Dummy question resolved before request. Timer cancelled.');
            _checkAndRetryFetchingQuestion(); // Final check to ensure timer is truly stopped if condition met
          } else {
            _requestNextQuestion(); // This will call _checkAndRetryFetchingQuestion again after fetch
          }
        });
      }
    } else {
      QuizzerLogger.logMessage('HomePage: Current question is NOT dummy. Stopping retry timer. ID: ${session.currentQuestionId}');
      _retryTimer?.cancel();
      _retryTimer = null; // Clear the timer instance
    }
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
      setState(() {}); // Trigger rebuild to show the new question
      _checkAndRetryFetchingQuestion(); // Check and manage retry timer after fetching
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorWheel.primaryBackground,
      appBar: HomePageTopBar( 
        onMenuPressed: () {
          Navigator.pushNamed(context, '/menu');
        },
        onQuestionEdited: _handleQuestionEdited,
      ),
      // Directly build the body, assuming SessionManager handles its initialization
      body: _buildQuestionBody(), 
    );
  }

  // TODO Add in "read question" button, that reads the question and it's answer, first need to build that service into the API.
  /// Selects and returns the appropriate widget based on the current question type.
  Widget _buildQuestionBody() {
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