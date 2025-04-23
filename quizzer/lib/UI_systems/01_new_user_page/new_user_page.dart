import 'package:quizzer/UI_systems/01_new_user_page/new_user_page_field_validation.dart';
import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
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
                SnackBar(content: Text(emailError), backgroundColor: ColorWheel.buttonError),
            );
            return;
        }

        final usernameError = validateUsername(username);
        if (usernameError.isNotEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(usernameError), backgroundColor: ColorWheel.buttonError),
            );
            return;
        }

        final passwordError = validatePassword(password, confirmPassword);
        if (passwordError.isNotEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(passwordError), backgroundColor: ColorWheel.buttonError),
            );
            return;
        }
        Map<String, dynamic> results = await session.createNewUserAccount(email: email, username: username, password: password);

        if (!results['success']) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(results['message']),
                    backgroundColor: ColorWheel.buttonError,
                ),
            );
            return;
        }
        if (!mounted) return;
        session.addPageToHistory('/login');
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
            backgroundColor: ColorWheel.primaryBackground,
            body: Center(
                child: SingleChildScrollView(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Image.asset(
                                'images/quizzer_assets/quizzer_logo.png',
                                width: logoWidth,
                            ),
                            const SizedBox(height: ColorWheel.majorSectionSpacing),
                            
                            SizedBox(
                                width: fieldWidth,
                                child: TextField(
                                    controller: _emailController,
                                    decoration: InputDecoration(
                                        labelText: 'Email Address',
                                        hintText: 'Enter your email address',
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
                            
                            SizedBox(
                                width: fieldWidth,
                                child: TextField(
                                    controller: _usernameController,
                                    decoration: InputDecoration(
                                        labelText: 'Username',
                                        hintText: 'Enter your desired username',
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
                            
                            SizedBox(
                                width: fieldWidth,
                                child: TextField(
                                    controller: _passwordController,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                        labelText: 'Password',
                                        hintText: 'Create a password',
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
                            
                            // Confirm Password Field
                            SizedBox(
                                width: fieldWidth,
                                child: TextField(
                                    controller: _confirmPasswordController,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                        labelText: 'Confirm Password',
                                        hintText: 'Confirm your password',
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
                                              session.addPageToHistory('/login');
                                              Navigator.pushReplacementNamed(context, '/login');
                                            },
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: ColorWheel.buttonSecondary,
                                                minimumSize: Size(100, elementHeight25px),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius: ColorWheel.buttonBorderRadius,
                                                ),
                                            ),
                                            child: const Text('Back', style: ColorWheel.buttonText),
                                        ),
                                    ),
                                    
                                    const SizedBox(width: ColorWheel.buttonHorizontalSpacing),
                                    
                                    // Create Account Button
                                    SizedBox(
                                        width: buttonWidth / 1.1,
                                        height: elementHeight25px,
                                        child: ElevatedButton(
                                            onPressed: _handleSignUpButton,
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: ColorWheel.buttonSuccess,
                                                minimumSize: Size(100, elementHeight25px),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius: ColorWheel.buttonBorderRadius,
                                                ),
                                            ),
                                            child: const Text('Create Account', style: ColorWheel.buttonTextBold),
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