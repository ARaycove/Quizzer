import 'package:flutter/material.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';
import 'package:quizzer/features/user_profile_management/pages/new_user_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:isolate';
import 'package:quizzer/features/user_profile_management/functionality/login_isolates.dart';
import 'package:flutter/services.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers for the text fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> submitLogin() async {
    setState(() {_isLoading = true;});
    // define the email and password submission
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    // Attempt to log in using credentials
    QuizzerLogger.logMessage('Login attempt for: $email');
    
    dynamic response;
    try {
      response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      response = e;
      QuizzerLogger.logError('AuthException: ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {_isLoading = false;});
      }
    }

    // Log the response regardless of outcome
    QuizzerLogger.logMessage('Supabase response: ${response.toString()}');
    if (response is AuthResponse) {
      QuizzerLogger.logMessage('User data: ${response.user?.toJson()}');
      QuizzerLogger.logMessage('Session data: ${response.session?.toJson()}');
    }

    // Log login attempt in isolate
    final receivePort = ReceivePort();
    Isolate.spawn(
      handleLoginAttempt,
      {
        'sendPort': receivePort.sendPort,
        'email': email,
        'timestamp': DateTime.now().toIso8601String(),
        'response': response,
        'rootToken': RootIsolateToken.instance!,
      },
    );

    // Route to home page
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  // Function to navigate to new user signup page
  void newUserSignUp() {
    QuizzerLogger.logMessage('Navigating to new user page');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewUserPage()),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
      backgroundColor: const Color(0xFF0A1929),
      body: Center(child: SingleChildScrollView(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Quizzer Logo
              Image.asset(
                "images/quizzer_assets/quizzer_logo.png",
                width: logoWidth,
              ),
              const SizedBox(height: 20),
              
              // Email Field
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "Email Address",
                    hintText: "Enter your email address to login",
                    contentPadding: const EdgeInsets.all(12),
                    filled: true,
                    fillColor: const Color.fromARGB(255, 145, 236, 247),
                    labelStyle: const TextStyle(color: Colors.black87),
                    hintStyle: const TextStyle(color: Colors.black54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              
              // Password Field
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password",
                    hintText: "Enter your account password to login",
                    contentPadding: const EdgeInsets.all(12),
                    filled: true,
                    fillColor: const Color.fromARGB(255, 145, 236, 247),
                    labelStyle: const TextStyle(color: Colors.black87),
                    hintStyle: const TextStyle(color: Colors.black54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Submit Button
              SizedBox(
                width: buttonWidth,
                height: elementHeight25px,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : submitLogin,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(100, elementHeight25px),
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Login"),
                ),
              ),
              
              // Space for Social Login buttons
              const SizedBox(height: 30),
              
              // Social Login Grid
              SizedBox(
                width: fieldWidth,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    // These would be replaced with actual social login buttons
                    _buildSocialLoginButton(Icons.g_mobiledata, "Google"),
                    _buildSocialLoginButton(Icons.facebook, "Facebook"),
                    _buildSocialLoginButton(Icons.code, "GitHub"),
                    _buildSocialLoginButton(Icons.code_outlined, "GitLab"),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // New User Sign Up Button
              SizedBox(
                width: buttonWidth,
                height: elementHeight25px,
                child: ElevatedButton(
                  onPressed: newUserSignUp,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(100, elementHeight25px),
                  ),
                  child: const Text("New User"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Helper method to build social login buttons
  Widget _buildSocialLoginButton(IconData icon, String service) {
    return Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 20),
        onPressed: () {
          // This would later call the appropriate social login function
          print("Social login with $service");
        },
      ),
    );
  }
}

// TODO this looks fine put should be placed in the login_isolates.dart file under functionality/ in the user_profile_management feature