import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/app_theme.dart';
import 'dart:async'; // Import for StreamSubscription

class VerifyOtpPage extends StatefulWidget {
  const VerifyOtpPage({super.key});

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  // Controllers for the text fields
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false; // Add loading state variable

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Function to navigate to
  void verifyOtp() {
    // Prevent navigation if already loading
    if (_isLoading) return;
    QuizzerLogger.logMessage('Navigating to OTP Verification Page');
    Navigator.pushNamed(context, '/newPassword');
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

              // OTP Field
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.number,
                  onTapUpOutside: (_) {
                    FocusScope.of(context).unfocus();
                  },
                  enabled: !_isLoading,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                  decoration: const InputDecoration(
                    labelText: "OTP Code",
                    hintText: "Enter the OTP sent to your email",
                  ),
                ),
              ),
              AppTheme.sizedBoxLrg,

              // Submit Button
              SizedBox(
                width: _isLoading ? fieldWidth : buttonWidth,
                // Expand to full width when loading
                child: ElevatedButton(
                  onPressed: _isLoading ? null : verifyOtp,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text("Verify OTP"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
