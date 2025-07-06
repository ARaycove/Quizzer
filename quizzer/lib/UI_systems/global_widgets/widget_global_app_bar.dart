import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showHomeButton;
  final List<Widget>? additionalActions;

  const GlobalAppBar({
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
          Navigator.of(context).pop();
        },
      ),
      actions: [
        if (showHomeButton)
          IconButton(
            icon: const Icon(Icons.home, color: ColorWheel.primaryText),
            tooltip: 'Home',
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/home');
            },
          ),
        if (additionalActions != null) ...additionalActions!,
      ],
    );
  }
} 