import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/widget_module_selection.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/add_question_widget/widget_add_question.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/widget_live_preview.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';


class EditQuestionDialog extends StatefulWidget {
  final String questionId;
  final bool disableSubmission;
  final Map<String, dynamic>? questionData; // NEW: Optional pre-loaded question data

  const EditQuestionDialog({
    super.key, 
    required this.questionId,
    this.disableSubmission = false,
    this.questionData, // NEW: Optional parameter
  });

  @override
  State<EditQuestionDialog> createState() => _EditQuestionDialogState();
}

class _EditQuestionDialogState extends State<EditQuestionDialog> {
  final SessionManager _session = SessionManager();
  late final TextEditingController _moduleController;
  late final String _questionType;

  // State for editing
  late List<Map<String, dynamic>> _questionElements;
  late List<Map<String, dynamic>> _answerElements;
  late List<Map<String, dynamic>> _options;
  int? _correctOptionIndex;
  List<int> _correctIndicesSATA = [];
  int _previewRebuildCounter = 0;

  late final String _originalModuleName; // Track the original module name
  
  // Loading state
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQuestionData();
  }

  Future<void> _loadQuestionData() async {
    try {
      QuizzerLogger.logMessage('EditQuestionDialog: Loading question data for ID: ${widget.questionId}');
      
      Map<String, dynamic> data;
      
      // Use passed data if available, otherwise fetch from SessionManager
      if (widget.questionData != null) {
        QuizzerLogger.logMessage('EditQuestionDialog: Using passed question data');
        data = widget.questionData!;
      } else {
        QuizzerLogger.logMessage('EditQuestionDialog: Fetching question data from SessionManager');
        // Fetch question data through SessionManager API
        data = await _session.fetchQuestionDetailsById(widget.questionId);
      }
      
      if (mounted) {
        setState(() {
          _questionType = data['question_type'] as String;
          _moduleController = TextEditingController(text: data['module_name'] as String? ?? '');
          _originalModuleName = data['module_name'] as String? ?? '';
          _questionElements = (data['question_elements'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
          _answerElements = (data['answer_elements'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
          _options = (data['options'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
          _correctOptionIndex = data['correct_option_index'] as int?;
          _correctIndicesSATA = (data['index_options_that_apply'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [];
          _isLoading = false;
        });
        
        QuizzerLogger.logSuccess('EditQuestionDialog: Successfully loaded question data');
      }
    } catch (e) {
      QuizzerLogger.logError('EditQuestionDialog: Error loading question data: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load question data: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _handleAddElement(String typeOrContent, String category) {
    final newElement = {'type': 'text', 'content': typeOrContent};
    setState(() {
      if (category == 'question') {
        _questionElements.add(newElement);
      } else if (category == 'answer') {
        _answerElements.add(newElement);
      }
      _previewRebuildCounter++;
    });
  }

  void _handleRemoveElement(int index, String category) {
    setState(() {
      if (category == 'question' && index >= 0 && index < _questionElements.length) {
        _questionElements.removeAt(index);
      } else if (category == 'answer' && index >= 0 && index < _answerElements.length) {
        _answerElements.removeAt(index);
      }
      _previewRebuildCounter++;
    });
  }

  void _handleEditElement(int index, String category, Map<String, dynamic> updatedElement) {
    setState(() {
      if (category == 'question' && index >= 0 && index < _questionElements.length) {
        _questionElements[index] = updatedElement;
      } else if (category == 'answer' && index >= 0 && index < _answerElements.length) {
        _answerElements[index] = updatedElement;
      }
      _previewRebuildCounter++;
    });
  }

  void _handleAddOption(Map<String, dynamic> newOption) {
    setState(() {
      _options.add(newOption);
      if (_options.length == 1 && (_questionType == 'multiple_choice')) {
        _correctOptionIndex = 0;
      }
      _previewRebuildCounter++;
    });
  }

  void _handleRemoveOption(int index) {
    setState(() {
      if (index >= 0 && index < _options.length) {
        _options.removeAt(index);
        if (_options.isEmpty) {
          _correctOptionIndex = null;
          _correctIndicesSATA = [];
        }
        _previewRebuildCounter++;
      }
    });
  }

  void _handleEditOption(int index, Map<String, dynamic> updatedOption) {
    setState(() {
      if (index >= 0 && index < _options.length) {
        _options[index] = updatedOption;
        _previewRebuildCounter++;
      }
    });
  }

  void _handleSetCorrectOptionIndex(int index) {
    setState(() {
      _correctOptionIndex = index;
      _previewRebuildCounter++;
    });
  }

  void _handleToggleCorrectOptionSATA(int index) {
    setState(() {
      if (_correctIndicesSATA.contains(index)) {
        _correctIndicesSATA.remove(index);
      } else {
        _correctIndicesSATA.add(index);
      }
      _previewRebuildCounter++;
    });
  }

  void _handleReorderElements(List<Map<String, dynamic>> reordered, String category) {
    setState(() {
      if (category == 'question') {
        _questionElements = List<Map<String, dynamic>>.from(reordered);
      } else if (category == 'answer') {
        _answerElements = List<Map<String, dynamic>>.from(reordered);
      }
      _previewRebuildCounter++;
    });
  }

  void _handleReorderOptions(List<Map<String, dynamic>> reordered) {
    setState(() {
      _options = List<Map<String, dynamic>>.from(reordered);
      _previewRebuildCounter++;
    });
  }

  bool _validateQuestionData() {
    if (_questionElements.isEmpty) return false;
    if (_answerElements.isEmpty) return false;
    if ((_questionType == 'multiple_choice' || _questionType == 'select_all_that_apply' || _questionType == 'sort_order') && _options.length < 2) return false;
    if ((_questionType == 'multiple_choice' || _questionType == 'true_false') && _correctOptionIndex == null) return false;
    if (_questionType == 'select_all_that_apply' && _correctIndicesSATA.isEmpty) return false;
    return true;
  }

  void _handleSubmit() async {
    if (!_validateQuestionData()) {
      QuizzerLogger.logWarning('Validation failed: Please fill all required fields.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Validation failed: Please fill all required fields.'), backgroundColor: ColorWheel.buttonError),
        );
      }
      return;
    }

    // Construct the map of data that will be sent for update
    // This is also the data we want to return to the caller
    final Map<String, dynamic> updatedQuestionDataForSession = {
      'question_id': widget.questionId, // Essential for SessionManager to identify
      'module_name': _moduleController.text,
      'question_elements': _questionElements,
      'answer_elements': _answerElements,
      'options': _options.isNotEmpty ? _options : null,
      'correct_option_index': _correctOptionIndex,
      'index_options_that_apply': _correctIndicesSATA.isNotEmpty ? _correctIndicesSATA : null,
      'question_type': _questionType,
      // Include other fields that SessionManager might need or that UI might use directly
      // For example, if the dialog modifies 'subjects' or 'concepts', add them here.
      // For now, keeping it to what's explicitly handled by _session.updateExistingQuestion
    };

    // --- Conditionally call updateExistingQuestion --- 
    if (!widget.disableSubmission) {
      QuizzerLogger.logMessage('EditQuestionDialog: Submitting changes to SessionManager.');
      await _session.updateExistingQuestion(
        questionId: widget.questionId,
        moduleName: _moduleController.text,
        questionElements: _questionElements,
        answerElements: _answerElements,
        options: _options.isNotEmpty ? _options : null,
        correctOptionIndex: _correctOptionIndex,
        indexOptionsThatApply: _correctIndicesSATA.isNotEmpty ? _correctIndicesSATA : null,
        questionType: _questionType,
        originalModuleName: _originalModuleName, // Pass the original module name
      );
    } else {
      QuizzerLogger.logMessage('EditQuestionDialog: Submission disabled, skipping SessionManager update.');
    }
    // -----------------------------------------------

    if (mounted) {
      // Pop with the updated data map regardless of submission status
      Navigator.of(context).pop(updatedQuestionDataForSession); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = screenWidth * 0.85 > 460 ? 460.0 : screenWidth * 0.85;
    final maxDialogHeight = screenHeight * 0.8;

    if (_isLoading) {
      return Dialog(
        backgroundColor: ColorWheel.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: ColorWheel.cardBorderRadius),
        child: SizedBox(
          width: dialogWidth,
          child: const Padding(
            padding: ColorWheel.standardPadding,
            child: Center(
              child: CircularProgressIndicator(color: ColorWheel.primaryText),
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Dialog(
        backgroundColor: ColorWheel.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: ColorWheel.cardBorderRadius),
        child: SizedBox(
          width: dialogWidth,
          child: Padding(
            padding: ColorWheel.standardPadding,
                         child: Center(
               child: Text(_errorMessage!, style: ColorWheel.titleText),
             ),
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: ColorWheel.secondaryBackground,
      shape: RoundedRectangleBorder(borderRadius: ColorWheel.cardBorderRadius),
      child: SizedBox(
        width: dialogWidth,
        child: Padding(
          padding: ColorWheel.standardPadding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxDialogHeight,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Edit Question', style: ColorWheel.titleText),
                  const SizedBox(height: ColorWheel.majorSectionSpacing),
                  ModuleSelection(controller: _moduleController),
                  const SizedBox(height: ColorWheel.formFieldSpacing),
                  AddQuestionWidget(
                    questionType: _questionType,
                    questionElements: _questionElements,
                    answerElements: _answerElements,
                    options: _options,
                    correctOptionIndex: _correctOptionIndex,
                    correctIndicesSATA: _correctIndicesSATA,
                    onAddElement: _handleAddElement,
                    onRemoveElement: _handleRemoveElement,
                    onEditElement: _handleEditElement,
                    onAddOption: _handleAddOption,
                    onRemoveOption: _handleRemoveOption,
                    onEditOption: _handleEditOption,
                    onSetCorrectOptionIndex: _handleSetCorrectOptionIndex,
                    onToggleCorrectOptionSATA: _handleToggleCorrectOptionSATA,
                    onReorderElements: _handleReorderElements,
                    onReorderOptions: _handleReorderOptions,
                  ),
                  const SizedBox(height: ColorWheel.majorSectionSpacing),
                  const Text('Live Preview:', style: ColorWheel.titleText),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: ColorWheel.secondaryText.withValues(alpha: 0.5)),
                      borderRadius: ColorWheel.cardBorderRadius,
                    ),
                    child: LivePreviewWidget(
                      key: ValueKey('live-preview-$_previewRebuildCounter'),
                      questionType: _questionType,
                      questionElements: _questionElements,
                      answerElements: _answerElements,
                      options: _options,
                      correctOptionIndexMC: _correctOptionIndex,
                      correctIndicesSATA: _correctIndicesSATA,
                      isCorrectAnswerTrueTF: (_questionType == 'true_false') ? (_correctOptionIndex == 0) : null,
                    ),
                  ),
                  const SizedBox(height: ColorWheel.majorSectionSpacing),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: ColorWheel.buttonError,
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: ColorWheel.buttonHorizontalSpacing),
                      ElevatedButton(
                        onPressed: _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorWheel.buttonSuccess,
                          shape: RoundedRectangleBorder(
                            borderRadius: ColorWheel.buttonBorderRadius,
                          ),
                        ),
                        child: const Text('Submit', style: ColorWheel.buttonText),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
