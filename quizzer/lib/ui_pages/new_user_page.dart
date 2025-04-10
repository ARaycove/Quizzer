import 'package:flutter/material.dart';
import 'package:quizzer/database/tables/user_profile_table.dart';

// Function to handle back button - return to login page
void goBackToLogin(BuildContext context) {
  Navigator.pop(context);
}

// Function to handle signup submission
void submitSignup(BuildContext context, String email, String username, String password, String confirmPassword) {
  // Validate input fields
  String errorMessage = '';
  
  if (email.isEmpty) {
    errorMessage = 'Email cannot be empty';
  } else if (!email.contains('@')) {
    errorMessage = 'Please enter a valid email address';
  } else if (username.isEmpty) {
    errorMessage = 'Username cannot be empty';
  } else if (password.isEmpty) {
    errorMessage = 'Password cannot be empty';
  } else if (password != confirmPassword) {
    errorMessage = 'Passwords do not match';
  } 
  
  if (errorMessage.isNotEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );return;} 
  else {createNewUserProfile(email, username, password);}
  
  // Show success message
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Account created successfully!'),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 3),
    ),
  );
  
  // Navigate back to login page after successful account creation
  Navigator.pop(context);
}

class NewUserPage extends StatefulWidget {
  const NewUserPage({super.key});

  @override
  State<NewUserPage> createState() => _NewUserPageState();
}

class _NewUserPageState extends State<NewUserPage> {
  // Controllers for the text fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    // Clean up controllers when the widget is disposed
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final logoWidth = screenWidth > 600 ? 460.0 : screenWidth * 0.85;
    final fieldWidth = logoWidth;
    final buttonWidth = logoWidth / 2;
    
    // Define uniform height for UI elements (max 25px, scaled to screen)
    final elementHeight = MediaQuery.of(context).size.height * 0.04;
    final elementHeight25px = elementHeight > 25.0 ? 25.0 : elementHeight;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
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
              const SizedBox(height: 20),
              
              // Email Field
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "Email Address",
                    hintText: "Enter your email address",
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
              
              // Username Field
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: "Username",
                    hintText: "Enter your desired username",
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
                    hintText: "Create a password",
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
              
              // Confirm Password Field
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    hintText: "Confirm your password",
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
              
              // Button Row with Back and Submit buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Back Button
                  SizedBox(
                    width: buttonWidth,
                    height: elementHeight25px,
                    child: ElevatedButton(
                      onPressed: () => goBackToLogin(context),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(100, elementHeight25px),
                      ),
                      child: const Text("Back"),
                    ),
                  ),
                  
                  const SizedBox(width: 20), // Space between buttons
                  
                  // Submit Button
                  SizedBox(
                    width: buttonWidth,
                    height: elementHeight25px,
                    child: ElevatedButton(
                      onPressed: () => submitSignup(
                        context,
                        _emailController.text,
                        _usernameController.text,
                        _passwordController.text,
                        _confirmPasswordController.text
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(100, elementHeight25px),
                      ),
                      child: const Text("Create Account"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}