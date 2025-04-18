import 'package:flutter/material.dart';
import 'package:quizzer/features/user_profile_management/pages/login_page.dart';
import 'package:quizzer/features/question_management/pages/home_page.dart';
import 'package:quizzer/global/pages/menu.dart';
import 'package:quizzer/features/question_management/pages/add_question_answer_page.dart';
import 'package:quizzer/features/modules/pages/display_modules_page.dart';
import 'package:quizzer/global/database/quizzer_database.dart';
import 'package:quizzer/global/database/database_monitor.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quizzer/global/functionality/session_manager.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';
import 'package:quizzer/features/modules/functionality/module_updates_process.dart';

// Custom NavigatorObserver to track route changes
class QuizzerNavigatorObserver extends NavigatorObserver {
  final SessionManager _sessionManager = SessionManager();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name != null) {
      _sessionManager.addPageToHistory(route.settings.name!);
      QuizzerLogger.logMessage('Navigated to: ${route.settings.name}');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase - will crash if initialization fails
  await Supabase.initialize(
    url: 'https://yruvxuvzztnahuuiqxit.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlydXZ4dXZ6enRuYWh1dWlxeGl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQzMTY1NDIsImV4cCI6MjA1OTg5MjU0Mn0.hF1oAILlmzCvsJxFk9Bpjqjs3OEisVdoYVZoZMtTLpo',
  );
  QuizzerLogger.logMessage('Supabase initialized');
  
  // Initialize database and monitor
  final monitor = DatabaseMonitor();
  await monitor.initialize();
  await Future.delayed(const Duration(milliseconds: 100)); // Ensure initialization is complete

  // build module records first upon loading in
  bool modulesBuilt = false;
  try {
    QuizzerLogger.logMessage('Starting module build process');
    modulesBuilt = await buildModuleRecords();
    if (modulesBuilt) {
      QuizzerLogger.logSuccess('Module build process completed successfully');
    } else {
      QuizzerLogger.logError('Module build process failed');
    }
  } catch (e) {
    QuizzerLogger.logError('Error during initialization: $e');
  }
  // End of Block
  runApp(QuizzerApp(modulesBuilt: modulesBuilt));
}

class QuizzerApp extends StatelessWidget {
  final bool modulesBuilt;
  
  const QuizzerApp({super.key, required this.modulesBuilt});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quizzer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/menu': (context) => const MenuPage(),
        '/add_question': (context) => const AddQuestionAnswerPage(),
        '/display_modules': (context) => const DisplayModulesPage(),
      },
      navigatorObservers: [QuizzerNavigatorObserver()],
    );
  }
}