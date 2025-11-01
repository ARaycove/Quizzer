// reset_password_page.dart
import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/app_theme.dart';
import 'package:supabase/supabase.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final SessionManager session = getSessionManager();

  late SupabaseClient supabase;

  final TextEditingController _emailController =
      TextEditingController(text: 'hamzasmayo@gmail.com');
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  bool _isLoading = false;
  int _step = 0; // 0: enter email, 1: enter otp, 2: new password
  String _statusMessage = '';
  Timer? _resendTimer;
  int _resendSecondsLeft = 0;
  static const _resendCooldown = 60; // seconds

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() {
      _resendSecondsLeft = _resendCooldown;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _resendSecondsLeft--;
        if (_resendSecondsLeft <= 0) {
          _resendTimer?.cancel();
        }
      });
    });
  }

  Future<void> _sendOtp() async {
    supabase = SessionManager().supabase;

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Sending OTP...';
    });

    try {
      QuizzerLogger.logMessage(
          'Attempting Supabase password recovery with email: $email');
      await supabase.auth.resetPasswordForEmail(email);
      QuizzerLogger.logMessage('OTP Sent...');

      // Move to OTP input step
      if (mounted) {
        setState(() {
          _step = 1;
          _statusMessage = 'Enter the OTP sent to your email';
        });
      }

      _startResendCooldown();
    } on AuthException catch (e) {
      QuizzerLogger.logError(
          'Supabase AuthException during password reset: ${e.message}');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      QuizzerLogger.logError('Error sending OTP: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    supabase = SessionManager().supabase;

    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enter the OTP sent to your email')));
      return;
    }
    setState(() {
      _isLoading = true;
      _statusMessage = 'Verifying OTP...';
    });

    try {
      // final res = await supabase.auth.verifyOTP(
      //   email: email,
      //   token: otp,
      //   type: OtpType.recovery,
      // );
      // if (res.user != null) {
      //   QuizzerLogger.logSuccess('OTP verified for $email');
      //   setState(() {
      //     _step = 2; // Move to new password step
      //     _statusMessage = '';
      //   });
      // } else {
      //   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to verify OTP')));
      // }
    } catch (e) {
      QuizzerLogger.logError('Error verifying OTP: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitNewPassword() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final newPass = _newPassController.text;
    final confirm = _confirmPassController.text;

    if (newPass.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill both password fields')));
      return;
    }
    if (newPass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password should be at least 6 characters')));
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Updating password...';
    });

    try {
      QuizzerLogger.logMessage(
          'Attempting Supabase password reset with email: $email');
      final response = await supabase.auth.updateUser(
        UserAttributes(
          password: newPass,
        ),
      );

      QuizzerLogger.logMessage(
          'Supabase password reset response received: ${response.user != null ? 'User updated' : 'No user returned'}');
    } catch (e) {
      QuizzerLogger.logError('Error changing password: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_resendSecondsLeft > 0) return;
    await _sendOtp();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width > 600
        ? 520.0
        : MediaQuery.of(context).size.width * 0.9;
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: width,
            child: Column(
              children: [
                if (_step == 0) ...[
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText:
                            'Enter the email associated with your account'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  AppTheme.sizedBoxMed,
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendOtp,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator())
                          : const Text('Send OTP'),
                    ),
                  ),
                ],
                if (_step >= 1) ...[
                  TextField(
                    controller: _otpController,
                    decoration: const InputDecoration(
                        labelText: 'OTP',
                        hintText: 'Enter the OTP you received'),
                    keyboardType: TextInputType.number,
                  ),
                  AppTheme.sizedBoxMed,
                  Row(
                    children: [
                      Expanded(
                          child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                supabase = SupabaseClient(
                                  'https://yruvxuvzztnahuuiqxit.supabase.co',
                                  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlydXZ4dXZ6enRuYWh1dWlxeGl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQzMTY1NDIsImV4cCI6MjA1OTg5MjU0Mn0.hF1oAILlmzCvsJxFk9Bpjqjs3OEisVdoYVZoZMtTLpo',
                                  authOptions: const AuthClientOptions(
                                    authFlowType: AuthFlowType.implicit,
                                  ),
                                );
                                final otp = _otpController.text.trim();
                                if (otp.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Please enter the OTP sent to your email')));
                                  return;
                                }
                                setState(() {
                                  _isLoading = true;
                                  // _statusMessage = 'Verifying OTP...';
                                });

                                try {
                                  final res = await supabase.auth.verifyOTP(
                                    email: _emailController.text.trim(),
                                    token: otp,
                                    type: OtpType.recovery,
                                  );

                                  log('OTP Verification Response: $res');

                                  if (res.user != null) {
                                    QuizzerLogger.logSuccess(
                                        'OTP verified for ${_emailController.text.trim()}');
                                    setState(() {
                                      _step = 2; // Move to new password step
                                      _statusMessage = '';
                                    });
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('Failed to verify OTP')));
                                  }
                                } catch (e) {
                                  QuizzerLogger.logError(
                                      'Error verifying OTP: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Unexpected error: $e')));
                                } finally {
                                  if (mounted)
                                    setState(() => _isLoading = false);
                                }
                                // _verifyOtp();
                              },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedOpacity(
                              opacity: _isLoading ? 0 : 1,
                              duration: const Duration(milliseconds: 200),
                              child: const Text('Verify OTP'),
                            ),
                            if (_isLoading)
                              const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator()),
                          ],
                        ),
                      )),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: (_resendSecondsLeft > 0 || _isLoading)
                            ? null
                            : _resendOtp,
                        child: Text(_resendSecondsLeft > 0
                            ? 'Resend ($_resendSecondsLeft)'
                            : 'Resend'),
                      )
                    ],
                  )
                ],
                if (_step == 2) ...[
                  TextField(
                    controller: _newPassController,
                    decoration:
                        const InputDecoration(labelText: 'New Password'),
                    obscureText: true,
                  ),
                  AppTheme.sizedBoxMed,
                  TextField(
                    controller: _confirmPassController,
                    decoration:
                        const InputDecoration(labelText: 'Confirm Password'),
                    obscureText: true,
                  ),
                  AppTheme.sizedBoxMed,
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitNewPassword,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator())
                          : const Text('Change Password'),
                    ),
                  ),
                ],
                if (_statusMessage.isNotEmpty) ...[
                  AppTheme.sizedBoxMed,
                  Text(_statusMessage),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// // reset_password_page.dart
// import 'package:flutter/material.dart';
// import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
// import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
// import 'package:quizzer/app_theme.dart';
//
// class ResetPasswordPage extends StatefulWidget {
//   const ResetPasswordPage({super.key});
//
//   @override
//   State<ResetPasswordPage> createState() => _ResetPasswordPageState();
// }
//
// class _ResetPasswordPageState extends State<ResetPasswordPage> {
//   final SessionManager session = getSessionManager();
//   final TextEditingController _emailController = TextEditingController();
//
//   bool _isLoading = false;
//
//   @override
//   void dispose() {
//     _emailController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _sendOTP() async {
//     if (_isLoading) return;
//     final email = _emailController.text.trim();
//     if (email.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your email')));
//       return;
//     }
//
//     setState(() {
//       _isLoading = true;
//     });
//
//     try {
//       final res = await session.requestPasswordReset(email);
//       if (res['success'] == true) {
//         QuizzerLogger.logMessage('OTP sent to $email');
//         // Navigate and pass email to VerifyOtpPage
//         Navigator.pushNamed(context, '/verifyOtp', arguments: {'email': email});
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Failed to send OTP')));
//       }
//     } catch (e) {
//       QuizzerLogger.logError('Error sending OTP: $e');
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final logoWidth = screenWidth > 600 ? 460.0 : screenWidth * 0.85;
//     final fieldWidth = logoWidth;
//     final buttonWidth = logoWidth * 0.6;
//
//     return Scaffold(
//       appBar: AppBar(title: const Text('Reset Password')),
//       body: Center(
//         child: SingleChildScrollView(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Image.asset("images/quizzer_assets/quizzer_logo.png", width: logoWidth),
//               AppTheme.sizedBoxLrg,
//               SizedBox(
//                 width: fieldWidth,
//                 child: TextField(
//                   controller: _emailController,
//                   keyboardType: TextInputType.emailAddress,
//                   style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
//                   decoration: const InputDecoration(
//                     labelText: "Email Address",
//                     hintText: "Enter the email associated with your account",
//                   ),
//                 ),
//               ),
//               AppTheme.sizedBoxLrg,
//               SizedBox(
//                 width: buttonWidth,
//                 child: ElevatedButton(
//                   onPressed: _isLoading ? null : _sendOTP,
//                   child: _isLoading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator()) : const Text("Send OTP to Email"),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
