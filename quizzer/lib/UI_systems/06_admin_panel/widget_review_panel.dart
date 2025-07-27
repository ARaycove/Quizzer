import 'package:flutter/material.dart';
import 'package:quizzer/app_theme.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/widget_live_preview.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_edit_question_dialogue.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

// Convert to StatefulWidget
class ReviewPanelWidget extends StatefulWidget {
  // Remove constructor arguments related to external state management
  const ReviewPanelWidget({super.key});

  @override
  State<ReviewPanelWidget> createState() => _ReviewPanelWidgetState();
}

class _ReviewPanelWidgetState extends State<ReviewPanelWidget> {
  final SessionManager _session = SessionManager();
  final ScrollController _scrollController = ScrollController();

  // Internal state variables
  Map<String, dynamic>? _currentData;
  Map<String, dynamic>? _editedData; // For storing edits before approval
  String? _sourceTable;
  Map<String, dynamic>? _primaryKey;
  String? _errorMessage;
  bool _isLoading = true;
  int _previewRebuildCounter = 0; // Internal counter for preview refresh

  @override
  void initState() {
    super.initState();
    _fetchNextQuestion();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchNextQuestion() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _editedData = null; // Clear edits when fetching new question
    });

    final result = await _session.getReviewQuestion();

    if (mounted) { // Check if widget is still in the tree
      setState(() {
        _currentData = result['data'] as Map<String, dynamic>?;
        _sourceTable = result['source_table'] as String?;
        _primaryKey = result['primary_key'] as Map<String, dynamic>?;
        _errorMessage = result['error'] as String?;
        _isLoading = false;
        _previewRebuildCounter++; // Increment to refresh preview
      });
    }
  }

  Future<void> _approveQuestion() async {
    if (_currentData == null || _sourceTable == null || _primaryKey == null) {
       QuizzerLogger.logWarning('Approve pressed but data is missing.');
       return;
    }
    QuizzerLogger.logMessage('Approving question...');
    setState(() => _isLoading = true);

    // Use edited data if available, otherwise current data
    final dataToSubmit = _editedData ?? _currentData!;

    final success = await _session.submitReview(
      isApproved: true,
      questionDetails: dataToSubmit,
      sourceTable: _sourceTable!,
      primaryKey: _primaryKey!,
    );

    if (mounted) {
      if (success) {
        QuizzerLogger.logSuccess('Approval successful, fetching next question.');
        _fetchNextQuestion(); // Fetch next on success
      } else {
        QuizzerLogger.logError('Approval failed.');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to approve question.';
        });
      }
    }
  }

  Future<void> _denyQuestion() async {
    if (_sourceTable == null || _primaryKey == null) {
       QuizzerLogger.logWarning('Deny pressed but key/table info is missing.');
       return;
    }
    QuizzerLogger.logMessage('Denying question...');
    setState(() => _isLoading = true);

    final success = await _session.submitReview(
      isApproved: false,
      sourceTable: _sourceTable!,
      primaryKey: _primaryKey!,
    );

    if (mounted) {
      if (success) {
        QuizzerLogger.logSuccess('Denial successful, fetching next question.');
        _fetchNextQuestion(); // Fetch next on success
      } else {
        QuizzerLogger.logError('Denial failed.');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to deny question.';
        });
      }
    }
  }

  // Handles the result from the EditQuestionDialog
  Future<void> _handleQuestionEdited(Map<String, dynamic> updatedData) async {
    QuizzerLogger.logMessage('ReviewPanelWidget: Question edited locally, updating preview state.');
    setState(() {
      _editedData = updatedData;
      _previewRebuildCounter++; // Refresh preview with edited data
    });
  }

  // Opens the EditQuestionDialog
  Future<void> _editQuestion() async {
    final Map<String, dynamic>? dataForEdit = _editedData ?? _currentData;
    if (dataForEdit == null) {
      QuizzerLogger.logWarning("Edit pressed but no review question loaded.");
      return;
    }

    QuizzerLogger.logMessage('Opening edit dialog for review question: ${dataForEdit['question_id']}');

    // Show the dialog with the question data
    final String questionId = dataForEdit['question_id'] as String;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => EditQuestionDialog(
        questionId: questionId,
        questionData: dataForEdit, // Pass the question data directly
        disableSubmission: true, // Keep submission disabled here
      ),
    );

    // Handle the result if the dialog submitted (returned data)
    if (result != null) {
      await _handleQuestionEdited(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use internal state variables now
    final Map<String, dynamic>? displayData = _editedData ?? _currentData;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
         child: Text('Error: $_errorMessage'),
      );
    }

    if (displayData == null) {
       // This case might occur if fetch fails silently or returns null data without error
       return const Center(
          child: Text('No question data available.'),
       );
    }

    // Key for LivePreviewWidget to force rebuilds
    final previewKey = ValueKey('review-preview-${displayData['question_id']}-$_previewRebuildCounter');

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Bar: Title + Edit Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Live Preview"),
              ElevatedButton(
                // Use internal _editQuestion method
                onPressed: _editQuestion, 
                child: const Text("Edit"),
              ),
            ],
          ),
          AppTheme.sizedBoxMed,
          // Live Preview Area
          LivePreviewWidget(
            key: previewKey,
            questionType: displayData['question_type'] as String? ?? 'error',
            questionElements: (displayData['question_elements'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            answerElements: (displayData['answer_elements'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            options: (displayData['options'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            correctOptionIndexMC: displayData['correct_option_index'] as int?,
            correctIndicesSATA: (displayData['index_options_that_apply'] as List<dynamic>? ?? []).map((e) => e as int).toList(),
            isCorrectAnswerTrueTF: (displayData['question_type'] == 'true_false')
                ? (displayData['correct_option_index'] == 0)
                : null,
            answersToBlanks: (displayData['answers_to_blanks'] as List<dynamic>? ?? []).map((e) => Map<String, List<String>>.from(e as Map)).toList(),
          ),
          // --- ADDED: Display Module Name ---
          AppTheme.sizedBoxSml,
          Row(
            children: [
              const Text('Module Name: '),
              Expanded(
                child: Text(
                  displayData['module_name'] as String? ?? 'N/A',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // --- END ADDED ---
          AppTheme.sizedBoxMed,
          // Bottom Bar: Skip/Deny/Approve Buttons
          Row(
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 100),
                  child: ElevatedButton(
                    onPressed: _fetchNextQuestion,
                    child: const Text("Skip"),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 100),
                  child: ElevatedButton(
                    // Use internal _denyQuestion method
                    onPressed: _denyQuestion,
                    child: const Text("Deny"),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 100),
                  child: ElevatedButton(
                    // Use internal _approveQuestion method
                    onPressed: _approveQuestion, 
                    child: const Text("Approve"),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
