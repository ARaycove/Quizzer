import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/app_theme.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/add_question_widget/edit_elements/widget_editable_text_element.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/add_question_widget/edit_elements/widget_editable_image_element.dart';

// ==========================================
//    Add Answer Explanation Elements Widget
// ==========================================
// Handles the answer explanation elements section

class AddAnswerExplanationElements extends StatefulWidget {
  final List<Map<String, dynamic>> answerElements;
  final Function(String type, String category) onAddElement;
  final Function(int index, String category) onRemoveElement;
  final Function(int index, String category, Map<String, dynamic> updatedElement) onEditElement;
  final Function(List<Map<String, dynamic>> reorderedElements, String category) onReorderElements;

  const AddAnswerExplanationElements({
    super.key,
    required this.answerElements,
    required this.onAddElement,
    required this.onRemoveElement,
    required this.onEditElement,
    required this.onReorderElements,
  });

  @override
  State<AddAnswerExplanationElements> createState() => _AddAnswerExplanationElementsState();
}

class _AddAnswerExplanationElementsState extends State<AddAnswerExplanationElements> {
  // Controllers and FocusNodes for text entry
  final _answerElementController = TextEditingController();
  final _answerElementFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _answerElementFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _answerElementFocusNode.removeListener(_handleFocusChange);
    _answerElementController.dispose();
    _answerElementFocusNode.dispose();
    super.dispose();
  }

  // --- Focus Change Handler for Text Entry Field ---
  void _handleFocusChange() {
    if (!mounted) return;
    
    final bool hasFocusNow = _answerElementFocusNode.hasFocus;
    final bool textIsNotEmpty = _answerElementController.text.isNotEmpty;
    final String currentText = _answerElementController.text;
    QuizzerLogger.logMessage("[DEBUG] Focus changed for 'answer' field. Has Focus: $hasFocusNow, Text Not Empty: $textIsNotEmpty, Text: '$currentText'");

    // Check if focus was lost and text is present
    if (!hasFocusNow && textIsNotEmpty) {
      QuizzerLogger.logMessage("Submitting answer '$currentText' via focus loss");
      widget.onAddElement(currentText, 'answer');
      // Clear the controller AFTER submitting
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted) { // Check if still mounted
           _answerElementController.clear(); 
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
        return EditableTextElement(
          element: element,
          index: index,
          category: 'answer',
          onRemoveElement: widget.onRemoveElement,
          onEditElement: widget.onEditElement,
        );
      case 'image':
        return EditableImageElement(
          element: element,
          index: index,
          category: 'answer',
          onRemoveElement: widget.onRemoveElement,
          onEditElement: widget.onEditElement,
        );
      default:
        return Card(
          child: ListTile(
            dense: true,
            title: Text('Unknown element type: $type'),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'Remove Element',
              onPressed: () => widget.onRemoveElement(index, 'answer'),
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
        const Text("Answer Explanation Elements"),
        AppTheme.sizedBoxMed,
        // --- Element Entry Row ---
        Row(
          children: [
            Expanded(
              child: _buildTextEntryField(
                controller: _answerElementController,
                focusNode: _answerElementFocusNode,
                hint: 'Enter new text element and press Enter',
                onSubmitted: (text) {
                  if (text.isNotEmpty) {
                    // Pass the actual text content back to the parent to create the map
                    widget.onAddElement(text, 'answer');
                    _answerElementController.clear();
                    // Keep focus - Request after frame build
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                       if (mounted) { // Ensure widget is still mounted
                           _answerElementFocusNode.requestFocus(); // Use the passed focusNode
                       }
                    });
                  } else {
                      QuizzerLogger.logWarning("Attempted to add empty answer element.");
                  }
                },
              ),
            ),
            AppTheme.sizedBoxMed,
            ElevatedButton.icon(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Image'),
              onPressed: () {
                // Let the parent handler do the image picking
                widget.onAddElement('image', 'answer');
              },
            ),
          ],
        ),
        AppTheme.sizedBoxMed,
        // --- List of Existing Elements (Now Reorderable) ---
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.answerElements.length,
          buildDefaultDragHandles: false, // Use custom handle (implicit via Listener)
          itemBuilder: (context, index) {
            final element = widget.answerElements[index];
            // Use a stable key based only on the element's identity, not its position
            final key = ValueKey('answer_element_${identityHashCode(element)}');

            // Build the element widget
            final elementWidget = _buildElementWidget(element, index);

            // Return the element widget directly - let each element handle its own drag functionality
            return KeyedSubtree(
              key: key,
              child: elementWidget,
            );
          },
          onReorder: (int oldIndex, int newIndex) {
              QuizzerLogger.logMessage("Reordering answer element from $oldIndex to $newIndex");
              // Create a mutable copy of the list received from the parent
              final List<Map<String, dynamic>> mutableElements = List.from(widget.answerElements);

              // Adjust index if moving down
              if (newIndex > oldIndex) {
                newIndex -= 1;
              }
              // Perform reorder on the mutable copy
              final Map<String, dynamic> item = mutableElements.removeAt(oldIndex);
              mutableElements.insert(newIndex, item);

              // Call the parent's callback with the newly ordered list
              widget.onReorderElements(mutableElements, 'answer');
          },

        ),
      ],
    );
  }
}
