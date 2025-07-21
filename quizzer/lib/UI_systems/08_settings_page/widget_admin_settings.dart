import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/08_settings_page/individual_setting_widgets/gemini_api_key.dart';
import 'package:quizzer/app_theme.dart';

class WidgetAdminSettings extends StatelessWidget {
  const WidgetAdminSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Admin Settings'),
        AppTheme.sizedBoxLrg,
        Column(
          children: <Widget>[
            GeminiApiKeySetting(),
            // Add other admin settings here in the future
          ],
        ),
      ],
    );
  }
}
