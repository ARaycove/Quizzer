import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/widget_module_action_buttons.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/widget_edit_module_dialog.dart';
import 'package:quizzer/backend_systems/04_module_management/module_isolates.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

class ModuleCard extends StatefulWidget {
  final Map<String, dynamic> moduleData;
  final bool isActivated;
  final VoidCallback? onModuleUpdated;

  const ModuleCard({
    super.key,
    required this.moduleData,
    required this.isActivated,
    this.onModuleUpdated,
  });

  @override
  State<ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<ModuleCard> {
  late bool _isActivated;
  late String _description;
  final SessionManager session = SessionManager();

  @override
  void initState() {
    super.initState();
    _isActivated = widget.isActivated;
    _description = widget.moduleData['description'] ?? '';
  }

  Future<Map<String, dynamic>> _fetchModuleData() async {
    final moduleName = widget.moduleData['module_name'];
    return await session.fetchModuleByName(moduleName);
  }

  Future<void> _toggleActivation() async {
    final moduleName = widget.moduleData['module_name'];
    if (moduleName == null) {
      QuizzerLogger.logError('Module name is null, cannot toggle activation.');
      return;
    }

    session.toggleModuleActivation(moduleName, !_isActivated);
    QuizzerLogger.logMessage('Sent activation toggle request for "$moduleName" to \\${!_isActivated}');

    if (mounted) {
      setState(() {
        _isActivated = !_isActivated;
      });
    }
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

    if (mounted) {
      setState(() {
        _description = newDescription;
      });
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
          if (widget.onModuleUpdated != null) {
            widget.onModuleUpdated!();
          }
        },
        onModuleUpdated: widget.onModuleUpdated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchModuleData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            color: ColorWheel.secondaryBackground,
            margin: const EdgeInsets.only(bottom: ColorWheel.standardPaddingValue),
            shape: RoundedRectangleBorder(
              borderRadius: ColorWheel.cardBorderRadius,
            ),
            child: const Padding(
              padding: ColorWheel.standardPadding,
              child: Center(
                child: CircularProgressIndicator(color: ColorWheel.accent),
              ),
            ),
          );
        } else if (snapshot.hasError || !snapshot.hasData) {
          return Card(
            color: ColorWheel.secondaryBackground,
            margin: const EdgeInsets.only(bottom: ColorWheel.standardPaddingValue),
            shape: RoundedRectangleBorder(
              borderRadius: ColorWheel.cardBorderRadius,
            ),
            child: const Padding(
              padding: ColorWheel.standardPadding,
              child: Center(
                child: Text('Error loading module', style: ColorWheel.secondaryTextStyle),
              ),
            ),
          );
        }
        final moduleData = snapshot.data!;
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
                    ModuleActionButtons(
                      onAddPressed: _toggleActivation,
                      onEditPressed: () => _showEditDialog(context, description),
                      isAdded: _isActivated,
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
      },
    );
  }
} 