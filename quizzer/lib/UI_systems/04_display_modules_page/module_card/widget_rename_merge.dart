import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/app_theme.dart';
import 'package:dropdown_search/dropdown_search.dart';

class ModuleRenameMergeWidget extends StatefulWidget {
  final String currentModuleName;
  final VoidCallback? onModuleUpdated;

  const ModuleRenameMergeWidget({
    super.key,
    required this.currentModuleName,
    this.onModuleUpdated,
  });

  @override
  State<ModuleRenameMergeWidget> createState() => _ModuleRenameMergeWidgetState();
}

class _ModuleRenameMergeWidgetState extends State<ModuleRenameMergeWidget> {
  final TextEditingController _renameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String? _selectedMergeTarget;
  List<Map<String, dynamic>> _availableModules = [];
  bool _isLoading = false;
  bool _showRenameField = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableModules();
    _searchController.addListener(_filterModules);
  }

  @override
  void dispose() {
    _renameController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _filterModules() {
    setState(() {
    });
  }

  Future<void> _loadAvailableModules() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final sessionManager = getSessionManager();
      final Map<String, Map<String, dynamic>> modulesWithQuestions = await sessionManager.getModuleData(onlyWithQuestions: true);
      final List<Map<String, dynamic>> availableModules = modulesWithQuestions.entries
          .where((entry) => entry.key != widget.currentModuleName)
          .map((entry) => {
            'module_name': entry.key,
            ...entry.value,
          })
          .toList();

      setState(() {
        _availableModules = availableModules;
        _isLoading = false;
      });
    } catch (e) {
      QuizzerLogger.logError('Error loading available modules: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _renameModule() async {
    final String newName = _renameController.text.trim();
    if (newName.isEmpty) {
      _showErrorSnackBar('Please enter a new module name');
      return;
    }
    if (newName == widget.currentModuleName) {
      _showErrorSnackBar('New name must be different from current name');
      return;
    }
    try {
      setState(() {
        _isLoading = true;
      });
      final sessionManager = getSessionManager();
      final bool success = await sessionManager.renameModule(widget.currentModuleName, newName);
      if (success) {
        _showSuccessSnackBar('Module renamed successfully');
        _renameController.clear();
        setState(() {
          _showRenameField = false;
        });
        widget.onModuleUpdated?.call();
      } else {
        _showErrorSnackBar('Failed to rename module');
      }
    } catch (e) {
      QuizzerLogger.logError('Error renaming module: $e');
      _showErrorSnackBar('Error renaming module: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _mergeModule() async {
    if (_selectedMergeTarget == null) {
      _showErrorSnackBar('Please select a target module');
      return;
    }
    try {
      setState(() {
        _isLoading = true;
      });
      final sessionManager = getSessionManager();
      final bool success = await sessionManager.mergeModules(
        widget.currentModuleName,
        _selectedMergeTarget!,
      );
      if (success) {
        _showSuccessSnackBar('Module merged successfully');
        setState(() {
          _selectedMergeTarget = null;
        });
        widget.onModuleUpdated?.call();
      } else {
        _showErrorSnackBar('Failed to merge module');
      }
    } catch (e) {
      QuizzerLogger.logError('Error merging module: $e');
      _showErrorSnackBar('Error merging module: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Module Management'),
        AppTheme.sizedBoxLrg,
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit),
                  AppTheme.sizedBoxSml,
                  const Text('Rename Module'),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showRenameField = !_showRenameField;
                        if (!_showRenameField) {
                          _renameController.clear();
                        }
                      });
                    },
                    icon: Icon(_showRenameField ? Icons.expand_less : Icons.expand_more),
                  ),
                ],
              ),
              if (_showRenameField) ...[
                AppTheme.sizedBoxMed,
                TextField(
                  controller: _renameController,
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                  decoration: const InputDecoration(
                    labelText: 'New Module Name',
                    hintText: 'Enter new name...',
                  ),
                ),
                AppTheme.sizedBoxMed,
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _renameModule,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Rename'),
                  ),
                ),
              ],
            ],
          ),
        ),
        AppTheme.sizedBoxMed,
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.merge),
                  AppTheme.sizedBoxSml,
                  Text('Merge Module'),
                ],
              ),
              AppTheme.sizedBoxMed,
              const Text(
                'Merge this module into another module. All questions will be moved to the target module.',
              ),
              AppTheme.sizedBoxMed,
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else if (_availableModules.isEmpty)
                const Text(
                  'No other modules with questions available for merging',
                  style: TextStyle(fontStyle: FontStyle.italic),
                )
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: DropdownSearch<String>(
                    items: (String filter, _) async {
                      final modules = _availableModules.map((module) => module['module_name'] as String).toList();
                      if (filter.isEmpty) return modules;
                      return modules.where((name) => name.toLowerCase().contains(filter.toLowerCase())).toList();
                    },
                    selectedItem: _selectedMergeTarget,
                    onChanged: (String? value) {
                      setState(() {
                        _selectedMergeTarget = value;
                      });
                    },
                    dropdownBuilder: (context, selectedItem) {
                      return InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Select Target Module',
                        ),
                        child: Text(
                          selectedItem ?? '',
                          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                        ),
                      );
                    },
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      showSelectedItems: true,
                      fit: FlexFit.loose,
                      itemBuilder: (context, item, isSelected, isDisabled) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text(
                            item,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        );
                      },
                      searchFieldProps: TextFieldProps(
                        autofocus: true,
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Search modules...',
                        ),
                      ),
                    ),
                  ),
                ),
                AppTheme.sizedBoxMed,
                if (_selectedMergeTarget != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _mergeModule,
                      child: const Text('Merge Module'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
