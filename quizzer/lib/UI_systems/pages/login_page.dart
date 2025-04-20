import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

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

  Future<void> submitLogin() async {
    // define the email and password submission
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    // Basic validation
    if (email.isEmpty && password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both email and password'),
          backgroundColor: Color.fromARGB(255, 214, 71, 71),
        ),
      );
      return;
    }

    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address'),
          backgroundColor: Color.fromARGB(255, 214, 71, 71),
        ),
      );
      return;
    }

    // Attempt to log in using credentials
    QuizzerLogger.logMessage('Login attempt for: $email');
    

    Map<String, dynamic> results = await session.attemptLogin(email, password);
    
    if (results['success']) {
      // Route to home page
      if (!mounted) return;session.addPageToHistory('/home');Navigator.pushReplacementNamed(context, '/home');} 
    else {
      // Display error message from login attempt
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(results['message'] ?? 'Login failed'),
          backgroundColor: const Color.fromARGB(255, 214, 71, 71),
        ),
      );
      return;
    }


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
                  onPressed: submitLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 71, 214, 93),
                    minimumSize: Size(100, elementHeight25px),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  child: const Text(
                    "Login",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                    backgroundColor: const Color.fromARGB(255, 71, 214, 93),
                    minimumSize: Size(100, elementHeight25px),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  child: const Text(
                    "New User",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
  Widget _buildSocialLoginButton(IconData icon, String service) {
    return Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3A),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: const Color.fromARGB(255, 71, 214, 93),
          width: 1,
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 20, color: Colors.white),
        onPressed: () {
          // This would later call the appropriate social login function
          print("Social login with $service");
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