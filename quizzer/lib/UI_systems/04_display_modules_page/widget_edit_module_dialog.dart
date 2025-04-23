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

class EditModuleDialog extends StatefulWidget {
  final Map<String, dynamic> moduleData;
  final Function(String) onSave;
  final String initialDescription;

  const EditModuleDialog({
    super.key,
    required this.moduleData,
    required this.onSave,
    required this.initialDescription,
  });

  @override
  State<EditModuleDialog> createState() => _EditModuleDialogState();
}

class _EditModuleDialogState extends State<EditModuleDialog> {
  late final TextEditingController _descriptionController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.initialDescription);
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
    final questionIds = widget.moduleData['question_ids'] as List<String>;

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
                'Edit Module: ${widget.moduleData['module_name']}',
                style: ColorWheel.titleText,
              ),
            ),
            const Divider(color: ColorWheel.secondaryText),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
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
                            'Total Questions: ${questionIds.length}',
                            style: ColorWheel.secondaryTextStyle,
                          ),
                          const SizedBox(height: ColorWheel.formFieldSpacing),
                          ...questionIds.take(10).map((id) => Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Text(
                                  id,
                                  style: ColorWheel.secondaryTextStyle.copyWith(fontSize: 12),
                                ),
                              )),
                          if (questionIds.length > 10)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text("... and ${questionIds.length - 10} more", style: ColorWheel.secondaryTextStyle.copyWith(fontStyle: FontStyle.italic)),
                            ),
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