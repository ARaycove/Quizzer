import 'package:flutter/material.dart';
import 'package:quizzer/features/user_profile_management/pages/login_page.dart';
import 'package:quizzer/features/question_management/pages/home_page.dart';
import 'package:quizzer/global/pages/menu.dart';
import 'package:quizzer/features/question_management/pages/add_question_answer_page.dart';
import 'package:quizzer/global/database/quizzer_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quizzer/global/functionality/session_manager.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';

late Database db;

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

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  
  // Need to initialize the database
  await Supabase.initialize(
    url: 'https://yruvxuvzztnahuuiqxit.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlydXZ4dXZ6enRuYWh1dWlxeGl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQzMTY1NDIsImV4cCI6MjA1OTg5MjU0Mn0.hF1oAILlmzCvsJxFk9Bpjqjs3OEisVdoYVZoZMtTLpo',
  );
  
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await initDb();
  
  // Once DB is loaded and opened, we can run the main application
  runApp(const QuizzerApp());
}

class QuizzerApp extends StatelessWidget {
  const QuizzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quizzer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/menu': (context) => const MenuPage(),
        '/add_question': (context) => const AddQuestionAnswerPage(),
      },
      navigatorObservers: [QuizzerNavigatorObserver()],
    );
  }
}