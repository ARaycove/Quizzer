import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

// Model to represent content in a question or answer
class QAContent {
  final String type; // 'text' or 'image'
  final String content; // text content or image filename

  QAContent({
    required this.type,
    required this.content,
  });
}

// Colors
const Color _backgroundColor = Color(0xFF0A1929); // Primary Background
const Color _surfaceColor = Color(0xFF1E2A3A); // Secondary Background
const Color _primaryColor = Color(0xFF4CAF50); // Accent Color
const Color _errorColor = Color(0xFFD64747); // Error red
const Color _textColor = Colors.white; // Primary Text
const Color _hintColor = Colors.grey; // Secondary Text
const double _borderRadius = 12.0;
const double _spacing = 16.0;

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
  bool _isAddingText = false;
  int? _editingIndex;

  void _editElement(int index) {
    setState(() {
      _editingIndex = index;
      final element = widget.elements[index];
      if (element.type == 'text') {
        _textEntryController.text = element.content;
        _isAddingText = true;
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
    if (text.isNotEmpty) {
      setState(() {
        if (_editingIndex != null) {
          widget.elements[_editingIndex!] = QAContent(type: 'text', content: text);
        } else {
          widget.elements.add(QAContent(type: 'text', content: text));
        }
        _isAddingText = false;
        _editingIndex = null;
        _textEntryController.clear();
        QuizzerLogger.logMessage('state after text change: [${widget.elements.map((e) => '{"type":"${e.type}","content":"${e.content}"}').join(',')}]');
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
            backgroundColor: _errorColor,
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
            backgroundColor: _errorColor,
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
          backgroundColor: _errorColor,
        ),
      );
    }
  }

  void _addTextElement(BuildContext context) {
    setState(() {
      _isAddingText = true;
      _editingIndex = null;
      _textEntryController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(_borderRadius),
        border: Border.all(color: _primaryColor.withAlpha(128)),
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
                  horizontal: _spacing,
                  vertical: _spacing / 2,
                ),
                leading: IconButton(
                  icon: const Icon(Icons.delete, color: _errorColor),
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
                          style: const TextStyle(color: _textColor),
                        )
                      : Image.file(
                          File(element.content),
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                ),
                trailing: const Icon(
                  Icons.drag_handle,
                  color: _hintColor,
                ),
              );
            }).toList(),
          ),
          if (_isAddingText)
            Padding(
              padding: const EdgeInsets.all(_spacing),
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
                        autofocus: true,
                        style: const TextStyle(color: _textColor),
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Enter text (Shift+Enter to submit)',
                          hintStyle: const TextStyle(color: _hintColor),
                          filled: true,
                          fillColor: _backgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_borderRadius),
                            borderSide: const BorderSide(color: _primaryColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: _spacing,
                            vertical: _spacing,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: _spacing / 2),
                  IconButton(
                    icon: const Icon(Icons.add, color: _primaryColor),
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
            padding: const EdgeInsets.all(_spacing),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _addTextElement(context),
                  icon: const Icon(Icons.text_fields, color: _textColor),
                  label: const Text('Add Text', style: TextStyle(color: _textColor)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: _spacing,
                      vertical: _spacing / 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_borderRadius),
                    ),
                  ),
                ),
                const SizedBox(width: _spacing),
                ElevatedButton.icon(
                  onPressed: () => _handleMediaUpload(context),
                  icon: const Icon(Icons.image, color: _textColor),
                  label: const Text('Add Image', style: TextStyle(color: _textColor)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: _spacing,
                      vertical: _spacing / 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_borderRadius),
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