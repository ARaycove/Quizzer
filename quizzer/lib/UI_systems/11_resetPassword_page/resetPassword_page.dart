import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/app_theme.dart';
import 'dart:async'; // Import for StreamSubscription

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  // Controllers for the text fields
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false; // Add loading state variable

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Function to navigate to otp verify page
  void sendOTP() {
    // Prevent navigation if already loading
    if (_isLoading) return;
    QuizzerLogger.logMessage('Navigating to OTP Verification Page');
    Navigator.pushNamed(context, '/verifyOtp');
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

              // Email Field
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _emailController,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                  decoration: const InputDecoration(
                    labelText: "Email Address",
                    hintText: "Enter your email address to login",
                  ),
                ),
              ),
              AppTheme.sizedBoxLrg,

              // Submit Button
              SizedBox(
                width: buttonWidth,
                // Expand to full width when loading
                child: ElevatedButton(
                  onPressed: _isLoading ? null : sendOTP,
                  child: const Text("Send OTP to Email"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
