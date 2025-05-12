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
  List<Map<String, dynamic>>  _modules                = [];
  Map<String, bool>           _moduleActivationStatus = {};
  bool                        _isLoading              = true;
  bool                        _showScrollToTop        = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    QuizzerLogger.logMessage('Initializing Display Modules Page');
    _loadModules();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadModules() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final result = await session.loadModules();
      
      setState(() {
        _modules = result['modules'] as List<Map<String, dynamic>>;
        _moduleActivationStatus = result['activationStatus'] as Map<String, bool>;
        _isLoading = false;
      });
    } catch (e) {
      QuizzerLogger.logError('Error loading modules: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scrollListener() {
    if (_scrollController.offset >= 100 && !_showScrollToTop) {
      setState(() {
        _showScrollToTop = true;
      });
    } else if (_scrollController.offset < 100 && _showScrollToTop) {
      setState(() {
        _showScrollToTop = false;
      });
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
      body: Stack(
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
                    height: 48.0, // Keep fixed for now, could use ColorWheel values later
                  ),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        color: ColorWheel.primaryText,
                      ),
                    )
                  else if (_modules.isEmpty)
                    const Center(
                      child: Text(
                        'No modules found',
                        style: ColorWheel.secondaryTextStyle,
                      ),
                    )
                  else
                    ..._modules
                      .where((module) => (module['total_questions'] ?? 0) > 0)
                      .map((module) => ModuleCard(
                            moduleData: module,
                            isActivated: _moduleActivationStatus[module['module_name']] ?? false,
                            onModuleUpdated: _loadModules,
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
                ScrollToTopButton(
                  scrollController: _scrollController,
                  showScrollToTop: _showScrollToTop,
                ),
                const SizedBox(width: ColorWheel.formFieldSpacing),
                ModuleFilterButton(
                  onFilterPressed: _handleFilter,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 