import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

// Model to represent content in a question or answer
class QAContent {
  final String type; // 'text' or 'image'
  final String content; // text content or image filename

  QAContent({
    required this.type,
    required this.content,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'content': content,
    };
  }
}

class QuestionAnswerElement extends StatefulWidget {
  final List<QAContent> elements;
  final Function(List<QAContent>) onElementsChanged;
  final bool isQuestion;
  final ImagePicker picker;

  const QuestionAnswerElement({
    super.key,
    required this.elements,
    required this.onElementsChanged,
    required this.isQuestion,
    required this.picker,
  });

  @override
  State<QuestionAnswerElement> createState() => _QuestionAnswerElementState();
}

class _QuestionAnswerElementState extends State<QuestionAnswerElement> {
  final TextEditingController _textEntryController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  bool _isAddingText = false;
  int? _editingIndex;

  @override
  void initState() {
    super.initState();
    _textFocusNode.addListener(_onTextFocusChange);
  }

  @override
  void dispose() {
    _textFocusNode.removeListener(_onTextFocusChange);
    _textFocusNode.dispose();
    _textEntryController.dispose();
    super.dispose();
  }

  void _onTextFocusChange() {
    if (!_textFocusNode.hasFocus && _isAddingText) {
      final currentText = _textEntryController.text.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (currentText.isNotEmpty) {
          QuizzerLogger.logMessage('Text field lost focus, auto-submitting content: "$currentText"');
          _handleTextSubmitted(currentText);
        } else {
          QuizzerLogger.logMessage('Text field lost focus and was empty, cancelling text entry.');
          setState(() {
            _isAddingText = false;
            _editingIndex = null;
            _textEntryController.clear();
          });
        }
      });
    }
  }

  void _editElement(int index) {
    setState(() {
      _editingIndex = index;
      final element = widget.elements[index];
      if (element.type == 'text') {
        _textEntryController.text = element.content;
        _isAddingText = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _textFocusNode.requestFocus());
      } else {
        _handleMediaUpload(context);
      }
    });
  }

  void _reorderElements(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final List<QAContent> newElements = List.from(widget.elements);
    final QAContent element = newElements.removeAt(oldIndex);
    newElements.insert(newIndex, element);
    widget.onElementsChanged(newElements);
    QuizzerLogger.logMessage('state after reorder: [${newElements.map((e) => '{"type":"${e.type}","content":"${e.content}"}').join(',')}]');
  }

  void _handleTextSubmitted(String text) {
    final trimmedText = text.trim();
    if (trimmedText.isNotEmpty) {
      setState(() {
        if (_editingIndex != null) {
          if (_editingIndex! < widget.elements.length) {
            widget.elements[_editingIndex!] = QAContent(type: 'text', content: trimmedText);
            QuizzerLogger.logMessage('Updated text element at index $_editingIndex');
          } else {
            QuizzerLogger.logError('Editing index $_editingIndex out of bounds!');
             widget.elements.add(QAContent(type: 'text', content: trimmedText));
             QuizzerLogger.logMessage('Added new text element instead due to index error.');
          }
        } else {
          widget.elements.add(QAContent(type: 'text', content: trimmedText));
          QuizzerLogger.logMessage('Added new text element.');
        }
        _isAddingText = false;
        _editingIndex = null;
        _textEntryController.clear();
        widget.onElementsChanged(List.from(widget.elements));
        QuizzerLogger.logMessage('state after text change: [${widget.elements.map((e) => '{"type":"${e.type}","content":"${e.content}"}').join(',')}]');
      });
    } else {
       QuizzerLogger.logMessage('Text submission attempted with empty content, cancelling.');
       setState(() {
          _isAddingText = false;
          _editingIndex = null;
          _textEntryController.clear();
       });
    }
  }

  Future<void> _handleMediaUpload(BuildContext context) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final XFile? image = await widget.picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (image == null) {
        return;
      }

      // Validate file size (max 5MB)
      final fileSize = await image.length();
      if (fileSize > 5 * 1024 * 1024) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Image file size must be less than 5MB'),
            backgroundColor: ColorWheel.buttonError,
          ),
        );
        return;
      }

      // Validate file type
      final validExtensions = ['.jpg', '.jpeg', '.png'];
      final fileExtension = image.path.toLowerCase().substring(image.path.lastIndexOf('.'));
      if (!validExtensions.contains(fileExtension)) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Please select a valid image file (${validExtensions.join(', ')})'),
            backgroundColor: ColorWheel.buttonError,
          ),
        );
        return;
      }

      // Create input_staging directory if it doesn't exist
      final stagingDir = Directory('images/input_staging');
      if (!await stagingDir.exists()) {
        await stagingDir.create(recursive: true);
      }

      // Generate a unique filename for the staged file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final originalFilename = image.path.split('/').last;
      final stagedFilename = '${timestamp}_$originalFilename';
      final stagedPath = '${stagingDir.path}/$stagedFilename';

      // Copy the file to the staging directory
      await File(image.path).copy(stagedPath);

      if (!mounted) return;
      setState(() {
        widget.elements.add(QAContent(type: 'image', content: stagedPath));
        QuizzerLogger.logMessage('state after image add: [${widget.elements.map((e) => '{"type":"${e.type}","content":"${e.content}"}').join(',')}]');
      });
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error uploading media: ${e.toString()}'),
          backgroundColor: ColorWheel.buttonError,
        ),
      );
    }
  }

  void _addTextElement(BuildContext context) {
    setState(() {
      _isAddingText = true;
      _editingIndex = null;
      _textEntryController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _textFocusNode.requestFocus());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorWheel.secondaryBackground,
        borderRadius: ColorWheel.cardBorderRadius,
        border: Border.all(color: ColorWheel.accent.withAlpha(128)),
      ),
      child: Column(
        children: [
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: _reorderElements,
            children: widget.elements.asMap().entries.map((entry) {
              final element = entry.value;
              final index = entry.key;
              return ListTile(
                key: Key(element.content),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: ColorWheel.standardPaddingValue,
                  vertical: ColorWheel.standardPaddingValue / 2,
                ),
                leading: IconButton(
                  icon: const Icon(Icons.delete, color: ColorWheel.buttonError),
                  onPressed: () {
                    setState(() {
                      widget.elements.removeAt(index);
                      widget.onElementsChanged(List.from(widget.elements));
                      QuizzerLogger.logMessage('state after remove: [${widget.elements.map((e) => '{"type":"${e.type}","content":"${e.content}"}').join(',')}]');
                    });
                  },
                ),
                title: GestureDetector(
                  onDoubleTap: () => _editElement(index),
                  child: element.type == 'text'
                      ? Text(
                          element.content,
                          style: ColorWheel.defaultText,
                        )
                      : Image.file(
                          File(element.content),
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                             return const Row(children: [ Icon(Icons.broken_image, color: ColorWheel.warning), SizedBox(width: ColorWheel.iconHorizontalSpacing), Text('[Image unavailable]', style: TextStyle(color: ColorWheel.warning))]);
                          },
                        ),
                ),
                trailing: const Icon(
                  Icons.drag_handle,
                  color: ColorWheel.secondaryText,
                ),
              );
            }).toList(),
          ),
          if (_isAddingText)
            Padding(
              padding: ColorWheel.standardPadding,
              child: Row(
                children: [
                  Expanded(
                    child: RawKeyboardListener(
                      focusNode: FocusNode(),
                      onKey: (RawKeyEvent event) {
                        if (event is RawKeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.enter &&
                            event.isShiftPressed) {
                          if (_textEntryController.text.isNotEmpty) {
                            _handleTextSubmitted(_textEntryController.text);
                          }
                        }
                      },
                      child: TextField(
                        controller: _textEntryController,
                        focusNode: _textFocusNode,
                        autofocus: true,
                        style: ColorWheel.defaultText,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Enter text (Shift+Enter to submit)',
                          hintStyle: ColorWheel.secondaryTextStyle,
                          filled: true,
                          fillColor: ColorWheel.primaryBackground,
                          border: OutlineInputBorder(
                            borderRadius: ColorWheel.textFieldBorderRadius,
                            borderSide: const BorderSide(color: ColorWheel.accent),
                          ),
                          enabledBorder: OutlineInputBorder(
                             borderRadius: ColorWheel.textFieldBorderRadius,
                             borderSide: const BorderSide(color: ColorWheel.accent),
                          ),
                          focusedBorder: OutlineInputBorder(
                             borderRadius: ColorWheel.textFieldBorderRadius,
                             borderSide: const BorderSide(color: ColorWheel.accent, width: 2.0), 
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: ColorWheel.standardPaddingValue,
                            vertical: ColorWheel.standardPaddingValue,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: ColorWheel.standardPaddingValue / 2),
                  IconButton(
                    icon: const Icon(Icons.add, color: ColorWheel.accent),
                    onPressed: () {
                      if (_textEntryController.text.isNotEmpty) {
                        _handleTextSubmitted(_textEntryController.text);
                      }
                    },
                  ),
                ],
              ),
            ),
          Padding(
            padding: ColorWheel.standardPadding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _addTextElement(context),
                  icon: const Icon(Icons.text_fields, color: ColorWheel.primaryText),
                  label: const Text('Add Text', style: ColorWheel.buttonText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorWheel.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: ColorWheel.standardPaddingValue,
                      vertical: ColorWheel.standardPaddingValue / 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: ColorWheel.buttonBorderRadius,
                    ),
                  ),
                ),
                const SizedBox(width: ColorWheel.standardPaddingValue),
                ElevatedButton.icon(
                  onPressed: () => _handleMediaUpload(context),
                  icon: const Icon(Icons.image, color: ColorWheel.primaryText),
                  label: const Text('Add Image', style: ColorWheel.buttonText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorWheel.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: ColorWheel.standardPaddingValue,
                      vertical: ColorWheel.standardPaddingValue / 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: ColorWheel.buttonBorderRadius,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 