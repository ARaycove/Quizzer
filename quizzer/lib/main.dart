import 'dart:async'; // For runZonedGuarded
import 'package:flutter/foundation.dart'; // For PlatformDispatcher
import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/03_add_question_page/add_question_answer_page.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/display_modules_page.dart';
import 'package:quizzer/UI_systems/01_new_user_page/new_user_page.dart';
import 'package:quizzer/UI_systems/00_login_page/login_page.dart';
import 'package:quizzer/UI_systems/02_home_page/home_page.dart';
import 'package:quizzer/UI_systems/05_menu_page/menu_page.dart';
import 'package:quizzer/UI_systems/06_admin_panel/admin_panel.dart';
import 'package:quizzer/UI_systems/08_settings_page/settings_page.dart';
import 'package:quizzer/UI_systems/09_feedback_page/feedback_page.dart';
import 'package:quizzer/backend_systems/logger/global_error_handler.dart';
import 'package:quizzer/UI_systems/07_critical_error_page/critical_error_screen.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:logging/logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // Import logging package
import 'package:quizzer/UI_systems/10_stats_page/stats_page.dart';
import 'package:quizzer/app_theme.dart';

import 'UI_systems/11_resetPassword_page/newPassword_page.dart';
import 'UI_systems/11_resetPassword_page/otp_page.dart';
import 'UI_systems/11_resetPassword_page/resetPassword_page.dart';
import 'backend_systems/00_database_manager/database_monitor.dart';
import 'backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart';

// Global Key for NavigatorState - MOVED HERE
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Zone-based error handler
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    SessionManager session = getSessionManager(); // Force initialization of session at startup
    // Initialize DB and schema before UI starts
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    await verifyUserProfileTable(db);
    getDatabaseMonitor().releaseDatabaseAccess();
    session.userId; // Just here to get rid of the warning message. . .
    QuizzerLogger.setupLogging(level: Level.FINE);

    // Global error handler for Flutter framework errors
    PlatformDispatcher.instance.onError = (error, stack) {
      reportCriticalError(
        'Unhandled Flutter error caught by PlatformDispatcher',
        error: error,
        stackTrace: stack,
      );
      return true; // Mark as handled
    };

    runApp(QuizzerApp(navigatorKey: navigatorKey));
  }, (error, stackTrace) {
    reportCriticalError(
      'Unhandled error caught by runZonedGuarded',
      error: error,
      stackTrace: stackTrace,
    );
  });
}

// Convert QuizzerApp to StatefulWidget to listen for critical errors
class QuizzerApp extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const QuizzerApp({super.key, required this.navigatorKey});

  @override
  State<QuizzerApp> createState() => _QuizzerAppState();
}

class _QuizzerAppState extends State<QuizzerApp> {
  CriticalErrorDetails? _criticalError;

  @override
  void initState() {
    super.initState();
    globalCriticalErrorNotifier.addListener(_handleCriticalError);
  }

  @override
  void dispose() {
    globalCriticalErrorNotifier.removeListener(_handleCriticalError);
    super.dispose();
  }

  void _handleCriticalError() {
    if (mounted && globalCriticalErrorNotifier.value != null) {
      QuizzerLogger.logMessage('_QuizzerAppState: Received critical error notification. Current error: $_criticalError, New error: ${globalCriticalErrorNotifier.value}');
      setState(() {
        _criticalError = globalCriticalErrorNotifier.value;
      });
      QuizzerLogger.logMessage('_QuizzerAppState: setState completed. _criticalError is now: $_criticalError');
      
      if (_criticalError != null) {
        widget.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/critical_error', 
          (Route<dynamic> route) => false,
          arguments: _criticalError, 
        );
        QuizzerLogger.logMessage('_QuizzerAppState: Navigation to /critical_error attempted.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    QuizzerLogger.logWarning('_QuizzerAppState: BUILD CALLED. _criticalError is: ${_criticalError?.message}'); // DEBUG LOG
    if (_criticalError != null) {
      // If a critical error has occurred, show the CriticalErrorScreen
      // Using a new MaterialApp instance for the error screen to ensure it's isolated
      return MaterialApp(
        home: CriticalErrorScreen(errorDetails: _criticalError!),
        debugShowCheckedModeBanner: false,
      );
    }

    // Otherwise, show the normal application
    return MaterialApp(
      navigatorKey: widget.navigatorKey,
      title: 'Quizzer',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login':           (context) => const LoginPage(),
        '/resetPassword':           (context) => const ResetPasswordPage(),
        '/verifyOtp':           (context) => const VerifyOtpPage(),
        '/newPassword':           (context) => const NewPasswordPage(),
        '/home':            (context) => const HomePage(),
        '/menu':            (context) => const MenuPage(),
        '/add_question':    (context) => const AddQuestionAnswerPage(),
        '/display_modules': (context) => const DisplayModulesPage(),
        '/signup':          (context) => const NewUserPage(),
        '/admin_panel':     (context) => const AdminPanelPage(),
        '/settings_page':   (context) => SettingsPage(),
        '/feedback':        (context) => const FeedbackPage(),
        '/stats':           (context) => const StatsPage(),
        '/critical_error': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is CriticalErrorDetails) {
            return CriticalErrorScreen(errorDetails: args);
          }
          // Fallback if arguments are not correct, this should not happen
          // if _handleCriticalError always passes them.
          QuizzerLogger.logError('CriticalErrorScreen route was pushed without valid CriticalErrorDetails arguments.');
          return CriticalErrorScreen(
            errorDetails: CriticalErrorDetails(
              message: 'Error: Critical error details not provided to route.',
              error: null,
              stackTrace: null,
            ),
          );
        },
      },
    );
  }
}

// TODO
// Practice Exam 1 from CLEP BOOK
// - continue with question 52 (last entered was question 51)
// Practice Exam 2 from CLEP BOOK