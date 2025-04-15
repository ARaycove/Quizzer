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
import 'package:image_picker/image_picker.dart';
import 'package:quizzer/backend/quizzer_logging.dart';
import 'package:quizzer/backend/session_manager.dart';
import 'package:quizzer/backend/utils.dart';
import 'package:quizzer/database/tables/question_answer_pairs.dart';
import 'package:quizzer/ui_pages/custom_widgets/module_selection.dart';
import 'package:quizzer/ui_pages/custom_widgets/question_type_selection.dart';
import 'package:quizzer/ui_pages/custom_widgets/question_answer_element.dart';
import 'package:quizzer/ui_pages/custom_widgets/question_entry_options_dialog.dart';
import 'package:quizzer/ui_pages/custom_widgets/submit_clear_buttons.dart';

// Colors
const Color _backgroundColor = Color(0xFF0A1929); // Primary Background
const Color _surfaceColor = Color(0xFF1E2A3A); // Secondary Background
const Color _textColor = Colors.white; // Primary Text
const double _spacing = 16.0;

// ==========================================

// Widgets
class AddQuestionAnswerPage extends StatefulWidget {
  const AddQuestionAnswerPage({super.key});

  @override
  State<AddQuestionAnswerPage> createState() => _AddQuestionAnswerPageState();
}

class _AddQuestionAnswerPageState extends State<AddQuestionAnswerPage> {
  final _moduleController = TextEditingController();
  final _questionTypeController = TextEditingController();
  final List<QAContent> _questionElements = [];
  final List<QAContent> _answerElements = [];
  final _imagePicker = ImagePicker();
  late final SessionManager _sessionManager;
  final List<String> _options = [];
  int _correctOptionIndex = -1;

  @override
  void initState() {
    super.initState();
    _sessionManager = SessionManager();
    _moduleController.text = 'general';
    _questionTypeController.text = 'multiple_choice';
    _questionTypeController.addListener(_handleQuestionTypeChange);
  }

  @override
  void dispose() {
    _moduleController.dispose();
    _questionTypeController.dispose();
    super.dispose();
  }

  void _handleQuestionTypeChange() {
    setState(() {
      // Reset options when question type changes
      _options.clear();
      _correctOptionIndex = -1;
    });
  }

  void _handleOptionsChanged(List<String> newOptions) {
    setState(() {
      _options.clear();
      _options.addAll(newOptions);
    });
  }

  void _handleCorrectOptionChanged(int newIndex) {
    setState(() {
      _correctOptionIndex = newIndex;
    });
  }

  String getCurrentModuleSelection() {
    final currentModule = _moduleController.text;
    QuizzerLogger.logMessage('Fetching current module selection: $currentModule');
    return currentModule;
  }

  void _handleQuestionElementsChanged(List<QAContent> newElements) {
    setState(() {
      _questionElements.clear();
      _questionElements.addAll(newElements);
    });
  }

  void _handleAnswerElementsChanged(List<QAContent> newElements) {
    setState(() {
      _answerElements.clear();
      _answerElements.addAll(newElements);
    });
  }

  void _handleSubmit() async {
    if (_validateForm()) {
      // Convert QAContent to Map format required by database
      final questionElements = await Future.wait(_questionElements.map((e) async {
        if (e.type == 'image') {
          // Move image to final location and get just the filename
          final filename = await moveImageToFinalLocation(e.content);
          return {
            'type': e.type,
            'content': filename,
          };
        }
        return {
          'type': e.type,
          'content': e.content,
        };
      }).toList());
      
      final answerElements = await Future.wait(_answerElements.map((e) async {
        if (e.type == 'image') {
          // Move image to final location and get just the filename
          final filename = await moveImageToFinalLocation(e.content);
          return {
            'type': e.type,
            'content': filename,
          };
        }
        return {
          'type': e.type,
          'content': e.content,
        };
      }).toList());

      // Get current timestamp
      final timeStamp = DateTime.now().toIso8601String();

      // Get user ID from session manager - crash if null
      final userId = _sessionManager.userId;
      if (userId == null) {
        throw Exception('Security Error: Attempted to add question without valid user session');
      }

      // Add to database
      await addQuestionAnswerPair(
        timeStamp: timeStamp,
        questionElements: questionElements,
        answerElements: answerElements,
        ansFlagged: false,
        ansContrib: userId,
        qstContrib: userId,
        hasBeenReviewed: false,
        flagForRemoval: false,
        moduleName: _moduleController.text,
        questionType: _questionTypeController.text,
        options: _questionTypeController.text == 'multiple_choice' ? _options : null,
        correctOptionIndex: _questionTypeController.text == 'multiple_choice' ? _correctOptionIndex : null,
      );

      _showSuccessSnackBar('Question-Answer pair saved successfully!');
      _handleClear(); // Clear the form after successful submission
    }
  }

  bool _validateForm() {
    QuizzerLogger.logMessage('Starting form validation...');

    // Check if module is selected
    // TODO: Formal validation of module name
    if (_moduleController.text.isEmpty) {
      QuizzerLogger.logMessage('Module validation failed: Expected non-empty module, got empty');
      _showErrorSnackBar('Please select a module');
      return false;
    }
    QuizzerLogger.logMessage('Module validation passed: Selected module is "${_moduleController.text}"');

    // Check if question type is selected
    if (_questionTypeController.text.isEmpty) {
      QuizzerLogger.logMessage('Question type validation failed: Expected non-empty type, got empty');
      _showErrorSnackBar('Please select a question type');
      return false;
    }
    QuizzerLogger.logMessage('Question type validation passed: Selected type is "${_questionTypeController.text}"');

    // Check if question has content
    if (_questionElements.isEmpty) {
      QuizzerLogger.logMessage('Question content validation failed: Expected at least one element, got none');
      _showErrorSnackBar('Please add content to the question');
      return false;
    }
    QuizzerLogger.logMessage('Question content validation passed: Found ${_questionElements.length} elements');

    // Check if answer has content
    if (_answerElements.isEmpty) {
      QuizzerLogger.logMessage('Answer content validation failed: Expected at least one element, got none');
      _showErrorSnackBar('Please add content to the answer');
      return false;
    }
    QuizzerLogger.logMessage('Answer content validation passed: Found ${_answerElements.length} elements');

    // Additional validation for multiple choice questions
    if (_questionTypeController.text == 'multiple_choice') {
      if (_options.isEmpty) {
        QuizzerLogger.logMessage('Multiple choice options validation failed: Expected at least one option, got none');
        _showErrorSnackBar('Please add options for the multiple choice question');
        return false;
      }
      QuizzerLogger.logMessage('Multiple choice options validation passed: Found ${_options.length} options');

      if (_correctOptionIndex == -1) {
        QuizzerLogger.logMessage('Correct option validation failed: Expected selected option, got none');
        _showErrorSnackBar('Please select the correct answer for the multiple choice question');
        return false;
      }
      QuizzerLogger.logMessage('Correct option validation passed: Selected option index is $_correctOptionIndex');
    }

    // Log final form data
    QuizzerLogger.logMessage('Form validation completed successfully');
    QuizzerLogger.logMessage('Final form data:');
    QuizzerLogger.logMessage('Module: ${_moduleController.text}');
    QuizzerLogger.logMessage('Question Type: ${_questionTypeController.text}');
    QuizzerLogger.logMessage('Question Elements: ${_questionElements.map((e) => '{"type":"${e.type}","content":"${e.content}"}').join(',')}');
    QuizzerLogger.logMessage('Answer Elements: ${_answerElements.map((e) => '{"type":"${e.type}","content":"${e.content}"}').join(',')}');
    if (_questionTypeController.text == 'multiple_choice') {
      QuizzerLogger.logMessage('Options: ${_options.join(',')}');
      QuizzerLogger.logMessage('Correct Option Index: $_correctOptionIndex');
    }

    return true;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleClear() {
    setState(() {
      _questionElements.clear();
      _answerElements.clear();
      _options.clear();
      _correctOptionIndex = -1;
      _moduleController.text = 'general';
      _questionTypeController.text = 'multiple_choice';
    });
    QuizzerLogger.logMessage('Cleared all form fields');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Question-Answer Pair',
          style: TextStyle(color: _textColor),
        ),
        backgroundColor: _surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textColor),
          onPressed: () {
            final previousPage = _sessionManager.getPreviousPage();
            if (previousPage != null) {
              Navigator.of(context).pushReplacementNamed(previousPage);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: _textColor),
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/home');
            },
          ),
        ],
      ),
      backgroundColor: _backgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(_spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModuleSelection(controller: _moduleController),
            const SizedBox(height: _spacing),
            QuestionTypeSelection(controller: _questionTypeController),
            const SizedBox(height: _spacing * 2),
            const Text(
              'Question Entry',
              style: TextStyle(
                color: _textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: _spacing),
            QuestionAnswerElement(
              elements: _questionElements,
              onElementsChanged: _handleQuestionElementsChanged,
              isQuestion: true,
              picker: _imagePicker,
            ),
            if (_questionTypeController.text == 'multiple_choice')
              Padding(
                padding: const EdgeInsets.only(top: _spacing),
                child: QuestionEntryOptionsDialog(
                  options: _options,
                  onOptionsChanged: _handleOptionsChanged,
                  correctOptionIndex: _correctOptionIndex,
                  onCorrectOptionChanged: _handleCorrectOptionChanged,
                ),
              ),
            const SizedBox(height: _spacing * 2),
            const Text(
              'Answer Entry',
              style: TextStyle(
                color: _textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: _spacing),
            QuestionAnswerElement(
              elements: _answerElements,
              onElementsChanged: _handleAnswerElementsChanged,
              isQuestion: false,
              picker: _imagePicker,
            ),
            const SizedBox(height: _spacing * 2),
            SubmitClearButtons(
              onSubmit: _handleSubmit,
              onClear: _handleClear,
            ),
          ],
        ),
      ),
    );
  }
} 