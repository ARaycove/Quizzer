import 'package:flutter/material.dart';
import 'package:quizzer/app_theme.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/widget_live_preview.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_edit_question_dialogue.dart';

class ReviewReportedQuestionsPanelWidget extends StatefulWidget {
  const ReviewReportedQuestionsPanelWidget({super.key});

  @override
  State<ReviewReportedQuestionsPanelWidget> createState() => _ReviewReportedQuestionsPanelWidgetState();
}

class _ReviewReportedQuestionsPanelWidgetState extends State<ReviewReportedQuestionsPanelWidget> {
  final SessionManager _session = SessionManager();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _flaggedQuestion;
  Map<String, dynamic>? _editedQuestionData; // For storing edits before approval

  @override
  void initState() {
    super.initState();
    _fetchFlaggedQuestion();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchFlaggedQuestion() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _editedQuestionData = null;
    });
    try {
      final result = await _session.getFlaggedQuestionForReview();
      setState(() {
        _flaggedQuestion = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load reported question: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleEdit() async {
    if (_flaggedQuestion == null) return;
    final questionData = _editedQuestionData ?? _flaggedQuestion!['question_data'] as Map<String, dynamic>;
    final questionId = questionData['question_id'] as String;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => EditQuestionDialog(
        questionId: questionId,
        questionData: questionData,
      ),
    );
    if (result != null) {
      setState(() {
        _editedQuestionData = result;
      });
    }
  }

  Future<void> _handleDecision(String action) async {
    if (_flaggedQuestion == null) return;
    final report = _flaggedQuestion!['report'] as Map<String, dynamic>;
    final questionId = report['question_id'] as String;
    final questionData = _editedQuestionData ?? _flaggedQuestion!['question_data'] as Map<String, dynamic>;
    setState(() { _isLoading = true; });
    try {
      await _session.submitQuestionFlagReview(
        questionId: questionId,
        action: action,
        updatedQuestionData: questionData,
      );
      await _fetchFlaggedQuestion();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to submit decision: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSkip() async {
    await _fetchFlaggedQuestion();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    if (_flaggedQuestion == null) {
      return const Center(child: Text('No reported questions to review.'));
    }
    final report = _flaggedQuestion!['report'] as Map<String, dynamic>;
    final questionData = _editedQuestionData ?? _flaggedQuestion!['question_data'] as Map<String, dynamic>;
    final questionType = questionData['question_type'] as String? ?? 'error';
    final correctOptionIndex = questionData['correct_option_index'] as int?;

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: flag_type and flag_description
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Card(
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: Text('Type: ${report['flag_type']}'),
                    ),
                  ),
                ),
                AppTheme.sizedBoxMed,
                Expanded(
                  flex: 3,
                  child: Card(
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: Text('Description: ${report['flag_description'] ?? ""}'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Edit button row (aligned right)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Question',
                onPressed: _handleEdit,
              ),
            ],
          ),
          AppTheme.sizedBoxMed,
          // Live Preview
          LivePreviewWidget(
            questionType: questionType,
            questionElements: (questionData['question_elements'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            answerElements: (questionData['answer_elements'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            options: (questionData['options'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            correctOptionIndexMC: questionData['correct_option_index'],
            correctIndicesSATA: (questionData['index_options_that_apply'] as List<dynamic>? ?? []).map((e) => e as int).toList(),
            isCorrectAnswerTrueTF: (questionType == 'true_false')
                ? (questionData['correct_option_index'] == 0)
                : null,
          ),
          AppTheme.sizedBoxMed,
          // Bottom Row: skip, delete, submit edit
          Row(
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 100),
                  child: ElevatedButton(
                    onPressed: _handleSkip,
                    child: const Text('Skip'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 100),
                  child: ElevatedButton(
                    onPressed: () => _handleDecision('delete'),
                    child: const Text('Delete'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 100),
                  child: ElevatedButton(
                    onPressed: () => _handleDecision('edit'),
                    child: const Text('Edit'),
                  ),
                ),
              ),
            ],
          ),
          AppTheme.sizedBoxLrg,
        ],
      ),
    );
  }
}
