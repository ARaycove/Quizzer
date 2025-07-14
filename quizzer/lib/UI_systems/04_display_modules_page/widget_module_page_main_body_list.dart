import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/module_card/widget_module_card.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

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
            child: CircularProgressIndicator(
              color: ColorWheel.primaryText,
            ),
          );
        } else if (snapshot.hasError) {
          QuizzerLogger.logError('Error loading modules: ${snapshot.error}');
          return const Center(
            child: Text(
              'Error loading modules. Please try again.',
              style: ColorWheel.secondaryTextStyle,
            ),
          );
        } else if (!snapshot.hasData) {
          return const Center(
            child: Text(
              'No data received',
              style: ColorWheel.secondaryTextStyle,
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
              style: ColorWheel.secondaryTextStyle,
            ),
          );
        }
        
        return SingleChildScrollView(
          controller: widget.scrollController,
          child: Padding(
            padding: const EdgeInsets.all(ColorWheel.standardPaddingValue),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Add space for floating buttons
                const SizedBox(height: 48.0),
                ...modulesWithQuestions
                    .map((entry) => ModuleCard(
                          moduleData: entry.value,
                          onModuleUpdated: () {
                            // Refresh the modules data when a module is updated
                            setState(() {
                              _loadModulesData();
                            });
                          },
                        )),
              ],
            ),
          ),
        );
      },
    );
  }
}
