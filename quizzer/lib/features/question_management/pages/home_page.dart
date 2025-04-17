import 'package:flutter/material.dart';
import 'package:quizzer/features/question_management/widgets/home_page_center_button.dart';
import 'package:quizzer/features/question_management/widgets/home_page_top_bar.dart';
import 'package:quizzer/features/question_management/widgets/home_page_response_system.dart';
import 'package:quizzer/global/functionality/session_manager.dart';
import 'package:quizzer/features/user_profile_management/database/user_profile_table.dart';
import 'package:quizzer/features/question_management/database/tutorial_questions_table.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';

// TODO: Implement proper error handling for all database operations
// TODO: Add comprehensive logging for all user interactions
// TODO: Add proper validation for all user inputs
// TODO: Flag

// ==========================================
// Widgets
class HomePage extends StatefulWidget {
    const HomePage({super.key});

    @override
    State<HomePage> createState() => _HomePageState();
}
// ------------------------------------------
class _HomePageState extends State<HomePage> {
    bool _showFlagDialog = false;
    bool _showOtherOptions = false;
    final TextEditingController _flagController = TextEditingController();
    final SessionManager _sessionManager = SessionManager();
    int _currentTutorialProgress = 0;

    Future<void> _loadTutorialQuestion(int questionNumber) async {
        // QuizzerLogger.logMessage('Loading tutorial question $questionNumber');
        final tutorialId = 'tutorial_${(questionNumber + 1).toString().padLeft(2, '0')}';
        // QuizzerLogger.logMessage('Tutorial ID: $tutorialId');
        
        final tutorialQuestion = await getTutorialQuestion(tutorialId);
        if (tutorialQuestion == null) {
            throw Exception('Failed to load tutorial question $tutorialId. Tutorial '
                'question not found in database.');
        }

        // QuizzerLogger.logMessage('Successfully loaded tutorial question');
        // QuizzerLogger.logMessage('Question content: ${tutorialQuestion['question']}');
        // QuizzerLogger.logMessage('Answer content: ${tutorialQuestion['answer']}');
        
        _sessionManager.setCurrentQuestionId(tutorialId);
        _sessionManager.setQuestionPresentedTime();
        
        final questionElements = [
            {'type': 'text', 'content': tutorialQuestion['question']!},
        ];
        final answerElements = [
            {'type': 'text', 'content': tutorialQuestion['answer']!},
        ];
        
        // QuizzerLogger.logMessage('Setting question elements: $questionElements');
        // QuizzerLogger.logMessage('Setting answer elements: $answerElements');
        
        _sessionManager.setQuestionAndAnswerElements(questionElements, answerElements);
    }

    void _loadRegularQuestion() {
        // TODO: Replace with actual database call
        // QuizzerLogger.logMessage('Loading regular question');
        
        _sessionManager.setCurrentQuestionId("q123");
        _sessionManager.setQuestionPresentedTime();
        
        final questionElements = [
            {'type': 'text', 'content': 'What is the Ebbinghaus forgetting curve '
                'and who discovered it?'},
        ];
        final answerElements = [
            {'type': 'text', 'content': 'The Ebbinghaus forgetting curve is a '
                'mathematical model that describes the rate at which information '
                'is forgotten over time when there is no attempt to retain it. '
                'It was discovered by Hermann Ebbinghaus in the 1880s and later '
                'confirmed in 2015 by Murre and Dros.'},
        ];
        
        // QuizzerLogger.logMessage('Setting question elements: $questionElements');
        // QuizzerLogger.logMessage('Setting answer elements: $answerElements');
        
        _sessionManager.setQuestionAndAnswerElements(questionElements, answerElements);
    }

    Future<void> _checkTutorialStatus() async {
        final userId = _sessionManager.userId;
        if (userId == null) {
            throw Exception('No user ID found in session. User must be logged in to '
                'check tutorial status.');
        }

        // QuizzerLogger.logMessage('Checking tutorial status for user: $userId');
        final progress = await getTutorialProgress(userId);
        // QuizzerLogger.logMessage('Current tutorial progress: $progress');
        
        // If the tutorial progress is less than 5, work on the tutorial questions
        if (progress < 5) { 
            // QuizzerLogger.logMessage('Loading tutorial question $progress');
            await _loadTutorialQuestion(progress);
            // QuizzerLogger.logMessage('After _loadTutorialQuestion, question elements: ${_sessionManager.questionElements}');
            // QuizzerLogger.logMessage('After _loadTutorialQuestion, answer elements: ${_sessionManager.answerElements}');
        } 
        // Otherwise, we are in the normal question loop
        else {
            // QuizzerLogger.logMessage('Tutorial completed, loading regular question');
            _loadRegularQuestion();
            // QuizzerLogger.logMessage('After _loadRegularQuestion, question elements: ${_sessionManager.questionElements}');
            // QuizzerLogger.logMessage('After _loadRegularQuestion, answer elements: ${_sessionManager.answerElements}');
        }
        
        // Log the current state after loading
        // QuizzerLogger.logMessage('After loading, question elements: ${_sessionManager.questionElements}');
        // QuizzerLogger.logMessage('After loading, answer elements: ${_sessionManager.answerElements}');
        
        // Trigger a rebuild of the widget to show the new question/answer
        if (mounted) {
            setState(() {});
        }
    }

    Future<void> _handleResponse(String status) async {
        final userId = _sessionManager.userId;
        if (userId == null) {
            throw Exception('No user ID found in session. User must be logged in to '
                'handle responses.');
        }

        final currentQuestionId = _sessionManager.currentQuestionId;
        if (currentQuestionId != null && currentQuestionId.startsWith('tutorial_')) {
            final newProgress = _currentTutorialProgress + 1;
            await updateTutorialProgress(userId, newProgress);
            _currentTutorialProgress = newProgress;
        }

        _sessionManager.toggleCardSide();
        _sessionManager.resetQuestionState();
        await _checkTutorialStatus();
    }

    @override
    void initState() {
        super.initState();
        // QuizzerLogger.logMessage('Initializing HomePage state');
        _checkTutorialStatus();
    }

    @override
    void dispose() {
        _flagController.dispose();
        super.dispose();
    }

    void _flipCard() {
        setState(() {
            _sessionManager.toggleCardSide();
            
            if (!_sessionManager.hasBeenFlipped) {
                _sessionManager.setHasBeenFlipped(true);
                _sessionManager.setQuestionAnsweredTime();
                _sessionManager.buttonsEnabled = true;
            }
        });
    }

    void _submitFlag() {
        // QuizzerLogger.logMessage('Flag submitted: ${_flagController.text}');
        setState(() {
            _showFlagDialog = false;
            _flagController.clear();
        });
    }

    @override
    Widget build(BuildContext context) {
        // QuizzerLogger.logMessage('Building HomePage with question elements: ${_sessionManager.questionElements}');
        // QuizzerLogger.logMessage('Building HomePage with answer elements: ${_sessionManager.answerElements}');
        return Scaffold(
            backgroundColor: const Color(0xFF0A1929),
            appBar: HomePageTopBar(
                onMenuPressed: () {
                    // QuizzerLogger.logMessage('Menu button pressed');
                    Navigator.pushNamed(context, '/menu');
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
                onTap: () {
                    if (_showOtherOptions) {
                        setState(() {
                            _showOtherOptions = false;
                        });
                    }
                },
                child: Column(
                    children: [
                        Expanded(
                            child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: HomePageCenterButton(
                                    questionElements: _sessionManager.questionElements,
                                    answerElements: _sessionManager.answerElements,
                                    onFlip: _flipCard,
                                    isShowingAnswer: 
                                        !_sessionManager.isQuestionSideActive,
                                ),
                            ),
                        ),
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