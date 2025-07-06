import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:quizzer/UI_systems/08_settings_page/individual_setting_widgets/gemini_api_key.dart';

class WidgetAdminSettings extends StatelessWidget {
  const WidgetAdminSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Admin Settings',
          style: ColorWheel.titleText.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: ColorWheel.secondaryBackground,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: const Column(
            children: <Widget>[
              GeminiApiKeySetting(),
              // Add other admin settings here in the future
            ],
          ),
        ),
      ],
    );
  }
}
