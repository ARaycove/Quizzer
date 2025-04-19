import 'package:flutter/material.dart';
import 'package:quizzer/features/modules/widgets/module_action_buttons.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';
import 'package:quizzer/features/modules/widgets/edit_module_dialog.dart';
import 'package:quizzer/features/modules/functionality/module_isolates.dart';

class ModuleCard extends StatelessWidget {
  final Map<String, dynamic> moduleData;
  final bool isActivated;
  final VoidCallback onToggleActivation;
  final Function(String) onDescriptionUpdated;

  const ModuleCard({
    super.key,
    required this.moduleData,
    required this.isActivated,
    required this.onToggleActivation,
    required this.onDescriptionUpdated,
  });

  Widget _buildMetadataItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4.0),
        Text(
          text,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => EditModuleDialog(
        moduleData: moduleData,
        onSave: (String newDescription) async {
          QuizzerLogger.logMessage('Saving new description for module: ${moduleData['module_name']}');
          final success = await handleUpdateModuleDescription({
            'moduleName': moduleData['module_name'],
            'description': newDescription,
          });
          
          if (success) {
            onDescriptionUpdated(newDescription);
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to update module description'),
                  backgroundColor: Color.fromARGB(255, 214, 71, 71),
                ),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E2A3A),
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Module name and action buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    moduleData['module_name'] ?? 'Unnamed Module',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ModuleActionButtons(
                  onAddPressed: onToggleActivation,
                  onEditPressed: () => _showEditDialog(context),
                  isAdded: isActivated,
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            // Description
            if (moduleData['description'] != null && moduleData['description'].isNotEmpty)
              Text(
                moduleData['description'],
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            const SizedBox(height: 8.0),
            // Metadata row
            Row(
              children: [
                _buildMetadataItem(
                  Icons.question_answer,
                  '${moduleData['total_questions']} questions',
                ),
                const SizedBox(width: 16.0),
                if (moduleData['primary_subject'] != null && moduleData['primary_subject'].isNotEmpty)
                  _buildMetadataItem(
                    Icons.category,
                    moduleData['primary_subject'],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 