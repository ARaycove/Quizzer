import 'package:flutter/material.dart';
import 'package:quizzer/features/user_profile_management/database/user_profile_table.dart';
import 'package:quizzer/features/user_profile_management/functionality/user_auth.dart' as auth;
import 'package:quizzer/global/functionality/quizzer_logging.dart';

// TODO: Fix the following issues:
// 1. If user is already registered, but not present in the local database, a record should be created in the local database.
// 2. If user is not registered with supabase, but is present in the local database, the user should register with supabase but bypass the creation of a new local profile record.
// 3. If the user is not registered with supabase, and is not present in the local database, the system should register the user with supabase and create a new local profile record.
// 4. If the user is both registered with supabase and present in the local database, the user should get a message that the account already exists and that they are free to login.

// Functions
void goBackToLogin(BuildContext context) {
    QuizzerLogger.logMessage('Navigating back to login page');
    Navigator.pop(context);
}

// ------------------------------------------

String validateEmail(String email) {
    QuizzerLogger.logMessage('Validating email: $email');
    
    // Basic checks for user-friendly feedback
    if (email.isEmpty) {
        QuizzerLogger.logWarning('Email validation failed: Empty email');
        return 'Email cannot be empty';
    }

    if (!email.contains('@')) {
        QuizzerLogger.logWarning('Email validation failed: Missing @ symbol');
        return 'Email must contain @ symbol';
    }

    if (!email.contains('.')) {
        QuizzerLogger.logWarning('Email validation failed: Missing domain');
        return 'Email must contain a domain (e.g., example.com)';
    }

    // Final validation using official regex pattern
    const pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$';
    final regex = RegExp(pattern);
    if (!regex.hasMatch(email)) {
        QuizzerLogger.logWarning('Email validation failed: Invalid email format');
        return 'Please enter a valid email address';
    }

    QuizzerLogger.logSuccess('Email validation passed');
    return '';
}

// ------------------------------------------

String validateUsername(String username) {
    QuizzerLogger.logMessage('Validating username: $username');
    
    if (username.isEmpty) {
        QuizzerLogger.logWarning('Username validation failed: Empty username');
        return 'Username cannot be empty';
    }
    if (username.length < 3) {
        QuizzerLogger.logWarning('Username validation failed: Too short');
        return 'Username must be at least 3 characters long';
    }
    if (username.length > 25) {
        QuizzerLogger.logWarning('Username validation failed: Too long');
        return 'Username cannot exceed 25 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
        QuizzerLogger.logWarning('Username validation failed: Invalid characters');
        return 'Username can only contain letters, numbers, and underscores';
    }
    
    QuizzerLogger.logSuccess('Username validation passed');
    return '';
}

// ------------------------------------------

String validatePassword(String password, String confirmPassword) {
    QuizzerLogger.logMessage('Validating password');
    
    if (password.isEmpty) {
        QuizzerLogger.logWarning('Password validation failed: Empty password');
        return 'Password cannot be empty';
    }
    if (password.length < 8) {
        QuizzerLogger.logWarning('Password validation failed: Too short');
        return 'Password must be at least 8 characters long';
    }
    if (password != confirmPassword) {
        QuizzerLogger.logWarning('Password validation failed: Passwords do not match');
        return 'Passwords do not match';
    }
    // Updated regex pattern to allow multiple letters and numbers
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).+$').hasMatch(password)) {
        QuizzerLogger.logWarning('Password validation failed: Missing required characters');
        return 'Password must contain at least one letter and one number';
    }
    
    QuizzerLogger.logSuccess('Password validation passed');
    return '';
}

// ------------------------------------------

Future<bool> checkUserExistsInSupabase(String email) async {
    QuizzerLogger.logMessage('Checking if user exists in Supabase: $email');
    try {
        final response = await auth.supabase.auth.signInWithPassword(
            email: email,
            password: 'dummy_password', // We don't need the actual password for this check
        );
        final exists = response.user != null;
        QuizzerLogger.logMessage('User ${exists ? "exists" : "does not exist"} in Supabase');
        return exists;
    } catch (e) {
        QuizzerLogger.logError('Error checking Supabase user existence: $e');
        // If sign in fails, user doesn't exist
        return false;
    }
}

Future<bool> checkUserExistsLocally(String email) async {
    QuizzerLogger.logMessage('Checking if user exists locally: $email');
    final userId = await getUserIdByEmail(email);
    final exists = userId != null;
    QuizzerLogger.logMessage('User ${exists ? "exists" : "does not exist"} in local database');
    return exists;
}

// ------------------------------------------

Future<String> handleSupabaseAuth(
    String email,
    String username,
    String password,
) async {
    QuizzerLogger.logMessage('Handling Supabase authentication for user: $email');
    
    // Check if user exists in Supabase
    final supabaseUser = await checkUserExistsInSupabase(email);
    
    // Check if user exists in local database
    final localUser = await checkUserExistsLocally(email);

    if (supabaseUser && localUser) {
        QuizzerLogger.logWarning('User already exists in both Supabase and local database');
        return 'Account already exists. Please login instead.';
    }

    if (supabaseUser && !localUser) {
        QuizzerLogger.logMessage('Creating local profile for existing Supabase user');
        final success = await createNewUserProfile(email, username, password);
        if (!success) {
            QuizzerLogger.logError('Failed to create local profile for existing Supabase user');
            return 'Failed to create local profile';
        }
        QuizzerLogger.logSuccess('Created local profile for existing Supabase user');
        return '';
    }

    if (!supabaseUser && localUser) {
        QuizzerLogger.logMessage('Registering with Supabase for existing local user');
        final result = await auth.registerUserWithSupabase(email, password);
        if (!result['success']) {
            QuizzerLogger.logError('Failed to register with Supabase: ${result['error']}');
            return result['error'] ?? 'Failed to register with Supabase';
        }
        QuizzerLogger.logSuccess('Registered with Supabase for existing local user');
        return '';
    }

    // User doesn't exist in either place - register with both
    QuizzerLogger.logMessage('Registering new user with both Supabase and local database');
    final supabaseResult = await auth.registerUserWithSupabase(email, password);
    if (!supabaseResult['success']) {
        QuizzerLogger.logError('Failed to register with Supabase: ${supabaseResult['error']}');
        return supabaseResult['error'] ?? 'Failed to register with Supabase';
    }

    final localResult = await createNewUserProfile(email, username, password);
    if (!localResult) {
        QuizzerLogger.logError('Failed to create local profile for new user');
        return 'Failed to create local profile';
    }
    
    QuizzerLogger.logSuccess('Successfully registered new user with both Supabase and local database');
    return '';
}

// ------------------------------------------

Future<void> submitSignup(
    BuildContext context,
    String email,
    String username,
    String password,
    String confirmPassword,
) async {
    QuizzerLogger.logMessage('Starting signup process for user: $email');
    
    // Validate input fields
    // ------------------------------------------
    // Email validation
    final emailError = validateEmail(email);
    if (emailError.isNotEmpty) {
        if (!context.mounted) return;
        QuizzerLogger.logWarning('Email validation failed: $emailError');
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
        QuizzerLogger.logWarning('Username validation failed: $usernameError');
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
        QuizzerLogger.logWarning('Password validation failed: $passwordError');
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
        QuizzerLogger.logError('Authentication failed: $authResult');
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
    QuizzerLogger.logSuccess('Account created successfully for user: $email');
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