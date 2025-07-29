import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/app_theme.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/add_question_widget/edit_elements/widget_editable_text_element.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/add_question_widget/edit_elements/widget_editable_image_element.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/add_question_widget/edit_elements/widget_editable_splittable_text_blank.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/add_question_widget/edit_elements/widget_editable_blank_element.dart';
import 'package:quizzer/UI_systems/03_add_question_page/helpers/image_picker_helper.dart';

// ==========================================
//    Add Question Elements Widget
// ==========================================
// Handles the question elements section

class AddQuestionElements extends StatefulWidget {
  final String questionType;
  final List<Map<String, dynamic>> questionElements;
  final List<Map<String, List<String>>> answersToBlanks; // For fill-in-the-blank
  final Function(String type, String category) onAddElement;
  final Function(int index, String category) onRemoveElement;
  final Function(int index, String category, Map<String, dynamic> updatedElement) onEditElement;
  final Function(List<Map<String, dynamic>> reorderedElements, String category) onReorderElements;
  // Fill-in-the-blank specific callbacks
  final Function(int index, TextSelection selection)? onTextSelectionChanged;
  final Function(int index, String selectedText)? onCreateBlank;
  final Function(int blankIndex, String newAnswerText)? onUpdateAnswerText; // For editing blank answers
  final Function(int blankIndex, String primaryAnswer, List<String> synonyms)? onUpdateSynonyms; // For editing synonyms

  const AddQuestionElements({
    super.key,
    required this.questionType,
    required this.questionElements,
    required this.answersToBlanks,
    required this.onAddElement,
    required this.onRemoveElement,
    required this.onEditElement,
    required this.onReorderElements,
    this.onTextSelectionChanged,
    this.onCreateBlank,
    this.onUpdateAnswerText,
    this.onUpdateSynonyms,
  });

  @override
  State<AddQuestionElements> createState() => _AddQuestionElementsState();
}

class _AddQuestionElementsState extends State<AddQuestionElements> {
  // Controllers and FocusNodes for text entry
  final _questionElementController = TextEditingController();
  final _questionElementFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _questionElementFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _questionElementFocusNode.removeListener(_handleFocusChange);
    _questionElementController.dispose();
    _questionElementFocusNode.dispose();
    super.dispose();
  }

  // --- Focus Change Handler for Text Entry Field ---
  void _handleFocusChange() {
    if (!mounted) return;
    
    final bool hasFocusNow = _questionElementFocusNode.hasFocus;
    final bool textIsNotEmpty = _questionElementController.text.isNotEmpty;
    final String currentText = _questionElementController.text;
    QuizzerLogger.logMessage("[DEBUG] Focus changed for 'question' field. Has Focus: $hasFocusNow, Text Not Empty: $textIsNotEmpty, Text: '$currentText'");

    // Check if focus was lost and text is present
    if (!hasFocusNow && textIsNotEmpty) {
      QuizzerLogger.logMessage("Submitting question '$currentText' via focus loss");
      widget.onAddElement(currentText, 'question');
      // Clear the controller AFTER submitting
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted) { // Check if still mounted
           _questionElementController.clear(); 
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
    final type = element['type'] as String;
    
    switch (type) {
      case 'text':
        // Use EditableSplittableTextElement for fill-in-the-blank, regular EditableTextElement otherwise
        if (widget.questionType == 'fill_in_the_blank') {
          return EditableSplittableTextElement(
            element: element,
            index: index,
            category: 'question',
            onRemoveElement: widget.onRemoveElement,
            onEditElement: widget.onEditElement,
            onTextSelectionChanged: widget.onTextSelectionChanged ?? (index, selection) {},
            onCreateBlank: widget.onCreateBlank ?? (index, selectedText) {},
          );
        } else {
          return EditableTextElement(
            element: element,
            index: index,
            category: 'question',
            onRemoveElement: widget.onRemoveElement,
            onEditElement: widget.onEditElement,
          );
        }
      case 'image':
        return EditableImageElement(
          element: element,
          index: index,
          category: 'question',
          onRemoveElement: widget.onRemoveElement,
          onEditElement: widget.onEditElement,
        );
      case 'blank':
        // Find the corresponding answer text and synonyms for this blank using index
        String answerText = '';
        List<String> synonyms = [];
        
        // Count how many blanks come before this one to get the blank index
        int blankIndex = widget.questionElements.take(index).where((e) => e['type'] == 'blank').length;
        
        if (blankIndex >= 0 && blankIndex < widget.answersToBlanks.length) {
          final answerGroup = widget.answersToBlanks[blankIndex];
          if (answerGroup.isNotEmpty) {
            answerText = answerGroup.keys.first;
            synonyms = answerGroup.values.first;
          }
        }
        
        return EditableBlankElement(
          element: element,
          index: index,
          category: 'question',
          onRemoveElement: widget.onRemoveElement,
          onEditElement: widget.onEditElement,
          answerText: answerText,
          onUpdateAnswerText: widget.onUpdateAnswerText,
          questionElements: widget.questionElements,
          synonyms: synonyms,
          onUpdateSynonyms: widget.onUpdateSynonyms,
        );
      default:
        return Card(
          child: ListTile(
            dense: true,
            title: Text('Unknown element type: $type'),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'Remove Element',
              onPressed: () => widget.onRemoveElement(index, 'question'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Question Elements"),
        AppTheme.sizedBoxMed,
        // --- Element Entry Row ---
        Row(
          children: [
            Expanded(
              child: _buildTextEntryField(
                controller: _questionElementController,
                focusNode: _questionElementFocusNode,
                hint: 'Enter new text element and press Enter',
                onSubmitted: (text) {
                  if (text.isNotEmpty) {
                    // Pass the actual text content back to the parent to create the map
                    widget.onAddElement(text, 'question');
                    _questionElementController.clear();
                    // Keep focus - Request after frame build
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                       if (mounted) { // Ensure widget is still mounted
                           _questionElementFocusNode.requestFocus(); // Use the passed focusNode
                       }
                    });
                  } else {
                      QuizzerLogger.logWarning("Attempted to add empty question element.");
                  }
                },
              ),
            ),
            AppTheme.sizedBoxMed,
            ElevatedButton.icon(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Image'),
              onPressed: () async {
                // Handle image picking for question elements
                final String? stagedImageFilename = await pickAndStageImage();
                if (stagedImageFilename != null) {
                  widget.onAddElement('image', 'question');
                }
              },
            ),
          ],
        ),
        AppTheme.sizedBoxMed,
        // --- List of Existing Elements (Now Reorderable) ---
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.questionElements.length,
          buildDefaultDragHandles: false, // Use custom handle (implicit via Listener)
          itemBuilder: (context, index) {
            final element = widget.questionElements[index];
            // Each item needs a unique key for reordering
            final key = ValueKey('question_element_${identityHashCode(element)}_$index'); // Composite key

            // Build the element widget
            final elementWidget = _buildElementWidget(element, index);

            // Return the element widget directly - let each element handle its own drag functionality
            return KeyedSubtree(
              key: key,
              child: elementWidget,
            );
          },
          onReorder: (int oldIndex, int newIndex) {
              QuizzerLogger.logMessage("Reordering question element from $oldIndex to $newIndex");
              // Create a mutable copy of the list received from the parent
              final List<Map<String, dynamic>> mutableElements = List.from(widget.questionElements);

              // Adjust index if moving down
              if (newIndex > oldIndex) {
                newIndex -= 1;
              }
              // Perform reorder on the mutable copy
              final Map<String, dynamic> item = mutableElements.removeAt(oldIndex);
              mutableElements.insert(newIndex, item);

              // Call the parent's callback with the newly ordered list
              widget.onReorderElements(mutableElements, 'question');
          },
        ),
      ],
    );
  }
}
