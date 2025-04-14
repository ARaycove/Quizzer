import 'package:flutter/material.dart';
import 'package:quizzer/ui_pages/custom_widgets/home_page_center_button.dart';
import 'package:quizzer/ui_pages/custom_widgets/home_page_top_bar.dart';
import 'package:quizzer/ui_pages/custom_widgets/home_page_response_system.dart';
import 'package:quizzer/backend/session_manager.dart';
import 'package:quizzer/database/tables/user_profile_table.dart';
import 'package:quizzer/database/tables/tutorial_questions.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Boolean flags indicating the state of the flag dialog and the other options submenu
  bool _showFlagDialog                          = false;
  bool _showOtherOptions                        = false;
  final TextEditingController _flagController   = TextEditingController();
  final SessionManager _sessionManager          = SessionManager();

  // Current question-answer pair data
  // {type: text, content: question}
  List<Map<String, dynamic>> _questionElements  = [];
  // {type: text, content: answer}
  List<Map<String, dynamic>> _answerElements    = [];
  // initialize variable (value means nothing)
  int _currentTutorialProgress                  = 0;

  @override
  void initState() {
    super.initState();
    // Check tutorial status and load appropriate question
    _checkTutorialStatus();
  }

  Future<void> _checkTutorialStatus() async {
    // Get user ID from session manager, throw error if no user ID is found
    final userId = _sessionManager.userId;
    if (userId == null) {
      throw Exception('No user ID found in session. User must be logged in to check tutorial status.');
    }

    print('DEBUG: Checking tutorial status for user: $userId');
    _currentTutorialProgress = await getTutorialProgress(userId);
    print('DEBUG: Current tutorial progress: $_currentTutorialProgress');
    
    // TODO: Should be dynamic based on the number of tutorial questions in the tutorial table
    // TODO: Also, should be based on the user's progress in the tutorial
    if (_currentTutorialProgress < 5) { 
      print('DEBUG: Loading tutorial question $_currentTutorialProgress');
      // Load tutorial question
      await _loadTutorialQuestion(_currentTutorialProgress);
    } else {
      print('DEBUG: Tutorial completed, loading regular question');
      // Load regular question
      _loadRegularQuestion();
    }
  }


  Future<void> _loadTutorialQuestion(int questionNumber) async {
    print('DEBUG: Loading tutorial question $questionNumber');
    final tutorialId = 'tutorial_${(questionNumber + 1).toString().padLeft(2, '0')}';
    print('DEBUG: Tutorial ID: $tutorialId');
    
    final tutorialQuestion = await getTutorialQuestion(tutorialId);
    if (tutorialQuestion == null) {
      throw Exception('Failed to load tutorial question $tutorialId. Tutorial question not found in database.');
    }

    print('DEBUG: Successfully loaded tutorial question');
    setState(() {
      _sessionManager.setCurrentQuestionId(tutorialId);
      _questionElements = [
        {'type': 'text', 'content': tutorialQuestion['question']!},
      ];
      _answerElements = [
        {'type': 'text', 'content': tutorialQuestion['answer']!},
      ];
      _sessionManager.setQuestionPresentedTime();
    });
  }

  void _loadRegularQuestion() {
    // TODO: Replace with actual database call
    setState(() {
      _sessionManager.setCurrentQuestionId("q123");
      _questionElements = [
        {'type': 'text', 'content': 'What is the Ebbinghaus forgetting curve and who discovered it?'},
      ];
      _answerElements = [
        {'type': 'text', 'content': 'The Ebbinghaus forgetting curve is a mathematical model that describes the rate at which information is forgotten over time when there is no attempt to retain it. It was discovered by Hermann Ebbinghaus in the 1880s and later confirmed in 2015 by Murre and Dros.'},
      ];
      _sessionManager.setQuestionPresentedTime();
    });
  }

  @override
  void dispose() {
    _flagController.dispose();
    super.dispose();
  }

  // Function to flip the card and show answer or question
  void _flipCard() {
    setState(() {
      _sessionManager.toggleCardSide();
      
      // Only set questionAnsweredTime if this is the first flip
      if (!_sessionManager.hasBeenFlipped) {
        _sessionManager.setHasBeenFlipped(true);
        _sessionManager.setQuestionAnsweredTime();
        _sessionManager.buttonsEnabled = true;
      }
    });
  }

  // Function to handle user response
  Future<void> _handleResponse(String status) async {
    final userId = _sessionManager.userId;
    if (userId == null) {
      throw Exception('No user ID found in session. User must be logged in to handle responses.');
    }

    // Check if this was a tutorial question and increment progress if needed
    final currentQuestionId = _sessionManager.currentQuestionId;
    if (currentQuestionId != null && currentQuestionId.startsWith('tutorial_')) {
      // Increment tutorial progress
      final newProgress = _currentTutorialProgress + 1;
      await updateTutorialProgress(userId, newProgress);
      _currentTutorialProgress = newProgress;
    }

    // Reset state and load next question
    setState(() {
      _sessionManager.toggleCardSide();
      _showOtherOptions = false;
      _sessionManager.resetQuestionState();
    });

    // Check tutorial status to load next question
    await _checkTutorialStatus();
  }

  // Function to handle flag submission
  void _submitFlag() {
    // This would call flagQuestionAnswerPair() in a real implementation
    // TODO Write the database functions for the Flag submission table
    // TODO integrate this function to submit the data to the backend
    print('Flag submitted: ${_flagController.text}');
    setState(() {
      _showFlagDialog = false;
      _flagController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      appBar: HomePageTopBar(
        onMenuPressed: () {
          // This would navigate to the menu page
          // FIXME Implement redirect function to Menu Page
          // TODO need to actually write up the Menu Page
          print('Menu button pressed');
        },
        showFlagDialog: _showFlagDialog,
        flagController: _flagController,
        onSubmitFlag: _submitFlag,
        onCancelFlag: () {
          setState(() {
            _showFlagDialog = false;
            _flagController.clear();
          });
        },
      ),
      body: GestureDetector(
        // Add click-off functionality to dismiss Other options submenu
        onTap: () {
          if (_showOtherOptions) {
            setState(() {
              _showOtherOptions = false;
            });
          }
        },
        child: Column(
          children: [
            // Question/Answer card area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: HomePageCenterButton(
                  questionElements: _questionElements,
                  answerElements: _answerElements,
                  onFlip: _flipCard,
                  isShowingAnswer: !_sessionManager.isQuestionSideActive,
                ),
              ),
            ),
            
            // Response system
            HomePageResponseSystem(
              showOtherOptions: _showOtherOptions,
              buttonsEnabled: _sessionManager.buttonsEnabled,
              onOtherOptionsToggle: () {
                setState(() {
                  _showOtherOptions = !_showOtherOptions;
                });
              },
              onResponse: _handleResponse,
            ),
          ],
        ),
      ),
    );
  }
}