import 'package:flutter/material.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';

// Colors
const Color _surfaceColor = Color(0xFF1E2A3A); // Secondary Background
const Color _primaryColor = Color(0xFF4CAF50); // Accent Color
const Color _textColor = Colors.white; // Primary Text

// Spacing and Dimensions
const double _borderRadius = 12.0;
const double _spacing = 16.0;
const double _fieldSpacing = 8.0; // Spacing between form fields

// Question types mapping
const Map<String, String> _questionTypes = {
  'multiple_choice': 'Multiple Choice',
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
        Text(
          'Question Type',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _textColor,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: _fieldSpacing),
        Container(
          width: width,
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(_borderRadius),
            border: Border.all(color: _primaryColor.withAlpha(128)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _spacing,
              vertical: 4.0,
            ),
            child: DropdownButton<String>(
              value: 'multiple_choice',
              isExpanded: true,
              dropdownColor: _surfaceColor,
              style: const TextStyle(color: _textColor),
              icon: const Icon(Icons.arrow_drop_down, color: _textColor),
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(_borderRadius),
              items: _questionTypes.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) {
                final newValue = value ?? 'multiple_choice';
                controller.text = newValue;
                QuizzerLogger.logMessage('Question type changed to: $newValue');
              },
            ),
          ),
        ),
      ],
    );
  }
} 