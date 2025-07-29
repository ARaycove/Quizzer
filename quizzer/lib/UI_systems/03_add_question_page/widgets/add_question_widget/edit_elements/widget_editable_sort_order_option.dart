import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/UI_systems/global_widgets/question_answer_element.dart';
// ==========================================
//    Editable Sort Order Option Widget
// ==========================================
// Handles individual sort order options with no toggle (order determines correctness)

class EditableSortOrderOption extends StatefulWidget {
  final Map<String, dynamic> element;
  final int index;
  final Function(int index) onRemoveElement;
  final Function(int index, Map<String, dynamic> updatedElement) onEditElement;

  const EditableSortOrderOption({
    super.key,
    required this.element,
    required this.index,
    required this.onRemoveElement,
    required this.onEditElement,
  });

  @override
  State<EditableSortOrderOption> createState() => _EditableSortOrderOptionState();
}

class _EditableSortOrderOptionState extends State<EditableSortOrderOption> {
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

    QuizzerLogger.logMessage("Submitting edit for sort order option at index ${widget.index}");
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
            QuizzerLogger.logMessage("Starting edit for sort order option at index ${widget.index}");
            _startEditing();
          } else if (widget.element['type'] == 'image') {
            QuizzerLogger.logWarning("Double-tap image edit (replacement) not implemented yet for sort order options.");
          }
        },
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 8.0, right: 4.0, top: 4.0, bottom: 4.0),
          // No leading icon for sort order (order determines correctness)
          leading: null,
          // Show TextField if editing, otherwise show ElementRenderer
          title: _isEditing
              ? TextField(
                   controller: _editController,
                   focusNode: _editFocusNode,
                   autofocus: true,
                   maxLines: null,
                   keyboardType: TextInputType.multiline,
                   style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
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