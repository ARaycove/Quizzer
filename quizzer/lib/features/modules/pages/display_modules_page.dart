import 'package:flutter/material.dart';
import 'package:quizzer/global/widgets/global_app_bar.dart';
import 'package:quizzer/features/modules/database/modules_table.dart';
import 'package:quizzer/features/modules/widgets/module_card.dart';
import 'package:quizzer/features/modules/widgets/scroll_to_top_button.dart';
import 'package:quizzer/features/modules/widgets/module_filter_button.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';
import 'package:quizzer/features/user_profile_management/database/user_profile_table.dart';
import 'package:quizzer/global/functionality/session_manager.dart';
import 'package:quizzer/features/user_profile_management/functionality/user_question_processes.dart';

class DisplayModulesPage extends StatefulWidget {
  const DisplayModulesPage({super.key});

  @override
  State<DisplayModulesPage> createState() => _DisplayModulesPageState();
}

class _DisplayModulesPageState extends State<DisplayModulesPage> {
  final ScrollController _scrollController = ScrollController();
  final SessionManager _sessionManager = SessionManager();
  List<Map<String, dynamic>> _modules = [];
  Map<String, bool> _moduleActivationStatus = {};
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
    try {
      setState(() {
        _isLoading = true;
      });

      // Get current user ID
      final userId = _sessionManager.userId;
      if (userId == null) {
        QuizzerLogger.logError('No user ID found in session');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Fetch all modules from the database
      final modules = await getAllModules();
      QuizzerLogger.logMessage('Retrieved ${modules.length} modules from database');

      // Fetch module activation status for the current user
      _moduleActivationStatus = await getModuleActivationStatus(userId);
      QuizzerLogger.logMessage('Retrieved module activation status: $_moduleActivationStatus');

      setState(() {
        _modules = modules;
        _isLoading = false;
      });
    } catch (e) {
      QuizzerLogger.logError('Error loading modules: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleModuleActivation(String moduleName) async {
    final userId = _sessionManager.userId;
    if (userId == null) {
      QuizzerLogger.logError('No user ID found in session');
      return;
    }

    // Get current activation status
    final currentStatus = _moduleActivationStatus[moduleName] ?? false;
    
    // Update the status
    final success = await updateModuleActivationStatus(
      userId,
      moduleName,
      !currentStatus,
    );

    if (success) {
      setState(() {
        _moduleActivationStatus[moduleName] = !currentStatus;
      });
      
      await validateModuleQuestionsInUserProfile(moduleName);
      
      QuizzerLogger.logSuccess('Module $moduleName activation status updated to ${!currentStatus}');
    } else {
      QuizzerLogger.logError('Failed to update module $moduleName activation status');
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
                  // Add space for floating buttons
                  const SizedBox(
                    height: 48.0, // Height of a mini FAB (40.0) + some padding
                  ),
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
                    ..._modules.map((module) => ModuleCard(
                          moduleData: module,
                          isActivated: _moduleActivationStatus[module['module_name']] ?? false,
                          onToggleActivation: () => _toggleModuleActivation(module['module_name']),
                        )).toList(),
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