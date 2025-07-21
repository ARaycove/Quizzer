import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_global_app_bar.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/08_settings_page/widget_admin_settings.dart';
import 'package:quizzer/UI_systems/08_settings_page/widget_user_settings.dart';
import 'package:quizzer/app_theme.dart';

class SettingsPage extends StatelessWidget {
  SettingsPage({super.key});

  final SessionManager _sessionManager = getSessionManager();

  @override
  Widget build(BuildContext context) {
    final String userRole = _sessionManager.userRole;
    final bool isAdminOrContributor = userRole == 'admin' || userRole == 'contributor';

    return Scaffold(
      appBar: const GlobalAppBar(
        title: 'Settings',
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (isAdminOrContributor) ...[
              const WidgetAdminSettings(),
              AppTheme.sizedBoxLrg,
            ],
            const WidgetUserSettings(),
          ],
        ),
      ),
    );
  }
}
