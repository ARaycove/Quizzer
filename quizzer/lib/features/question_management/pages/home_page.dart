import 'package:flutter/material.dart';
import 'package:quizzer/features/question_management/widgets/home_page_top_bar.dart';
import 'package:quizzer/global/functionality/session_manager.dart';

// ==========================================
// Widgets
class HomePage extends StatefulWidget {
    const HomePage({super.key});

    @override
    State<HomePage> createState() => _HomePageState();
}
// ------------------------------------------
class _HomePageState extends State<HomePage> {
    final SessionManager _sessionManager = SessionManager();
    bool _showFlagDialog = false;
    final TextEditingController _flagController = TextEditingController();

    @override
    void initState() {
        super.initState();
        if (_sessionManager.userId == null) {
            throw Exception('Security Error: No user ID found in session');
        }
    }

    @override
    void dispose() {
        _flagController.dispose();
        super.dispose();
    }

    void _submitFlag() {
        setState(() {
            _showFlagDialog = false;
            _flagController.clear();
        });
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            backgroundColor: const Color(0xFF0A1929),
            appBar: HomePageTopBar(
                onMenuPressed: () {
                    Navigator.pushNamed(context, '/menu');
                },
                showFlagDialog: _showFlagDialog,
                flagController: _flagController,
                onSubmitFlag: _submitFlag,
                onCancelFlag: () {
                    setState(() {
                        _showFlagDialog = false;
                        _flagController.clear();
                    });
                },
            ),
            body: const Center(
                child: Text(
                    'Home Page',
                    style: TextStyle(color: Colors.white),
                ),
            ),
        );
    }
}