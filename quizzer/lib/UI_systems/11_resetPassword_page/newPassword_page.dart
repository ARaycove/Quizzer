import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/app_theme.dart';
import 'dart:async'; // Import for StreamSubscription

class NewPasswordPage extends StatefulWidget {
  const NewPasswordPage({super.key});

  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  // Controllers for the text fields
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();

  bool _isLoading = false; // Add loading state variable

  @override
  void dispose() {
    _newPasswordController.dispose();
    super.dispose();
  }

  // Function to navigate to otp verify page
  void updatePassword() {
    // Prevent navigation if already loading
    if (_isLoading) return;
    QuizzerLogger.logMessage('Navigating to Login Screen');
    // remove all previous routes
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    // Calculate responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final logoWidth = screenWidth > 600 ? 460.0 : screenWidth * 0.85;
    final fieldWidth = logoWidth;
    final buttonWidth = logoWidth * 0.6;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Quizzer Logo
              Image.asset(
                "images/quizzer_assets/quizzer_logo.png",
                width: logoWidth,
              ),
              AppTheme.sizedBoxLrg,
              AppTheme.sizedBoxLrg,
              AppTheme.sizedBoxLrg,

              // New Password Field
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _newPasswordController,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                  decoration: const InputDecoration(
                    labelText: "New Password",
                    hintText: "Enter your new password",
                  ),
                ),
              ),
              AppTheme.sizedBoxMed,
              // Confirm New Password Field
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _confirmNewPasswordController,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                  decoration: const InputDecoration(
                    labelText: "Confirm New Password",
                    hintText: "Enter your new password again",
                  ),
                ),
              ),

              AppTheme.sizedBoxLrg,

              // Submit Button
              SizedBox(
                width: buttonWidth,
                // Expand to full width when loading
                child: ElevatedButton(
                  onPressed: _isLoading ? null : updatePassword,
                  child: const Text("Update Password"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
