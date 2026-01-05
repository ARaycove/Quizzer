import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/UI_systems/global_widgets/question_answer_element.dart';
// ==========================================
//    Editable Multiple Choice Option Widget
// ==========================================
// Handles individual multiple choice options with radio button selection

class EditableMultipleChoiceOption extends StatefulWidget {
  final Map<String, dynamic> element;
  final int index;
  final bool isCorrect;
  final Function(int index) onRemoveElement;
  final Function(int index, Map<String, dynamic> updatedElement) onEditElement;
  final Function(int index) onSetCorrect;

  const EditableMultipleChoiceOption({
    super.key,
    required this.element,
    required this.index,
    required this.isCorrect,
    required this.onRemoveElement,
    required this.onEditElement,
    required this.onSetCorrect,
  });

  @override
  State<EditableMultipleChoiceOption> createState() => _EditableMultipleChoiceOptionState();
}

class _EditableMultipleChoiceOptionState extends State<EditableMultipleChoiceOption> {
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

    QuizzerLogger.logMessage("Submitting edit for MC option at index ${widget.index}");
    widget.onEditElement(widget.index, updatedElement);

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
        onDoubleTap: () {
          // Only allow editing for text options for now
          if (widget.element['type'] == 'text') {
            QuizzerLogger.logMessage("Starting edit for MC option at index ${widget.index}");
            _startEditing();
          } else if (widget.element['type'] == 'image') {
            QuizzerLogger.logWarning("Double-tap image edit (replacement) not implemented yet for MC options.");
          }
        },
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 8.0, right: 4.0, top: 4.0, bottom: 4.0),
          // Radio button for multiple choice
          leading: IconButton(
            icon: Icon(
              widget.isCorrect ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            ),
            tooltip: 'Select as Correct Answer',
            onPressed: () => widget.onSetCorrect(widget.index),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
          // Show TextField if editing, otherwise show ElementRenderer
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
                tooltip: 'Remove Option',
                onPressed: () => widget.onRemoveElement(widget.index),
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
          // Prevent normal tap action if editing
          onTap: _isEditing ? () {} : null,
        ),
      ),
    );
  }
} 