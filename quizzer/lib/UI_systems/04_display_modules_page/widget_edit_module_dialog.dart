// TODO [Module Access Control]
// Implement role-based access control for module editing:
// - Create user role system (admin, editor, viewer)
// - Add role check before enabling edit functionality
// - Disable edit buttons for users without proper permissions
// - Show appropriate messaging for unauthorized users
// - Add role management UI for admins

// TODO [Module Viewing Enhancement]
// Convert edit dialog to a view/edit dialog:
// - Rename to ModuleDetailsDialog
// - Show all module details in view mode by default
// - Only show edit controls for authorized users
// - Add tabs or sections for different types of information
// - Improve question display format

// TODO [Question Display Enhancement]
// Show actual question content instead of IDs:
// - Create a question preview component
// - Add pagination for questions
// - Include search/filter for questions
// - Show question stats and metadata
// - Add quick actions for questions (view, edit, delete)

// TODO [Question Management]
// Add question editing capabilities:
// - Create question edit interface
// - Add validation for edits
// - Implement edit history tracking
// - Add bulk edit capabilities
// - Include review system for edits
// - Handle question versioning

import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_edit_question_dialogue.dart';
// import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

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
  final ScrollController _scrollController = ScrollController();

  late Map<String, dynamic> _moduleData;
  late List<String> _questionIds;
  late String _moduleName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.initialDescription);
    _moduleData = Map<String, dynamic>.from(widget.moduleData);
    _moduleName = _moduleData['module_name'] as String;
    final rawQuestionIds = _moduleData['question_ids'];
    if (rawQuestionIds is List) {
      _questionIds = rawQuestionIds.map((e) => e.toString()).toList();
    } else {
      _questionIds = [];
    }
  }

  Future<void> _reloadModuleData() async {
    setState(() => _isLoading = true);
    final newData = await SessionManager().fetchModuleByName(_moduleName);
    final rawQuestionIds = newData['question_ids'];
    List<String> newQuestionIds = [];
    if (rawQuestionIds is List) {
      newQuestionIds = rawQuestionIds.map((e) => e.toString()).toList();
    }
    setState(() {
      _moduleData = newData;
      _questionIds = newQuestionIds;
      _isLoading = false;
    });
    if (widget.onModuleUpdated != null) {
      widget.onModuleUpdated!();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _scrollController.dispose();
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
            // Scrollable content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: ColorWheel.accent))
                  : SingleChildScrollView(
                      controller: _scrollController,
                      padding: ColorWheel.standardPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Description field
                          const Text(
                            'Description',
                            style: ColorWheel.titleText,
                          ),
                          const SizedBox(height: ColorWheel.formFieldSpacing),
                          TextField(
                            controller: _descriptionController,
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
                          const SizedBox(height: ColorWheel.majorSectionSpacing),
                          // Questions section
                          const Text(
                            'Questions in Module',
                            style: ColorWheel.titleText,
                          ),
                          const SizedBox(height: ColorWheel.formFieldSpacing),
                          Container(
                            decoration: BoxDecoration(
                              color: ColorWheel.primaryBackground,
                              borderRadius: ColorWheel.textFieldBorderRadius,
                            ),
                            padding: ColorWheel.inputFieldPadding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Questions: ${_questionIds.length}',
                                  style: ColorWheel.secondaryTextStyle,
                                ),
                                const SizedBox(height: ColorWheel.formFieldSpacing),
                                ..._questionIds.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final id = entry.value;
                                  return _QuestionPreviewRow(
                                    questionId: id,
                                    isAlternate: idx % 2 == 1,
                                    onEdit: () async {
                                      final details = await SessionManager().fetchQuestionDetailsById(id);
                                      final result = await showDialog(
                                        context: context,
                                        builder: (context) => EditQuestionDialog(initialQuestionData: details),
                                      );
                                      if (result != null && result is Map<String, dynamic>) {
                                        await _reloadModuleData();
                                      }
                                    },
                                    moduleName: _moduleName,
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            // Fixed footer with buttons
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
    );
  }
}

class _QuestionPreviewRow extends StatelessWidget {
  final String questionId;
  final VoidCallback onEdit;
  final bool isAlternate;
  final String moduleName;

  const _QuestionPreviewRow({
    required this.questionId,
    required this.onEdit,
    required this.isAlternate,
    required this.moduleName,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isAlternate
        ? ColorWheel.previewAlternateBackground
        : ColorWheel.previewDefaultBackground;
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: ColorWheel.textFieldBorderRadius,
      ),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: FutureBuilder<Map<String, dynamic>>(
        future: SessionManager().fetchQuestionDetailsById(questionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ColorWheel.accent),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Loading question...',
                    style: ColorWheel.secondaryTextStyle,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: ColorWheel.accent),
                  onPressed: onEdit,
                  tooltip: 'Edit Question',
                  padding: EdgeInsets.zero,
                ),
              ],
            );
          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error loading question',
                    style: ColorWheel.secondaryTextStyle.copyWith(color: Colors.red),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: ColorWheel.accent),
                  onPressed: onEdit,
                  tooltip: 'Edit Question',
                  padding: EdgeInsets.zero,
                ),
              ],
            );
          } else {
            final data = snapshot.data!;
            // Only show if the question still belongs to this module
            if (data['module_name'] != moduleName) {
              return const SizedBox.shrink();
            }
            final questionElements = data['question_elements'] as List<dynamic>?;
            String previewText = '[No preview available]';
            if (questionElements != null && questionElements.isNotEmpty) {
              final firstElement = questionElements.first;
              if (firstElement is Map && firstElement.containsKey('content')) {
                previewText = firstElement['content'].toString();
              } else {
                previewText = questionElements.first.toString();
              }
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    previewText,
                    style: ColorWheel.secondaryTextStyle.copyWith(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: ColorWheel.accent),
                  onPressed: onEdit,
                  tooltip: 'Edit Question',
                  padding: EdgeInsets.zero,
                ),
              ],
            );
          }
        },
      ),
    );
  }
}