import 'package:flutter/material.dart';
import 'package:quizzer/app_theme.dart';

class WidgetUserSettings extends StatelessWidget {
  const WidgetUserSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('User Settings'),
        AppTheme.sizedBoxLrg,
        Center(
          child: Text('User settings will be available here in a future update.'),
        ),
      ],
    );
  }
}
