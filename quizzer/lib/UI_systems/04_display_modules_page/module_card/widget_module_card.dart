import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/module_card/widget_activation_button.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/module_card/widget_edit_module_button.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/module_card/widget_edit_module_dialog.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/module_card/widget_question_type_counts.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/04_module_management/module_management.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/app_theme.dart';
import 'package:quizzer/UI_systems/UI_Utils/ui_helper_functions.dart';

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
        Icon(icon),
        AppTheme.sizedBoxSml,
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
          ),
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
    final formattedModuleName = formatModuleNameForDisplay(moduleName);
    final description = moduleData['description'] ?? '';
    final totalQuestions = moduleData['total_questions'] ?? 0;
    if (totalQuestions == 0) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  formattedModuleName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Remove Expanded from the button row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ActivateOrDeactivateModuleButton(
                    onPressed: _handleActivationToggle,
                    isActive: _isActivated,
                  ),
                  AppTheme.sizedBoxSml,
                  EditModuleButton(
                    onPressed: _handleEditModule,
                  ),
                ],
              ),
            ],
          ),
          AppTheme.sizedBoxMed,
          Visibility(
            visible: description.isNotEmpty,
            child: Column(
              children: [
                Text(description),
                AppTheme.sizedBoxMed,
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side: Total Questions
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Questions'),
                    _buildMetadataItem(
                      Icons.question_answer,
                      '$totalQuestions questions',
                    ),
                  ],
                ),
              ),
              AppTheme.sizedBoxMed,
              // Right side: Total By Type
              if (moduleData.containsKey('question_count_by_type'))
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total By Type'),
                      QuestionTypeCountsWidget(
                        questionCountByType: Map<String, int>.from(
                          moduleData['question_count_by_type'] as Map? ?? {}
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
} 