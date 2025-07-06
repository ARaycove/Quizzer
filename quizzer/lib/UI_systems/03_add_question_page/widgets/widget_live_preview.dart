import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

// Import Core Question Widgets
// Adjust path based on the new location relative to question_widgets
import '../../question_widgets/widget_multiple_choice_question.dart';
import '../../question_widgets/widget_select_all_that_apply_question.dart';
import '../../question_widgets/widget_sort_order_question.dart';
import '../../question_widgets/widget_true_false_question.dart';

// ==========================================
//         Live Preview Widget
// ==========================================
// Displays a disabled preview of a question based on passed-in data.

class LivePreviewWidget extends StatelessWidget {
  final String questionType;
  final List<Map<String, dynamic>> questionElements;
  final List<Map<String, dynamic>> answerElements;
  final List<Map<String, dynamic>> options;
  // Type-specific correct answer data
  final int? correctOptionIndexMC;
  final List<int> correctIndicesSATA;
  final bool? isCorrectAnswerTrueTF; // Correct answer for True/False

  const LivePreviewWidget({
    super.key,
    required this.questionType,
    required this.questionElements,
    required this.answerElements,
    required this.options,
    // Pass type-specific data, allow nulls where appropriate for the type
    this.correctOptionIndexMC,
    required this.correctIndicesSATA,
    this.isCorrectAnswerTrueTF,
  });

  @override
  Widget build(BuildContext context) {
    // --- Input Validation --- 
    // Require at least one question element for any preview
    if (questionElements.isEmpty) {
      return _buildPreviewError('Preview requires at least one question element.');
    }
    // Require options for types that use them
    if ((questionType == 'multiple_choice' || 
         questionType == 'select_all_that_apply' || 
         questionType == 'sort_order') 
        && options.isEmpty) {
       return _buildPreviewError('Preview requires at least one option for type $questionType.');
    } 
    // TODO: Add validation for correct index requirements if needed

    // --- Original Build Logic ---
    // Dummy callback for disabled widgets
    void dummyOnNext() {
      QuizzerLogger.logWarning("onNextQuestion called on disabled preview widget.");
    }

    // Key to potentially help Flutter update when data changes significantly
    // Include relevant data points that define the current preview state.
    final previewKey = ValueKey(
      'preview_${questionType}_'
      // Include lengths for explicit change detection on add/remove
      'qlen${questionElements.length}_alen${answerElements.length}_olen${options.length}_'
      '${questionElements.hashCode}_'
      '${answerElements.hashCode}_'
      '${options.hashCode}_'
      '${correctOptionIndexMC}_'
      '${correctIndicesSATA.hashCode}_'
      '$isCorrectAnswerTrueTF'
    );


    QuizzerLogger.logValue("LivePreviewWidget build for type: $questionType");

    switch (questionType) {
      case 'multiple_choice':
        // Ensure options list is handled gracefully if empty during build
        return MultipleChoiceQuestionWidget(
          key: previewKey,
          questionElements: questionElements,
          answerElements: answerElements,
          options: options, // Pass original options list directly
          // Adjust default correct index logic for potentially empty list
          correctOptionIndex: correctOptionIndexMC ?? (options.isNotEmpty ? 0 : null),
          onNextQuestion: dummyOnNext,
          isDisabled: true, // ALWAYS disabled in preview
        );
      case 'select_all_that_apply':
         // Ensure options list is handled gracefully if empty during build
         return SelectAllThatApplyQuestionWidget(
           key: previewKey,
           questionElements: questionElements,
           answerElements: answerElements,
           options: options, // Pass original options list directly
           correctIndices: correctIndicesSATA,
           onNextQuestion: dummyOnNext,
           isDisabled: true, // ALWAYS disabled in preview
         );
      case 'sort_order':
         // Ensure options list has at least one item for SortOrder preview
         return SortOrderQuestionWidget(
           key: previewKey,
           questionElements: questionElements,
           answerElements: answerElements,
           options: options, // Pass original options list directly
           onNextQuestion: dummyOnNext,
           isDisabled: true, // ALWAYS disabled in preview
         );
      case 'true_false':
        return TrueFalseQuestionWidget(
          key: previewKey,
          questionElements: questionElements,
          answerElements: answerElements,
          isCorrectAnswerTrue: isCorrectAnswerTrueTF ?? true, // Default if null
          onNextQuestion: dummyOnNext,
          isDisabled: true, // ALWAYS disabled in preview
        );
      default:
        QuizzerLogger.logError('LivePreviewWidget: Unknown question type "$questionType"');
        return Container(
          padding: ColorWheel.standardPadding,
          decoration: BoxDecoration(
            color: ColorWheel.warning.withValues(alpha: 0.1),
            border: Border.all(color: ColorWheel.warning),
            borderRadius: ColorWheel.cardBorderRadius,
          ),
          child: Center(
            child: Text(
              'Error: Unknown question type "$questionType" for preview.',
              style: const TextStyle(color: ColorWheel.warning),
            ),
          ),
        );
    }
  }

  // Helper to build a consistent error message container
  Widget _buildPreviewError(String message) {
     QuizzerLogger.logWarning("LivePreviewWidget: $message");
     return Container(
       padding: const EdgeInsets.all(16.0),
       alignment: Alignment.center,
       decoration: BoxDecoration(
         color: ColorWheel.secondaryBackground.withValues(alpha: 0.5),
         border: Border.all(color: ColorWheel.warning.withValues(alpha: 0.5)),
         borderRadius: ColorWheel.cardBorderRadius,
       ),
       child: Text(
         message,
         textAlign: TextAlign.center,
         style: ColorWheel.secondaryTextStyle.copyWith(color: ColorWheel.warning),
       ),
     );
  }
}
