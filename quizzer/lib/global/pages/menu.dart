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

import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:quizzer/global/functionality/session_manager.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';

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
  final SessionManager _sessionManager = SessionManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1929),
        title: const Text('Quizzer Menu', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            QuizzerLogger.logMessage('Back button pressed in menu');
            final previousPage = _sessionManager.getPreviousPage();
            if (previousPage != null) {
              Navigator.pushReplacementNamed(context, previousPage);
              QuizzerLogger.logMessage('Navigated back to $previousPage');
            } else {
              Navigator.pop(context);
              QuizzerLogger.logMessage('No previous page in history, using default back navigation');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () {
              QuizzerLogger.logMessage('Home button pressed in menu');
              Navigator.pushReplacementNamed(context, '/home');
              QuizzerLogger.logMessage('Navigated to home page');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Add Question Button
            _buildMenuButton(
              icon: Icons.add_circle_outline,
              label: 'Add Question',
              onPressed: () {
                QuizzerLogger.logMessage('Add Question button pressed');
                Navigator.pushNamed(context, '/add_question');
                QuizzerLogger.logMessage('Navigated to Add Question page');
              },
            ),
            const SizedBox(height: 16),

            // Add Content Button
            _buildMenuButton(
              icon: Icons.content_paste,
              label: 'Add Content',
              onPressed: () {
                QuizzerLogger.logMessage('Add Content button pressed');
                developer.log('Add Content page not implemented yet');
              },
            ),
            const SizedBox(height: 16),

            // Display Modules Button
            _buildMenuButton(
              icon: Icons.view_module,
              label: 'Display Modules',
              onPressed: () {
                QuizzerLogger.logMessage('Display Modules button pressed');
                developer.log('Display Modules page not implemented yet');
              },
            ),
            const SizedBox(height: 16),

            // My Profile Button
            _buildMenuButton(
              icon: Icons.person,
              label: 'My Profile',
              onPressed: () {
                QuizzerLogger.logMessage('My Profile button pressed');
                developer.log('My Profile page not implemented yet');
              },
            ),
            const SizedBox(height: 16),

            // Settings Button
            _buildMenuButton(
              icon: Icons.settings,
              label: 'Settings',
              onPressed: () {
                QuizzerLogger.logMessage('Settings button pressed');
                developer.log('Settings page not implemented yet');
              },
            ),
            const SizedBox(height: 16),

            // Stats Button
            _buildMenuButton(
              icon: Icons.bar_chart,
              label: 'Stats',
              onPressed: () {
                QuizzerLogger.logMessage('Stats button pressed');
                developer.log('Stats page not implemented yet');
              },
            ),
            const SizedBox(height: 16),

            // Feedback & Bug Reports Button
            _buildMenuButton(
              icon: Icons.bug_report,
              label: 'Feedback & Bug Reports',
              onPressed: () {
                QuizzerLogger.logMessage('Feedback & Bug Reports button pressed');
                developer.log('Feedback & Bug Reports page not implemented yet');
              },
            ),
            const SizedBox(height: 16),

            // Help with Research Button
            _buildMenuButton(
              icon: Icons.science,
              label: 'Help with Research',
              onPressed: () {
                QuizzerLogger.logMessage('Help with Research button pressed');
                developer.log('Help with Research page not implemented yet');
              },
            ),
            const SizedBox(height: 16),

            // Logout Button
            _buildMenuButton(
              icon: Icons.logout,
              label: 'Logout',
              onPressed: () async {
                QuizzerLogger.logMessage('Logout button pressed');
                final navigator = Navigator.of(context);
                // Only reset session state, don't clear stored credentials
                _sessionManager.userId = null;
                _sessionManager.email = null;
                _sessionManager.currentQuestionId = null;
                _sessionManager.resetQuestionState();
                _sessionManager.sessionStartTime = null;
                QuizzerLogger.logMessage('Session state reset for logout');
                if (mounted) {
                  navigator.pushReplacementNamed('/login');
                  QuizzerLogger.logMessage('Navigated to login page');
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
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 71, 214, 93),
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
    );
  }
}


