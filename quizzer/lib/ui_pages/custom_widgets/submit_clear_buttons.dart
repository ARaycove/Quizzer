import 'package:flutter/material.dart';

// Colors
const Color _primaryColor = Color(0xFF4CAF50);
const Color _errorColor = Color(0xFFD64747);
const Color _textColor = Colors.white;
const double _borderRadius = 12.0;
const double _spacing = 16.0;

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
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            padding: const EdgeInsets.symmetric(
              horizontal: _spacing * 2,
              vertical: _spacing,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_borderRadius),
            ),
          ),
          child: const Text(
            'Submit',
            style: TextStyle(
              color: _textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: _spacing),
        ElevatedButton(
          onPressed: onClear,
          style: ElevatedButton.styleFrom(
            backgroundColor: _errorColor,
            padding: const EdgeInsets.symmetric(
              horizontal: _spacing * 2,
              vertical: _spacing,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_borderRadius),
            ),
          ),
          child: const Text(
            'Clear All',
            style: TextStyle(
              color: _textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
} 