import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/03_add_question_page/add_question_answer_page.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/display_modules_page.dart';
import 'package:quizzer/UI_systems/01_new_user_page/new_user_page.dart';
import 'package:quizzer/UI_systems/00_login_page/login_page.dart';
import 'package:quizzer/UI_systems/02_home_page/home_page.dart';
import 'package:quizzer/UI_systems/05_menu_page/menu_page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:path/path.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // --- Hive Initialization (Platform Aware) ---
  String hivePath;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Desktop: Use the ambiguous runtime_cache directory
    hivePath = join(Directory.current.path, 'runtime_cache', 'hive');
    QuizzerLogger.logMessage("Platform: Desktop. Setting Hive path to: $hivePath");
  } else {
    // Mobile: Use standard application documents directory
    Directory appDocumentsDir = await getApplicationDocumentsDirectory();
    hivePath = appDocumentsDir.path;
    QuizzerLogger.logMessage("Platform: Mobile. Setting Hive path to: $hivePath");
  }

  // Ensure the directory exists (important for desktop)
  // If this fails, the app should crash (Fail Fast)
  Directory(dirname(hivePath)).createSync(recursive: true); // Ensure parent dir exists
  // For mobile, appDocumentsDir usually exists, but createSync is safe
  // For desktop, create runtime_cache if needed
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    Directory(hivePath).createSync(recursive: true); // Create the hive subdir
  }
  Hive.init(hivePath); // Initialize Hive with the determined path
  QuizzerLogger.logMessage("Hive Initialized at: $hivePath");
  // ---------------------------------------------
  
  // Optional: Register Adapters here if needed later
  // Hive.registerAdapter(YourAdapter()); 

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