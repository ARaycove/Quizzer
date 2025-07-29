import 'package:flutter/material.dart';
import 'package:quizzer/app_theme.dart';
import 'package:quizzer/UI_systems/08_settings_page/individual_setting_widgets/stat_display_settings.dart';

class WidgetUserSettings extends StatelessWidget {
  const WidgetUserSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // H1 header for User Settings
        Text(
          'User Settings',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        AppTheme.sizedBoxLrg,
        const StatDisplaySettings(),
      ],
    );
  }
}
