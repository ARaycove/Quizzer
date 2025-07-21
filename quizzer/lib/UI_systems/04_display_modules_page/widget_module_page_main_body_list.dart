import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/module_card/widget_module_card.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/app_theme.dart';

class ModulePageMainBodyList extends StatefulWidget {
  final ScrollController scrollController;

  const ModulePageMainBodyList({
    super.key,
    required this.scrollController,
  });

  @override
  State<ModulePageMainBodyList> createState() => _ModulePageMainBodyListState();
}

class _ModulePageMainBodyListState extends State<ModulePageMainBodyList> {
  final SessionManager session = SessionManager();
  late Future<Map<String, Map<String, dynamic>>> _modulesFuture;

  @override
  void initState() {
    super.initState();
    _loadModulesData();
  }

  void _loadModulesData() {
    _modulesFuture = session.getModuleData();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: _modulesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        } else if (snapshot.hasError) {
          QuizzerLogger.logError('Error loading modules: ${snapshot.error}');
          return const Center(
            child: Text(
              'Error loading modules. Please try again.',
            ),
          );
        } else if (!snapshot.hasData) {
          return const Center(
            child: Text(
              'No data received',
            ),
          );
        }
        
        final modulesData = snapshot.data!;
        
        // Filter modules to only show those with questions
        final modulesWithQuestions = modulesData.entries
            .where((entry) => (entry.value['total_questions'] ?? 0) > 0)
            .toList()
          ..sort((a, b) => (a.value['module_name'] ?? '').toLowerCase().compareTo((b.value['module_name'] ?? '').toLowerCase()));
        
        if (modulesWithQuestions.isEmpty) {
          return const Center(
            child: Text(
              'No modules with questions found',
            ),
          );
        }
        
        return ListView(
          controller: widget.scrollController,
          padding: EdgeInsets.zero,
          children: [
            // Add extra space at the top for the floating buttons
            const SizedBox(height: 40), // Adjust height as needed to fit the buttons
            ...modulesWithQuestions.map((entry) => ModuleCard(
              moduleData: entry.value,
              onModuleUpdated: () {
                setState(() {
                  _loadModulesData();
                });
              },
            )),
          ],
        );
      },
    );
  }
}
