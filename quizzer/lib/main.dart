import 'package:flutter/material.dart';
import 'package:quizzer/login_page.dart';
import 'package:quizzer/database/quizzer_database.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late Database db;

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  // Need to initialize the database
  sqfliteFfiInit();databaseFactory = databaseFactoryFfi;
  await QuizzerDatabase.instance.initDb();
  // Once DB is loaded and opened, we can run the main application
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quizzer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginPage(),
    );
  }
}