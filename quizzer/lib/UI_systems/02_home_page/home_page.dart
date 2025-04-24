import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/02_home_page/widget_home_page_top_bar.dart';
import 'package:quizzer/UI_systems/02_home_page/widget_multiple_choice_question.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
// ==========================================
// Widgets
class HomePage extends StatefulWidget {
    const HomePage({super.key});

    @override
    State<HomePage> createState() => _HomePageState();
}
// ------------------------------------------
class _HomePageState extends State<HomePage> {
    final SessionManager session = SessionManager();
    bool _isLoading = true;
    bool _initialQuestionLoaded = false; // Flag to track initial load
    bool _showFlagDialog = false;
    final TextEditingController _flagController = TextEditingController();

    @override
    void initState() {
        super.initState();
        // Only load the initial question once per state lifecycle
        if (!_initialQuestionLoaded) {
            _loadInitialQuestion();
        } else {
            // If returning, data should already be in session, just ensure loading is false
            // This might happen if state is preserved during navigation
             QuizzerLogger.logMessage('HomePage initState: Re-entering, initial question already loaded.');
             // Ensure loading indicator isn't stuck if we return quickly
             if (_isLoading) { 
                 setState(() { _isLoading = false; }); 
             }
        }
    }
    
    // Renamed from initState to avoid async void initState
    Future<void> _loadInitialQuestion() async {
        // Check mounted status at the beginning
        if (!mounted) return;
        setState(() {_isLoading = true;});
        
        bool success = await session.requestNextQuestion();
        
        // Check mounted status again after async gap
        if (!mounted) return; 

        if (success) {
            session.setQuestionDisplayTime(); 
            _initialQuestionLoaded = true; // Mark initial load as complete
            setState(() {_isLoading = false;});
        } else {
             QuizzerLogger.logError('HomePage: Failed to load initial question from session.requestNextQuestion');
             // Keep loading true or set an error state?
             // For now, keep loading true, might need an error display later.
             // Or, set loading false and let _buildBody handle potential null data from session.
             setState(() {_isLoading = false;}); 
        }
    }

    @override
    void dispose() {
        _flagController.dispose();
        super.dispose();
    }

    void _submitFlag() {
        // TODO: Implement question flagging logic using SessionManager
        // This should likely involve getting the current question ID from the session
        // and sending a flag request through the SessionManager.
        setState(() {
            _showFlagDialog = false;
            _flagController.clear();
        });
    }


    Widget _buildBody() {
        if (_isLoading) {
            return const Center(
                child: CircularProgressIndicator(color: ColorWheel.primaryText),
            );
        }

        // Route to the appropriate widget based on type
        // Validation is now pushed down into the specific widgets
        switch (session.currentType) {
            case 'multiple_choice':
                // Directly pass the data map
                return MultipleChoiceQuestionWidget(
                    onNextQuestion: () async {
                        setState(() {_isLoading = true;});
                        await session.requestNextQuestion();
                        // Set display time AFTER getting the new question data
                        session.setQuestionDisplayTime(); 
                        if (mounted) {
                           setState(() {_isLoading = false;});
                        }
                    },
                );
            case 'sort_order':
                // TODO: Implement SortOrderWidget and replace placeholder
                return const Center(child: Text('TODO: Sort Order Widget', style: TextStyle(color: ColorWheel.warning)));
            case 'true_false':
                 // TODO: Implement TrueFalseWidget and replace placeholder
                return const Center(child: Text('TODO: True/False Widget', style: TextStyle(color: ColorWheel.warning)));
            case 'matching':
                 // TODO: Implement MatchingWidget and replace placeholder
                return const Center(child: Text('TODO: Matching Widget', style: TextStyle(color: ColorWheel.warning)));
            case 'fill_in_the_blank':
                 // TODO: Implement FillInTheBlankWidget and replace placeholder
                return const Center(child: Text('TODO: Fill In The Blank Widget', style: TextStyle(color: ColorWheel.warning)));
            case 'short_answer':
                 // TODO: Implement ShortAnswerWidget and replace placeholder
                return const Center(child: Text('TODO: Short Answer Widget', style: TextStyle(color: ColorWheel.warning)));
            case 'hot_spot':
                 // TODO: Implement HotSpotWidget and replace placeholder
                return const Center(child: Text('TODO: Hot Spot Widget', style: TextStyle(color: ColorWheel.warning)));
            case 'label_diagram':
                 // TODO: Implement LabelDiagramWidget and replace placeholder
                return const Center(child: Text('TODO: Label Diagram Widget', style: TextStyle(color: ColorWheel.warning)));
            case 'math':
                 // TODO: Implement MathInputWidget and replace placeholder
                return const Center(child: Text('TODO: Math Input Widget', style: TextStyle(color: ColorWheel.warning)));
            // TODO: Add cases for other question types, e.g.:
            // case 'fill_in_the_blank':
            //   return FillInTheBlankWidget(questionData: currentData, onNextQuestion: ...);
            default:
                QuizzerLogger.logWarning('HomePage encountered unsupported question type: ${session.currentType}');
                return Center(
                    child: Text(
                        'Unsupported question type: ${session.currentType}',
                        style: const TextStyle(color: ColorWheel.warning),
                    ),
                );
        }
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            backgroundColor: ColorWheel.primaryBackground,
            appBar: HomePageTopBar(
                onMenuPressed: () {
                    // Add menu to history BEFORE navigating
                    session.addPageToHistory('/menu'); 
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
            body: _buildBody(),
        );
    }
}