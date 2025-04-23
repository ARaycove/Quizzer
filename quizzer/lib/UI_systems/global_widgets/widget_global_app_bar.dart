import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showHomeButton;
  final List<Widget>? additionalActions;
  final SessionManager session = SessionManager();

  GlobalAppBar({
    super.key,
    required this.title,
    this.showHomeButton = true,
    this.additionalActions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: ColorWheel.titleText,
      ),
      backgroundColor: ColorWheel.secondaryBackground,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: ColorWheel.primaryText),
        tooltip: 'Back',
        onPressed: () {
          final previousPage = session.getPreviousPage();
          session.addPageToHistory(previousPage);
          Navigator.of(context).pushReplacementNamed(previousPage);
        },
      ),
      actions: [
        if (showHomeButton)
          IconButton(
            icon: const Icon(Icons.home, color: ColorWheel.primaryText),
            tooltip: 'Home',
            onPressed: () {
              session.addPageToHistory('/home');
              Navigator.of(context).pushReplacementNamed('/home');
            },
          ),
        if (additionalActions != null) ...additionalActions!,
      ],
    );
  }
} 