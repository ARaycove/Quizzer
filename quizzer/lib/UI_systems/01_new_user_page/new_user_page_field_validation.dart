import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

String validateEmail(String email) {
    QuizzerLogger.logMessage('Validating email: $email');

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

    const pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$';
    final regex = RegExp(pattern);
    if (!regex.hasMatch(email)) {
        QuizzerLogger.logWarning('Email validation failed: Invalid email format');
        return 'Please enter a valid email address';
    }

    QuizzerLogger.logSuccess('Email validation passed');
    return '';
}

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
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).+$').hasMatch(password)) {
        QuizzerLogger.logWarning('Password validation failed: Missing required characters');
        return 'Password must contain at least one letter and one number';
    }

    QuizzerLogger.logSuccess('Password validation passed');
    return '';
}