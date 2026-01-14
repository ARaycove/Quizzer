import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/app_theme.dart';
import 'dart:async'; // Import for StreamSubscription

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers for the text fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false; // Add loading state variable
  String _loginProgressMessage = "Login"; // To hold progress messages
  StreamSubscription?
      _progressSubscription; // To manage the stream subscription

  @override
  void initState() {
    super.initState();
    _progressSubscription =
        SessionManager().loginProgressStream.listen((message) {
      if (mounted) {
        setState(() {
          _loginProgressMessage = message;
          // If the message is "Login Complete!" or an error state,
          // we might want to stop showing it as button text after a delay
          // or once navigation happens. For now, it just updates.
        });
      }
    }, onError: (error) {
      // Handle any errors from the stream if necessary
      if (mounted) {
        setState(() {
          _loginProgressMessage = "Error during login";
          _isLoading = false; // Stop loading on stream error
        });
      }
      QuizzerLogger.logError("Error on loginProgressStream: $error");
    });
  }

  Future<void> submitLogin() async {
    // Set loading state to true
    setState(() {
      _isLoading = true;
      _loginProgressMessage =
          "Connecting..."; // Initial message when button pressed
    });

    // define the email and password submission
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Attempt to log in using credentials
    QuizzerLogger.logMessage('Login attempt for: $email');

    Map<String, dynamic> results = await SessionManager().attemptLogin(
        email: email, password: password, authType: "email_login");

    if (results['success']) {
      // Login successful, keep loading state true until navigation completes
      QuizzerLogger.logMessage(
          'Login successful for: $email. Navigating home.');
      if (!mounted) return;
      // _loginProgressMessage will be updated by the stream, culminating in "Login Complete!"
      // Potentially, could set a final success message here if desired before navigation
      // setState(() { _loginProgressMessage = "Success!"; });
      setState(() {
        _loginProgressMessage = "Success!";
      });
      Navigator.pushReplacementNamed(context, '/home');
      // Don't reset loading state here, it disappears on navigation
    } else {
      // Display error message from login attempt
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(results['message'] ?? 'Login failed'),
        ),
      );
      // Reset loading state on login failure
      setState(() {
        _isLoading = false;
        _loginProgressMessage = "Login"; // Reset button text
      });
      return;
    }
    // It's good practice to reset loading state if something unexpected happens,
    // though ideally the code paths above cover all scenarios.
    // If the function somehow reaches here without navigating or erroring out,
    // reset the loading state.
    if (mounted && _isLoading) {
      // Check mounted and isLoading before setting state
      setState(() {
        _isLoading = false;
        _loginProgressMessage = "Login"; // Reset button text
      });
    }
  }

  // Future<void> submitSocialLogin() async {
  //   // FIXME FIX GOOGLE LOGIN
  //   // // Attempt to log in using credentials
  //   // QuizzerLogger.logMessage('Social Login attempt.');

  //   // Map<String, dynamic> results = await SessionManager().attemptLogin(authType: "google_login");

  //   // if (results['success']) {
  //   //   // Login successful, keep loading state true until navigation completes
  //   //   QuizzerLogger.logMessage(
  //   //       'Login successful for: $email. Navigating home.');
  //   //   if (!mounted) return;
  //   //   // _loginProgressMessage will be updated by the stream, culminating in "Login Complete!"
  //   //   // Potentially, could set a final success message here if desired before navigation
  //   //   // setState(() { _loginProgressMessage = "Success!"; });
  //   //   Navigator.pushReplacementNamed(context, '/home');
  //   //   // Don't reset loading state here, it disappears on navigation
  //   // } else {
  //   //   // Display error message from login attempt
  //   //   if (!mounted) return;
  //   //   ScaffoldMessenger.of(context).showSnackBar(
  //   //     SnackBar(
  //   //       content: Text(results['message'] ?? 'Login failed'),
  //   //     ),
  //   //   );
  //   //   // Reset loading state on login failure
  //   //   setState(() {
  //   //     _isLoading = false;
  //   //     _loginProgressMessage = "Login"; // Reset button text
  //   //   });
  //   //   return;
  //   }
  //   // It's good practice to reset loading state if something unexpected happens,
  //   // though ideally the code paths above cover all scenarios.
  //   // If the function somehow reaches here without navigating or erroring out,
  //   // reset the loading state.
  //   // if (mounted && _isLoading) {
  //   //   // Check mounted and isLoading before setting state
  //   //   setState(() {
  //   //     _isLoading = false;
  //   //     _loginProgressMessage = "Login"; // Reset button text
  //   //   });
  //   // }
  // }

  // Function to navigate to new user signup page
  void newUserSignUp() {
    // Prevent navigation if already loading
    if (_isLoading) return;
    QuizzerLogger.logMessage('Navigating to new user page');
    Navigator.pushNamed(context, '/signup');
  }

  // Navigate to reset password and handle return (true => password reset succeeded)
  void resetPassword() async {
    if (_isLoading) return;
    QuizzerLogger.logMessage('Navigating to reset password page');
    final result = await Navigator.pushNamed(context, '/resetPassword');
    if (result is bool && result == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Password changed successfully — please log in with your new password')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _progressSubscription?.cancel(); // Cancel the stream subscription
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final logoWidth = screenWidth > 600 ? 460.0 : screenWidth * 0.85;
    final fieldWidth = logoWidth;
    final buttonWidth = logoWidth / 2;

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

              // Email Field
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 16.0),
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                  decoration: const InputDecoration(
                    hintText: "Email Address",
                  ),
                ),
              ),
              AppTheme.sizedBoxMed,

              // Password Field
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  enabled: !_isLoading,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 16.0),
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                  decoration: const InputDecoration(
                    hintText: "Password",
                  ),
                ),
              ),
              AppTheme.sizedBoxMed,
              // Reset Password Button
              SizedBox(
                width: buttonWidth,
                child: TextButton(
                  onPressed: _isLoading ? null : resetPassword,
                  child: const Text(
                    "Reset Password",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
              AppTheme.sizedBoxLrg,

              // Submit Button
              SizedBox(
                width: _isLoading
                    ? fieldWidth
                    : buttonWidth, // Expand to full width when loading
                width: _isLoading ? fieldWidth : buttonWidth,
                // Expand to full width when loading
                child: ElevatedButton(
                  onPressed: _isLoading ? null : submitLogin,
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            AppTheme.sizedBoxMed,
                            Expanded(
                              child: Text(
                                _loginProgressMessage,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            )
                          ],
                        )
                      : const Text("Login"),
                ),
              ),

              // Space for Social Login buttons
              AppTheme.sizedBoxLrg,

              // Social Login Grid
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  // These would be replaced with actual social login buttons
                  _buildSocialLoginButton(Icons.g_mobiledata, "Google"),
                  _buildSocialLoginButton(Icons.facebook, "Facebook"),
                  _buildSocialLoginButton(Icons.code, "GitHub"),
                  _buildSocialLoginButton(Icons.code_outlined, "GitLab"),
                ],
              ),

              AppTheme.sizedBoxLrg,

              // New User Sign Up Button
              ElevatedButton(
                onPressed: _isLoading ? null : newUserSignUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.chartOrange,
                ),
                child: const Text("New User"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build social login buttons
  Widget _buildSocialLoginButton(IconData icon, String service) {
    return IconButton(
      icon: Icon(icon),
      onPressed: () {
        // This would later call the appropriate social login function
        QuizzerLogger.logWarning(
            'Social login ($service) not implemented yet.');
        QuizzerLogger.logMessage("Disabled social login for now");
        // _isLoading ? null : submitSocialLogin();
      },
    );
  }
}

// TODO this looks fine put should be placed in the login_isolates.dart file under functionality/ in the user_profile_management feature

/*
{access_token: eyJhbGciOiJIUzI1NiIsImtpZCI6IkR1UEdZT3Z6eFhxbklFT3AiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL3lydXZ4dXZ6enRuYWh1dWlxeGl0LnN1cGFiYXNlLmNvL2F1dGgvdjEiLCJzdWIiOiJkNDI1MDY5MC05ZjJiLTQ3NzAtYjgxMy1iMTI0MjFlNWFhZTYiLCJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoxNzQ0OTg5NjIwLCJpYXQiOjE3NDQ5ODYwMjAsImVtYWlsIjoiYWFjcmEwODIwQGdtYWlsLmNvbSIsInBob25lIjoiIiwiYXBwX21ldGFkYXRhIjp7InByb3ZpZGVyIjoiZW1haWwiLCJwcm92aWRlcnMiOlsiZW1haWwiXX0sInVzZXJfbWV0YWRhdGEiOnsiZW1haWwiOiJhYWNyYTA4MjBAZ21haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsInBob25lX3ZlcmlmaWVkIjpmYWxzZSwic3ViIjoiZDQyNTA2OTAtOWYyYi00NzcwLWI4MTMtYjEyNDIxZTVhYWU2In0sInJvbGUiOiJhdXRoZW50aWNhdGVkIiwiYWFsIjoiYWFsMSIsImFtciI6W3sibWV0aG9kIjoicGFzc3dvcmQiLCJ0aW1lc3RhbXAiOjE3NDQ5ODYwMjB9XSwic2Vzc2lvbl9pZCI6IjNkYzNlMzM3LTFiNDUtNDA3YS04NTNhLWY2ZjQ5N2M1N2NkMCIsImlzX2Fub255bW91cyI6ZmFsc2V9.7BYGZ0RFV7aVQnSUJYPk3SRSTU8oc7Mk76YJqol3My8,
expires_in: 3600,
expires_at: 1744989620,
refresh_token: 7XJ4tMyfYLETgXpSrlT7-w,
token_type: bearer,
provider_token: null,
provider_refresh_token: null,
user: {id: d4250690-9f2b-4770-b813-b12421e5aae6, app_metadata: {provider: email, providers: [email]}, user_metadata: {email: aacra0820@gmail.com, email_verified: true, phone_verified: false, sub: d4250690-9f2b-4770-b813-b12421e5aae6},

aud: authenticated,
confirmation_sent_at: 2025-04-10T20:53:23.546196Z,
recovery_sent_at: 2025-04-11T03:54:57.716707Z,
email_change_sent_at: null,
new_email: null,
invited_at: null,
action_link: null,
email: aacra0820@gmail.com,
phone: ,
created_at: 2025-04-10T20:53:23.501392Z,
confirmed_at: 2025-04-11T03:48:21.571134Z,
email_confirmed_at: 2025-04-11T03:48:21.571134Z,
phone_confirmed_at: null,
last_sign_in_at: 2025-04-18T14:20:20.367791489Z,
role: authenticated,
updated_at: 2025-04-18T14:20:20.376848Z,
identities: [{id: d4250690-9f2b-4770-b813-b12421e5aae6, user_id: d4250690-9f2b-4770-b813-b12421e5aae6, identity_data: {email: aacra0820@gmail.com, email_verified: false, phone_verified: false, sub: d4250690-9f2b-4770-b813-b12421e5aae6}, identity_id: 089495ed-1d2a-4b4d-9b85-f85012ae355e, provider: email, created_at: 2025-04-10T20:53:23.525002Z, last_sign_in_at: 2025-04-10T20:53:23.524929Z, updated_at: 2025-04-10T20:53:23.525002Z}],
factors: null, is_anonymous: false}}
*/
