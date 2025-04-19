import 'package:flutter/material.dart';
import 'package:quizzer/global/widgets/global_app_bar.dart';
import 'package:quizzer/features/modules/widgets/module_card.dart';
import 'package:quizzer/features/modules/widgets/scroll_to_top_button.dart';
import 'package:quizzer/features/modules/widgets/module_filter_button.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';
import 'package:quizzer/global/functionality/session_manager.dart';
import 'package:quizzer/features/modules/functionality/module_isolates.dart';

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

      final result = await handleLoadModules({
        'userId': userId,
      });
      
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

  Future<void> _toggleModuleActivation(String moduleName) async {
    final userId = _sessionManager.userId;
    if (userId == null) {
      QuizzerLogger.logError('No user ID found in session');
      return;
    }

    final currentStatus = _moduleActivationStatus[moduleName] ?? false;
    
    final success = await handleModuleActivation({
      'userId': userId,
      'moduleName': moduleName,
      'isActive': !currentStatus,
    });
    
    if (success) {
      setState(() {
        _moduleActivationStatus[moduleName] = !currentStatus;
      });
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
                          onDescriptionUpdated: (String newDescription) {
                            setState(() {
                              // Update the module in our local state
                              final index = _modules.indexWhere(
                                (m) => m['module_name'] == module['module_name']
                              );
                              if (index != -1) {
                                _modules[index] = {
                                  ..._modules[index],
                                  'description': newDescription,
                                };
                              }
                            });
                          },
                        )),
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