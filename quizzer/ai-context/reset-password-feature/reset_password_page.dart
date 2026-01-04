import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
// import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:supabase/supabase.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {

  late SupabaseClient supabase;

  final TextEditingController _emailController =
      TextEditingController(text: 'enter your email');
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
    // final email = _emailController.text.trim();
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

    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enter the OTP sent to your email')));
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
            const SnackBar(content: Text('Failed to verify OTP')));
      }
    } catch (e) {
      QuizzerLogger.logError('Error verifying OTP: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitNewPassword() async {
    final email = _emailController.text.trim();
    // final otp = _otpController.text.trim();
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
        'Supabase password reset response received: ${response.user != null ? 'User updated' : 'No user returned'}',
      );
      Navigator.of(context).pop();
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_step == 0) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText:
                            'Enter the email associated with your account',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendOtp,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send OTP'),
                    ),
                  ),
                ],
                if (_step >= 1) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: TextField(
                      controller: _otpController,
                      decoration: const InputDecoration(
                        labelText: 'OTP',
                        hintText: 'Enter the OTP you received',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _verifyOtp,
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
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: (_resendSecondsLeft > 0 || _isLoading)
                            ? null
                            : _resendOtp,
                        child: Text(
                          _resendSecondsLeft > 0
                              ? 'Resend ($_resendSecondsLeft)'
                              : 'Resend',
                        ),
                      ),
                    ],
                  ),
                ],
                if (_step == 2) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20, top: 16),
                    child: TextField(
                      controller: _newPassController,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      obscureText: true,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: TextField(
                      controller: _confirmPassController,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      obscureText: true,
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitNewPassword,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Change Password'),
                    ),
                  ),
                ],
                if (_statusMessage.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
