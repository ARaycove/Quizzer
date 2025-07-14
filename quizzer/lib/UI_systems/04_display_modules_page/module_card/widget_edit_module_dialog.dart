import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_edit_question_dialogue.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/module_card/widget_rename_merge.dart';
import 'dart:io';


class EditDescription extends StatelessWidget {
  final TextEditingController descriptionController;

  const EditDescription({
    super.key,
    required this.descriptionController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: ColorWheel.titleText,
        ),
        const SizedBox(height: ColorWheel.formFieldSpacing),
        TextField(
          controller: descriptionController,
          maxLines: null,
          minLines: 3,
          style: ColorWheel.secondaryTextStyle,
          decoration: InputDecoration(
            hintText: 'Enter module description',
            hintStyle: ColorWheel.secondaryTextStyle,
            filled: true,
            fillColor: ColorWheel.primaryBackground,
            border: OutlineInputBorder(
              borderRadius: ColorWheel.textFieldBorderRadius,
              borderSide: const BorderSide(color: ColorWheel.secondaryText),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: ColorWheel.textFieldBorderRadius,
              borderSide: const BorderSide(color: ColorWheel.secondaryText),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: ColorWheel.textFieldBorderRadius,
              borderSide: const BorderSide(color: ColorWheel.accent),
            ),
            contentPadding: ColorWheel.inputFieldPadding,
          ),
        ),
      ],
    );
  }
}

class QuestionList extends StatelessWidget {
  final List<Map<String, dynamic>> questionRecords;
  final VoidCallback? onQuestionUpdated;

  const QuestionList({
    super.key,
    required this.questionRecords,
    this.onQuestionUpdated,
  });

  void _showEditQuestionDialog(BuildContext context, Map<String, dynamic> questionRecord) {
    final String questionId = questionRecord['question_id'] as String;
    showDialog(
      context: context,
      builder: (context) => EditQuestionDialog(
        questionId: questionId,
        disableSubmission: false,
      ),
    ).then((result) {
      if (result != null && onQuestionUpdated != null) {
        onQuestionUpdated!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Questions',
          style: ColorWheel.titleText,
        ),
        const SizedBox(height: ColorWheel.formFieldSpacing),
        SizedBox(
          height: 250, // Fixed height for scrollable area
          child: ListView.builder(
            itemCount: questionRecords.length,
            itemBuilder: (context, idx) {
              final questionRecord = questionRecords[idx];
              final questionElements = questionRecord['question_elements'];
              
              Widget questionPreview;
              if (questionElements is List && questionElements.isNotEmpty) {
                final firstElement = questionElements.first;
                if (firstElement is Map<String, dynamic>) {
                  final elementType = firstElement['type'];
                  final elementContent = firstElement['content'];
                  
                  if (elementType == 'text' && elementContent is String) {
                    // Truncate text content
                    final truncatedText = elementContent.length > 50 
                        ? '${elementContent.substring(0, 50)}...' 
                        : elementContent;
                    questionPreview = Text(
                      truncatedText,
                      style: ColorWheel.defaultText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    );
                  } else if (elementType == 'image' && elementContent is String) {
                    // Display small thumbnail from user media directory
                    questionPreview = FutureBuilder<String>(
                      future: getQuizzerMediaPath(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done || !snapshot.hasData) {
                          return Container(
                            width: 40,
                            height: 40,
                            color: ColorWheel.secondaryText,
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }
                        final imagePath = '${snapshot.data}/$elementContent';
                        return Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4.0),
                              child: Image.file(
                                File(imagePath),
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 40,
                                    height: 40,
                                    color: ColorWheel.secondaryText,
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: ColorWheel.primaryText,
                                      size: 20,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  } else {
                    questionPreview = const Text(
                      '[Unsupported element type]',
                      style: ColorWheel.defaultText,
                    );
                  }
                } else {
                  questionPreview = const Text(
                    '[Invalid element format]',
                    style: ColorWheel.defaultText,
                  );
                }
              } else {
                questionPreview = const Text(
                  '[No question elements]',
                  style: ColorWheel.defaultText,
                );
              }
              
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                decoration: BoxDecoration(
                  color: idx % 2 == 0 
                      ? ColorWheel.primaryBackground 
                      : ColorWheel.secondaryBackground,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Row(
                  children: [
                    Expanded(child: questionPreview),
                    IconButton(
                      onPressed: () => _showEditQuestionDialog(context, questionRecord),
                      icon: const Icon(
                        Icons.edit,
                        color: ColorWheel.accent,
                        size: 16,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 16,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class EditModuleDialog extends StatefulWidget {
  final Map<String, dynamic> moduleData;
  final Function(String) onSave;
  final String initialDescription;
  final VoidCallback? onModuleUpdated;

  const EditModuleDialog({
    super.key,
    required this.moduleData,
    required this.onSave,
    required this.initialDescription,
    this.onModuleUpdated,
  });

  @override
  State<EditModuleDialog> createState() => _EditModuleDialogState();
}

class _EditModuleDialogState extends State<EditModuleDialog> {
  late final TextEditingController _descriptionController;
  late String _moduleName;
  late List<Map<String, dynamic>> _questionRecords;
  final SessionManager _session = SessionManager();

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.initialDescription);
    _moduleName = widget.moduleData['module_name'] as String;
    
    // Extract question records from module data
    final rawQuestions = widget.moduleData['questions'];
    if (rawQuestions is List) {
      _questionRecords = rawQuestions.whereType<Map<String, dynamic>>().toList();
    } else {
      _questionRecords = [];
    }
    
    QuizzerLogger.logMessage('EditModuleDialog: Initialized for module: $_moduleName with ${_questionRecords.length} questions');
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.85 > 460 ? 460.0 : screenWidth * 0.85;

    return Dialog(
      backgroundColor: ColorWheel.secondaryBackground,
      shape: RoundedRectangleBorder(
        borderRadius: ColorWheel.cardBorderRadius,
      ),
      child: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: ColorWheel.standardPadding,
                  child: Text(
                    'Edit Module: $_moduleName',
                    style: ColorWheel.titleText,
                  ),
                ),
                const Divider(color: ColorWheel.secondaryText),
                // Rename and Merge Widget (only for admin/contributor users)
                if (_session.userRole == 'admin' || _session.userRole == 'contributor') ...[
                  Padding(
                    padding: ColorWheel.standardPadding,
                    child: ModuleRenameMergeWidget(
                      currentModuleName: _moduleName,
                      onModuleUpdated: () {
                        // Refresh module data when rename/merge operations complete
                        widget.onModuleUpdated?.call();
                        // Close the dialog since the module may have been renamed or merged
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const Divider(color: ColorWheel.secondaryText),
                ],
                // Description field
                Padding(
                  padding: ColorWheel.standardPadding,
                  child: EditDescription(
                    descriptionController: _descriptionController,
                  ),
                ),
                // Question list
                Padding(
                  padding: ColorWheel.standardPadding,
                  child: QuestionList(
                    questionRecords: _questionRecords,
                    onQuestionUpdated: () async {
                      // Refresh the question records when a question is updated
                      try {
                        // Get fresh module data from the database using the more efficient single module call
                        final currentModule = await _session.getModuleDataByName(_moduleName);
                        if (currentModule != null) {
                          setState(() {
                            // Update with fresh question records
                            final rawQuestions = currentModule['questions'];
                            if (rawQuestions is List) {
                              _questionRecords = rawQuestions.whereType<Map<String, dynamic>>().toList();
                            } else {
                              _questionRecords = [];
                            }
                          });
                          QuizzerLogger.logSuccess('Successfully refreshed question records for module: $_moduleName');
                        } else {
                          QuizzerLogger.logWarning('Module $_moduleName not found when refreshing question records');
                        }
                      } catch (e) {
                        QuizzerLogger.logError('Failed to refresh question records: $e');
                      }
                    },
                  ),
                ),
                // Footer with buttons
                Container(
                  padding: ColorWheel.standardPadding,
                  decoration: const BoxDecoration(
                    color: ColorWheel.primaryBackground,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(ColorWheel.cardRadiusValue),
                      bottomRight: Radius.circular(ColorWheel.cardRadiusValue),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'Cancel',
                          style: ColorWheel.secondaryTextStyle,
                        ),
                      ),
                      const SizedBox(width: ColorWheel.buttonHorizontalSpacing),
                      ElevatedButton(
                        onPressed: () {
                          widget.onSave(_descriptionController.text);
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorWheel.buttonSuccess,
                          shape: RoundedRectangleBorder(
                            borderRadius: ColorWheel.buttonBorderRadius,
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: ColorWheel.buttonText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}