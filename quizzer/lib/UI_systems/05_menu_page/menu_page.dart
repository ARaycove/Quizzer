import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_global_app_bar.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:quizzer/app_theme.dart';
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
    // Get the user role dynamically
    final String userRole = session.userRole; 
    QuizzerLogger.logValue("Building MenuPage for user role: $userRole");

    return Scaffold(
      appBar: const GlobalAppBar(
        title: 'Quizzer Menu',
        showHomeButton: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            AppTheme.sizedBoxMed, // Spacer for app bar
            // --- Conditional Admin Panel Button (Moved to Top) ---
            if (userRole == 'admin' || userRole == 'contributor') ...[
              _buildMenuButton(
                icon: Icons.admin_panel_settings, // Suitable icon
                label: 'Admin Panel',
                onPressed: () {
                  QuizzerLogger.logMessage('Admin Panel button pressed by $userRole');
                  Navigator.pushNamed(context, '/admin_panel'); 
                },
              ),
              AppTheme.sizedBoxMed,
            ],
            // --- End Conditional Button ---

            // Add Question Button
            _buildMenuButton(
              icon: Icons.add_circle_outline,
              label: 'Add Question',
              onPressed: () {
                Navigator.pushNamed(context, '/add_question');
              },
            ),
            AppTheme.sizedBoxMed,

            // Display Modules Button
            _buildMenuButton(
              icon: Icons.view_module,
              label: 'Display Modules',
              onPressed: () {
                Navigator.pushNamed(context, '/display_modules');
              },
            ),
            AppTheme.sizedBoxMed,

            // My Profile Button
            _buildMenuButton(
              icon: Icons.person,
              label: 'My Profile',
              onPressed: () {
                QuizzerLogger.logMessage('My Profile button pressed');
                developer.log('My Profile page not implemented yet');
              },
            ),
            AppTheme.sizedBoxMed,

            // Settings Button
            _buildMenuButton(
              icon: Icons.settings,
              label: 'Settings',
              onPressed: () {
                QuizzerLogger.logMessage('Settings button pressed');
                Navigator.pushNamed(context, '/settings_page');
              },
            ),
            AppTheme.sizedBoxMed,

            // Stats Button
            _buildMenuButton(
              icon: Icons.bar_chart,
              label: 'Stats',
              onPressed: () {
                QuizzerLogger.logMessage('Stats button pressed');
                Navigator.pushNamed(context, '/stats');
              },
            ),
            AppTheme.sizedBoxMed,

            // Feedback & Bug Reports Button
            _buildMenuButton(
              icon: Icons.bug_report,
              label: 'Feedback & Bug Reports',
              onPressed: () {
                QuizzerLogger.logMessage('Feedback & Bug Reports button pressed');
                Navigator.pushNamed(context, '/feedback');
              },
            ),
            AppTheme.sizedBoxMed,

            // Logout Button
            _buildMenuButton(
              icon: Icons.logout,
              label: 'Logout',
              isLogoutButton: true,
              onPressed: () async {
                final navigator = Navigator.of(context);
                session.logoutUser();
                QuizzerLogger.logMessage('Session state reset for logout');
                if (mounted) { // Ensure the widget is still in the tree
                  // Clear navigation stack and go to login page
                  navigator.pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
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
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}


