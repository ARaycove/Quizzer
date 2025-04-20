import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/pages/login_page.dart';
import 'package:quizzer/UI_systems/pages/home_page.dart';
import 'package:quizzer/UI_systems/pages/menu.dart';
import 'package:quizzer/UI_systems/pages/add_question_answer_page.dart';
import 'package:quizzer/UI_systems/pages/display_modules_page.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object session = getSessionManager(); // Ensures we load in the session manager and initialize it
  // End of Block
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
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/menu': (context) => const MenuPage(),
        '/add_question': (context) => const AddQuestionAnswerPage(),
        '/display_modules': (context) => const DisplayModulesPage(),
      },
    );
  }
}