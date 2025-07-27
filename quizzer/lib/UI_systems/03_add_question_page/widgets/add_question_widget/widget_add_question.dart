import 'package:flutter/material.dart';
import 'package:quizzer/app_theme.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/add_question_widget/widget_add_question_elements.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/add_question_widget/widget_add_options.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/add_question_widget/widget_add_answer_explanation_elements.dart';

// ==========================================
//       Add/Edit Question Controls Widget
// ==========================================
// This widget orchestrates the modular question editing widgets.
// It receives the current question state and callbacks from the parent page.

class AddQuestionWidget extends StatefulWidget {
  // Data from parent
  final String questionType;
  final List<Map<String, dynamic>> questionElements;
  final List<Map<String, dynamic>> answerElements;
  final List<Map<String, dynamic>> options;
  final int? correctOptionIndex;       // For MC, TF
  final List<int> correctIndicesSATA;  // For SATA
  final List<Map<String, List<String>>> answersToBlanks; // For fill-in-the-blank

  // Callbacks to parent
  final Function(String type, String category) onAddElement; // category: 'question' or 'answer'
  final Function(int index, String category) onRemoveElement;
  final Function(int index, String category, Map<String, dynamic> updatedElement) onEditElement;
  final Function(Map<String, dynamic> newOption) onAddOption;
  final Function(int index) onRemoveOption;
  final Function(int index, Map<String, dynamic> updatedOption) onEditOption;
  final Function(int index) onSetCorrectOptionIndex; // For MC/TF
  final Function(int index) onToggleCorrectOptionSATA;
  final Function(List<Map<String, dynamic>> reorderedElements, String category) onReorderElements;
  final Function(List<Map<String, dynamic>> reorderedOptions) onReorderOptions;
  final Function(List<Map<String, List<String>>> answersToBlanks) onAnswersToBlanksChanged;
  final Function(int index, String selectedText) onCreateBlank; // For fill-in-the-blank
  final Function(int blankIndex, String newAnswerText)? onUpdateAnswerText; // For editing blank answers
  final Function(int blankIndex, String primaryAnswer, List<String> synonyms)? onUpdateSynonyms; // For editing synonyms

  const AddQuestionWidget({
    super.key,
    required this.questionType,
    required this.questionElements,
    required this.answerElements,
    required this.options,
    this.correctOptionIndex,
    required this.correctIndicesSATA,
    required this.answersToBlanks,
    required this.onAddElement,
    required this.onRemoveElement,
    required this.onEditElement,
    required this.onAddOption,
    required this.onRemoveOption,
    required this.onEditOption,
    required this.onSetCorrectOptionIndex,
    required this.onToggleCorrectOptionSATA,
    required this.onReorderElements,
    required this.onReorderOptions,
    required this.onAnswersToBlanksChanged,
    required this.onCreateBlank,
    this.onUpdateAnswerText,
    this.onUpdateSynonyms,
  });

  @override
  State<AddQuestionWidget> createState() => _AddQuestionWidgetState();
}

class _AddQuestionWidgetState extends State<AddQuestionWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Question Elements Section
        AddQuestionElements(
          questionType: widget.questionType,
        questionElements: widget.questionElements,
          answersToBlanks: widget.answersToBlanks,
        onAddElement: widget.onAddElement,
        onRemoveElement: widget.onRemoveElement,
        onEditElement: widget.onEditElement,
        onReorderElements: widget.onReorderElements,
          onTextSelectionChanged: (index, selection) {
            // Handle text selection for fill-in-the-blank
            // This could be used to track which text elements have selections
          },
          onCreateBlank: widget.onCreateBlank,
          onUpdateAnswerText: widget.onUpdateAnswerText,
          onUpdateSynonyms: widget.onUpdateSynonyms,
        ),
        AppTheme.sizedBoxLrg,
        
        // Options Section (only for non-fill-in-the-blank questions)
        if (widget.questionType != 'fill_in_the_blank') ...[
          AddOptions(
            questionType: widget.questionType,
            options: widget.options,
            correctOptionIndex: widget.correctOptionIndex,
            correctIndicesSATA: widget.correctIndicesSATA,
            onAddOption: widget.onAddOption,
            onRemoveOption: widget.onRemoveOption,
            onEditOption: widget.onEditOption,
            onReorderOptions: widget.onReorderOptions,
            onSetCorrectOptionIndex: widget.onSetCorrectOptionIndex,
            onToggleCorrectOptionSATA: widget.onToggleCorrectOptionSATA,
          ),
          AppTheme.sizedBoxLrg,
        ],
        
        // Answer Explanation Elements Section
        AddAnswerExplanationElements(
          answerElements: widget.answerElements,
          onAddElement: widget.onAddElement,
          onRemoveElement: widget.onRemoveElement,
          onEditElement: widget.onEditElement,
          onReorderElements: widget.onReorderElements,
        ),
      ],
    );
  }
}
