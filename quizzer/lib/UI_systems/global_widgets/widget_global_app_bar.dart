import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

// Colors
const Color _surfaceColor = Color(0xFF1E2A3A); // Secondary Background
const Color _textColor = Colors.white; // Primary Text

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
        style: const TextStyle(color: _textColor),
      ),
      backgroundColor: _surfaceColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: _textColor),
        onPressed: () {
          final previousPage = session.getPreviousPage();
          session.addPageToHistory(previousPage);
          Navigator.of(context).pushReplacementNamed(previousPage);

        },
      ),
      actions: [
        if (showHomeButton)
          IconButton(
            icon: const Icon(Icons.home, color: _textColor),
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