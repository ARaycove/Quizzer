import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_global_app_bar.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:quizzer/UI_systems/color_wheel.dart';
/*
Menu Page Description:
The menu serves as the central navigation hub for Quizzer, providing access to various behavioral task interfaces and settings.
It contains buttons that redirect to:
- Add Question Interface: For entering complete question-answer pairs
- Add Content Interface: For manual entry of content
- Help with Research options: Access to various behavioral tasks
- Settings and other pages
- Logout functionality

The menu is purely a navigation element with no direct functionality beyond page redirection.
*/



// TODO: Implement proper error handling for all navigation actions
// TODO: Add proper validation for all user inputs

// ==========================================
// Widgets
class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}
// ------------------------------------------
class _MenuPageState extends State<MenuPage> {
  final SessionManager session = SessionManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorWheel.primaryBackground,
      appBar: GlobalAppBar(
        title: 'Quizzer Menu',
        showHomeButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ColorWheel.standardPaddingValue),
        child: Column(
          children: [
            // Add Question Button
            _buildMenuButton(
              icon: Icons.add_circle_outline,
              label: 'Add Question',
              onPressed: () {
                session.addPageToHistory('/add_question');
                Navigator.pushNamed(context, '/add_question');
              },
            ),
            const SizedBox(height: ColorWheel.standardPaddingValue),

            // Add Content Button
            _buildMenuButton(
              icon: Icons.content_paste,
              label: 'Add Content',
              onPressed: () {
                QuizzerLogger.logMessage('Add Content button pressed');
                developer.log('Add Content page not implemented yet');
              },
            ),
            const SizedBox(height: ColorWheel.standardPaddingValue),

            // Display Modules Button
            _buildMenuButton(
              icon: Icons.view_module,
              label: 'Display Modules',
              onPressed: () {
                session.addPageToHistory('/display_modules');
                Navigator.pushNamed(context, '/display_modules');
              },
            ),
            const SizedBox(height: ColorWheel.standardPaddingValue),

            // My Profile Button
            _buildMenuButton(
              icon: Icons.person,
              label: 'My Profile',
              onPressed: () {
                QuizzerLogger.logMessage('My Profile button pressed');
                developer.log('My Profile page not implemented yet');
              },
            ),
            const SizedBox(height: ColorWheel.standardPaddingValue),

            // Settings Button
            _buildMenuButton(
              icon: Icons.settings,
              label: 'Settings',
              onPressed: () {
                QuizzerLogger.logMessage('Settings button pressed');
                developer.log('Settings page not implemented yet');
              },
            ),
            const SizedBox(height: ColorWheel.standardPaddingValue),

            // Stats Button
            _buildMenuButton(
              icon: Icons.bar_chart,
              label: 'Stats',
              onPressed: () {
                QuizzerLogger.logMessage('Stats button pressed');
                developer.log('Stats page not implemented yet');
              },
            ),
            const SizedBox(height: ColorWheel.standardPaddingValue),

            // Feedback & Bug Reports Button
            _buildMenuButton(
              icon: Icons.bug_report,
              label: 'Feedback & Bug Reports',
              onPressed: () {
                QuizzerLogger.logMessage('Feedback & Bug Reports button pressed');
                developer.log('Feedback & Bug Reports page not implemented yet');
              },
            ),
            const SizedBox(height: ColorWheel.standardPaddingValue),

            // Help with Research Button
            _buildMenuButton(
              icon: Icons.science,
              label: 'Help with Research',
              onPressed: () {
                QuizzerLogger.logMessage('Help with Research button pressed');
                developer.log('Help with Research page not implemented yet');
              },
            ),
            const SizedBox(height: ColorWheel.standardPaddingValue),

            // Logout Button
            _buildMenuButton(
              icon: Icons.logout,
              label: 'Logout',
              isLogoutButton: true,
              onPressed: () async {
                final navigator = Navigator.of(context);
                session.clearSessionState();
                QuizzerLogger.logMessage('Session state reset for logout');
                if (mounted) {
                  session.addPageToHistory('/login');
                  navigator.pushReplacementNamed('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isLogoutButton = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: ColorWheel.primaryText),
        label: Text(label, style: ColorWheel.buttonText),
        style: ElevatedButton.styleFrom(
          backgroundColor: isLogoutButton ? ColorWheel.buttonError : ColorWheel.buttonSuccess,
          padding: const EdgeInsets.symmetric(vertical: ColorWheel.standardPaddingValue),
          shape: RoundedRectangleBorder(
            borderRadius: ColorWheel.buttonBorderRadius,
          ),
        ),
      ),
    );
  }
}


