import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

class CategorizationPanelWidget extends StatelessWidget {
  const CategorizationPanelWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Simple placeholder for now
    return Container(
      // color: Colors.yellow.withOpacity(0.1), // REMOVE temporary background
      // Use standard padding for consistency
      padding: ColorWheel.standardPadding, 
      child: const Center(
        child: Text(
          'Categorization Panel Placeholder',
          style: ColorWheel.secondaryTextStyle, // Use ColorWheel style
        ),
      ),
    );
  }
}
