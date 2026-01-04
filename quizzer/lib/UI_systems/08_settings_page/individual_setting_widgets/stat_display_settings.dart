import 'package:flutter/material.dart';
import 'package:quizzer/app_theme.dart';

class StatDisplaySettings extends StatelessWidget {
  const StatDisplaySettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // H2 header for the section
        Text(
          'Home Page Statistics Display',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        AppTheme.sizedBoxSml,
        const Text(
          'Toggle the statistics you want to display directly on the home page. '
          'When enabled, these stats will appear alongside your questions, '
          'allowing you to track your progress without navigating to the stats page.',
        ),
        const Text(
          'Under Construction no User Settings deployed yet. Hang Tight'
        )
      ],
    );
  }
}
