import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/app_theme.dart';

class QuestionFlaggingDialog extends StatefulWidget {
  final String questionId;
  final Function(Map<String, dynamic> flagResult)? onQuestionFlagged; // Callback when question is flagged

  const QuestionFlaggingDialog({
    super.key,
    required this.questionId,
    this.onQuestionFlagged,
  });

  @override
  State<QuestionFlaggingDialog> createState() => _QuestionFlaggingDialogState();
}

class _QuestionFlaggingDialogState extends State<QuestionFlaggingDialog> {
  final TextEditingController _flagController = TextEditingController();
  final SessionManager _session = SessionManager();
  String _selectedFlagType = 'other'; // Default flag type

  @override
  void dispose() {
    _flagController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitFlag(String reason) async {
    // Basic validation: do nothing if reason is empty
    if (reason.trim().isEmpty) {
      QuizzerLogger.logWarning('Attempted to submit flag with empty reason.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for flagging.'),
        ),
      );
      return; 
    }
    
    final String currentQuestionId = widget.questionId;
    if (currentQuestionId.isEmpty || currentQuestionId == "dummy_no_questions") {
      QuizzerLogger.logWarning('Attempted to flag question but no valid question is active.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active question to flag.'),
        ),
      );
      return;
    }
    
    QuizzerLogger.logMessage('Submitting flag for question: $currentQuestionId, Reason: $reason');

    bool success = false;
    String? errorMessage;
    
    try {
      success = await _session.addQuestionFlag(
        questionId: currentQuestionId,
        flagType: _selectedFlagType,
        flagDescription: reason.trim(),
      );
    } catch (e) {
      QuizzerLogger.logError('Error flagging question: $e');
      errorMessage = e.toString();
    }

    if (!mounted) return;
    
    if (mounted) {
      if (errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error flagging question: $errorMessage'),
          ),
        );
      } else if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question flagged successfully.'),
          ),
        );
        // Call the callback to notify parent that question was flagged
        widget.onQuestionFlagged?.call({
          'success': true,
          'questionId': widget.questionId,
          'flagType': _selectedFlagType,
          'flagDescription': _flagController.text.trim(),
          'message': 'Question flagged successfully and removed from circulation.',
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to flag question. Please try again.'),
          ),
        );
      }
      
      _flagController.clear();
      Navigator.pop(context);
    } 
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        children: [
          const Text("Flag Question"),
          AppTheme.sizedBoxLrg,
          // Flag Type Dropdown
          DropdownButton<String>(
            value: _selectedFlagType,
            onChanged: (String? newValue) {
              setState(() {
                _selectedFlagType = newValue!;
              });
            },
            items: const [
              DropdownMenuItem(value: 'factually_incorrect', child: Text('Factually Incorrect')),
              DropdownMenuItem(value: 'misleading_information', child: Text('Misleading Information')),
              DropdownMenuItem(value: 'outdated_content', child: Text('Outdated Content')),
              DropdownMenuItem(value: 'biased_perspective', child: Text('Biased Perspective')),
              DropdownMenuItem(value: 'confusing_answer_explanation', child: Text('Confusing Answer Explanation')),
              DropdownMenuItem(value: 'incorrect_answer', child: Text('Incorrect Answer')),
              DropdownMenuItem(value: 'confusing_question', child: Text('Confusing Question')),
              DropdownMenuItem(value: 'grammar_spelling_errors', child: Text('Grammar/Spelling Errors')),
              DropdownMenuItem(value: 'violent_content', child: Text('Violent Content')),
              DropdownMenuItem(value: 'sexual_content', child: Text('Sexual Content')),
              DropdownMenuItem(value: 'hate_speech', child: Text('Hate Speech')),
              DropdownMenuItem(value: 'duplicate_question', child: Text('Duplicate Question')),
              DropdownMenuItem(value: 'poor_quality_image', child: Text('Poor Quality Image')),
              DropdownMenuItem(value: 'broken_media', child: Text('Broken Media')),
              DropdownMenuItem(value: 'copyright_violation', child: Text('Copyright Violation')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
          ),
          AppTheme.sizedBoxLrg,
          TextField(
            controller: _flagController,
            maxLines: null,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: "Please explain the issue...",
            ),
          ),
          AppTheme.sizedBoxLrg,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text("Cancel"),
              ),
              AppTheme.sizedBoxMed,
              ElevatedButton(
                onPressed: () => _handleSubmitFlag(_flagController.text), // Pass text only
                child: const Text("Submit Flag"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
