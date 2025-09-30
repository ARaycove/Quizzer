import 'package:quizzer/UI_systems/01_new_user_page/new_user_page_field_validation.dart';
import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/app_theme.dart';

import '../../backend_systems/logger/quizzer_logging.dart';

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
    final TextEditingController _confirmPasswordController =
    TextEditingController();
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
        Map<String, dynamic> results = await session.createNewUserAccount(
            email: email, username: username, password: password);

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
        // final elementHeight25px = elementHeight > 25.0 ? 25.0 : elementHeight;
        final elementHeight40px = elementHeight > 40.0 ? 40.0 : elementHeight * 2;

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
                            ),
                            AppTheme.sizedBoxMed,

                            SizedBox(
                                width: fieldWidth,
                                child: _buildTextField(
                                    label: 'Email Address',
                                    hint: 'Enter your email address',
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                ),
                            ),
                            AppTheme.sizedBoxMed,

                            SizedBox(
                                width: fieldWidth,
                                child: _buildTextField(
                                    label: 'Username',
                                    hint: 'Enter your desired username',
                                    controller: _usernameController,
                                    keyboardType: TextInputType.text,
                                    textInputAction: TextInputAction.next,
                                ),
                            ),
                            AppTheme.sizedBoxMed,

                            SizedBox(
                                width: fieldWidth,
                                child: _buildTextField(
                                    label: 'Password',
                                    hint: 'Create a password',
                                    controller: _passwordController,
                                    obscureText: true,
                                    textInputAction: TextInputAction.next,
                                ),
                            ),
                            AppTheme.sizedBoxMed,

                            // Confirm Password Field
                            SizedBox(
                                width: fieldWidth,
                                child: _buildTextField(
                                    label: 'Confirm Password',
                                    hint: 'Confirm your password',
                                    controller: _confirmPasswordController,
                                    obscureText: true,
                                    textInputAction: TextInputAction.done,
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
                                        height: elementHeight40px,
                                        child: ElevatedButton(
                                            onPressed: () {
                                                // if login screen is previous routes then just pop
                                                // else navigate to login screen
                                                if (Navigator.canPop(context)) {
                                                    QuizzerLogger.logMessage(
                                                        'Navigating back to previous screen',
                                                    );
                                                    Navigator.pop(context);
                                                    return;
                                                }

                                                // yes it will replace the current screen but if
                                                // user presses back again it will go to the login screen
                                                // instead of going back to the new user screen
                                                // Otherwise navigate to login screen
                                                Navigator.pushReplacementNamed(context, '/login');
                                            },
                                            child: const Text('Back'),
                                        ),
                                    ),

                                    AppTheme.sizedBoxMed,

                                    // Create Account Button
                                    SizedBox(
                                        width: buttonWidth / 1.1,
                                        height: elementHeight40px,
                                        child: ElevatedButton(
                                            onPressed: _handleSignUpButton,
                                            child: const Text(
                                                'Create Account',
                                                textAlign: TextAlign.center,
                                            ),
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

    Widget _buildTextField({
        required String label,
        required String hint,
        required TextEditingController controller,
        bool obscureText = false,
        TextInputType? keyboardType,
        TextInputAction? textInputAction,
    }) {
        return TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            decoration: InputDecoration(
                labelText: label,
                hintText: hint,
            ),
        );
    }
}
