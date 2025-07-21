import 'package:quizzer/UI_systems/01_new_user_page/new_user_page_field_validation.dart';
import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/app_theme.dart';
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
    SessionManager session = getSessionManager();

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
                SnackBar(content: Text(emailError)),
            );
            return;
        }

        final usernameError = validateUsername(username);
        if (usernameError.isNotEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(usernameError)),
            );
            return;
        }

        final passwordError = validatePassword(password, confirmPassword);
        if (passwordError.isNotEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(passwordError)),
            );
            return;
        }
        Map<String, dynamic> results = await session.createNewUserAccount(email: email, username: username, password: password);

        if (!results['success']) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(results['message']),
                ),
            );
            return;
        }
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
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
            body: Center(
                child: SingleChildScrollView(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Image.asset(
                                'images/quizzer_assets/quizzer_logo.png',
                                width: logoWidth,
                            ),
                            AppTheme.sizedBoxLrg,
                            
                            SizedBox(
                                width: fieldWidth,
                                child: TextField(
                                    controller: _emailController,
                                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                    decoration: const InputDecoration(
                                        labelText: 'Email Address',
                                        hintText: 'Enter your email address',
                                    ),
                                ),
                            ),
                            AppTheme.sizedBoxMed,
                            
                            SizedBox(
                                width: fieldWidth,
                                child: TextField(
                                    controller: _usernameController,
                                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                    decoration: const InputDecoration(
                                        labelText: 'Username',
                                        hintText: 'Enter your desired username',
                                    ),
                                ),
                            ),
                            AppTheme.sizedBoxMed,
                            
                            SizedBox(
                                width: fieldWidth,
                                child: TextField(
                                    controller: _passwordController,
                                    obscureText: true,
                                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                    decoration: const InputDecoration(
                                        labelText: 'Password',
                                        hintText: 'Create a password',
                                    ),
                                ),
                            ),
                            AppTheme.sizedBoxMed,
                            
                            // Confirm Password Field
                            SizedBox(
                                width: fieldWidth,
                                child: TextField(
                                    controller: _confirmPasswordController,
                                    obscureText: true,
                                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                    decoration: const InputDecoration(
                                        labelText: 'Confirm Password',
                                        hintText: 'Confirm your password',
                                    ),
                                ),
                            ),
                            AppTheme.sizedBoxLrg,
                            
                            // Button Row with Back and Submit buttons
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    // Back Button
                                    SizedBox(
                                        width: buttonWidth / 1.1,
                                        height: elementHeight25px,
                                        child: ElevatedButton(
                                            onPressed: () {
                                              Navigator.pushReplacementNamed(context, '/login');
                                            },
                                            child: const Text('Back'),
                                        ),
                                    ),
                                    
                                    AppTheme.sizedBoxMed,
                                    
                                    // Create Account Button
                                    SizedBox(
                                        width: buttonWidth / 1.1,
                                        height: elementHeight25px,
                                        child: ElevatedButton(
                                            onPressed: _handleSignUpButton,
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