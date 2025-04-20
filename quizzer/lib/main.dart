import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/03_add_question_page/add_question_answer_page.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/display_modules_page.dart';
import 'package:quizzer/UI_systems/01_new_user_page/new_user_page.dart';
import 'package:quizzer/UI_systems/00_login_page/login_page.dart';
import 'package:quizzer/UI_systems/02_home_page/home_page.dart';
import 'package:quizzer/UI_systems/05_menu_page/menu_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        '/login':           (context) => const LoginPage(),
        '/home':            (context) => const HomePage(),
        '/menu':            (context) => const MenuPage(),
        '/add_question':    (context) => const AddQuestionAnswerPage(),
        '/display_modules': (context) => const DisplayModulesPage(),
        '/signup':          (context) => const NewUserPage(),
      },
    );
  }
}