import 'package:flutter/material.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';
import 'package:quizzer/features/user_profile_management/functionality/new_user_page_field_validation.dart';
import 'package:quizzer/features/user_profile_management/functionality/new_user_isolates.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

// =======================================================================================================
// Widgets
class NewUserPage extends StatefulWidget {
    const NewUserPage({super.key});

    @override
    State<NewUserPage> createState() => _NewUserPageState();
}

class _NewUserPageState extends State<NewUserPage> {
    final TextEditingController _emailController = TextEditingController();
    final TextEditingController _usernameController = TextEditingController();
    final TextEditingController _passwordController = TextEditingController();
    final TextEditingController _confirmPasswordController = TextEditingController();

    @override
    void dispose() {
        _emailController.dispose();
        _usernameController.dispose();
        _passwordController.dispose();
        _confirmPasswordController.dispose();
        super.dispose();
    }

    Future<void> _handleSignUpButton() async {
        final email = _emailController.text;
        final username = _usernameController.text;
        final password = _passwordController.text;
        final confirmPassword = _confirmPasswordController.text;

        // Validate fields
        // Validate the Email
        final emailError = validateEmail(email);
        if (emailError.isNotEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(emailError), backgroundColor: Colors.red),
            );
            return;
        }

        final usernameError = validateUsername(username);
        if (usernameError.isNotEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(usernameError), backgroundColor: Colors.red),
            );
            return;
        }

        final passwordError = validatePassword(password, confirmPassword);
        if (passwordError.isNotEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(passwordError), backgroundColor: Colors.red),
            );
            return;
        }

        bool userAlreadyRegistered = false;
        // We either get an AuthException or AuthResponse
        // If AuthException it means the user already exists, otherwise we we're successful in registering. It's not a null response
        // statusCode 422 indicates the user already is registered
        // 
        try {
            await supabase.auth.signUp(
                email: email,
                password: password,
            );
            userAlreadyRegistered = false;
        } on AuthException catch (e) {
            QuizzerLogger.logError('AuthException during signup: $e');
            userAlreadyRegistered = true;
        }

        // Regardless of whether the user is registered with supabase we need to ensure they are stored locally
        final success = await handleSignupInIsolate({
            'email': email,
            'username': username,
            'password': password,
        });

        if (!success) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('User already exists or error occurred'),
                    backgroundColor: Color.fromARGB(255, 214, 71, 71),
                ),
            );
            return;
        }

        String message;
        Color backgroundColor;
        if (userAlreadyRegistered) {
            message = 'User already registered with Supabase, but local profile created successfully';
            backgroundColor = Colors.orange;
        } else {
            message = 'Account created successfully in both Supabase and local database';
            backgroundColor = Colors.green;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(message),
                backgroundColor: backgroundColor,
            ),
        );
        Navigator.pop(context);
    }

    // ================================================================================================
    // End of signup function
    @override
    Widget build(BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final logoWidth = screenWidth > 600 ? 460.0 : screenWidth * 0.85;
        final fieldWidth = logoWidth;
        final buttonWidth = logoWidth / 2;
        
        final elementHeight = MediaQuery.of(context).size.height * 0.04;
        final elementHeight25px = elementHeight > 25.0 ? 25.0 : elementHeight;
        
        return Scaffold(
            backgroundColor: const Color(0xFF0A1929),
            body: Center(
                child: SingleChildScrollView(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Image.asset(
                                'images/quizzer_assets/quizzer_logo.png',
                                width: logoWidth,
                            ),
                            const SizedBox(height: 20),
                            
                            SizedBox(
                                width: fieldWidth,
                                child: TextField(
                                    controller: _emailController,
                                    decoration: InputDecoration(
                                        labelText: 'Email Address',
                                        hintText: 'Enter your email address',
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
                            
                            SizedBox(
                                width: fieldWidth,
                                child: TextField(
                                    controller: _usernameController,
                                    decoration: InputDecoration(
                                        labelText: 'Username',
                                        hintText: 'Enter your desired username',
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
                            
                            SizedBox(
                                width: fieldWidth,
                                child: TextField(
                                    controller: _passwordController,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                        labelText: 'Password',
                                        hintText: 'Create a password',
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
                                        labelText: 'Confirm Password',
                                        hintText: 'Confirm your password',
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
                                            onPressed: () => Navigator.pop(context),
                                            style: ElevatedButton.styleFrom(
                                                minimumSize: Size(100, elementHeight25px),
                                            ),
                                            child: const Text('Back'),
                                        ),
                                    ),
                                    
                                    const SizedBox(width: 20),
                                    
                                    SizedBox(
                                        width: buttonWidth,
                                        height: elementHeight25px,
                                        child: ElevatedButton(
                                            onPressed: _handleSignUpButton,
                                            style: ElevatedButton.styleFrom(
                                                minimumSize: Size(100, elementHeight25px),
                                            ),
                                            child: const Text('Create Account'),
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