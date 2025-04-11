import 'package:flutter/material.dart';
import 'package:quizzer/ui_pages/login_page.dart';
import 'package:quizzer/database/quizzer_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
late Database db;

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  // Need to initialize the database
  await Supabase.initialize(
    url: 'https://yruvxuvzztnahuuiqxit.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlydXZ4dXZ6enRuYWh1dWlxeGl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQzMTY1NDIsImV4cCI6MjA1OTg5MjU0Mn0.hF1oAILlmzCvsJxFk9Bpjqjs3OEisVdoYVZoZMtTLpo',
  );
  
  sqfliteFfiInit();databaseFactory = databaseFactoryFfi;await initDb();
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