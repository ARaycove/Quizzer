import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

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
            backgroundColor: ColorWheel.buttonSuccess,
            padding: const EdgeInsets.symmetric(
              horizontal: ColorWheel.standardPaddingValue * 2,
              vertical: ColorWheel.standardPaddingValue,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: ColorWheel.buttonBorderRadius,
            ),
          ),
          child: const Text(
            'Submit',
            style: ColorWheel.buttonTextBold,
          ),
        ),
        const SizedBox(width: ColorWheel.standardPaddingValue),
        ElevatedButton(
          onPressed: onClear,
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorWheel.buttonError,
            padding: const EdgeInsets.symmetric(
              horizontal: ColorWheel.standardPaddingValue * 2,
              vertical: ColorWheel.standardPaddingValue,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: ColorWheel.buttonBorderRadius,
            ),
          ),
          child: const Text(
            'Clear All',
            style: ColorWheel.buttonTextBold,
          ),
        ),
      ],
    );
  }
} 