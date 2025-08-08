import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/app_theme.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/add_question_widget/edit_elements/widget_editable_multiple_choice_option.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/add_question_widget/edit_elements/widget_editable_select_all_that_apply_option.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/add_question_widget/edit_elements/widget_editable_sort_order_option.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/add_question_widget/edit_elements/widget_editable_true_false_option.dart';
import 'package:quizzer/UI_systems/03_add_question_page/helpers/image_picker_helper.dart';

// ==========================================
//    Add Options Widget
// ==========================================
// Handles the options section for different question types

class AddOptions extends StatefulWidget {
  final String questionType;
  final List<Map<String, dynamic>> options;
  final int? correctOptionIndex;
  final List<int> correctIndicesSATA;
  final Function(Map<String, dynamic> option) onAddOption;
  final Function(int index) onRemoveOption;
  final Function(int index, Map<String, dynamic> updatedOption) onEditOption;
  final Function(List<Map<String, dynamic>> reorderedOptions, int oldIndex, int newIndex) onReorderOptions;
  final Function(int index) onSetCorrectOptionIndex;
  final Function(int index) onToggleCorrectOptionSATA;

  const AddOptions({
    super.key,
    required this.questionType,
    required this.options,
    required this.correctOptionIndex,
    required this.correctIndicesSATA,
    required this.onAddOption,
    required this.onRemoveOption,
    required this.onEditOption,
    required this.onReorderOptions,
    required this.onSetCorrectOptionIndex,
    required this.onToggleCorrectOptionSATA,
  });

  @override
  State<AddOptions> createState() => _AddOptionsState();
}

class _AddOptionsState extends State<AddOptions> {
  // Controllers and FocusNodes for text entry
  final _optionTextController = TextEditingController();
  final _optionTextFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _optionTextFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _optionTextFocusNode.removeListener(_handleFocusChange);
    _optionTextController.dispose();
    _optionTextFocusNode.dispose();
    super.dispose();
  }

  // --- Focus Change Handler for Text Entry Field ---
  void _handleFocusChange() {
    if (!mounted) return;
    
    final bool hasFocusNow = _optionTextFocusNode.hasFocus;
    final bool textIsNotEmpty = _optionTextController.text.isNotEmpty;
    final String currentText = _optionTextController.text;
    QuizzerLogger.logMessage("[DEBUG] Focus changed for 'option' field. Has Focus: $hasFocusNow, Text Not Empty: $textIsNotEmpty, Text: '$currentText'");

    // Check if focus was lost and text is present
    if (!hasFocusNow && textIsNotEmpty) {
      QuizzerLogger.logMessage("Submitting option '$currentText' via focus loss");
      widget.onAddOption({'type': 'text', 'content': currentText});
      // Clear the controller AFTER submitting
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted) { // Check if still mounted
           _optionTextController.clear(); 
         }
      });
    }
  }

    // --- Helper for Text Entry Fields ---
  Widget _buildTextEntryField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required ValueChanged<String> onSubmitted,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),

      // Allow multiple lines for text wrapping
      maxLines: null,
      keyboardType: TextInputType.multiline, // Improve keyboard for multiline
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        isDense: true,
      ),
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.newline, // Allow newlines with Shift+Enter
    );
  }

  // --- Build element widget based on type ---
  Widget _buildElementWidget(Map<String, dynamic> element, int index) {
    switch (widget.questionType) {
      case 'multiple_choice':
        return EditableMultipleChoiceOption(
          element: element,
          index: index,
          isCorrect: widget.correctOptionIndex == index,
          onRemoveElement: widget.onRemoveOption,
          onEditElement: widget.onEditOption,
          onSetCorrect: widget.onSetCorrectOptionIndex,
        );
      case 'select_all_that_apply':
        return EditableSelectAllThatApplyOption(
          element: element,
          index: index,
          isCorrect: widget.correctIndicesSATA.contains(index),
          onRemoveElement: widget.onRemoveOption,
          onEditElement: widget.onEditOption,
          onToggleCorrect: widget.onToggleCorrectOptionSATA,
        );
      case 'sort_order':
        return EditableSortOrderOption(
          element: element,
          index: index,
          onRemoveElement: widget.onRemoveOption,
          onEditElement: widget.onEditOption,
        );
      default:
        // Fallback for unknown types
        return EditableSortOrderOption(
          element: element,
          index: index,
          onRemoveElement: widget.onRemoveOption,
          onEditElement: widget.onEditOption,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- True/False Case: Show selection UI only ---
    if (widget.questionType == 'true_false') {
      return EditableTrueFalseOption(
        isTrueSelected: widget.correctOptionIndex == 0, // True is index 0
        onSetCorrect: widget.onSetCorrectOptionIndex,
      );
    }

    // --- Default Case: MC, SATA, Sort Order --- 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Options"),
        AppTheme.sizedBoxMed,
        // --- Option Entry Row ---
        Row(
          children: [
            Expanded(
              child: _buildTextEntryField(
                controller: _optionTextController,
                focusNode: _optionTextFocusNode,
                hint: 'Enter new option text and press Enter',
                onSubmitted: (text) {
                  if (text.isNotEmpty) {
                    widget.onAddOption({'type': 'text', 'content': text});
                    _optionTextController.clear();
                    // Keep focus - Request after frame build
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                       if (mounted) { // Ensure widget is still mounted
                           _optionTextFocusNode.requestFocus();
                       }
                    });
                  } else {
                     QuizzerLogger.logWarning("Attempted to add empty option.");
                  }
                },
              ),
            ),
            AppTheme.sizedBoxMed,
            ElevatedButton.icon(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Image'),
              onPressed: () async {
                // Handle image picking for options
                final String? stagedImageFilename = await pickAndStageImage();
                if (stagedImageFilename != null) {
                  widget.onAddOption({'type': 'image', 'content': stagedImageFilename});
                }
              },
            ),
          ],
        ),
        AppTheme.sizedBoxMed,
        // --- List of Existing Options (Now Reorderable) ---
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.options.length,
          buildDefaultDragHandles: false, // Use custom handle (implicit via Listener)
          itemBuilder: (context, index) {
            final option = widget.options[index];
            // Use a stable key based only on the option's identity, not its position
            final key = ValueKey('option_${identityHashCode(option)}');
            
            // Build the actual option item UI using the modular widget
            final optionCard = _buildElementWidget(option, index);

            // Return the option card directly - let each option handle its own drag functionality
            return KeyedSubtree(
              key: key,
              child: optionCard,
            );
          },
          onReorder: (int oldIndex, int newIndex) {
              QuizzerLogger.logMessage("Reordering option from $oldIndex to $newIndex");
              // Create a mutable copy
              final List<Map<String, dynamic>> mutableOptions = List.from(widget.options);

              // Adjust index if moving down
              if (newIndex > oldIndex) {
                newIndex -= 1;
              }
              // Perform reorder
              final Map<String, dynamic> item = mutableOptions.removeAt(oldIndex);
              mutableOptions.insert(newIndex, item);

              // Call the parent's callback with reorder information
              widget.onReorderOptions(mutableOptions, oldIndex, newIndex);
          },

        )
      ],
    );
  }
}
