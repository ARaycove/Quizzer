import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

class WidgetUserSettings extends StatelessWidget {
  const WidgetUserSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'User Settings',
          style: ColorWheel.titleText.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: ColorWheel.secondaryBackground,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: const Center(
            child: Text(
              'User settings will be available here in a future update.',
              style: ColorWheel.defaultText,
            ),
          ),
        ),
      ],
    );
  }
}
