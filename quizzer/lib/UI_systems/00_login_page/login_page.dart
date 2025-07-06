import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
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
  SessionManager session = getSessionManager();
  bool _isLoading = false; // Add loading state variable
  String _loginProgressMessage = "Login"; // To hold progress messages
  StreamSubscription? _progressSubscription; // To manage the stream subscription

  @override
  void initState() {
    super.initState();
    _progressSubscription = session.loginProgressStream.listen((message) {
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
      _loginProgressMessage = "Connecting..."; // Initial message when button pressed
    });

    // define the email and password submission
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Attempt to log in using credentials
    QuizzerLogger.logMessage('Login attempt for: $email');
    
    Map<String, dynamic> results = await session.attemptLogin(email, password);
    
    if (results['success']) {
      // Login successful, keep loading state true until navigation completes
      QuizzerLogger.logMessage('Login successful for: $email. Navigating home.');
      if (!mounted) return;
      // _loginProgressMessage will be updated by the stream, culminating in "Login Complete!"
      // Potentially, could set a final success message here if desired before navigation
      // setState(() { _loginProgressMessage = "Success!"; }); 
      Navigator.pushReplacementNamed(context, '/home');
      // Don't reset loading state here, it disappears on navigation
    } else {
      // Display error message from login attempt
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(results['message'] ?? 'Login failed'),
          backgroundColor: ColorWheel.buttonError,
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
    if (mounted && _isLoading) { // Check mounted and isLoading before setting state
      setState(() {
          _isLoading = false;
          _loginProgressMessage = "Login"; // Reset button text
      });
    }
  }

  // Function to navigate to new user signup page
  void newUserSignUp() {
    // Prevent navigation if already loading
    if (_isLoading) return; 
    QuizzerLogger.logMessage('Navigating to new user page');
    Navigator.pushNamed(context, '/signup');
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
    final screenWidth       = MediaQuery.of(context).size.width;
    final logoWidth         = screenWidth > 600 ? 460.0 : screenWidth * 0.85;
    final fieldWidth        = logoWidth;
    final buttonWidth       = logoWidth / 2;
    // Define uniform height for UI elements (max 25px, scaled to screen)
    final elementHeight     = MediaQuery.of(context).size.height * 0.04;
    final elementHeight25px = elementHeight > 25.0 ? 25.0 : elementHeight;
    
    return Scaffold(
      backgroundColor: ColorWheel.primaryBackground,
      body: Center(child: SingleChildScrollView(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Quizzer Logo
              Image.asset(
                "images/quizzer_assets/quizzer_logo.png",
                width: logoWidth,
              ),
              const SizedBox(height: ColorWheel.majorSectionSpacing),
              
              // Email Field
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: "Email Address",
                    hintText: "Enter your email address to login",
                    contentPadding: ColorWheel.inputFieldPadding,
                    filled: true,
                    fillColor: ColorWheel.textInputBackground,
                    labelStyle: ColorWheel.inputLabelText,
                    hintStyle: ColorWheel.hintTextStyle,
                    border: OutlineInputBorder(
                      borderRadius: ColorWheel.textFieldBorderRadius,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: ColorWheel.relatedElementSpacing),
              
              // Password Field
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: "Password",
                    hintText: "Enter your account password to login",
                    contentPadding: ColorWheel.inputFieldPadding,
                    filled: true,
                    fillColor: ColorWheel.textInputBackground,
                    labelStyle: ColorWheel.inputLabelText,
                    hintStyle: ColorWheel.hintTextStyle,
                    border: OutlineInputBorder(
                      borderRadius: ColorWheel.textFieldBorderRadius,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: ColorWheel.majorSectionSpacing),
              
              // Submit Button
              SizedBox(
                width: _isLoading ? fieldWidth : buttonWidth,
                height: elementHeight25px,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : submitLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorWheel.buttonSuccess,
                    minimumSize: Size(100, elementHeight25px),
                    shape: RoundedRectangleBorder(
                      borderRadius: ColorWheel.buttonBorderRadius,
                    ),
                    disabledBackgroundColor: ColorWheel.buttonSecondary,
                  ),
                  child: _isLoading 
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: ColorWheel.primaryText,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _loginProgressMessage, 
                                style: ColorWheel.buttonTextBold,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            )
                          ],
                        ) 
                      : const Text(
                          "Login", // Or _loginProgressMessage if you want it to persist last known state
                          style: ColorWheel.buttonTextBold,
                        ),
                ),
              ),
              
              // Space for Social Login buttons
              const SizedBox(height: ColorWheel.majorSectionSpacing + 10),
              
              // Social Login Grid
              SizedBox(
                width: fieldWidth,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: ColorWheel.relatedElementSpacing,
                  runSpacing: ColorWheel.relatedElementSpacing,
                  children: [
                    // These would be replaced with actual social login buttons
                    _buildSocialLoginButton(Icons.g_mobiledata, "Google"),
                    _buildSocialLoginButton(Icons.facebook, "Facebook"),
                    _buildSocialLoginButton(Icons.code, "GitHub"),
                    _buildSocialLoginButton(Icons.code_outlined, "GitLab"),
                  ],
                ),
              ),
              
              const SizedBox(height: ColorWheel.majorSectionSpacing + 10),
              
              // New User Sign Up Button
              SizedBox(
                width: buttonWidth,
                height: elementHeight25px,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : newUserSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorWheel.buttonSuccess,
                    minimumSize: Size(100, elementHeight25px),
                    shape: RoundedRectangleBorder(
                      borderRadius: ColorWheel.buttonBorderRadius,
                    ),
                  ),
                  child: const Text(
                    "New User",
                    style: ColorWheel.buttonTextBold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Helper method to build social login buttons
  // TODO Finish Social login integration, BAAS
  Widget _buildSocialLoginButton(IconData icon, String service) {
    return Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        color: ColorWheel.secondaryBackground,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: ColorWheel.buttonSuccess,
          width: 1,
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 20, color: ColorWheel.primaryText),
        onPressed: () {
          // This would later call the appropriate social login function
          QuizzerLogger.logWarning('Social login ($service) not implemented yet.');
        },
      ),
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