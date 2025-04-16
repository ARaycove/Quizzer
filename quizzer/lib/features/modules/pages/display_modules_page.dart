import 'package:flutter/material.dart';
import 'package:quizzer/global/widgets/global_app_bar.dart';
import 'package:quizzer/features/modules/database/modules_table.dart';
import 'package:quizzer/features/modules/widgets/module_card.dart';
import 'package:quizzer/features/modules/widgets/scroll_to_top_button.dart';
import 'package:quizzer/features/modules/widgets/module_filter_button.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';

class DisplayModulesPage extends StatefulWidget {
  const DisplayModulesPage({super.key});

  @override
  State<DisplayModulesPage> createState() => _DisplayModulesPageState();
}

class _DisplayModulesPageState extends State<DisplayModulesPage> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _modules = [];
  bool _isLoading = true;
  bool _showScrollToTop = false;

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
    // TODO: Implement module loading
    // Should fetch module records from the database
    // Should then construct cards for each module in the database
    // Should start a validation process to ensure that the module data is correct and up to date
    // Should then display the module cards in the UI
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
      backgroundColor: const Color(0xFF0A1929),
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                  else if (_modules.isEmpty)
                    const Center(
                      child: Text(
                        'No modules found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ..._modules.map((module) => ModuleCard(moduleData: module)).toList(),
                ],
              ),
            ),
          ),
          // Top action buttons
          Positioned(
            top: 16.0,
            right: 16.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScrollToTopButton(
                  scrollController: _scrollController,
                  showScrollToTop: _showScrollToTop,
                ),
                const SizedBox(width: 8.0),
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