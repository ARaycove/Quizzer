import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/global_widgets/question_answer_element.dart';

// ==========================================
//    Editable Image Element Widget
// ==========================================
// Handles individual image elements with preview

class EditableImageElement extends StatefulWidget {
  final Map<String, dynamic> element;
  final int index;
  final String category; // 'question' or 'answer'
  final Function(int index, String category) onRemoveElement;
  final Function(int index, String category, Map<String, dynamic> updatedElement) onEditElement;

  const EditableImageElement({
    super.key,
    required this.element,
    required this.index,
    required this.category,
    required this.onRemoveElement,
    required this.onEditElement,
  });

  @override
  State<EditableImageElement> createState() => _EditableImageElementState();
}

class _EditableImageElementState extends State<EditableImageElement> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        dense: true,
        title: ElementRenderer(elements: [widget.element]), // Use existing renderer
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          tooltip: 'Remove Element',
          onPressed: () => widget.onRemoveElement(widget.index, widget.category),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
        onTap: () {}, // Prevent tile tap interfering with drag
      ),
    );
  }
}
