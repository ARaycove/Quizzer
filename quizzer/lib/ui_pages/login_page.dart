import 'package:flutter/material.dart';
import 'package:quizzer/database/tables/user_profile_table.dart';
import 'package:quizzer/ui_pages/new_user_page.dart';
import 'package:quizzer/ui_pages/home_page.dart';
import 'package:quizzer/database/tables/login_attempts.dart';
import 'package:quizzer/backend/functions/user_auth.dart';
import 'package:quizzer/backend/session_manager.dart';

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

  // Function to handle login submission
Future<void> submitLogin() async {
  setState(() {_isLoading = true;});

  final result = await authenticateUser(_emailController.text.trim(),_passwordController.text);

  if (!mounted) return;

  setState(() {_isLoading = false;});

  bool shouldGoToHomePage = false;

  late String status;

  if (result['success']) {
    shouldGoToHomePage = true; 
    status=result['response'];
    final sessionManager = SessionManager();
    await sessionManager.initializeSession(_emailController.text.trim());
    }
  else {
    String errorMessage = result['error'] ?? 'Invalid email or password';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage),backgroundColor:Colors.red,),);
    status = errorMessage;
    }
  String? userId = await getUserIdByEmail(_emailController.text.trim());
  if (userId == null) {throw Exception("email address does not exist in table, but authenticated anyway");}
  addLoginAttemptRecord(userId: userId, email: _emailController.text.trim(), statusCode: status);
  if (shouldGoToHomePage == true) {Navigator.pushReplacement(context,MaterialPageRoute(builder: (context) => const HomePage()),);}
}

  // Function to navigate to new user signup page
  void newUserSignUp() {Navigator.push(context,MaterialPageRoute(builder: (context) => const NewUserPage()),);}

  @override
  void dispose() {_emailController.dispose();_passwordController.dispose();super.dispose();}

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