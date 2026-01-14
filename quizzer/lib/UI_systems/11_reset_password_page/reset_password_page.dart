import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/02_login_authentication/user_auth.dart';
import 'package:supabase/supabase.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  // Use SessionManager to get the initialized client
  final SupabaseClient supabase = SessionManager().supabase;
  final UserAuth _userAuth = UserAuth();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  bool _isLoading = false;
  int _step = 0; // 0: enter phone, 1: enter otp, 2: new password

  Timer? _resendTimer;
  int _resendSecondsLeft = 0;
  static const _resendCooldown = 60; // seconds

  @override
  void dispose() {
    _phoneController.dispose();
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

  // Step 1: Send SMS
  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _userAuth.signInWithPhone(phone, supabase);

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        QuizzerLogger.logMessage('OTP Sent to $phone');
        setState(() => _step = 1);
        _startResendCooldown();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Error sending OTP')),
        );
      }
    }
  }

  // Step 2: Verify OTP
  Future<void> _verifyOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _userAuth.verifyPhoneOtp(phone, otp, supabase);

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        setState(() => _step = 2);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Invalid OTP')),
        );
      }
    }
  }

  // Step 3: Update Password
  Future<void> _submitNewPassword() async {
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

    setState(() => _isLoading = true);

    try {
      QuizzerLogger.logMessage('Attempting password update...');
      // User should be logged in via verifyOtp by now
      final response = await supabase.auth.updateUser(
        UserAttributes(password: newPass),
      );

      if (response.user != null) {
        QuizzerLogger.logSuccess('Password updated successfully');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password updated successfully!')),
          );
          Navigator.of(context).pop(); // Go back to login
        }
      }
    } on AuthException catch (e) {
      QuizzerLogger.logError('Error changing password: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    } catch (e) {
      QuizzerLogger.logError('Unexpected error changing password: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Basic Layout similar to previous
    final width = MediaQuery.of(context).size.width > 600
        ? 520.0
        : MediaQuery.of(context).size.width * 0.9;

    return Scaffold(
      appBar: AppBar(title: const Text('Recover Password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_step == 0) _buildPhoneInput(),
                if (_step == 1) _buildOtpInput(),
                if (_step == 2) _buildPasswordInput(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Column(
      children: [
        const Text('Enter your phone number to receive a verification code.',
            style: TextStyle(fontSize: 16)),
        const SizedBox(height: 20),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            hintText: '+15551234567',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendOtp,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Send Code'),
          ),
        )
      ],
    );
  }

  Widget _buildOtpInput() {
    return Column(
      children: [
        Text('Enter the 6-digit code sent to ${_phoneController.text}',
            style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 20),
        TextField(
          controller: _otpController,
          decoration: const InputDecoration(
            labelText: 'OTP Code',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock_clock),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Verify'),
          ),
        ),
        TextButton(
          onPressed: (_resendSecondsLeft > 0 || _isLoading) ? null : _sendOtp,
          child: Text(_resendSecondsLeft > 0
              ? 'Resend in $_resendSecondsLeft s'
              : 'Resend Code'),
        )
      ],
    );
  }

  Widget _buildPasswordInput() {
    return Column(
      children: [
        const Text('Create a new password.', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 20),
        TextField(
          controller: _newPassController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New Password',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPassController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Confirm Password',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitNewPassword,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Update Password'),
          ),
        ),
      ],
    );
  }
}
