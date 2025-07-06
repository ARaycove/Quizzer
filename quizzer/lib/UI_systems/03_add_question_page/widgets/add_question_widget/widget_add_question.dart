import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/UI_systems/global_widgets/question_answer_element.dart';

// ==========================================
//       Add/Edit Question Controls Widget
// ==========================================
// This widget displays the controls for editing question elements, options, and answers.
// It receives the current question state and callbacks from the parent page.

class AddQuestionWidget extends StatefulWidget {
  // Data from parent
  final String questionType;
  final List<Map<String, dynamic>> questionElements;
  final List<Map<String, dynamic>> answerElements;
  final List<Map<String, dynamic>> options;
  final int? correctOptionIndex;       // For MC, TF
  final List<int> correctIndicesSATA;  // For SATA

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

  const AddQuestionWidget({
    super.key,
    required this.questionType,
    required this.questionElements,
    required this.answerElements,
    required this.options,
    this.correctOptionIndex,
    required this.correctIndicesSATA,
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
  });

  @override
  State<AddQuestionWidget> createState() => _AddQuestionWidgetState();
}

class _AddQuestionWidgetState extends State<AddQuestionWidget> {
  // Controllers and FocusNodes for the text entry fields
  final _questionElementController = TextEditingController();
  final _optionTextController = TextEditingController();
  final _answerElementController = TextEditingController();

  // Controller for inline editing
  final _editController = TextEditingController();

  // State to track inline editing
  int? _editingElementIndex;
  String? _editingElementCategory; // 'question' or 'answer'
  int? _editingOptionIndex;

  final _questionElementFocusNode = FocusNode();
  final _optionTextFocusNode = FocusNode();
  final _answerElementFocusNode = FocusNode();
  // FocusNode for the inline editor
  final _editFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    QuizzerLogger.logMessage("_AddQuestionWidgetState: initState CALLED");
    // Add listeners to submit text fields on focus loss
    _questionElementFocusNode.addListener(_handleFocusChangeQuestion);
    _optionTextFocusNode.addListener(_handleFocusChangeOption);
    _answerElementFocusNode.addListener(_handleFocusChangeAnswer);
    _editFocusNode.addListener(_handleEditFocusChange);
  }

  @override
  void dispose() {
    QuizzerLogger.logMessage("_AddQuestionWidgetState: dispose CALLED");
    // Remove listeners first
    _questionElementFocusNode.removeListener(_handleFocusChangeQuestion);
    _optionTextFocusNode.removeListener(_handleFocusChangeOption);
    _answerElementFocusNode.removeListener(_handleFocusChangeAnswer);
    // Then dispose controllers and focus nodes
    _questionElementController.dispose();
    _optionTextController.dispose();
    _answerElementController.dispose();
    _editController.dispose(); // Dispose the new controller
    _questionElementFocusNode.dispose();
    _optionTextFocusNode.dispose();
    _answerElementFocusNode.dispose();
    _editFocusNode.removeListener(_handleEditFocusChange);
    _editFocusNode.dispose(); // Dispose the new focus node
    super.dispose();
  }

  // --- Focus Change Handlers for Text Entry Fields ---
  void _handleFocusChangeQuestion() {
    _handleFocusChange(_questionElementFocusNode, _questionElementController, 'question');
  }
  void _handleFocusChangeOption() {
    _handleFocusChange(_optionTextFocusNode, _optionTextController, 'option');
  }
  void _handleFocusChangeAnswer() {
    _handleFocusChange(_answerElementFocusNode, _answerElementController, 'answer');
  }

  // Generic handler for focus change
  void _handleFocusChange(FocusNode focusNode, TextEditingController controller, String type) {
    // --- Debug Logging --- 
    final bool hasFocusNow = focusNode.hasFocus;
    final bool textIsNotEmpty = controller.text.isNotEmpty;
    final String currentText = controller.text;
    QuizzerLogger.logMessage("[DEBUG] Focus changed for '$type' field. Has Focus: $hasFocusNow, Text Not Empty: $textIsNotEmpty, Text: '$currentText'");
    // --- End Debug --- 

    // Check if focus was lost and text is present
    if (!hasFocusNow && textIsNotEmpty) {
      // final text = controller.text; // Already captured above
      QuizzerLogger.logMessage("Submitting $type '$currentText' via focus loss");
      // Trigger the appropriate add callback
      if (type == 'question') {
        widget.onAddElement(currentText, 'question');
      } else if (type == 'answer') {
        widget.onAddElement(currentText, 'answer');
      } else if (type == 'option') {
        widget.onAddOption({'type': 'text', 'content': currentText});
      }
      // Clear the controller AFTER submitting
      // Use a post-frame callback for clearing to avoid potential build conflicts if submission triggers immediate rebuilds
       WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) { // Check if still mounted
            controller.clear(); 
          }
       });
      // Note: No need to manually unfocus, focus has already changed.
    }
  }

  // --- Helper to initiate text editing ---
  void _startEditing(int index, String categoryOrType, String initialText) {
    setState(() {
      _editController.text = initialText;
      if (categoryOrType == 'question' || categoryOrType == 'answer') {
        _editingElementIndex = index;
        _editingElementCategory = categoryOrType;
        _editingOptionIndex = null; // Ensure option editing is off
      } else { // Assume it's an option type
        _editingOptionIndex = index;
        _editingElementIndex = null; // Ensure element editing is off
        _editingElementCategory = null;
      }
      // Request focus after the build
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted) {
            _editFocusNode.requestFocus();
         }
      });
    });
  }

  // --- Helper to cancel editing ---
  void _cancelEditing() {
    setState(() {
      _editingElementIndex = null;
      _editingElementCategory = null;
      _editingOptionIndex = null;
      _editController.clear();
      // Optionally, move focus back to the main entry field?
      // Or just let it unfocus naturally.
    });
  }

   // --- Helper to submit edit (called by TextField onSubmitted/lost focus) ---
  void _submitEdit() {
    final newText = _editController.text;
    if (newText.isEmpty) {
       QuizzerLogger.logWarning("Edit cancelled: Text cannot be empty.");
       _cancelEditing();
       return; // Don't submit empty text
    }

    if (_editingElementIndex != null && _editingElementCategory != null) {
       final index = _editingElementIndex!;
       final category = _editingElementCategory!;
       final originalElement = (category == 'question')
           ? widget.questionElements[index]
           : widget.answerElements[index];

       // Create updated element map (assuming type remains 'text')
       final updatedElement = {...originalElement, 'content': newText};

       QuizzerLogger.logMessage("Submitting edit for $category element at index $index");
       widget.onEditElement(index, category, updatedElement); // Pass updated data
    } else if (_editingOptionIndex != null) {
       final index = _editingOptionIndex!;
       final originalOption = widget.options[index];

       // Create updated option map (assuming type remains 'text')
       final updatedOption = {...originalOption, 'content': newText};

       QuizzerLogger.logMessage("Submitting edit for option at index $index");
       widget.onEditOption(index, updatedOption); // Pass updated data
    }

    _cancelEditing(); // Clear editing state after submitting
  }

  // --- Handler for Inline Edit Focus Change ---
  void _handleEditFocusChange() {
    // If focus is lost *while* editing, submit the change
    if (!_editFocusNode.hasFocus && (_editingElementIndex != null || _editingOptionIndex != null)) {
      QuizzerLogger.logMessage("Inline edit field lost focus, submitting edit...");
      _submitEdit();
    }
  }

  // --- Helper to build True/False ChoiceChips ---
  // Renamed to reflect change to Button
  Widget _buildTrueFalseButton({required String label, required int index}) {
     final bool isSelected = widget.correctOptionIndex == index;
     // return ChoiceChip(...);
     return ElevatedButton(
        onPressed: () {
          // Always trigger the callback when a button is pressed
          widget.onSetCorrectOptionIndex(index);
        },
        style: ElevatedButton.styleFrom(
          // Background: Green if selected, standard secondary background if not
          backgroundColor: isSelected ? ColorWheel.buttonSuccess : ColorWheel.secondaryBackground,
          // Text: White if selected, grey if not
          foregroundColor: isSelected ? ColorWheel.primaryText : ColorWheel.secondaryText,
          // Shape: Consistent rounded rectangle
          shape: RoundedRectangleBorder(
            borderRadius: ColorWheel.buttonBorderRadius, // Use consistent radius
          ),
          // Border: Green and thicker if selected, subtle grey otherwise
          side: BorderSide(
            color: isSelected ? ColorWheel.buttonSuccess : ColorWheel.secondaryText.withAlpha(128),
            width: isSelected ? 1.5 : 1.0, 
          ),
          // Padding: Adjust for visual balance
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          // Ensure minimum height/tap target size if needed (can be added)
          // minimumSize: const Size(0, 40), // Example minimum height
          elevation: isSelected ? 2.0 : 1.0, // Slightly raise selected button
        ),
        child: Text(
          label,
          style: TextStyle(
            // Explicitly set font weight for clarity
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ), 
     );
  }

  // --- Helper Methods for Building UI Sections ---

  // Builds the section for Question Elements
  Widget _buildQuestionElementsSection() {
    return _buildEditableListSection(
      title: 'Question Elements',
      elements: widget.questionElements,
      textController: _questionElementController,
      focusNode: _questionElementFocusNode,
      category: 'question',
      onAddElementCallback: widget.onAddElement,
      onRemoveElementCallback: widget.onRemoveElement,
      onEditElementCallback: widget.onEditElement,
      onReorderElementsCallback: widget.onReorderElements,
    );
  }

  // Builds the section for Options
  Widget _buildOptionsSection() {
    // --- Special Case: True/False --- 
    if (widget.questionType == 'true_false') {
      // Provide dedicated True/False selection UI
      return Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           const Text("Correct Answer", style: ColorWheel.titleText),
           const SizedBox(height: 8),
           Row(
             children: [
               Expanded(
                 child: _buildTrueFalseButton(label: "True", index: 0),
               ),
               const SizedBox(width: 8),
               Expanded(
                 child: _buildTrueFalseButton(label: "False", index: 1),
               ),
             ],
           ),
         ],
      );
    }

    // --- Default Case: MC, SATA, Sort Order --- 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Options", style: ColorWheel.titleText),
        const SizedBox(height: 8),
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
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('Image'),
              onPressed: () {
                widget.onAddOption({'type': 'image', 'content': ''}); // Trigger image add
                 QuizzerLogger.logWarning("Image Option Add - Picker Not Implemented");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorWheel.primaryBackground,
                foregroundColor: ColorWheel.primaryText,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 13)
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // --- List of Existing Options (Now Reorderable) ---
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.options.length,
          buildDefaultDragHandles: false, // Use custom handle (implicit via Listener)
          itemBuilder: (context, index) {
            final option = widget.options[index];
            // Assign key based on content or index
            final key = ValueKey(option['content']?.toString() ?? 'option_$index');
            
            // Build the actual option item UI using the existing helper
            final optionCard = _buildOptionItem(option, index);

            // Wrap the card for drag start
            return ReorderableDragStartListener(
              key: key, // Apply key to the listener
              index: index,
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

              // Call the parent's callback
              widget.onReorderOptions(mutableOptions);
          },
          // Optional: Add proxy decorator
          proxyDecorator: (Widget child, int index, Animation<double> animation) {
            return Material(
                color: Colors.transparent,
                elevation: 6.0,
                shadowColor: ColorWheel.secondaryBackground.withAlpha(150),
                child: child,
            );
          },
        )
      ],
    );
  }

  // Builds the section for Answer Elements
  Widget _buildAnswerElementsSection() {
    return _buildEditableListSection(
      title: 'Answer Explanation Elements',
      elements: widget.answerElements,
      textController: _answerElementController,
      focusNode: _answerElementFocusNode,
      category: 'answer',
      onAddElementCallback: widget.onAddElement,
      onRemoveElementCallback: widget.onRemoveElement,
      onEditElementCallback: widget.onEditElement,
      onReorderElementsCallback: widget.onReorderElements,
    );
  }

  // --- Generic Helper for Editable Element Lists (Question/Answer) ---
  Widget _buildEditableListSection({
    required String title,
    required List<Map<String, dynamic>> elements,
    required TextEditingController textController,
    required FocusNode focusNode,
    required String category,
    required Function(String type, String category) onAddElementCallback,
    required Function(int index, String category) onRemoveElementCallback,
    required Function(int index, String category, Map<String, dynamic> updatedElement) onEditElementCallback,
    required Function(List<Map<String, dynamic>> reorderedElements, String category) onReorderElementsCallback,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: ColorWheel.titleText),
        const SizedBox(height: 8),
        // --- Element Entry Row ---
        Row(
          children: [
            Expanded(
              child: _buildTextEntryField(
                controller: textController,
                focusNode: focusNode,
                hint: 'Enter new text element and press Enter',
                onSubmitted: (text) {
                  if (text.isNotEmpty) {
                    // Pass the actual text content back to the parent to create the map
                    onAddElementCallback(text, category);
                    textController.clear();
                    // focusNode.requestFocus(); // Keep focus
                    // Keep focus - Request after frame build
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                       if (mounted) { // Ensure widget is still mounted
                           focusNode.requestFocus(); // Use the passed focusNode
                       }
                    });
                  } else {
                      QuizzerLogger.logWarning("Attempted to add empty $category element.");
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('Image'),
              onPressed: () {
                  // Parent needs to handle image picking and element creation
                  onAddElementCallback('image', category);
                  QuizzerLogger.logWarning("Image Element Add - Picker Not Implemented by parent");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorWheel.primaryBackground,
                foregroundColor: ColorWheel.primaryText,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                 textStyle: const TextStyle(fontSize: 13)
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // --- List of Existing Elements (Now Reorderable) ---
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: elements.length,
          buildDefaultDragHandles: false, // Use custom handle (implicit via Listener)
          itemBuilder: (context, index) {
            final element = elements[index];
            // Each item needs a unique key for reordering
            final key = ValueKey('${category}_element_${element.hashCode}_$index'); // Composite key

            // Determine if this specific element is being edited
            final bool isEditingThisElement = _editingElementIndex == index && _editingElementCategory == category;

            // Build the visual item (Card with ListTile)
             final elementCard = Card(
               margin: const EdgeInsets.symmetric(vertical: 4.0),
               color: isEditingThisElement ? ColorWheel.accent.withAlpha(50) : ColorWheel.secondaryBackground,
               elevation: 1.0,
               shape: RoundedRectangleBorder(borderRadius: ColorWheel.buttonBorderRadius),
               child: GestureDetector(
                  onDoubleTap: () {
                    if (element['type'] == 'text') {
                       QuizzerLogger.logMessage("Starting edit for $category element at index $index");
                       _startEditing(index, category, element['content']);
                    } else if (element['type'] == 'image') {
                       QuizzerLogger.logWarning("Double-tap image edit (replacement) not implemented yet.");
                    }
                  },
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                    title: isEditingThisElement
                        ? TextField(
                             controller: _editController,
                             focusNode: _editFocusNode,
                             autofocus: true,
                             style: const TextStyle(color: ColorWheel.primaryText, fontSize: 16.0),
                             cursorColor: ColorWheel.primaryText,
                             maxLines: null,
                             keyboardType: TextInputType.multiline,
                             decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(vertical: 8.0), // Adjust padding
                                isDense: true,
                                border: InputBorder.none, // Minimal decoration
                                focusedBorder: UnderlineInputBorder( // Add underline when focused
                                  borderSide: BorderSide(color: ColorWheel.accent),
                                ),
                             ),
                             onSubmitted: (_) => _submitEdit(),
                          )
                        : ElementRenderer(elements: [element]), // Normal view
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 20, color: ColorWheel.buttonError),
                      tooltip: 'Remove Element',
                      onPressed: () => onRemoveElementCallback(index, category),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    onTap: () {}, // Prevent tile tap interfering with drag/edit
                 ),
               ),
             );
             // Wrap the card for drag start, similar to SortOrder widget
             return ReorderableDragStartListener(
               key: key,
               index: index,
               child: elementCard,
             );
          },
          onReorder: (int oldIndex, int newIndex) {
              QuizzerLogger.logMessage("Reordering $category element from $oldIndex to $newIndex");
              // Create a mutable copy of the list received from the parent
              final List<Map<String, dynamic>> mutableElements = List.from(elements);

              // Adjust index if moving down
              if (newIndex > oldIndex) {
                newIndex -= 1;
              }
              // Perform reorder on the mutable copy
              final Map<String, dynamic> item = mutableElements.removeAt(oldIndex);
              mutableElements.insert(newIndex, item);

              // Call the parent's callback with the newly ordered list
              onReorderElementsCallback(mutableElements, category);
          },
          // Optional: Add proxy decorator like SortOrderWidget
          proxyDecorator: (Widget child, int index, Animation<double> animation) {
            return Material(
                color: Colors.transparent,
                elevation: 6.0,
                shadowColor: ColorWheel.secondaryBackground.withAlpha(150),
                child: child,
            );
          },
        ),
      ],
    );
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
      // Explicitly set TextStyle with primaryText color
      style: const TextStyle(
        color: ColorWheel.primaryText, 
        fontSize: 16.0, // Match defaultText size or adjust as needed
      ),
      cursorColor: ColorWheel.primaryText, // Set caret color explicitly
      // Allow multiple lines for text wrapping
      maxLines: null,
      keyboardType: TextInputType.multiline, // Improve keyboard for multiline
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: ColorWheel.defaultText.copyWith(color: ColorWheel.secondaryText),
        filled: true,
        fillColor: ColorWheel.secondaryBackground,
        // Use border settings consistent with selection widgets
        border: OutlineInputBorder(
          borderRadius: ColorWheel.cardBorderRadius, // Match selection widget container radius
          borderSide: BorderSide(color: ColorWheel.accent.withAlpha(128), width: 1.0), // Match border
        ),
        // Also ensure enabled/focused borders match if needed, or use the main border
        enabledBorder: OutlineInputBorder(
          borderRadius: ColorWheel.cardBorderRadius,
          borderSide: BorderSide(color: ColorWheel.accent.withAlpha(128), width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: ColorWheel.cardBorderRadius,
          borderSide: const BorderSide(color: ColorWheel.accent, width: 1.5), // Slightly thicker focus border
        ),
        contentPadding: ColorWheel.inputFieldPadding, 
        isDense: true,
      ),
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.done, // Use 'done' instead of 'newline'
    );
  }

   // --- Helper for Individual Option Items ---
  Widget _buildOptionItem(Map<String, dynamic> option, int index) {
    bool isCorrect = false;
    IconData toggleIcon = Icons.radio_button_unchecked; // Default
    VoidCallback? onTogglePressed;

    // Determine toggle state and action based on question type
    switch (widget.questionType) {
      case 'multiple_choice':
        isCorrect = widget.correctOptionIndex == index;
        toggleIcon = isCorrect ? Icons.radio_button_checked : Icons.radio_button_unchecked;
        onTogglePressed = () => widget.onSetCorrectOptionIndex(index);
        break;
      case 'select_all_that_apply':
        isCorrect = widget.correctIndicesSATA.contains(index);
        toggleIcon = isCorrect ? Icons.check_box : Icons.check_box_outline_blank;
        onTogglePressed = () => widget.onToggleCorrectOptionSATA(index);
        break;
      case 'true_false': // Should not happen as options are hidden, but handle defensively
      case 'sort_order': // No toggle for sort order
      default:
        toggleIcon = Icons.do_not_disturb_alt; // Indicate no action
        onTogglePressed = null;
        break;
    }

    // Determine if this specific option is being edited
    final bool isEditingThisOption = _editingOptionIndex == index;

    // TODO: Add GestureDetector for double-tap edit (point 2)
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      color: isEditingThisOption 
              ? ColorWheel.accent.withAlpha(50) 
              : (isCorrect ? ColorWheel.buttonSuccess.withAlpha(26) : ColorWheel.secondaryBackground),
      elevation: 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: ColorWheel.buttonBorderRadius,
        side: BorderSide(color: isCorrect ? ColorWheel.buttonSuccess : Colors.transparent, width: 1.0)
      ),
      // Use GestureDetector for double-tap edit
      child: GestureDetector(
        onDoubleTap: () {
          // Only allow editing for text options for now
          if (option['type'] == 'text') {
              QuizzerLogger.logMessage("Starting edit for option at index $index");
              _startEditing(index, 'option', option['content']); // Pass 'option' as type hint
          } else if (option['type'] == 'image') {
              QuizzerLogger.logWarning("Double-tap image edit (replacement) not implemented yet for options.");
              // Potentially call onEditOption directly for image replacement flow
              // widget.onEditOption(index, {}); // Need a way to signal image edit
          }
        },
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 8.0, right: 4.0, top: 4.0, bottom: 4.0),
          // Conditionally build the leading icon button
          leading: onTogglePressed != null 
            ? IconButton(
                icon: Icon(toggleIcon, color: isCorrect ? ColorWheel.buttonSuccess : ColorWheel.secondaryText),
                tooltip: 'Toggle Correctness', // Tooltip only relevant if button exists
                onPressed: onTogglePressed,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              )
            : null, // Set leading to null if no toggle action (e.g., sort_order)
          // Show TextField if editing, otherwise show ElementRenderer
          title: isEditingThisOption
              ? TextField(
                   controller: _editController,
                   focusNode: _editFocusNode,
                   autofocus: true,
                   style: const TextStyle(color: ColorWheel.primaryText, fontSize: 16.0),
                   cursorColor: ColorWheel.primaryText,
                   maxLines: null,
                   keyboardType: TextInputType.multiline,
                   decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                      isDense: true,
                      border: InputBorder.none,
                      focusedBorder: UnderlineInputBorder(
                         borderSide: BorderSide(color: ColorWheel.accent),
                      ),
                   ),
                   onSubmitted: (_) => _submitEdit(),
                  )
              : ElementRenderer(elements: [option]), // Normal view
          trailing: IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 20, color: ColorWheel.buttonError),
            tooltip: 'Remove Option',
            onPressed: () => widget.onRemoveOption(index),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            color: ColorWheel.buttonError,
          ),
          // Prevent normal tap action if editing
          onTap: isEditingThisOption ? () {} : null,
        ),
      ),
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    // Use a Column or ListView depending on expected content height
    return Column(
      children: [
        _buildQuestionElementsSection(),
        const SizedBox(height: 20),
        _buildOptionsSection(),
        const SizedBox(height: 20),
        _buildAnswerElementsSection(),
      ],
    );
  }
}
