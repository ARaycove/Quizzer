import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_global_app_bar.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/widget_module_card.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/widget_scroll_to_top_button.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/widget_module_filter_button.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

class DisplayModulesPage extends StatefulWidget {
  const DisplayModulesPage({super.key});

  @override
  State<DisplayModulesPage> createState() => _DisplayModulesPageState();
}

class _DisplayModulesPageState extends State<DisplayModulesPage> {
  final ScrollController      _scrollController       = ScrollController();
  final SessionManager        session                 = SessionManager();
  late Future<Map<String, dynamic>> _modulesFuture;
  final ValueNotifier<bool> _showScrollToTopNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    QuizzerLogger.logMessage('Initializing Display Modules Page');
    _loadModulesData();
  }

  void _loadModulesData() {
    _modulesFuture = session.loadModules();
  }

  void _refreshModules() {
    setState(() {
      _loadModulesData();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _showScrollToTopNotifier.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.offset >= 100 && !_showScrollToTopNotifier.value) {
      _showScrollToTopNotifier.value = true;
    } else if (_scrollController.offset < 100 && _showScrollToTopNotifier.value) {
      _showScrollToTopNotifier.value = false;
    }
  }

  void _handleFilter() {
    // TODO: Implement filter functionality
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorWheel.primaryBackground,
      appBar: GlobalAppBar(
        title: 'Modules',
        showHomeButton: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
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
          } else if (!snapshot.hasData || (snapshot.data!['modules'] as List).isEmpty) {
            return const Center(
              child: Text(
                'No modules found',
                style: ColorWheel.secondaryTextStyle,
              ),
            );
          }

          final modules = snapshot.data!['modules'] as List<Map<String, dynamic>>;
          final moduleActivationStatus = snapshot.data!['activationStatus'] as Map<String, bool>;

          return Stack(
            children: [
              // Main content
              SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: const EdgeInsets.all(ColorWheel.standardPaddingValue),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Add space for floating buttons
                      const SizedBox(
                        height: 48.0, 
                      ),
                      ...modules
                          .where((module) => (module['total_questions'] ?? 0) > 0)
                          .map((module) => ModuleCard(
                                moduleData: module,
                                isActivated: moduleActivationStatus[module['module_name']] ?? false,
                                onModuleUpdated: _refreshModules,
                              )),
                    ],
                  ),
                ),
              ),
              // Top action buttons
              Positioned(
                top: ColorWheel.standardPaddingValue,
                right: ColorWheel.standardPaddingValue,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _showScrollToTopNotifier,
                      builder: (context, showScrollToTop, child) {
                        return ScrollToTopButton(
                          scrollController: _scrollController,
                          showScrollToTop: showScrollToTop,
                        );
                      },
                    ),
                    const SizedBox(width: ColorWheel.formFieldSpacing),
                    ModuleFilterButton(
                      onFilterPressed: _handleFilter,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
} 