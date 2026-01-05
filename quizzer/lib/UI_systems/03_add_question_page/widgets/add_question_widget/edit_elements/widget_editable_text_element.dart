import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/UI_systems/global_widgets/question_answer_element.dart';
// ==========================================
//    Editable Text Element Widget
// ==========================================
// Handles individual text elements with inline editing and text selection

class EditableTextElement extends StatefulWidget {
  final Map<String, dynamic> element;
  final int index;
  final String category; // 'question' or 'answer'
  final Function(int index, String category) onRemoveElement;
  final Function(int index, String category, Map<String, dynamic> updatedElement) onEditElement;

  const EditableTextElement({
    super.key,
    required this.element,
    required this.index,
    required this.category,
    required this.onRemoveElement,
    required this.onEditElement,
  });

  @override
  State<EditableTextElement> createState() => _EditableTextElementState();
}

class _EditableTextElementState extends State<EditableTextElement> {
  // Inline editing state
  bool _isEditing = false;
  final TextEditingController _editController = TextEditingController();
  final FocusNode _editFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _editFocusNode.addListener(_handleEditFocusChange);
  }

  @override
  void dispose() {
    _editFocusNode.removeListener(_handleEditFocusChange);
    _editController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  // --- Helper to initiate text editing ---
  void _startEditing() {
    if (!mounted) return;
    
    setState(() {
      _editController.text = widget.element['content'] as String;
      _isEditing = true;
      // Request focus after the build
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted && _editFocusNode.canRequestFocus) {
            _editFocusNode.requestFocus();
         }
      });
    });
  }

  // --- Helper to cancel editing ---
  void _cancelEditing() {
    if (!mounted) return;
    
    setState(() {
      _isEditing = false;
      _editController.clear();
    });
  }

  // --- Helper to submit edit ---
  void _submitEdit() {
    if (!mounted) return;
    
    final newText = _editController.text;
    if (newText.isEmpty) {
       QuizzerLogger.logWarning("Edit cancelled: Text cannot be empty.");
       _cancelEditing();
       return; // Don't submit empty text
    }

    // Create updated element map
    final updatedElement = {...widget.element, 'content': newText};

    QuizzerLogger.logMessage("Submitting edit for ${widget.category} element at index ${widget.index}");
    widget.onEditElement(widget.index, widget.category, updatedElement);

    _cancelEditing(); // Clear editing state after submitting
  }

  // --- Handler for Inline Edit Focus Change ---
  void _handleEditFocusChange() {
    // If focus is lost *while* editing, submit the change
    if (!_editFocusNode.hasFocus && _isEditing && mounted) {
      QuizzerLogger.logMessage("Inline edit field lost focus, submitting edit...");
      _submitEdit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: GestureDetector(
        onDoubleTap: () => _startEditing(),
        child: ListTile(
          dense: true,
          title: _isEditing
              ? TextField(
                   controller: _editController,
                   focusNode: _editFocusNode,
                   autofocus: true,
                   maxLines: null,
                   keyboardType: TextInputType.multiline,
                   decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                   ),
                   onSubmitted: (_) => _submitEdit(),
                )
              : ElementRenderer(elements: [widget.element]), // Normal view
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Remove Element',
                onPressed: () => widget.onRemoveElement(widget.index, widget.category),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              // Drag handle for reordering
              ReorderableDragStartListener(
                index: widget.index,
                child: const Icon(Icons.drag_handle),
              ),
            ],
          ),
          onTap: () {}, // Prevent tile tap interfering with drag/edit
        ),
      ),
    );
  }


}
