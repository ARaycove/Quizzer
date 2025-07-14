import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/module_card/widget_activation_button.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/module_card/widget_edit_module_button.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/module_card/widget_edit_module_dialog.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/04_module_management/module_management.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

class ModuleCard extends StatefulWidget {
  final Map<String, dynamic> moduleData;
  final VoidCallback? onModuleUpdated;

  const ModuleCard({
    super.key,
    required this.moduleData,
    this.onModuleUpdated,
  });

  @override
  State<ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<ModuleCard> {
  late bool _isActivated;
  final SessionManager session = SessionManager();

  @override
  void initState() {
    super.initState();
    // Determine activation state from module data
    _isActivated = widget.moduleData['is_active'] ?? false;
    
    // Debug: Log the actual values
    QuizzerLogger.logMessage('ModuleCard initState for module: ${widget.moduleData['module_name']}');
    QuizzerLogger.logMessage('  is_active from data: ${widget.moduleData['is_active']}');
    QuizzerLogger.logMessage('  _isActivated set to: $_isActivated');
  }

  // Function for activation/deactivation button
  void _handleActivationToggle() async {
    final moduleName = widget.moduleData['module_name'];
    if (moduleName == null) {
      QuizzerLogger.logError('Module name is null, cannot toggle activation.');
      return;
    }

    // Switch the button state immediately for responsive UI
    setState(() {
      _isActivated = !_isActivated;
    });

    try {
      // Fire the API call in the background
      await session.toggleModuleActivation(moduleName, _isActivated);
      QuizzerLogger.logMessage('Successfully toggled activation for module: $moduleName to $_isActivated');
    } catch (e) {
      QuizzerLogger.logError('Failed to toggle activation for module $moduleName: $e');
      // Revert the button state if the API call failed
      setState(() {
        _isActivated = !_isActivated;
      });
    }
  }

  // Function for edit button
  void _handleEditModule() {
    final moduleName = widget.moduleData['module_name'];
    final description = widget.moduleData['description'] ?? '';
    QuizzerLogger.logMessage('Opening edit dialog for module: $moduleName');
    _showEditDialog(context, description);
  }

  Future<void> _updateDescription(String newDescription) async {
    final moduleName = widget.moduleData['module_name'];
    if (moduleName == null) {
      QuizzerLogger.logError('Module name is null, cannot update description.');
      return;
    }

    QuizzerLogger.logMessage('Sending description update for module: $moduleName');
    handleUpdateModuleDescription({
      'moduleName': moduleName,
      'description': newDescription,
    });
    QuizzerLogger.logMessage('Sent description update request for module: $moduleName');
    
    // Trigger refresh of all module cards after description update
    if (widget.onModuleUpdated != null) {
      widget.onModuleUpdated!();
    }
  }

  Widget _buildMetadataItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: ColorWheel.secondaryText),
        const SizedBox(width: ColorWheel.iconHorizontalSpacing / 2),
        Text(
          text,
          style: ColorWheel.secondaryTextStyle.copyWith(fontSize: 14),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, String currentDescription) {
    showDialog(
      context: context,
      builder: (context) => EditModuleDialog(
        moduleData: widget.moduleData,
        initialDescription: currentDescription,
        onSave: (String newDescription) async {
          await _updateDescription(newDescription);
        },
        onModuleUpdated: () async {
          // Refresh the module data when the dialog closes
          if (widget.onModuleUpdated != null) {
            widget.onModuleUpdated!();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moduleData = widget.moduleData;
    final moduleName = moduleData['module_name'] ?? 'Unnamed Module';
    final description = moduleData['description'] ?? '';
    final totalQuestions = moduleData['total_questions'] ?? 0;
    final primarySubject = moduleData['primary_subject'] ?? '';
    if (totalQuestions == 0) {
      return const SizedBox.shrink();
    }
    return Card(
      color: ColorWheel.secondaryBackground,
      margin: const EdgeInsets.only(bottom: ColorWheel.standardPaddingValue),
      shape: RoundedRectangleBorder(
        borderRadius: ColorWheel.cardBorderRadius,
      ),
      child: Padding(
        padding: ColorWheel.standardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    moduleName,
                    style: ColorWheel.titleText,
                  ),
                ),
                Row(
                  children: [
                    ActivateOrDeactivateModuleButton(
                      onPressed: _handleActivationToggle,
                      isActive: _isActivated,
                    ),
                    const SizedBox(width: 8),
                    EditModuleButton(
                      onPressed: _handleEditModule,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: ColorWheel.formFieldSpacing),
            Visibility(
              visible: description.isNotEmpty,
              child: Padding(
                padding: const EdgeInsets.only(bottom: ColorWheel.formFieldSpacing),
                child: Text(
                  description,
                  style: ColorWheel.secondaryTextStyle.copyWith(fontSize: 14),
                ),
              ),
            ),
            Row(
              children: [
                _buildMetadataItem(
                  Icons.question_answer,
                  '$totalQuestions questions',
                ),
                const SizedBox(width: ColorWheel.standardPaddingValue),
                if (primarySubject.isNotEmpty)
                  _buildMetadataItem(
                    Icons.category,
                    primarySubject,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 