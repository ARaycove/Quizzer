import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/app_theme.dart';

// Question types mapping
const Map<String, String> _questionTypes = {
  'multiple_choice': 'Multiple Choice',
  'select_all_that_apply': 'Select All That Apply',
  'true_false': 'True/False',
  'sort_order': 'Sort Order',
  'fill_in_the_blank': 'Fill in the Blank',
  // Add other question types here as they become available
};

class QuestionTypeSelection extends StatelessWidget {
  final TextEditingController controller;

  const QuestionTypeSelection({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Use 85% of screen width with a max of 460px to match logo width guideline
    final width = screenWidth * 0.85 > 460 ? 460.0 : screenWidth * 0.85;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Question Type'),
        AppTheme.sizedBoxMed,
        SizedBox(
          width: width,
          child: DropdownButton<String>(
            value: controller.text.isNotEmpty && _questionTypes.containsKey(controller.text) 
                    ? controller.text 
                    : _questionTypes.keys.first,
            isExpanded: true,
            underline: const SizedBox(),
            items: _questionTypes.entries.map((entry) {
              return DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
            onChanged: (value) {
              final newValue = value ?? _questionTypes.keys.first;
              controller.text = newValue;
              QuizzerLogger.logMessage('Question type changed to: $newValue');
            },
          ),
        ),
      ],
    );
  }
} 