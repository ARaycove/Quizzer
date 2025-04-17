import 'package:flutter/material.dart';
import 'package:quizzer/features/modules/widgets/module_action_buttons.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';

class ModuleCard extends StatelessWidget {
  final Map<String, dynamic> moduleData;
  final bool isActivated;
  final VoidCallback onToggleActivation;

  const ModuleCard({
    super.key,
    required this.moduleData,
    required this.isActivated,
    required this.onToggleActivation,
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
                  onEditPressed: () {
                    QuizzerLogger.logMessage('Edit module button pressed for: ${moduleData['module_name']}');
                    // TODO: Implement edit module functionality
                  },
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