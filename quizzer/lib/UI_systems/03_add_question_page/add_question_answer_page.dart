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

// TODO [Question Bank Upload Feature]
// Implement functionality to upload questions in batches via formatted JSON file:
// - Add a file upload button in the UI
// - Create JSON schema for batch question format
// - Add validation for uploaded file format
// - Create batch processing logic for questions
// - Add progress indicator for batch upload
// - Handle errors and provide feedback
// - Consider adding template download option for users

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widget_module_selection.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widget_question_type_selection.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widget_question_answer_element.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widget_question_entry_options_dialog.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widget_submit_clear_buttons.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widget_bulk_add_button.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_global_app_bar.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
// ==========================================

// Widgets
class AddQuestionAnswerPage extends StatefulWidget {
  const AddQuestionAnswerPage({super.key});

  @override
  State<AddQuestionAnswerPage> createState() => _AddQuestionAnswerPageState();
}

class _AddQuestionAnswerPageState extends State<AddQuestionAnswerPage> {
  final                 _moduleController       = TextEditingController();
  final                 _questionTypeController = TextEditingController();
  final List<QAContent> _questionElements       = [];
  final List<QAContent> _answerElements         = [];
  final                 _imagePicker            = ImagePicker();
  final List<String>    _options                = [];
  int                   _correctOptionIndex     = -1;
  SessionManager        session                 = getSessionManager();

  @override
  void initState() {
    super.initState();
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
      QuizzerLogger.logMessage('Submitting question-answer pair...');
      final String module          = _moduleController.text;
      final String questionType    = _questionTypeController.text;
      
      // Get current timestamp
      final String timeStamp = DateTime.now().toIso8601String();
      
      // Convert QAContent objects to maps
      final List<Map<String, dynamic>> questionElementsMaps = 
          _questionElements.map((element) => element.toMap()).toList();
      final List<Map<String, dynamic>> answerElementsMaps = 
          _answerElements.map((element) => element.toMap()).toList();
      
      // Call the API to add the question-answer pair
      await session.addQuestionAnswerPair(
        timeStamp: timeStamp,
        questionElements: questionElementsMaps,
        answerElements: answerElementsMaps,
        moduleName: module,
        questionType: questionType,
        sourcePaths: null, // Add source paths if there are media files
        options: questionType == 'multiple_choice' ? _options : null,
        correctOptionIndex: questionType == 'multiple_choice' ? _correctOptionIndex : null,
      );
      
      QuizzerLogger.logMessage('Question-answer pair submitted successfully');

      _showSuccessSnackBar('Question-Answer pair saved successfully!');
      _handleClear();
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
        backgroundColor: ColorWheel.buttonError,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ColorWheel.buttonSuccess,
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
      appBar: GlobalAppBar(
        title: 'Add Question-Answer Pair',
      ),
      backgroundColor: ColorWheel.primaryBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ColorWheel.standardPaddingValue),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModuleSelection(controller: _moduleController),
            const SizedBox(height: ColorWheel.standardPaddingValue),
            QuestionTypeSelection(controller: _questionTypeController),
            const SizedBox(height: ColorWheel.majorSectionSpacing),
            const Text(
              'Question Entry',
              style: ColorWheel.titleText,
            ),
            const SizedBox(height: ColorWheel.standardPaddingValue),
            QuestionAnswerElement(
              elements: _questionElements,
              onElementsChanged: _handleQuestionElementsChanged,
              isQuestion: true,
              picker: _imagePicker,
            ),
            if (_questionTypeController.text == 'multiple_choice')
              Padding(
                padding: const EdgeInsets.only(top: ColorWheel.standardPaddingValue),
                child: QuestionEntryOptionsDialog(
                  options: _options,
                  onOptionsChanged: _handleOptionsChanged,
                  correctOptionIndex: _correctOptionIndex,
                  onCorrectOptionChanged: _handleCorrectOptionChanged,
                ),
              ),
            const SizedBox(height: ColorWheel.majorSectionSpacing),
            const Text(
              'Answer Entry',
              style: ColorWheel.titleText,
            ),
            const SizedBox(height: ColorWheel.standardPaddingValue),
            QuestionAnswerElement(
              elements: _answerElements,
              onElementsChanged: _handleAnswerElementsChanged,
              isQuestion: false,
              picker: _imagePicker,
            ),
            const SizedBox(height: ColorWheel.majorSectionSpacing),
            SubmitClearButtons(
              onSubmit: _handleSubmit,
              onClear: _handleClear,
            ),
            const SizedBox(height: 20.0),
            const Divider(thickness: 1.0),
            const SizedBox(height: 10.0),
            Center(child: BulkAddButton()),
          ],
        ),
      ),
    );
  }
} 