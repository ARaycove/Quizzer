import 'package:flutter/material.dart';
import 'package:quizzer/features/question_management/widgets/home_page_top_bar.dart';

// TODO: Implement proper error handling for all database operations
// TODO: Add comprehensive logging for all user interactions
// TODO: Add proper validation for all user inputs
// TODO: Flag

// ==========================================
// Widgets
class HomePage extends StatefulWidget {
    const HomePage({super.key});

    @override
    State<HomePage> createState() => _HomePageState();
}
// ------------------------------------------
class _HomePageState extends State<HomePage> {
    bool _showFlagDialog = false;
    final TextEditingController _flagController = TextEditingController();

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