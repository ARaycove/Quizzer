/*
Add Question Answer Pair Page Description:
This page provides a streamlined interface for creating complete question-answer pairs.
Key features:
- Source Material Selection with citation display
- Question and Answer entry fields
- Media support for both questions and answers
- Subject classification and concept tagging
- Content moderation tags
- Preview functionality
- Submit button for saving to database

TODO: Future Improvements
1. Math Support
   - Add LaTeX/math equation support for text elements
   - Add inline math editor with preview
   - Add common math symbols toolbar

2. Media Elements
   - Add audio element support with file upload
   - Add video element support with file upload
   - Add media player preview for audio/video elements
   - Add file size limits and format validation

3. User Guidance
   - Add tooltips to explain:
     * Module field purpose and usage
     * Question type selection
     * Multiple choice options
     * Text and media element buttons
     * Reordering functionality
     * Double-tap to edit
*/

import 'package:flutter/material.dart';
import 'package:quizzer/backend/quizzer_logging.dart';
import 'package:quizzer/database/tables/question_answer_pairs.dart';
import 'package:quizzer/backend/session_manager.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

// Element model to represent both text and media elements
class Element {
  final String type; // 'text' or 'image'
  final String content; // text content or image filename

  Element({
    required this.type,
    required this.content,
  });
}

// Widget to display a list of elements with drag and drop functionality
class ElementList extends StatefulWidget {
  final List<Element> elements;
  final Function(List<Element>) onElementsChanged;
  final Function() onAddText;
  final Function() onAddMedia;

  const ElementList({
    super.key,
    required this.elements,
    required this.onElementsChanged,
    required this.onAddText,
    required this.onAddMedia,
  });

  @override
  State<ElementList> createState() => _ElementListState();
}

class _ElementListState extends State<ElementList> {
  void _reorderElements(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final List<Element> newElements = List.from(widget.elements);
    final Element element = newElements.removeAt(oldIndex);
    newElements.insert(newIndex, element);
    widget.onElementsChanged(newElements);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
              leading: IconButton(
                icon: const Icon(Icons.delete, color: _textColor),
                onPressed: () {
                  setState(() {
                    widget.elements.removeAt(index);
                    widget.onElementsChanged(widget.elements);
                  });
                },
              ),
              title: element.type == 'text'
                  ? Text(element.content, style: const TextStyle(color: _textColor))
                  : Image.file(File(element.content), height: 100),
              trailing: const Icon(Icons.drag_handle, color: Colors.grey),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.text_fields, color: _textColor),
              onPressed: widget.onAddText,
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.image, color: _textColor),
              onPressed: widget.onAddMedia,
            ),
          ],
        ),
      ],
    );
  }
}

// Colors
const Color _backgroundColor = Color(0xFF0A1929);
const Color _fieldBackgroundColor = Color(0xFF1E2A3A);
const Color _accentColor = Color(0xFF4CAF50);
const Color _textColor = Colors.white;
const Color _hintColor = Colors.grey;
const Color _errorColor = Colors.red;

// ==========================================

// Widgets
class AddQuestionAnswerPage extends StatefulWidget {
  const AddQuestionAnswerPage({super.key});

  @override
  State<AddQuestionAnswerPage> createState() => _AddQuestionAnswerPageState();
}

class _AddQuestionAnswerPageState extends State<AddQuestionAnswerPage> {
  final _formKey = GlobalKey<FormState>();
  final _optionsController = TextEditingController();
  final _optionsFocusNode = FocusNode();
  final _options = <String>[];
  int _correctOptionIndex = -1;
  String _selectedQuestionType = 'Multiple Choice';
  final _moduleController = TextEditingController(); // Module text field controller
  
  // New state variables for elements
  List<Element> _questionElements = [];
  List<Element> _answerElements = [];
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _textEntryController = TextEditingController();
  bool _isAddingText = false;
  int? _editingIndex;
  bool _isEditingQuestion = true;
  late final SessionManager _sessionManager;

  @override
  void initState() {
    super.initState();
    _sessionManager = SessionManager();
    _moduleController.text = 'General';
  }

  @override
  void dispose() {
    _optionsController.dispose();
    _optionsFocusNode.dispose();
    _textEntryController.dispose();
    _moduleController.dispose();
    super.dispose();
  }

  void _editElement(int index, bool isQuestion) {
    setState(() {
      _isEditingQuestion = isQuestion;
      _editingIndex = index;
      final elements = isQuestion ? _questionElements : _answerElements;
      if (elements[index].type == 'text') {
        _textEntryController.text = elements[index].content;
        _isAddingText = true;
      } else {
        _handleMediaUpload(context, isQuestion);
      }
    });
  }

  void _reorderQuestionElements(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final List<Element> newElements = List.from(_questionElements);
    final Element element = newElements.removeAt(oldIndex);
    newElements.insert(newIndex, element);
    setState(() {
      _questionElements = newElements;
    });
  }

  void _reorderAnswerElements(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final List<Element> newElements = List.from(_answerElements);
    final Element element = newElements.removeAt(oldIndex);
    newElements.insert(newIndex, element);
    setState(() {
      _answerElements = newElements;
    });
  }

  void _handleTextSubmitted(String text, bool isQuestion) {
    if (text.isNotEmpty) {
      setState(() {
        final elements = isQuestion ? _questionElements : _answerElements;
        if (_editingIndex != null) {
          elements[_editingIndex!] = Element(type: 'text', content: text);
        } else {
          elements.add(Element(type: 'text', content: text));
        }
        _isAddingText = false;
        _editingIndex = null;
        _textEntryController.clear();
      });
    }
  }

  Future<void> _handleMediaUpload(BuildContext context, bool isQuestion) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (image == null) {
        return;
      }

      // Validate that it's an image file
      if (!image.path.toLowerCase().endsWith('.jpg') && 
          !image.path.toLowerCase().endsWith('.jpeg') && 
          !image.path.toLowerCase().endsWith('.png')) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Please select a valid image file (JPG, JPEG, or PNG)'),
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
        if (isQuestion) {
          _questionElements.add(Element(type: 'image', content: stagedPath));
        } else {
          _answerElements.add(Element(type: 'image', content: stagedPath));
        }
      });
    } catch (e) {
      QuizzerLogger.logError('Error handling image upload: $e');
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error handling image: ${e.toString()}'),
          backgroundColor: _errorColor,
        ),
      );
    }
  }

  void _addTextElement(BuildContext context, bool isQuestion) {
    setState(() {
      _isAddingText = true;
      _isEditingQuestion = isQuestion;
      _editingIndex = null;
      _textEntryController.clear();
    });
  }

  void _addOption() {
    if (_options.length < 6 && _optionsController.text.isNotEmpty) {
      setState(() {
        _options.add(_optionsController.text);
        _optionsController.clear();
        if (_selectedQuestionType == 'Multiple Choice' && _optionsFocusNode.hasFocus) {
          _optionsFocusNode.requestFocus();
        }
      });
    }
  }

  void _removeOption(int index) {
    setState(() {
      _options.removeAt(index);
      if (_correctOptionIndex == index) {
        _correctOptionIndex = -1;
      } else if (_correctOptionIndex > index) {
        _correctOptionIndex--;
      }
    });
  }

  void _submitQuestionAnswerPair(BuildContext context) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    if (!_formKey.currentState!.validate()) {
      QuizzerLogger.logError('Form validation failed');
      return;
    }

    // Validate module name
    if (_moduleController.text.trim().isEmpty) {
      QuizzerLogger.logError('Module name is required');
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Please enter a module name'),
          backgroundColor: _errorColor,
        ),
      );
      return;
    }

    // Validate multiple choice options
    if (_selectedQuestionType == 'Multiple Choice') {
      if (_options.isEmpty) {
        QuizzerLogger.logError('No options added for multiple choice question');
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Please add at least one option'),
            backgroundColor: _errorColor,
          ),
        );
        return;
      }

      if (_correctOptionIndex == -1) {
        QuizzerLogger.logError('No correct option selected for multiple choice question');
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Please select the correct option'),
            backgroundColor: _errorColor,
          ),
        );
        return;
      }
    }

    try {
      // Create question_answer_pair_assets directory if it doesn't exist
      final assetsDir = Directory('images/question_answer_pair_assets');
      if (!await assetsDir.exists()) {
        await assetsDir.create(recursive: true);
      }

      // Process all image elements
      for (var element in [..._questionElements, ..._answerElements]) {
        if (element.type == 'image') {
          final sourceFile = File(element.content);
          if (await sourceFile.exists()) {
            final filename = element.content.split('/').last;
            final destinationPath = '${assetsDir.path}/$filename';
            await sourceFile.copy(destinationPath);
            // Update the content to point to the new location
            element = Element(type: 'image', content: destinationPath);
          }
        }
      }

      // Log the raw data structure
      QuizzerLogger.printHeader('Raw Data Structure');
      QuizzerLogger.logMessage('''
Raw Data Feed:
{
  "questionType": "$_selectedQuestionType",
  "module": "${_moduleController.text.trim()}",
  "questionElements": [${_questionElements.map((e) => '{"type":"${e.type}","content":"${e.content}"}').join(',')}],
  "options": [${_options.map((o) => '"$o"').join(',')}],
  "correctOptionIndex": $_correctOptionIndex,
  "answerElements": [${_answerElements.map((e) => '{"type":"${e.type}","content":"${e.content}"}').join(',')}]
}
''');
      QuizzerLogger.printDivider();

      // Convert elements to the format expected by the database
      final questionElements = _questionElements.map((e) => {
        'type': e.type,
        'content': e.content,
      }).toList();

      final answerElements = _answerElements.map((e) => {
        'type': e.type,
        'content': e.content,
      }).toList();

      // Get current user's UUID from session manager
      final currentUserUuid = _sessionManager.userId;
      if (currentUserUuid == null) {
        throw Exception('No user logged in');
      }

      // Add the question-answer pair to the database
      final timestamp = DateTime.now().toIso8601String();
      await addQuestionAnswerPair(
        timeStamp: timestamp,
        citation: '', // Required parameter but not used
        questionElements: questionElements,
        answerElements: answerElements,
        ansFlagged: false,
        ansContrib: currentUserUuid,
        qstContrib: currentUserUuid,
        hasBeenReviewed: false,
        flagForRemoval: false,
        moduleName: _moduleController.text.trim(),
        questionType: _selectedQuestionType,
        options: _selectedQuestionType == 'Multiple Choice' ? _options : null,
        correctOptionIndex: _selectedQuestionType == 'Multiple Choice' ? _correctOptionIndex : null,
      );

      QuizzerLogger.logSuccess('Question-Answer pair submitted successfully');
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Question-Answer pair submitted successfully'),
          backgroundColor: _accentColor,
        ),
      );

      // Clear the form after successful submission
      _clearAllFields();
    } catch (e) {
      QuizzerLogger.logError('Error processing files: $e');
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error processing files: ${e.toString()}'),
          backgroundColor: _errorColor,
        ),
      );
    }
  }

  void _clearAllFields() {
    setState(() {
      _questionElements.clear();
      _answerElements.clear();
      _options.clear();
      _correctOptionIndex = -1;
      _optionsController.clear();
      _textEntryController.clear();
      _isAddingText = false;
      _editingIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Add Question-Answer Pair', style: TextStyle(color: _textColor)),
        backgroundColor: _backgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TODO: Convert to autocomplete/autosuggest field that shows existing modules
              // This will help users find existing modules and maintain consistency
              TextField(
                controller: _moduleController,
                style: const TextStyle(color: _textColor),
                decoration: InputDecoration(
                  labelText: 'Module',
                  labelStyle: const TextStyle(color: _textColor),
                  hintText: 'Enter module name',
                  hintStyle: const TextStyle(color: _hintColor),
                  filled: true,
                  fillColor: _fieldBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _accentColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _accentColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _accentColor),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Question Type Selection
              DropdownButtonFormField<String>(
                value: _selectedQuestionType,
                dropdownColor: _fieldBackgroundColor,
                style: const TextStyle(color: _textColor),
                decoration: InputDecoration(
                  labelText: 'Question Type',
                  labelStyle: const TextStyle(color: _textColor),
                  filled: true,
                  fillColor: _fieldBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _accentColor),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Multiple Choice',
                    child: Text('Multiple Choice', style: TextStyle(color: _textColor)),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _correctOptionIndex = -1;
                    _selectedQuestionType = value!;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Question Elements
              Text(
                'Question',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: _textColor),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: _fieldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accentColor),
                ),
                child: Column(
                  children: [
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: _reorderQuestionElements,
                      children: _questionElements.asMap().entries.map((entry) {
                        final element = entry.value;
                        final index = entry.key;
                        return ListTile(
                          key: Key(element.content),
                          leading: IconButton(
                            icon: const Icon(Icons.delete, color: _textColor),
                            onPressed: () {
                              setState(() {
                                _questionElements.removeAt(index);
                              });
                            },
                          ),
                          title: GestureDetector(
                            onDoubleTap: () => _editElement(index, true),
                            child: element.type == 'text'
                                ? Text(element.content, style: const TextStyle(color: _textColor))
                                : Image.file(File(element.content), height: 100),
                          ),
                          trailing: const Icon(Icons.drag_handle, color: Colors.grey),
                        );
                      }).toList(),
                    ),
                    if (_isAddingText && _isEditingQuestion)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textEntryController,
                                autofocus: true,
                                style: const TextStyle(color: _textColor),
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                decoration: InputDecoration(
                                  hintText: 'Enter text',
                                  hintStyle: const TextStyle(color: _hintColor),
                                  filled: true,
                                  fillColor: _fieldBackgroundColor,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: _accentColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: _accentColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: _accentColor),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: _textColor),
                              onPressed: () {
                                if (_textEntryController.text.isNotEmpty) {
                                  _handleTextSubmitted(_textEntryController.text, true);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.text_fields, color: _textColor),
                          onPressed: () => _addTextElement(context, true),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.image, color: _textColor),
                          onPressed: () => _handleMediaUpload(context, true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Multiple Choice Options
              if (_selectedQuestionType == 'Multiple Choice') ...[
                Text(
                  'Options',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: _textColor),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _optionsController,
                        focusNode: _optionsFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Enter an option',
                          filled: true,
                          fillColor: _fieldBackgroundColor,
                          hintStyle: const TextStyle(color: _hintColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _accentColor),
                          ),
                        ),
                        style: const TextStyle(color: _textColor),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            _addOption();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add, color: _textColor),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  return ListTile(
                    title: Text(option, style: const TextStyle(color: _textColor)),
                    leading: IconButton(
                      icon: Icon(
                        _correctOptionIndex == index ? Icons.check_circle : Icons.cancel,
                        color: _correctOptionIndex == index ? _accentColor : _errorColor,
                        size: 28,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_correctOptionIndex == index) {
                            _correctOptionIndex = -1;
                          } else {
                            _correctOptionIndex = index;
                          }
                        });
                      },
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: _textColor),
                      onPressed: () => _removeOption(index),
                    ),
                  );
                }),
              ],

              // Answer Elements
              Text(
                'Answer',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: _textColor),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: _fieldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accentColor),
                ),
                child: Column(
                  children: [
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: _reorderAnswerElements,
                      children: _answerElements.asMap().entries.map((entry) {
                        final element = entry.value;
                        final index = entry.key;
                        return ListTile(
                          key: Key(element.content),
                          leading: IconButton(
                            icon: const Icon(Icons.delete, color: _textColor),
                            onPressed: () {
                              setState(() {
                                _answerElements.removeAt(index);
                              });
                            },
                          ),
                          title: GestureDetector(
                            onDoubleTap: () => _editElement(index, false),
                            child: element.type == 'text'
                                ? Text(element.content, style: const TextStyle(color: _textColor))
                                : Image.file(File(element.content), height: 100),
                          ),
                          trailing: const Icon(Icons.drag_handle, color: Colors.grey),
                        );
                      }).toList(),
                    ),
                    if (_isAddingText && !_isEditingQuestion)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textEntryController,
                                autofocus: true,
                                style: const TextStyle(color: _textColor),
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                decoration: InputDecoration(
                                  hintText: 'Enter text',
                                  hintStyle: const TextStyle(color: _hintColor),
                                  filled: true,
                                  fillColor: _fieldBackgroundColor,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: _accentColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: _accentColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: _accentColor),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: _textColor),
                              onPressed: () {
                                if (_textEntryController.text.isNotEmpty) {
                                  _handleTextSubmitted(_textEntryController.text, false);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.text_fields, color: _textColor),
                          onPressed: () => _addTextElement(context, false),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.image, color: _textColor),
                          onPressed: () => _handleMediaUpload(context, false),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Submit and Clear Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => _submitQuestionAnswerPair(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Submit', style: TextStyle(color: _textColor)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _clearAllFields,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _errorColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Clear All', style: TextStyle(color: _textColor)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 