import 'package:flutter/material.dart';
import 'package:quizzer/app_theme.dart';

// ==========================================
//    Editable True/False Option Widget
// ==========================================
// Handles true/false options with button-based selection

class EditableTrueFalseOption extends StatefulWidget {
  final bool isTrueSelected;
  final Function(int index) onSetCorrect;

  const EditableTrueFalseOption({
    super.key,
    required this.isTrueSelected,
    required this.onSetCorrect,
  });

  @override
  State<EditableTrueFalseOption> createState() => _EditableTrueFalseOptionState();
}

class _EditableTrueFalseOptionState extends State<EditableTrueFalseOption> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Correct Answer"),
        AppTheme.sizedBoxMed,
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  // True is index 0
                  widget.onSetCorrect(0);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isTrueSelected 
                    ? Theme.of(context).colorScheme.primary 
                    : Theme.of(context).colorScheme.surface,
                  foregroundColor: widget.isTrueSelected 
                    ? Theme.of(context).colorScheme.onPrimary 
                    : Theme.of(context).colorScheme.onSurface,
                ),
                child: const Text("True"),
              ),
            ),
            AppTheme.sizedBoxMed,
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  // False is index 1
                  widget.onSetCorrect(1);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: !widget.isTrueSelected 
                    ? Theme.of(context).colorScheme.primary 
                    : Theme.of(context).colorScheme.surface,
                  foregroundColor: !widget.isTrueSelected 
                    ? Theme.of(context).colorScheme.onPrimary 
                    : Theme.of(context).colorScheme.onSurface,
                ),
                child: const Text("False"),
              ),
            ),
          ],
        ),
      ],
    );
  }
} 