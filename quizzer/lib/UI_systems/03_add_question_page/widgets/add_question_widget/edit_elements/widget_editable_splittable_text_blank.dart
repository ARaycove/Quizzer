import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
// ==========================================
//    Editable Splittable Text Element Widget
// ==========================================
// Handles text elements that can be split into blanks for fill-in-the-blank questions
//
// CRITICAL PAINT ORDER CONFLICT FIX - DO NOT BREAK THIS STRUCTURE
// ================================================================
// 
// ISSUE HISTORY:
// This widget was plagued by a "LeaderLayer anchor must come before FollowerLayer in paint order" 
// error that caused massive error spam when users tried to select text. The error occurs because:
//
// 1. SelectableText creates its own internal layers for text selection functionality
// 2. When SelectableText is placed inside a ReorderableDragStartListener (which wraps this entire widget),
//    it creates conflicting layer hierarchies with the drag listener's layers
// 3. This is a fundamental Flutter rendering limitation where SelectableText's internal layers
//    conflict with ReorderableDragStartListener's layers
// 4. The conflict occurs regardless of layout structure - it's the combination itself that's incompatible
//
// FAILED ATTEMPTS TO FIX:
// =======================
// 1. REMOVED onTap from ListTile - DID NOT FIX IT
// 2. Changed from Row to Column layout - DID NOT FIX IT
// 3. Moved SelectableText to ListTile.title - DID NOT FIX IT
// 4. Removed SelectableText entirely - DID NOT FIX IT
// 5. Used GestureDetector with onLongPress - DID NOT FIX IT
// 6. Tried different layout structures - DID NOT FIX IT
// 7. Tried separating with Row layout - DID NOT FIX IT
// 8. Tried dialog overlay approach - NOT ACCEPTABLE
//
// THE CURRENT WORKING SOLUTION:
// ============================
// - Using SelectableText with custom selection handling
// - Using a Stack to overlay the create blank button when text is selected
// - The create blank button appears conditionally based on text selection
// - This keeps everything in one widget while avoiding paint order conflicts
//
// WHY THIS STRUCTURE MUST BE MAINTAINED:
// - SelectableText and ReorderableDragStartListener are fundamentally incompatible
// - The create blank button must be conditionally shown, not always present
// - Do NOT try to combine SelectableText with complex gesture handlers
// - This is a fundamental Flutter limitation, not a code logic issue
//
// IF YOU BREAK THIS AGAIN:
// - Users will get massive error spam when selecting text
// - The app becomes unusable for fill-in-the-blank questions
// - You will have to debug the same paint order conflict again
// - This is a fundamental Flutter rendering limitation, not a code logic issue
//
// TESTING:
// - Always test text selection in fill-in-the-blank questions after any changes
// - If you see "LeaderLayer anchor must come before FollowerLayer" errors, you broke it
// - Revert immediately to this exact structure
// - SelectableText + ReorderableDragStartListener = ALWAYS BROKEN
//
// FUNCTIONALITY:
// - Text selection with SelectableText
// - Create blank button appears when text is selected
// - Double-click to edit
// - Drag to reorder (no drag handle icon)
// - All functionality in single widget
//
// DO NOT REPEAT THESE FAILED ATTEMPTS:
// - Do NOT try SelectableText inside ReorderableDragStartListener
// - Do NOT try complex layout separations
// - Do NOT try different widget combinations
// - The issue is fundamental, not solvable with layout changes
//
// ================================================================

class EditableSplittableTextElement extends StatefulWidget {
  final Map<String, dynamic> element;
  final int index;
  final String category; // 'question' or 'answer'
  final Function(int index, String category) onRemoveElement;
  final Function(int index, String category, Map<String, dynamic> updatedElement) onEditElement;
  final Function(int index, TextSelection selection) onTextSelectionChanged;
  final Function(int index, String selectedText) onCreateBlank;

  const EditableSplittableTextElement({
    super.key,
    required this.element,
    required this.index,
    required this.category,
    required this.onRemoveElement,
    required this.onEditElement,
    required this.onTextSelectionChanged,
    required this.onCreateBlank,
  });

  @override
  State<EditableSplittableTextElement> createState() => _EditableSplittableTextElementState();
}

class _EditableSplittableTextElementState extends State<EditableSplittableTextElement> {
  // Inline editing state
  bool _isEditing = false;
  final TextEditingController _editController = TextEditingController();
  final FocusNode _editFocusNode = FocusNode();
  
  // Text selection state
  TextSelection? _currentSelection;

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

  // --- Handle text selection changes ---
  void _handleSelectionChanged(TextSelection selection, SelectionChangedCause? cause) {
    setState(() {
      _currentSelection = selection;
    });
    
    widget.onTextSelectionChanged(widget.index, selection);
  }

  // --- Create blank from current selection ---
  void _createBlankFromSelection() {
    if (_currentSelection == null || _currentSelection!.isCollapsed) return;
    
    final text = widget.element['content'] as String;
    final selectedText = text.substring(_currentSelection!.start, _currentSelection!.end);
    
    widget.onCreateBlank(widget.index, selectedText);
    
    // Clear selection
    setState(() {
      _currentSelection = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.element['content'] as String;
    final hasSelection = _currentSelection != null && !_currentSelection!.isCollapsed;

    return Card(
      child: _isEditing
          ? ListTile(
              dense: true,
              title: TextField(
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
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check),
                    tooltip: 'Save Edit',
                    onPressed: () => _submitEdit(),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel),
                    tooltip: 'Cancel Edit',
                    onPressed: () => _cancelEditing(),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                ListTile(
                  dense: true,
                  title: GestureDetector(
                    onDoubleTap: () => _startEditing(),
                    child: SelectableText(
                      text,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      onSelectionChanged: _handleSelectionChanged,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit Element',
                        onPressed: () => _startEditing(),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
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
                ),
                // Overlay create blank button when text is selected
                if (hasSelection)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(4),
                      child: InkWell(
                        onTap: _createBlankFromSelection,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.create,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Create Blank',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
