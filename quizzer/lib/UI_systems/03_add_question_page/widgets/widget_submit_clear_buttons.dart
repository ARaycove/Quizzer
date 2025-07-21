import 'package:flutter/material.dart';
import 'package:quizzer/app_theme.dart';

class SubmitClearButtons extends StatelessWidget {
  final VoidCallback onSubmit;
  final VoidCallback onClear;

  const SubmitClearButtons({
    super.key,
    required this.onSubmit,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: onSubmit,
          child: const Text('Submit'),
        ),
        AppTheme.sizedBoxMed,
        ElevatedButton(
          onPressed: onClear,
          child: const Text('Clear All'),
        ),
      ],
    );
  }
} 