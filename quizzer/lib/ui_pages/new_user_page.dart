import 'package:flutter/material.dart';
import 'package:quizzer/database/tables/user_profile_table.dart';

// TODO: Fix the following issues:
// 1. If user is already registered, but not present in the local database, a record should be created in the local database.
// 2. If user is not registered with supabase, but is present in the local database, the user should register with supabase but bypass the creation of a new local profile record.
// 3. If the user is not registered with supabase, and is not present in the local database, the system should register the user with supabase and create a new local profile record.
// 4. If the user is both registered with supabase and present in the local database, the user should get a message that the account already exists and that they are free to login.

// Functions
void goBackToLogin(BuildContext context) {
    Navigator.pop(context);
}

// ------------------------------------------

String validateEmail(String email) {
    // Basic checks for user-friendly feedback
    if (email.isEmpty) {
        return 'Email cannot be empty';
    }

    if (!email.contains('@')) {
        return 'Email must contain @ symbol';
    }

    if (!email.contains('.')) {
        return 'Email must contain a domain (e.g., example.com)';
    }

    // Final validation using official regex pattern
    const pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$';
    final regex = RegExp(pattern);
    if (!regex.hasMatch(email)) {
        return 'Please enter a valid email address';
    }

    return '';
}

// ------------------------------------------

String validateUsername(String username) {
    if (username.isEmpty) {
        return 'Username cannot be empty';
    }
    if (username.length < 3) {
        return 'Username must be at least 3 characters long';
    }
    if (username.length > 25) {
        return 'Username cannot exceed 25 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
        return 'Username can only contain letters, numbers, and underscores';
    }
    return '';
}

// ------------------------------------------

String validatePassword(String password, String confirmPassword) {
    if (password.isEmpty) {
        return 'Password cannot be empty';
    }
    if (password.length < 6) {
        return 'Password must be at least 8 characters long';
    }
    if (password != confirmPassword) {
        return 'Passwords do not match';
    }
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$').hasMatch(password)) {
        return 'Password must contain at least one letter and one number';
    }
    return '';
}

// ------------------------------------------

Future<bool> checkUserExistsInSupabase(String email) async {
    try {
        final response = await supabase.auth.signInWithPassword(
            email: email,
            password: 'dummy_password', // We don't need the actual password for this check
        );
        return response.user != null;
    } catch (e) {
        // If sign in fails, user doesn't exist
        return false;
    }
}

Future<bool> checkUserExistsLocally(String email) async {
    final userId = await getUserIdByEmail(email);
    return userId != null;
}

// ------------------------------------------

Future<String> handleSupabaseAuth(
    String email,
    String username,
    String password,
) async {
    // Check if user exists in Supabase
    final supabaseUser = await checkUserExistsInSupabase(email);
    
    // Check if user exists in local database
    final localUser = await checkUserExistsLocally(email);

    if (supabaseUser && localUser) {
        return 'Account already exists. Please login instead.';
    }

    if (supabaseUser && !localUser) {
        // Create local profile for existing Supabase user
        final success = await createNewUserProfile(email, username, password);
        return success ? '' : 'Failed to create local profile';
    }

    if (!supabaseUser && localUser) {
        // Register with Supabase but skip local profile creation
        final result = await registerUserWithSupabase(email, password);
        return result['success'] ? '' : (result['error'] ?? 'Failed to register with Supabase');
    }

    // User doesn't exist in either place - register with both
    final supabaseResult = await registerUserWithSupabase(email, password);
    if (!supabaseResult['success']) {
        return supabaseResult['error'] ?? 'Failed to register with Supabase';
    }

    final localResult = await createNewUserProfile(email, username, password);
    return localResult ? '' : 'Failed to create local profile';
}

// ------------------------------------------

Future<void> submitSignup(
    BuildContext context,
    String email,
    String username,
    String password,
    String confirmPassword,
) async {
    // Validate input fields
    // ------------------------------------------
    // Email validation
    final emailError = validateEmail(email);
    if (emailError.isNotEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(emailError),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
            ),
        );
        return;
    }
    // ------------------------------------------
    // Username validation
    final usernameError = validateUsername(username);
    if (usernameError.isNotEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(usernameError),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
            ),
        );
        return;
    }
    // ------------------------------------------
    // Password validation
    final passwordError = validatePassword(password, confirmPassword);
    if (passwordError.isNotEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(passwordError),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
            ),
        );
        return;
    }
    // ------------------------------------------
    // Handle Supabase authentication
    final authResult = await handleSupabaseAuth(email, username, password);
    if (authResult.isNotEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(authResult),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
            ),
        );
        return;
    }
    // ------------------------------------------
    // Show success message
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
        ),
    );
    // ------------------------------------------
    // Navigate back to login page after successful account creation
    if (!context.mounted) return;
    Navigator.pop(context);
}

// ==========================================

// Widgets
class NewUserPage extends StatefulWidget {
    const NewUserPage({super.key});

    @override
    State<NewUserPage> createState() => _NewUserPageState();
}

// ------------------------------------------

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
                                'images/quizzer_assets/quizzer_logo.png',
                                width: logoWidth,
                            ),
                            const SizedBox(height: 20),
                            
                            // Email Field
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
                            
                            // Username Field
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
                            
                            // Password Field
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
                                            onPressed: () => goBackToLogin(context),
                                            style: ElevatedButton.styleFrom(
                                                minimumSize: Size(100, elementHeight25px),
                                            ),
                                            child: const Text('Back'),
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
                                                _confirmPasswordController.text,
                                            ),
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